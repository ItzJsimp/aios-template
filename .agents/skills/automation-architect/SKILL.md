---
name: automation-architect
description: "Audit AIOS automation gaps, deconstruct workflows into deterministic state machines, and route to optimal 7-tier automation engines."
category: planning
scope: structural
disable-model-invocation: true
---

# Automation Architect: The 7-Tier Automation Standard

Identify manual friction in {{AIOS_NAME}}, deconstruct workflows into deterministic state machines, and select the optimal implementation layer across the 7-tier automation hierarchy.

## The 7-Tier Automation Ladder
1. **Tier 1 (CLI Aliases & Functions):** Simple shell shortcuts and path aliases.
2. **Tier 2 (Deterministic PowerShell/Python Scripts):** Standalone scripts with parameter validation, error handling, and strict exit codes.
3. **Tier 3 (Git Hooks & Pre-Commit Gates):** Automated formatting, linting, and link verification running on commit.
4. **Tier 4 (Windows Scheduled Tasks):** Time-based or logon-based background maintenance jobs.
5. **Tier 5 (File Watchers & Event Triggers):** Reactive background scripts monitoring specific folder changes.
6. **Tier 6 (Local Daemons & Microservices):** Always-on local background services (e.g. logging or audio services).
7. **Tier 7 (Autonomous Agent Loops):** LLM-powered subagents operating with tool access for complex synthesis.
