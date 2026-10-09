---
name: code-quality
description: "The quality bar for all code: hexagonal architecture, clean code, KISS, and each language's idiomatic conventions, with no hacks, anti-patterns, or overlapping responsibilities. ALWAYS use when writing, modifying, refactoring, or reviewing code in any language, when designing the structure of a module or project, or when the user mentions code quality, architecture, clean code, refactoring, or best practices."
license: PolyForm-Noncommercial-1.0.0
metadata:
  author: Kevin Illanas — https://github.com/kevinsillo
  version: 1.0.0
  trigger: code-quality, "code quality", "clean code", "best practices"
  tags: code-quality, hexagonal-architecture, clean-code, kiss, best-practices
---

# code-quality — Code quality standard

**Architecture.** Use hexagonal architecture whenever the situation or the project allows it, organized into three layers inside `core/`: `domain`, `application`, and `infrastructure`. Always name and reason about the design in terms of these layers, never as "ports and adapters". Dependencies point inward: `domain` knows nothing about frameworks, persistence, or transport, `application` orchestrates the use cases, and `infrastructure` implements the interfaces the inner layers define, so business logic can be tested without it. Where it doesn't fit (a script, a one-off fix, a project with an established architecture of its own), respect what is already there and keep the principle at whatever scale applies: responsibilities stay separate and never overlap, every module, class, and function has a single reason to change, and no business rule lives in controllers, views, or infrastructure.

**Code.** Write clean code, and apply KISS to logic, not to architecture: the body of every function, condition, and algorithm should be easy to read, understand, and express, but interfaces, layers, and other structural elements are not complexity to trim and are never dropped for the sake of simplicity. Use intention-revealing names and small, cohesive functions, don't duplicate knowledge, leave no dead code or magic values, and comment only to explain why. Follow the most widely accepted conventions of each language and its ecosystem (style guide, idioms, project layout, standard tooling) rather than carrying over habits from another language; in an existing project, its established style wins for the sake of consistency.

**What is not acceptable.** Hacks, anti-patterns, and workarounds that mask the symptom: fix the root cause. Handle errors explicitly, with no swallowed exceptions and no linter or type-checker warnings suppressed just to get things to pass. Avoid global state and hidden side effects. If a compromise is the only viable way out (a third-party limitation, a project constraint), don't slip it in quietly: flag it, isolate it, and document why it exists and what the proper solution would be.