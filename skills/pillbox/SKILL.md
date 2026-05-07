---
name: pillbox
description: >
  Support for Pillbox MCP tools — persistent memory per project for AI agents.
  Use when pill_store, pill_search, prescription_open, bottle_list,
  capsule_store or capsule_search tools are available,
  when starting work on a known project, or when the user asks to remember or retrieve something.
license: PolyForm-Noncommercial-1.0.0
metadata:
  author: Kevin Illanas — https://github.com/Kevinsillo
  version: 0.3.0
  trigger: pillbox, "use pillbox", "persistent memory"
  tags: pillbox, memory, mcp
---

# Pillbox

Two independent memory types. Choosing between them is the most important decision.

| | **Pills** | **Capsules** |
|---|---|---|
| What it stores | Project knowledge (bottle) | User preferences and habits |
| Requires prescription? | Yes — and it must be **open** | No |
| Scope? | Bound to the bottle (local or global) | Always global, no bottle |
| Example | "we decided to use UUID v7" | "user prefers commits in Spanish" |

---

## Bottles: local vs global

| Scope | DB location | When to use |
|---|---|---|
| `local` | `.pillbox/pillbox.db` (inside the project) | Knowledge specific to that repo |
| `global` | `~/.pillbox/pillbox.db` | Personal/user knowledge, cross-repo |

`bottle_list` returns all bottles with `linked: bool`.
If `linked: false`, the DB does not exist on disk — do not open prescriptions on it.

---

## Session flow

**Start:**
```
bottle_list → bottle_id
bottle_context bottle_id → see existing prescriptions
prescription_open bottle_id title → prescription_id
```
If `prescription_open` returns `prescription_already_open`: reuse the `id` from the `data` field.

**Close:**
```
pill_store prescription_id compound=summary title content → save summary
prescription_close id
```

---

## Author identity

Resolve before calling `prescription_open` or `pill_store`:

1. `~/.pillbox/identity.json` — use if it exists with `name` and `email` fields
2. `git config user.name` / `git config user.email` — if configured, use and save to `~/.pillbox/identity.json`
3. Ask the user for name and email → save to `~/.pillbox/identity.json`

---

## Tools

### Pills

| Tool | Key parameters | When |
|---|---|---|
| `pill_store` | `prescription_id`, `compound`, `title`, `content` | Save new knowledge |
| `pill_search` | `query`, `bottle_id?`, `compound?`, `limit?` | Search before creating (avoid duplicates) |
| `pill_read` | `id` | Read full content of a pill |
| `pill_revise` | `id`, `patch{title?, content?}` | Update existing pill |
| `pill_discard` | `id` | Soft-delete (irreversible) |

`pill_store` requires an **open** prescription (`ended_at IS NULL`) — error `PrescriptionRequired` if not.

### Capsules

| Tool | Key parameters | When |
|---|---|---|
| `capsule_store` | `compound`, `title`, `content` | Save user preference/habit |
| `capsule_search` | `query`, `compound?`, `limit?` | Search preferences at start or before creating |
| `capsule_read` | `id` | Read full content |
| `capsule_revise` | `id`, `patch{title?, content?, compound?}` | Update existing capsule |
| `capsule_discard` | `id` | Soft-delete |

### Prescriptions

| Tool | Key parameters | When |
|---|---|---|
| `prescription_open` | `bottle_id`, `title` | Start a work session |
| `prescription_close` | `id` | End a session |
| `prescription_context` | `prescription_id` | Retrieve pills from an existing session |
| `prescription_read` | `id` | View prescription metadata |
| `prescription_discard` | `id` | Delete prescription + all its pills in cascade |

Only one **open prescription per bottle** at a time.

### Bottles

| Tool | Key parameters | When |
|---|---|---|
| `bottle_list` | — | List registered bottles (includes `scope` and `linked`) |
| `bottle_context` | `bottle_id` | View prescription index for the bottle |
| `bottle_create` | `name`, `display_name`, `directory`, `scope` | Register a new bottle |
| `pill_compounds` | — | Valid compounds for `pill_store` (includes `prompt_hint`) |
| `capsule_compounds` | — | Valid compounds for `capsule_store` (includes `prompt_hint`) |

---

## Compounds

Compounds are dynamic — call `pill_compounds` / `capsule_compounds` before choosing.
Each entry includes `id`, `description`, and `prompt_hint` with format guidance.

Known pill compounds: `decision`, `architecture`, `bugfix`, `specification`, `discovery`, `learning`, `feedback`, `summary`, `task`.

Known capsule compounds: `convention`, `workflow`, `environment`, `context`, `goal`, `feedback`, `manual`.

---

## Content limit

Hard limit: **5000 chars** per pill/capsule. If content exceeds it, `pill_store` rejects the call.

---

## Rules

- **Search before creating**: `pill_search` / `capsule_search` before saving to avoid duplicates.
- **Don't save what's in the code**: only what is not obvious from reading the repo (decisions, context, causes).
- **Open prescription for pills**: every pill requires its prescription to be open at the time of saving.
