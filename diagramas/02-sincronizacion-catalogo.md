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
    D -- si --> E{"localVersion >= currentVersion?"}
    E -- si --> Z
    E -- no --> F{"localVersion + 1 >= oldestAvailableVersion?"}
    F -- no --> S["Sincronizacion COMPLETA: GET snapshot"]
    F -- si --> G["Sincronizacion INCREMENTAL"]
    G --> H{"Fallo o falta changes:N?"}
    H -- si --> S
    H -- no --> I["Version local = currentVersion"]
    S --> I
    I --> Z
```

## Incremental (version por version, en orden)

```mermaid
sequenceDiagram
    participant R as Redis catedra:sync
    participant C as Servicio Catalogo
    participant DB as BD catalogo

    loop v = local+1 .. current
        C->>R: GET changes:v
        C->>R: HGET de cada ID afectado (categorias, profesionales, horarios)
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
