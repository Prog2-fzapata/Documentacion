# 06 - Casos de uso

En arquitectura hexagonal cada caso de uso es una interfaz en `domain/ports/in` (una por caso). Este documento es el **catalogo de esos puertos de entrada** y de quien los invoca (adaptador de entrada: controller, listener Kafka o tarea programada).

Slices propuestos: `usuario` y `catalogo` en el servicio de catalogo; `disponibilidad` y `reserva` en el servicio de turnos.

## Servicio Catalogo

```mermaid
flowchart LR
    U(["Usuario final"])
    T(["Servicio Turnos"])
    K(["Kafka catedra.catalog"])
    S(["Tarea programada / arranque"])

    subgraph usuario["slice usuario"]
        UC1(["Registrar usuario"])
        UC2(["Autenticar usuario"])
        UC3(["Consultar cuenta actual"])
    end
    subgraph catalogo["slice catalogo"]
        UC4(["Buscar profesionales"])
        UC5(["Consultar profesional y agenda"])
        UC6(["Listar categorias"])
        UC7(["Consultar estado de sincronizacion"])
        UC8(["Procesar CatalogUpdated"])
        UC9(["Sincronizar incrementalmente"])
        UC10(["Sincronizar completo (snapshot)"])
        UC11(["Verificar version del catalogo"])
    end

    U --> UC1 & UC2 & UC3 & UC4 & UC5 & UC6 & UC7
    T --> UC5
    K --> UC8
    S --> UC11
    UC8 -. incluye .-> UC9
    UC11 -. incluye .-> UC9
    UC9 -. "si no puede continuar" .-> UC10
```

## Servicio Turnos

```mermaid
flowchart LR
    U(["Usuario final"])
    K(["Kafka acciones"])
    S(["Tareas programadas / arranque"])

    subgraph disponibilidad["slice disponibilidad"]
        A1(["Consultar disponibilidad"])
    end
    subgraph reserva["slice reserva"]
        R1(["Iniciar reserva (hold + confirm)"])
        R2(["Enviar telefono"])
        R3(["Listar mis reservas"])
        R4(["Consultar mi reserva"])
        R5(["Cancelar mi reserva"])
        R6(["Suscribirse a cambios (SSE)"])
        E1(["Procesar AdditionalInformationRequested"])
        E2(["Procesar AppointmentConfirmed"])
        E3(["Procesar AdditionalInformationRejected"])
        E4(["Procesar ProcessExpired / ProcessInvalid"])
        E5(["Procesar AppointmentCancelled"])
        J1(["Publicar mensajes pendientes (outbox)"])
        J2(["Recuperar procesos al arrancar"])
        J3(["Expirar procesos vencidos"])
    end

    U --> A1 & R1 & R2 & R3 & R4 & R5 & R6
    K --> E1 & E2 & E3 & E4 & E5
    S --> J1 & J2 & J3
    R1 -. incluye .-> A1
```

`R1` incluye una validacion contra el servicio de catalogo (agenda vigente) antes de pedir el hold; `A1` tambien la usa.

## Catalogo de puertos de entrada (nombres propuestos)

### usuario

| Caso de uso | Puerto `in` | Adaptador de entrada |
| --- | --- | --- |
| Registrar usuario | `RegisterUserUseCase` | `POST /api/register` |
| Autenticar usuario | `AuthenticateUserUseCase` | `POST /api/authenticate` |
| Consultar cuenta actual | `GetCurrentUserUseCase` | `GET /api/account` |

### catalogo

| Caso de uso | Puerto `in` | Adaptador de entrada |
| --- | --- | --- |
| Buscar profesionales | `SearchProfessionalsUseCase` | `GET /api/professionals` |
| Consultar profesional y agenda | `GetProfessionalByIdUseCase` | `GET /api/professionals/{id}` |
| Listar categorias | `GetAllCategoriesUseCase` | `GET /api/professional-categories` |
| Consultar estado de sincronizacion | `GetSyncStatusUseCase` | `GET /api/sync/status` |
| Procesar CatalogUpdated | `HandleCatalogUpdatedUseCase` | `@KafkaListener` |
| Sincronizar incrementalmente | `IncrementalSyncUseCase` | invocado por los dos anteriores |
| Sincronizar completo | `FullSyncUseCase` | invocado por los anteriores |
| Verificar version del catalogo | `CheckCatalogVersionUseCase` | `@Scheduled` y arranque |

### disponibilidad

| Caso de uso | Puerto `in` | Adaptador de entrada |
| --- | --- | --- |
| Consultar disponibilidad | `GetAvailabilityUseCase` | `GET /api/availability` |

### reserva

| Caso de uso | Puerto `in` | Adaptador de entrada |
| --- | --- | --- |
| Iniciar reserva | `StartReservationUseCase` | `POST /api/reservations` |
| Enviar telefono | `SubmitPhoneUseCase` | `POST /api/reservations/{id}/phone` |
| Listar mis reservas | `GetAllReservationsUseCase` | `GET /api/reservations` |
| Consultar mi reserva | `GetReservationByIdUseCase` | `GET /api/reservations/{id}` |
| Cancelar mi reserva | `CancelReservationUseCase` | `POST /api/reservations/{id}/cancel` |
| Suscribirse a cambios | `SubscribeReservationEventsUseCase` | `GET /api/reservations/stream` (SSE) |
| Procesar eventos de la catedra | `HandleAdditionalInformationRequestedUseCase`, `HandleAppointmentConfirmedUseCase`, `HandleAdditionalInformationRejectedUseCase`, `HandleProcessClosedUseCase`, `HandleAppointmentCancelledUseCase` | `@KafkaListener` |
| Publicar mensajes pendientes | `PublishPendingMessagesUseCase` | `@Scheduled` |
| Recuperar procesos al arrancar | `RecoverReservationsUseCase` | `ApplicationReadyEvent` |
| Expirar procesos vencidos | `ExpireOverdueReservationsUseCase` | `@Scheduled` |

## Notas de diseño

- Los eventos de la catedra que llegan por Kafka son **casos de uso como cualquier otro**; el listener solo los traduce a un objeto de dominio y llama al puerto. Asi se pueden probar sin Kafka.
- Los casos de uso de eventos aplican idempotencia (`processed_event`) y las transiciones de la maquina de estados ([04](04-maquina-estados-reserva.md)).
- `HandleProcessClosedUseCase` agrupa `AppointmentProcessExpired` y `AppointmentProcessInvalid`: ambos cierran el proceso con distinto estado final.
- Los puertos `out` (repositorios, cliente de la catedra, Redis, publisher Kafka, cliente de catalogo) se definen al implementar cada slice.
