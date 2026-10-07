---
type: canon
id: standard-template-governance
title: "Template Governance & Consistency Standard"
description: System-wide standard governing template creation, enforcement strictness tiers, and file consistency across {{AIOS_NAME}} and {{BUSINESS_AIOS_NAME}}.
kind: policy
load: on-demand
owner: shared
scope: structural
verified: 2026-08-30
sources: []
related: ["standard-naming", "standard-frontmatter"]
generated: false
---

# Template Governance & Consistency Standard

## Core Principle

Templates ensure predictability, quality control, and machine readability across both **{{AIOS_NAME}}** and **{{BUSINESS_AIOS_NAME}}**. Files created frequently or consumed across multiple agent turns must follow standardized schemas to minimize hallucinations and token overhead.

---

## 3-Tier Template Enforcement Hierarchy

Not all files require identical rigidity. All AIOS templates belong to one of three enforcement rungs:

```
┌─────────────────────────────────────────────────────────────┐
│ Tier 1: Rigidly Enforced (Machine Parsed & Indexed)        │
│ • Skills (page-skill.md), YouTube Analysis, Tasks, ADRs     │
├─────────────────────────────────────────────────────────────┤
│ Tier 2: Structured / Guided (Skeleton Defaults)             │
│ • Project Specs, SOPs, Modes & Personas, Creator Dossiers   │
├─────────────────────────────────────────────────────────────┤
│ Tier 3: Open Guardrail (Goal-Oriented, Freeform Layout)     │
│ • Brainstorms, Scratch Scripts, Research Dumps, Notes       │
└─────────────────────────────────────────────────────────────┘
```

### 1. Tier 1: Rigidly Enforced Templates (Exact Schemas)
- **Applies to:** [`youtube-analysis.md`](../templates/youtube-analysis.md), [`page-skill.md`](../templates/page-skill.md), [`db-tasks.md`](../templates/db-tasks.md), ADRs.
- **Rules:**
  - Frontmatter fields are **mandatory and machine-validated**.
  - All H2 (`##`) headings must be preserved verbatim.
  - Heading order is fixed; sections may not be deleted or rearranged.
  - Missing content must be explicitly noted (e.g. `_None_` or omitted rows) rather than dropping the section.

### 2. Tier 2: Structured / Guided Templates (Skeleton Defaults)
- **Applies to:** Project Specs, SOPs, Modes & Personas, Creator Dossiers.
- **Rules:**
  - Frontmatter schema is standard.
  - Section headings provide a baseline checklist, but specific subsections can be tailored to the project's technical needs.

### 3. Tier 3: Open Guardrail Templates (Creative Latitude)
- **Applies to:** Brainstorms, research dumps, exploratory transcripts.
- **Rules:**
  - Frontmatter is minimal.
  - Format is optimized for clarity and high information density.

---

## Template Creation Lifecycle

Create a template in `templates/` when:
1. **Recurrence:** The file type will be created repeatedly (>3 times per month).
2. **Multi-Agent Consumption:** Other skills, scripts, or indexers parse this file type automatically.
3. **Quality Baseline:** Standardizing headings prevents omissions (e.g. ensuring every video analysis includes an Executive Brief, Architecture Breakdown, and Actionability Routing).

## When to split one file into a parent + children

Reading a file always loads all of it: there's no partial load. A file that mixes universally-relevant content with narrow, occasionally-relevant content taxes every session that opens it with the narrow part's tokens, whether or not that session needs them. Split when **all** of these hold:

1. **Independently queried.** In practice, a task needs the child topic alone far more often than it needs it alongside the rest of the parent (a specific game's settings vs. general hardware specs).
2. **Substantial enough to earn a file.** A sentence isn't worth a new file and a pointer; a real block of content is.
3. **The parent is `load: always` or heavily trafficked.** The higher a file's load frequency, the higher the tax on carrying content most sessions don't need: split aggressively out of always-loaded files, more leniently out of rarely-opened ones.

Keep together when the split content is small, tightly coupled to the rest, or queried together with the parent most of the time: don't split for its own sake.

**Mechanism:** the parent keeps a short pointer (a one-line table row, not the content) to the child, `load: on-demand`. See `memory/pc-system-profile.md`'s "Game Optimization Profiles" table pointing at `memory/games/apex-legends.md` as the reference example (split 2026-08-25).
