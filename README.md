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
agents/          # Canonical agent content (platform-independent)
  sdd-explorer.md
  sdd-proposer.md
  sdd-specifier.md
  sdd-architect.md
  sdd-planner.md
  sdd-implementer.md
  sdd-verifier.md
  sdd-archiver.md
  sdd-committer.md
  sdd-init.md
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
| `sdd` skill | Skill | SDD orchestrator — coordinates the full spec-driven cycle |
| `sdd-*` agents | Agents | Sub-agents for exploration, specs, design, implementation, verification |
| `sdd` commands | Commands | `/sdd:new`, `/sdd:continue`, `/sdd:fix`, `/sdd:explore`, `/sdd:init`, `/sdd:status` |

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
3. Copies skills to `~/.{provider}/skills/`
4. Generates agent files with platform-specific frontmatter and copies to `~/.{provider}/agents/`

Re-running the script overwrites existing files — use it to update after pulling changes.

## Providers

| Provider | Skills path | Agents path | Commands path |
|---|---|---|---|
| Claude Code | `~/.claude/skills/` | `~/.claude/agents/` | `~/.claude/commands/` |
| OpenCode | `~/.config/opencode/skill/` | `~/.config/opencode/agent/` | `~/.config/opencode/command/` |

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
