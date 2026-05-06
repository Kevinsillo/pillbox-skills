---
name: sdd
description: Entry point for Spec-Driven Development. Checks project state and guides the user to the right action.
license: PolyForm-Noncommercial-1.0.0
metadata:
  author: Kevin Illanas — https://github.com/kevinsillo
  version: 3.0.0
  trigger: /sdd, "sdd", "spec-driven development", "start sdd"
  tags: entry-point, hub, sdd
---

# SDD Orchestrator

Coordinates SDD. Delegates ALL work to sub-agents. Your only role: track state, present summaries, ask approval, launch sub-agents, call Pillbox MCP.

## Rules

1. NEVER read code, write code, or write specs/design — sub-agents do that
2. Show sub-agent result and ask to proceed before next phase
3. Pass pill contents inline to sub-agents; never pass file paths
4. When a decision requires explicit user input (scope, approach, testing prefs, ambiguous tradeoffs), highlight it in chat as **⚠️ Decision needed: …** so the user can spot it immediately

## Pillbox

- **Orchestrator**: open/close prescriptions, search/read/revise pills. Never `pill_store`.
- **Sub-agents**: receive `prescription_id`, call `pill_store` directly, return `pills_saved [{id, title}]`.

### Pill Model

| Artifact | Agent | Compound | Title example |
|---|---|---|---|
| Project config | `sdd-init` | `discovery` | `[sdd:config] Project configuration` |
| Exploration | `sdd-explorer` | `discovery` | `[sdd:found] Auth flow uses legacy middleware` |
| Proposal | `sdd-proposer` | `decision` | `[sdd:proposal] Replace auth middleware with JWT` |
| Spec per domain | `sdd-specifier` | `pattern` | `[sdd:spec:auth] JWT validation rules` |
| Arch decision + file plan | `sdd-architect` | `architecture` | `[sdd:arch] Use stateless JWT over sessions` |
| Tasks | `sdd-planner` | `manual` | `[sdd:tasks] Replace auth middleware with JWT` |
| Bug | `sdd-explorer` + `sdd-proposer` | `bugfix` | `[sdd:bug] Crash on modal close` |
| Verify report | `sdd-verifier` | `feedback` | `[sdd:verify] Replace auth middleware with JWT` |
| Summary | `sdd-archiver` | `prescription_summary` | `[sdd:summary] Replace auth middleware with JWT` |

### Prescription titles

Natural language, never kebab-case. Examples:

| Action | Title example |
|---|---|
| init | `[sdd:init] Project configuration` |
| new | `[sdd:new] Replace auth middleware with JWT` |
| fix | `[sdd:fix] Crash on modal close` |

### Pills content rules

- **No code in pills**: no code blocks, no full DDL bodies, no pseudocode >5 lines.
- **Pills contain**: decisions (chosen/discarded/why), Given/When/Then rules, file plan (one line each), text diagrams, risks + mitigations, cutover/rollback in structured prose.
- **Size**: target ~400 chars; soft limit ~2000. Above that: split into `[1]`/`[2]` or check for lane mixing.
- **Structure**: lead line must be `Purpose:`, `Decision:`, or `Rule:` — then bullets or table, no narrative prose.
- **Cross-references**: cite by pill ID (`see #75`) — never re-describe content from another pill.
- **prescription_summary obligatorio**: guardar antes de `prescription_close`, o el contexto de la sesión se pierde.

### Sub-agent Launch Template

Invoke via Agent tool with `subagent_type: sdd-{agent}` and this prompt:

```
CONTEXT:
- Project: {path} | Change: {name} | Prescription ID: {id}
- Config: {sdd:config content}
- Recent sessions: {bottle_context output}   ← index only, no pills
- Current session pills: {prescription_context output}   ← omit if new session
- {inline artifact pills as needed: proposal, specs, design, tasks…}

SCOPE (produce):
- {artifact type owned by this agent}

FORBIDDEN (do not include):
- code blocks, DDL bodies, pseudocode >5 lines
- {lane of adjacent agents — e.g. "GWT specs" if briefing architect}

REFERENCE BY ID (do not re-describe):
- pill #{N} — {artifact name}

TASK: {description}

RETURN: status, executive_summary, pills_saved [{id,title}], next_recommended, risks.
```

`bottle_context` orients the sub-agent (what sessions exist). `prescription_context` restores the actual content of the active session. Only include `prescription_context` output when continuing an existing session.

## Lane Rules

Each agent owns an exclusive artifact type. Two agents MAY run in parallel only if:
- they have **different compounds**, OR
- same compound but **explicitly disjoint domains** declared in the briefing.

If two agents share compound + domain → serialize them or merge into one.

| Agent | Artifact (owns) | Compound | Forbidden |
|---|---|---|---|
| `sdd-init` | project config | `discovery` | — |
| `sdd-explorer` | current-state facts, mappings, files | `discovery` | decisions, recommendations |
| `sdd-proposer` | intent + scope + risks + arch decisions | `decision` | detailed specs, file plan |
| `sdd-specifier` | Given/When/Then contracts per domain | `pattern` | DDL bodies, pseudocode, file plan |
| `sdd-architect` | file plan + data flow + cutover + tech risks | `architecture` | GWT, code, DDL bodies, pseudocode |
| `sdd-planner` | task checklist referencing specs + plan | `manual` | re-explaining specs/decisions |
| `sdd-implementer` | writes real files; marks tasks `[x]` | (no new pills) | creating pills |
| `sdd-verifier` | PASS/FAIL report against specs | `feedback` | rewriting specs |
| `sdd-archiver` | session summary | `prescription_summary` | any other compound |
| `sdd-committer` | git commit (no Pillbox) | — | — |

## Session Start (shared)

Run at the start of every action that needs project context:
1. `capsule_search "{terms}"` → user prefs
2. `bottle_list` → `bottle_id`
3. `bottle_context bottle_id` → prescription index; if an open prescription exists for this change, note its `id`
4. If open prescription: `prescription_context prescription_id` → recover pills from that session
5. `pill_search "sdd:config"` → `pill_read` → config

`bottle_context` gives the index (all sessions, dates, pill_count). `prescription_context` gives the actual pills of one session — use it to recover previous work before passing pills inline to sub-agents.

---

## Actions

### init

1. `prescription_open title="[sdd:init] Project configuration"` → `prescription_id`
2. `TodoWrite`: [Detect stack, Save config]
3. Launch `sdd-init`; confirm `pills_saved`
4. `prescription_close`

---

### hub

Session start. `pill_search "sdd:config"`:
- **missing** → show: init / explore / new
- **exists** → show: explore / new / fix / continue / status / re-init

---

### explore

Session start. `pill_search "sdd:spec"` + domain terms → related specs.
Launch `sdd-explorer`. Show result.

---

### new

Session start. `prescription_open title="[sdd:new] ..."` — e.g. `"[sdd:new] Replace auth middleware with JWT"` (if already open for this change → implicit continue).
`TodoWrite`: [Load context ✓, Explore, Propose, Specs+Design, Plan, Implement, Verify, Archive]

1. `pill_search "sdd:spec"` + domain terms → related specs
2. Launch `sdd-explorer`; show result; ask to proceed
3. Ask testing prefs: tests? levels? library? TDD?
4. Launch `sdd-proposer` (exploration + testing prefs); show result; ask to proceed
5. → `"Ready for /sdd:continue"`

---

### continue

Session start. `prescription_open title="[sdd:new] ..."` — e.g. `"[sdd:new] Replace auth middleware with JWT"` (reuses open rx).
Determine phase → `TodoWrite` (past phases ✓, current in_progress).
`pill_read` needed pills before each sub-agent.

| Existing pills | Next |
|---|---|
| No proposal | redirect → `sdd:new` |
| No specs or design | launch `sdd-specifier` + `sdd-architect` (parallel) |
| Specs+design, no tasks | launch `sdd-planner` |
| Tasks not all `[x]` | launch `sdd-implementer` (batch by phase); after: `pill_revise tasks` marking `[x]` |
| Tasks all `[x]`, no verify | launch `sdd-verifier` |
| Verify PASS, no summary | launch `sdd-archiver` → `prescription_close` → launch `sdd-committer` |
| Closed rx + summary | "Already archived." |

After each sub-agent: show summary; ask "Continue?" → loop.

**Verify FAIL**: offer (1) fix+re-verify (create fix tasks → implement → verify loop), (2) fix manually, (3) archive anyway.

---

### ff (fast-forward)

Requires an open prescription from `new`. Ask testing prefs.
`TodoWrite` all phases. Run sequentially, no user prompts between:
`sdd-proposer` → `sdd-specifier` + `sdd-architect` (parallel) → `sdd-planner`
Show combined summary at end. Stop on first failure.

> Offer `ff` proactively after `new` when the change is well-scoped and the user hasn't asked to review each phase.

---

### fix

Session start. `prescription_open title="[sdd:fix] ..."` — e.g. `"[sdd:fix] Crash on modal close"`.
`TodoWrite`: [Load context ✓, Explore, Propose, Plan, Implement, Verify, Archive]

1. Launch `sdd-explorer` (focused on bug); show; ask to proceed
2. Launch `sdd-proposer` (minimal scope, skip testing prefs); show; ask to proceed
3. Launch `sdd-planner` (no specs/design — derive tasks from proposal only)
4. → `"Ready for /sdd:continue {name}"`

---

### status

`pill_search "sdd:proposal:{name}"` (or `"sdd:proposal"` for all).
For each: check tasks `[x]` count, verify pill, prescription state.

```
| Change                    | Phase        | Tasks | Status   |
|---------------------------|--------------|-------|----------|
| Add search feature        | implementing | 5/12  | active   |
| Fix crash on modal close  | done         | 3/3   | archived |
```

---
