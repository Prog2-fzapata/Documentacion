# Contratos - convenciones comunes

> Contratos **entre la app KMP y los backends, y entre los dos backends**. Los contratos con la catedra estan en `INTEGRATION_REFERENCE-v2.md`. Todo es propuesta hasta marcarse en [decisiones.md](../decisiones.md).

## General

- Prefijo `/api/`. JSON en `camelCase`. Fechas `yyyy-MM-dd`, instantes ISO-8601 UTC, horas `HH:mm:ss` (se aceptan `HH:mm` y `HH:mm:ss`).
- HTTPS hacia el cliente en entornos reales (en local Compose puede ser HTTP; se documenta como limitacion).
- Paginacion estilo Spring/JHipster: `page`, `size`, `sort`. La respuesta es un arreglo JSON con cabeceras `X-Total-Count` y `Link`.
- CORS: solo origenes configurados por variable de entorno.

## Autenticacion

- Todo es protegido salvo `POST /api/register` y `POST /api/authenticate`. Cabecera `Authorization: Bearer <jwt-usuario>`.
- **El servicio de catalogo emite el JWT**; turnos lo valida (firma, vigencia, autoridades). Metodo de validacion: ver A3 en decisiones.
- Claims propuestos:

| Claim | Contenido |
| --- | --- |
| `sub` | `login` del usuario |
| `uid` | `id` numerico del usuario (se envia a la catedra como `externalPatientId`) |
| `auth` | autoridades, p. ej. `ROLE_USER` |
| `firstName`, `lastName` | datos del paciente para confirmar la reserva |
| `iat`, `exp` | emision y vencimiento |

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

En errores de validacion se agrega `fieldErrors: [{ "objectName", "field", "message" }]` y `code = VALIDATION_ERROR`. El cliente decide por `status` y `code`, nunca por `detail`.

Errores comunes:

| HTTP | `code` | Cuando |
| --- | --- | --- |
| 400 | `VALIDATION_ERROR` | body o parametros invalidos |
| 401 | (sin garantia) | falta JWT, firma invalida o vencido |
| 403 | (sin garantia) | autenticado sin permiso |
| 404 | `*_NOT_FOUND` | recurso inexistente **o ajeno** (no se distingue, para no revelar existencia) |
| 503 | `CATALOG_UNAVAILABLE` / `CATEDRA_UNAVAILABLE` | dependencia requerida caida o con timeout |
| 500 | (sin garantia) | error inesperado, sin detalles internos |
