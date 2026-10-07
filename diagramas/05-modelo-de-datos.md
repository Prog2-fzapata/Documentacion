# 05 - Modelo de datos (propuesta)

Cada servicio tiene su **propia base logica** en PostgreSQL, con usuario propio y migraciones independientes. No hay claves foraneas entre ambas bases.

## Servicio Catalogo (`catalogo_db`)

```mermaid
erDiagram
    APP_USER ||--o{ USER_AUTHORITY : tiene
    AUTHORITY ||--o{ USER_AUTHORITY : asignada
    PROFESSIONAL_CATEGORY ||--o{ PROFESSIONAL : agrupa
    PROFESSIONAL ||--o{ WEEKLY_SCHEDULE : atiende

    APP_USER {
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
    AUTHORITY {
        string name PK
    }
    USER_AUTHORITY {
        bigint user_id FK
        string authority_name FK
    }
    PROFESSIONAL_CATEGORY {
        bigint id PK "id de catedra"
        string name
        string description
        boolean enabled
        timestamp created_at
        timestamp updated_at
    }
    PROFESSIONAL {
        bigint id PK "id de catedra"
        bigint category_id FK
        string first_name
        string last_name
        boolean enabled
        timestamp created_at
        timestamp updated_at
    }
    WEEKLY_SCHEDULE {
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
    PROCESSED_EVENT {
        string event_id PK
        string event_type
        timestamp processed_at
    }
```

Notas:

- Las entidades del catalogo conservan el **ID de la catedra** como clave primaria (no se generan IDs propios), para poder aplicar cambios por ID.
- Las bajas de la catedra son logicas (`enabled = false`): se guardan, no se borran.
- `SYNC_STATE.local_version` solo se actualiza en la misma transaccion que aplica los datos.
- `APP_USER` y `AUTHORITY` replican el modelo de usuario de JHipster (requisito de compatibilidad del enunciado).
- `SYNC_STATE` cubre "informar estado y errores de sincronizacion" (4.1).

## Servicio Turnos (`turnos_db`)

```mermaid
erDiagram
    RESERVATION_PROCESS ||--o{ OUTBOX : genera

    RESERVATION_PROCESS {
        bigint id PK
        string reservation_process_id UK "id de catedra"
        string hold_id "id de catedra"
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
        string patient_phone
        string request_event_id "para responder el telefono"
        bigint reservation_id "id de catedra al confirmar"
        string failure_reason
        string cancellation_reason
        timestamp cancelled_at
        timestamp created_at
        timestamp updated_at
        bigint version "bloqueo optimista"
    }
    OUTBOX {
        bigint id PK
        string event_id UK
        string reservation_process_id FK
        string topic
        string message_key
        text payload
        string status "PENDING o SENT"
        int attempts
        timestamp created_at
        timestamp sent_at
    }
    PROCESSED_EVENT {
        string event_id PK
        string event_type
        timestamp processed_at
    }
```

Notas:

- `user_id` identifica al dueño de la reserva. Viene del JWT (no del cliente) y se envia a la catedra como `externalPatientId`. Toda consulta y cancelacion filtra por este campo.
- `professional_id` y los nombres son **datos descriptivos historicos**: sirven para mostrar la reserva, no como catalogo vigente (el enunciado lo permite y lo restringe).
- `status`: `HOLD_REQUESTED`, `HELD`, `WAITING_PHONE`, `PHONE_QUEUED`, `PHONE_SUBMITTED`, `CONFIRMED`, `EXPIRED`, `FAILED`, `CANCELLED` (ver [04](04-maquina-estados-reserva.md)).
- `version` evita que dos eventos concurrentes (REST y Kafka) pisen el mismo proceso.
- `reservation_process_id` es unico: garantiza que no haya reservas duplicadas para el mismo proceso.
- `OUTBOX` y `PROCESSED_EVENT` son tecnicas, no del dominio.

## Fronteras de propiedad

```mermaid
flowchart LR
    subgraph CAT["catalogo_db"]
        P["PROFESSIONAL"]
        U["APP_USER"]
    end
    subgraph TUR["turnos_db"]
        R["RESERVATION_PROCESS"]
    end
    R -. "professional_id (solo valor, sin FK)" .-> P
    R -. "user_id (viene del JWT, sin FK)" .-> U
```

Las lineas punteadas son referencias **por valor**. El servicio de turnos nunca consulta la base de catalogo: pide la agenda por REST. Esto respeta la regla de "no acceder a tablas del otro servicio".

## Decisiones

- **Identificador del usuario:** el `id` numerico de `APP_USER`, incluido como claim en el JWT y enviado como texto en `externalPatientId`. Es inmutable, a diferencia de cualquier dato editable, y la catedra asocia las reservas a ese valor.
- **Telefono:** se conserva en `RESERVATION_PROCESS.patient_phone` (la catedra tambien lo devuelve en el listado).
- **Indices:** por `user_id`, por `status` + `expires_at` (job de recuperacion) y por `status` en `OUTBOX`.
