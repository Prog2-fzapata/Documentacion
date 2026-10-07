# Contrato - Servicio Turnos

Consumidor: **app KMP**. Todos los endpoints requieren JWT de usuario y operan **solo sobre datos del usuario autenticado**. Convenciones en [00-convenciones.md](00-convenciones.md).

## Disponibilidad

### `GET /api/availability?professionalId=15&from=2026-10-12&to=2026-10-25`

Los tres parametros son obligatorios. `to` no puede ser anterior a `from` y el rango maximo es 31 dias (propuesta). Se excluyen horarios pasados.

Respuesta `200 OK`, ordenada por fecha y hora ascendente:

```json
{
  "professionalId": 15,
  "from": "2026-10-12",
  "to": "2026-10-25",
  "slots": [
    { "date": "2026-10-12", "startTime": "09:00:00", "endTime": "09:30:00" },
    { "date": "2026-10-12", "startTime": "10:00:00", "endTime": "10:30:00" }
  ]
}
```

Es una foto: el veredicto real lo da el hold al reservar.

Errores: `400 INVALID_DATE_RANGE`, `404 PROFESSIONAL_NOT_FOUND`, `400 PROFESSIONAL_DISABLED`, `503 CATALOG_UNAVAILABLE`, `503 CATEDRA_UNAVAILABLE`.

## Reservas

### Objeto `Reservation`

```json
{
  "id": 101,
  "reservationProcessId": "process-a92b47d0",
  "status": "WAITING_PHONE",
  "professionalId": 15,
  "professionalFirstName": "Ana",
  "professionalLastName": "Gomez",
  "appointmentDate": "2026-10-12",
  "startTime": "09:30:00",
  "endTime": "10:00:00",
  "expiresAt": "2026-10-07T14:44:50Z",
  "patientPhone": null,
  "failureReason": null,
  "cancellationReason": null,
  "createdAt": "2026-10-07T14:35:00Z",
  "updatedAt": "2026-10-07T14:35:10Z"
}
```

`status`: `HOLD_REQUESTED`, `HELD`, `WAITING_PHONE`, `PHONE_QUEUED`, `PHONE_SUBMITTED`, `CONFIRMED`, `EXPIRED`, `FAILED`, `CANCELLED`. `id` es el identificador local; `expiresAt` solo tiene sentido en estados no finales. Nunca se expone el `user_id`.

### `POST /api/reservations`

```json
{ "professionalId": 15, "date": "2026-10-12", "startTime": "09:30" }
```

El backend valida con Catalogo (profesional habilitado, horario dentro de su agenda), pide el hold, lo confirma inicialmente y devuelve el proceso. Nombre y apellido del paciente y el identificador salen del JWT.

Respuesta `201 Created`: `Reservation` normalmente en `WAITING_PHONE` (si la catedra aun no publico el pedido, el telefono se solicita igual: el SSE avisa cuando se puede enviar; ver nota).

Errores:

| HTTP | `code` | Cuando |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` | campos faltantes o formato invalido |
| 400 | `INVALID_SLOT` | horario fuera de la agenda |
| 400 | `PROFESSIONAL_DISABLED` | profesional deshabilitado |
| 404 | `PROFESSIONAL_NOT_FOUND` | profesional inexistente |
| 409 | `SLOT_UNAVAILABLE` | la catedra respondio `SLOT_ALREADY_HELD` o `SLOT_ALREADY_RESERVED` |
| 503 | `CATALOG_UNAVAILABLE` / `CATEDRA_UNAVAILABLE` | dependencia caida |

### `POST /api/reservations/{id}/phone`

```json
{ "phoneNumber": "+5492615551234" }
```

Valida `^\+?[0-9]{7,15}$` (tras quitar espacios, guiones, parentesis y puntos). Solo en `WAITING_PHONE` y con el pedido de la catedra ya recibido. Respuesta `202 Accepted`: `Reservation` en `PHONE_QUEUED`. El resultado final llega por SSE.

Errores: `400 VALIDATION_ERROR`, `404 RESERVATION_NOT_FOUND`, `409 INVALID_RESERVATION_STATE` (incluye "todavia no llego el pedido de telefono"), `409 RESERVATION_EXPIRED`.

Si la catedra rechaza el telefono, la reserva vuelve a `WAITING_PHONE` y el usuario puede reintentar hasta `expiresAt`.

### `GET /api/reservations?status=CONFIRMED&page=0&size=20`

Lista **solo las reservas del usuario autenticado**. Filtro opcional `status`. Orden por defecto: fecha y hora descendente. Con `X-Total-Count`.

### `GET /api/reservations/{id}`

Una reserva propia. `404 RESERVATION_NOT_FOUND` tambien para reservas ajenas.

### `POST /api/reservations/{id}/cancel`

Body opcional: `{ "reason": "hasta 500 caracteres" }`. Solo reservas propias en `CONFIRMED`. `200 OK`: `Reservation` en `CANCELLED`. Cancelar una ya `CANCELLED` devuelve su estado actual (idempotente).

Errores: `404 RESERVATION_NOT_FOUND`, `409 RESERVATION_NOT_CANCELLABLE`, `503 CATEDRA_UNAVAILABLE`.

## Cambios en tiempo real (SSE)

### `GET /api/reservations/stream`

`Accept: text/event-stream`, con `Authorization: Bearer`. Solo emite eventos de reservas del usuario autenticado.

```
event: reservation-updated
id: 101-5
data: {"id":101,"status":"CONFIRMED","expiresAt":null,"updatedAt":"2026-10-07T14:36:01Z"}
```

- Se emite un `reservation-updated` en cada cambio de estado (incluye `WAITING_PHONE` cuando llega el pedido de telefono, rechazos, confirmacion, vencimiento y cancelacion).
- El `data` es resumido; para el detalle completo la app llama a `GET /api/reservations/{id}`.
- Comentario de latido (`: ping`) cada ~25 s para mantener viva la conexion.
- **La app no depende del stream**: al conectar o reconectar consulta `GET /api/reservations` de procesos no finales y refresca. El stream es una optimizacion, no la fuente de verdad.
- Si el JWT vence, el servidor cierra con `401` y la app vuelve a autenticarse.

## Nota: pedido de telefono vs. respuesta del POST

La catedra publica `AdditionalInformationRequested` **despues** del `202` de confirm, de forma asincrona. Por eso `POST /api/reservations` puede devolver la reserva en `WAITING_PHONE` antes de tener guardado el `requestEventId`. Regla: `POST .../phone` responde `409 INVALID_RESERVATION_STATE` hasta recibir el pedido; la app solo habilita el formulario cuando el SSE (o una consulta) informa que se puede enviar. Alternativa a evaluar: un campo `phoneRequested` (boolean) en `Reservation` (ver A8).
