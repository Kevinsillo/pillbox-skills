---
name: pillbox
description: >
  Apoyo para las MCP tools de Pillbox — memoria persistente por proyectos para agentes IA.
  Usar cuando las herramientas pill_store, pill_search, prescription_open, bottle_list,
  capsule_store o capsule_search están disponibles,
  al empezar trabajo en un proyecto conocido, o cuando el usuario pide recordar o recuperar algo.
license: PolyForm-Noncommercial-1.0.0
metadata:
  author: Kevin Illanas — https://github.com/kevinsillo
  version: 0.3.0
  trigger: pillbox, "usar pillbox", "memoria persistente"
  tags: pillbox, memory, mcp
---

# Pillbox

Dos tipos de memoria independientes. La elección entre ellos es la decisión más importante.

| | **Pills** | **Capsules** |
|---|---|---|
| ¿Qué guarda? | Conocimiento de un proyecto (bottle) | Preferencias y hábitos del usuario |
| ¿Requiere prescription? | Sí — y debe estar **abierta** | No |
| ¿Scope? | Ligado al bottle (local o global) | Siempre global, sin bottle |
| Ejemplo | "decidimos usar UUID v7" | "el usuario prefiere commits en español" |

---

## Bottles: local vs global

| Scope | DB location | Cuándo usarlo |
|---|---|---|
| `local` | `.pillbox/pillbox.db` (dentro del proyecto) | Conocimiento específico de ese repo |
| `global` | `~/.pillbox/pillbox.db` | Conocimiento personal/usuario, cross-repo |

`bottle_list` devuelve todos los bottles con `linked: bool`.
Si `linked: false`, la DB no existe en disco — no abrir prescriptions sobre él.

---

## Flujo de sesión

**Inicio:**
```
bottle_list → bottle_id
bottle_context bottle_id → ver prescriptions existentes
prescription_open bottle_id title → prescription_id
```
Si `prescription_open` devuelve `prescription_already_open`: reutilizar el `id` del campo `data`.

**Cierre:**
```
pill_store prescription_id compound=prescription_summary title content → guardar resumen
prescription_close id
```

---

## Tools

### Pills

| Tool | Parámetros clave | Cuándo |
|---|---|---|
| `pill_store` | `prescription_id`, `compound`, `title`, `content` | Guardar conocimiento nuevo |
| `pill_search` | `query`, `bottle_id?`, `compound?`, `limit?` | Buscar antes de crear (evitar duplicados) |
| `pill_read` | `id` | Leer contenido completo de una pill |
| `pill_revise` | `id`, `patch{title?, content?}` | Actualizar pill existente |
| `pill_discard` | `id` | Soft-delete (irreversible) |

`pill_store` requiere prescription **abierta** (`ended_at IS NULL`) — error `PrescriptionRequired` si no.

### Capsules

| Tool | Parámetros clave | Cuándo |
|---|---|---|
| `capsule_store` | `compound`, `title`, `content` | Guardar preferencia/hábito del usuario |
| `capsule_search` | `query`, `compound?`, `limit?` | Buscar preferencias al inicio o antes de crear |
| `capsule_read` | `id` | Leer contenido completo |
| `capsule_revise` | `id`, `patch{title?, content?, compound?}` | Actualizar capsule existente |
| `capsule_discard` | `id` | Soft-delete |

### Prescriptions

| Tool | Parámetros clave | Cuándo |
|---|---|---|
| `prescription_open` | `bottle_id`, `title` | Iniciar sesión de trabajo |
| `prescription_close` | `id` | Finalizar sesión |
| `prescription_context` | `prescription_id` | Recuperar pills de una sesión existente |
| `prescription_read` | `id` | Ver metadatos de una prescripción |
| `prescription_discard` | `id` | Eliminar prescripción + todas sus pills en cascada |

Solo puede haber **una prescription abierta por bottle** al mismo tiempo.

### Bottles

| Tool | Parámetros clave | Cuándo |
|---|---|---|
| `bottle_list` | — | Listar bottles registrados (incluye `scope` y `linked`) |
| `bottle_context` | `bottle_id` | Ver índice de prescriptions del bottle |
| `bottle_create` | `name`, `display_name`, `directory`, `scope` | Registrar bottle nuevo |
| `pill_compounds` | — | Compounds válidos para `pill_store` (incluye `prompt_hint`) |
| `capsule_compounds` | — | Compounds válidos para `capsule_store` (incluye `prompt_hint`) |

---

## Compounds

Los compounds son dinámicos — consultar `pill_compounds` / `capsule_compounds` antes de elegir.
Cada entry incluye `id`, `description` y `prompt_hint` con orientación de formato.

Compounds conocidos de pills: `decision`, `architecture`, `bugfix`, `pattern`, `discovery`, `learning`, `feedback`, `prescription_summary`, `manual`.

Compounds conocidos de capsules: `convention`, `workflow`, `environment`, `context`, `goal`, `feedback`, `manual`.

---

## Límite de contenido

Límite duro: **5000 chars** por pill/capsule. Si el contenido lo supera, `pill_store` rechaza la llamada.

---

## Reglas

- **Buscar antes de crear**: `pill_search` / `capsule_search` antes de guardar para evitar duplicados.
- **No guardar lo que está en el código**: solo lo que no es obvio leyendo el repo (decisiones, contexto, causas).
- **Prescription abierta para pills**: toda pill requiere que su prescription esté abierta en el momento de guardarla.
