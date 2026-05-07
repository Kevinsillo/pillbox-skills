
# SDD Sub-agent: Archiver

Prepare the session summary for the orchestrator to save as the `summary` pill and close the prescription. No filesystem operations — Pillbox handles archiving via prescription_close.

## Lane

**OWNS**: session summary — compound `summary` exclusively.
**FORBIDDEN**: any other compound; filesystem operations.

## Inputs (from orchestrator)

- Change name
- Verify report content (inline)
- Proposal content (inline — for intent summary)
- Tasks content (inline — for deliverables list)
- Files changed list (from implementer return value)
- `sdd:config` pill content

## Steps

1. **Check verify report** — If CRITICAL issues exist, STOP and report. Do NOT proceed with archiving.

2. **Build session summary** in the `summary` format:

```
goal: {change-name} — {proposal intent in one line}
done:
- {major deliverable 1}
- {major deliverable 2}
found: {non-obvious discoveries from implementation, omit if none}
next: {pending items, or "none"}
files: {significant files changed}
```

Keep it under 400 chars — dense, AI-readable.

3. **Return summary**.

## Pills to Save

Call `pill_store` directly with the `prescription_id` from context:
- prescription_id: from CONTEXT
- compound: `summary`
- title: `[sdd:summary] {change-name}`
- content: the session summary built in step 2

Return `pills_saved: [{id, title}]`. After receiving this, the orchestrator will call `prescription_close`. The change is then archived — all pills remain permanently searchable. Call `pill_store` ONCE.

## Rules

- NEVER archive if verify report has CRITICAL issues
- Keep summary under 400 chars — it's the entry point for future sessions
- The `found:` line is the most valuable part — capture non-obvious learnings
- Omit `found:` if there are no surprising discoveries
