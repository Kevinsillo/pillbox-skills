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
4. When a decision requires explicit user input (scope, approach, testing prefs, ambiguous tradeoffs), highlight it in chat as **⚠️ User decision: …**
5. Titles (pills and prescriptions) use natural language — no `[sdd:*]` prefix. The category lives in `compound`; duplicating it in the title is redundant.

## Pillbox

- **Orchestrator**: open/close prescriptions, search/read/revise pills. Never `pill_store`.
- **Sub-agents**: receive `prescription_id`, call `pill_store` directly, return `pills_saved [{id, title}]`.

### Agents & Artifacts

| Agent | Compound | Artifact (owns) | Forbidden | Title example |
|---|---|---|---|---|
| `sdd-init` | `config` (exclusive) | project config | — | `Project configuration` |
| `sdd-explorer` | `discovery` | current-state facts, mappings, files | decisions, recommendations | `Auth flow uses legacy middleware` |
| `sdd-proposer` | `decision` | intent + scope + risks + arch decisions | detailed specs, file plan | `Replace auth middleware with JWT` |
| `sdd-specifier` | `specification` | Given/When/Then contracts per domain | DDL bodies, pseudocode, file plan | `JWT validation rules (auth domain)` |
| `sdd-architect` | `architecture` | file plan + data flow + cutover + tech risks | GWT, code, DDL bodies, pseudocode | `Stateless JWT over sessions` |
| `sdd-planner` | `task` | task checklist referencing specs + plan | re-explaining specs/decisions | `Replace auth middleware with JWT — tasks` |
| `sdd-implementer` | — | writes real files; marks tasks `[x]`; reports off-script findings via structured summary | creating ANY pills (findings travel via summary; orchestrator runs Off-script protocol) | — |
| `sdd-verifier` | `feedback` | PASS/FAIL report against specs | rewriting specs | `Verify: Replace auth middleware with JWT` |
| `sdd-archiver` | `summary` | session summary | any other compound | `Session: Replace auth middleware with JWT` |
| `sdd-committer` | — | git commit (no Pillbox) | — | — |

Bugs combine `sdd-explorer` + `sdd-proposer` under compound `bugfix` (e.g. title `Crash on modal close`).

Two agents MAY run in parallel only if they have **different compounds**, OR same compound with **explicitly disjoint domains** declared in the briefing. Otherwise serialize them.

### Pills content rules

- **No code in pills**: no code blocks, no full DDL bodies, no pseudocode >5 lines.
- **Pills contain**: decisions (chosen/discarded/why), Given/When/Then rules, file plan (one line each), text diagrams, risks + mitigations, cutover/rollback in structured prose.
- **Size**: target ~400 chars; soft limit ~2000. `pill_store` can be split into `[1]`/`[2]`; `pill_revise` updates one ID in place and can only be trimmed. The MCP tool returns the appropriate remediation in the error itself when the limit is hit.
- **Structure**: lead line must be `Purpose:`, `Decision:`, or `Rule:` — then bullets or table, no narrative prose.
- **Cross-references**: cite by pill ID (`see #75`) — never re-describe content from another pill.

### Sub-agent Launch Template

Invoke via Agent tool with `subagent_type: sdd-{agent}` and this prompt:

```
CONTEXT:
- Project: {path} | Change: {name} | Prescription ID: {id}
- Identity: {"name": "...", "email": "..."}   ← use as author in every pill_store call
- Config: {project config pill content}
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

## Identity Resolution (shared)

Run once per session, before opening any prescription or storing any pill:

1. Read `~/.pillbox/identity.json` → if it exists, load `name` + `email` as `$identity`.
2. If missing: run `git config user.name` + `git config user.email`.
   - On success: write `~/.pillbox/identity.json` with `{"name": "...", "email": "..."}` → store as `$identity`.
3. If git config fails or returns empty: ask the user for name and email → write `~/.pillbox/identity.json` → store as `$identity`.

Pass `$identity` as the `Identity` field in every sub-agent launch (see Launch Template) and in every `prescription_open` call.

## Session Start (shared)

Run at the start of every action that needs project context:
1. Identity Resolution (see above)
2. `capsule_search "{terms}"` → user prefs
3. `bottle_list` → `bottle_id`; if no bottle exists → `bottle_create` first
4. `bottle_context bottle_id` → prescription index (sessions, dates, pill_count); note any open prescription for this change
5. If open prescription: `prescription_context prescription_id` → recover actual pills of that session before passing them inline to sub-agents
6. `pill_search compound="config"` → `pill_read` → project config (compound is exclusive to this pill, so the search is unambiguous)

## Session Close (shared)

Run when ending a prescription that contains work (i.e. `continue` reaches Verify PASS):

1. Launch `sdd-archiver` → creates the `summary` pill via `pill_store`
2. `prescription_close prescription_id` → marks `ended_at`
3. Launch `sdd-committer` → creates the git commit (skip if no code changed)

The `summary` pill MUST be stored before `prescription_close` — without it the session's context is lost for future runs.

`new` and `fix` open prescriptions but do not close them: they hand off to `/sdd:continue`, which runs this sequence when the full cycle completes.

`init` is the exception: its prescription holds only the project config pill (no work to summarize), so it closes directly after `sdd-init` saves the config — no archiver, no committer.

---

## Actions

### init

1. Ensure bottle (`bottle_list` → `bottle_create` if missing); `prescription_open title="Project configuration"`
2. `TodoWrite`: [Detect stack, Save config]
3. Launch `sdd-init`; confirm `pills_saved`; `prescription_close`

---

### hub

`pill_search compound="config"`:
- **missing** → show: init / explore / new
- **exists** → show: explore / new / fix / continue / status / re-init

---

### explore

`pill_search compound="specification" query="{domain terms}"` → related specs.
Launch `sdd-explorer`. Show result.

---

### new

`prescription_open title="{change name}"` — e.g. `"Replace auth middleware with JWT"` (if already open for this change → implicit continue).
`TodoWrite`: [Load context ✓, Explore, Propose, Spec, Arch, Plan, Implement, Verify, Archive]

1. `pill_search compound="specification" query="{domain terms}"` → related specs
2. Launch `sdd-explorer`; show result; ask to proceed
3. Ask testing prefs: tests? levels? library? TDD?
4. Launch `sdd-proposer` (exploration + testing prefs); show result; ask to proceed
5. → `"Ready for /sdd:continue"`

---

### continue

`prescription_open title="{change name}"` (reuses open rx).
Determine phase → `TodoWrite` (past phases ✓, current in_progress).
`pill_read` needed pills before each sub-agent.

| Existing pills | Next |
|---|---|
| No proposal | redirect → `sdd:new` |
| No spec or arch | prefetch past `architecture` pills relevant to the domain (`pill_search compound="architecture" query="{domain terms}"`, top 2-3) and pass inline; then launch `sdd-specifier` + `sdd-architect` (parallel) |
| Spec+arch, no tasks | launch `sdd-planner` |
| Tasks not all `[x]` | launch `sdd-implementer` (batch by phase); after: `pill_revise tasks` marking `[x]`. **If `executive_summary.status != proceeding` → run Off-script protocol (below) before next batch** |
| Tasks all `[x]`, no verify | launch `sdd-verifier` |
| Verify PASS, no summary | launch `sdd-archiver` → `prescription_close` → launch `sdd-committer` |
| Closed rx + summary | "Already archived." |

After each sub-agent: show summary; ask "Continue?" → loop.

**Verify FAIL**: offer (1) fix+re-verify (create fix tasks → implement → verify loop), (2) fix manually, (3) archive anyway.

#### Off-script protocol

After each implementer batch, parse its structured summary (Bugs Found / Deviations / Discoveries) and act per the table:

| Finding from implementer | Orchestrator action |
|---|---|
| `bug in_scope=yes` | Already fixed inline. Note in chat. Continue. |
| `bug in_scope=no` + `blocks_progress=yes` | Pause implementer. **⚠️ User decision**: extend scope? If yes → relaunch `sdd-proposer` with proposal pill ID + extension instructions (proposer uses `pill_revise`). If specs/design also affected → chain `sdd-specifier`/`sdd-architect` with `pill_revise` on their pills. Update tasks pill via `pill_revise` to add the new tasks. Resume implementer. |
| `bug in_scope=no` + `blocks_progress=no` | Note in chat. Carry forward into archiver context (so it lands in `found:`). Continue. |
| `deviation` with valid `why` | Relaunch `sdd-architect` with architecture pill ID + deviation details → `pill_revise`. Continue. |
| `deviation` without valid `why` | Tell implementer to rework following the original design. Re-run the same batch. |
| `discovery` | Note in chat. Carry forward into archiver context. Continue. |
| `status: blocked` | Stop. Show the implementer's blocker. **⚠️ User decision** required before any next step. |

---

### ff (fast-forward)

Requires an open prescription from `new`. Ask testing prefs.
`TodoWrite` all phases. Run sequentially, no user prompts between:
`sdd-proposer` → `sdd-specifier` + `sdd-architect` (parallel) → `sdd-planner`
Show combined summary at end. Stop on first failure.

> Offer `ff` proactively after `new` when the change is well-scoped and the user hasn't asked to review each phase.

---

### fix

`prescription_open title="{bug summary}"` — e.g. `"Crash on modal close"`.
`TodoWrite`: [Load context ✓, Explore, Propose, Plan, Implement, Verify, Archive]

1. Launch `sdd-explorer` (focused on bug); show; ask to proceed
2. Launch `sdd-proposer` (minimal scope, skip testing prefs); show; ask to proceed
3. Launch `sdd-planner` (no specs/design — derive tasks from proposal only)
4. → `"Ready for /sdd:continue {name}"`

---

### status

`pill_search compound="decision"` (optionally narrow by query).
For each: check tasks `[x]` count, verify pill, prescription state.

```
| Change                    | Phase        | Tasks | Status   |
|---------------------------|--------------|-------|----------|
| Add search feature        | implementing | 5/12  | active   |
| Fix crash on modal close  | done         | 3/3   | archived |
```

---
