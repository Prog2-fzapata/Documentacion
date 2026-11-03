# kcat: mirar los topics de Kafka de la cátedra

`kcat` (antes `kafkacat`) es una herramienta de terminal para leer, escribir y consultar metadatos de Kafka. Sirve para ver qué hay en los topics de la cuenta `fzapata` sin programar nada. Postman no puede: Kafka no habla HTTP.

**Estado:** los comandos están escritos a partir de la documentación de `kcat` y todavía no se verificaron contra el broker de la cátedra. Anotar acá la fecha de la primera prueba con `-L`: _pendiente_.

## Requisitos

- Docker y ZeroTier activo (el broker se alcanza por la red de la cátedra).
- La dirección del broker, que está en `CATEDRA_KAFKA_BOOTSTRAP_SERVERS` del `.env` del catálogo. No va en este archivo.
- Se corre de afuera de los compose: no se agrega nada a `docker-compose.yml`.

Cargar solo esa variable en la terminal (sin cargar el resto del `.env`):

```bash
cd ~/Documentos/um/prog2/final/ServicioCatalogo
export KAFKA_BOOTSTRAP=$(grep '^CATEDRA_KAFKA_BOOTSTRAP_SERVERS=' .env | cut -d= -f2-)
```

`--network host` hace que el contenedor salga por la red de la máquina (la que tiene ZeroTier).

## Comandos útiles

### Ver los topics y a qué broker se conectó

```bash
docker run --rm --network host edenhill/kcat:1.7.1 -b "$KAFKA_BOOTSTRAP" -L
```

Deben aparecer los tres topics de la cuenta (`catedra.catalog.fzapata`, `alumnos.turnos.acciones.fzapata` y `catedra.turnos.telefono.fzapata`), cada uno con la partición 0.

### Leer todo lo que hay y terminar

```bash
docker run --rm --network host edenhill/kcat:1.7.1 -b "$KAFKA_BOOTSTRAP" -t alumnos.turnos.acciones.fzapata -C -o beginning -e
```

Con el topic vacío termina enseguida sin imprimir nada.

### Leer con partición, offset y clave en cada mensaje

```bash
docker run --rm --network host edenhill/kcat:1.7.1 -b "$KAFKA_BOOTSTRAP" -t alumnos.turnos.acciones.fzapata -C -o beginning -e -f 'partición=%p offset=%o clave=%k\n%s\n\n'
```

### Leer los últimos 5 mensajes

```bash
docker run --rm --network host edenhill/kcat:1.7.1 -b "$KAFKA_BOOTSTRAP" -t alumnos.turnos.acciones.fzapata -C -o -5 -e
```

### Quedarse esperando mensajes nuevos (como `tail -f`)

```bash
docker run --rm --network host edenhill/kcat:1.7.1 -b "$KAFKA_BOOTSTRAP" -t alumnos.turnos.acciones.fzapata -C -o end
```

No termina: se corta con `Ctrl+C`. Sirve para dejarlo abierto mientras se hace una reserva real y ver llegar los eventos.

### Cada mensaje como JSON, con sus metadatos

```bash
docker run --rm --network host edenhill/kcat:1.7.1 -b "$KAFKA_BOOTSTRAP" -t alumnos.turnos.acciones.fzapata -C -o beginning -e -J
```

### Publicar un mensaje (cuidado)

```bash
echo '{"eventType":"..."}' | docker run --rm -i --network host edenhill/kcat:1.7.1 -b "$KAFKA_BOOTSTRAP" -t <topic> -P -k <reservationProcessId>
```

Publicar en `alumnos.turnos.acciones.fzapata` equivale a falsificar un evento de la cátedra: el consumer lo procesaría y cambiaría una reserva real. Solo en una prueba controlada y sabiendo qué se envía. Para el desarrollo se usa Kafka en Testcontainers.

## Las flags

| Flag | Qué hace |
| --- | --- |
| `-b <broker>` | Dirección del broker (`host:puerto`). |
| `-t <topic>` | Topic sobre el que se trabaja. |
| `-L` | Modo metadatos: lista topics, particiones y brokers. No lee ni escribe mensajes. |
| `-C` | Modo consumidor: lee mensajes. |
| `-P` | Modo productor: publica lo que llega por la entrada estándar, un mensaje por línea. |
| `-o beginning` | Empieza desde el primer mensaje del topic. |
| `-o end` | Empieza desde el final: solo muestra lo nuevo. |
| `-o <N>` | Empieza en el offset `N`. Con un número negativo (`-5`), desde `N` mensajes antes del final. |
| `-e` | Termina al llegar al final del topic. Sin esta flag, `kcat` queda esperando mensajes nuevos. |
| `-c <N>` | Termina después de leer `N` mensajes. |
| `-p <N>` | Solo la partición `N` (todas, si no se indica). |
| `-k <clave>` | Clave del mensaje al publicar (acá es el `reservationProcessId`). |
| `-f <formato>` | Formato de salida al leer (ver abajo). |
| `-J` | Salida en JSON, con topic, partición, offset, fecha, clave y contenido. |
| `-q` | Silencioso: no imprime los mensajes informativos de `kcat`. |
| `-X <clave>=<valor>` | Configuración avanzada de la librería, por ejemplo `-X debug=broker` para diagnosticar una conexión. |
| `-G <grupo>` | Consume como miembro de un consumer group. **No usarla con `alumnos-fzapata`:** confirmaría offsets de nuestro grupo. |

Dentro de `-f` se pueden usar: `%t` topic, `%p` partición, `%o` offset, `%k` clave, `%s` contenido del mensaje, `%T` fecha del mensaje, `%h` encabezados y `\n` salto de línea.

## Cuidados

- **Leer nunca borra mensajes:** en Kafka los mensajes quedan en el topic hasta que vence la retención, los lea quien los lea. Lo que cambia con un consumer group es su *posición guardada* (hasta qué offset leyó).
- **Leer con `-C` (sin `-G`) es seguro:** no se une a ningún grupo ni guarda posición, así que no altera la de nuestros servicios. Solo `-G <grupo>` guarda posición.
- **Nunca pasar el grupo de los servicios** (`alumnos-fzapata`), ni con `-G` ni con `-X group.id=...`: avanzaría su posición y el servicio se saltearía los mensajes que `kcat` ya leyó.
- **Publicar con `-P` tiene efectos reales** (ver arriba). Pedir confirmación antes de usarlo.
- Si `-L` conecta pero la lectura falla, mirar A12 en [decisiones.md](decisiones.md): el broker anuncia una dirección y el cliente se reconecta a ella.
- La imagen queda guardada en Docker. Para borrarla: `docker rmi edenhill/kcat:1.7.1`.

## Dejar un contenedor corriendo (opcional)

Con `--rm` cada comando levanta un contenedor y lo descarta. Si se prefiere uno fijo, que se detiene cuando no se usa:

```bash
docker run -d --name kcat --network host --entrypoint tail edenhill/kcat:1.7.1 -f /dev/null
```

Cada consulta se hace con `docker exec`:

```bash
docker exec kcat kcat -b "$KAFKA_BOOTSTRAP" -L
```

Para detenerlo y volver a usarlo después:

```bash
docker stop kcat
docker start kcat
```

Para borrarlo del todo: `docker rm -f kcat`. Los comandos de esta sección no se probaron todavía.
