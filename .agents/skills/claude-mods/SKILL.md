---
name: claude-mods
description: "Single interface for Claude Code mods (function-hook plugins): research, adopt, build, manage and audit them."
category: system
scope: structural
disable-model-invocation: true
---

# Claude Mods: Research, Build, Manage, Audit

A mod is a Claude Code plugin whose `hooks/register.tsx` exports `register(on, options)` and hooks events or draws UI (band, pane, status line, toast). Loaded in-process and hot-reloaded.

## Installed System Mods
- `cache-clock`: Live prompt cache countdown band with hit percentage and token headroom meter.
- `limit-watch`: Subscription quota countdown and `/limit-watch` usage pane.
- `quick-replies`: Clickable reply directive pills for rapid one-click interaction.

## Mod Configuration
Mods live in `mods/<mod-name>/` and are registered in `mods/.claude-plugin/marketplace.json`. To enable a mod in Claude Code, ensure it is set to `true` under `enabledPlugins` in `.claude/settings.json`.
