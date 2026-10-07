# 01 - Arquitectura general

> Borrador de diseño. Los puntos marcados como **[decidir]** son decisiones abiertas.

## Componentes y comunicaciones

```mermaid
flowchart LR
    subgraph Cliente
        KMP["App Android (KMP)"]
    end

    subgraph Alumno["Backends del alumno (Docker Compose)"]
        CAT["Servicio Catalogo y Sincronizacion"]
        TUR["Servicio Turnos y Reservas"]
        DBC[("BD catalogo")]
        DBT[("BD turnos")]
    end

    subgraph Catedra["Servicio de catedra (externo)"]
        API["API REST"]
        RED[("Redis")]
        KAF{{"Kafka"}}
    end

    KMP -- "REST + JWT usuario" --> CAT
    KMP -- "REST + JWT usuario" --> TUR
    TUR -- "REST + JWT (agenda vigente)" --> CAT

    CAT --- DBC
    TUR --- DBT

    CAT -- "REST: snapshot (JWT tecnico)" --> API
    CAT -- "lee sync:*" --> RED
    KAF -- "catedra.catalog: CatalogUpdated" --> CAT

    TUR -- "REST: ocupaciones, holds, confirm, listado, cancel (JWT tecnico)" --> API
    KAF -- "alumnos.turnos.acciones: eventos de reserva" --> TUR
    TUR -- "catedra.turnos.telefono: AdditionalInformationSubmitted" --> KAF
```

## Reglas que el diagrama debe respetar

- La app KMP **nunca** habla con la catedra ni conoce el JWT tecnico.
- Cada servicio es dueño exclusivo de su BD (esquemas/usuarios separados, migraciones propias).
- Turnos **no** replica el catalogo: le pide la agenda vigente a Catalogo antes de cada operacion nueva.
- Catalogo es el unico que consume `catedra.catalog` y lee Redis `catedra:sync:*`.
- Turnos es el unico que consume `alumnos.turnos.acciones` y produce `catedra.turnos.telefono`.
- Ambos backends comparten la misma cuenta tecnica (mismo JWT de catedra), cargada por variables de entorno.

## Dos identidades, dos JWT

```mermaid
flowchart TB
    U["Usuario final"] -- "login/registro" --> CAT
    CAT["Backend alumno"] -- "emite JWT usuario" --> U
    U -- "JWT usuario" --> TUR["Backend alumno"]
    TUR -- "JWT tecnico (nunca sale del backend)" --> API["API catedra"]
```

## Decisiones abiertas

- **[decidir]** Quien emite el JWT de usuario (propuesta: Catalogo, estilo JHipster) y como lo valida Turnos (secreto compartido HS256 o clave publica RSA).
- **[decidir]** Comunicacion Turnos -> Catalogo: propagar el JWT del usuario (propuesta, preserva identidad y trazabilidad) o usar un JWT tecnico interno.
- **[decidir]** Motor de BD de cada servicio (ambos en un mismo PostgreSQL con esquemas separados es lo mas simple).
