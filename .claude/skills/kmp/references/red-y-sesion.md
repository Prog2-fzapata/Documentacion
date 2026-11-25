# Red, errores, sesión y SSE

Marcas: **[verificado]** probado en esta máquina, **[repo]** visto en un repo del profesor, **[propuesta]** sin probar: confirmar al implementar con la versión elegida de Ktor.

## Dependencias (catálogo `libs.versions.toml`)

`ktor-client-core`, `ktor-client-cio`, `ktor-client-content-negotiation`, `ktor-serialization-kotlinx-json`, plugin `kotlinxSerialization` **[repo: kmp-ktor-basico]**. Se suman: `ktor-client-auth` (Bearer), `ktor-client-logging`, y para tests `ktor-client-mock`. El motor CIO sirve en Android **[repo]**; `okhttp` es opcional.

## El cliente (verificado en KMP-02)

```kotlin
class HttpClientFactory(private val session: SessionManager) {

    fun create(engine: HttpClientEngine = CIO.create()): HttpClient = HttpClient(engine) {
        install(ContentNegotiation) { json(json) }
        install(HttpTimeout) { connectTimeoutMillis = 10_000; requestTimeoutMillis = 15_000 }
        defaultRequest { session.token()?.let { bearerAuth(it) } }   // se evalúa en cada pedido
        HttpResponseValidator {
            validateResponse { response -> if (!response.status.isSuccess()) throw toApiException(response) }
        }
    }
}
```

- **Token por pedido con `defaultRequest`, no con el plugin `Auth`:** ese plugin está pensado para renovar tokens y los servicios no los emiten. Se comprueba con `MockEngine` que sin sesión no hay cabecera y con sesión sí.
- **El motor entra por parámetro** para probar con `MockEngine`.
- **Ktor reconoce `application/problem+json`** con el `json()` de ContentNegotiation: `response.body<ProblemDetail>()` alcanza (una mutación lo demostró; no hace falta leerlo como texto). Sin cuerpo o con uno inválido, `runCatching` deja solo el estado HTTP.
- **Sin plugin `Logging`** (ADR 005 del repo KMP).
- El timeout de 15 s por pedido **no sirve para el stream SSE**: ajustarlo por pedido en KMP-08.
- Las respuestas de error de ejemplo para las pruebas se graban de los servicios reales (`curl` a `localhost:8081` y `:8082`), no se inventan.

## Errores: `problem+json` a `ApiException`

```kotlin
@Serializable
data class ProblemDetail(
    val code: String? = null,
    val fieldErrors: List<FieldError> = emptyList()
)

class ApiException(val status: Int, val code: String?, val fieldErrors: List<FieldError>) :
    RuntimeException("HTTP $status ${code ?: ""}")
```

- Formato y códigos: la sección de errores de `docs/contrato.md` de cada servicio. La app decide por `status` y `code`, **nunca** por `detail`.
- **`401`: mirar el `code` y que el pedido llevara token** (ADR 005 del repo KMP). Solo `UNAUTHORIZED` en un pedido con `Authorization` vacía la sesión; `INVALID_CREDENTIALS` es una clave incorrecta al iniciar sesión y no la toca. El servidor no distingue «vencido» de «inválido» a propósito.
- **`code` es un conjunto abierto** (ADR 005 del repo KMP): `ErrorMessages` traduce los códigos de las tablas de errores de `docs/contrato.md` de cada servicio; si llega uno desconocido, se decide por el estado HTTP con un mensaje genérico. **`failureReason` es texto, no un enumerado** (a veces es lo que informó la cátedra): mensaje genérico si no se reconoce, sin `switch`.
- Un `ViewModel` también debe tratar los fallos sin respuesta (sin conexión, timeout): son excepciones de Ktor/IO, no `ApiException`. Mostrar un mensaje «sin conexión» y permitir reintentar.
- Mapa `code → mensaje en español`: una sola clase (por ejemplo `ErrorMessages`) con un `when (code)` y un mensaje genérico para códigos desconocidos.

## `ApiService` por recurso

```kotlin
class ReservationApiService(private val client: HttpClient, private val config: AppConfig) {
    suspend fun create(request: CreateReservationRequest): Reservation =
        client.post("${config.turnosUrl}/api/reservations") {
            contentType(ContentType.Application.Json)
            setBody(request)
        }.body()
}
```

- Un método por endpoint, DTO con los campos del contrato, sin `try/catch` que oculte el error **[repo: tab-navigator atrapa todo y devuelve null/false; no copiar]**.
- Paginación (`X-Total-Count`, `Link`): leer los encabezados de la respuesta antes de `.body()`; `size` por defecto 20 y tope 100.
- Fechas y horas: el contrato usa `yyyy-MM-dd`, `HH:mm:ss` e instantes ISO-8601. **[repo: basic_consumer]** usa `kotlinx-datetime` con un `KSerializer` propio para `LocalDate`; alternativa: dejarlas como `String` en el DTO y convertir en el `ViewModel`.

## Sesión y JWT

- `SessionManager`: guarda el JWT en `SessionStore`, guarda el token en una `MutableStateFlow`; expone `tokenFlow: StateFlow<String?>` (KMP-03): quien lo observa vuelve al login cuando pasa a `null`; y un método `expire()` que borra el token. Un `ApiException` con `status == 401` en cualquier llamada lo invoca (el contrato no distingue vencido de inválido).
- **El JWT no va en `SharedPreferences` comunes ni en logs** (ADR 004 y 005 del repo KMP). `SessionStore` es una interfaz en `commonMain`; la implementación Android cifra el token con AES-GCM con una clave del Android Keystore, sin librería (`EncryptedSharedPreferences` está deprecada por Google; Tink se descartó). Se guarda el texto cifrado con su vector de inicialización.
- Vigencia: 24 horas, o 30 días con `rememberMe`. Al abrir la app, si hay token, entrar; si el primer pedido da `401`, volver al login.
- El JWT técnico de la cátedra **no existe** en la app (`INTEGRATION_REFERENCE-v2.md`).

## SSE y reconciliación (D5; KMP-08)

El contrato (`02-servicio-turnos.md`, «Cambios en tiempo real») es la fuente. Lo que importa para el cliente:

```kotlin
install(SSE)   // en el HttpClient
client.sse("${config.turnosUrl}/api/reservations/stream") {
    incoming.collect { event ->
        if (event.event == "reservation-updated") onUpdated(event.data)   // [propuesta]
    }
}
```

- El `Authorization` lo agrega `defaultRequest` del mismo cliente (no hay plugin `Auth`). Un latido llega como comentario (`:ping`), sin `event` ni `data`: ignorarlo.
- **El stream no es la fuente de verdad.** Al conectar y al reconectar: `GET /api/reservations` y quedarse con las que no son finales (`HOLD_REQUESTED`, `HELD`, `WAITING_PHONE`, `PHONE_QUEUED`, `PHONE_SUBMITTED`) para refrescar. Al recibir un aviso: `GET /api/reservations/{id}` (el `data` es solo un resumen).
- No hay `Last-Event-ID` ni historia: un aviso perdido no se reenvía.
- Si el JWT vence, el servidor cierra el stream (no hay `401` en esa conexión): detectar el cierre, comprobar la sesión y recién entonces reconectar. Reconexión con espera creciente y tope; cerrar el stream al cerrar sesión.
- Hasta 5 conexiones por usuario: abrir **una** por proceso de la app, no una por pantalla.
- **[propuesta]** Qué motor de Ktor soporta bien SSE en Android y cómo llegan los comentarios: probarlo contra el servicio real (`docker compose up` en `ServicioTurnos`) antes de darlo por cerrado.
