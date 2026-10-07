---
name: skill-creator
description: "Create, scaffold, or refactor agent skills adhering to AIOS standards, progressive disclosure, and harness budgets."
category: agents
scope: structural
disable-model-invocation: true
---

# Skill Creator

Author, scaffold, and refine agent skills across Claude Code and Google Antigravity. This skill governs the lifecycle of an AIOS skill from initial intent and trigger design down to progressive disclosure, harness budget compliance, and mechanical verification.

Universal document writing theory (pointers, leading words, information hierarchy, pruning) originates in [system-prompt-authoring](../system-prompt-authoring/SKILL.md). This skill adapts that theory specifically to the mechanical packaging, execution loops, and harness constraints of skills.

---

## 1. The Two Loops (Cole Medin / Nate Herk Pattern)

Every skill authoring task operates across two distinct phases:

1. **The Outer Strategic Loop (Intent, Triggers & Schema):**
   - Clarify the user's intent: Is this a repeatable capability, a one-off task, or a domain coach?
   - Determine scope: scope: structural (cross-tenant, reusable tooling) vs scope: personal ({{OPERATOR_NAME}}-specific hardware, finances, routines).
   - Decide invocation posture: Model-invoked vs user-invoked (disable-model-invocation: true). Consult [
eferences/harness-economics.md](references/harness-economics.md).
   - Design the context pointer: Craft a concise description under 250 characters with front-loaded leading words and positive trigger branches.

2. **The Inner Execution Loop (Drafting, Disclosure & Verification):**
   - Scaffold the skill directory via scripts/New-Skill.ps1 or manual layout.
   - Apply progressive disclosure: Structure SKILL.md around sequential steps and completion criteria; push background reference, large schemas, and scripts into 
eferences/ or scripts/.
   - Score against the 6-pillar rubric in [
eferences/rubric.md](references/rubric.md).
   - Mechanically sync and lint: Run scripts/Sync-AgentSkills.ps1 and scripts/Audit-Substrate.ps1.

---

## 2. Authoring Procedure

### Step 1: Triage and Boundary Check
Before writing any file, determine if a new skill is necessary:
- **Avoid Duplication:** Check existing skills in [.agents/skills/skills-index.md](../skills-index.md). If an existing skill covers 80% of the capability, refactor the existing skill instead.
- **Scope Allocation:** Mark scope: structural if the skill should be tracked in scripts/sync/shared-manifest.psd1 for {{BUSINESS_AIOS_NAME}}. Mark scope: personal if it contains private data or operator-specific hardware bindings.
- **Determine Execution Style:** Will the skill execute automated steps directly, run interactive Socratic grilling, or guide manual developer workflows?

### Step 2: Choose Invocation Posture & Write Frontmatter
Evaluate against portfolio listing budgets:
- **Model-Invoked:** Omit disable-model-invocation. Write a description that is:
  - **Front-loaded:** Start with active verbs indicating what the skill does (e.g., Create, scaffold, or refactor...).
  - **Positive:** Describe target situations rather than negated exclusions.
  - **Calibrated:** Keep length between 80 and 250 characters (never exceed 550 characters, the Claude Code hard cap).
- **User-Invoked:** Set disable-model-invocation: true. Write a concise human-facing summary. User-invoked skills consume 0 context listing tokens and are reachable strictly via /skill-name. Use this for destructive operations, rare maintenance scripts, or manual operator walkthroughs.
- See [
eferences/templates.md](references/templates.md) for boilerplate.

### Step 3: Scaffold Directory Structure
Execute the scaffolding helper or create the folder:
`powershell
pwsh -File scripts/New-Skill.ps1 -Name "my-skill" -Description "..." -Scope "structural" -Category "<id from .agents/skills/_categories.json>"
`
Or create manually:
`
.agents/skills/<skill-name>/
|-- SKILL.md                 # Primary workflow and completion criteria
|-- references/              # (Optional) Secondary specs, rubrics, deep background
-- scripts/                 # (Optional) Deterministic automation scripts
`

### Step 4: Draft Primary SKILL.md (Information Hierarchy)
Organize the root file for execution clarity:
1. **Title & Mission Statement:** 1-2 lines defining what the skill achieves.
2. **Sequential Steps (The Recipe):** Numbered actions the agent performs in order. Keep steps lean.
3. **Progressive Disclosure:** If a reference table, schema, or guide exceeds 30 lines, move it to 
eferences/<topic>.md and point to it with a markdown link.
4. **Completion Criteria ("Done when"):** Explicit, observable conditions confirming the task finished. Avoid vague bounds like "ensure clean design"; use checkable gates like "All unit tests pass and Audit-Substrate.ps1 reports 0 errors".

### Step 5: Mechanical Validation and Sync
Never leave a skill unlinked or unvalidated:
1. **Link to Claude Code:** Run pwsh -File scripts/Sync-AgentSkills.ps1 to update project-scoped .claude/skills/ junctions.
2. **Substrate Linter:** Run pwsh -File scripts/Audit-Substrate.ps1 to verify frontmatter, ensure no U+2014 em dashes exist, and validate markdown links.
3. **Drift Detection:** Run pwsh -File scripts/Detect-Drift.ps1 to verify shared manifest alignment.
4. **Rebuild Indexes:** Run pwsh -File scripts/Build-Index.ps1 if a new skill was registered.

---

## 3. Governance Standards Checklist

Every skill in AIOS must satisfy these non-negotiables:
- [ ] **No Em Dashes (ADR-0012):** Zero Unicode U+2014 characters. Use colons, commas, hyphens, or parentheses.
- [ ] **Quoted YAML Frontmatter (ADR-0013):** String fields in frontmatter (
ame, description) must be double-quoted.
- [ ] **Explicit Scope Tag (ADR-0013):** Must include scope: structural or scope: personal.
- [ ] **Zero Navigation Footers (ADR-0013):** Do not add Quick Navigation or trailing index footers.
- [ ] **Repo-Relative Links (Rule 7):** All file references inside repository markdown files must be clickable relative links (e.g. [
eferences/rubric.md](references/rubric.md)).
- [ ] **Listing Budget Solvent:** Keep descriptions tight to prevent portfolio listing truncation in Claude Code.
