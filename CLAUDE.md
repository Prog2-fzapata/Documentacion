# Proyecto integrador 2026: sistema distribuido de turnos

Carpeta de trabajo local (no es un repo). Contiene cuatro repos independientes: `Documentacion`, `KMP`, `ServicioCatalogo`, `ServicioTurnos`.

## Antes de trabajar

1. Leer `Documentacion/decisiones.md`: decisiones tomadas, propuestas y preguntas abiertas.
2. Los contratos externos estan en `INTEGRATION_REFERENCE-v2.md`; el alcance en `PROJECT_STATEMENT-v1.md`.
3. Diagramas en `Documentacion/diagramas/`.
4. Usar la skill `hexagonal` para todo codigo backend (vive en `Documentacion/.claude/skills/hexagonal`; `.claude/skills/hexagonal` es un enlace simbolico).

## Donde vive cada documento

- **`Documentacion` (repo propio, no lo revisa el profesor):** contexto de trabajo, `decisiones.md`, planificacion, borradores de diagramas y contratos, y las skills. Se versiona para tener respaldo en la nube; se puede pushear directo a `main`.
- **Entregables del enunciado (seccion 12):** viven en el README y en `docs/` de **cada repo de servicio** (el enunciado pide codigo y documentacion en tres repos: KMP, catalogo y turnos). Se escriben **a medida que se implementa** lo que describen, porque la documentacion debe coincidir con la solucion. Incluye un resumen breve de decisiones con alternativas descartadas y su justificacion. El diagrama de arquitectura (los dos servicios juntos) va en ambos repos de backend.

## Regla de documentacion

Toda decision, cambio de diseño o pregunta abierta que surja en la conversacion se registra **en el momento** en `Documentacion/decisiones.md` y, si afecta un diagrama, se actualiza el diagrama. La documentacion vive en el repo `Documentacion` para que quede en GitHub. No hacer commit ni push sin que el usuario lo pida.

## Git

- **Nunca hacer `git push` sin aprobacion explicita del usuario**, cada vez. Tampoco commit sin pedido.
- **Conventional Commits obligatorio** (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, con scope opcional). Asunto de hasta ~72 caracteres y un cuerpo **completo**: que alguien entienda que se hizo sin leer los archivos (que se agrega o cambia, decisiones relevantes, como se verifico, `Refs #n` al issue).
- **Siempre redactar los mensajes y mostrarlos al usuario antes de commitear.** El usuario los lee; con su OK explicito sobre esos mensajes se hace el commit y el push de ese conjunto de cambios.
- Todos los repos tienen las ramas `main`, `develop` y `testing`.
- El proyecto es **individual**.

## Estilo de codigo y archivos

- **Pocos comentarios.** No explicar cada linea dentro de los archivos (compose, scripts, config, codigo); las explicaciones van en la respuesta o en el README. Solo comentar lo que no se pueda deducir.
- El proyecto es educativo: las claves de `.env` no son sensibles y se pueden leer. Aun asi, `.env` nunca se versiona.

## Idioma

Documentacion y conversacion en español.
