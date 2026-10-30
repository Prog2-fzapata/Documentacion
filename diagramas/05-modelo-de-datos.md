# 05 - Modelo de datos (propuesta)

Cada servicio tiene su **propia base logica** en PostgreSQL, con usuario propio y migraciones independientes. No hay claves foraneas entre ambas bases.

## Servicio Catalogo (`catalogo_db`)

```mermaid
erDiagram
    USERS ||--o{ USER_AUTHORITIES : tiene
    AUTHORITIES ||--o{ USER_AUTHORITIES : asignada
    PROFESSIONAL_CATEGORIES ||--o{ PROFESSIONALS : agrupa
    PROFESSIONALS ||--o{ WEEKLY_SCHEDULES : atiende

    USERS {
        bigint id PK
        string login UK
        string password_hash
        string first_name
        string last_name
        string email UK
        string image_url "opcional"
        string lang_key
        boolean activated
        timestamp created_date
        timestamp last_modified_date
    }
    AUTHORITIES {
        string name PK
    }
    USER_AUTHORITIES {
        bigint user_id FK
        string authority_name FK
    }
    PROFESSIONAL_CATEGORIES {
        bigint id PK "id de catedra"
        string name
        string description
        boolean enabled
        timestamp created_at
        timestamp updated_at
    }
    PROFESSIONALS {
        bigint id PK "id de catedra"
        bigint category_id FK
        string first_name
        string last_name
        boolean enabled
        timestamp created_at
        timestamp updated_at
    }
    WEEKLY_SCHEDULES {
        bigint id PK "id de catedra"
        bigint professional_id FK
        string day_of_week
        time start_time
        time end_time
        int slot_duration_minutes
        boolean enabled
        timestamp created_at
        timestamp updated_at
    }
    SYNC_STATE {
        int id PK "una sola fila"
        bigint local_version
        timestamp last_sync_at
        string last_sync_type "FULL o INCREMENTAL"
        string last_status "OK o ERROR"
        string last_error
    }
    PROCESSED_EVENTS {
        string event_id PK
        string event_type
        timestamp processed_at
    }
```

Notas:

- Las entidades del catalogo conservan el **ID de la catedra** como clave primaria (no se generan IDs propios), para poder aplicar cambios por ID.
- Las bajas de la catedra son logicas (`enabled = false`): se guardan, no se borran.
- `SYNC_STATE.local_version` solo se actualiza en la misma transaccion que aplica los datos.
- `USERS` y `AUTHORITIES` replican el modelo de usuario de JHipster (requisito de compatibilidad del enunciado).
- `SYNC_STATE` cubre "informar estado y errores de sincronizacion" (4.1). La migracion crea su unica fila (`id = 1`, `local_version = 0`).
- Los nombres de las tablas van en plural (convencion de la catedra); `SYNC_STATE` queda en singular por ser una sola fila. Las tablas de turnos se nombraron igual al implementar TUR-04 (`reservation_processes`, `outbox_events`, `processed_events`).

## Servicio Turnos (`turnos_db`)

```mermaid
erDiagram
    RESERVATION_PROCESSES ||--o{ OUTBOX_EVENTS : genera

    RESERVATION_PROCESSES {
        bigint id PK "generado por la base"
        string reservation_process_id UK "id de catedra, NULL hasta el hold"
        string hold_id "id de catedra, NULL hasta el hold"
        string user_id "id del usuario final, sin FK"
        bigint professional_id "referencia a catalogo, sin FK"
        string professional_first_name "dato historico"
        string professional_last_name "dato historico"
        date appointment_date
        time start_time
        time end_time
        string status
        timestamp expires_at
        string patient_first_name
        string patient_last_name
        string patient_phone "opcional"
        string request_event_id "para responder el telefono"
        bigint reservation_id "id de catedra al confirmar"
        string failure_reason
        string cancellation_reason
        timestamp cancelled_at
        timestamp created_at
        timestamp updated_at
        bigint version "bloqueo optimista"
    }
    OUTBOX_EVENTS {
        bigint id PK
        string event_id UK
        string reservation_process_id FK "al id de catedra"
        string topic
        string message_key
        text payload
        string status "PENDING o SENT"
        int attempts
        timestamp created_at
        timestamp sent_at
    }
    PROCESSED_EVENTS {
        string event_id PK
        string event_type
        timestamp processed_at
    }
```

Implementado en la migracion `V1` de turnos (TUR-04, ver D78). Notas:

- `reservation_process_id` y `hold_id` aceptan `NULL`: el proceso local se crea en `HOLD_REQUESTED` antes de llamar a la catedra. El `UNIQUE` evita duplicados igual (PostgreSQL permite varios `NULL`).
- `user_id` identifica al dueño de la reserva. Viene del JWT (no del cliente) y se envia a la catedra como `externalPatientId`. Toda consulta y cancelacion filtra por este campo.
- `professional_id` y los nombres son **datos descriptivos historicos**: sirven para mostrar la reserva, no como catalogo vigente (el enunciado lo permite y lo restringe).
- `status`: `HOLD_REQUESTED`, `HELD`, `WAITING_PHONE`, `PHONE_QUEUED`, `PHONE_SUBMITTED`, `CONFIRMED`, `EXPIRED`, `FAILED`, `CANCELLED` (ver [04](04-maquina-estados-reserva.md)).
- `version` evita que dos eventos concurrentes (REST y Kafka) pisen el mismo proceso.
- `reservation_process_id` es unico: garantiza que no haya reservas duplicadas para el mismo proceso.
- `OUTBOX_EVENTS` y `PROCESSED_EVENTS` son tecnicas, no del dominio.
- `status` tiene un `CHECK` con los nueve estados: un estado nuevo exige una migracion.

## Fronteras de propiedad

```mermaid
flowchart LR
    subgraph CAT["catalogo_db"]
        P["PROFESSIONALS"]
        U["USERS"]
    end
    subgraph TUR["turnos_db"]
        R["RESERVATION_PROCESSES"]
    end
    R -. "professional_id (solo valor, sin FK)" .-> P
    R -. "user_id (viene del JWT, sin FK)" .-> U
```

Las lineas punteadas son referencias **por valor**. El servicio de turnos nunca consulta la base de catalogo: pide la agenda por REST. Esto respeta la regla de "no acceder a tablas del otro servicio".

## Decisiones

- **Identificador del usuario:** el `id` numerico de `USERS`, incluido como claim en el JWT y enviado como texto en `externalPatientId`. Es inmutable, a diferencia de cualquier dato editable, y la catedra asocia las reservas a ese valor.
- **Telefono:** se conserva en `RESERVATION_PROCESSES.patient_phone` (la catedra tambien lo devuelve en el listado).
- **Indices:** por `user_id`, por `status` + `expires_at` (job de recuperacion), por la clave foranea del outbox y uno **parcial** sobre `created_at` solo para las filas `PENDING` de `OUTBOX_EVENTS` (es lo unico que lee el relay).
