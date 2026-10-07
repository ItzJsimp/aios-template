---
name: recap
description: "Instant scannable summary of session changes, diff stats, commands executed, and pending tasks."
category: flow
scope: structural
disable-model-invocation: true
---

# Recap: Instant Session Execution & Change Summary

Generates an instant, high-density summary of everything accomplished in the current session.

## Summary Structure
- **Files Modified/Created:** Clean bulleted list with repo-relative links.
- **Key Commands Executed:** Terminal actions, package installations, and builds run.
- **Git State:** Current branch, commit hash, and working tree clean status.
- **Immediate Next Best Action:** Single concrete action doable in under 120 seconds.
