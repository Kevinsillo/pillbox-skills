
# SDD Sub-agent: Init

Bootstrap the SDD context by detecting the project's tech stack and saving it as the project config pill (compound `config`, exclusive to this artifact).

## Lane

**OWNS**: the single project config pill — compound `config`.
**FORBIDDEN**: modifying code, any other compound, a second `config` pill.

## Inputs (from orchestrator)

- Project path
- Prescription ID (on re-init the orchestrator has already reopened the prescription that holds the config pill)
- Existing config pill ID on re-init — always passed by the orchestrator (you have no search tools); `pill_read` it and update rather than replace
- Identity: user name and email

## Steps

1. **Detect project context** — Read real files (package.json, pyproject.toml, go.mod, Cargo.toml, etc.) to determine:
   - Tech stack and languages
   - Architecture patterns in use
   - Test frameworks and linters
   - Existing conventions (naming, structure, commit style)

2. **Return summary** — Report detected stack and next steps.

## Pills to Save

First init: call `pill_store` with the `prescription_id` provided in context. Re-init: `pill_revise` the given config pill ID with the full updated content instead.

- prescription_id: from CONTEXT
- compound: `config`   ← reserved exclusively for this pill; nothing else uses it
- title: `Project configuration`
- content (dense, target ~200–2000 chars):

```
stack: {detected tech stack}
arch: {detected architecture pattern}
testing: {detected test framework}
style: {naming, commit, structure conventions}
```

Return `pills_saved: [{id, title}]` (first init) or `pills_revised: [{id, title}]` (re-init).

## Rules

- Pillbox is reached only through the `pillbox_*` MCP tools — never `sqlite3`/SQL or a DB client against `pillbox.db`; if the MCP is unavailable or a call errors, stop and report the error to the user
- ALWAYS detect real tech stack — never guess
- Target ~200–2000 chars — dense, AI-readable
- First init: call `pill_store` ONCE
- Re-init: `pill_revise` the existing config pill with the full updated content — NEVER call `pill_store` on re-init (searching `compound="config"` must stay unambiguous)
- Pass Identity from CONTEXT as author to every `pill_store`/`pill_revise` call
