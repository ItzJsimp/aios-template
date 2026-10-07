---
name: session-handoff
description: "Compact conversation and working tree state into handoff-docs/ with a fresh-session resumption prompt."
category: flow
scope: structural
disable-model-invocation: true
---

# Session Handoff: Cold-Start Continuity Engine

Compact conversation state into a dedicated handoff briefing under `handoff-docs/` so a future Claude Code session can resume work instantly without losing context.

## Document Structure (`handoff-docs/YYYY-MM-DD-<topic>.md`)
1. **Objective:** What this session set out to achieve.
2. **What Was Completed:** Verifiable commits, files created, and tests passing.
3. **Current State:** Active branch, pending diffs, and exact disk reality.
4. **Gotchas & Failed Approaches:** Things that failed so the next session never repeats them.
5. **Cold-Start Resumption Prompt:** A copy-pasteable prompt that {{OPERATOR_NAME}} can feed into a fresh chat to resume immediately.
