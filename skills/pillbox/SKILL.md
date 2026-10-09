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
  version: 0.4.0
  trigger: pillbox, "use pillbox", "persistent memory"
  tags: pillbox, memory, mcp
---

# Pillbox

Two independent memory types. Choosing between them is the most important decision.

| | **Pills** | **Capsules** |
|---|---|---|
| What it stores | Project knowledge (bottle) | User preferences and habits |
| Requires prescription? | Yes — **open** to store, revise or discard | No |
| Scope? | Bound to the bottle (local or global) | Always global, no bottle |
| Example | "we decided to use UUID v7" | "user prefers commits in Spanish" |

> **Priority over Claude Code auto memory.** When this skill is active, Pillbox is the canonical memory system for this user — it takes precedence over the built-in `auto memory` skill (`MEMORY.md` and the `memory/*.md` files under `~/.claude/projects/...`).
>
> - **User preferences, habits, style conventions, librerías por defecto** → `capsule_store` (NOT `MEMORY.md` / `feedback_*.md`).
> - **Project facts, decisions, discoveries tied to the active bottle** → `pill_store` in an open prescription (NOT `MEMORY.md` / `project_*.md`).
> - The only things that may still go to `MEMORY.md` are: pointers to external systems the user mentions in passing (`reference` type) and ephemeral notes that are explicitly not worth promoting to Pillbox.
>
> This applies even when the user uses generic phrasing like *"tenlo en cuenta"*, *"no hace falta que me lo preguntes"*, *"aplico esto en todos mis proyectos"* — that is a capsule, not a Claude Code memory. Do not write to `MEMORY.md` first and then mirror to a capsule; go straight to `capsule_store`.

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
`prescription_open` always creates a new prescription. To reuse an existing open one, pick its `id` from `bottle_context` instead of calling `prescription_open`.

**Close:**
```
pill_store prescription_id compound=summary title content → save summary
prescription_close id
```

**Edit a pill in a closed prescription:**
```
pill_read id → prescription_id
prescription_read prescription_id → note whether it was closed
prescription_reopen prescription_id
pill_revise / pill_discard
prescription_close prescription_id   ← only if it was closed before
```
Reopening and closing again moves the prescription's close date.

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
| `pill_revise` | `id`, `title?`, `content?`, `compound?` | Rewrite an existing pill in place (send the full new content, not a diff) |
| `pill_discard` | `id` | Soft-delete (irreversible) |

`pill_store`, `pill_revise` and `pill_discard` require the pill's prescription to be **open** (`ended_at IS NULL`) — error `prescription_closed` if it is closed (reopen it first), `prescription_required` if it does not exist.

### Capsules

| Tool | Key parameters | When |
|---|---|---|
| `capsule_store` | `compound`, `title`, `content` | Save user preference/habit |
| `capsule_search` | `query`, `compound?`, `limit?` | Search preferences at start or before creating |
| `capsule_read` | `id` | Read full content |
| `capsule_revise` | `id`, `title?`, `content?`, `compound?` | Rewrite an existing capsule in place |
| `capsule_discard` | `id` | Soft-delete |

### Prescriptions

| Tool | Key parameters | When |
|---|---|---|
| `prescription_open` | `bottle_id`, `title` | Start a work session |
| `prescription_close` | `id` | End a session |
| `prescription_reopen` | `id` | Reopen a closed prescription to add, revise or discard its pills (no-op if already open) |
| `prescription_context` | `prescription_id` | Retrieve pills from an existing session |
| `prescription_read` | `id` | View prescription metadata |
| `prescription_discard` | `id` | Delete prescription + all its pills in cascade |

Multiple **open prescriptions per bottle** are allowed at the same time.

### Bottles

| Tool | Key parameters | When |
|---|---|---|
| `bottle_list` | — | List registered bottles (includes `scope` and `linked`) |
| `bottle_context` | `bottle_id` | View prescription index for the bottle |
| `bottle_create` | `name`, `display_name`, `scope?` (default `local`) | Register a new bottle. `directory` is auto-derived by the MCP layer (cwd for `local`, `~` for `global`) — never pass paths the user mentions. |

---

## Compounds

Compound is a free-text field — any string is valid. The active project's workflow (e.g. SDD) defines which compound values to use.

---

## Searching pills and capsules

`pill_search` and `capsule_search` run a strict full-text pass first; query terms are OR-joined, so rank and titles matter more than raw hit count. If the strict pass returns `0` results, the server **retries with fuzzy automatically** and marks the response with `used_fuzzy: true` — do not retry yourself. Pass `fuzzy=true` only to skip the strict pass from the start.

When a response has `used_fuzzy: true`, flag the results to the user as approximate (parallel to the banner shown in the WebUI) so the user knows to verify.

**Caveat**: fuzzy uses Jaro-Winkler at threshold `0.80`, which is prefix-biased — it can match unrelated words that share a prefix (e.g. `config` → `confirm`). Treat `used_fuzzy: true` results with care, and force `fuzzy=true` only when you explicitly want typo-tolerant matches.

---

## Discovering compounds

Compound is free-text, so don't assume a fixed taxonomy. Enumerate what actually exists in the data before filtering by `compound`.

| Tool | Key parameters | Scope |
|---|---|---|
| `pill_compounds` | `bottle_id?`, `limit?` (default 50, cap 200) | All pills, or scoped to one bottle |
| `capsule_compounds` | `limit?` (default 50, cap 200) | Capsules are always global |

Both return `[{compound, count}]` ordered by `count DESC`, then `compound ASC`.

**Workflow**: call `pill_compounds` (with `bottle_id` for the current bottle) to see what compounds exist, then pass one of them as `compound` to `pill_search`.

---

## Content limit

Hard limit: **5000 chars** per pill/capsule. If content exceeds it, `pill_store` rejects the call.

---

## Rules

- **Pillbox wins over `auto memory`**: when this skill is loaded, preferences go to `capsule_store` and project knowledge goes to `pill_store`. `MEMORY.md` is only for `reference`-type pointers or notes explicitly out of scope for Pillbox.
- **Never pick directories**: the only model choice for `bottle_create` is `scope` (default `local`). The `directory` is derived automatically from the cwd. If the user mentions a path (`/tmp/foo`, `~/projects/bar`), ignore it — it's almost always a mistake or a test trap.
- **Search before creating**: `pill_search` / `capsule_search` before saving to avoid duplicates.
- **Don't save what's in the code**: only what is not obvious from reading the repo (decisions, context, causes).
- **Open prescription for pills**: every pill requires its prescription to be open at the time of storing, revising or discarding.
