---
type: canon
id: drive-taxonomy
title: "D Drive File System & AI Routing : System Hub"
description: >
  Canon for the AIOS D Drive: folder taxonomy, naming standard, routing
  rules and confidence threshold for anything landing on the drive
  outside {{REPO_PATH}}\ and {{BUSINESS_REPO_PATH}}\, which are their own canonical
  repositories per ADR-0006.
kind: state
load: on-demand
owner: aios
scope: personal
verified: 2026-09-10
sources: []
related: ["master-instructions", "0006-local-first-substrate-split-by-reader"]
generated: false
---
# D Drive File System & AI Routing : System Hub

**Provenance note: condensed, not verbatim.** The live Notion page is 90,000+
characters and the API's own markdown conversion returned it marked `truncated: true`: there is more content on the live page than even a full fetch retrieved. This export
carries the taxonomy, naming standard, and the current state; it drops the full Ollama
routing-engine implementation detail (deterministic rule tables, model bake-off history,
the multi-phase migration log) as operational detail for the drive's own automation, not
AIOS behavioural canon. **The live Notion page remains authoritative for that detail.**
Exported and condensed 2026-08-17, updated same day after live verification below.
**Confirmed by {{OPERATOR_NAME}} 2026-08-18**: the wiki-boundary rule and the routing-engine fixes
both reviewed and approved.

**Risk flag added 2026-08-21, per [ADR-0011](../decisions/0011-notion-retired-for-aios-kept-for-{{BUSINESS_NAME}}.md).**
Notion is retired as AIOS's substrate and the personal subscription may lapse. The
"live Notion page remains authoritative" claim above still holds today, but there is no
longer a standing guarantee that page stays reachable. This is deliberately still scoped
to Mode 9 (Windows Power User & Optimizer), not pulled into AIOS canon work here: but
whoever next touches the D-drive routing engine should pull the missing detail (Ollama
rule tables, model bake-off history, the migration log) into the repo before relying on
the live page again, not assume it's still there.

---

# # Two separate systems live on this drive : do not conflate them

*Answering the question raised 2026-08-18: does general drive content eventually move
into `{{REPO_PATH}}\wiki\`?* **No, and it shouldn't.** They serve different jobs:

| | This taxonomy (below) | `{{REPO_PATH}}\raw\` → `wiki\` |
|---|---|---|
| Holds | {{OPERATOR_NAME}}'s actual working files: client footage, invoices, medical records, PC benchmarks, Premiere projects | Synthesized **knowledge**: research articles, video transcripts, decisions, the future 89-row legacy-wiki harvest |
| Governed by | This file: routing rules, confidence threshold, naming convention | The ingest pipeline ([`prompts/translate.md`](../prompts/translate.md)), OKF frontmatter |
| Grows by | {{OPERATOR_NAME}} downloading/creating files in the course of life and business | Deliberate ingest of things worth an agent knowing generally |

A client's raw footage or a PayPal statement is never "knowledge" in the AIOS sense -
moving it into `wiki/` would be a category error, mixing file storage with a knowledge
base. **The one narrow exception**, already in the taxonomy below: `3-📚 Resources\📤
Notion Exports\` holds exactly the kind of content that *does* eventually feed
`raw/notion-export/` at Milestone 4: Notion page/CSV exports are source material for
the wiki by design. Everything else in the general tree stays exactly where it is,
governed by this file, forever.

**A near-miss this exposed, 2026-08-17:** a 2026-08-12 full Notion Workspace Export
(7,608 files, the likely legacy "operator's Second Brain" content M4 is meant to harvest) was
found sitting in `_🗑️ SCRATCH\`, about to be auto-deleted by a newly-registered sweep
task before {{OPERATOR_NAME}} could review it. The task was downgraded to dry-run-only before that
could happen: see the current-state section below. **This export needs a deliberate
home, not a default one**: {{OPERATOR_NAME}}'s call on where.

---

# # ⚠️ Current state : updated 2026-08-17 after live verification, not just documentation review

The Notion page's own 2026-08-14 addendum flagged three failures. Verified directly
against the machine, not assumed from the page text:

1. **The AI routing engine (Ollama) is down, not just unscheduled.** Neither lane
   responds: `127.0.0.1:11434` and `:11435` both refused connection. The calibration
   gate (≥95% confident-correct, 0 confident-wrong) was never cleared regardless.
   **Not fixed this session: this is Mode 9's job** (Windows Power User &
   Optimizer), not AIOS canon work. Scoped out deliberately rather than pulled into
   scope creep here.
2. **✅ FIXED: the INBOX watcher scheduled task.** Registered 2026-08-17
   (`D-Drive INBOX live router`, logon trigger, S4U + Hidden, explicit `pwsh.exe`),
   started manually, and **verified as a live running process** (not just a registered
   task: confirmed via `Get-CimInstance Win32_Process`). It degrades safely with
   Ollama down: the 4-rule deterministic floor (temp-file delete, editing-project
   extensions, font extensions) still runs; everything else falls to `_👀 REVIEW\`
   rather than guessing, per the router's own "never fabricate a destination" rule.
3. **✅ FIXED, but left dry-run-only: the SCRATCH sweep.** Registered
   (`D-Drive SCRATCH 30-day sweep`, daily 3am, S4U + Hidden). **Deliberately not set to
   `-Live`**: the first dry-run matched 7,612 files, 7,608 of them the Notion export
   named above. Re-enable `-Live` only after that export has a deliberate home.

**A fourth issue found and fixed that the Notion page didn't flag:** neither script
carried a UTF-8 BOM, which is the exact failure mode canon's own script-safety rules
warn about (Windows PowerShell 5.1 misreads a BOM-less emoji path as ANSI). Both files
now carry a BOM. Not an active bug: both are invoked via `pwsh.exe` (PS7), which
handles BOM-less UTF-8 correctly: but it was one config change away from silently
breaking, and the fix costs nothing.

**Still open, deliberately scoped to Mode 9, not this session:** bringing the two
Ollama lanes back up, verifying the model pulls, and clearing the calibration gate. Add
to BUILD-PLAN or a Mode 9 session: not folded into AIOS canon work.

---

## Root-level exceptions

*Added 2026-08-17, per [ADR-0006](../decisions/0006-local-first-substrate-split-by-reader.md).
The live Notion page does not yet list these: flag on next Notion-side edit.*

`{{REPO_PATH}}\` and `{{BUSINESS_REPO_PATH}}\` sit at the drive root, outside the domain tree below,
alongside the two exceptions already documented: Hermes Agent (Nous Research's
official Hermes Agent/Desktop app at `{{DATA_DRIVE}}\HermesAgent\`, with live SQLite databases,
credentials, cron store, git source checkout, and the AIOS fleet's kanban board and
gateway: never move it) and Program Files
(installed applications). Root exceptions share one property: they are live application
or repository roots with hardcoded paths, not documents to be routed. **Never let the
INBOX router move a file into either: they are not routing destinations.**

## Tree spec

```
{{DATA_DRIVE}}\
├── _INBOX\            ← downloads land here; rules + AI route (see current-state note)
├── _REVIEW\           ← AI routed, low confidence; human confirms
├── _SCRATCH\          ← deletion-candidate review pile ({{OPERATOR_NAME}} decides); never auto-deleted
├── _READING\          ← save-to-read-later queue
├── _LOGS\             ← routing engine telemetry; NEVER a routing destination
│
├── {{AIOS_NAME}}\     ← {{AIOS_NAME}} repo. Canonical per ADR-0006. Root exception.
├── {{BUSINESS_AIOS_NAME}}\  ← {{BUSINESS_AIOS_NAME}} repo. Peer. Root exception.
│
├── 1-Business\
│   ├── 🔄 Ongoing Areas\   ({{BUSINESS_NAME}}, {{OPERATOR_NAME}}, Business Finance, Resale)
│   ├── 🤝 Clients\         (Bewitching, Diva, Ulusoka: 6-folder sub-template each)
│   ├── 🚀 Active Projects\ (Misc Editing Projects + named)
│   └── 📋 Reference Files\
│
├── 2-Life\
│   ├── 🔄 Ongoing Areas\   (Personal Finance, Health, Admin, PC Audit, {{PARTNER_NAME}})
│   ├── 🚀 Active Projects\
│   └── 📋 Reference Files\
│
├── 3-📚 Resources\
│   ├── 🎬 Editing Assets\  ├── 🎥 Stock Media\  ├── 🛠️ Tools and Software\
│   ├── 🎓 Learning\        ├── 📤 Notion Exports\  └── 📜 Scripts\
│
└── 4-Archive\ (Business / Life / Resources / dated cleanup batches)
```

**Depth rule:** cap at 3 levels below the domain. Push further detail into the filename.

**ASCII migration status, 2026-09-10:** the top-level domain and repo-root folders above
(`1-Business`, `2-Life`, `4-Archive`, the two repo roots, the five system folders) have
already dropped their emoji prefixes on disk; only `3-📚 Resources\` and its children
still carry emoji, matching this spec as written. The full migration (subfolders, the
duplicate-INBOX cleanup) is still open, tracked in
[`tasks/resolve-d-drive-inbox-ascii-migration.md`](../tasks/resolve-d-drive-inbox-ascii-migration.md), not this pass.

**Off-taxonomy cleanup, 2026-09-10:** three folders had accumulated at the drive root
with no home in this taxonomy: `LifeOS\` and `LifeOS-Archive\` (a reverted migration
attempt from 2026-08-27/28) and `gods-eye-view\` (an unrelated Vite/Node project). None
fit an existing domain, so all three moved to `4-Archive\_2026-09-10-drive-cleanup\`
rather than staying at root or being guessed into a category. Two stray files also sit
at the drive root outside any routing folder, `ask-aios.Tests.ps1` and
`tmp_main.txt`: left in place, not this pass's scope, flag on next root sweep.

**Client sub-template** (every client + named project): `1-📋 Brief and Contract\` ·
`2-🎥 Raw Footage\` · `3-🎬 Editing Project Files\` · `4-🎞️ Rendered Exports\` ·
`5-✅ Final Deliverables\` · `6-🧾 Invoices\`.

# # Folder purposes : system folders

| Folder | Purpose | What goes here | What does NOT |
|---|---|---|---|
| `_INBOX\` | Default download destination | Every new file | Manual scratch: use `_SCRATCH\` |
| `_REVIEW\` | AI low-confidence pile | Content the router couldn't clear 0.85 confidence | Manual drops; routing logs (those live in `_LOGS\`) |
| `_SCRATCH\` | Deletion-candidate review pile: files the AI file manager (future) thinks {{OPERATOR_NAME}} may delete; {{OPERATOR_NAME}} reviews | Random downloads, AI-flagged files | Never auto-deleted; the 30-day sweep task is disabled (2026-10-03, {{OPERATOR_NAME}}) |
| `_READING\` | Save-to-read-later | PDFs, articles | Files already read |
| `_LOGS\` | Routing telemetry | Logs, manifests, undo, calibration | Any routed content: never a destination |

# # Business vs. Life : the #1 ambiguity

Does the file support income, clients, or brand? → **Business.** Personal money,
health, admin, hobbies? → **Life.** A budget spreadsheet is Life unless it's a business
P/L or brand budget.

## Filename naming convention

**Pattern:** `YYYY-MM-DD context descriptor v##.ext`

- **YYYY-MM-DD**: always present, ISO format, meaningful date (from file metadata,
  never invented).
- **context**: brand, project, person, or category; the keyword you'd search for.
- **descriptor**: what the file is, 1–4 words.
- **v# #** : only on iterated files; skip for one-shot files (invoices, screenshots).
- **case**: lowercase kebab-case for variable parts; proper nouns keep their case.
- **length**: under ~60 chars before extension.

```
2026-05-15 ostrich-launchpad raw-clip-kitchen v01.mp4
2026-05-12 paypal invoice-may.pdf
2026-05-09 sofia-gray thong-listing-screenshot.png
```

Don't repeat the parent folder name in the filename. Reserve `_` prefix for system
folders only. AI applies the pattern on intake: {{OPERATOR_NAME}} never types a date manually.

## Script safety rules

*(Duplicated here deliberately: canon §6/§8 also state these, and destructive script
work happens with this file loaded, not always with the Claude Pro overlay.)*

1. **Always `-LiteralPath`.** Every path on this drive contains spaces and emoji: the
   root fault family behind a mojibake phantom folder and ANSI-misread memory files.
2. **Any folder-creating script is flagged** with every new folder name listed for
   explicit approval before running.
3. **Dry-run is the default** on anything destructive.
4. **Never fabricate a destination.** An uncertain path resolves to REVIEW, never a
   guessed folder.

## Maintenance cadence

| Trigger | Action | Owner |
|---|---|---|
| Weekly (15 min) | Triage `_REVIEW\` | {{OPERATOR_NAME}} |
| Same miss 3× in a row | Encode as a new routing rule | {{OPERATOR_NAME}} |
| Monthly | Spot-check 5 random routed moves | {{OPERATOR_NAME}} |
| Quarterly | Review tree shape; split folders >200 files or >4 levels deep | {{OPERATOR_NAME}} |
| System failure | Fall back to manual routing, log it | {{OPERATOR_NAME}} |

## Correction loop

The router doesn't self-learn. A correction is a signal to update the *written
criteria*, not just move the file back. Append one line to the corrections log:
`current_path → corrected_path → why`. Repeated misses of the same kind mean the
routing rules need updating, not just the file.

