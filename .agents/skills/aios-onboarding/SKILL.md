---
name: aios-onboarding
description: "First-run interview that turns this AIOS template into the operator's own personal AI operating system: names it, places it, fills every {{PLACEHOLDER}}, profiles hardware, and verifies skills and mods."
scope: structural
---

# AIOS Onboarding

Run when [`memory/operator.md`](../../../memory/operator.md) still contains `{{...}}` placeholders, or when
the operator says "set me up", "onboard me", or pastes the README onboarding prompt.

## 1. Interview (one round at a time, max 4 questions per round)

Ask conversationally; offer 2-4 concrete example answers per question so the operator can pick fast.
Accept "skip" and use the default in brackets.

**Round 1: Identity**
- `AIOS_NAME`: What should your AI be called? (examples: Atlas, Jarvis, Nova, Sage)
- `OPERATOR_NAME`: What should it call you?
- `REPO_PATH`: Where should it live? [`{{DATA_DRIVE}}\<AIOS_NAME> AIOS` if a D: drive exists, else `%USERPROFILE%\<AIOS_NAME> AIOS`]. Recommend a path with no emoji.
- `CITY` and `TIMEZONE`: Where are you based? [ask; derive timezone from city]

**Round 2: Direction**
- `OPERATOR_ONE_LINER`: In one sentence, what do you do or what are you building?
- `GOALS`: Top 1-3 goals for the next 6-12 months (with a number or date if possible).
- `WORK_CONTEXT`: School, job, business, or projects that eat your week?
- `PEOPLE`: Anyone the AI should know by name (partner, cofounder, friends)? [none]

**Round 3: How you work**
- `FOCUS_WINDOW`: When do you actually get deep work done? (morning / afternoon / night / varies)
- `EXECUTION_STYLE`: What gets in your way most? (starting, finishing, focus, too many ideas)
- `BUDGET_STANCE`: Money stance for tools and services? (free first / some budget / cost no object)
- `COMMUNICATION_PREFS`: Answer style? (short and direct / detailed / step by step)
- `AI_RELATIONSHIP`: What do you want from your AI most? (thought partner, assistant, teammate, the system itself)

**Round 4: Business (optional)**
- `BUSINESS_NAME`: Do you run a business or brand? [none: write "my business"]
- `PARTNER_NAME` / `COLLABORATOR_NAME`: business partner or main collaborator [none: "my partner" / "my collaborator"]
- `BUSINESS_AIOS_NAME` / `BUSINESS_REPO_PATH`: only if they want a separate business AIOS later [defaults: "<BUSINESS_NAME> AIOS", "<parent of REPO_PATH>\<BUSINESS_NAME> AIOS"]
- `OPERATOR_EMAIL`: optional, used only for git authorship [skip]

Fill derived values silently: `USER_HOME` = `$HOME`, `DATA_DRIVE` = drive letter of `REPO_PATH`
(for example `D:`), `MACHINE_NAME` = `$env:COMPUTERNAME`.

## 2. Confirm

Show a compact table of every answer. Ask "ship it?" before writing anything.

## 3. Apply

Write the answers to `onboarding-answers.json` (flat `{"AIOS_NAME": "...", ...}`) in the current folder, then run:

```powershell
pwsh -NoProfile -File scripts/Initialize-AIOS.ps1 -AnswersFile onboarding-answers.json
```

The script copies the template to `REPO_PATH` (if different), replaces every placeholder, renames
`ask-aios` to `ask-<name>`, runs `git init` plus a first commit, links skills into `.claude/skills/`,
and lists any placeholder still unfilled. Fix those by asking, then rerun (it is idempotent).

## 4. Hardware profile

Run the PowerShell discovery block in [`.agents/skills/_shared/pc-machines.md`](../_shared/pc-machines.md),
fill its table, and save a copy to `memory/pc-system-profile.md`.

## 5. Optional: voice dictation

Ask: "Want voice dictation ({{AIOS_NAME}} Scribe, free)?" If yes, from `REPO_PATH` run:

```powershell
git clone https://github.com/ItzJsimp/leonidas-scribe.git projects/aios-scribe
pwsh -NoProfile -File projects/aios-scribe/Setup.ps1
```

Then walk them through getting a free Groq key at https://console.groq.com/keys and pasting it in
Scribe's Settings > Models. Spoken captures land in `capture/`.

## 6. Hand off

If `REPO_PATH` differs from the current folder, tell the operator exactly:
"Close this window, open a terminal in `<REPO_PATH>`, run `claude`, and say hi." Then they are live.
Recommend installing Obsidian and opening `REPO_PATH` as a vault for the visual graph.
