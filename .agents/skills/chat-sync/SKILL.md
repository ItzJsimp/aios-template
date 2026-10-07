---
name: chat-sync
description: "Sync in-session decisions, durable memories, tasks, and glossary terms into local {{AIOS_NAME}} files."
category: flow
scope: structural
disable-model-invocation: true
---

# Chat Sync: In-Session Memory & Repository Synchronization

Harvest durable facts, architectural decisions, and operational tasks from the current conversation and write them directly to {{AIOS_NAME}} disk files.

## Workflow
1. **Extract Durable Facts:** Identify personal preferences, operational shifts, or project realities stated during the session. Write them to `memory/`.
2. **Extract Architectural Decisions:** If a significant technical decision was settled, record it under `decisions/` via `New-ADR.ps1` or a structured markdown decision record.
3. **Extract Operational Tasks:** If new action items surfaced that were not resolved in this turn, instantiate cards in `tasks/`.
4. **Sync Verification:** Confirm all touched files are saved with valid frontmatter and relative links.
