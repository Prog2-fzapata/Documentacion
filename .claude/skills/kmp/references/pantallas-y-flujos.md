# Pantallas, navegación y mapa de issues

Los endpoints, campos y errores están en `docs/contrato.md` de cada servicio. Acá solo el mapa de la app. Marcas: **[repo]** visto en el repo del profesor, **[propuesta]** sin probar.

## Navegación (Voyager)

```
Navigator(raíz)
 ├─ sin sesión → LoginScreen ⇄ RegisterScreen
 └─ con sesión → MainScreen   (TabNavigator + NavigationBar)
        ├─ Tab Profesionales  → push AvailabilityScreen → push ReservationScreen (teléfono)
        ├─ Tab Mis reservas   → push ReservationDetailScreen (cancelar) o ReservationScreen
        └─ Tab Mi perfil      → datos de la cuenta, cerrar sesión
```

- **[verificado en KMP-04]** Con sesión, la raíz muestra `ProfessionalListScreen` (la lista con filtros) y la barra de pestañas llegó después, con el issue #21 (ADR 014 del repo). Lista paginada: `LazyColumn` + `derivedStateOf` sobre el último ítem visible y `LaunchedEffect(nearTheEnd, items.size)` para pedir la página siguiente; `X-Total-Count` corta; cambiar un filtro cancela el `Job` en curso (ADR 007 del repo). El pedido al llegar al final es el componente `LoadMoreWhenNearEnd`.
- **[verificado en KMP-05]** `AvailabilityScreen(professionalId, professionalName)` pide ventanas de 30 días seguidas (hoy a hoy+29, luego +30…) con el mismo scroll infinito; salta las ventanas vacías y corta al llegar a un año (`BOOKING_HORIZON_DAYS = 365`); el servicio no tiene tope hacia adelante (devolvió horarios hasta 2100). Fechas con `kotlinx-datetime` (0.7.1; `kotlin.time.Clock` pide `@OptIn(ExperimentalTime::class)` en Kotlin 2.2) y como `String` en los modelos; el contrato admite 31 días contando ambos extremos (ADR 008 del repo).
- **[verificado en KMP-06]** Reservar: diálogo de confirmación, un pedido a la vez (`reserving`), timeout propio de 45 s en el `POST`, un camino por código y, ante `RESERVATION_CONFLICT`, corte o `503`, buscar en `GET /api/reservations` antes de dejar repetir. El nombre se guarda con `POST /api/account` parcial (solo `firstName` y `lastName`; turnos exige 2 caracteres y el catálogo acepta 1). La reserva abre `ReservationScreen` con `replace`. Las reglas de cada respuesta viven en `ReservationStarter` (sin estado, devuelve un `StartResult`) y el `ViewModel` solo las traduce a estado: cuando un `ViewModel` mezcla dos tareas, se saca una a una clase colaboradora (ADR 011 del repo).
- Login correcto y sesión vencida (`401`): no se navega a mano. `App` observa `tokenFlow` y, con `key(hasSession)`, reemplaza la raíz por `MainScreen` o `LoginScreen`.
- Las pestañas son clases `Tab` (`class ProfileScreen : Tab`) con `TabOptions` (índice, título, ícono); dentro de una pestaña `LocalNavigator` es el de las pestañas, así que se apila con `.parent`. Las demás pantallas, clases `Screen`.
- **[propuesta]** Apilar pantallas dentro de una pestaña (push desde una `Tab`) requiere un `Navigator` anidado; probarlo en KMP-04.
- Las pantallas reciben datos y callbacks; no deciden la navegación global (la sesión sí).

## Mapa de issues KMP

| Issue | Pantalla o pieza | Endpoints | Códigos a mostrar |
| --- | --- | --- | --- |
| KMP-01 | Proyecto base | — | — |
| KMP-02 | Cliente, sesión, errores | todos | `UNAUTHORIZED`, `VALIDATION_ERROR`, `*_UNAVAILABLE` |
| KMP-03 | `LoginScreen`, `RegisterScreen`, cuenta | `POST /api/register`, `POST /api/authenticate`, `GET /api/account` | `INVALID_CREDENTIALS`, `LOGIN_ALREADY_USED`, `EMAIL_ALREADY_USED` |
| KMP-04 | Lista de profesionales + filtros | `GET /api/professionals`, `GET /api/professional-categories` | `VALIDATION_ERROR` |
| KMP-05 | Turnos disponibles | `GET /api/availability` | `INVALID_DATE_RANGE`, `PROFESSIONAL_DISABLED`, `PROFESSIONAL_NOT_FOUND` |
| KMP-06 | Reservar | `POST /api/reservations`, `GET`/`POST /api/account` | `SLOT_UNAVAILABLE`, `PATIENT_NAME_REQUIRED`, `INVALID_SLOT`, `RESERVATION_EXPIRED`, `RESERVATION_CONFLICT` |
| KMP-07 | Teléfono | `POST /api/reservations/{id}/phone` | `VALIDATION_ERROR`, `INVALID_RESERVATION_STATE` |
| KMP-08 | SSE + reconciliación | `GET /api/reservations/stream`, `GET /api/reservations` | cierre del stream |
| KMP-09 | Mis reservas y cancelar | `GET /api/reservations`, `GET /{id}`, `POST /{id}/cancel` | `RESERVATION_NOT_FOUND`, `RESERVATION_NOT_CANCELLABLE`, `RESERVATION_CONFLICT` |
| KMP-10 | Errores y vencimiento | — | `EXPIRED`, `FAILED`, `*_UNAVAILABLE`, sin conexión |

## Reglas de comportamiento (ya decididas)

- **Reservar** (D14): el pedido de reserva es la verificación; no se consulta disponibilidad antes. Un `409 SLOT_UNAVAILABLE` es un caso normal: avisar y refrescar la grilla. Evitar el doble toque.
- **Nombre y apellido** (D33, D34): son opcionales al registrarse y se exigen al reservar. `400 PATIENT_NAME_REQUIRED` abre un modal; como `POST /api/account` exige `email`, primero `GET /api/account` y reenviar los datos actuales más el nombre; luego reintentar la reserva.
- **Teléfono** (A8, D89): el campo se habilita cuando `canSubmitPhone` es `true`. Validar localmente `^\+?[0-9]{7,15}$` tras quitar espacios, guiones, paréntesis y puntos. Si la cátedra lo rechaza la reserva vuelve a `WAITING_PHONE` y se reintenta hasta `expiresAt`.
- **Cancelar**: solo reservas `CONFIRMED`, con confirmación y motivo opcional (hasta 500 caracteres).
- **`RESERVATION_CONFLICT`**: consultar el estado de la reserva antes de repetir el pedido.
- **Lista de reservas**: sin `status` no trae las `EXPIRED` ni `FAILED`; con `status` trae exactamente las de ese estado.
- **Ventana de disponibilidad** (D13): 14 a 30 días, máximo 31 contando ambos extremos.

## Estados de la reserva y qué muestra la UI

| `status` | Qué ve el usuario |
| --- | --- |
| `HOLD_REQUESTED`, `HELD` | «Reservando…» (sin cuenta regresiva: ADR 012) |
| `WAITING_PHONE` | Pide el teléfono (campo habilitado solo con `canSubmitPhone`) |
| `PHONE_QUEUED`, `PHONE_SUBMITTED` | «Enviando el teléfono…» |
| `CONFIRMED` | Confirmada; permite cancelar |
| `EXPIRED` | «El tiempo para confirmar terminó» |
| `FAILED` | Mensaje según `failureReason` (genérico si no se reconoce) |
| `CANCELLED` | Cancelada, con `cancellationReason` |

Sin estados colgados (KMP-10): toda llamada con timeout y el vencimiento lo resuelven el servicio, el stream, `RESERVATION_EXPIRED` al enviar y el «Reintentar» de los 42 s; no hay un reloj con `expiresAt` (ADR 012 y 016).

## Pruebas que valen la pena (ADR 003)

Pocas, en `commonTest`, solo donde protegen el contrato con los servicios:

- **KMP-02:** un `problem+json` con `code` se traduce al error esperado de la app, y uno sin cuerpo no rompe.
- **KMP-03:** las validaciones del registro (login de 3 a 50, password de 4 a 100, email de 5 a 254).
- **KMP-07:** el teléfono `^\+?[0-9]{7,15}$` tras quitar separadores.
- **KMP-08:** un evento `reservation-updated` se lee bien y un `:ping` se ignora.
- **KMP-10:** cada estado terminal de la reserva tiene su mensaje.

No se prueban las pantallas Compose.
