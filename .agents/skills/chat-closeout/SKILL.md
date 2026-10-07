---
name: chat-closeout
description: "Pre-archival session gate: extract memories/tasks, write continuation capsule, and stamp archival readiness."
category: flow
scope: structural
disable-model-invocation: true
---

# Chat Closeout: Session Extraction & Archival Certification

The closing gate for a working session. Ensures no durable context is trapped in conversation history before a chat is closed or reset.

## Closeout Protocol
1. **Durable Knowledge Extraction:** Run `chat-sync` to ensure all facts, decisions, and tasks are saved to disk.
2. **Working Tree Hygiene:** Run `git status` to verify uncommitted changes are cleanly committed or staged.
3. **Continuation Capsule:** Write a brief handoff capsule in `handoff-docs/` specifying the last completed milestone and the immediate next step.
4. **Readiness Stamp:** Confirm the session is clean and ready to close.
