# 02 - Sincronizacion del catalogo

Kafka es solo la **notificacion**; los datos salen de Redis o del snapshot REST.

## Decision: como se procesa una notificacion

```mermaid
flowchart TD
    A["Llega CatalogUpdated(newVersion, eventId)"] --> B{"eventId ya procesado?"}
    B -- si --> Z["Ignorar y commit de offset"]
    B -- no --> C["Leer metadata en Redis: currentVersion, oldestAvailableVersion"]
    C --> D{"Hay version local?"}
    D -- no --> S
    D -- si --> E{"localVersion == currentVersion?"}
    E -- si --> Z
    E -- no --> E2{"localVersion > currentVersion? (la catedra retrocedio)"}
    E2 -- si --> S
    E2 -- no --> F{"localVersion >= oldestAvailableVersion?"}
    F -- no --> S["Sincronizacion COMPLETA: GET snapshot"]
    F -- si --> G["Sincronizacion INCREMENTAL"]
    G --> H{"Fallo o falta changes:N?"}
    H -- si --> S
    H -- no --> I["Version local = currentVersion"]
    S --> I
    I --> Z
```

## Estado actual (CAT-10 y CAT-11): como procesa el servicio un evento

La decision usa la version **actual de Redis**, no la del evento: el evento solo dispara. Una version local mayor es un retroceso de la catedra (fuente de verdad) y se aplica el snapshot. Cualquier fallo de la incremental, o Redis caido, cae al snapshot. La deduplicacion es parte de la transaccion: en la incremental, el `eventId` se guarda con la **ultima** version.

```mermaid
flowchart TD
    A["Llega CatalogUpdated(newVersion, eventId)"] --> B{"JSON valido?"}
    B -- no --> X["Descartar con log de error y commit de offset"]
    B -- si --> C{"eventId ya procesado o localVersion == newVersion del evento?"}
    C -- si --> Z["Ignorar y commit de offset"]
    C -- no --> M["Leer metadata de Redis"]
    M -. Redis falla .-> S
    M --> D{"localVersion vs currentVersion de Redis"}
    D -- "igual" --> Z
    D -- "local = 0 (base vacia)" --> S
    D -- "local mayor (retroceso)" --> S
    D -- "local menor que oldestAvailable" --> S
    D -- "otro caso" --> I["Incremental: una transaccion por version (la ultima guarda el eventId)"]
    I -. falta historial, dato invalido o la base rechaza .-> S["GET snapshot y una transaccion: datos + version + eventId"]
    I --> Z
    S --> Z
    S -. falla .-> R["Reintentos con espera creciente; agotados: descartar con log"]
    R -. ok .-> S
    R -. se agotan .-> X
```

El offset se confirma siempre despues de resolver el mensaje (aplicado, ignorado o descartado), nunca antes del COMMIT.

## Incremental (version por version, en orden)

```mermaid
sequenceDiagram
    participant R as Redis catedra:sync
    participant C as Servicio Catalogo
    participant DB as BD catalogo

    loop v = local+1 .. current
        C->>R: GET changes:v
        C->>R: HMGET de los ids afectados de cada tipo (categorias, profesionales, horarios)
        C->>DB: BEGIN
        C->>DB: upsert de entidades (incluye deshabilitadas)
        C->>DB: version local = v
        C->>DB: COMMIT
    end
```

La version solo avanza dentro de la misma transaccion que aplica los cambios.

## Completa (snapshot)

```mermaid
sequenceDiagram
    participant A as API catedra
    participant C as Servicio Catalogo
    participant DB as BD catalogo

    Note over C: candado en memoria: una sincronizacion a la vez
    C->>A: GET /api/synchronization/snapshot
    A-->>C: snapshotVersion + 3 colecciones
    alt aplica bien
        C->>DB: BEGIN
        C->>DB: SELECT sync_state FOR UPDATE
        C->>DB: leer categorias, profesionales y horarios actuales
        C->>DB: INSERT o UPDATE solo lo nuevo o lo que cambio (categorias, profesionales, horarios)
        C->>DB: DELETE lo que ya no llega (horarios, profesionales, categorias)
        C->>DB: version local = snapshotVersion, last_status = OK
        C->>DB: COMMIT
    else falla la catedra o la transaccion
        Note over C,DB: si habia transaccion, ROLLBACK: ni datos ni version cambian
        C->>DB: BEGIN (transaccion aparte)
        C->>DB: last_status = ERROR, last_error
        C->>DB: COMMIT
    end
```

El pedido HTTP va **antes** de abrir la transaccion para no retener una conexion a la base mientras espera a la catedra. El candado en memoria envuelve todo, pedido incluido: la sincronizacion que espera pide despues su propio snapshot, ya fresco. El `FOR UPDATE` sobre `sync_state` serializa tambien a dos instancias del servicio.

Si algo falla antes del COMMIT, no cambia nada: ni datos ni version. El error se registra en otra transaccion (la de los datos ya se deshizo); si la base esta caida no hay donde registrarlo y `sync_state` conserva el estado anterior.

## Cuando se dispara

| Disparador | Accion |
| --- | --- |
| BD vacia al arrancar | Snapshot |
| `CatalogUpdated` | Flujo de decision de arriba |
| Arranque del servicio | Comparar version local con Redis (recupera notificaciones perdidas) |
| Chequeo periodico | Misma comparacion, por si Kafka perdio avisos |
| Estado que no se puede verificar | Snapshot |

## Decisiones abiertas

- **[decidir]** Frecuencia del chequeo periodico por comparacion de versiones.
- **[decidir]** Tabla de eventos procesados (`eventId` unico) y por cuanto tiempo se retiene.
- **[decidir]** Estado y errores de sincronizacion expuestos por REST (requisito 4.1).
