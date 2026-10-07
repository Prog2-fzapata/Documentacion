# Contrato - Servicio Catalogo

Consumidores: **app KMP** y **servicio Turnos** (solo `GET /api/professionals/{id}`). Convenciones en [00-convenciones.md](00-convenciones.md).

## Usuarios

Compatibles con JHipster (requisito del enunciado).

### `POST /api/register` (publico)

```json
{
  "login": "juan.perez",
  "password": "una-clave",
  "firstName": "Juan",
  "lastName": "Perez",
  "email": "juan@example.com",
  "imageUrl": null,
  "langKey": "es"
}
```

| Campo | Obligatorio | Restricciones |
| --- | --- | --- |
| `login` | si | 1 a 50, patron de login JHipster, unico |
| `password` | si | 4 a 100 |
| `firstName`, `lastName` | si (ver A7) | 2 a 50 |
| `email` | si | email valido, 5 a 254, unico |
| `imageUrl` | no | hasta 256 |
| `langKey` | no | 2 a 10, por defecto `es` |

Respuesta `201 Created` sin cuerpo (como JHipster). El usuario queda **activo** de inmediato. `id`, `activated`, autoridades y auditoria los asigna el backend; si llegan en el body se ignoran. La contraseña se guarda con hash (BCrypt).

Errores: `400 VALIDATION_ERROR`, `400 LOGIN_ALREADY_USED`, `400 EMAIL_ALREADY_USED`.

### `POST /api/authenticate` (publico)

```json
{ "username": "juan.perez", "password": "una-clave", "rememberMe": false }
```

`200 OK`: `{ "id_token": "<jwt>" }` (y cabecera `Authorization`). Credenciales incorrectas: `401`.

### `GET /api/account`

`200 OK`: `{ "id", "login", "firstName", "lastName", "email", "imageUrl", "langKey", "authorities": ["ROLE_USER"] }`. Nunca incluye la contraseña.

## Catalogo (solo lectura, desde la copia local)

### `GET /api/professional-categories`

Parametro opcional: `enabled` (boolean). Respuesta: `[ { "id", "name", "description", "enabled" } ]`.

### `GET /api/professionals`

| Parametro | Descripcion |
| --- | --- |
| `categoryId` | filtra por categoria |
| `name` | texto parcial, sin distinguir mayusculas, sobre nombre y apellido |
| `enabled` | `true`/`false`; sin valor devuelve todos |
| `available` | `true` = tiene al menos un horario semanal habilitado (ver A2) |
| `page`, `size`, `sort` | paginacion; orden por defecto apellido, nombre |

Respuesta `200 OK` (con `X-Total-Count`):

```json
[
  {
    "id": 15,
    "categoryId": 1,
    "categoryName": "Clinica medica",
    "firstName": "Ana",
    "lastName": "Gomez",
    "enabled": true,
    "weeklySchedules": [
      { "dayOfWeek": "MONDAY", "startTime": "09:00:00", "endTime": "12:00:00", "slotDurationMinutes": 30 }
    ]
  }
]
```

`weeklySchedules` solo trae horarios habilitados; alcanza para el resumen de la lista.

### `GET /api/professionals/{id}`

Mismo objeto que arriba, incluyendo `id` y `enabled` de cada horario. Es la **agenda vigente** que usa Turnos. Si el profesional o su categoria estan deshabilitados, se devuelve igual con `enabled=false` (la decision la toma quien consume). Errores: `404 PROFESSIONAL_NOT_FOUND`.

## Sincronizacion

### `GET /api/sync/status`

```json
{
  "localVersion": 7,
  "lastSyncAt": "2026-10-07T13:44:59Z",
  "lastSyncType": "INCREMENTAL",
  "lastStatus": "OK",
  "lastError": null
}
```

`lastStatus` es `OK` o `ERROR`; `lastError` es un mensaje corto sin datos sensibles. Sirve como evidencia de snapshot, incremental y recuperacion.

## Notas

- Las busquedas se resuelven siempre sobre la base local; ningun endpoint llama a la catedra.
- No hay endpoints de escritura de catalogo: la unica fuente es la sincronizacion.
- Turnos usa `GET /api/professionals/{id}` con el JWT del usuario. Si responde 5xx o hay timeout, Turnos devuelve `503 CATALOG_UNAVAILABLE` y no inicia operaciones nuevas (enunciado 8).
