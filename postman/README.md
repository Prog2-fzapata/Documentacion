# Postman: cuenta técnica de la cátedra

Colección para registrar una sola vez la cuenta técnica del proyecto y recuperar su configuración (contrato en `INTEGRATION_REFERENCE-v2.md`, sección 5).

## Uso

1. En Postman (modo local), abrir esta carpeta como workspace: la colección está en `postman/collections/` y el entorno en `postman/environments/`. Para validar los archivos: `postman workspace lint`.
2. Seleccionar el entorno **Catedra** y completar sus variables (`baseUrl` es la URL base que envía la cátedra, sin `/` final). Postman guarda esos valores en el archivo del entorno, que está versionado: antes de cada commit revisar `git diff` y no subir `login`, `password` ni `jwt`.
3. Ejecutar **1. Registrar cuenta técnica**. Se hace una sola vez: `login`, `email` y `groupId` quedan ocupados.
4. Guardar los valores de la respuesta (`id_token` y el objeto `integration`) en el `.env` de cada servicio que los use, que no se versiona. Los nombres de las variables `CATEDRA_*` se definen en el `.env.example` de cada servicio a medida que se usan.
5. Si hace falta otro JWT o releer la configuración, usar **2.** o **3.**; no se vuelve a registrar.

Verificar que `provisioningStatus` sea `PROVISIONED`; con `PENDING` no se entrega `redisPassword`.

## Qué no se commitea

Los archivos de este directorio no llevan valores. No exportar ni commitear el entorno completado ni capturas con el JWT o las claves de Redis: viven solo en el `.env` de cada servicio, que está en `.gitignore`.
