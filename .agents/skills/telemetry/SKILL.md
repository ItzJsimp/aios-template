---
name: telemetry
description: "Record and inspect task velocity, skill invocations, and tool usage across {{AIOS_NAME}}."
category: system
scope: structural
disable-model-invocation: true
---

# {{AIOS_NAME}} Telemetry & Execution Tracking

Record, monitor, and audit operational events across {{AIOS_NAME}} without heavy external database dependencies.

## Standard Log Stores
- **Skill Invocations:** Append to `logs/skill-invocations.jsonl`:
  ```json
  {"timestamp": "ISO-8601", "skill": "grill-me", "type": "manual", "harness": "Claude Code", "snippet": "user prompt"}
  ```
- **Task Telemetry:** Append to `logs/task-telemetry.jsonl`:
  ```json
  {"timestamp": "ISO-8601", "task": "task-slug", "event": "start|complete", "harness": "Claude Code"}
  ```
