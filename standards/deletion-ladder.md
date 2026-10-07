---
type: canon
id: deletion-ladder
title: The Deletion Ladder
description: >
  What may be deleted without asking, what needs approval, and what is
  never auto-deleted. Three tiers, five guardrails, plus the retrieval-
  architecture rules that govern every build decision, not only deletion.
kind: state
load: on-demand
owner: aios
scope: structural
verified: 2026-08-18
sources: []
related: ["master-instructions"]
generated: false
---

# The Deletion Ladder

Extracted from Master Instructions §3, 2026-08-17, so it can be `load: on-demand` rather
than always-loaded. Two questions decide the tier, in order: **(1)** Does any canon page
@mention it? If yes, it can never be hard-deleted. **(2)** Would {{OPERATOR_NAME}} ever ask "why did I
decide this?" and want the page? If yes, supersede-and-archive. If no, it can be deleted.

# # Tier 1 : delete without asking, then log

Requires **all** of: no body content, or an exact duplicate of a canon page · zero
inbound links · not a database, linked view, or parent of children · no dedicated
commit: only ever touched as part of a bulk/scaffold commit · an auto-generated or
template-imported name.

Move to trash, commit the deletion with a `Delete:`-prefixed message stating what was
deleted and why. *(Rewritten 2026-08-18 per [ADR-0010](../decisions/0010-git-history-replaces-the-master-log.md)
- the separate Deletion Ledger is retired; `git log --diff-filter=D` already gives an
append-only record of every deletion, with no second artifact to keep in sync.)* AIOS has
no Notion content left to delete this way ([ADR-0011](../decisions/0011-notion-retired-for-aios-kept-for-{{BUSINESS_NAME}}.md)).
For {{BUSINESS_NAME}} content still living in Notion, Notion's trash holds a deletion 30 days
regardless.

# # Tier 2 : propose, delete on approval

Has real content but is superseded, duplicated, or untouched for 12+ months. Present as
one batched approval list, never one item at a time.

# # Tier 3 : never auto-delete; supersede-and-archive only

Anything canon references · anything with real commit history: more than a bulk
scaffold touch · any decision, reasoning trail, or original work · any database or
database row · anything still open in an active triage pass.

## Guardrails

- **Cap Tier 1 at 25 deletions per session**, so a mistaken rule cannot cascade.
- **Ambiguity resolves upward.** Anything uncertain is Tier 2, never Tier 1.
- **Trash, never purge.** On the local repo (AIOS), nothing hard-deletes: move to a
  dated folder or let git history carry it (see Engine split below). Nothing empties
  {{BUSINESS_NAME}}'s Notion trash either.
- **Resolve object type before scoring.** A linked view can render as "Untitled," and an
  empty database is indistinguishable from an empty page by file metadata alone. Both
  were mis-scored once; type resolution is what prevents a repeat.
- **Engine split.** On AIOS's local repo: the only substrate AIOS has left per
  [ADR-0011](../decisions/0011-notion-retired-for-aios-kept-for-{{BUSINESS_NAME}}.md): the
  rule is: never `rm`, always move to a dated folder or let git history carry it, see
  [ADR-0007](../decisions/0007-git-is-the-sync-and-sharing-layer.md). {{BUSINESS_NAME}}'s
  Notion tenant keeps the older split: Notion AI has native delete and executes Tier 1
  directly; Claude Pro's Notion MCP has no delete tool, so it stages Tier 1 candidates
  for single-click removal instead.

## Absence of deletion is a defect

Every audit, health check, or migration pass returns a deletion candidate list.
Returning zero candidates is a valid outcome only with a stated reason. A workspace that
never loses pages goes stale, and stale pages are what make retrieval unreliable -
pruning is part of maintaining the brain, not an exception to it.

---

# # Retrieval architecture : governs every build, not only deletion

Promoted here because both rules are load-bearing for the whole local-canon design, not
deletion-specific:

- **Reverse-engineer storage from the retrieval question.** Before creating or
  restructuring any store, state the question it will need to answer and the shape of
  the answer expected back: then design the structure to fit that retrieval. Never
  store first and hope.
- **Context vs. connections: the ingestion gate.** Persist only evergreen context
  (still true and useful in a year) into the brain. Volatile connections: live
  platform or customer data, ephemeral threads: do not get ingested; route to them
  live instead. The test: would this have to be cleaned out in a month? If yes, it's a
  connection, and the brain only needs to know where to look, not hold a copy.
- **Section reads for lookups, whole reads for synthesis.** To find one fact in a large
  file (the buried-fact case: "find rule 17 out of a thousand"), Grep with context or
  read only the matching section by offset; never load a 10,000-word file for one
  sentence. To summarize or aggregate a file, read it whole: whole-document reads beat
  chunk retrieval on accuracy there. Both cases come from the
  [2026-08-16 target-state blueprint](../raw/blueprints/2026-08-16%20AIOS%20target-state%20blueprint%20v01.md)
  (the cost-model argument and the M4 climb trigger).

