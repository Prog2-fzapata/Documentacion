# 04 - Maquina de estados de la reserva (propuesta)

```mermaid
stateDiagram-v2
    [*] --> HOLD_REQUESTED: usuario elige horario
    HOLD_REQUESTED --> HELD: 201 hold creado
    HOLD_REQUESTED --> FAILED: 409 / 400 / 404

    HELD --> WAITING_PHONE: 202 confirm
    HELD --> EXPIRED: HOLD_EXPIRED / expiresAt vencido
    HELD --> FAILED: error no recuperable

    WAITING_PHONE --> PHONE_QUEUED: app envia telefono (estado + outbox en una transaccion)
    WAITING_PHONE --> EXPIRED: AppointmentProcessExpired / expiresAt
    WAITING_PHONE --> FAILED: AppointmentProcessInvalid

    PHONE_QUEUED --> PHONE_SUBMITTED: relay publica en Kafka y marca SENT
    PHONE_QUEUED --> EXPIRED: vence antes de poder enviarse
    PHONE_QUEUED --> FAILED: AppointmentProcessInvalid

    PHONE_SUBMITTED --> CONFIRMED: AppointmentConfirmed
    PHONE_SUBMITTED --> WAITING_PHONE: AdditionalInformationRejected
    PHONE_SUBMITTED --> EXPIRED: AppointmentProcessExpired
    PHONE_SUBMITTED --> FAILED: AppointmentProcessInvalid

    CONFIRMED --> CANCELLED: cancelacion propia / AppointmentCancelled

    EXPIRED --> [*]
    FAILED --> [*]
    CANCELLED --> [*]
```

## Reglas

- **Estados finales:** `EXPIRED`, `FAILED`, `CANCELLED`. Un evento tardio o duplicado no los reabre.
- `CONFIRMED` solo puede pasar a `CANCELLED`.
- El relay del outbox al confirmar el ack solo marca la fila como `SENT`; el estado de la reserva pasa a `PHONE_SUBMITTED` unicamente si sigue en `PHONE_QUEUED`. Si `AppointmentConfirmed` llego antes, el estado se mantiene.
- Una transicion invalida para el estado actual se ignora y se registra (no se rompe ni se retrocede).
- REST y Kafka pueden contar la misma cosa en momentos distintos: se avanza solo hacia adelante y gana el estado mas avanzado. `AppointmentConfirmed` puede llegar antes de que REST lo refleje.
- Cada proceso guarda: usuario dueño, `reservationProcessId`, `holdId`, `requestEventId`, `expiresAt`, datos del slot y datos descriptivos historicos del profesional.

## Idempotencia

```mermaid
flowchart TD
    A["Evento Kafka"] --> B{"eventId en tabla de procesados?"}
    B -- si --> Z["Ignorar, commit de offset"]
    B -- no --> C{"Estado actual es final?"}
    C -- si --> D["Registrar eventId, ignorar efecto, commit"]
    C -- no --> E["Aplicar transicion + registrar eventId (misma transaccion)"]
    E --> F["Commit de offset"]
```

## Decisiones abiertas

- **[decidir]** Si el mensaje del telefono se publica directo o via tabla outbox (garantiza que no se pierda ante una caida entre guardar estado y publicar).
- **[decidir]** Job de recuperacion al arrancar: procesos no finales con `expiresAt` vencido pasan a `EXPIRED`; los dudosos se reconcilian con `GET /api/appointments`.
