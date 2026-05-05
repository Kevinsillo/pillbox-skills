---
name: pillbox
description: >
  Apoyo para las MCP tools de Pillbox — memoria persistente por proyectos para agentes IA.
  Usar cuando las herramientas pill_store, pill_search, prescription_open, bottle_list,
  capsule_store o capsule_search están disponibles,
  al empezar trabajo en un proyecto conocido, o cuando el usuario pide recordar o recuperar algo.
license: PolyForm-Noncommercial-1.0.0
metadata:
  author: https://github.com/Kevinsillo
  version: 0.2.0
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

Cada bottle tiene un `scope` que determina dónde vive su DB:

| Scope | DB location | Cuándo usarlo |
|---|---|---|
| `local` | `.pillbox/pillbox.db` (dentro del proyecto) | Conocimiento específico de ese repo |
| `global` | `~/.pillbox/pillbox.db` | Conocimiento personal/usuario, cross-repo |

`bottle_list` devuelve todos los bottles registrados con el campo `linked: bool`.
Si `linked: false`, la DB no existe en disco (proyecto movido o eliminado) — no abrir prescriptions sobre él.

---

## Arranque de sesión

```json
{ "tool": "capsule_search", "query": "<términos relevantes>" }
{ "tool": "bottle_list" }
{ "tool": "bottle_context", "bottle_id": "<uuid>" }
{ "tool": "prescription_open", "bottle_id": "<uuid>", "title": "<descripción de la tarea>" }
```

Si `prescription_open` devuelve `prescription_already_open`: el campo `data` contiene la prescripción
activa — reutilizar ese `id` directamente sin abrir otra.

Solo abrir prescription sobre bottles con `linked: true`.

---

## Cierre de sesión

```json
{ "tool": "pill_store", "prescription_id": "<uuid>", "compound": "prescription_summary", "title": "<título>", "content": "<resumen>" }
{ "tool": "prescription_close", "id": "<uuid>" }
```

`prescription_summary` es **obligatorio** antes de cerrar. Sin él se pierde el contexto de la sesión.

---

## Tools completas

### Pills

| Tool | Parámetros clave | Cuándo |
|---|---|---|
| `pill_store` | `prescription_id`, `compound`, `title`, `content` | Guardar conocimiento nuevo |
| `pill_search` | `query`, `bottle_id?`, `compound?`, `limit?` | Buscar antes de crear (evitar duplicados) |
| `bottle_context` | `bottle_id`, `limit?` | Índice de prescriptions al inicio de sesión |
| `prescription_context` | `prescription_id`, `limit?` | Pills de una prescription concreta |
| `pill_read` | `id` | Leer contenido completo de una pill |
| `pill_revise` | `id`, `patch{title?, content?}` | Actualizar pill existente |
| `pill_discard` | `id` | Soft-delete (irreversible) |

`pill_store` requiere `prescription_id` de una prescription **abierta** (`ended_at IS NULL`).
Si la prescription está cerrada o descartada, devuelve error `PrescriptionRequired`.

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
| `prescription_read` | `id` | Ver detalles de una prescripción |
| `prescription_discard` | `id` | Eliminar prescripción + todas sus pills en cascada |

Solo puede haber **una prescription abierta por bottle** al mismo tiempo.

### Bottles

| Tool | Parámetros clave | Cuándo |
|---|---|---|
| `bottle_list` | — | Listar bottles registrados (incluye `scope` y `linked`) |
| `bottle_create` | `name`, `display_name`, `directory`, `scope` | Registrar bottle nuevo (normalmente lo hace el CLI) |
| `stats` | — | Idéntico a `bottle_list` |
| `pill_compounds` | — | Compounds disponibles para pill_store |
| `capsule_compounds` | — | Compounds disponibles para capsule_store |

---

## Compounds

Los compounds son dinámicos. Consultar antes de elegir:
- `pill_compounds` → lista de compounds válidos para `pill_store`
- `capsule_compounds` → lista de compounds válidos para `capsule_store`

Cada entry incluye `id`, `description` y `prompt_hint` con instrucciones de formato.

Compounds conocidos de pills: `decision`, `architecture`, `bugfix`, `pattern`, `discovery`, `learning`, `feedback`, `prescription_summary`, `manual`.

Compounds conocidos de capsules: `convention`, `workflow`, `environment`, `context`, `goal`, `feedback`, `manual`.

---

## Formato de contenido

Las pills las lee una IA, no un humano. Máxima densidad, mínimos tokens.
Target: 100–400 chars. El límite es 5000 — es un techo, no un objetivo.

```
# decision / architecture / bugfix
symptom/context: una línea
chosen/fix: qué y por qué
discarded: alternativas descartadas (si las hay)

# pattern / discovery / learning
Prosa técnica densa, 1-2 frases. Sin cabeceras.

# prescription_summary
goal: una línea
done: bullet por item logrado
found: descubrimientos no obvios (omitir si ninguno)
next: pendiente
files: solo los modificados significativamente
```

---

## Reglas

- **Buscar antes de crear**: `pill_search` / `capsule_search` antes de `pill_store` / `capsule_store` para evitar duplicados.
- **No guardar lo que está en el código**: solo lo que no es obvio leyendo el repo (decisiones, contexto, causas).
- **prescription_summary siempre**: sin él, el contexto de la sesión se pierde para futuras sesiones.
- **Prescription abierta para pills**: toda pill requiere que su prescription esté abierta en el momento de guardarla.
- **Subagentes no usan MCP**: solo el orquestrador llama `pill_store`. Los subagentes devuelven hallazgos estructurados y el orquestrador consolida antes de guardar.
