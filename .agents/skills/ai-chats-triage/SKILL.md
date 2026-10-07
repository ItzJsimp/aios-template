---
name: ai-chats-triage
description: "Audit open and stale chats across AI harnesses, validate naming conventions, and triage sessions for archival."
category: flow
scope: structural
disable-model-invocation: true
---

# AI Chats Triage: Session Health & Lifecycle Management

Audit, triage, and organize active and completed AI conversation sessions. Ensures workspaces remain clean, flags stale sessions (>3 days inactive), and prevents context loss by staging continuation capsules.

## First-Run Calibration
On first execution, Claude checks local session storage directories (`capture/transcripts/`, `archive/chats/`, or `.claude/`) to calibrate active paths.

## Triage Procedure
1. **Inventory Sessions:** Scan active conversation transcripts in the workspace.
2. **Freshness Assessment:** Flag sessions with no activity in over 72 hours as stale candidates.
3. **Pre-Archival Check:** Verify whether open tasks or durable facts remain trapped in the conversation.
4. **Continuation Staging:** For completed sessions, extract milestones into `handoff-docs/` or `memory/` before moving transcript files to `archive/chats/`.
