# Postman: cuenta técnica de la cátedra

Colección para registrar una sola vez la cuenta técnica del proyecto y recuperar su configuración (contrato en `INTEGRATION_REFERENCE-v2.md`, sección 5).

## Uso

1. En Postman, importar `catedra.postman_collection.json` y `catedra.postman_environment.json`.
2. Seleccionar el entorno **Catedra** y completar sus variables (`baseUrl` es la URL base que envía la cátedra, sin `/` final).
3. Ejecutar **1. Registrar cuenta técnica**. Se hace una sola vez: `login`, `email` y `groupId` quedan ocupados.
4. Guardar los valores de la respuesta (`id_token` y el objeto `integration`) en `infra/.env`, siguiendo los nombres de `infra/.env.example`.
5. Si hace falta otro JWT o releer la configuración, usar **2.** o **3.**; no se vuelve a registrar.

Verificar que `provisioningStatus` sea `PROVISIONED`; con `PENDING` no se entrega `redisPassword`.

## Qué no se commitea

Los archivos de este directorio no llevan valores. No exportar ni commitear el entorno completado ni capturas con el JWT o las claves de Redis: viven solo en `infra/.env`, que está en `.gitignore`.
