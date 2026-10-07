---
name: aios-audit
description: "Comprehensive {{AIOS_NAME}} audit: Substrate Health Gate, link integrity, task hygiene, and skill discovery."
category: system
scope: structural
disable-model-invocation: true
---

# {{AIOS_NAME}} OS Audit: Substrate Health & System Maturity Audit

Verifies every claim against disk, checks link integrity, audits task queues, and ensures all skills are properly discovered by Claude Code.

## The 4 Governance Gates
1. **Substrate Health Gate:**
   - Zero broken relative markdown links across the repository.
   - Zero em-dash (U+2014) characters in markdown, code, and documentation.
   - Zero syntax errors in PowerShell and Python scripts.
2. **Skill Discovery Gate:**
   - Verify every folder in `.agents/skills/` has a valid junction or copy in `.claude/skills/`.
   - Run `pwsh scripts/Sync-AgentSkills.ps1` if discrepancies exist.
3. **Task Hygiene Gate:**
   - Check `tasks/` for completed tasks needing closure or stale cards lacking acceptance criteria.
4. **Four Cs Maturity Index:**
   - **Correctness:** Do documentation claims match verifiable code on disk?
   - **Completeness:** Are required templates, references, and standards in place?
   - **Conciseness:** Are prompts and instructions high-density without filler?
   - **Compounding:** Does each session build durable knowledge in `memory/` rather than starting cold?

## Output
Outputs a structured report to `audits/YYYY-MM-DD-aios-audit.md` and appends a summary row to `audits/audit-history.jsonl`.
