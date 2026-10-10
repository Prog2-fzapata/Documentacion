# Planificacion: milestones e issues

Borrador para cargar en GitHub. Criterio: **milestones por entrega vertical**, cada uno deja algo demostrable. Los milestones se crean con el mismo nombre en los cuatro repos y cada issue pertenece al repo donde se implementa. Entrega final: ultimos dias de noviembre 2026 (fecha exacta pendiente de la catedra). Las fechas son **tentativas** y deben ajustarse a las reuniones quincenales con el profesor.

Los codigos (`CAT-01`, `TUR-01`, `KMP-01`, `DOC-01`) son solo para referenciar dependencias aqui; GitHub asignara sus propios numeros.

## Milestones

| Milestone | Objetivo demostrable | Fecha tentativa |
| --- | --- | --- |
| **M1 - Base e infraestructura** | Los dos servicios y las bases levantan con Docker Compose; cuenta tecnica registrada; esqueletos hexagonales | 14 oct |
| **M2 - Usuarios y seguridad** | Registro y login desde la app; JWT validado en ambos servicios; accesos no autenticados rechazados | 21 oct |
| **M3 - Catalogo y sincronizacion** | Snapshot, incremental por Kafka+Redis, recuperacion; busqueda con filtros en la app | 4 nov |
| **M4 - Disponibilidad** | La app muestra turnos libres de un profesional | 11 nov |
| **M5 - Reserva** | Reserva completa REST+Kafka, SSE, consulta y cancelacion propias | 18 nov |
| **M6 - Robustez y pruebas** | Duplicados, vencimientos, reinicios, recuperacion; pruebas backend obligatorias | 22 nov |
| **M7 - Documentacion y entrega** | README, diagramas finales, evidencias, ensayo de defensa | 25 nov |

## Etiquetas (labels)

Solo las que GitHub trae por defecto, sin etiquetas propias: `enhancement` (funcionalidad nueva), `bug` y `documentation`.

## Flujo de trabajo (propuesta)

- Un issue por rama: `feat/<codigo>-descripcion-corta` desde `develop`. Commits en Conventional Commits, breves; el PR referencia el issue (`Closes #n`).
- `develop` integra y `main` es lo estable. `testing` se usara segun el issue, si hace falta (ver A11 en [decisiones.md](decisiones.md)).
- Nada se pushea sin aprobacion explicita.

---

## Repo `Documentacion`

Los entregables del §12 del enunciado (README, arquitectura, modelo de datos, sincronización, idempotencia, seguridad, evidencias) viven en cada repo de servicio y se escriben al implementar (ver D31 en decisiones.md). Los issues `DOC-03` a `DOC-06` se movieron allí. Quedan sin issue propio, para crear cuando corresponda: modelo de datos, contrato entre los dos servicios y resumen de decisiones de diseño.

| Codigo | Issue | Milestone | Criterio de aceptacion |
| --- | --- | --- | --- |
| DOC-01 | Docker Compose con Postgres | M1 | **Reemplazado**: el compose vive en cada repo de servicio con su propio Postgres (ver CAT-02 y TUR-02) |
| DOC-02 | Registrar cuenta tecnica en la catedra (Postman) | M1 | Coleccion Postman en el repo **sin secretos**; `.env.example` con todas las claves; JWT y config guardados fuera de git |
| DOC-03 | Estrategia de sincronizacion e idempotencia (texto) | M6 | **Movido** a los repos de servicio: `ServicioCatalogo#22` y `#23`, `ServicioTurnos#24` |
| DOC-04 | Seguridad: decisiones y limitaciones | M6 | **Movido**: `ServicioCatalogo#24` y `ServicioTurnos#25` |
| DOC-05 | README final y diagrama de arquitectura | M7 | **Movido**: `ServicioCatalogo#25` y `ServicioTurnos#26` |
| DOC-06 | Evidencias minimas (§11) | M7 | **Movido**: `ServicioCatalogo#26` y `ServicioTurnos#27` |

## Repo `ServicioCatalogo`

| Codigo | Issue | Milestone | Criterio de aceptacion |
| --- | --- | --- | --- |
| CAT-01 | Proyecto Spring Boot base y estructura hexagonal | M1 | Esqueleto con la skill `hexagonal`; Flyway; configuracion por variables de entorno; arranca contra `catalogo_db` |
| CAT-02 | Dockerfile y configuracion del servicio | M1 | Dockerfile multi-stage; `docker-compose.yml` propio con su PostgreSQL y `.env.example`; se levanta con `docker compose up -d --build`; sin secretos en el repo |
| CAT-03 | Slice `usuario`: registro | M2 | `POST /api/register` segun contrato; hash BCrypt; usuario activo; validaciones; tests |
| CAT-04 | Slice `usuario`: autenticacion y emision del JWT | M2 | `POST /api/authenticate`, `GET /api/account`; claims `sub`, `uid`, `auth`, nombres; 401 en credenciales invalidas; tests |
| CAT-05 | Seguridad: filtro JWT, endpoints publicos y CORS | M2 | Todo protegido salvo registro y login; CORS por variable de entorno; tests de rechazo |
| CAT-06 | Modelo del catalogo y migraciones | M3 | Tablas de categoria, profesional, horario, `sync_state`, `processed_event` segun [05](diagramas/05-modelo-de-datos.md) |
| CAT-07 | Cliente de la catedra: snapshot REST con JWT tecnico | M3 | Puerto `out` + adapter; timeout configurable; errores traducidos; JWT tecnico solo por entorno |
| CAT-08 | Sincronizacion completa (snapshot) | M3 | Reemplazo atomico de las 3 colecciones y de la version en una transaccion; falla = no cambia nada; tests |
| CAT-09 | Cliente Redis: metadata, versiones, entidades y cambios | M3 | Lectura de `catedra:sync:*` segun anexo §14; usuario y password por entorno |
| CAT-10 | Sincronizacion incremental | M3 | Aplica version por version en orden; la version avanza en la misma transaccion; si falta historial, cae a snapshot; tests |
| CAT-11 | Consumer Kafka de `CatalogUpdated` con deduplicacion | M3 | `eventId` en `processed_event` en la misma transaccion; commit de offset despues; duplicado no cambia el resultado; tests |
| CAT-12 | Verificacion de version al arrancar y periodica | M3 | Recupera notificaciones perdidas; base vacia dispara snapshot |
| CAT-13 | Busqueda de profesionales con filtros | M3 | Categoria, nombre, habilitado y disponibilidad sobre datos locales; paginacion; tests |
| CAT-14 | Consulta de profesional y categorias | M3 | `GET /api/professionals/{id}` (agenda vigente) y `GET /api/professional-categories` |
| CAT-15 | Estado de sincronizacion | M3 | `GET /api/sync/status`; errores registrados sin datos sensibles |
| CAT-16 | Pruebas de integracion de sincronizacion | M6 | Snapshot inicial, incremental, discontinuidad, duplicado (Testcontainers o equivalente) |
| CAT-17 | Logs y observabilidad basica | M6 | Sin secretos ni passwords en logs; trazas de sincronizacion |

## Repo `ServicioTurnos`

| Codigo | Issue | Milestone | Criterio de aceptacion |
| --- | --- | --- | --- |
| TUR-01 | Proyecto Spring Boot base y estructura hexagonal | M1 | Igual que CAT-01 contra `turnos_db` |
| TUR-02 | Dockerfile y configuracion del servicio | M1 | Igual que CAT-02 |
| TUR-03 | Seguridad: validacion del JWT emitido por catalogo | M2 | Valida firma, vigencia y autoridades; 401/403; `uid` solo desde el JWT; A3 resuelto; tests |
| TUR-04 | Modelo de datos y migraciones | M2 | `reservation_process`, `outbox`, `processed_event` e indices segun [05](diagramas/05-modelo-de-datos.md) |
| TUR-05 | Cliente de catalogo con propagacion del JWT | M4 | Puerto `out` + adapter; timeout y reintentos limitados; 5xx o timeout = `CATALOG_UNAVAILABLE` |
| TUR-06 | Cliente de la catedra: ocupaciones, holds, confirm, listado y cancelacion | M4 | Un adapter con JWT tecnico por entorno; traduccion de errores del anexo §13; timeouts y reintentos limitados |
| TUR-07 | Disponibilidad | M4 | `GET /api/availability`: slots de la agenda menos ocupaciones, ordenados, sin horarios pasados; tests |
| TUR-08 | Iniciar reserva | M5 | Valida con catalogo, hold, confirm; estados `HOLD_REQUESTED` a `WAITING_PHONE`; `409 SLOT_UNAVAILABLE`; ownership; tests |
| TUR-09 | Maquina de estados de la reserva | M5 | Transiciones segun [04](diagramas/04-maquina-estados-reserva.md); estados finales inmutables; bloqueo optimista; tests unitarios |
| TUR-10 | Consumer Kafka de eventos de la catedra con deduplicacion | M5 | Cinco eventos procesados por casos de uso; `eventId` idempotente; no retrocede estados finales |
| TUR-11 | Enviar telefono con outbox | M5 | `POST .../phone`; `PHONE_QUEUED` + outbox en una transaccion; relay publica con `requestEventId` y `enable.idempotence`; `PHONE_SUBMITTED` al confirmar el ack |
| TUR-12 | Consultar y cancelar reservas propias | M5 | Aislamiento por usuario (404 en ajenas); cancelacion idempotente; tests de acceso cruzado |
| TUR-13 | SSE de cambios de reserva | M5 | `GET /api/reservations/stream` autenticado, solo eventos propios, latido; no es fuente de verdad |
| TUR-14 | Vencimiento de procesos | M6 | Tarea que expira procesos vencidos; evento `ProcessExpired` tambien cierra; tests |
| TUR-15 | Recuperacion al arrancar | M6 | Reconciliacion con `GET /api/appointments` de procesos dudosos; `HOLD_REQUESTED` sin ids pasa a `FAILED`; tests |
| TUR-16 | Reintentos, timeouts y degradacion | M6 | Politica documentada; sin bucles ilimitados; con catalogo caido no se inician reservas pero se atienden consultas propias |
| TUR-17 | Pruebas de integracion del flujo de reserva | M6 | Confirmada, rechazada y reintentada, vencida, duplicado, acceso cruzado entre usuarios |
| TUR-18 | Logs y observabilidad basica | M6 | Sin JWT, passwords ni telefonos completos en logs |

## Repo `KMP`

| Codigo | Issue | Milestone | Criterio de aceptacion |
| --- | --- | --- | --- |
| KMP-01 | Proyecto KMP Android base | M1 | Compila y ejecuta; modulo `shared`; configuracion de URLs por build; sin secretos |
| KMP-02 | Cliente HTTP, almacenamiento seguro del JWT y manejo de errores | M2 | Ktor con `Authorization`; token en almacenamiento seguro; mapeo de `code` a mensajes |
| KMP-03 | Pantallas de registro e inicio de sesion | M2 | Registro con las validaciones del contrato; login; cierre de sesion; 401 vuelve al login |
| KMP-04 | Lista de profesionales con filtros | M3 | Categoria, nombre, habilitado, disponibilidad; paginacion; resumen de horarios semanales |
| KMP-05 | Pantalla de turnos disponibles | M4 | Al elegir un profesional muestra slots ordenados por fecha y hora |
| KMP-06 | Iniciar reserva y manejo de `409` | M5 | Selecciona horario, crea la reserva; `SLOT_UNAVAILABLE` muestra aviso y refresca |
| KMP-07 | Pantalla de ingreso de telefono | M5 | Se habilita cuando corresponde (A8); validacion local; reintento tras rechazo hasta `expiresAt` |
| KMP-08 | Cliente SSE y reconciliacion por REST | M5 | Recibe cambios; al reconectar consulta procesos no finales; reanuda el proceso si se cerro la app |
| KMP-09 | Mis reservas y cancelacion | M5 | Lista propia, detalle, cancelar con confirmacion |
| KMP-10 | Estados de error y vencimiento | M6 | Mensajes para vencida, fallida, servicio no disponible; sin estados colgados |
| KMP-11 | Pruebas minimas de la app (opcional) | M6 | Opcionales segun el enunciado |
| KMP-12 | Evidencias de uso (capturas o video) | M7 | Flujo completo demostrable sin pasos manuales externos |

## Orden de ataque sugerido

1. **M1**: DOC-01, DOC-02, CAT-01, TUR-01, KMP-01 (en paralelo).
2. **M2**: CAT-03 a CAT-05, TUR-03, KMP-02, KMP-03. Sin esto no hay nada protegido.
3. **M3**: CAT-06 a CAT-15 (backend primero), luego KMP-04.
4. **M4 a M5**: backend de turnos y su pantalla correspondiente, de a un caso de uso por vez.
5. **M6 y M7**: robustez, pruebas y documentacion final.

## Dependencias entre issues

- CAT-05 depende de CAT-04; TUR-03 depende de CAT-04 (el JWT) y de A3.
- CAT-10 depende de CAT-08, CAT-09 y CAT-11.
- TUR-07 depende de TUR-05, TUR-06 y CAT-14.
- TUR-08 depende de TUR-04, TUR-05, TUR-06 y TUR-09.
- TUR-11 depende de TUR-10 (necesita `requestEventId`).
- KMP-07 y TUR-11 dependen de resolver A8. TUR-11 y TUR-17 dependen de la respuesta del profesor (A1) solo para documentar el comportamiento, no para implementarse.
