<!-- calidad:inicio -->
![Calidad](https://img.shields.io/badge/Calidad-sin%20c%C3%B3digo-lightgrey) ![Aprobar](https://img.shields.io/badge/Aprobar-no-red) ![Destacar](https://img.shields.io/badge/Destacar-no-lightgrey)

**Calidad (7 dimensiones):** sin código en `main` (no evaluable).
<!-- calidad:fin -->


# Documentacion

Contexto de trabajo del proyecto: no es un entregable ni lo revisa el profesor. Lo vigente de cada servicio está en su propio repo.

| Archivo | Contenido |
| --- | --- |
| [decisiones.md](decisiones.md) | Decisiones generales (organización, entorno y preferencias de trabajo) y preguntas abiertas. Las decisiones de cada proyecto son ADR en `docs/decisiones/` de su repo |
| [kcat.md](kcat.md) | Cómo mirar los topics de Kafka de la cátedra con `kcat` (comandos y flags) |
| [infra/README.md](infra/README.md) | Docker Compose que levanta catálogo y turnos juntos (en Linux, la forma de que turnos alcance a catálogo) y cómo leer los logs de los dos |
| [postman/README.md](postman/README.md) | Colección de Postman de la cuenta técnica de la cátedra, sin valores |
| [.claude/skills/hexagonal](.claude/skills/hexagonal/SKILL.md) | Skill de arquitectura hexagonal de la cátedra |
| [.claude/skills/kmp](.claude/skills/kmp/SKILL.md) | Skill de la app Android con Kotlin Multiplatform |
| [.claude/skills/repaso](.claude/skills/repaso/SKILL.md) | Skill `/repaso`: guarda el estado de trabajo y lo retoma tras un `/clear` o `/compact` |

**Lo vigente:** los contratos, los diagramas y las decisiones de cada proyecto están en `docs/` de `ServicioCatalogo`, `ServicioTurnos` y `KMP` (arquitectura, modelo de datos, contrato, sincronización, idempotencia, máquina de estados y los ADR de `docs/decisiones/`). Los borradores de contratos, diagramas y la planificación que había acá se borraron el 2026-11-25 porque habían quedado atrás; siguen en el historial de git. Los issues y los hitos están en GitHub.

Fuentes: `PROJECT_STATEMENT-v1.md` e `INTEGRATION_REFERENCE-v2.md`.
