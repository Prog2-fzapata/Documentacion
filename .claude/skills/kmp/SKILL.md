---
name: kmp
description: Genera o revisa la app Android del proyecto de turnos hecha con Kotlin Multiplatform y Compose Multiplatform, con las convenciones de los repos del profesor (UI en clases con Content(), navegación con Voyager, MVVM, cliente Ktor con JWT y SSE). Usar al crear o modificar pantallas, ViewModels, el cliente HTTP, la sesión, la navegación o el build del repo KMP. Palabras clave: KMP, Kotlin Multiplatform, Compose Multiplatform, Voyager, Ktor, ViewModel, StateFlow, SSE, composeApp, Gradle, Android, pantalla, Tab.
---

# KMP — convenciones del proyecto de turnos

App Android (obligatoria) con Kotlin Multiplatform + Compose Multiplatform que consume los dos servicios (catálogo `:8081`, turnos `:8082`). Los contratos vigentes están en `docs/contrato.md` de cada servicio (`ServicioCatalogo` y `ServicioTurnos`) y son la fuente de los endpoints y de los códigos de error: **no copiarlos acá**. Los borradores de `Documentacion/contratos/` quedaron atrás y no hay que usarlos.

Fuentes de esta skill, todas del profesor (`dqmdz`): `kmp.cliente.producto` (23/11/2026, la base), `full-stack-mobile-crud-tab-navigator` (formularios y CRUD con Voyager), `kmp.basic_consumer` (MVVM con `ViewModel`), `kmp.navegacion.bottombar` (otra navegación) y `kmp-ktor-basico`. Cada afirmación se marca: **[verificado]** probado en esta máquina, **[repo]** visto en un repo del profesor, **[propuesta]** sin probar, a confirmar al implementar.

## Qué mira el profesor

El informe automático de `main` (`docs/EVALUACION.md` de cada servicio) trae una dimensión **D3 «Frontend KMP: MVVM y buenas prácticas» (10 %)** y las métricas «código dentro de clases (%POO)» y «funciones fuera de clases». Los criterios de D3 **no están publicados** (en los servicios figura N/A). Por eso:

- **[propuesta, no confirmada]** Preferir clases para pantallas y lógica, y funciones sueltas solo cuando hacen falta (`App()`, `expect/actual`, `main`, `@Preview`). Las métricas «%POO» y «funciones fuera de clases» solo se vieron en los informes de backend (Java); no se sabe si penalizan las `@Composable` sueltas: `cliente.producto` (23/11) usa una `fun App()` suelta y `bottombar` usa clases.
- Arquitectura **MVVM**: la pantalla no llama a Ktor; un `ViewModel` expone estado y la pantalla lo dibuja.
- Sin secretos, con `.env`/config de entorno y el wrapper de Gradle versionado (como D7 en los backends).

## Regla fundamental

```
screens (Content)  →  viewmodel  →  network (ApiService)
```

- La pantalla conoce al `ViewModel`; el `ViewModel` conoce al `ApiService`; **nunca** una pantalla importa `io.ktor`.
- El `ViewModel` no conoce Compose ni Voyager: expone `StateFlow<…State>` y recibe eventos como métodos.
- Los `ApiService` reciben el `HttpClient` por constructor (se prueban con `MockEngine`); no leer un cliente global.

## Estructura (un módulo `composeApp`)

Un solo módulo de Gradle con `commonMain` (casi todo) y `androidMain` (lo propio de Android), como `cliente.producto` (ADR 001 del repo KMP). Con AGP 9 este diseño no es posible **[verificado]**: `kotlinMultiplatform` y `com.android.application` no pueden ir en el mismo módulo; por eso se usa AGP 8.13.

```
composeApp/src/commonMain/kotlin/<paquete>/
├── App.kt                      → arranca el tema y el Navigator raíz
├── config/AppConfig.kt         → URLs base de catálogo y turnos
├── network/
│   ├── HttpClientFactory.kt    → fábrica del HttpClient (JSON, token por pedido, timeouts, errores)
│   ├── ErrorMessages.kt        → code → mensaje en español, con mensaje genérico por estado
│   ├── ApiException.kt         → error de la app con status y code
│   ├── UserApi.kt              → register, authenticate (KMP-03), updateName (POST /api/account parcial, KMP-06): el slice `usuario` del catálogo
│   ├── CatalogApi.kt           → professionals (filtros, página y X-Total-Count), categories (KMP-04)
│   ├── TurnosApi.kt            → availability ordenada en la app (KMP-05), startReservation con timeout propio y reservations (KMP-06), reservation(id) y sendPhone (KMP-07); la lista paginada con status y cancel (KMP-09)
│   ├── StreamConnection.kt     → una conexión SSE a /api/reservations/stream con el plugin de Ktor: Connected y Updated(id) (KMP-08)
│   ├── ReservationStream.kt    → reconecta con 2, 4 y 8 s y comprueba la sesión antes de reconectar; recibe cómo conectar (KMP-08)
│   ├── AppJson.kt              → el Json compartido por los pedidos y los avisos del stream
│   └── model/                  → DTO @Serializable (ProblemDetail, Professional, Reservation…)
├── AppContainer.kt             → arma cliente, sesión y mensajes a mano; lo crea ClienteApplication (androidMain)
├── session/                    → SessionStore (JWT) y SessionManager (sesión activa, 401)
├── viewmodel/                  → un ViewModel por pantalla o flujo + su State (ReservationViewModel sigue una reserva hasta confirmarla; ResumeViewModel la reanuda al abrir la app); ReservationStep dice qué se espera según el estado y canSubmitPhone
├── screens/                    → MainNavigationScreen, auth/, tabs/, reserva/ (clases Screen/Tab)
│   └── components/             → piezas que varias pantallas reutilizan (FormField, LabeledCheckbox, Centered, RetryMessage, LoadMoreWhenNearEnd, DaySlots, ConfirmReservationDialog, PatientNameDialog, PhoneDialog) [verificado en KMP-03]
└── ui/                         → tema compartido, si hace falta
composeApp/src/androidMain/…    → MainActivity (delgada), AndroidManifest, almacenamiento seguro del JWT
composeApp/src/commonTest/…     → tests con kotlin-test y MockEngine
```

Paquete raíz y `applicationId`: `ar.edu.um.prog2.fzapata.cliente` (ADR 010 del repo KMP; el profesor usa `ar.edu.um.programacion2`).

## UI: clases con `Content()`

Toda pantalla es una clase (o `object` para las `Tab`, como en el repo) con un `Content()`. Con Voyager ese método lo impone `Screen`/`Tab`.

```kotlin
class ProfessionalListScreen : Screen {
    @Composable
    override fun Content() {
        val viewModel = viewModel { ProfessionalListViewModel(/* ApiService */) }
        val state by viewModel.state.collectAsState()
        // dibuja state y delega eventos: viewModel.search(text)
    }
}
```

- Estado que cambia → parámetros de `Content()` o `StateFlow`, no del constructor.
- Los componentes reutilizables también son clases con `Content(...)`.
- La `MainActivity` solo llama a `App().Content()` **[repo: bottombar]**; en `cliente.producto` llama a `App()` suelta: preferir la clase.

## MVVM

```kotlin
class ProfessionalListViewModel(private val api: CatalogApiService) : ViewModel() {
    private val _state = MutableStateFlow(ProfessionalListState())
    val state: StateFlow<ProfessionalListState> = _state.asStateFlow()

    fun load() {
        viewModelScope.launch {
            _state.update { it.copy(loading = true, error = null) }
            try {
                _state.update { it.copy(loading = false, items = api.professionals()) }
            } catch (e: ApiException) {
                _state.update { it.copy(loading = false, error = e.code) }
            }
        }
    }
}
```

- `…State` es una `data class` inmutable con `loading`, datos y `error`; toda pantalla de red tiene los tres estados.
- Capturar `ApiException` (y los fallos de red) y convertirlos en estado; **nunca** un `catch` vacío ni uno que devuelva `null`/`false` y oculte la causa.
- `ViewModel` de `androidx.lifecycle` (`org.jetbrains.androidx.lifecycle:lifecycle-viewmodel-compose` 2.9.4) **[verificado en KMP-03, ADR 006 del repo]**; alternativa de Voyager: `ScreenModel` (otra dependencia). Un `viewModel { }` dentro de una `Screen` de Voyager se asocia a la Activity, no a la pantalla: pedirlo con `viewModel(key = key)` (la clave de la pantalla) para que cada instancia tenga el suyo, y no dejar contraseñas en su estado (queda en memoria hasta cerrar la Activity).
- **Pantalla según la sesión:** `App` observa `session.tokenFlow` y arma el `Navigator` con `key(hasSession) { Navigator(if (hasSession) HomeScreen() else LoginScreen()) }`; el `ViewModel` de login solo guarda el token. Cubre iniciar y cerrar sesión y el `401` sin que cada pantalla navegue **[verificado]**.

## Red (Ktor)

Detalle en [references/red-y-sesion.md](references/red-y-sesion.md). Reglas:

- JSON con `ignoreUnknownKeys` y DTO `@Serializable`; `Authorization: Bearer` desde la sesión.
- Un solo traductor de errores: `status` + `code` del `problem+json` a `ApiException`; la app decide por `code`, **nunca** por `detail`.
- `Logging` sin `LogLevel.BODY` en release y con `Authorization` ocultado; la respuesta de `POST /api/authenticate` trae el JWT.
- Timeouts en todas las llamadas (el backend responde `503` cuando una dependencia cae).

### SSE (KMP-08) **[verificado]**

- El plugin `io.ktor.client.plugins.sse.SSE` viene dentro de `ktor-client-core` y anda con el motor CIO (no hace falta OkHttp). `client.sse(url, request = { timeout { requestTimeoutMillis = INFINITE; socketTimeoutMillis = INFINITE } }) { incoming.collect { … } }`: sin los dos topes infinitos el general de 15 s corta la conexión.
- Por defecto no reconecta (`maxReconnectionAttempts = 0`) y oculta los `:ping`. La reconexión, con espera creciente y comprobación de sesión, es de la app (`ReservationStream`).
- El plugin envuelve **todo** error del apretón de manos (un 401, un corte) en una `SSEClientException`, y el 401 llega sin `code`: se desenvuelve con `e.cause ?: e` y la sesión se comprueba con un pedido normal, que sí sabe vaciarla.
- `MockEngine` **no soporta SSE** y no se puede adaptar desde afuera: se prueba la política de reconexión con conexiones guionadas (`() -> Flow`) y tiempo virtual, y la conexión real contra los servicios.
- Una pantalla que escucha lo hace con `LaunchedEffect(viewModel) { viewModel.watch() }` dentro de `if (!state.finished)`: se cancela al irse la pantalla o al terminar la reserva y la conexión se cierra (comprobado con `ss`: 1 conexión abierta con la reserva a la vista, 0 al salir). `canRetry` no tapa la cancelación.
- Un pedido que no debe ocurrir se comprueba con el motor falso en el mismo hilo (`MockEngine.create { dispatcher = Dispatchers.Unconfined; addHandler { … } }`); si no, el «no pasó nada» siempre parece cierto.

## Navegación (Voyager)

- `Navigator` raíz con una puerta de autenticación: sin sesión `LoginScreen`, con sesión `MainNavigationScreen` (`TabNavigator` + `NavigationBar`) **[repo: cliente.producto]**.
- Detalle y reserva se apilan con `navigator.push(...)`. Un `401` en cualquier llamada vacía la sesión y vuelve al login.
- **Pestañas (KMP#21, KMP-09) [verificado]:** `MainScreen` (la pantalla con sesión) arma un `TabNavigator` con Profesionales, Mis reservas y Mi perfil. Dentro de una pestaña `LocalNavigator` es el navegador **de las pestañas**: apilar ahí una pantalla que no es `Tab` cierra la app (`ClassCastException`), así que las pestañas apilan con `LocalNavigator.currentOrThrow.parent`, que las tapa con la barra. La reanudación de la reserva vive en `MainScreen`, no en una pestaña (se dispararía en cada vuelta).
- **ViewModel por pantalla [verificado]:** la clave por defecto de `Screen` es el nombre de la clase, pero Voyager da a cada pantalla su propio almacén de `ViewModel` y lo descarta al salir de la pila: dos pantallas de la misma clase en secuencia no comparten ViewModel (probado con dos profesionales y con dos usuarios). No hace falta `uniqueScreenKey`. Al cambiar de pestaña lo escrito en un `ViewModel` se conserva.
- Una lista con secciones por día y el stream (KMP-09): ver `MyReservationsViewModel` (lee páginas hasta la primera anterior y reconcilia las ya cargadas ante cada aviso).
- Mapa de pantallas y endpoints: [references/pantallas-y-flujos.md](references/pantallas-y-flujos.md).

## Build y entorno

Detalle en [references/proyecto-y-build.md](references/proyecto-y-build.md). Lo esencial (ADR 001 del repo KMP):

- Pila: AGP 8.13.0, Gradle 8.14.3, Kotlin 2.2.20, Compose Multiplatform 1.9.0, Ktor 3.3.0, Voyager 1.1.0-beta03, `compileSdk` 36, **JDK 21**. Compila y **se ejecuta en el emulador** **[verificado]**.
- Gradle 8.14.3 **no arranca con JDK 25** (el del sistema aquí) **[verificado]**: usar JDK 21.
- Solo target Android: en `cliente.producto` los otros (`jvm`, iOS, web) sobran y **`jvm` no compila** **[verificado]** (quedaron `actual` sin su `expect`).
- Las URLs base cambian por tipo de build y no se escriben en el código; el JWT técnico de la cátedra no existe en la app.
- Los repos del profesor son **AGPL-3.0**: se aprende de ellos, no se copia su código.

## Qué NO copiar de los repos del profesor

| Visto en | Problema | Qué hacer |
| --- | --- | --- |
| `kmp-ktor-basico` | API key escrita en la URL | Sin secretos en el repo ni en el APK |
| `basic_consumer` | `BASE_URL` fija con una IP de la LAN; `LogLevel.BODY` | URL por build; sin log de cuerpos |
| `basic_consumer` | Funciones y `client` globales en `KtorClient.kt` | Clases `ApiService` con el cliente por constructor |
| `cliente.producto` | `catch (e: Exception) {}` vacío; llamada de red desde el composable | Estado de error en el `ViewModel` |
| `tab-navigator` | `ApiService` que atrapa todo y devuelve `null`/`false` | Lanzar `ApiException` y que el `ViewModel` decida |
| `cliente.producto` | Funciones vacías (`deleteProduct`), imports sin usar, test `1 + 2` | No dejar código muerto ni tests de relleno |
| `cliente.producto` | `http://` sin `usesCleartextTraffic` en el manifest | Permitir texto plano solo en debug **[propuesta]**: Android 9+ lo bloquea por defecto |
| varios | Mezcla de Material y Material 3 | Solo Material 3 |

## Estilo del proyecto (manda sobre el KDoc del profesor)

- Comentarios breves de una línea que expliquen el **porqué**; no KDoc largo. Lo largo va al README.
- En clases de producción: métodos **públicos arriba**, auxiliares privados **abajo**, en el orden en que los llama el código de arriba. En los tests, los auxiliares **arriba**, antes de los `@Test`.
- Un solo estilo para todo el repo (consistencia total).
- Documentación al implementar: cada decisión de la app, con sus alternativas descartadas, como ADR numerado en `docs/decisiones/` del repo KMP (con su entrada en el índice); en `Documentacion/decisiones.md` solo lo general.
- Git, commits y PR: ver `CLAUDE.md` y `/repaso`; el flujo por issue es el mismo que en los backends.

## Checklist de una pantalla nueva

1. Leer el issue y el `docs/contrato.md` del servicio para ese endpoint.
2. `network/model/`: DTO `@Serializable` con los campos reales del contrato.
3. `network/<Recurso>ApiService`: un método por endpoint; el `HttpClient` entra por constructor.
4. `viewmodel/<Pantalla>ViewModel` + `…State` con `loading`, datos y `error`.
5. `screens/…`: clase `Screen` o `Tab` con `Content()`; sin `io.ktor`.
6. Mensajes en español para cada `code` posible (tabla en `pantallas-y-flujos.md`).
7. Pruebas (opcionales, ADR 003 del repo KMP): solo para lógica pura que codifica el contrato (traducción de `problem+json`, validaciones, lectura de SSE, reglas de estado); no se prueban las pantallas ni hay SonarCloud en la app. Pocas, y que se puedan explicar.
8. Verificar con JDK 21: `./gradlew :composeApp:assembleDebug :composeApp:testDebugUnitTest` **[verificado en KMP-01]**; para confiar en un test, romper el código a propósito y ver que falle (y recompilar con `clean` al restaurar).
