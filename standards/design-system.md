---
type: standard
id: standard-design-system
title: "Design System: {{AIOS_NAME}}"
description: "Canonical {{AIOS_NAME}} design system for every app, doc and PDF. Two registers on one token set: Command (dark obsidian apps; crimson, electric cyan, gold with glows) and Dispatch (Linen Sand paper docs and PDFs; darker accent twins). Fonts: Big Shoulders Display, Archivo, Newsreader, JetBrains Mono. Soft 8/12/16 radii. Tokens live in the Command Center's tokens.css; this doc is the usage contract."
kind: state
load: on-demand
owner: aios
scope: structural
verified: 2026-09-24
generated: false
---
# Design System: {{AIOS_NAME}}

**Token source of truth:** [`projects/aios-command-center/src/tokens.css`](../projects/aios-command-center/src/tokens.css). Values live there only; this file says how to use them.
- Command Center compiles the file through Tailwind v4 `@theme static`, so every token is both a utility (`bg-crimson`, `font-display`, `rounded-card`) and a CSS variable (`var(--color-crimson)`).
- Scribe (Qt) and PDF pipelines mirror the same hex values.
- The project folder rename to `aios-command-center` is complete.

**Visual reference:** [`assets/branding/design-system.html`](../assets/branding/design-system.html). Open it in any browser.

**Decided by {{OPERATOR_NAME}}** in the design-taste grill ([`logs/grill-sessions/2026-09-23-aios-design-system-taste.md`](../logs/grill-sessions/2026-09-23-aios-design-system-taste.md)): palette P1, fonts T1, `//` mono labels, Dispatch D2, teal on paper, soft corners, Linen Sand paper, two registers, and the name **{{AIOS_NAME}} Command Center**.
**Chosen by {{AIOS_NAME}}:** contrast calibrations, paper accent hex values, and the component recipes below.

**Supersedes** the Personal track palette in [`design-preferences.md`](./design-preferences.md). That file still governs the Capsule HUD, desktop packaging and the {{BUSINESS_NAME}} track.

## Two registers, one token set

| Register | Surfaces | Canvas | Feel |
|---|---|---|---|
| **Command** | Command Center, Scribe, every app and widget | Obsidian `#07070A`, dark only | Dense, tactical, glowing, glanceable |
| **Dispatch** | Docs, PDFs, reports, landing pages | Linen Sand paper `#EEE6D6`, never white | Calmer, more whitespace, serif reading body |

Colors keep their meaning across registers. On paper each accent becomes its darker twin, so contrast holds.

## Color roles

Each hue has one job. Color alone never carries meaning: pair it with an icon or a text label.

| Role | Command | Dispatch | Job | Never |
|---|---|---|---|---|
| Primary | `crimson` `#D92626` | `paper-crimson` `#A8221B` | Brand, primary action, active-nav bar, the one thing to press | Small text on obsidian (4.1:1). Use `crimson-text` `#F05252` |
| Interaction | `cyan` `#00E5FF` | `paper-teal` `#0A6474` | Focus, links, selection, live and streaming state, the `//` label prefix, chart series 1 | Large fills |
| Status | `gold` `#F59E0B` | `paper-gold` `#735A1F` | Attention, pending, warnings, "Critical" tier, KPI highlights | Success or brand |
| Success | `success` `#10B981` | `paper-success` `#0B6B4A` | Complete, synced | Decoration |
| Error | `error` `#FF4D6D` | `paper-error` `#A3173F` | Errors, destructive confirms | Brand. It is rose-shifted so it never reads as crimson |

`*-soft` tokens (12% alpha) sit behind badges in the matching text color.

**Glow** is part of Command's identity. Use `shadow-glow-cyan` for live items only (never for focus, {{OPERATOR_NAME}} 2026-10-04), and `shadow-glow-crimson` only on the single primary action in view. Allow one glowing element per region; a screen where everything glows has nothing that stands out. Dispatch never glows.

## Command surfaces

| Tier | Token | Use |
|---|---|---|
| 0 | `obsidian-950` `#07070A` | Canvas |
| 1 | `obsidian-900` `#0E0E12` | Sidebar, page sections |
| 2 | `obsidian-850` `#15151B` | Cards |
| 3 | `obsidian-800` `#1D1D25` | Hover, popovers, dialogs |
| Border | `obsidian-700` / `obsidian-600` | Default / strong borders |

- Step up one tier per layer; never skip two.
- **Glass** (overlays, Action Center widgets): `bg-glass backdrop-blur-glass border border-hairline shadow-card`, on tier 2 and above only.
- **Text:** `ink` `#F4F4F5` (18.3:1), `ink-muted` `#A1A1AA` (7.9:1), `ink-dim` `#84848E` (5.4:1).

## Dispatch surfaces

- **Page:** `paper` `#EEE6D6`.
- **Callouts and table header rows:** `paper-raised` `#E4D9C3`.
- **Rules:** `paper-rule` `#CFC2A8`.
- **Ink:** `paper-ink` `#1F1A14` (13.9:1), `paper-ink-muted` `#4A4236`, `paper-ink-dim` `#5F5647`.
- **Contrast:** every paper accent clears 4.5:1 on both the page and callout backgrounds.
- **Decisions and key callouts:** a 3px `paper-crimson` left rule on `paper-raised`.

## Typography

| Role | Font | Where |
|---|---|---|
| Display | **Big Shoulders Display** 800, often uppercase | Page headers, titles, the Command Center wordmark. **20px minimum**: below that its narrow letters blur |
| Hero (Command) | **Archivo** 600, sentence case, `tracking-tight` | Hero titles inside cards, such as the Home daily brief (decided by {{OPERATOR_NAME}} 2026-09-26). Big Shoulders stays for the wordmark and page headers |
| Body (Command) | **Archivo** 400/600 | UI text, buttons, inputs, tables |
| Body (Dispatch) | **Newsreader** 400, 14px+, line-height 1.55 | Long-form reading in docs and PDFs |
| Numbers and labels | **JetBrains Mono** with `tabular-nums` | Every number, ID, timestamp and dollar amount. Also section labels |

**Section labels** use JetBrains Mono, 11px, uppercase, `tracking-[0.04em]`, `ink-label`, with a cyan `//` prefix: `// ATTENTION QUEUE`. This replaced small Big Shoulders labels, which {{OPERATOR_NAME}} found hard to read.

| Token | Size | Use |
|---|---|---|
| `text-micro` | 10px | Badges |
| `text-label` / `text-caption` | 11px | `//` labels / timestamps |
| `text-body` | 12px | Command body |
| `text-title` | 14px | Card titles, Archivo 600 |
| `text-heading` | 20px | Page headers, Big Shoulders |
| `text-display` / `text-kpi` | 32px | Hero and Dispatch titles / big numbers (mono) |

All four fonts are free (OFL) and must ship as files: in the Command Center's bundle, in Scribe's PyInstaller build, and embedded in PDFs. They are never loaded from a CDN in production.

## Assets: where everything lives

Use these paths directly; nothing needs to be searched for or downloaded again.

| Asset | Path | Use |
|---|---|---|
| Tokens (source of truth) | [`projects/aios-command-center/src/tokens.css`](../projects/aios-command-center/src/tokens.css) | Tailwind v4: `@import "./tokens.css";` |
| Fonts, static TTF, 12 files | [`assets/fonts/`](../assets/fonts/fonts.css): `big-shoulders-display/` (700, 800), `archivo/` (400-700), `newsreader/` (400, 600, italic), `jetbrains-mono/` (400, 600, italic) | Web, Qt and PDF, one file set. Each folder carries its `OFL.txt` |
| `@font-face` sheet | [`assets/fonts/fonts.css`](../assets/fonts/fonts.css) | Web: `<link href=".../assets/fonts/fonts.css">`, or copy the folder into an app's `public/` |
| Font fetcher | [`scripts/get-design-fonts.py`](../scripts/get-design-fonts.py) | Re-run only when a family or weight changes |
| Visual reference | [`assets/branding/design-system.html`](../assets/branding/design-system.html) | Loads the bundled fonts, works offline |
| {{AIOS_NAME}} avatar (the one icon for every component) | [`assets/branding/avatar-master.png`](../assets/branding/avatar-master.png), 2048px | Never edited; every icon derives from it |
| App icons, favicon, PWA | [`assets/branding/icons/`](../assets/branding/icons/manifest.json) | Built by the [`brand-icons`](../.agents/skills/brand-icons/SKILL.md) skill; never hand-made per app |

**Qt (Scribe):** call `QFontDatabase.addApplicationFont(path)` on each TTF at startup, then use the family names above. Add `assets/fonts/**` to the PyInstaller `datas`.
**PDF (Dispatch):** embed the same TTFs (WeasyPrint `@font-face`, or ReportLab `TTFont`).

## Shape, space, motion

- **Radius (soft):** `rounded-control` 8px, `rounded-card` 12px, `rounded-panel` 16px, `rounded-full` for pills and the Capsule HUD.
- **Spacing:** 4pt grid.
  - Command: card padding 16px, 12px gaps.
  - Dispatch: roughly double both, with a 64-72 character reading measure.
- **Motion:** expressive: 150ms micro, 240ms entrances, bursts up to 900ms, ambient 12-20s loops, and sound on actions, with a Calm switch and `prefers-reduced-motion` honoured. Full rules: [`app-building-standard.md`](./app-building-standard.md) §6.

## Component recipes (Command)

- **Primary button:** `bg-crimson hover:shadow-glow-crimson active:bg-crimson-press text-white rounded-control`. One per view. Hover adds the glow and keeps the crimson fill: white on `crimson-hover` is 4.2:1, under the 4.5:1 floor for 12px text (decided by {{OPERATOR_NAME}} 2026-09-24). `crimson-hover` stays for fills without text.
- **Secondary button:** `bg-obsidian-800 border border-obsidian-700 hover:border-obsidian-600`.
- **Focus:** one thin cyan outline that follows the element's corners (global rule in `src/index.css`, `@layer base`), never a glow and never a square box; every focusable control has a radius ({{OPERATOR_NAME}} 2026-10-04). A control that must show no ring, such as the search field, sets `outline-none`.
- **Active nav item:** a 2px `crimson` left bar, `obsidian-800` fill, `ink` text.
- **Status badge:** `bg-{role}-soft text-{role} text-micro uppercase rounded-full`.
- **Confirm dialog:** `rounded-panel bg-obsidian-800`. The destructive confirm is `bg-error`, never crimson.

## Done when

1. Every hex value in this file matches [`tokens.css`](../projects/aios-command-center/src/tokens.css).
2. [`design-system.html`](../assets/branding/design-system.html) renders both registers and every token listed here.
3. No Command Center component uses a raw Tailwind palette color where a token exists, and Scribe's `T` dict uses only these values (tracked in the two redesign tasks).
