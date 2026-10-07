---
type: standard
id: standard-app-building
title: "App-Building Standard: how {{AIOS_NAME}} builds apps"
description: "How every {{AIOS_NAME}} app is built and behaves: per-tab layout templates (card grid, workbench, list + detail) saved in a git-tracked layout file, comfortable-by-default density with per-section overrides, click-first input with a mirrored command palette, AI via decision cards + embedded terminals + context-aware side chat over one multi-engine adapter (Claude, Gemini, Hermes, Ollama), a baseline feature set, and expressive motion and sound. Pairs with design-system.md for the look."
kind: state
load: on-demand
owner: aios
scope: structural
verified: 2026-09-25
generated: false
---
# App-Building Standard: how {{AIOS_NAME}} builds apps

**How things look** lives in [`design-system.md`](./design-system.md). **This file says how apps behave and are built.**

**Reference implementation:** {{AIOS_NAME}} Command Center ([`projects/aios-command-center/`](../projects/aios-command-center/)). Scribe and every future app follow the same rules where they apply.

**Decided by {{OPERATOR_NAME}}** in the app-taste grill ([`logs/grill-sessions/2026-09-23-aios-app-building-taste.md`](../logs/grill-sessions/2026-09-23-aios-app-building-taste.md)).
**Chosen by {{AIOS_NAME}}:** the routing rules, motion timings, sound defaults and file locations below.

## 1. Layout: templates per tab, customizable, one file

| Template | Default for | Shape |
|---|---|---|
| **Card grid** | Home, Inbox, any "state of everything" tab | Sidebar + grid of live cards |
| **Workbench** | AI Sessions, Files, any "do the work" tab | Icon rail · explorer · embedded terminals · side panel (nudges, running sessions) |
| **List + detail** | Inside pages: Tasks, captures, decisions | A focused list; the selected item opens beside it |

- **One layout file, git-tracked.** In Command Center that is `config/layouts.json`. It holds every tab's template, card order, card sizes and density.
  - {{OPERATOR_NAME}} can ask {{AIOS_NAME}} to change a layout ("put the Inbox above Tasks"), and {{AIOS_NAME}} edits the file. The app hot-reloads it.
- **Build order:**
  1. Presets and the file.
  2. Drag-and-drop in the app, saving back to the same file, with **Save as template** and **Reset to default**.
- **One layout for every device.** Phones reflow to a single column, and card order in the file is the priority order on the phone. There are no per-device layouts.

## 2. Density: comfortable by default, per-section override

| Density | Row height | Use |
|---|---|---|
| Compact | 28px | Status boards, logs, dense tables |
| **Comfortable (default)** | **40px** | Lists you scan all day |
| Spacious | 56px, two-line items | Small sets where each item needs context |

Set density per section in the layout file. Tokens: `--density-row-compact`, `--density-row-comfortable` and `--density-row-spacious` in [`tokens.css`](../projects/aios-command-center/src/tokens.css).

## 3. Input: click-first

- Every important action is a **visible button**. Nothing important hides behind a shortcut or a right-click.
- The **⌘K palette** (Ctrl+K on Windows) mirrors every button and adds navigation. It speeds up repeats; it is never the only way.
- Every write action shows a **confirm** step (for anything destructive or outward-facing), then a **toast with Undo**.

## 4. AI inside apps: three surfaces, one engine adapter

1. **Decision cards:** AI prepares the work and {{OPERATOR_NAME}} taps **Approve** or **Reject** in place (the Command Center's Attention Queue).
2. **Embedded terminals:** real PTY terminals (xterm.js on the page, node-pty on the server) running any engine CLI or a full shell.
   - Reachable from **any device on {{OPERATOR_NAME}}'s Tailscale network**. Tailscale device auth is the only gate: an accepted risk, recorded in [ADR-0058](../decisions/0058-aios-cockpit-is-a-tailscale-served-web-app.md) amendment 2026-09-23.
   - Sessions are **named** so they can be listed, resumed and killed, a pattern borrowed from the AIOS app.
3. **Side chat:** an "ask" panel on every screen that receives what is currently on screen as context.

**The engine adapter** is one server-side interface: `run(engine, prompt, context)` streams output, and `spawn(engine)` opens a terminal.

| Engine | Headless call | Plan it spends | Auto-route when |
|---|---|---|---|
| Claude Code | `claude -p` (run in the repo, so canon loads) | Claude subscription | Anything touching {{AIOS_NAME}} canon, memory, files or decisions (the default) |
| Gemini | Gemini REST API, `gemini-3.6-flash`, streamed (Gemini CLI is retired for individual accounts, 2026-09-23) | Gemini API free tier, `GEMINI_API_KEY` | Long research, very large context, web-heavy questions |
| Hermes | `hermes -z` | OpenRouter credits (real dollars) | Background, scheduled or messaging work |
| Ollama | `ollama run gemma3:4b` (fits the 12 GB GPU; `gpt-oss:20b` failed for memory) | Free, local | Quick lookups, rewording, anything private or offline |

- The router picks by those rules and shows an **engine chip** (for example `Claude`).
- **One tap overrides it.**
- The chip always shows which plan is being spent.

## 5. Baseline: every app ships these

- **⌘K palette**, **confirm + Undo toast**, and designed **empty** and **loading** states (skeletons, never spinners on a blank page).
- **Time-aware nudge:** one button that always shows the next ritual for the time of day (morning plan, close the day, weekly plan). Borrowed from the AIOS app.
- **Live status dots** on anything running (sessions, syncs, scheduled tasks).
- **Per-engine usage meters** (Claude, Gemini, Hermes, Ollama), so {{OPERATOR_NAME}} sees which plan is burning.
- Not in the baseline: a first-run tour, a shortcuts sheet, a settings page, and push notifications. Add them per app only when someone other than {{OPERATOR_NAME}} will use it.

## 6. Motion and sound: expressive, with a Calm switch

| Kind | Budget | Examples |
|---|---|---|
| Micro | 150ms `ease-soft` | Hover, press, toggle |
| Entrance | 240ms | Cards, dialogs, toasts |
| Celebration | Up to 900ms | Success burst on a completed task or approved decision |
| Ambient | 12-20s loops | Slow crimson and cyan drift in the canvas background, breathing live dots, glowing edges on the active item |

- **Sound on actions:** short synthesized earcons (the same harmonic-sine style as Scribe) for approve, complete, error and spawn. On by default at low volume, with one mute toggle.
- **Guardrails:**
  - `prefers-reduced-motion` turns off ambient motion and bursts in web apps. Windows desktop apps do not follow the OS "Animation effects" switch: {{OPERATOR_NAME}} keeps it off for a snappier desktop and still wants his apps animated (2026-09-25), so their Calm switch is the only control.
  - A **Calm** switch in the app does the same on demand.
  - Glow stays limited to one element per region ([`design-system.md`](./design-system.md)).

## 6b. Data and telemetry: live, deterministic, code only

Set by {{OPERATOR_NAME}} on 2026-09-25 for every app he builds. Every number an app shows is derived by code from its source of truth and recomputed the moment that source changes; nothing is typed in, refreshed by hand, or produced by a model.

- **One source, derived views.** Counts, medians, totals and rates are computed from the raw log or file (Scribe: `history.jsonl`, `dictionary.json`), never kept in a second hand-maintained store that can drift.
- **Recompute on change, not on a schedule.** The writer emits an event (Scribe's `sig_history_updated`) and a file watcher (`QFileSystemWatcher`, or `fs.watch` on the web) catches edits made by anything else, so a new transcript, word or latency sample shows up instantly. Pages that are hidden recompute when they are shown.
- **Measure, then label.** A figure that is an estimate says so on screen until real measurements exist (Scribe's speaking pace shows "estimated" until 30 s of measured speech).
- **Free to run.** Metrics are plain code over local files: no scheduled job, no model call, no API. A model may write prose on top of computed numbers (Scribe's weekly voice profile summary), never the numbers themselves, and the report still ships if that call fails.
- **Thresholds alert themselves.** A limit that matters (Scribe: median latency of the last 20 dictations) is checked in-process on every new sample and raises one native notification, then a cooldown, instead of waiting for someone to look.

## 7. Borrowed from The AIOS app (patterns only)

The public AIOS app is GPL-2.0, so we copy ideas and never code ([gap analysis](../projects/aios-command-center/research/2026-09-23-the-aios-app-gap-analysis.md)). The ideas Command Center takes:
- The time-aware nudge.
- Named, resumable sessions and a session launcher (their spawn-inbox command bus is the model).
- The ⌘K palette.
- Switchable layouts.

## Done when

1. the Command Center's layout file exists and every tab resolves to one of the three templates.
2. The engine adapter answers the same prompt through all four engines, and the chip shows the routed one.
3. Every baseline feature in §5 is present in Command Center.
4. The Calm switch (and, in web apps, `prefers-reduced-motion`) silences ambient motion, bursts and sound.
5. Every metric an app shows traces to code over its source file and updates without a manual refresh (§6b).
