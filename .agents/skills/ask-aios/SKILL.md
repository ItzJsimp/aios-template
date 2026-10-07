---
name: ask-aios
description: "Master Skill & Prompt Amplifier: routes tasks to optimal {{AIOS_NAME}} skills and sharpens prompts to peak quality."
category: agents
type: skill
id: skill-ask-aios
title: "Ask {{AIOS_NAME}} : Master Skill & Prompt Amplifier"
kind: procedure
load: on-demand
owner: shared
scope: structural
---

# Ask {{AIOS_NAME}}: Master Skill & Prompt Amplifier

The central meta-router and prompt optimization engine for {{AIOS_NAME}}. Evaluates intent, sharpens user prompts into high-precision instructions, and selects optimal skill execution chains.

## How {{AIOS_NAME}} Uses This Skill
When {{AIOS_NAME}} (or {{OPERATOR_NAME}}) runs `/ask-aios <query or draft prompt>`, {{AIOS_NAME}} performs two synchronized actions:
1. **Prompt Amplification:** Deconstructs the draft prompt, strips ambiguity, applies prompt-composer lenses, and refactors it into a production-grade, token-efficient instruction.
2. **Skill Pipeline Selection:** Maps the task to the exact sequence of skills in {{AIOS_NAME}} that will solve it with highest fidelity.

---

## High-Velocity Intent Router

| Intent / Workload | Optimal Skill Pipeline | Outcome |
|---|---|---|
| **Feature Build / New System** | `/grill-me` -> `/task-scoping` -> `/implement` | Deep interview, design tree, test-driven code execution. |
| **Vibe Coding & Rapid Prototyping** | `/prototype` -> `/tdd` -> `/codebase-design` | Quick working spike validated with clean modular code. |
| **YouTube Video Intelligence** | `/youtube-analyzer` -> `/llm-wiki-research` | Full video download, frames, OCR, and synthesis dossier. |
| **UI Design & Frontend Craft** | `/ui-taste` -> `/design-build` -> `/design-audit` | Anti-slop UI design, token-true components, scored audit. |
| **PC Hardware / Windows Diagnostics** | `/pc-systems-engineer` -> `/game-optimization` | Live hardware diagnosis, risk-gated tweaks, measured gains. |
| **Deep Research & Web Evidence** | `/deep-research` -> `/defuddle` -> `/obsidian-markdown` | Free academic and web research stored cleanly in markdown. |
| **Session Wrap-Up & Continuity** | `/chat-sync` -> `/session-handoff` -> `/chat-closeout` | Sync decisions to disk, create handoff brief, archive clean. |
| **Substrate Health & System Audit** | `/aios-audit` -> `/token-optimizer` | Comprehensive broken-link check, drift audit, token budget. |

---

## Prompt Amplification Standard
When sharpening a user's prompt, {{AIOS_NAME}} structures the output with:
1. **Core Objective:** Single sentence defining the verifiable win.
2. **Context & Constraints:** Specific files, token budgets, zero em-dash rules.
3. **Execution Steps:** Sequential, testable operations.
4. **Verification Gate:** How to prove the task succeeded before declaring completion.
