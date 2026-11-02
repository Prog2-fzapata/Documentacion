# Postman: cuenta técnica de la cátedra

Colección para registrar una sola vez la cuenta técnica del proyecto y recuperar su configuración (contrato en `INTEGRATION_REFERENCE-v2.md`, sección 5).

## Uso

1. En Postman (modo local), abrir esta carpeta como workspace: la colección está en `postman/collections/` y el entorno en `postman/environments/`. Para validar los archivos: `postman workspace lint`.
2. Seleccionar el entorno **Catedra** y completar sus variables (`baseUrl` es la URL base que envía la cátedra, sin `/` final). Postman guarda esos valores en el archivo del entorno, que está versionado: antes de cada commit revisar `git diff` y no subir `login`, `password` ni `jwt`.
3. Ejecutar **1. Registrar cuenta técnica**. Se hace una sola vez: `login`, `email` y `groupId` quedan ocupados.
4. Guardar los valores de la respuesta (`id_token` y el objeto `integration`) en el `.env` de cada servicio que los use, que no se versiona. Los nombres de las variables `CATEDRA_*` se definen en el `.env.example` de cada servicio a medida que se usan.
5. Si hace falta otro JWT o releer la configuración, usar **2.** o **3.**; no se vuelve a registrar.

Verificar que `provisioningStatus` sea `PROVISIONED`; con `PENDING` no se entrega `redisPassword`.

## Servicio de la cátedra (carpeta `Servicio de la catedra`)

Para ver cómo responde la API REST de la cátedra (`INTEGRATION_REFERENCE-v2.md`, secciones 7 a 12). Cada request envía `Authorization: Bearer {{jwt}}`, leído de la variable `jwt` del entorno, así que primero hay que tenerla cargada (pegarla o ejecutar **2. Autenticar y obtener configuracion**).

| Request | Qué hace | Escribe en la cátedra |
| --- | --- | --- |
| 1. Snapshot del catalogo | Catálogo completo; elige un profesional con agenda y lo guarda en `professionalId` (la agenda sale en la consola de Postman) | No |
| 2. Ocupaciones | Slots ocupados (`CONFIRMED` y `HELD`) de un profesional entre `from` y `to` | No |
| 2b. Ocupaciones con rango invertido | Error esperado `400 INVALID_DATE_RANGE` | No |
| 3. Crear hold | Bloquea un slot unos 10 minutos; guarda `holdId` y `reservationProcessId` | **Sí** |
| 3b. Crear hold con body incompleto | Error esperado `400 VALIDATION_ERROR` con `fieldErrors` | No |
| 4. Confirmar hold | Pasa el hold a reserva `PHONE_PENDING` y publica `AdditionalInformationRequested` en Kafka | **Sí** |
| 5. Listar reservas | Reservas de toda la cuenta técnica, paginadas (`X-Total-Count` y `Link` en las cabeceras) | No |
| 6. Cancelar reserva | Cancela por `reservationProcessId` (solo si está `CONFIRMED`) | **Sí** |

Variables del entorno que usa: `professionalId`, `from` y `to` (si están vacías, **2.** usa hoy y hoy + 7 días), `date` y `startTime` (el slot a reservar: tiene que caer en un día y hora de la agenda del profesional, por ejemplo `MONDAY 09:00-12:00 cada 30 min` permite `startTime` 09:00, 09:30, ...), `externalPatientId`, `patientFirstName` y `patientLastName`. `holdId` y `reservationProcessId` las completa **3.** sola.

Orden sugerido: 1, 2, completar `date` y `startTime` con un slot libre, 3, 2 otra vez (el slot ahora figura `HELD`), 4 y 5. Los errores de 2b y 3b se pueden ejecutar en cualquier momento.

Cuidado: 3, 4 y 6 escriben en la instancia central de la cátedra. Un hold vence solo a los 10 minutos; una reserva confirmada solo pasa a `CONFIRMED` cuando se completa el teléfono por Kafka (eso lo hará el servicio de turnos), así que desde Postman la reserva queda en `PHONE_PENDING` hasta que venza su proceso.

## Qué no se commitea

Los archivos de este directorio no llevan valores. No exportar ni commitear el entorno completado ni capturas con el JWT o las claves de Redis: viven solo en el `.env` de cada servicio, que está en `.gitignore`.
