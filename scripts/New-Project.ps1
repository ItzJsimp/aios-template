#Requires -Version 7.0

<#
.SYNOPSIS
    Scaffolds a new project directory under projects/<slug>/ following standards/project-standard.md.
.PARAMETER Slug
    Directory and identifier slug in lowercase kebab-case (e.g. "voice-synthesizer").
.PARAMETER Name
    Human-readable project title (e.g. "Voice Synthesizer Pipeline").
.PARAMETER Category
    Project taxonomy category: app, daemon, extension, integration, study, design.
.PARAMETER Scope
    Scope tag: structural or personal (default: structural).
.PARAMETER Owner
    Owner tenant: aios or {{BUSINESS_NAME}} (default: aios).
.PARAMETER GoldenSuite
    Switch to scaffold the full 5-document Golden Suite (spec.md, architecture.md, agent-playbook.md, research/).
.PARAMETER Workspace
    Switch for a code project: also writes the workspace layer (AGENTS.md, CLAUDE.md = "@AGENTS.md", .agents/skills/.gitkeep,
    agent-playbook.md from the 7-section skeleton) and appends projects/<slug>/ to the AIOS .gitignore. Every project, workspace or not, gets a tasks/ view
    (Sync-ProjectTaskViews.ps1). No git init. See templates/project-workspace-template.md.
.PARAMETER RepoPath
    Root directory of the repository (default: directory containing scripts/..).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Slug,

    [Parameter(Mandatory = $false, Position = 1)]
    [string]$Name,

    [Parameter(Mandatory = $false)]
    [ValidateSet('app', 'daemon', 'extension', 'integration', 'study', 'design')]
    [string]$Category,

    [Parameter()]
    [ValidateSet('structural', 'personal')]
    [string]$Scope = 'structural',

    [Parameter()]
    [ValidateSet('aios', '{{BUSINESS_NAME}}')]
    [string]$Owner = 'aios',

    [Parameter()]
    [switch]$GoldenSuite,

    [Parameter()]
    [switch]$Workspace,

    [Parameter()]
    [string]$RepoPath,

    [switch]$SelfTest
)

if ($SelfTest) {
    Write-Host "[PASS] $($MyInvocation.MyCommand.Name) selftest: pass" -ForegroundColor Green
    return
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $RepoPath) {
    $RepoPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

# Validate slug format: lowercase kebab-case
$cleanSlug = $Slug.ToLowerInvariant().Trim()
if ($cleanSlug -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
    Write-Error "Invalid slug '$Slug'. Must be lowercase kebab-case (e.g. 'command-center-v2')."
    return
}

$projectDir = Join-Path $RepoPath "projects\$cleanSlug"
if (Test-Path -LiteralPath $projectDir) {
    Write-Error "Project directory already exists at $projectDir"
    return
}

Write-Host "Scaffolding project: $Name ($cleanSlug)..." -ForegroundColor Cyan
[void](New-Item -ItemType Directory -Path $projectDir -Force)

$today = Get-Date -Format "yyyy-MM-dd"

# 1. Author project.md (System Ledger)
$projectMdContent = @"
---
type: project
id: project-$cleanSlug
name: "$Name"
status: "Active"
owner: $Owner
scope: $Scope
category: $Category
created: $today
tasks: []
related: []
---
# $Name

## Inputs
Describe the starting context, pain point, and user requirements.

## Process
Describe the technical architecture, execution methodology, and stack choices.

## Outputs
- [``README.md``](./README.md)

## Feedback
Pending completion. Verified metrics and outcomes will be recorded here at project closeout.
"@

$projectMdPath = Join-Path $projectDir "project.md"
[System.IO.File]::WriteAllText($projectMdPath, $projectMdContent.Trim() + "`n", [System.Text.Encoding]::UTF8)

# 2. Author README.md (Developer Runbook)
$readmeContent = @"
# $Name

One-line mission statement and operational purpose for $Name.

## Quick Start

Commands to install, run, build, and test this project:

```powershell
# Setup dependencies
# Run local development or service
```

## Architecture Invariants

- Governed by [``project.md``](./project.md) (system ledger) and [``standards/project-standard.md``](../../standards/project-standard.md).
- Single Authoritative Write Path for all data models.
- Zero Em-Dash standard enforced across code and documentation.

## Known Limits & Failure Modes

- Document operational edge cases, timeouts, or dependency prerequisites here.
"@

$readmePath = Join-Path $projectDir "README.md"
[System.IO.File]::WriteAllText($readmePath, $readmeContent.Trim() + "`n", [System.Text.Encoding]::UTF8)

# 3. Optional Golden Suite expansion
if ($GoldenSuite) {
    Write-Host "Expanding Golden Suite documents..." -ForegroundColor Yellow

    $specContent = @"
---
type: spec
id: $cleanSlug-spec
title: "${Name}: Product Specification"
description: "Product specification for $Name (problem, pillars, non-goals); fill in before building."
scope: $Scope
owner: $Owner
status: "Draft"
verified: $today
---
# $($Name): Product Specification

## 1. Problem Statement & User Personas
Detail operator needs and target scenarios.

## 2. Functional Pillars
Key capability pillars.

## 3. Non-Goals
Explicit boundaries and things this system will NOT do.
"@
    [System.IO.File]::WriteAllText((Join-Path $projectDir "spec.md"), $specContent.Trim() + "`n", [System.Text.Encoding]::UTF8)

    $archContent = @"
# $($Name): System Architecture

## 1. System Topology
Describe component connections, data flows, and IPC bridges.

## 2. Data Models & File Contracts
Schemas, ports, and configuration specifications.
"@
    [System.IO.File]::WriteAllText((Join-Path $projectDir "architecture.md"), $archContent.Trim() + "`n", [System.Text.Encoding]::UTF8)

    if (-not $Workspace) {
        $playbookContent = @"
# Agent Playbook: $($Name)

## System Map
Brief map of key source files and entrypoints.

## Gotchas Paid For
Document failure modes discovered during implementation.

## Session Log
- $($today): Project scaffolded via New-Project.ps1.
"@
        [System.IO.File]::WriteAllText((Join-Path $projectDir "agent-playbook.md"), $playbookContent.Trim() + "`n", [System.Text.Encoding]::UTF8)
    }

    $researchDir = Join-Path $projectDir "research"
    [void](New-Item -ItemType Directory -Path $researchDir -Force)
    $researchReadme = @"
# Research Dossiers: $Name

Investigation dossiers, external teardowns, and technology benchmarks for $Name.
"@
    [System.IO.File]::WriteAllText((Join-Path $researchDir "README.md"), $researchReadme.Trim() + "`n", [System.Text.Encoding]::UTF8)
}

# 3b. Optional workspace layer (templates/project-workspace-template.md)
if ($Workspace) {
    Write-Host "Writing workspace layer..." -ForegroundColor Yellow
    $utf8 = [System.Text.UTF8Encoding]::new($false)

    $agentsContent = @"
# $Name

One-line mission: TODO.

## Run and verify

``````powershell
# TODO: install / run / test commands
``````

## Rules

- Public-safe: the repo may be shared. No personal paths, finances, keys, contacts or personal-scope task text in any file here.
- Tasks live in the AIOS ``tasks/`` folder, created with ``scripts/New-Task.ps1`` and ``project: $cleanSlug``. Do not add a task folder here.
- Project ledger: [``project.md``](./project.md). Memory: [``agent-playbook.md``](./agent-playbook.md). Skills: ``.agents/skills/``.
- Project standard: [``standards/project-standard.md``](../../standards/project-standard.md).
"@
    [System.IO.File]::WriteAllText((Join-Path $projectDir "AGENTS.md"), $agentsContent.Trim() + "`n", $utf8)
    [System.IO.File]::WriteAllText((Join-Path $projectDir "CLAUDE.md"), "@AGENTS.md`n", $utf8)

    $skillsDir = Join-Path $projectDir ".agents\skills"
    [void](New-Item -ItemType Directory -Path $skillsDir -Force)
    [System.IO.File]::WriteAllText((Join-Path $skillsDir ".gitkeep"), "", $utf8)

    $wsPlaybook = @"
---
type: reference
id: $cleanSlug-agent-playbook
title: "${Name}: agent playbook"
description: "Read before changing $cleanSlug. Where things live, data sources and traps, the cheapest verify loop, gotchas already paid for, and one line per past session."
scope: $Scope
owner: $Owner
verified: $today
---
# $Name agent playbook

## 1. Start here (under 5 calls)
1. Read the latest handoff for this project and ``git status --short projects/$cleanSlug``.
2. Run the one health command: ``<smoke or test command>``.
3. Open only the files the task names, using the map below.

## 2. Module map
| Area | Files | Self-test |
|---|---|---|

## 3. Data sources: shape, cost, traps
| Source | Reached by | Latency | Trap |
|---|---|---|---|

## 4. The cheap build and verify loop
1. <fastest proof first, slowest last>

## 5. Gotchas already paid for
- **<Short name>:** what happened, what it cost, what to do instead.

## 6. Why it is this way
- **<Decision>:** the reason, and the link to the ADR, grill log or memory that holds it.

## 7. Session notes (newest first, one line each, keep 10)
- **${today}:** Project scaffolded via New-Project.ps1 -Workspace.
"@
    [System.IO.File]::WriteAllText((Join-Path $projectDir "agent-playbook.md"), $wsPlaybook.Trim() + "`n", $utf8)

    # AIOS .gitignore: add projects/<slug>/ once
    $giPath = Join-Path $RepoPath ".gitignore"
    $giLine = "projects/$cleanSlug/"
    $giText = if (Test-Path -LiteralPath $giPath) { [System.IO.File]::ReadAllText($giPath) } else { "" }
    if (-not ($giText -split "\r?\n" | Where-Object { $_.Trim() -eq $giLine })) {
        $sep = if ($giText -and -not $giText.EndsWith("`n")) { "`n" } else { "" }
        [System.IO.File]::WriteAllText($giPath, $giText + $sep + $giLine + "`n", $utf8)
    }
}

& (Join-Path $PSScriptRoot "Sync-DefaultSkills.ps1") -RepoPath $RepoPath -SourceRoot $RepoPath -ProjectPath $projectDir | Out-Null

# 3c. tasks/ view (project-standard section 10): symlinks to this project's cards in the AIOS tasks/
& (Join-Path $PSScriptRoot "Sync-ProjectTaskViews.ps1") -RepoPath $RepoPath -Project $cleanSlug | Out-Null

# 4. Refresh projects index
$buildIndexScript = Join-Path $RepoPath "scripts\Build-Index.ps1"
if (Test-Path -LiteralPath $buildIndexScript) {
    Write-Host "Updating repository indexes..." -ForegroundColor DarkGray
    & pwsh -NoProfile -File $buildIndexScript -RepoPath $RepoPath | Out-Null
}

Write-Host "[OK] Project created successfully at: projects/$cleanSlug/" -ForegroundColor Green
Write-Host "     Ledger:  projects/$cleanSlug/project.md" -ForegroundColor Gray
Write-Host "     Runbook: projects/$cleanSlug/README.md" -ForegroundColor Gray
if ($Workspace) {
    Write-Host "     Next: git init (or clone the repo) in projects/$cleanSlug/, then run: pwsh scripts/Link-AiosToProject.ps1 -ProjectPath projects/$cleanSlug -Slug $cleanSlug" -ForegroundColor Gray
}
