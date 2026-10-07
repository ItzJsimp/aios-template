---
name: implement
description: "Execute plans and specifications through disciplined test-first slices (Red-Green-Refactor)."
category: code
type: skill
id: skill-implement
title: "Implement: Disciplined Test-First Execution Loop"
kind: procedure
load: on-demand
owner: shared
scope: structural
verified: 2026-08-30
related: ["skills-index", "grill-with-docs", "task-scoping", "task-management", "master-instructions"]
generated: false
---

# Implement: Disciplined Test-First Execution Loop

**Upstream of this skill:** for a new build or non-trivial system (not a one-line fix), run the 6 phases before this one per [`standards/execution-standard.md`](../../../standards/execution-standard.md): Ideate & Scope, Deep Research, Core Principles, Power User Posture, Best Practices, Gap Analysis (with 3 Work Tiers). This skill is that standard's 7th phase, Test-First Execution.

## Purpose

Translates an approved plan, task checklist, or technical specification into tested, working code through an iterative vertical-slice loop. Enforces observable red-phase validation, minimal green implementations, workspace refactoring standards, and atomic commits.

---

## Procedure

1. **Intake & Verification:**
   - Read the approved task specification, plan checklist, or prompt brief.
   - Confirm all acceptance criteria and prerequisites are unambiguous before writing code.

2. **Slice Extraction:**
   - Select exactly one vertical slice or numbered task item.
   - Work strictly within the boundary of this single slice.

3. **Red Phase (Observable Failure):**
   - Establish a reproducible, failing check that proves the requirement is currently missing before making changes.
   - Run the check and observe the non-zero exit or assertion failure.
   - For non-compiled stacks (PowerShell, markdown governance, data schemas), consult [`verification-patterns.md`](./references/verification-patterns.md).

4. **Green Phase (Minimal Implementation):**
   - Write the minimal direct code required to make the check pass.
   - Reach for standard library and platform-native tools before adding dependencies or abstractions.

5. **Refactor Phase:**
   - Clean up formatting, streamline logic, and adhere to workspace coding standards.
   - Verify all tests remain green.

6. **Reconcile & Commit Slice:**
   - Run `pwsh -File scripts/Complete-Slice.ps1 -Paths <files...> -Message "<type>(<scope>): <summary>"` to verify em dashes, check drift, and create an atomic git commit per [ADR-0010](../../../decisions/0010-git-history-replaces-the-master-log.md). Always pass `-Paths` with explicit changed files; omitting `-Paths` refuses to commit to prevent sweeping other sessions' half-finished work.
   - Reconcile task state by marking the slice item complete (`[x]`).

7. **Loop or Finalize:**
   - Repeat steps 2 through 6 for each remaining slice.
   - When all slices are complete, verify full suite health.

---

## Execution Guardrails

- **No Simulated Verifications:** Every Red and Green transition must be backed by actual shell execution output. Never assert tests pass without running the command.
- **Single Slice Boundary:** Never modify files outside the current task slice. If a blocker or architectural ambiguity is hit, immediately halt the slice, report the exact obstacle, and await user clarification.
- **No Unsolicited Planning Artifacts (Rule 6):** Never generate `implementation_plan.md` or `walkthrough.md` files unless explicitly requested.
- **Batch Multi-File Operations (Rule 3):** When modifying or refactoring >3 files, write and run a single script rather than executing sequential single-file tool calls.
- **Zero Em-Dash Standard (Rule 4):** Never introduce U+2014 em dashes in code, comments, strings, or documentation.
- **Relative File Links (Rule 7):** Format all path and symbol references in prose as repo-relative clickable links.

---

## Done When

The implementation task is complete when all five are true:

1. **Every Slice Check Green:** All acceptance criteria in the intake plan have an automated test or check that passes green.
2. **Substrate Drift Clean:** `scripts/Detect-Drift.ps1` emits zero `[FAIL]` lines.
3. **Punctuation Clean:** `scripts/Find-EmDashes.ps1` reports zero em dashes in touched files.
4. **Atomic Git Log:** Every completed slice corresponds to a distinct git commit per [ADR-0010](../../../decisions/0010-git-history-replaces-the-master-log.md).
5. **Task Progress Reconciled:** The source task checklist or file in [`tasks/`](../../../tasks/tasks-index.md) reflects updated `[x]` completion states.
