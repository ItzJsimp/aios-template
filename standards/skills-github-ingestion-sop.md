---
type: standard
id: standard-skills-github-ingestion-sop
title: "Standard Operating Procedure: Skills GitHub Ingestion"
description: "Authoritative 3-step workflow (discover, inspect, install) for vendoring agent skills from GitHub into AIOS repositories via Install-ExternalSkill.ps1 adhering to ADR-0012, ADR-0013, and ADR-0038."
kind: procedure
load: on-demand
owner: shared
scope: structural
verified: 2026-09-27
generated: false
---

# Skills GitHub Ingestion SOP

This standard defines the authoritative, repeatable 3-step procedure for discovering, inspecting, and vendoring agent skills from GitHub or the open skills ecosystem into {{AIOS_NAME}} and {{BUSINESS_AIOS_NAME}} repositories.

It replaces raw `npx skills add -g` and older manual symlink setups, enforcing project-scoped discovery per [ADR-0038](../decisions/0038-claude-code-skill-discovery-is-project-scoped-per-tenant.md), canonical frontmatter quoting per [ADR-0013](../decisions/0013-canonical-skills-yaml-quoting-and-zero-footers.md), and zero em-dashes per [ADR-0012](../decisions/0012-zero-emdash-punctuation-standard.md).

---

## The 3-Step Ingestion Workflow

```
[ Step 1: Discover & Evaluate ]  -->  [ Step 2: Inspect & Verify ]  -->  [ Step 3: Install & Sync ]
   npx -y skills find <query>            Examine SKILL.md & scripts          pwsh Install-ExternalSkill.ps1
```

### Step 1: Discover & Evaluate

Find candidate skills via the skills CLI or the web leaderboard:

1. **Search CLI:**
   ```bash
   npx -y skills find <query> [--owner <github-owner>]
   ```
   *Example:* `npx -y skills find markdown` or `npx -y skills find --owner anthropics`
2. **Web Leaderboard:** Browse [skills.sh](https://skills.sh/) for top-ranked skills by verified installs.
3. **Quality & Trust Bar:**
   - **Installs:** Prefer skills with >=1,000 installs. Treat skills with <100 installs with deep skepticism.
   - **Source Reputation:** Prioritize official organizations (`anthropics`, `vercel-labs`, `kepano`, `microsoft`) or reputable OSS maintainers.
   - **Repository Health:** Check GitHub stars, recent commit activity, and valid open-source licensing (MIT, Apache, BSD).

### Step 2: Inspect & Verify

Before installing any external code into AIOS, inspect the source repository:

1. **Locate SKILL.md Path:**
   Identify the repository URL and the relative path inside the repo containing `SKILL.md`. (Repos often host multiple skills in a subfolder like `skills/<name>/`).
2. **Review Instruction Quality:**
   Verify the skill provides concrete procedural knowledge, clear triggers in its description, and lacks generic boilerplate, self-review loops, or anti-patterns.
3. **Audit Executable Content:**
   Check whether the skill folder bundles executable scripts (`.ps1`, `.py`, `.sh`, `.js`, `.exe`). Executable scripts must be audited for security and safety before any agent invokes them. AIOS vendoring copies bundled scripts but never executes them automatically.

### Step 3: Install & Sync (Single Authoritative Script)

Install the skill using the canonical AIOS installer:

```powershell
pwsh scripts/Install-ExternalSkill.ps1 <repo-url> <path-in-repo> [<path-in-repo-2>...] [-Force]
```

*Example:*
```powershell
pwsh scripts/Install-ExternalSkill.ps1 https://github.com/kepano/obsidian-skills skills/obsidian-markdown
```

**What the installer executes deterministically:**
1. **Shallow Clone:** Clones the repository to a clean, isolated temporary directory.
2. **Metadata Normalization (ADR-0013):** Rewrites `SKILL.md` frontmatter to canonical AIOS schema (`scope: structural`, `type: skill`, `kind: procedure`, `load: on-demand`, valid title case, and source commit SHA attribution).
3. **De-Emdash Sweep (ADR-0012):** Executes [`Invoke-DeEmdash.ps1`](../scripts/Invoke-DeEmdash.ps1) across the vendored skill directory.
4. **Security Scan:** Scans for executable scripts and prints explicit warnings naming any bundled scripts that require human review.
5. **Project-Scoped Junctions (ADR-0038):** Invokes [`Sync-AgentSkills.ps1`](../scripts/Sync-AgentSkills.ps1) to create project-scoped junctions in `<repo>/.claude/skills/` pointing to `.agents/skills/<name>`. The global `~/.claude/skills/` directory is kept empty to prevent cross-tenant collision.
6. **Index Regeneration:** Rebuilds [`.agents/skills/skills-index.md`](../.agents/skills/skills-index.md) via [`Build-Index.ps1`](../scripts/Build-Index.ps1).

---

## Post-Install Verification & Commit

1. **Verify Claude Code Discovery:**
   Verify junction exists: `Test-Path .claude/skills/<skill-name>` returns `True`.
2. **Verify Antigravity Discovery:**
   Verify native folder exists: `Test-Path .agents/skills/<skill-name>/SKILL.md` returns `True`.
3. **Stage Explicit Paths:**
   Follow safe-parallel-commit protocol by staging explicit paths only:
   ```powershell
   git add .agents/skills/<skill-name>/ .agents/skills/skills-index.md
   git commit -m "Skill: vendor <skill-name> from <repo-slug>"
   ```
