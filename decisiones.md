# Registro de decisiones

Bitacora de decisiones de diseño y preguntas abiertas. Se actualiza a medida que avanza la conversacion de analisis. Fuentes de verdad externas: `PROJECT_STATEMENT-v1.md` y `INTEGRATION_REFERENCE-v2.md` (en la carpeta raiz del proyecto).

Estados: **Decidido**, **Propuesta** (acordada en lineas generales, sin confirmacion explicita) o **Abierta**.

## Decididas

| # | Tema | Decision | Detalle |
| --- | --- | --- | --- |
| D1 | Arquitectura de codigo | **Hexagonal** (puertos y adaptadores) con las convenciones de la catedra | Skill en [.claude/skills/hexagonal](../.claude/skills/hexagonal/SKILL.md). Repo de referencia: github.com/dqmdz/hexagonal |
| D2 | Emision del JWT de usuario | La emite el **servicio de catalogo** (estilo JHipster) | Registro y login de usuarios finales viven en catalogo |
| D3 | JWT entre servicios | **Un solo JWT de usuario para ambos servicios**; turnos lo valida y lo propaga al llamar a catalogo | Preserva identidad y trazabilidad. Falta definir validacion de firma (secreto compartido o clave publica) |
| D4 | Base de datos | PostgreSQL, **una instancia con dos bases logicas** (`catalogo_db`, `turnos_db`), usuarios sin permisos cruzados, migraciones independientes | Script de inicializacion en Docker Compose |
| D5 | App Android <-> backend | **SSE** (Server-Sent Events) para avisar cambios de estado de reserva | Autenticado con JWT (Ktor permite header). Al reconectar, la app pide el estado actual por REST: no depende de haber recibido el aviso |
| D6 | Identificador del usuario ante la catedra | `externalPatientId` = `id` numerico del usuario (como texto), claim en el JWT | Inmutable; la catedra asocia reservas a este valor |
| D7 | Telefono | Se **conserva** en `reservation_process.patient_phone` | |
| D8 | Indices | `user_id`; `status` + `expires_at`; `status` en `outbox` | |
| D9 | Configuracion y secretos | Variables de entorno: `.env` fuera de git, `.env.example` versionado, `env_file` en Compose | Ambos backends comparten cuenta tecnica y JWT tecnico. El JWT tecnico nunca llega a KMP ni a logs |
| D10 | Lectura de Kafka | `@KafkaListener` de Spring (el bucle de lectura lo maneja el framework) | Catalogo consume `catedra.catalog`; turnos consume `alumnos.turnos.acciones` y produce `catedra.turnos.telefono`. KMP no toca Kafka |
| D11 | Idempotencia de consumidores | Tabla `processed_event(event_id PK, event_type, processed_at)` por servicio; insert + cambio de estado en la **misma transaccion**; commit de offset despues | Limpieza de filas viejas (propuesta: > 7 dias) |
| D12 | Publicacion del telefono | **Outbox transaccional** | Tx1: estado `PHONE_QUEUED` + fila `outbox` `PENDING`. Relay periodico (siempre activo, consulta barata): publica, espera ack, Tx2: fila `SENT` + estado `PHONE_SUBMITTED`. Si cae entre ack y Tx2 se reenvia el mismo `eventId` (duplicado posible). Producer con `enable.idempotence=true` |
| D12b | Duplicados del telefono (respuesta del profesor, antes A1) | La catedra **ignora como duplicado** un `AdditionalInformationSubmitted` con el mismo `eventId`; lo comprueba **antes** de mirar el estado de la reserva, asi que el reenvio no genera `AppointmentProcessInvalid`, no modifica una reserva confirmada ni reemite `AppointmentConfirmed` | En los reintentos del outbox se conserva el **mismo `eventId` y el mismo contenido**. `PHONE_SUBMITTED` significa "mensaje enviado" (ack del broker), no confirmacion funcional. `AppointmentConfirmed` puede llegar antes de que el relay actualice el estado local: esa actualizacion **no debe hacer retroceder** una reserva ya confirmada |
| D13 | Flujo de UI | Lista de profesionales desde copia local; al elegir uno se piden ocupaciones a la API y se muestran turnos libres ordenados por fecha/hora ascendente | Ventana acotada (propuesta: 14 a 30 dias) |
| D14 | Reserva | El **hold (`POST appointment-holds`) es la verificacion**: no se consulta disponibilidad antes de bloquear (evita condicion de carrera). `409` es un caso normal y se refresca la grilla | Antes de pedir el hold, turnos valida con catalogo que el profesional este habilitado y el horario exista |
| D15 | Modelo de datos | Ver [05-modelo-de-datos.md](diagramas/05-modelo-de-datos.md) | Sin FK entre bases; referencias por valor |
| D16 | Commits | **Conventional Commits** obligatorio, mensajes breves | `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:` |
| D17 | Ramas | `main`, `develop` y `testing` en los cuatro repos | Proyecto individual |
| D19 | Planificacion | Milestones e issues **en GitHub, por repo**, milestones por **entrega vertical** (M1 a M7) | Detalle en [planificacion.md](planificacion.md). `gh` instalado y autenticado (SSH). **Creados el 2026-10-07** en `Documentacion` (6), `ServicioCatalogo` (17) y `ServicioTurnos` (18) con sus milestones; las dependencias entre issues quedaron como enlaces `#n` |
| D22 | Issues de KMP | **Se crean al terminar el backend**, no antes | Los 12 issues `KMP-01` a `KMP-12` siguen solo en planificacion.md |
| D20 | Docker Compose | Vive en `Documentacion/infra/` | Implementado (issue `Documentacion#1`): `postgres:18` (PostgreSQL no tiene "LTS" oficial: cada version mayor recibe 5 años de soporte; la 18 es la mas reciente soportada hasta 2030), un script crea las dos bases y usuarios, puerto solo en `127.0.0.1`, claves en `.env` (fuera de git), healthcheck. Verificado: cada usuario accede a su base y recibe `permission denied` en la otra. Las claves con `$` se escriben `$$` en `.env`. Los servicios se agregan al compose cuando tengan Dockerfile |
| D23 | Cuenta tecnica de la catedra | Colección Postman sin valores en `Documentacion/postman/`. Los datos de integración (JWT, Redis, Kafka) viven en `infra/.env` con prefijo `CATEDRA_`, fuera de git | El registro lo hace el usuario a mano, una sola vez. Issue `Documentacion#2` |
| D21 | Etiquetas de GitHub | Solo las por defecto (`enhancement`, `bug`, `documentation`); sin etiquetas propias | |
| D18 | Push | **Nunca se pushea sin aprobacion explicita del usuario** | Tampoco se commitea sin pedido |

## Propuestas (aceptadas en lineas generales)

| # | Tema | Propuesta |
| --- | --- | --- |
| P1 | Timeouts y reintentos hacia la API | Reintentos **limitados** (ej. 3) con espera creciente. Ante timeout se reconcilia antes de repetir. `POST holds`: un `409` es ambiguo, el proceso pasa a `FAILED` y el hold huerfano vence solo. `POST confirm`: reintentar es seguro; `409 RESERVATION_PROCESS_ALREADY_CONFIRMED` se trata como exito. `POST cancel`: idempotente por contrato |
| P2 | Job de recuperacion al arrancar | Procesos no finales con `expiresAt` vencido pasan a `EXPIRED`. Procesos dudosos (`HELD` con confirm sin respuesta, `PHONE_SUBMITTED` sin resultado, `CONFIRMED` que la catedra marca distinto) se reconcilian con `GET /api/appointments?externalPatientId=...`. `HOLD_REQUESTED` sin ids guardados pasa a `FAILED` |
| P3 | Proceso nunca recibe telefono | No requiere accion: la catedra publica `AppointmentProcessExpired` en `expiresAt`; el job de arranque es red de seguridad |
| P4 | Chequeo periodico de version de catalogo | Ademas de `CatalogUpdated`, comparar version local con Redis al arrancar y periodicamente (frecuencia a definir) |

| P5 | Contratos entre app y backends | Borradores en [contratos/](contratos/00-convenciones.md): errores `problem+json` con `code`, paginacion JHipster, `404` tambien para recursos ajenos, `uid` solo desde el JWT, usuarios compatibles con JHipster (`/api/register`, `/api/authenticate`, `/api/account`), turnos usa `GET /api/professionals/{id}` de catalogo como agenda vigente, SSE en `/api/reservations/stream` |
| P6 | Slices | `usuario` y `catalogo` (servicio catalogo); `disponibilidad` y `reserva` (servicio turnos). Casos de uso y puertos `in` en [06-casos-de-uso.md](diagramas/06-casos-de-uso.md) |
| P7 | Inicio de reserva en un solo endpoint | `POST /api/reservations` hace validacion con catalogo + hold + confirm y devuelve la reserva; nombre y apellido del paciente salen de los claims del JWT |

## Abiertas

| # | Pregunta | Estado |
| --- | --- | --- |
| A2 | Significado del filtro "disponibilidad" en la busqueda: ¿tiene horarios habilitados (local) o tiene turnos libres reales (requeriria ocupaciones)? | Sin confirmar. La lectura local es la coherente con "busquedas sobre copia local" |
| A3 | Validacion del JWT en turnos: secreto compartido (HS256) o clave publica (RSA) | Sin decidir |
| A4 | Frecuencia del chequeo periodico y retencion de `processed_event` | Sin decidir |
| A5 | Estado y errores de sincronizacion expuestos por REST (requisito 4.1) | Modelo listo (`SYNC_STATE`), falta definir endpoint |
| A6 | Datos de acceso a la catedra (URL base API, Redis, Kafka) | **Recibidos** (acceso por ZeroTier, red `programacion-2-2026`). Verificada la conectividad. No se escriben en el repo (el anexo lo prohibe): viven en `infra/.env`. Falta confirmar si el registro devuelve los mismos host y puertos |
| A12 | La catedra devuelve en `integration` un host interno para Redis y Kafka, no alcanzable por ZeroTier. Redis funciona usando la IP del servidor en ZeroTier. En Kafka el bootstrap conecta pero el broker anuncia su direccion interna, por lo que un cliente Kafka fallaria despues de conectar | Cuenta tecnica registrada y verificada (`PROVISIONED`, Redis responde). **Consultar al profesor** si el listener de Kafka puede anunciar la IP de ZeroTier. Mientras tanto, redireccion local con `iptables`: **dos reglas**, DNAT en `OUTPUT` (de la direccion interna a la IP de ZeroTier) y MASQUERADE en `POSTROUTING` por la interfaz de ZeroTier, para que el servidor vea la IP de ZeroTier del alumno. **Verificado el 2026-10-07**: el broker responde en ambas direcciones. No persiste tras reiniciar y no cubre contenedores Docker |
| A7 | Validaciones de registro "definidas por la catedra" (enunciado 3.2): el anexo no las detalla. Se uso el estandar JHipster; `firstName` y `lastName` se hicieron obligatorios porque la catedra exige nombre y apellido del paciente (2 a 100) | Confirmar con el profesor |
| A8 | Como sabe la app que ya puede pedir el telefono (el pedido de la catedra llega asincronico despues del `202` de confirm): ¿campo `phoneRequested` en `Reservation`, o estado propio? | Sin decidir |
| A11 | Uso de la rama `testing`: se decide segun el issue si hace falta. Falta saber que espera la catedra de esa rama | Confirmar con el profesor |
| A9 | Zona horaria para "horarios pasados" y calculo de slots (las horas de la catedra son locales de atencion) | Propuesta: configurable, por defecto `America/Argentina/Mendoza` |

## Cambios respecto de borradores anteriores

- El polling propuesto en [03-flujo-reserva.md](diagramas/03-flujo-reserva.md) se reemplaza por **SSE** (D5).
- Se agrego el estado `PHONE_QUEUED` a la maquina de estados (D12).
