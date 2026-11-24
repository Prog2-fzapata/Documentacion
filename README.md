<!-- calidad:inicio -->
![Calidad](https://img.shields.io/badge/Calidad-sin%20c%C3%B3digo-lightgrey) ![Aprobar](https://img.shields.io/badge/Aprobar-no-red) ![Destacar](https://img.shields.io/badge/Destacar-no-lightgrey)

**Calidad (7 dimensiones):** sin código en `main` (no evaluable).
<!-- calidad:fin -->

# Documentacion

Borradores de analisis y diseño. Los diagramas usan Mermaid (se ven en GitHub, VS Code con extension y la mayoria de visores Markdown).

| Archivo | Contenido |
| --- | --- |
| [decisiones.md](decisiones.md) | **Registro de decisiones y preguntas abiertas** (leer primero) |
| [planificacion.md](planificacion.md) | Milestones, issues por repo, orden de ataque y dependencias |
| [kcat.md](kcat.md) | Cómo mirar los topics de Kafka de la cátedra con `kcat` (comandos y flags) |
| [infra/README.md](infra/README.md) | Docker Compose que levanta catálogo y turnos juntos (en Linux, la forma de que turnos alcance a catálogo) |
| [.claude/skills/hexagonal](.claude/skills/hexagonal/SKILL.md) | Skill de arquitectura hexagonal de la catedra |
| [.claude/skills/repaso](.claude/skills/repaso/SKILL.md) | Skill `/repaso`: guarda el estado de trabajo y lo retoma tras un `/clear` o `/compact` |
| [diagramas/06-casos-de-uso.md](diagramas/06-casos-de-uso.md) | Casos de uso por servicio y catalogo de puertos `in` |

**Contratos y diagramas vigentes:** están en `docs/` de cada servicio (`ServicioCatalogo` y `ServicioTurnos`): `arquitectura.md`, `modelo-de-datos.md`, `contrato.md`, la sincronización, la idempotencia y la máquina de estados. Los borradores de contratos y de los diagramas 01 a 05 que había acá se borraron el 2026-11-24 porque habían quedado atrás; siguen en el historial de git. El único borrador que queda es el de casos de uso (06).

Fuentes: `PROJECT_STATEMENT-v1.md` e `INTEGRATION_REFERENCE-v2.md`. Las decisiones marcadas como **[decidir]** estan abiertas.
