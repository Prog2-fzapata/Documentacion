# Contrato - Servicio Turnos

Consumidor: **app KMP**. Todos los endpoints requieren JWT de usuario y operan **solo sobre datos del usuario autenticado**. Convenciones en [00-convenciones.md](00-convenciones.md).

## Disponibilidad

### `GET /api/availability?professionalId=15&from=2026-10-12&to=2026-10-25`

Los tres parametros son obligatorios. `to` no puede ser anterior a `from` y el rango maximo es 31 dias contando ambos extremos (configurable con `AVAILABILITY_MAX_RANGE_DAYS`). Los slots salen de la agenda del profesional, menos las ocupaciones de la catedra (`CONFIRMED` y `HELD`). Se excluyen horarios pasados, medidos en la hora local de atencion (`AVAILABILITY_ZONE`, por defecto `America/Argentina/Mendoza`).

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

Errores: `400 INVALID_DATE_RANGE` (rango invertido o mayor al maximo), `404 PROFESSIONAL_NOT_FOUND`, `400 PROFESSIONAL_DISABLED` (profesional o categoria deshabilitados), `503 CATALOG_UNAVAILABLE`, `503 CATEDRA_UNAVAILABLE`. Un parametro faltante o de tipo equivocado es `400 BAD_REQUEST`.

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
  "canSubmitPhone": false,
  "createdAt": "2026-10-07T14:35:00Z",
  "updatedAt": "2026-10-07T14:35:10Z"
}
```

`status`: `HOLD_REQUESTED`, `HELD`, `WAITING_PHONE`, `PHONE_QUEUED`, `PHONE_SUBMITTED`, `CONFIRMED`, `EXPIRED`, `FAILED`, `CANCELLED`. `id` es el identificador local; `expiresAt` solo tiene sentido en estados no finales. `canSubmitPhone` es `true` cuando la reserva espera el teléfono (`WAITING_PHONE`) y la catedra ya lo pidio: es la señal para habilitar el formulario (ver la nota al final); la app compara `expiresAt` con la hora para saber si todavia hay tiempo. Nunca se expone el `user_id`.

### `POST /api/reservations`

```json
{ "professionalId": 15, "date": "2026-10-12", "startTime": "09:30" }
```

El backend valida con Catalogo (profesional habilitado, horario dentro de su agenda), pide el hold, lo confirma inicialmente y devuelve el proceso. El identificador sale del JWT. Nombre y apellido del paciente se piden a `GET /api/account` de Catalogo con el mismo JWT, **antes** del hold; si faltan, responde `PATIENT_NAME_REQUIRED` y no se crea nada.

Si se pierde la respuesta del hold o el hold vence antes de confirmarse, el backend reintenta con un hold nuevo hasta `RESERVATION_HOLD_MAX_ATTEMPTS` intentos (D85). Respuesta `201 Created`: `Reservation` normalmente en `WAITING_PHONE` (si la catedra aun no publico el pedido, el telefono se solicita igual: el SSE avisa cuando se puede enviar; ver nota).

Errores:

| HTTP | `code` | Cuando |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` | campos faltantes o formato invalido |
| 400 | `PATIENT_NAME_REQUIRED` | la cuenta no tiene nombre o apellido cargado (o tiene menos de 2 caracteres); la app pide los datos y reintenta |
| 400 | `INVALID_SLOT` | horario fuera de la agenda, o que ya paso |
| 400 | `PROFESSIONAL_DISABLED` | profesional deshabilitado |
| 404 | `PROFESSIONAL_NOT_FOUND` | profesional inexistente |
| 409 | `SLOT_UNAVAILABLE` | la catedra respondio `SLOT_ALREADY_HELD` o `SLOT_ALREADY_RESERVED`, o tras perder la respuesta del hold las ocupaciones muestran el horario ocupado |
| 409 | `RESERVATION_EXPIRED` | el hold vencio antes de confirmarse y no se consiguio otro dentro de los intentos |
| 503 | `CATALOG_UNAVAILABLE` / `CATEDRA_UNAVAILABLE` | dependencia caida |

### `POST /api/reservations/{id}/phone`

```json
{ "phoneNumber": "+5492615551234" }
```

Valida `^\+?[0-9]{7,15}$` (tras quitar espacios, guiones, parentesis y puntos): se acepta `+5492616159550`, `+542616159550`, `2616159550`, `(0261) 615-9550`, etc. El numero se guarda y envia **tal cual queda tras quitar los separadores**, sin completar el codigo de pais ni quitar el `0` o el `15` (`+549...` y `+54...` son numeros distintos). Un texto de mas de 40 caracteres tambien se rechaza. Solo en `WAITING_PHONE` (`canSubmitPhone`). Respuesta `202 Accepted`: `Reservation` en `PHONE_QUEUED`, con el telefono normalizado en `patientPhone`. El resultado final llega por SSE.

Errores: `400 VALIDATION_ERROR` (`fieldErrors` con `phoneNumber`), `404 RESERVATION_NOT_FOUND` (tambien ajena), `409 INVALID_RESERVATION_STATE` (incluye "todavia no llego el pedido de telefono" y un segundo envio con la reserva ya en `PHONE_QUEUED`), `409 RESERVATION_EXPIRED` (paso su `expiresAt`).

El estado y el mensaje a la catedra se guardan en una sola transaccion (outbox); un relay interno lo publica en Kafka, normalmente en menos de un segundo, y recien con el ack pasa a `PHONE_SUBMITTED`.

Si la catedra rechaza el telefono, la reserva vuelve a `WAITING_PHONE` y el usuario puede reintentar hasta `expiresAt`.

### `GET /api/reservations?status=CONFIRMED&page=0&size=20`

Lista **solo las reservas del usuario autenticado**. Filtro opcional `status` (un valor de `ReservationStatus`; otro da `400`). Orden fijo: fecha y hora del turno descendente (el `sort` del pedido se ignora). Con `X-Total-Count` y `Link` (`first`, `prev`, `next`, `last`, con el mismo filtro). `size` vale 20 por defecto y tiene un tope configurable (100 por defecto; un `size` mayor se reduce al tope).

**Intentos descartados:** sin `status` la lista no incluye las reservas `EXPIRED` ni `FAILED` (son intentos que no llegaron a ser una reserva). Con `status` se devuelven exactamente las de ese estado: `?status=FAILED` trae las `FAILED` y `?status=EXPIRED` las `EXPIRED`. Una `CANCELLED` aparece siempre.

### `GET /api/reservations/{id}`

Una reserva propia. `404 RESERVATION_NOT_FOUND` tambien para reservas ajenas: la respuesta es idéntica a la de una inexistente.

### `POST /api/reservations/{id}/cancel`

Body opcional: `{ "reason": "hasta 500 caracteres" }`. Solo reservas propias en `CONFIRMED`. `200 OK`: `Reservation` en `CANCELLED`. Cancelar una ya `CANCELLED` devuelve su estado actual (idempotente).

Errores: `404 RESERVATION_NOT_FOUND` (también ajena), `409 RESERVATION_NOT_CANCELLABLE` (la reserva no está `CONFIRMED`, o la cátedra no permite cancelarla), `503 CATEDRA_UNAVAILABLE`, `400 VALIDATION_ERROR` (motivo de más de 500 caracteres).

Orden: primero se cancela en la cátedra y recién entonces la reserva pasa a `CANCELLED`; si la cátedra falla no cambia nada y se puede repetir el pedido. Cancelar una reserva ya `CANCELLED` no llama a la cátedra y conserva el motivo original.

## Cambios en tiempo real (SSE)

### `GET /api/reservations/stream`

`Accept: text/event-stream`, con `Authorization: Bearer`. Solo emite eventos de reservas del usuario autenticado.

```
event: reservation-updated
id: 101-5
data: {"id":101,"status":"CONFIRMED","expiresAt":null,"canSubmitPhone":false,"updatedAt":"2026-10-07T14:36:01Z"}
```

- Se emite un `reservation-updated` en cada cambio de una reserva: de estado (rechazos, confirmacion, vencimiento y cancelacion) y tambien cuando llega el pedido de telefono, que deja la reserva en `WAITING_PHONE` pero pasa `canSubmitPhone` a `true` (por eso el `data` lo lleva: el estado es el mismo que en el aviso anterior).
- El `data` es un resumen (`id`, `status`, `expiresAt`, `canSubmitPhone`, `updatedAt`); `expiresAt` es `null` si la reserva ya termino, igual que en `Reservation`. Para el detalle completo la app llama a `GET /api/reservations/{id}`.
- El `id` del evento es `{id de la reserva}-{version}` y crece con cada cambio. **No hay historia ni `Last-Event-ID`**: un aviso perdido no se reenvia.
- El aviso sale despues de que el cambio quedo guardado: si la app consulta al recibirlo, lo ve. Un cambio que se deshace no avisa.
- Al conectar el servidor manda enseguida un comentario (`:ping`) para que el cliente reciba las cabeceras, y repite el comentario cada ~25 s (`STREAM_HEARTBEAT_INTERVAL`) para mantener viva la conexion. Un cliente que lo recibe como evento debe ignorarlo.
- **La app no depende del stream**: al conectar o reconectar consulta `GET /api/reservations` de procesos no finales y refresca. El stream es una optimizacion, no la fuente de verdad.
- Cada usuario puede tener hasta 5 conexiones abiertas a la vez (`STREAM_MAX_CONNECTIONS_PER_USER`); al abrir una mas, el servidor cierra la mas vieja.
- **JWT vencido:** el servidor cierra el stream en el primer latido posterior al `exp` del token. Una vez enviada la cabecera `200` no existe un `401` en esa conexion, asi que la app lo detecta porque el stream termina. Antes de reconectar tiene que renovar el token: el servidor tolera 60 s de desfase de reloj (valor por defecto de Spring), y con un token vencido hace menos que eso la conexion se acepta y se vuelve a cerrar en el siguiente latido; pasada la tolerancia la respuesta es `401`.
- Al apagar o reiniciar el servicio se cierran todos los streams; la app reconecta y reconsulta.

## Nota: pedido de telefono vs. respuesta del POST

La catedra publica `AdditionalInformationRequested` **despues** del `202` de confirm, de forma asincrona. Por eso `POST /api/reservations` puede devolver la reserva en `WAITING_PHONE` antes de tener guardado el `requestEventId`. Regla: `POST .../phone` responde `409 INVALID_RESERVATION_STATE` hasta recibir el pedido; la app solo habilita el formulario cuando el SSE (o una consulta) informa que se puede enviar. **Decidido (A8):** `Reservation.canSubmitPhone` (boolean). Vale `true` solo con la reserva en `WAITING_PHONE` y el pedido ya recibido; tambien vuelve a ser `true` si la catedra rechaza el numero y la reserva regresa a `WAITING_PHONE`.
