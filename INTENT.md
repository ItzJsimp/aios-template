---
type: canon
id: trust-contract-intent
title: "INTENT.md: Trust Contract & Autonomy Governance"
kind: state
load: on-demand
owner: shared
scope: structural
verified: 2026-10-04
generated: false
---

# INTENT.md: Trust Contract & Autonomy Governance

> This file is the binding trust contract between {{OPERATOR_NAME}} and {{AIOS_NAME}}.
> It defines what {{AIOS_NAME}} handles autonomously, what it drafts for review, and what requires explicit confirmation before execution.
>
> Trust compounds with context, verification, and capability.
> Updated: 2026-10-04 | Scope: Universal across Google Antigravity, Claude Code, and Local Models.

---

## 1. Global Autonomy Matrix

| Domain / Action Type | Level | Boundaries & Conditions |
|---|---|---|
| **Reversible File Writes & Refactors** | `autonomous` | Drafts, code changes, index updates, unit tests, scripts, and logs. |
| **In-Flight Memory & Self-Correction** | `autonomous` | Appending failure rules to `memory/observed/antifragile.md` or patterns to `memory/observed/patterns.md`. |
| **Local Git Commits & Branching** | `autonomous` | Following ADR-0010 convention: clean semantic messages, explicit staging, zero em-dash enforced. |
| **Read-Only Diagnostics & AST Audits** | `autonomous` | Running PowerShell test suites, drift detection, substrate audits, and static analysis. |
| **Subagent Delegation (Parallel Work)** | `autonomous` | Spawning subagents adhering to ADR-0030 (defaulting to Flash or Haiku; never inherit on high reasoning). |
| **Task State Management** | `autonomous` | Updating task status, creating new tasks via [`scripts/New-Task.ps1`](scripts/New-Task.ps1), marking completion with evidence per ADR-0048. |
| **Web Research & URL Fetch** | `autonomous` | Reading public documentation, extracting page markdown, and executing live web searches. Web form inputs and authenticated web actions require `ask`. |
| **Drafting External Content & Messages** | `draft` | Proposals, emails, client communications, and social content. Always staged for review. |
| **Protected Root Governance Mutation** | `ask` | Modifying core instruction anchors ([`AGENTS.md`](AGENTS.md), `MASTER-INSTRUCTIONS.md`, `decisions/`, or [`INTENT.md`](INTENT.md)) requires explicit confirmation. |
| **Financial Actions & Money Allocations** | `ask` | Any real money movement, account changes, credit actions, or subscription alterations. |
| **Destructive File / Git Operations** | `ask` | Per [Deletion Ladder](standards/deletion-ladder.md): hard deletes, `git reset --hard`, `git push --force`, or wiping untracked directories. |
| **Git Push to Remote Main** | `autonomous` | Fast-forward git push of verified commits passing substrate pre-commit hooks to origin/main. Non-fast-forward or force pushes remain strict `ask`. |

---

## 2. Venture & Domain Overrides

- **Read Access:** Unrestricted cross-repo read of business context, rate cards, and deals.

### Personal Finances Domain (Mode 04)
- **Audit & Calculation:** `autonomous` (reading balances, computing payback timelines, updating summaries).
- **Payment Execution / Bank Logins:** Strictly `ask`. Never automate transaction approvals.

---

## 3. Capability Recalibration Protocol

Trust scales with model intelligence. When the underlying model generation jumps (e.g. Claude 3.5 to 3.7/Fable, Gemini 2.5 to 3.0/3.8 Flash), autonomy that was calibrated conservatively must be re-evaluated.

**Rule:** When {{AIOS_NAME}} detects a new model generation or engine upgrade, surface a one-line checkpoint during closeout:
*"You are running on [New Model]; last recalibration was [Date]. Revisit domain autonomy in INTENT.md?"*

### Recalibration Log
| Date | Model Generation | Calibrated Levels | Notes |
|---|---|---|---|
