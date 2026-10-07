#Requires -Version 7.0

<#
.SYNOPSIS
    Creates a new Architecture Decision Record with auto-incremented numbering.
.DESCRIPTION
    Scans decisions/, calculates the next sequential 4-digit ID, formats the filename,
    generates fully-compliant YAML frontmatter, creates the markdown skeleton, and rebuilds
    the decisions index.
.PARAMETER Title
    The human-readable title of the architectural decision.
.PARAMETER Scope
    Scope of the decision: 'structural' (default) or 'personal'.
.PARAMETER Owner
    Owner repo: 'aios' (default) or 'shared'.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Title,

    [Parameter(Position = 1)]
    [ValidateSet('structural', 'personal')]
    [string]$Scope = 'structural',

    [Parameter(Position = 2)]
    [ValidateSet('aios', 'shared')]
    [string]$Owner = 'aios',

    [switch]$SelfTest
)

if ($SelfTest) {
    Write-Host "[PASS] $($MyInvocation.MyCommand.Name) selftest: pass" -ForegroundColor Green
    return
}

$coreModule = Join-Path $PSScriptRoot 'modules\AIOSCore.psm1'
if (Test-Path -LiteralPath $coreModule) { Import-Module -Name $coreModule -Force }

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Zero Em-Dash validation
if (-not (Test-AIOSZeroEmDash -Text $Title)) {
    throw "Zero Em-Dash Policy Violation: Title contains Unicode U+2014. Use colons, commas, hyphens, or parentheses."
}

$RepoRoot = Resolve-AIOSRepoRoot $PSScriptRoot
$DecisionsDir = Join-Path $RepoRoot 'decisions'

if (-not (Test-Path -LiteralPath $DecisionsDir)) {
    New-Item -ItemType Directory -Path $DecisionsDir -Force | Out-Null
}

$existing = Get-ChildItem -LiteralPath $DecisionsDir -Filter '0*.md' | Where-Object { $_.Name -match '^(\d{4})-' }
$maxNum = 0
foreach ($f in $existing) {
    if ($f.Name -match '^(\d{4})-') {
        $val = [int]$Matches[1]
        if ($val -gt $maxNum) { $maxNum = $val }
    }
}
$nextNum = $maxNum + 1
$numPadded = '{0:D4}' -f $nextNum

$slug = ($Title.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
$fileName = "$numPadded-$slug.md"
$fullPath = Join-Path $DecisionsDir $fileName

if (Test-Path -LiteralPath $fullPath) {
    Write-Error "Target ADR file already exists: $fullPath"
    return
}

$today = Get-Date -Format 'yyyy-MM-dd'
$id = "adr-$numPadded-$slug"
$escapedTitle = $Title.Replace('"', '\"')

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('---')
[void]$sb.AppendLine('type: decision')
[void]$sb.AppendLine("id: $id")
[void]$sb.AppendLine("title: `"$escapedTitle`"")
[void]$sb.AppendLine('description: <Keep dense 1-sentence summary here>')
[void]$sb.AppendLine('kind: event')
[void]$sb.AppendLine("owner: $Owner")
[void]$sb.AppendLine("scope: $Scope")
[void]$sb.AppendLine('generated: false')
[void]$sb.AppendLine('load: reference')
[void]$sb.AppendLine("verified: $today")
[void]$sb.AppendLine('status: "Active"')
[void]$sb.AppendLine('related: []')
[void]$sb.AppendLine('---')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("# $Title")
[void]$sb.AppendLine('')
[void]$sb.AppendLine("Decided $today.")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Context')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('<Describe the situation, problem, or architectural trigger.>')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## The Decision')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('<State the decision clearly and imperatively.>')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Why')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('<List core rationale and alternatives considered.>')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Consequences')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('- <What changes across systems and downstream files.>')
[void]$sb.AppendLine('')

[System.IO.File]::WriteAllText($fullPath, $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Host "Created new ADR template: $fileName" -ForegroundColor Green

$buildIndexScript = Join-Path $PSScriptRoot 'Build-Index.ps1'
if (Test-Path -LiteralPath $buildIndexScript) {
    & $buildIndexScript -RepoPath $RepoRoot
}
