# AIOS Template: Your Personal AI Operating System

A complete, ready-to-personalize AI operating system for Leonidas Code: 80+ skills, 9 modes, a trust
contract, task and decision tooling, shared provider instructions, and an Obsidian visual graph. On first run your
AI interviews you and rebuilds this template around you: its name, where it lives, your goals, how you work.

## Setup (about 10 minutes)

1. **Install the prerequisites** (skip any you have):
   - Leonidas Code, with at least one supported provider account connected in Settings. Keep any runtime dependency requested by its provider setup.
   - [PowerShell 7](https://aka.ms/powershell) and [Git](https://git-scm.com/download/win)
   - Optional: [Obsidian](https://obsidian.md) for the visual graph
2. **Get the template**, either way works:
   - Click **Use this template** at the top of this page to create your own private copy, then clone it, or
   - Run `git clone https://github.com/ItzJsimp/aios-template.git "My AIOS"`
3. **Open that folder as a project in Leonidas Code** and select a connected provider.
4. **Say:** `Onboard me.`
5. Answer the interview. Your AI names itself, fills in your profile, sets up git, and links every skill.

## What you get

- **Response format:** every substantive answer opens with the active Mode and focus, and ends with a
  dock: `TL;DR`, `Immediate Next Actions` (yours and the AI's), and `Input & Decisions Needed` with
  lettered options and a recommendation. Defined in `memory/soul.md`.
- **Modes:** architect, assistant, health, finance, productivity, decisions, research, Windows, app
  builder. `modes/router.md` picks one per prompt.
- **Rules:** `AGENTS.md` (commit everything, capture tasks and preferences immediately, batch edits,
  pre-flight thinking checklist). `INTENT.md` says what the AI may do alone and what it must ask about.
- **Provider adapters:** Claude instruction imports and skill discovery remain compatible. Legacy terminal UI plugins are disabled by default.

## Optional: {{AIOS_NAME}} Scribe (voice dictation)

Free, system-wide voice dictation for Windows (Whisper plus LLM polish, free API tiers). Onboarding
offers to install it into `projects/aios-scribe/`, where spoken captures land in your `capture/`
folder. Manual install: `git clone https://github.com/ItzJsimp/leonidas-scribe.git projects/aios-scribe`, then run
`projects/aios-scribe/Setup.ps1`.

## Updates

Review changes before merging them into your personalized AIOS. Existing users can dry-run the [harness migration](./scripts/Update-AIOSHarness.ps1), then apply it after review; personal files are preserved and modified files are backed up.

Onboarding renames this repo's remote to `template`. Pull new skills and rules any time with
`git pull template main`.
