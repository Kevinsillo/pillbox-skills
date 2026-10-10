<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="resources/pillbox-logo-light.png">
  <img src="resources/pillbox-logo-dark.png" alt="Pillbox" width="220">
</picture>

# pillbox-skills

***Pillbox skills and agents for AI coding assistants***

Part of the [Pillbox](https://github.com/Kevinsillo/pillbox) ecosystem.

</div>

Skills and agents that extend AI assistants with Pillbox support and Spec-Driven Development (SDD). Compatible with Claude Code and OpenCode.

## Structure

```
skills/          # Skill definitions (SKILL.md per skill)
  pillbox/       # Teaches the agent how to use Pillbox MCP tools
  sdd/           # SDD orchestrator — Spec-Driven Development workflow
  code-quality/  # Quality bar for all code, followed by the SDD agents
agents/          # Canonical agent content (platform-independent)
  sdd-init.md
  sdd-explorer.md
  sdd-designer.md
  sdd-implementer.md
  sdd-verifier.md
commands/          # Command definitions (provider-independent)
  sdd/             # SDD slash commands (/sdd:new, /sdd:continue, etc.)
providers/
  configurations.json  # Per-provider frontmatter and install paths
install.sh             # Install script (Linux/macOS) — detects providers and installs to home
install.ps1            # Install script (Windows) — PowerShell counterpart of install.sh
```

## What's included

| Item | Type | What it does |
|---|---|---|
| `pillbox` skill | Skill | Technical usage guide for Pillbox MCP tools |
| `sdd` skill | Skill | SDD orchestrator — coordinates the spec-driven cycle and writes the `decision` and `summary` pills itself |
| `code-quality` skill | Skill | Single quality bar for code and structure — hexagonal architecture, clean code, KISS, idiomatic conventions, no hacks |
| `sdd-*` agents | Agents | Five sub-agents: `init` (project config), `explorer` (facts + open questions), `designer` (specs + task batches), `implementer` (code + gate + commit), `verifier` (independent check) |
| `sdd` commands | Commands | `/sdd:new`, `/sdd:continue`, `/sdd:fix`, `/sdd:explore`, `/sdd:init`, `/sdd:status` |

## How the SDD cycle works

1. `/sdd:new` — the explorer maps the code and returns open questions; the orchestrator asks the user **once** (questions, testing, tier, commit policy), writes the `decision` pill and launches the designer, which produces `specification` pills (only when there are behaviour rules) and one `task` pill per batch.
2. `/sdd:continue` — the implementer runs batch after batch: code, its **directed gate** (tests of the touched module plus an incremental syntax/type check) and evidence in the `task` pill, committing when authorized. After the last batch the orchestrator orders the **full gate** (formatting, static analysis, the entire suite) once per change; verification is proportional to the tier (`small`/`standard`: reuse those results + one spot check; `large` or sensitive: independent verifier).
3. Close — the orchestrator commits (when authorized at close), writes the `summary` pill, discards the specifications superseded by this change and closes the prescription.

Code quality is part of the cycle and has a single source: the `code-quality` skill. Claude Code preloads it into the designer, implementer and verifier; OpenCode agents load it with the skill tool. The designer designs within its architecture, the implementer reviews its own diff against it before running the gate, and the verifier reports hacks that hide a failure as CRITICAL and any other breach of the skill as WARNING.

Sub-agents keep their context small: gate runners report only a command, verdict and counts (never logs or per-test listings), each batch reads only its `decision`, the `specification` of its domain and the active `task`, and only the explorer scans the codebase — the designer, implementer and verifier work from the stored `discovery` IDs instead of re-exploring. The verifier reuses the recorded full-gate evidence and re-runs the gate only for migration, schema, security, data-loss, public-contract or shared-core changes.

Sub-agents receive **pill IDs**, never pasted content, and read what they need with the Pillbox MCP tools. Each compound has one owner (see the `sdd` skill; the implementer only marks progress and evidence in the designer's `task` pills) and a soft size target under the 5000-character hard limit; corrections revise pills in place instead of creating duplicates, and each domain keeps one current specification — a newer version carries `Supersedes: #id` and the old one is discarded at close.

## Installation

Run the install script for your platform from the repo root:

```bash
./skills/install.sh      # Linux / macOS
```

```powershell
.\skills\install.ps1     # Windows
```

The script:
1. Detects installed providers (Claude Code at `~/.claude`, OpenCode at `~/.config/opencode`)
2. Asks which providers to install to
3. Copies skills to `~/.{provider}/skills/` — `code-quality` is installed together with SDD, since the agents depend on it
4. Generates agent files with platform-specific frontmatter (Claude Code `tools` and `skills`, OpenCode `permission`) and copies them to `~/.{provider}/agents/`
5. Substitutes the provider's skills path into agent and command bodies

Re-running the script overwrites existing files — use it to update after pulling changes.

## Providers

| Provider | Skills path | Agents path | Commands path |
|---|---|---|---|
| Claude Code | `~/.claude/skills/` | `~/.claude/agents/` | `~/.claude/commands/` |
| OpenCode | `~/.config/opencode/skills/` | `~/.config/opencode/agents/` | `~/.config/opencode/commands/` |

## Pillbox skill only

If you only need the Pillbox skill (no SDD), the main installer handles it:

```bash
# Linux / macOS
curl -fsSL https://raw.githubusercontent.com/Kevinsillo/pillbox/main/install.sh | bash
# or, if pillbox is already installed
pillbox skill install
```

## Main repository

→ [pillbox](https://github.com/Kevinsillo/pillbox) — install the full ecosystem from there.
