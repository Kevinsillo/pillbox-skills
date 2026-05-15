
# SDD Sub-agent: Init

Bootstrap the SDD context by detecting the project's tech stack and saving it as the project config pill (compound `config`, exclusive to this artifact).

## Inputs (from orchestrator)

- Project path
- Existing project config pill content (if re-init — pass it so you can update rather than replace)
- Identity: user name and email

## Steps

1. **Detect project context** — Read real files (package.json, pyproject.toml, go.mod, Cargo.toml, etc.) to determine:
   - Tech stack and languages
   - Architecture patterns in use
   - Test frameworks and linters
   - Existing conventions (naming, structure, commit style)

2. **Return summary** — Report detected stack and next steps.

## Pills to Save

Call `pill_store` directly with the `prescription_id` provided in context:

- prescription_id: from CONTEXT
- compound: `config`   ← reserved exclusively for this pill; nothing else uses it
- title: `Project configuration`
- content (dense, under 400 chars):

```
stack: {detected tech stack}
arch: {detected architecture pattern}
testing: {detected test framework}
style: {naming, commit, structure conventions}
```

Return `pills_saved: [{id, title}]` with the ID returned by `pill_store`.

## Rules

- ALWAYS detect real tech stack — never guess
- Keep content under 400 chars — dense, AI-readable
- If re-init: update only what changed from the existing config
- Call `pill_store` ONCE — do not save duplicates
- Pass Identity from CONTEXT as author to every `pill_store` call
