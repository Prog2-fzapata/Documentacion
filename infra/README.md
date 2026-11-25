# Catálogo y turnos juntos con Docker Compose

`docker-compose.yml` levanta los dos servicios, cada uno con su PostgreSQL, en una misma red de Docker. Turnos llega a catálogo por el nombre del servicio (`http://catalogo:8081`).

Hace falta porque con los compose de cada servicio, en Linux, el contenedor de turnos **no** alcanza a catálogo: catálogo publica su puerto solo en `127.0.0.1` y `host.docker.internal` resuelve a otra dirección (ver A32 en [decisiones.md](../decisiones.md)). Fuera de Linux los compose sueltos también funcionan.

## Requisitos

- Docker y Docker Compose v2.
- Los repos `ServicioCatalogo` y `ServicioTurnos` clonados al lado de `Documentacion` (el compose construye las imágenes desde `../../ServicioCatalogo` y `../../ServicioTurnos`).
- La VPN de la cátedra (ZeroTier) activa: catálogo lee el Redis y el Kafka de la cátedra y turnos usa su Kafka.

## Configurar

Este compose tiene su propio `.env`, en esta carpeta. No usa los `.env` de cada servicio, que solo sirven para correrlos por separado.

```bash
cp .env.example .env
```

Después se completan los valores `cambiar`. La plantilla agrupa las variables en lo que vale para los dos servicios (`JWT_SECRET`, la API y el JWT técnico de la cátedra, el servidor y el grupo de Kafka), lo que usa solo catálogo (Redis, topic del catálogo, nombres del contrato y costo de Argon2) y lo que usa solo turnos (topics de turnos y `groupId` de la cuenta). Lo compartido se escribe una sola vez, así no puede quedar distinto entre los dos.

Los valores de la cátedra salen de la respuesta de `integration` (el mismo origen que en el `.env` de cada servicio), y la clave del JWT se genera con `openssl rand -base64 64`. Si ya tenés los `.env` de los dos servicios completos, los valores son los mismos: se copian de ahí.

Compose lee el `.env` de esta carpeta solo, sin cargarlo en el shell. Si falta una variable obligatoria, se detiene antes de crear nada y dice cuál (`required variable JWT_SECRET is missing a value`). Los parámetros de ajuste (por ejemplo `LOG_FORMAT`, o `RESERVATION_HOLD_MAX_ATTEMPTS`, que usa solo turnos) no están en la plantilla: tienen su valor por defecto en cada servicio y, si se agregan al `.env`, ganan.

## Levantar

```bash
docker compose up -d --build
```

Catálogo queda en `http://localhost:8081` y turnos en `http://localhost:8082` (puertos `CATALOGO_PORT` y `TURNOS_PORT`). Las bases se publican solo en `127.0.0.1`, en `5432` (catálogo) y `5433` (turnos); se cambian con `CATALOGO_POSTGRES_PORT` y `TURNOS_POSTGRES_PORT`. El `CATALOGO_BASE_URL` de turnos no se configura: en este compose es siempre `http://catalogo:8081`.

Para comprobar el `.env` sin levantar nada: `docker compose config --quiet` (no muestra nada si está todo; si falta algo, dice qué).

## Operar

| Acción | Comando |
| --- | --- |
| Ver estado | `docker compose ps` |
| Ver logs | `docker compose logs -f catalogo turnos` |
| Detener (conserva los datos) | `docker compose down` |
| Borrar todo, incluidos los datos | `docker compose down -v` |

Los dos servicios escriben sus logs en JSON, una línea por evento. `docker compose logs` antepone a cada línea una secuencia de control (`ESC[2K`, «borrar la línea») que hace que `jq` descarte todo en silencio, por eso los comandos de abajo la quitan con `sed` antes de pasar por `jq`. Con `-u` y `--unbuffered` las líneas llegan al instante.

Para ver los dos servicios a la vez, sin el ruido de las librerías (Kafka, Hibernate, Spring), con el nombre del servicio y los `WARN` en amarillo y los `ERROR` en rojo, `logs-demo.jq`:

```bash
docker compose logs -f --no-log-prefix catalogo turnos | sed -u 's/\x1b\[2K//' | jq --unbuffered -R -r -f logs-demo.jq
```

Para ver todo lo que escribe un servicio, incluidas las librerías, en una línea corta por evento, `logs.jq`:

```bash
docker compose logs -f --no-log-prefix turnos | sed -u 's/\x1b\[2K//' | jq --unbuffered -R -r -f logs.jq
```

Para filtrar por un campo: `docker compose logs --no-log-prefix turnos | sed 's/\x1b\[2K//' | jq -R -c 'fromjson? | select(.reservationId == 12)'`.

No usar `docker compose config` sin `--quiet`: imprime los valores de las variables, incluido el JWT técnico.

Este compose usa su propio proyecto (`turnos-integrador`) y sus propios volúmenes: no comparte datos con los compose de cada servicio, y catálogo vuelve a sincronizar con la cátedra al primer arranque.
