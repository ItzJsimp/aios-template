---
name: subagent-builder
description: "Author, audit, and configure subagents for Claude Code with model routing and isolated context boundaries."
category: agents
scope: structural
disable-model-invocation: true
---

# Subagent Builder: Isolated Execution & Tool Delegation

A subagent executes tasks in an isolated context window with dedicated tool permissions and model routing. This isolates the parent orchestrator from token bloat, enables parallel execution swarms, and preserves budget headroom.

## First-Run Calibration Protocol
On first use in {{AIOS_NAME}}, Claude checks available API keys and configured models to calibrate model tiers.

## Model Routing Tiers
- **Read-Only / Fast Grep:** `haiku` (Claude 3.5 Haiku) for search, file listing, and AST parsing.
- **Implementation & Refactoring:** `sonnet` (Claude Sonnet) for code writing, tests, and component edits.
- **Deep Architecture & Formal Proofs:** `opus` (Claude Opus) for complex system design.

## Subagent Authoring Sequence
1. **Role & Operational Bounds:** State the subagent's single responsibility.
2. **Spawn vs Inline Criteria:** Define concrete thresholds (e.g. scanning >5 files, running full test suites).
3. **Tool Access:** Grant least-privilege tools needed for the role.
4. **Execution Protocol:** Define input prompt schema and under-300-word output report schema.
