---
name: mode-persona-builder
description: "Author, promote, or refine AIOS Modes and personas adhering to canonical 5-section architecture and mode-specific output contracts."
category: agents
scope: structural
disable-model-invocation: true
---

# Mode & Persona Builder

Produces a fully-formed Mode for your AIOS: a roster row in `modes/modes-index.md`, an instruction file built to canonical 5-section standard with a personalized Output Protocol and Mode Footer Contract, a `modes/router.md` precedence entry, and a cold-start test.

## First-Run Calibration Protocol
When authoring or editing Modes in {{AIOS_NAME}}, Claude must check `memory/user-profile.md` (or `memory/core.md`) to align the assistant's persona with the operator's actual working style and focus rhythms.

## Canonical 5-Section Mode Architecture
1. **Identity & Core Directive:** Purpose, boundaries, and tone.
2. **Behavioral Invariants:** Absolute rules that never lapse.
3. **Execution Procedures:** Step-by-step methodology for the domain.
4. **Output Format & Landmarks:** Headings, visual structure, and tables.
5. **Session Footer Contract:** Telemetry and next action formatting.
