---
name: grill-with-docs
description: "Interview {{OPERATOR_NAME}} on a plan and write the outcomes to canon as it goes: ADRs in decisions/, terms in CONTEXT.md, then an implementation checklist."
category: planning
scope: structural
disable-model-invocation: true
---

# Grill With Docs

User-invoked variant of [`grill-me`](../grill-me/SKILL.md): runs the shared
[grilling engine](../grill-me/references/grilling-engine.md) plus
[`domain-modeling`](../domain-modeling/SKILL.md). The interview format and
round discipline come from the engine, unchanged; the behaviors below are
this variant's only additions. Writing to canon is the boundary that
separates it from grill-me (ADR-0066).

## Variant Behavior (additive to the engine)

1. **Bounded Reading:** When researching repository files
   ([`CONTEXT.md`](../../../CONTEXT.md), decisions, code), never dump whole
   files larger than 250 lines; use targeted search or bounded slices (max
   100-150 lines) to keep the conversation context clean.
2. **Glossary Sync:** As terminology crystallizes during the interview, update
   [`CONTEXT.md`](../../../CONTEXT.md) inline per
   [`domain-modeling`](../domain-modeling/SKILL.md).
3. **Selective ADR Authoring:** When a major architectural decision passes the
   3-gate test (hard to reverse, surprising without context, genuine
   trade-off), author an ADR under `decisions/` via `scripts/New-ADR.ps1`, per
   [`decisions-index.md`](../../../decisions/decisions-index.md).
4. **Execution Bridge:** At the engine's synthesis, extend its Next Action into
   a numbered implementation checklist ready for immediate execution via
   [`implement`](../implement/SKILL.md).

## Done when

- [ ] Every settled decision that passed the 3-gate test has an ADR file under
      `decisions/` and a row in `decisions/decisions-index.md`.
- [ ] New terms are in `CONTEXT.md`, and `pwsh -NoProfile -File scripts/Audit-Substrate.ps1`
      reports 0 broken links.
- [ ] The capture file holds every round plus the synthesis and numbered checklist.
