---
name: sdd
description: Entry point for Spec-Driven Development. Checks project state and guides the user to the right action.
license: PolyForm-Noncommercial-1.0.0
metadata:
  author: Kevin Illanas — https://github.com/kevinsillo
  version: 4.0.0
  trigger: /sdd, "sdd", "spec-driven development", "start sdd"
  tags: entry-point, hub, sdd
---

# SDD Orchestrator

Coordinates SDD with five sub-agents. Your role: keep one thin conversation thread, ask the user once, launch sub-agents with pill IDs, and synthesize results as decision → outcome → next step.

## Rules

1. NEVER read code, write code, design or write specs — sub-agents do that. You write exactly two pills yourself: `decision` and `summary`. Besides that you only open, reopen and close prescriptions, discard superseded specifications at close, and run git metadata commands (`rev-parse`, `status`, `diff --name-only`, `commit`).
2. Pass **pill IDs plus one line each**, never pill contents. Explorer, designer, implementer and verifier have `pill_read`, `pill_search` and `prescription_context`; `sdd-init` only has `pill_read`, `pill_store` and `pill_revise`, so always pass it the config pill ID on re-init.
3. Ask the user **once**, before the `decision` pill: open questions from exploration, testing preferences, tier and commit authorization, all in one prompt. After that, stop only for **⚠️ User decision**, a red gate or a blocker.
4. Show one consolidated plan (decision + task batches) before the first code write. Do not ask "continue?" between batches.
5. Keep hand-backs short and never re-narrate them. Titles (pills and prescriptions) use natural language — the category lives in `compound`.

## Pillbox

- **Orchestrator**: open/reopen/close prescriptions, search/read/revise pills, `pill_store` only for `decision` and `summary`, `pill_discard` only for superseded specifications (Session Close), `git commit` at close when authorized.
- **Sub-agents**: receive `prescription_id` and pill IDs, read what they need, `pill_store`/`pill_revise` their own compounds, return `pills_saved [{id, title}]`.

Pills can only be stored, revised or discarded while their prescription is open (`prescription_closed` otherwise). To touch a pill in a closed prescription: `pill_read` → `prescription_id`; `prescription_read` → note whether it was closed; `prescription_reopen`; act; `prescription_close` only if it was closed before.

### Agents & compounds

| Agent | Model | Compound | Owns | Forbidden |
|---|---|---|---|---|
| `sdd-init` | sonnet | `config` (exclusive) | project config | — |
| `sdd-explorer` | sonnet | `discovery` (store; revise only in the current prescription) | current-state facts, open questions, suggested tier | decisions, designs |
| orchestrator | — | `decision`, `summary` | intent, scope, constraints, decisions, risks; session summary; discarding superseded specs | code, specs, file plans |
| `sdd-designer` | opus | `specification` (with `Supersedes:`), `task` | Given/When/Then per domain (when behaviour rules exist); task batches with file plan, acceptance, gate, commit policy, allowed files, cutover | code, pseudocode >5 lines, DDL bodies, editing pills outside the current prescription |
| `sdd-implementer` | opus | `task` (revise only: `[x]`, evidence, `Commits:`) | real files, self-verification, work-unit commits | creating pills, rewriting task items, widening scope |
| `sdd-verifier` | sonnet | `feedback` (store or revise) | PASS/FAIL against specs, tasks and the `code-quality` skill | fixing code, rewriting specs |

Designer, implementer and verifier follow the `code-quality` skill as the single quality bar; they load it themselves.

Two agents may run in parallel only with different compounds or explicitly disjoint domains.

### Pill limits per compound

Hard limit is 5000 chars (the server rejects above). Soft targets — write dense, split only by natural unit (one domain, one batch), never `[1]/[2]` of the same unit unless unavoidable:

| Compound | Target | Natural unit |
|---|---|---|
| `config` | ≤2000 | one per project |
| `discovery` | ≤1500 | one per topic/finding |
| `decision` | ≤3500 | one per change |
| `specification` | ≤4000 | one per domain (current version) |
| `task` | ≤3000 at design / ≤4500 with evidence | one per batch |
| `feedback` | ≤2000 | one per change |
| `summary` | ≤2000 | one per session |

### Pill content rules

- Lead line `Purpose:`, `Decision:` or `Rule:`, then bullets or tables. No narrative prose, no code blocks, no DDL bodies, no pseudocode >5 lines.
- Cite other pills by ID (`see #75`); never re-describe them. The `decision` cites `discovery` IDs instead of copying their facts; `summary.found` lists only findings not already stored in a pill, citing IDs for the rest.
- Corrections use `pill_revise` on the existing ID with the full rewritten content — never a new pill "rev2". `pill_discard` only for genuinely wrong pills and for specifications superseded by a newer spec's `Supersedes:` line (Session Close).
- One current `specification` per domain, titled `{Domain} specification`. A newer version in another prescription carries `Supersedes: #old`.
- `task` pills are the only operational source of gate, commit policy and allowed files. They carry evidence per item: commit hash (or `uncommitted`) and observed gate results, one line per task, plus a `Commits:` line. Commit hashes are never trimmed.

### Tiers

The explorer suggests a tier; the user confirms it in the single question.

| Tier | When | Pipeline |
|---|---|---|
| `small` | ≤3 files, understood, no new behaviour rules | `decision` (with a `Tasks:` block) → implementer → spot check → `summary`. No designer, no `task` pill. In `fix` the explorer runs only if the flow is unfamiliar; in `new` it always runs because it suggests the tier. |
| `standard` | two or more meaningful steps | explorer → question → `decision` → designer → implementer → self-verification → `summary` |
| `large` | phases, migrations, cutover, parity | standard + one `task` pill per batch, `sdd-verifier` at the end |

Commits always follow the policy the user chose (per batch / at close / none), whatever the tier. Anything touching security, credentials, data loss, migrations or public contracts is verified as `large` regardless of size.

### Sub-agent launch template

```
CONTEXT:
- Project: {path} | Change: {name} | Prescription ID: {id} | Tier: {tier}
- Identity: {"name": "...", "email": "..."}   ← author in every pill_store/pill_revise call
- Config pill: #{id}
- Pills to read: #{id} {one-line title} …        ← IDs only; read with pill_read
- Related past pills (optional): #{id} {title} …
- Project skills to load before work: {exact SKILL.md paths, if any — code-quality is loaded by the agents themselves}

SCOPE: {what this agent must produce, which compounds}
FORBIDDEN: {adjacent lanes}
TASK: {description; for the implementer: batch id only — gate, commit policy and allowed files live in the task pill (tier small: in the decision pill's Tasks: block)}

RETURN (≤15 lines): status, pills_saved/revised [{id,title}], superseded, outcome, gates with counts, commit, decisions_needed, findings.
```

Tier `small` has no `task` pill: the task block is a `Tasks:` section of the `decision` pill (≤5 tasks), so it survives an interrupted session and the verifier can read it. The implementer never edits the `decision` pill: after it returns, the orchestrator marks the finished items `[x]` in that block. Fixes in tier `small` add items to it.

```
Tasks:
Gate: {exact commands}
Commit: {policy} (decision #id)
Allowed files: {paths}
- [ ] 1 {concrete action}. Verify: {command or observable}
```

## Identity Resolution

Once per session, before opening a prescription or storing a pill:
1. `~/.pillbox/identity.json` → `name` + `email`.
2. Else `git config user.name` / `user.email` → write the file.
3. Else ask the user → write the file.

## Session Start

1. Identity Resolution.
2. `capsule_search "{terms}"` → user preferences.
3. `bottle_list` → `bottle_id` (`bottle_create` if missing).
4. `bottle_context bottle_id` → prescription index; note any open prescription for this change.
5. If open: `prescription_context` → current pill IDs.
6. `pill_search compound="config"` → config pill ID.

## Session Close

Runs when verification passes (or the user accepts warnings):
1. **Commit at close** — if commits were authorized "at close" and something is uncommitted: take the changed files from `git diff --name-only <Base>` plus untracked files (`git status --porcelain`; with `Base: none`, `git status --porcelain` alone), keep only those inside the batches' allowed files, stage them explicitly, one Conventional Commit in the project's language, no AI attribution lines. Never `git add .`, never push, never commit databases or secrets.
2. **Summary** — write the `summary` pill: `goal`, `done` (mention a FAIL that was fixed; in tier `small`, the implementer's evidence), `found` (only what no pill holds yet; cite IDs), `next`, `files`, `commits`.
3. **Superseded specs** — `prescription_context` of the current prescription → `pill_read` each `specification` → collect its `Supersedes: #id` lines. For each ID: `pill_read` → its `prescription_id`; `prescription_read` → note whether it was closed; `prescription_reopen`; `pill_discard`; `prescription_close` only if it was closed before. Skip IDs already discarded or not found.
4. `prescription_close` the current prescription.

`init` closes right after `sdd-init` saves the config (no summary).

---

## Actions

### init

1. `bottle_list` → `bottle_create` if missing.
2. `pill_search compound="config"`:
   - **Missing** → `prescription_open title="Project configuration"`; launch `sdd-init`; confirm `pills_saved`; `prescription_close`.
   - **Exists (re-init)** → `pill_read` → its `prescription_id`; `prescription_read` → note whether it was closed; `prescription_reopen`; launch `sdd-init` with that prescription ID and the config pill ID; confirm `pills_revised`; `prescription_close` only if it was closed before. More than one `config` (legacy) → use the most recent and tell the user.

### hub

`pill_search compound="config"`: missing → offer init / explore / new; exists → explore / new / fix / continue / status / re-init.

### explore

`pill_search compound="specification" query="{terms}"` and `pill_search compound="discovery" query="{terms}"` → related IDs. Launch `sdd-explorer` (read-only, no change intent) with those IDs. Show its summary. Without an open prescription the explorer stores nothing; to keep the findings, open one first (`prescription_open title="Explore: {topic}"`) and close it afterwards.

### new

`prescription_open title="{change name}"` (reuse an open one from `bottle_context` if it exists).
`TodoWrite`: [Explore, Decide, Design, Implement, Verify, Close]

1. `pill_search` compounds `specification`, `decision` and `discovery` with domain terms → related IDs (titles only).
2. Launch `sdd-explorer` with the change intent, the related IDs and the prior `discovery` IDs. It returns: facts summary, `discovery` pill IDs, affected areas, **open questions**, suggested tier.
3. **One** `AskUserQuestion`: the open questions, testing (tests? levels? library? TDD?), tier, commit policy (per batch / at close / none).
4. Write the `decision` pill: `Decision:` line, **tier**, `Base: {git rev-parse HEAD}` (`Base: none` outside git or without commits), intent, scope in/out, constraints (testing, runner, gates, commit policy), user decisions, chosen/discarded/why for each non-obvious choice, risks + mitigations, success criteria, and for tier `small` the `Tasks:` block. Cite `discovery` IDs; never copy their facts.
5. Tier `small`: launch `sdd-implementer` with the `decision` ID → verification as in `continue` (spot check; `sdd-verifier` if sensitive) → Session Close.
6. Otherwise launch `sdd-designer` with the `decision` and `discovery` IDs (+ related past `specification`/`task` IDs found in step 1). It returns `specification` (if any) and `task` pill IDs with batch list, gate commands and `superseded` spec IDs.
7. Show the consolidated plan: decision summary, batches, gates, what will be committed. Ask once: proceed? → `"Ready for /sdd:continue"` or continue directly if the user says so.

### continue

Locate the open prescription (`bottle_context`), `prescription_context` → pill IDs. Determine state and `TodoWrite`.

| State | Next |
|---|---|
| No `decision` | redirect → `sdd:new` |
| `decision`, no `task` | tier `small`: `Tasks:` block not all done → launch `sdd-implementer` with the `decision` ID; done → verification. Otherwise launch `sdd-designer` |
| `task` with `[ ]` items | launch `sdd-implementer` for the next batch with IDs (task, specification, decision) and the batch id — gate, commit policy and allowed files come from the task pill. It revises the `task` pill itself. Then run the Off-script protocol. Loop batches without asking. |
| All `[x]` | tier `small`/`standard`: implementer gate results are the verification; orchestrator re-runs **one** gate command as spot check. Tier `large` or sensitive: launch `sdd-verifier` with the `decision`, `specification` and every `task` ID (tier `small`: the `decision` ID alone), plus the existing `feedback` ID if `prescription_context` lists one. |
| Verify PASS (or accepted warnings) | Session Close |
| Closed prescription | "Already archived." |

**Verify FAIL**: offer
1. **Fix** — tier `small`: `pill_revise` the `decision` pill adding fix tasks to its `Tasks:` block (derived from the `feedback` pill or the failed gate) → `sdd-implementer`. Tier `standard`/`large`: launch `sdd-designer` with the `feedback` ID to create a new `task` pill `{change} — tasks [fix]` → implementer → verify again passing the same `feedback` ID.
2. Fix manually.
3. Close anyway with the failures in `summary.next`.

#### Off-script protocol

The implementer's hand-back has `findings` with kind and flags. Act per row; do not relaunch anything for a note.

| Finding | Action |
|---|---|
| `bug in_scope=yes` | already fixed inline; note it |
| `bug in_scope=no blocks=yes` | pause. **⚠️ User decision**: extend scope? Yes → `pill_revise` the `decision` pill (scope + why), relaunch `sdd-designer` with the `task` pill ID to add the new items (keeping `[x]` and evidence verbatim), resume the implementer |
| `bug in_scope=no blocks=no` | note; goes to `summary.found` |
| `deviation` with valid `why` | the implementer already recorded it in the `task` evidence; note it |
| `deviation` without valid `why` | tell the implementer to rework the batch following the task |
| `discovery` | note; goes to `summary.found` |
| `status: blocked` | stop. **⚠️ User decision** before anything else |

### fix

Same as `new` with tier `small` by default: `prescription_open title="{bug summary}"`, search prior `discovery` pills, launch `sdd-explorer` focused on the bug **only if the flow is unfamiliar**, one question if a real decision exists, `decision` pill (compound `decision`, title = the bug, with `Base:` and a `Tasks:` block), implementer, spot check, Session Close. If exploration reveals ≥2 meaningful steps, promote to `standard`.

### status

`pill_search compound="decision"` (optionally narrowed by query). For each change: tier from the `decision` pill, `[x]`/total across all its `task` pills (including `[fix]` batches; tier `small`: the `Tasks:` block of the `decision`), `feedback` verdict, prescription state. Superseded specifications are discarded and do not appear. Changes made with earlier versions may use the compounds `bugfix` and `architecture`; include `bugfix` in the search and treat `architecture` pills as read-only design context (never superseded or discarded).

```
| Change                    | Tier     | Tasks | Status   |
|---------------------------|----------|-------|----------|
| Add search feature        | standard | 5/12  | active   |
| Fix crash on modal close  | small    | 3/3   | archived |
```
