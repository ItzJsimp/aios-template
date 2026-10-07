---
name: quick-question
description: "Rapid, zero-fluff answers to quick queries or lookups using local memory or live web search."
category: research
scope: structural
disable-model-invocation: true
---

# Quick Question: Rapid Single-Shot Lookup Engine

Rapid, zero-fluff answer engine for single-shot questions, factual lookups, and quick queries. Bypasses multi-step planning, suppresses heavy footers, and delivers the answer directly.

## First-Run Calibration
On first run, Claude locates the user's resident memory files in `memory/` (e.g. `memory/core.md`, `memory/operator.md`, or `memory/user-profile.md`) to establish local fact lookups.

## Operating Invariants
1. **Direct Answer First:** The opening line delivers the core fact, command, number, or answer. No pleasantries.
2. **Zero Planning Artifacts:** Never emit unsolicited implementation plans or walkthrough files.
3. **Zero Em-Dash Standard:** Use colons, hyphens, or parentheses for punctuation.
4. **Token Density Budget:** Cap total response length under 150 to 250 tokens unless detailed expansion is requested.

## Execution Pipeline
- **Local Context Query:** Check `memory/` or repository files directly for user facts, configs, or project status.
- **External Web Query:** If external information is required, call the harness search tool immediately.
- **Output Structure:**
  - **Answer:** 1-3 crisp bullets or one dense paragraph.
  - **Source:** 1 line citing file or URL.
  - **Next Step:** 1 optional executable command if applicable.
