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

    C->>A: GET /api/synchronization/snapshot
    A-->>C: snapshotVersion + 3 colecciones
    C->>DB: BEGIN
    C->>DB: reemplazar categorias, profesionales y horarios
    C->>DB: version local = snapshotVersion
    C->>DB: COMMIT
```

Si algo falla antes del COMMIT, no cambia nada: ni datos ni version.

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
