---
name: repaso
description: Guarda y retoma el estado de trabajo del proyecto de turnos entre un /clear o /compact. Usar cuando el usuario escribe /repaso, o pide "retomar", "repasar dónde estábamos" o "guardar el estado antes de limpiar el contexto". Con trabajo en curso en la conversación guarda un resumen en disco; con la conversación vacía lo lee, lo contrasta con git, GitHub y la documentación, y propone cómo seguir.
---

# Repaso: guardar y retomar el trabajo

El usuario limpia o compacta el contexto cuando está por empezar un issue nuevo y la conversación ya cargó mucho. Esta skill hace que no se pierda lo importante. Un `/clear` borra todo, así que lo que no esté en disco o en GitHub se pierde: por eso hay dos modos.

## Elegir el modo

- Argumento `guardar` o `retomar`: se hace lo pedido.
- Sin argumento: si la conversación ya tiene trabajo previo (más que este comando), modo **guardar**; si está vacía o solo tiene un resumen de compactación, modo **retomar**.
- Decir en una línea qué modo se eligió.

El archivo de estado es `Documentacion/.claude/repaso-estado.md`. Está ignorado por git: es un apunte de trabajo, no un entregable.

## Modo guardar

1. **Mirar el estado real** de los repos (`Documentacion`, `ServicioCatalogo`, `ServicioTurnos`, `KMP`), todos bajo `/home/franco/Documentos/um/prog2/final`:
   `git -C <repo> status -sb`, `git -C <repo> log --oneline origin/<rama>..HEAD` (commits sin subir) y `gh pr list --state open` en cada repo.
2. **Registrar lo pendiente de registrar.** Toda decisión tomada en la conversación debe estar en `Documentacion/decisiones.md`; si falta alguna, agregarla ahora (sin commit). Si el usuario dio una preferencia durable ("siempre...", "no hagas..."), guardarla en memoria.
3. **Escribir el archivo** (sobrescribirlo) con esta plantilla, breve y concreto:

```markdown
# Estado de trabajo (guardado <fecha y hora>)

## Siguiente issue
<código, repo y número, milestone, rama sugerida, criterios de aceptación en una línea>

## Dónde estamos
- Último trabajo terminado: <qué y en qué PR o commit>
- Repos: <por repo: rama, commits sin subir, cambios sin commitear, PR abiertos y su estado>
- CI / Sonar: <resultado conocido>

## Decisiones por tomar para el siguiente issue
<cada una con opciones y mi recomendación; sin tomar ninguna que el usuario no haya aprobado>

## Pendientes del usuario
<lo que espera respuesta del profesor, aprobaciones de commit o push, merges, etc.>

## Conversación en curso
<temas que quedaron a medias, preguntas que el usuario hizo y no se cerraron, lo último que se estaba explicando>
```

4. **Avisar al usuario**: qué quedó guardado, si hay trabajo sin commitear o sin subir (para que no lo dé por perdido), y que ya puede hacer `/clear` o `/compact` y luego escribir `/repaso`.
5. No hacer commit ni push, ni escribir tokens, IPs de la cátedra o claves en el archivo.

## Modo retomar

1. **Leer** `Documentacion/.claude/repaso-estado.md` si existe. Es un punto de partida, no la verdad.
2. **Contrastar con la realidad**, que gana si discrepa (y se informa la diferencia):

| Qué | Cómo |
| --- | --- |
| Git por repo | `git -C <repo> status -sb`, `git -C <repo> log --oneline -5`, ramas locales |
| PR y CI | `gh pr list --state all --limit 5` por repo; Sonar: `https://sonarcloud.io/api/qualitygates/project_status?projectKey=Prog2-fzapata_<Servicio>&pullRequest=<n>` |
| Tablero | `gh project item-list 3 --owner Prog2-fzapata --limit 200 --format json` (columnas Por hacer, En curso, En revisión, Hecho) |
| Decisiones y dudas | `Documentacion/decisiones.md`: últimas decisiones (D) y preguntas abiertas (A) |
| Plan | `Documentacion/planificacion.md`: el issue siguiente, sus dependencias y milestone |
| Issue | `gh issue view <n> --repo Prog2-fzapata/<repo>`: criterios de aceptación |

3. **Si no hay archivo de estado**: reconstruir con las mismas fuentes y avisarlo.
4. **Entregar un resumen** en español, claro y sin jerga:
   - dónde está cada repo y qué PR esperan revisión;
   - lo último que se hizo;
   - el issue que sigue, con su criterio de aceptación y de qué depende;
   - las decisiones de diseño que hay que tomar antes de escribir código, con opciones y una recomendación para cada una;
   - lo que está pendiente del usuario.
5. **No empezar a implementar.** Terminar preguntando si arrancamos o si algo cambió.

## Cómo trabajamos

Complementa a `CLAUDE.md` (reglas de git, comentarios y documentación) y a la skill `hexagonal`. Es lo aprendido trabajando con el usuario:

**Con el usuario**
- Está aprendiendo: explicar en castellano, con ejemplos y sin jerga, y cuando pregunta algo, contestar eso primero. Si pide repasar archivo por archivo, ir de a uno, con quién llama a quién, y esperar su "avanzá".
- Ante una decisión de diseño, presentar opciones con una recomendación y esperar su respuesta; coincidir con el comportamiento por defecto de JHipster cuenta a favor.
- No inventar: si no se sabe, verificar (leer el enunciado, el código, la API) o decirlo. Si hay un error propio, decirlo y repararlo.
- Lo irreversible o de cara afuera (push, PR, issues, proyectos, mensajes) solo con su pedido claro.

**Por issue**
1. Leer el issue y sus criterios; presentar un plan corto con las decisiones abiertas y esperar su confirmación.
2. Rama `feat/<n>-descripcion` desde la rama más reciente de la cadena de PR; un issue por rama.
3. Código con la skill `hexagonal`: constructor con `@RequiredArgsConstructor` (nunca `@Autowired`, ni `@Data`), una interfaz por caso de uso, constantes sí y estado estático mutable no.
4. Pruebas en tres niveles: unitarias con Mockito para los casos de uso, `@WebMvcTest` para controllers y handlers, e integración contra PostgreSQL real con Testcontainers. Correr `./mvnw verify` (necesita Docker) y, para confiar en un test, romper el código a propósito y ver que falle.
5. Documentar al implementar: decisión en `Documentacion/decisiones.md`; las no impuestas por el enunciado, también como entrada de `docs/decisiones.md` del servicio (contexto, decisión, alternativas descartadas, justificación); contratos, diagramas y README si cambian.
6. Commits en Conventional Commits con cuerpo completo y `Refs #n`, sin `Co-Authored-By`. Mostrar cada mensaje y esperar el OK. Push solo con aprobación explícita, y cada vez.
7. Abrir el PR hacia la rama que corresponda de la cadena, **sin líneas de atribución** en la descripción, y con sus metadatos completos (lo pidió el profesor): responsable `francozapata05`, etiqueta (`enhancement`, `documentation` o `bug`), el hito del issue y el proyecto 3 con estado «En revisión» (`gh project item-add 3 --owner Prog2-fzapata --url <PR>` y `gh project item-edit`). Si `gh pr edit` falla por «Projects (classic)», usar `gh api -X PATCH repos/<owner>/<repo>/issues/<n>`. Los issues también llevan responsable: asignarlo al tomarlo. Al mergear, el estado del PR en el tablero pasa a «Hecho». Después del push consultar el estado con `mcp__ccd_pr__get_status`, sin sondear. Si el Quality Gate de Sonar falla, leer sus condiciones y sus issues por la API y corregir.
8. Cuando el usuario mergea en GitHub, darle el mensaje del merge con el número del PR (`tipo: resumen (#N)`) y retargetear los PR que dependían de esa rama.

**Entorno**
- Cada servicio trae su `docker-compose.yml` y su `.env`, que no se versiona; las variables se cargan con `set -a; . ./.env; set +a`. Los tests no usan ese `.env` ni la base del compose.
- El entorno se declara con `SPRING_PROFILES_ACTIVE` (`dev` o `prod`).
- En zsh las variables sin comillas no se separan por espacios: usar `bash -c` para los bucles.
- Kafka de la cátedra: ver A12 en `decisiones.md` antes de depender de él.
