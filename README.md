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
providers/
  configurations.json  # Per-provider frontmatter and install paths
build-agents.sh        # Install script — detects providers and installs to home
```

## What's included

| Item | Type | What it does |
|---|---|---|
| `pillbox` skill | Skill | Technical usage guide for Pillbox MCP tools |
| `sdd` skill | Skill | SDD orchestrator — coordinates the full spec-driven cycle |
| `sdd-*` agents | Agents | Sub-agents for exploration, specs, design, implementation, verification |

## Installation

Run the install script from the repo root:

```bash
./skills/build-agents.sh
```

The script:
1. Detects installed providers (Claude Code at `~/.claude`, OpenCode at `~/.config/opencode`)
2. Asks which providers to install to
3. Copies skills to `~/.{provider}/skills/`
4. Generates agent files with platform-specific frontmatter and copies to `~/.{provider}/agents/`

Re-running the script overwrites existing files — use it to update after pulling changes.

## Providers

| Provider | Skills path | Agents path |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `~/.claude/agents/` |
| OpenCode | `~/.config/opencode/skills/` | `~/.config/opencode/agents/` |

## Pillbox skill only

If you only need the Pillbox skill (no SDD), the main installer handles it:

```bash
curl -fsSL https://get.pillbox.dev | bash
# or
pillbox skill install
```

## Main repository

→ [pillbox](https://github.com/Kevinsillo/pillbox) — install the full ecosystem from there.
