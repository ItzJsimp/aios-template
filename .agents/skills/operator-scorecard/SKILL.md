---
name: operator-scorecard
description: "Read the weekly AI-native operator scorecard and frontier watch, explain the lowest pillar in plain English, and turn it into one experiment for the coming week."
category: knowledge
scope: structural
distribution: core
type: skill
id: skill-operator-scorecard
title: "Operator Scorecard: weekly self-improvement check"
kind: procedure
load: on-demand
owner: shared
---

# Operator Scorecard

Grades the human operator (not the AI) from the last 7 days of Claude Code transcripts. Runs itself every Sunday at 9 PM; this skill is for reading it and acting on it.

## When to use
The user asks how they are doing with AI, wants to improve their score, or opens a new week.

## Steps
1. Read `logs/operator-scorecard-report.md` (latest week). If missing or older than 8 days, run `python scripts/score-operator.py` (add `--judge` for the free prompt critique).
2. Name the single lowest pillar, its score, its change vs last week, and the evidence session (`evidence_session` in the last line of `logs/operator-scorecard.jsonl`).
3. Offer exactly one experiment for the coming week from the report's "How to raise the score" list. Do not list every tip.
4. Read `logs/frontier-watch.md`. For each tactic, say whether AIOS already covers it or it is a gap; propose adopting at most one.
5. Next week, compare the pillar you targeted. If it did not move, change the experiment instead of repeating it.

## Pillars (0-100, deterministic)
prompting, oversight, delegation, tool_adoption, context_hygiene, cost_efficiency. The overall score is their mean. The optional prompt critique is advisory and never changes a score.

## Rules
- Never grade per turn or call a paid model for scoring.
- Manual runs: `python scripts/score-operator.py --dry-run` prints without writing; `python scripts/frontier-watch.py --dry-run` does the same for the feed.
