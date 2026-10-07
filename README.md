# AIOS Template: Your Personal AI Operating System

A complete, ready-to-personalize AI operating system for Claude Code: 80+ skills, 9 modes, a trust
contract, task and decision tooling, Claude Code mods, and an Obsidian visual graph. On first run your
AI interviews you and rebuilds this template around you: its name, where it lives, your goals, how you work.

## Setup (about 10 minutes)

1. **Install the prerequisites** (skip any you have):
   - [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) (Claude Pro or Max plan)
   - [PowerShell 7](https://aka.ms/powershell) and [Git](https://git-scm.com/download/win)
   - Optional: [Obsidian](https://obsidian.md) for the visual graph
2. **Get the template**, either way works:
   - Click **Use this template** at the top of this page to create your own private copy, then clone it, or
   - Run `git clone https://github.com/ItzJsimp/aios-template.git "My AIOS"`
3. **Open a terminal in that folder** and run `claude`.
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
- **Mods:** cache-clock, limit-watch and quick-replies are enabled in `.claude/settings.json`.

## Optional: {{AIOS_NAME}} Scribe (voice dictation)

Free, system-wide voice dictation for Windows (Whisper plus LLM polish, free API tiers). Onboarding
offers to install it into `projects/aios-scribe/`, where spoken captures land in your `capture/`
folder. Manual install: `git clone https://github.com/ItzJsimp/leonidas-scribe.git projects/aios-scribe`, then run
`projects/aios-scribe/Setup.ps1`.

## Updates

Onboarding renames this repo's remote to `template`. Pull new skills and rules any time with
`git pull template main`.
