---
type: standard
id: standard-execution
title: "Standard: AI Execution Meta-Workflow"
description: >
  Codifies the canonical 9-phase compounding framework for building systems with AI
  (Subtraction Gate, Ideate/Scope, Research, Principles, Power User Posture,
  Context Budgeting, MECE Gap Analysis with 3 Work Tiers, Test-First & Adversarial Probe,
  Substrate Reconciliation, Flywheel Memory Harvest).
kind: state
load: on-demand
owner: aios
scope: structural
verified: 2026-09-12
sources: ["archive/permanent/captures/2026-08-31T2045-today-tasks-raw.md", "wiki/ai-implementation-playbook.md"]
related: ["adr-0024-task-substrate-lifecycle-and-completion-archival", "ideal-state-models", "skill-implement", "skill-research", "prompt-aios-architecture-and-workflows", "wiki-ai-implementation-playbook", "template-page-feature-spec", "standard-telemetry"]
generated: false
---

# Standard: AI Execution Meta-Workflow

Promoted from capture [`2026-08-31T2045-today-tasks-raw.md`](../archive/permanent/captures/2026-08-31T2045-today-tasks-raw.md), where {{OPERATOR_NAME}} named this as the pattern almost every one of his builds already follows, expanded into a closed-loop compounding architecture.

**The gap this closes.** Without this written down, each session re-derives its own approach from scratch, skips straight from "build X" to code without research, burns unbounded context tokens, leaves unvalidated edge cases behind, and fails to harvest learnings into durable memory. This standard is the fixed 9-phase compounding sequence {{AIOS_NAME}} runs by default on any non-trivial build, so {{OPERATOR_NAME}} never has to re-explain the process, only the task.

## The 9 Compounding Phases

1. **Phase 0: Subtraction & Deletion Gate.** Run **M2 Inversion** ([`ideal-state/models.md`](../ideal-state/models.md)) and consult [`standards/deletion-ladder.md`](../standards/deletion-ladder.md) plus the Absorb-Keep-Kill matrix. Ask: Can this problem be solved by deleting an existing layer, consolidating existing files, or changing a configuration flag? Can native platform capabilities absorb it? If building creates more maintenance debt than value, abort or simplify immediately.
2. **Phase 1: Ideate & Scope.** State the problem, core outcome, and boundary constraints in 1-2 crisp sentences. Explicitly list non-goals. Do not design premature abstractions or write code during this phase.
3. **Phase 2: Deep Research.** Check GitHub, YouTube, Reddit, documentation, and the web for verified, already-solved approaches before designing from scratch. Prefer what an elite operator already built over reinventing it. Delegate to [`research`](../.agents/skills/research/SKILL.md) for tasks requiring 2+ external sources.
4. **Phase 3: Establish Core Principles (M1).** Strip the problem to fundamental truths per **M1 First Principles** ([`ideal-state/models.md`](../ideal-state/models.md)). Counter conventional industry patterns that do not fit {{OPERATOR_NAME}}'s local-first, low-friction architecture.
5. **Phase 4: Power User Posture.** Assume frontier tooling, highest-leverage configurations, and expert execution. Determine what a power user would do (CLI switches, native shell piping, keyboard shortcuts) instead of accepting slow beginner defaults.
6. **Phase 5: Best Practices & Context Budgeting.** Apply standing productivity and efficiency principles ([`memory/soul.md`](../memory/soul.md), [`AGENTS.md`](../AGENTS.md)). Crucially, budget AI resources upfront per [ADR-0030](../decisions/0030-harness-aware-model-routing-and-quota-telemetry.md) and [`tools/model-router.md`](../tools/model-router.md): choose the optimal model tier (Flash swarms, Haiku scripts, Sonnet/Pro refactors), establish a <50 turn ceiling, and preserve prompt cache prefix stability per [`standards/prompt-caching-standard.md`](../standards/prompt-caching-standard.md).
7. **Phase 6: MECE Gap Analysis & 3 Work Tiers Decomposition.** Decompose the build into exhaustive, non-overlapping deliverables (**M8 MECE**). Crucially, classify every deliverable into the Boom Automations **3 Work Tiers** ([`wiki/ai-implementation-playbook.md`](../wiki/ai-implementation-playbook.md)) before writing code:
   - **Tier 1: Deterministic Work (0% AI):** If a step can be written as a deterministic rule (*"when X happens, do Y"*), implement as a pure PowerShell or Python script in `scripts/`. Zero LLM tokens.
   - **Tier 2: Judgment Work (AI Agents):** If a step requires reasoning, multi-source synthesis, unstructured text extraction, or architectural tradeoffs, route to a dedicated Mode or skill.
   - **Tier 3: Decision Work (Human Operator):** If a step requires human sign-off (architectural commitments, credentials, external spending), prepare a 60-second review card for {{OPERATOR_NAME}} rather than automating unchecked or asking open-ended questions.
8. **Phase 7: Test-First Execution & Adversarial Chaos Probe.** Execute via [`implement`](../.agents/skills/implement/SKILL.md)'s Red-Green-Refactor loop. Once checks pass green, execute an **Adversarial Chaos Probe**: test dirty environments (spaces in paths, nulls, CRLF/LF, KaTeX `\$` collisions), scale stress ("what crashes if volume doubles?"), and cross-engine safety. Track all deliverables under [ADR-0024](../decisions/0024-task-substrate-lifecycle-and-completion-archival.md)'s 5-state lifecycle (`Awaiting Review`).
9. **Phase 8: Substrate Reconciliation & Single Write Path Gate.** Deterministic post-execution validation:
   - Run `scripts/Build-Index.ps1` to rebuild affected indices per [ADR-0023](../decisions/0023-folder-prefixed-index-naming-and-expanded-metadata-tables.md).
   - Verify the Single Write Path: prove that no duplicate state was created in parallel files.
   - Run `scripts/Audit-Substrate.ps1` to verify zero em-dashes (U+2014) and 100% resolvable relative links.
   - Verify the Telemetry & Observability Gate per [`standards/telemetry-standard.md`](./telemetry-standard.md): prove that new capabilities emit structured telemetry to an append-only JSONL log (`logs/`) or ActivityWatch bucket with an automated analysis consumer.
10. **Phase 9: Flywheel Harvest & Memory Promotion (M9 OODA Closure).** Close the loop so every build permanently immunizes and elevates future sessions:
    - *Gotcha Capture:* Append resolved platform quirks or unexpected tool behavior to [`logs/lessons-learned.md`](../logs/lessons-learned.md).
    - *Domain Sync:* Register new concepts or entities in [`CONTEXT.md`](../CONTEXT.md).
    - *Memory Promotion:* Promote validated preferences or operating constraints to a [`memory/`](../memory/memory-index.md) topic file or [`memory/operator.md`](../memory/operator.md).
    - *Floor Map Check:* Verify that the real-world friction stays under {{OPERATOR_NAME}}'s ADHD 2-click threshold.

## Binding to the rest of canon

- **This is a sequence, not a new skill.** No dedicated skill invokes all phases; each phase routes to whatever already handles it (`research`, `implement`, `task-scoping`, model router, Pre-Flight Checklist). The standard exists so the sequence itself, and the order, is written down once.
- **Cadence, not a one-shot.** Running all 9 phases is a full lap of **M9 OODA Loop** ([`ideal-state/models.md`](../ideal-state/models.md)): observe (phases 0-2), orient (phases 3-5), decide (phase 6), act & harden (phases 7-8), and compound (phase 9).
- **When to skip phases.** A trivial, single-file fix does not need all 9 phases documented explicitly; the Pre-Flight Checklist in [`AGENTS.md`](../AGENTS.md) already governs when the full gate applies. This standard governs non-trivial builds, systems, or recurring patterns worth getting right once.
- **Task creation is downstream of this, not parallel to it.** A task file's `Done when` checklist (ADR-0024) reflects the output of phase 6, while Phases 7-9 govern the transition from `In progress` to `Awaiting Review` and `Done`.
- **Feature specification template.** When authoring a comprehensive build brief before execution, use [`templates/page-feature-spec.md`](../templates/page-feature-spec.md), which structures the artifact around this 9-phase compounding model.

## Done when

- [x] The 9-phase compounding sequence is written down once, here, so it does not need re-deriving per session.
- [x] Each phase points at the existing skill, model, or standard that already owns it, rather than duplicating that content.
- [x] Pre-flight subtraction (Phase 0) and context budgeting (Phase 5) are explicitly bound to canon.
- [x] The Boom Automations 3 Work Tiers are embedded in Phase 6.
- [x] Adversarial probing, substrate reconciliation, and flywheel memory harvest (Phases 7-9) close the execution loop.
- [x] Referenced from [`.agents/skills/implement/SKILL.md`](../.agents/skills/implement/SKILL.md) and [`prompts/aios-architecture-and-workflows.md`](../prompts/aios-architecture-and-workflows.md).
- [x] `scripts/Detect-Drift.ps1` reports zero em-dash and zero broken-link issues against this file.
