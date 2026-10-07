# Infraestructura local

Levanta una instancia de PostgreSQL con **dos bases logicas separadas**, una por servicio:

| Base | Usuario propietario | Servicio |
| --- | --- | --- |
| `catalogo_db` | `catalogo_user` | ServicioCatalogo |
| `turnos_db` | `turnos_user` | ServicioTurnos |

Cada usuario es dueño solo de su base y ningun otro rol puede conectarse a ella: el usuario de turnos no puede leer `catalogo_db` ni al reves. Cada servicio administra sus propias migraciones. Redis y Kafka **no** se levantan aca: los administra la catedra.

## Requisitos

- Docker y Docker Compose v2 (`docker compose`).

## Primer uso

```bash
cd infra
cp .env.example .env     # completar las claves en .env
docker compose up -d --wait
```

`--wait` espera a que la base este lista (healthcheck) antes de devolver el control.

`.env` esta en `.gitignore` y no se versiona. Si falta alguna variable, Compose falla con un mensaje que indica cual.

> **Claves con `$`:** Compose interpreta `$` en `.env` como una variable. Si una clave lo contiene, escribirlo como `$$`, o evitar ese caracter.

## Conexion desde los servicios

Mientras los servicios corran fuera de Docker, se conectan a `localhost`:

| Servicio | URL JDBC |
| --- | --- |
| Catalogo | `jdbc:postgresql://localhost:5432/catalogo_db` |
| Turnos | `jdbc:postgresql://localhost:5432/turnos_db` |

El puerto se cambia con `POSTGRES_PORT` en `.env`. Se publica solo en `127.0.0.1`: no es accesible desde otras maquinas de la red. Usuario y clave: los `*_DB_USER` y `*_DB_PASSWORD` de `.env`. Los servicios nunca usan el superusuario.

## Operaciones habituales

| Accion | Comando |
| --- | --- |
| Ver estado | `docker compose ps` |
| Ver logs | `docker compose logs -f postgres` |
| Detener (conserva datos) | `docker compose down` |
| **Borrar todo, incluidos los datos** | `docker compose down -v` |

El script de `postgres/init/` crea las bases y usuarios **solo en el primer arranque**, cuando el volumen esta vacio. Si se cambian los nombres o claves en `.env` despues, no tienen efecto hasta ejecutar `docker compose down -v` (que borra los datos).

## Verificar la separacion de datos

Debe fallar con `permission denied for database`:

```bash
docker exec -e PGPASSWORD=<clave-turnos> turnos-postgres \
  psql -h 127.0.0.1 -U turnos_user -d catalogo_db -c "select 1"
```

## Proximos pasos

Cuando los servicios tengan su `Dockerfile` se agregaran a este `docker-compose.yml`, con `depends_on` sobre el estado `healthy` de `postgres`.
