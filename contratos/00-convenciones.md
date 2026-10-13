# Contratos - convenciones comunes

> Contratos **entre la app KMP y los backends, y entre los dos backends**. Los contratos con la catedra estan en `INTEGRATION_REFERENCE-v2.md`. Todo es propuesta hasta marcarse en [decisiones.md](../decisiones.md).

## General

- Prefijo `/api/`. JSON en `camelCase`. Fechas `yyyy-MM-dd`, instantes ISO-8601 UTC, horas `HH:mm:ss` (se aceptan `HH:mm` y `HH:mm:ss`).
- HTTPS hacia el cliente en entornos reales (en local Compose puede ser HTTP; se documenta como limitacion).
- Paginacion estilo Spring/JHipster: `page`, `size`, `sort`. La respuesta es un arreglo JSON con cabeceras `X-Total-Count` y `Link`.
- CORS: sin configurar por ahora (A16); la app es Android y CORS solo lo aplican los navegadores.

## Autenticacion

- Todo es protegido salvo `POST /api/register` y `POST /api/authenticate`. Cabecera `Authorization: Bearer <jwt-usuario>`.
- **El servicio de catalogo emite el JWT**; turnos lo valida (firma, vigencia, autoridades). Firma **HS512** con secreto compartido en Base64 de al menos 512 bits (D32 y D45 en decisiones); turnos solo acepta HS512. Vigencia de 24 horas, o 30 días con `rememberMe`.
- Claims propuestos:

| Claim | Contenido |
| --- | --- |
| `sub` | `login` del usuario |
| `uid` | `id` numerico del usuario (se envia a la catedra como `externalPatientId`) |
| `auth` | autoridades separadas por espacio, p. ej. `ROLE_USER` (como JHipster) |
| `iat`, `exp` | emision y vencimiento |

- El nombre y apellido del paciente **no** van en el JWT (un claim queda fijo al emitirlo): turnos los consulta en `GET /api/account` de catalogo al reservar (D34).
- El `uid` **siempre** sale del JWT; ningun endpoint lo acepta en el body o la URL.
- Turnos propaga el mismo JWT cuando llama a catalogo.
- El JWT tecnico de la catedra no aparece en ningun contrato de este proyecto.

## Errores

Formato `application/problem+json`, igual al de la catedra y JHipster:

```json
{
  "type": "about:blank",
  "title": "Conflict",
  "status": 409,
  "detail": "El horario ya no esta disponible",
  "path": "/api/reservations",
  "code": "SLOT_UNAVAILABLE"
}
```

En errores de validacion se agrega `fieldErrors: [{ "objectName", "field", "message" }]` y `code = VALIDATION_ERROR`. El cliente decide por `status` y `code`, nunca por `detail`. Todo el `detail` está en español. Spring agrega además el campo `instance`, igual a `path`; los clientes lo ignoran.

Errores comunes:

| HTTP | `code` | Cuando |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` | body o parametros invalidos |
| 401 | `UNAUTHORIZED` | falta JWT, firma invalida o vencido (no se distingue el motivo; cabecera `WWW-Authenticate: Bearer`) |
| 403 | `FORBIDDEN` | autenticado sin permiso |
| 400 | `BAD_REQUEST` | solicitud inválida que Spring detecta antes del controller (parámetro mal tipado, etc.) |
| 404 | `NOT_FOUND` | ruta inexistente |
| 405 | `METHOD_NOT_ALLOWED` | método HTTP no permitido para la ruta |
| 415 | `UNSUPPORTED_MEDIA_TYPE` | `Content-Type` no soportado |
| 404 | `*_NOT_FOUND` | recurso inexistente **o ajeno** (no se distingue, para no revelar existencia) |
| 503 | `CATALOG_UNAVAILABLE` / `CATEDRA_UNAVAILABLE` | dependencia requerida caida o con timeout |
| 500 | (sin garantia) | error inesperado, sin detalles internos |
