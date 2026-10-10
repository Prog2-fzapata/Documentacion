# Documentacion

Borradores de analisis y diseño. Los diagramas usan Mermaid (se ven en GitHub, VS Code con extension y la mayoria de visores Markdown).

| Archivo | Contenido |
| --- | --- |
| [decisiones.md](decisiones.md) | **Registro de decisiones y preguntas abiertas** (leer primero) |
| [planificacion.md](planificacion.md) | Milestones, issues por repo, orden de ataque y dependencias |
| [.claude/skills/hexagonal](.claude/skills/hexagonal/SKILL.md) | Skill de arquitectura hexagonal de la catedra |
| [diagramas/01-arquitectura.md](diagramas/01-arquitectura.md) | Componentes, integraciones e identidades |
| [diagramas/02-sincronizacion-catalogo.md](diagramas/02-sincronizacion-catalogo.md) | Sincronizacion completa e incremental |
| [diagramas/03-flujo-reserva.md](diagramas/03-flujo-reserva.md) | Disponibilidad, reserva, consulta y cancelacion |
| [diagramas/04-maquina-estados-reserva.md](diagramas/04-maquina-estados-reserva.md) | Estados, transiciones e idempotencia |
| [diagramas/05-modelo-de-datos.md](diagramas/05-modelo-de-datos.md) | Modelo entidad-relacion de cada servicio y fronteras de propiedad |
| [diagramas/06-casos-de-uso.md](diagramas/06-casos-de-uso.md) | Casos de uso por servicio y catalogo de puertos `in` |
| [contratos/00-convenciones.md](contratos/00-convenciones.md) | Convenciones comunes: auth, JWT, errores, paginacion |
| [contratos/01-servicio-catalogo.md](contratos/01-servicio-catalogo.md) | Contrato del servicio de catalogo (app y turnos) |
| [contratos/02-servicio-turnos.md](contratos/02-servicio-turnos.md) | Contrato del servicio de turnos (app), incluido SSE |

Fuentes: `PROJECT_STATEMENT-v1.md` e `INTEGRATION_REFERENCE-v2.md`. Las decisiones marcadas como **[decidir]** estan abiertas.
