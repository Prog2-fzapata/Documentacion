# 03 - Flujo de reserva

## Disponibilidad (solo lectura)

```mermaid
sequenceDiagram
    actor U as Usuario
    participant K as App KMP
    participant T as Servicio Turnos
    participant C as Servicio Catalogo
    participant A as API catedra

    U->>K: elige profesional
    K->>T: GET disponibilidad(profesional, desde, hasta)
    T->>C: agenda vigente del profesional
    C-->>T: profesional + horarios semanales
    T->>A: GET appointment-occupancies
    A-->>T: CONFIRMED y HELD
    T->>T: slots de los horarios - ocupaciones, ordenados por fecha/hora
    T-->>K: turnos disponibles
```

La disponibilidad es una foto: puede quedar vieja. El veredicto real lo da el `POST` del hold.

## Reserva completa

```mermaid
sequenceDiagram
    actor U as Usuario
    participant K as App KMP
    participant T as Servicio Turnos
    participant C as Servicio Catalogo
    participant A as API catedra
    participant KA as Kafka acciones
    participant KP as Kafka telefono

    U->>K: selecciona horario
    K->>T: POST iniciar reserva
    T->>C: validar profesional habilitado y horario en agenda
    C-->>T: ok
    T->>T: crea proceso local (usuario, slot) en HOLD_REQUESTED
    T->>A: POST appointment-holds (externalPatientId = id usuario)
    alt slot ocupado
        A-->>T: 409 SLOT_ALREADY_HELD / RESERVED
        T-->>K: horario no disponible
    else hold creado
        A-->>T: 201 holdId, reservationProcessId, expiresAt
        T->>T: guarda ids y expiresAt, estado HELD
        T->>A: POST holds/{id}/confirm (nombre, apellido)
        A-->>T: 202 WAITING_FOR_PHONE
        T->>T: estado WAITING_PHONE
        A-->>KA: AdditionalInformationRequested
        KA-->>T: consume y guarda eventId como requestEventId
        T-->>K: (SSE) se necesita telefono
        U->>K: ingresa telefono
        K->>T: POST telefono
        T->>KP: AdditionalInformationSubmitted (key = processId)
        T->>T: estado PHONE_SUBMITTED
        A-->>KA: resultado final
        KA-->>T: consume
        T-->>K: (SSE) estado final
    end
```

## Resultados finales posibles (Kafka, topic acciones)

```mermaid
flowchart LR
    P["PHONE_SUBMITTED"] --> E1["AppointmentConfirmed"] --> R1["CONFIRMED"]
    P --> E2["AdditionalInformationRejected"] --> R2["vuelve a WAITING_PHONE (hasta expiresAt)"]
    P --> E3["AppointmentProcessExpired"] --> R3["EXPIRED"]
    P --> E4["AppointmentProcessInvalid"] --> R4["FAILED + reconciliar por REST"]
```

## Consulta y cancelacion

```mermaid
sequenceDiagram
    actor U as Usuario
    participant K as App KMP
    participant T as Servicio Turnos
    participant A as API catedra

    U->>K: Mis reservas
    K->>T: GET reservas (JWT usuario)
    T->>T: filtra por usuario autenticado
    T-->>K: solo reservas propias

    U->>K: cancelar
    K->>T: POST cancelar(id)
    T->>T: verifica que la reserva es del usuario y esta CONFIRMED
    T->>A: POST appointments/{processId}/cancel
    A-->>T: 200 CANCELLED
    T->>T: estado CANCELLED
    T-->>K: ok
```

## Decisiones abiertas

- **Decidido:** la app se entera por SSE (ver [decisiones.md](../decisiones.md), D5). Al reconectar consulta el estado actual por REST.
- **[decidir]** Que hace el backend si la app nunca envia el telefono (el proceso vence por `expiresAt`).
- **[decidir]** Reintentos y timeouts hacia la API; ante timeout se reconcilia antes de repetir.
