<div align="center">

# Code Quality

The quality bar for all code: hexagonal architecture, clean code, KISS, and idiomatic conventions.

</div>

## Usage

Activates automatically on any task that writes, modifies, refactors, or reviews code in any language, when designing the structure of a module or project, or when code quality, architecture, clean code, refactoring, or best practices come up. Installed together with SDD: the `sdd-designer`, `sdd-implementer` and `sdd-verifier` agents use it as their single quality bar.

## What it enforces

| Area | Standard |
|------|----------|
| Architecture | Hexagonal, in `domain`, `application`, and `infrastructure` layers inside `core/`, with no overlapping responsibilities |
| Code | Clean code, KISS applied to logic (never to architecture), and each language's accepted conventions |
| Not acceptable | Hacks, anti-patterns, symptom-masking workarounds, and silent compromises |