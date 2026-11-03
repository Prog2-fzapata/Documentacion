# Catálogo y turnos juntos con Docker Compose

`docker-compose.yml` levanta los dos servicios, cada uno con su PostgreSQL, en una misma red de Docker. Turnos llega a catálogo por el nombre del servicio (`http://catalogo:8081`).

Hace falta porque con los compose de cada servicio, en Linux, el contenedor de turnos **no** alcanza a catálogo: catálogo publica su puerto solo en `127.0.0.1` y `host.docker.internal` resuelve a otra dirección (ver A32 en [decisiones.md](../decisiones.md)). Fuera de Linux los compose sueltos también funcionan.

## Requisitos

- Docker y Docker Compose v2.
- Los repos `ServicioCatalogo` y `ServicioTurnos` clonados al lado de `Documentacion` (el compose construye las imágenes desde `../../ServicioCatalogo` y `../../ServicioTurnos`).
- El `.env` de cada servicio completo (los valores salen de ahí; no se copian a otro archivo).

## Levantar

Los dos `.env` se cargan en el shell. Las variables compartidas (`JWT_SECRET`, `CATEDRA_BASE_URL`, `CATEDRA_JWT`, `CATEDRA_KAFKA_BOOTSTRAP_SERVERS` y `CATEDRA_KAFKA_GROUP_ID`) tienen que valer lo mismo en ambos. El `CATALOGO_BASE_URL` del `.env` de turnos no se usa acá.

```bash
bash -c 'set -a; . ../../ServicioCatalogo/.env; . ../../ServicioTurnos/.env; set +a; docker compose up -d --build'
```

Catálogo queda en `http://localhost:8081` y turnos en `http://localhost:8082` (puertos `CATALOGO_PORT` y `TURNOS_PORT`). Las bases se publican solo en `127.0.0.1`, en `5432` (catálogo) y `5433` (turnos); se pueden cambiar con `CATALOGO_POSTGRES_PORT` y `TURNOS_POSTGRES_PORT`.

## Operar

Para los comandos que no construyen nada alcanza con `docker compose` en esta carpeta, sin cargar los `.env`; si Compose avisa de variables sin definir, son avisos de interpolación y no cambian lo que ya está corriendo.

| Acción | Comando |
| --- | --- |
| Ver estado | `docker compose ps` |
| Ver logs | `docker compose logs -f catalogo turnos` |
| Detener (conserva los datos) | `docker compose down` |
| Borrar todo, incluidos los datos | `docker compose down -v` |

No usar `docker compose config`: imprime los valores de las variables, incluido el JWT técnico.

Este compose usa su propio proyecto (`turnos-integrador`) y sus propios volúmenes: no comparte datos con los compose de cada servicio, y catálogo vuelve a sincronizar con la cátedra al primer arranque.
