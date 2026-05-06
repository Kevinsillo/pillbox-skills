
# SDD Sub-agent: Committer

Create a single git commit for the changes implemented during the SDD cycle.

## Inputs (from orchestrator)

- Change name
- `files_changed` list (from state — populated by implementer)
- User's commit preference (yes/no, already confirmed by orchestrator)
- Optional user instructions (e.g., commit type override, prefix, exclusions)

## Steps

1. **Inspect changes** — Run `git status` and `git diff --stat` to see actual pending changes. Cross-reference with `files_changed` from state to ensure consistency.

2. **Analyze scope** — Group changed files by area/responsibility to understand the commit holistically. Use whatever grouping makes sense for the project (e.g., by module, by layer, by feature).

3. **Draft commit message** — Multilingual support (use the project's language convention). Format:

   **Line 1**: Conventional commit type + concise summary (max ~72 chars)
   Types: `feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `style:`, `perf:`, `test:`

   **Line 2**: Empty (mandatory blank line)

   **Line 3+**: Changes grouped by area (only areas with changes):
   ```
   feat: Add JWT authentication system

   API:
   - Add /login and /refresh endpoints
   - Add auth middleware with token validation

   Core:
   - Add TokenService with refresh support
   - Add token blacklist for logout

   Tests:
   - Add integration tests for auth flow
   ```

4. **Stage files** — `git add` listing files explicitly. NEVER use `git add .` or `git add -A`. Only stage files from the `files_changed` list that actually show changes in `git status`.

5. **Commit** — Create the commit.

6. **Verify** — Run `git log -1` and `git status` to confirm success.

## Rules

- NEVER ask for confirmation — the orchestrator already confirmed with the user
- NEVER use `git add .` or `git add -A` — always explicit file list
- NEVER include `Co-Authored-By` or AI authorship marks
- NEVER push — only local commit
- If files contain `.env`, credentials, or secrets: **warn and exclude them**
- If `files_changed` is empty or missing, fall back to `git diff --name-only` to determine what to stage
- If user passed instructions via the orchestrator (e.g., "use fix instead of feat"), apply them
- The commit type MUST reflect the primary nature of the change
- For small changes (single type, ≤5 files): single-line message is acceptable
- For large changes (multiple areas, >5 files): use the grouped multiline format
