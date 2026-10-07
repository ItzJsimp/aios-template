---
type: reference
id: ideal-state-models
title: "Ideal State : Mental Models"
description: >
  The curated cognitive operating roster: 16 high-order mental models across epistemics, systems, strategy, and human execution, each with a plain-English definition, an execution trigger, its failure mode, and the exact AIOS file or gate it binds to. Read before finalizing any strategy, plan, or architectural decision.
kind: state
load: on-demand
owner: aios
scope: personal
verified: 2026-08-31
generated: false
---

# Mental Models

Two halves. **{{OPERATOR_NAME}}'s recorded models** came out of how he actually decides. **The curated
roster** is the standard toolkit every Mode and every engine is expected to reach for,
hardcoded into AIOS by the gates named in each entry.

The rule that keeps this file from becoming a quote wall: **a model with no binding gets
cut.** Every entry names a file, gate, or workflow where it actually fires. If it only
lives here, it is theory, and theory belongs in `wisdom.md`.

## The five thinking layers

The roster is grouped by the layer of thinking it serves. The same five layers are the
axes of the cognitive baseline scorecard under `audits/`.

| Layer | What it governs | Models |
|---|---|---|
| L1 Cognition and First Principles | How a problem is deconstructed before any answer | M1 to M4 |
| L2 Problem Structuring | How a messy situation gets cut into parts | M8, applied on top of L1 |
| L3 Systems Dynamics | Where the constraint sits and how loops behave | M5 to M7 |
| L4 Execution and Operations | Why work starts, stalls, or compounds | M13 to M16 |
| L5 Meta-Cognition | Picking which model applies and catching your own bias | The act of using this table |

---

## Domain 1: Epistemic and Logic (Layer 1)

**M1. First Principles.**
Strip a problem down to the few things that must be true, then rebuild the answer from
those. The opposite is copying what someone else did and hoping the shape fits.
- *Reach for this when:* you hear yourself say "this is how it is normally done," or you
  are about to copy another system's structure into AIOS.
- *Trap:* rebuilding things that were already correct. It is expensive. Spend it on
  hard-to-reverse choices, not on picking a file name.
- *Binds to:* the ADR gate in `decisions/`. An ADR
  states the underlying constraint, not the precedent it copied.

**M2. Inversion.**
Instead of asking how this succeeds, ask how it fails, then delete the causes. Listing the
ways something breaks is far easier than imagining every way it works.
- *Reach for this when:* a plan looks obviously good, or right before any strategy is
  called final.
- *Trap:* listing the failures and then not changing the plan. An inversion that changes
  nothing was decoration.
- *Binds to:* the Cognitive Gate in
  [`modes/06-decision-vision-coach.md`](../modes/06-decision-vision-coach.md). No
  strategic output ships without a stated failure path.

**M3. Bayesian Updating.**
Start with a rough belief, then move it a little with each new piece of evidence, sized to
how strong that evidence actually is.
- *Reach for this when:* one bad week of numbers or one good sales call tempts a full
  strategy rewrite.
- *Trap:* both directions at once. Flipping on a single loud data point, and never moving
  at all. The fix is to say what would change your mind before the data arrives.
- *Binds to:* `ideal-state/predictions.md`. A prediction carrying a
  confidence number is a belief you can actually update.

**M4. Second-Order Thinking.**
Ask "and then what?" twice. The first effect is the one you wanted. The second one is the
one that bills you.
- *Reach for this when:* a change looks free. A new rule, a new tool, a new folder, a new
  subscription.
- *Trap:* infinite regress. Two orders is enough for almost every decision here.
- *Binds to:* [`standards/deletion-ladder.md`](../standards/deletion-ladder.md) and the
  Standing Risk entries in `BUILD-PLAN.md`.

## Domain 2: Systems and Operations (Layer 3)

**M5. Theory of Constraints.**
Every system has exactly one slowest step at a time. Improving any other step does not
make the system faster, it just piles work up in front of the slow one.
- *Reach for this when:* you feel busy but output is flat, or before adding capacity
  anywhere.
- *Trap:* optimizing the step that is most fun or most visible. Building AIOS tooling is
- *Binds to:* the Cognitive Gate in
  [`modes/06-decision-vision-coach.md`](../modes/06-decision-vision-coach.md), and the
  Acceptance Gate on each milestone in `BUILD-PLAN.md`.

**M6. Cybernetic Feedback Loop.**
A loop that measures its own output and feeds the reading back in. Reinforcing loops
compound, which is a flywheel. Balancing loops hold a level, which is a thermostat.
- *Reach for this when:* designing anything meant to run without you watching it.
- *Trap:* a loop with no sensor is a wish. Build the measurement before the mechanism.
- *Binds to:* Two-Tier Telemetry and
  [`scripts/Detect-Drift.ps1`](../scripts/Detect-Drift.ps1). Those are the sensors this
  repo actually has.

**M7. Poka-Yoke (mistake-proofing).**
Make the wrong move impossible instead of reminding yourself not to make it.
- *Reach for this when:* the same mistake happens twice.
- *Trap:* a check that only warns. If it does not block, it is a note, and notes get
  scrolled past.
- *Binds to:* the `.git/hooks/pre-commit` em-dash block and the drift gates. The zero
  em-dash rule holds because the hook rejects the commit, not because it is written down.

**M8. MECE, mutually exclusive and collectively exhaustive (Layer 2).**
Cut a problem into buckets that do not overlap and that leave nothing out.
- *Reach for this when:* a problem feels big and vague, or before any plan with more than
  three parts.
- *Trap:* tidy categories hiding a "misc" bucket doing the heavy lifting. If the leftovers
  matter, the split is wrong.
- *Binds to:* the Pre-Flight Thinking Checklist in [`AGENTS.md`](../AGENTS.md). Every
  agent decomposes before it writes.

## Domain 3: Strategy and Decision

**M9. OODA Loop.**
Observe, Orient, Decide, Act, then go again. You win by cycling faster than the situation
changes, not by making one perfect decision slowly.
- *Reach for this when:* the ground is moving, or you are stuck in analysis.
- *Trap:* speed with no Orient step is thrashing. Orient is where your read of the
  situation gets corrected, and it is the step people skip.
- *Binds to:* the two-bar definition of done,
  ADR-0002. The survival bar is what
  makes a fast cycle possible at all.

**M10. Asymmetric Upside.**
Prefer bets where the worst case is small and known and the best case is large and open.
- *Reach for this when:* spending money or a weekend on something unproven.
- *Trap:* counting only the cash. A cheap bet still occupies attention, and attention is
  the scarcer resource here. Ten cheap bets add up to one expensive one.
- *Binds to:* triage in `ideal-state/sparks.md`.

**M11. Opportunity Cost.**
The real price of anything is the best thing you gave up in order to do it.
- *Reach for this when:* saying yes to work, or adding a tool to the stack.
- *Trap:* pricing it in dollars only. The binding currency here is peak evening and
  late-night focus hours, when hyperfocus locks in.
- *Binds to:* the Tool Decision Tree in `tools/tools-index.md`.
  Absorb, Keep, or Kill is an opportunity-cost verdict wearing a different name.

**M12. Regret Minimization.**
For a decision you cannot undo, pick the option you would regret least looking back from
the end, not the one that scores best this quarter.
- *Reach for this when:* the choice is genuinely irreversible. Moving, quitting, taking on
  a partner.
- *Trap:* using it on reversible choices, where it inflates a small decision into an
  identity question. Reversible decisions get M9 instead.
- *Binds to:* `ideal-state/goals.md` and
  [`modes/06-decision-vision-coach.md`](../modes/06-decision-vision-coach.md).

## Domain 4: Human Execution (Layer 4)

**M13. Activation Energy.**
The cost of starting is a separate cost from the cost of doing, and it is usually the
bigger one. Lower the start cost and the task tends to run itself.
- *Reach for this when:* a task has sat on the list three or more days without being hard.
- *Trap:* reading it as a motivation problem. It is a setup problem. The fix is a smaller
  first step and a pre-staged environment, not more resolve.
- *Binds to:*
  `templates/page-activation-ramp.md`.

**M14. Habit Compounding.**
Small repeated actions beat large rare ones, because the small ones keep running.
- *Reach for this when:* designing any routine, review, or cadence.
- *Trap:* setting the daily bar at ambition level. Set it at worst-day level, so the
  streak survives a bad week and the good weeks take care of themselves.
- *Binds to:* the survival bar in
  ADR-0002.

**M15. Cognitive Offloading.**
Put state in the system, not in your head. Memory is for thinking with, not for storage.
- *Reach for this when:* you notice yourself deliberately trying to remember something.
- *Trap:* offloading into a place with no read path. A note nobody opens is worse than no
  note, because it feels handled.
- *Binds to:* `capture/`,
  `tasks/`, and the One Write Path rule in
  `CONTEXT.md`.

**M16. Working Memory Gate.**
You hold roughly four things at once. Past that, more open threads means slower, not more.
- *Reach for this when:* more than about three things are simultaneously in progress.
- *Trap:* confusing a long backlog with many open threads. A hundred queued tasks on disk
  cost nothing. Four half-finished ones cost everything.
- *Binds to:* WIP limits in `tasks/tasks-index.md`.

---

## How this file gets used

1. **Agents** run the Pre-Flight Thinking Checklist in [`AGENTS.md`](../AGENTS.md), which
   points here for the full definitions.
2. **Mode 06** blocks any final strategic recommendation that has not explicitly passed
   M2 (Inversion) and M5 (Constraint).
3. **{{OPERATOR_NAME}}** gets drilled on one model per substantive session, per the teach-and-quiz
   protocol in [`memory/soul.md`](../memory/soul.md), selected from his weakest layer in
   the most recent cognitive baseline under `audits/`.
