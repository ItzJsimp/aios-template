---
type: standard
id: standard-ai-build-protocol
title: "AI Build Protocol: how {{AIOS_NAME}} builds apps with agents"
description: "The working protocol for building the Command Center, Scribe and any {{AIOS_NAME}} app inside Leonidas Code or existing unattended workers, distilled from Anthropic's Claude Code best practices, Boris Cherny's workflow, spec-driven development (GitHub Spec Kit, Kiro) and Claude Design. Covers the Intent-to-Build-Menu step (agent proposes the full build, {{OPERATOR_NAME}} approves or denies per item), when to plan vs just build, when to spawn subagents and on which model, verification gates, design fidelity, context hygiene, and the error loop."
kind: state
load: on-demand
owner: aios
scope: structural
verified: 2026-10-02
generated: false
---
# AI Build Protocol

Why this exists: {{OPERATOR_NAME}} was dictating standard components (an Inbox, a Memories tab) one at a
time, and sessions lost calls to re-discovery and unverified "looks done" work. The best
practitioners fix both the same way: the agent carries the spec and the proof, the human
carries taste and approval. Rules marked ({{AIOS_NAME}}) are this repo's choice, not from a source.

## 1. Intent to Build Menu (the step {{OPERATOR_NAME}} asked for)

{{OPERATOR_NAME}} gives intent in one or two sentences. The agent does the rest before writing code:

1. **Research the category** (2 to 5 calls): what does a best-in-class version of this contain? Name 2 or 3 reference products and what each does well. Read the project's `agent-playbook.md` and existing components first, so the menu reuses what exists.
2. **Propose the Build Menu**: every element the finished thing should have, grouped as *Core* (it is broken without it), *Standard* (every good one has it) and *Stretch*. One line each: what it is, why, rough cost (S/M/L), and a default (on/off).
3. **{{OPERATOR_NAME}} approves or denies per item** in one reply (`all core+standard, drop 4, add 7`). Unclear items get one lettered question, never an open-ended one.
4. **Freeze the menu into a spec** (a task file or `spec.md`): files touched, out of scope, and one end-to-end check that proves it works.
5. **Build in slices**, one commit per slice, each with its check.

The agent never waits to be told a standard component exists. Missing an obvious element is a
menu failure, not a {{OPERATOR_NAME}} failure. ({{AIOS_NAME}}; Anthropic's docs recommend the agent interview the
user and write the spec before building, and Spec Kit marks gaps `[NEEDS CLARIFICATION]` rather
than inventing them.)

## 1b. Every AIOS build answers "where does this show in the Command Center?"

The [Command Center](../projects/aios-command-center/architecture.md) is how {{OPERATOR_NAME}} sees AIOS. Any new
script, folder, job, data source or skill states in its spec how it surfaces there (a card, a
column, a job row, a Library shelf, a notification), and either builds that or files a
`project: aios-command-center` task for it. Any control that spawns an agent or spends tokens
or money shows a confirmation naming the engine, model and rough cost first. ({{AIOS_NAME}}; {{OPERATOR_NAME}},
2026-09-26.)

Every automated writer into an inbox (`capture/`, `logs/`, `memory/_staged/`, `raw/`) ships in
the same commit as its reader and its close step: a `status:` lifecycle plus whatever moves an item
out (a reaper, a queue decision, a nightly drain). A writer with no close step builds a backlog that
looks active forever; the 2026-10-02 backlog audit found 81 continuation capsules and a 105-item
review queue that way. ({{AIOS_NAME}}; {{OPERATOR_NAME}}, 2026-10-02.)

## 1c. Frontier plans and reviews, workhorse swarm builds (Tiered Orchestration)

Governed by [standards/tiered-orchestration-standard.md](./tiered-orchestration-standard.md) and [skill-tiered-orchestration](../.agents/skills/tiered-orchestration/SKILL.md).
Planning chats (Opus 5.5 / GPT-6.1-Sol) end with a self-contained build brief: files, exact changes, out of scope, done-when checks, verify commands. The build is delegated to high-speed, cost-effective workhorse subagents (Claude Haiku 5.5, Gemini 3.8 Flash, GPT-5.6 Luna) via delegate_task or invoke_subagent.
When child tasks complete, the Frontier Orchestrator enforces the mandatory 5-point Review Gate (diff audit, typecheck verification, edge-case probing, regression check, senior polish) before delivering the unified result.

## 2. Plan or just build

| Situation | Do |
|---|---|
| The diff fits in one sentence | Build directly. Planning is overhead |
| Several files, unfamiliar code, or unsure of approach | Explore, then plan (plan mode or a written plan), then build |
| New feature or tab | Build Menu (section 1), then spec, then **a fresh session** builds from the spec |

Anthropic's own guidance: explore, plan, implement, commit; skip the plan when the diff is one sentence.

## 3. Subagents and models

- **Use a subagent to read, not to think for you.** Its value is a clean main context: investigation that would read 20+ files, a fresh-eyes review of a finished diff, or a long tool-heavy build via [`executor`](../.claude/agents/executor.md) (Sonnet).
- **Do not** use subagents for work that needs the conversation's decisions, or for a two-file change: the cold start costs more than it saves.
- **Models:** Opus plans, designs and reviews; Sonnet builds from a locked spec and runs test loops; Haiku greps and formats. Full routing: [`tools/model-router.md`](../tools/model-router.md).
- **Parallel sessions** only in separate worktrees, each with one job (build, review, docs). Two sessions in one file is the conflict pattern this repo already paid for.
- **Review with a second context:** before calling a feature done, a fresh subagent reviews the diff against the spec and reports only correctness or requirement gaps (asking it for "any issues" invites over-engineering).

## 4. Verification is the job, not a step

The single highest-leverage habit (Anthropic, Cherny: 2 to 3x quality): give the agent a check that returns pass or fail, and show evidence, not claims.

- Every slice leaves a runnable check (`scripts/check-*.ts`, a smoke route, a screenshot compared to the design).
- UI work ends with a browser read or screenshot of the running app, not "the typecheck passed".
- Data work samples the source once and sanity-checks the numbers before a card is built on it. A metric that is not live shows its last-updated time.
- Deterministic rules the agent must never skip become hooks, not prose (for example the em dash pre-commit hook).

## 5. Design fidelity without coding expertise

- **Show, do not describe.** A screenshot or reference product beats adjectives. Keep an inspiration board per project.
- **Claude Design** (Anthropic Labs, research preview since 2026-04-17, included in Pro): prototype a new screen by conversation against the repo's design system, then hand its bundle to Leonidas Code. Use it for new tabs or big redesigns; skip it for a card inside an existing tab, where copying an existing component is faster.
- **One design system file** ([`design-system.md`](./design-system.md)) and the [`app-building-standard.md`](./app-building-standard.md) baseline; the agent copies an existing component before inventing one.
- Close the loop visually: implement, screenshot, list differences against the reference, fix.

## 6. Context and error hygiene

- One task per session. Unrelated question mid-build: open another chat.
- After two failed corrections on the same issue, stop. Write down what was learned and start a fresh session with a better prompt; a long session full of failed attempts keeps failing.
- Errors are reported as Location, Cause, Fix, and fixed at the shared root (grep every caller first).
- Every session leaves the project's `agent-playbook.md` one line smarter: traps hit, checks added.

## 7. Engine choice for builds

| Engine | Use for |
|---|---|
| Leonidas Code | Anything touching the repo: builds, refactors, verification, commits |
| Connected provider in Leonidas Code | Authorized parallel sweeps and second opinions as delegated child work |
| Hermes | Chat-side and background jobs; not multi-file app builds |

## Sources

- [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices) (Anthropic docs)
- [Introducing Claude Design](https://www.anthropic.com/news/claude-design-anthropic-labs) (Anthropic, 2026-04-17)
- [How the creator of Claude Code uses Claude Code](https://paddo.dev/blog/how-boris-uses-claude-code/) and [InfoQ summary](https://infoq.com/news/2026/01/claude-code-creator-workflow/)
- [Spec-driven development in 2026](https://dev.to/krlz/spec-driven-development-in-2026-what-it-is-the-tooling-and-how-teams-actually-use-it-2fk2) (secondary; adoption numbers there are unverified)

## Done when

1. A new feature request produces a Build Menu before any code.
2. Each shipped slice names its check and shows its evidence.
3. The Command Center and Scribe playbooks link here.
