# Proof Gates: Red, Green, Verify, Complete

Absorbed from the retired `autonomous-slice` skill ([ADR-0065](../../../../decisions/0065-task-lifecycle-consolidation-and-delegation-gate.md)). Backed by [`scripts/skills/autonomous-slice/Invoke-AutonomousSlice.ps1`](../../../../scripts/skills/autonomous-slice/Invoke-AutonomousSlice.ps1). Use it for every `aios` lane slice so "I tested it" is always an executed exit code.

| Phase | Command | Gate |
|---|---|---|
| Red | `pwsh -NoProfile -File scripts/skills/autonomous-slice/Invoke-AutonomousSlice.ps1 -Phase Red -TestCommand "<probe>"` | Must fail before the change; exit 0 aborts with `RED GATE VIOLATION` |
| Green | same, `-Phase Green` | Must pass after the minimal change; non-zero aborts with `GREEN GATE VIOLATION` |
| Verify | `-Phase Verify` | Runs `Audit-Substrate.ps1`: 0 em dashes, 0 broken links, clean AST, valid frontmatter |
| Complete | `-Phase Complete -StageFiles @("<path>", "tasks/<slug>.md") -CommitMessage "Build: ..." -TaskFile "<slug>.md" -Resolution "..."` | Explicit-path staging only, prefix enum commit, task closed |

Rules: probes run non-interactively with clean exit codes; never `git add -A`; one slice per Red/Green cycle. For autonomous work, stop at `Awaiting Review` rather than `-Phase Complete` until {{OPERATOR_NAME}} approves.
