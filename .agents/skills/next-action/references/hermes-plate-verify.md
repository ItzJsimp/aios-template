# Hermes Plate Verify: Independent Completion Check

Absorbed from the retired `kanban-plate-verify` skill ([ADR-0065](../../../../decisions/0065-task-lifecycle-consolidation-and-delegation-gate.md)). A Hermes worker's completion summary is a self-report. Proven on the 2026-09-16/17 mem0 build: every silent failure that week (dossier overwritten by Build-Index, keepalive death mid-run, free-model zero-fact extraction) surfaced through this check, never through worker reports.

1. **Read the card fully:** `hermes kanban show <hermes_card>` (summary, metadata, comments, attachments). Turn every falsifiable claim, plus every `Done when` claim of the linked task file, into a verdict row.
2. **Probe each claim with the cheapest independent check that could refute it:** live endpoints (curl the URL), files (read the artifact), git (`git log`/`git show` with pathspec), database counts, scheduled tasks (`Get-ScheduledTask` in pwsh; git-bash mangles schtasks arguments).
3. **Re-run cited gates yourself** (eval gates, `-Status` doctors, `Audit-Substrate.ps1`). A green the worker printed is a claim; a green you executed is evidence.
4. **Attribute discrepancies before judging:** concurrent sessions share the repo, generated files get rebuilt by `Build-Index.ps1`, and probe-side errors (path mangling, wrong filenames) look like worker failures. Fix the probe before failing the plate.
5. **Verdict table to {{OPERATOR_NAME}}:** claim | probe | verdict. Accept: task stays `Awaiting Review` for {{OPERATOR_NAME}}'s approve. Reject: `hermes kanban request-changes <id>` naming the failing check and minimal fix, then `Invoke-TaskManagement.ps1 -Action Bounce` on the task.

Done when: every claim has a probe row backed by a real tool result, and at least one gate or ground-truth count was re-executed by the verifier.
