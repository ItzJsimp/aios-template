---
type: canon
id: standard-naming
title: "File & Folder Naming Standard"
description: Complete, authoritative naming taxonomy, casing rules, and collision prevention across AIOS repositories, scripts, engines, and storage layers.
kind: state
load: on-demand
owner: shared
scope: structural
verified: 2026-09-09
sources: []
related: ["standard-frontmatter", "standard-template-governance", "drive-taxonomy", "adr-0020-unified-cli-dispatcher-and-script-ast-gate", "adr-0023-folder-prefixed-index-naming-and-expanded-metadata-tables"]
generated: false
---

# File & Folder Naming Standard

The single authoritative source of truth for all file, folder, script, and directory naming conventions across **{{AIOS_NAME}}** and **{{BUSINESS_AIOS_NAME}}**.

---

## 1. Core Universal Laws

1. **Every non-root documentation file and directory is lowercase kebab-case:**
   - Permitted characters: Lowercase alphanumeric ASCII (`a-z`, `0-9`) and single hyphens (`-`).
   - Prohibited: Spaces, underscores (`_`), camelCase, PascalCase, consecutive hyphens (`--`), and leading/trailing hyphens.
   - Examples: [`standards/frontmatter-standard.md`](./frontmatter-standard.md), `tasks/configure-tailscale-mesh-sync.md`, `handoff-docs/`.

2. **Root instruction files stay ALL-CAPS:**
   - Permitted root files follow uppercase ASCII with hyphens: [`AGENTS.md`](../AGENTS.md), [`CLAUDE.md`](../CLAUDE.md), [`GEMINI.md`](../GEMINI.md), [`MASTER-INSTRUCTIONS.md`](../MASTER-INSTRUCTIONS.md), [`BUILD-PLAN.md`](../BUILD-PLAN.md), [`CONTEXT.md`](../CONTEXT.md), [`TASKS.md`](../TASKS.md), [`README.md`](../README.md).
   - This prevents collisions and supports native AI engine discovery.

3. **Folder indexes are named after the parent folder with `-index.md` suffix:**
   - Every directory requiring an index carries a folder-prefixed index file (e.g. `tasks/tasks-index.md`, `modes/modes-index.md`, `standards/standards-index.md`, `tools/tools-index.md`, `wiki/wiki-index.md`).
   - Subdirectories follow the same convention (e.g. `domains/finances/finances-index.md`, `memory/games/games-index.md`, `raw/youtube/youtube-index.md`).
   - The repository root retains `index.md` as the universal repository entrypoint and anchor (ADR-0023).

4. **Frontmatter carries metadata, not the filename:**
   - Never encode status, tags, priority, or owners into filenames (e.g. `task-high-p0-done.md` is forbidden).
   - Filenames represent durable semantic identity; operational metadata belongs strictly in YAML frontmatter (`status:`, `kind:`, `scope:`, `owner:`).

5. **Multi-Engine Reserved Collision Blacklist:**
   - On Windows (case-insensitive filesystem), lowercase tool dossiers or documentation files named after AI engines collide with root-level instruction loaders.
   - Banned filenames across all directories: `claude.md`, `agents.md`, `gemini.md`, `cursor.md`, `copilot.md`, `windsurf.md`, `chatgpt.md`.
   - Permitted resolution: Disambiguate by appending `-ai`, `-tool`, or `-engine` (e.g. [`tools/apps/claude-ai.md`](../tools/apps/claude-ai.md), `tools/apps/cursor-editor.md`).
   - **Vendored-Tree Carve-Out:** Vendored trees committed as upstream code, notably [tools/mem0/server/](../tools/mem0/server/), are exempt from the kebab-case law (1) and this collision blacklist: their files keep the exact names upstream ships, because renaming inside vendored code severs upstream diffs and update paths. Ratified in the 2026-09-17 os-audit ([audits/2026-09-17-os-audit.md](../audits/2026-09-17-os-audit.md)).

---

## 2. Root-Level File Qualification Standard

The repository root is a protected zone. To prevent clutter and ensure deterministic engine routing, a file qualifies to reside in the repository root **only if it satisfies at least one of three criteria:**

| Qualification Criterion | Rationale | Approved Root Files |
|---|---|---|
| **1. Engine Auto-Discovery Entrypoint** | Fixed, exact filenames natively detected by AI engines at project launch. | [`AGENTS.md`](../AGENTS.md), [`CLAUDE.md`](../CLAUDE.md), [`GEMINI.md`](../GEMINI.md), `.gitignore` |
| **2. Core System Anchor** | Universally referenced governance router or high-priority directive requiring zero-depth pathing. | [`MASTER-INSTRUCTIONS.md`](../MASTER-INSTRUCTIONS.md), [`CONTEXT.md`](../CONTEXT.md), [`BUILD-PLAN.md`](../BUILD-PLAN.md), [`INTENT.md`](../INTENT.md), [`TASKS.md`](../TASKS.md), [`README.md`](../README.md), [`connections.md`](../connections.md), [`rot.md`](../rot.md) |
| **3. Universal CLI Dispatcher** | The single repository entrypoint script for operator commands. | [`aios.ps1`](../aios.ps1) |

**Enforcement Rule:** Any file failing to meet at least one qualification criterion is strictly prohibited from the root directory and must be placed in a categorized subfolder. Adding a new root-level file requires an approved Architectural Decision Record (ADR) justifying why it cannot reside in a subdirectory.

---

## 3. Substrate Master Naming Matrix

| Substrate Domain | Directory / Path | Casing & Format Convention | Pattern / Regex | Canonical Example | Owning Generator / CLI |
|---|---|---|---|---|---|
| **Root Canon** | `/` | ALL-CAPS (Hyphenated) | `^[A-Z0-9-]+\.md$` | [`AGENTS.md`](../AGENTS.md), [`BUILD-PLAN.md`](../BUILD-PLAN.md) | Manual / ADR Governed |
| **Root Dispatcher** | `/` | Lowercase Single-Word | `^aios\.ps1$` | [`aios.ps1`](../aios.ps1) | [ADR-0020](../decisions/0020-unified-cli-dispatcher-and-script-ast-gate.md) |
| **Folder Indexes** | `<folder>/` | Kebab Folder Prefix + `-index.md` | `^[a-z0-9-]+-index\.md$` | `modes/modes-index.md`, `standards/standards-index.md` | [ADR-0023](../decisions/0023-folder-prefixed-index-naming-and-expanded-metadata-tables.md) / [`scripts/Build-Index.ps1`](../scripts/Build-Index.ps1) |
| **Decisions (ADRs)** | `decisions/` | 4-Digit Zero-Padded Prefix + Kebab Slug | `^\d{4}-[a-z0-9-]+\.md$` | [`decisions/0010-git-history-replaces-the-master-log.md`](../decisions/0010-git-history-replaces-the-master-log.md) | [`scripts/New-ADR.ps1`](../scripts/New-ADR.ps1) |
| **System Modes** | `modes/` | 2-Digit Zero-Padded Prefix + Kebab Slug | `^(\d{2}-[a-z0-9-]+|router)\.md$` | [`modes/00-build-architect.md`](../modes/00-build-architect.md), [`modes/router.md`](../modes/router.md) | Manual Mode Scaffolding |
| **Operational Tasks** | `tasks/` | Lowercase Kebab-Case Action Slug | `^[a-z0-9-]+\.md$` | `tasks/build-wiki-lint-tool.md` | [`scripts/New-Task.ps1`](../scripts/New-Task.ps1) |
| **Thought Capture** | `capture/` | Compact ISO 8601 Timestamp + Kebab Slug | `^\d{4}-\d{2}-\d{2}T\d{4}-[a-z0-9-]+\.md$` | `capture/2026-08-26T1801-task-idea.md` | [`scripts/Capture-Thought.ps1`](../scripts/Capture-Thought.ps1) |
| **Handoff Briefs** | `handoff-docs/` | Date-Prefix (`YYYY-MM-DD-`) + Kebab Slug | `^\d{4}-\d{2}-\d{2}-[a-z0-9-]+\.md$` | [`handoff-docs/2026-08-25-structural-audit-and-grill.md`](../handoff-docs/2026-08-25-structural-audit-and-grill.md) | Session Handoff Flow |
| **Audits & Reviews** | `audits/` | Date-Prefix (`YYYY-MM-DD-`) + Kebab Slug | `^\d{4}-\d{2}-\d{2}-[a-z0-9-]+\.md$` | `audits/2026-08-30-substrate-audit.md` | Audit Procedures |
| **Durable Memory** | `memory/` | Lowercase Kebab-Case | `^[a-z0-9-]+\.md$` | [`memory/pc-system-profile.md`](../memory/pc-system-profile.md), [`memory/games/apex-legends.md`](../memory/games/apex-legends.md) | [`scripts/New-Memory.ps1`](../scripts/New-Memory.ps1) |
| **Agent Skills** | `.agents/skills/` | Kebab Folder + ALL-CAPS `SKILL.md` | `^\.agents[\\/]skills[\\/][a-z0-9-]+[\\/]SKILL\.md$` | `.agents/skills/task-management/SKILL.md` | [`scripts/Package-Skill.ps1`](../scripts/Package-Skill.ps1) |
| **Templates** | `templates/` | Lowercase Kebab-Case | `^[a-z0-9-]+\.md$` | [`templates/youtube-analysis.md`](../templates/youtube-analysis.md) | Template Standards |
| **PowerShell Scripts** | `scripts/` | PascalCase Approved `Verb-Noun.ps1` | `^[A-Z][a-zA-Z0-9]+-[A-Z][a-zA-Z0-9]+\.ps1$` | [`scripts/Build-Index.ps1`](../scripts/Build-Index.ps1), [`scripts/Detect-Drift.ps1`](../scripts/Detect-Drift.ps1) | Developer / Admin |
| **Python Scripts** | `scripts/` | Lowercase Kebab-Case (`.py`) | `^[a-z0-9-]+\.py$` | `scripts/track-skill.py`, `scripts/track-context.py` | Developer / Daemons |
| **Projects** | `projects/` | Kebab Project Directory + Kebab Files | `^projects[\\/][a-z0-9-]+[\\/][a-z0-9-]+\.md$` | `projects/aios-scribe/spec.md` | Project Workspaces |
| **Standards** | `standards/` | Lowercase Kebab-Case | `^[a-z0-9-]+\.md$` | [`standards/naming-standard.md`](./naming-standard.md) | Governance Canon |
| **Domain Wikis** | `wiki/` | Lowercase Kebab-Case | `^[a-z0-9-]+\.md$` | [`wiki/ai-implementation-playbook.md`](../wiki/ai-implementation-playbook.md) | Ingest Pipeline |
| **Raw Ingest & Notes** | `raw/` | Lowercase Kebab-Case Directory & Files | `^[a-z0-9-]+\.md$` | `raw/notes/file-audit-sequence-checklist.md` | Ingest Pipeline |
| **Graph Imports** | `raw/graph-imports/` | Kebab Corpus Directory + Kebab Files | `^raw[\\/]graph-imports[\\/][a-z0-9-]+[\\/].*$` | `raw/graph-imports/claude-code/concepts/sub-agent.md` | [ADR-0036](../decisions/0036-quarantined-graph-ingestion-and-source-hydration-architecture.md) |
| **Life Domains** | `domains/` | Kebab Domain Directory + Kebab Files | `^domains[\\/][a-z0-9-]+[\\/][a-z0-9-]+\.md$` | `domains/finances/summary.md` | Private Domain Mode |
| **Ideal State** | `ideal-state/` | Lowercase Kebab-Case | `^[a-z0-9-]+\.md$` | `ideal-state/mission.md`, `ideal-state/areas/money.md` | Life Direction Substrate |
| **Tool Dossiers** | `tools/` | Lowercase Kebab-Case | `^[a-z0-9-]+\.md$` | `tools/apps/obsidian.md`, [`tools/apps/claude-ai.md`](../tools/apps/claude-ai.md) | Software Baselines |
| **Prompt Templates** | `prompts/` | Lowercase Kebab-Case | `^[a-z0-9-]+\.md$` | `prompts/translate.md` | Prompt Governance |
| **Session Logs** | `logs/` | Lowercase Kebab-Case | `^[a-z0-9-]+\.md$` | `logs/lessons-learned.md` | Session Telemetry |
| **Archive Tiers** | `archive/` | Retention Tier Folder + Archived Asset | `^archive[\\/](14|30|90|180|365-days|permanent)[\\/].*$` | `archive/permanent/notion-standard.md` | [`scripts/Sweep-Archive.ps1`](../scripts/Sweep-Archive.ps1) |
| **Assets & Visuals** | `assets/` | Subfolder + Kebab-Case File | `^assets[\\/][a-z0-9-]+[\\/][a-z0-9-]+\.(html|png|svg|json)$` | `assets/dashboards/token-usage.html` | Asset Management |
| **Shortcut Launchers** | `scripts/launchers/` | Hyphenated PascalCase (`.cmd` / `.ps1`) | `^[A-Za-z0-9-]+\.(cmd|ps1)$` | `scripts/launchers/Quick-Capture.cmd` | Desktop Shortcuts |

---

## 4. Script & Automation Casing Standard

To preserve native ecosystem alignment and prevent tooling friction:

1. **PowerShell 7+ Scripts (`scripts/*.ps1`):**
   - Must adhere to the official PowerShell `Verb-Noun.ps1` syntax using approved PowerShell verbs (`Get`, `Set`, `New`, `Invoke`, `Test`, `Build`, `Detect`, `Sync`, `Complete`, `Audit`, `Register`, `Process`).
   - PascalCase is strictly enforced for both the verb and noun segments (e.g. [`Build-Index.ps1`](../scripts/Build-Index.ps1), [`Detect-Drift.ps1`](../scripts/Detect-Drift.ps1), [`Complete-Task.ps1`](../scripts/Complete-Task.ps1)).
   - Single-word root CLI entrypoint: [`aios.ps1`](../aios.ps1) in the repository root.

2. **Python Utilities & Background Daemons (`scripts/*.py`):**
   - Must adhere to lowercase kebab-case formatting (`track-skill.py`, `track-context.py`, `profile-creator.py`, `track-youtube-telemetry.py`).
   - Prohibited: PascalCase, camelCase, or snake_case for standalone script filenames in `scripts/`.

---

## 5. Temporal & Sequential Naming Rules

1. **Daily Chronological Events (Audits, Handoffs, Reviews):**
   - Must use the ISO date prefix format: `YYYY-MM-DD-<slug>.md` (e.g. `2026-08-30-os-audit.md`, `2026-08-25-structural-audit-and-grill.md`).
   - Guarantees natural chronological ordering in directory listings and terminal output.
   - Suffix date formats (e.g. `os-audit-2026-08-24.md`) are legacy and prohibited for new files.

2. **High-Frequency Timestamp Ingestion (Capture Inbox):**
   - Rapid thought captures in `capture/` must use the compact ISO timestamp format: `YYYY-MM-DDTHHmm-<slug>.md` (e.g. `2026-08-26T1801-review-voice-engine.md`).
   - Avoids colon characters (`:`) which are illegal in Windows file paths.
   - Exemption (ratified 2026-09-17): `capture/continuations/` capsules are tool-generated by the chat-closeout/chat-sync writers and use `YYYY-MM-DD-<slug>.md`; the `THHmm` format applies to root `capture/` inbox notes only. Renaming tool-generated capsules would break the writers that reference them.

3. **Sequential Governance Numbering (ADRs & Modes):**
   - ADRs in `decisions/`: Must use 4-digit zero-padded prefixes (`0001-slug.md`, `0020-slug.md`).
   - Modes in `modes/`: Must use 2-digit zero-padded prefixes (`00-build-architect.md`, `03-{{BUSINESS_NAME}}.md`).

---

## 6. External Drive Taxonomy Boundary

Files residing on the `{{DATA_DRIVE}}\` drive outside `{{REPO_PATH}}\` and `{{BUSINESS_REPO_PATH}}\` follow the external directory taxonomy defined in [`standards/drive-taxonomy.md`](./drive-taxonomy.md). The naming conventions defined in this file apply to all AIOS repository workspaces.

