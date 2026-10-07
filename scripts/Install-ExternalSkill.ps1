#Requires -Version 7.0
<#
.SYNOPSIS
    Vendor one or more skills from a GitHub repo into .agents/skills/ (ADR-0038).
.DESCRIPTION
    Replaces `npx skills add -g`, which writes to the global ~/.claude/skills folder
    that ADR-0038 keeps empty. Clones the repo shallow, copies each skill folder to
    .agents/skills/<frontmatter name>/, rewrites SKILL.md frontmatter to the AIOS
    shape (quoted description per ADR-0013, source pinned to the commit), strips em
    dashes via Invoke-DeEmdash.ps1 (ADR-0012), then runs Sync-AgentSkills.ps1 and
    Build-Index.ps1. Scripts bundled with a skill are copied, never executed.
.EXAMPLE
    pwsh scripts/Install-ExternalSkill.ps1 https://github.com/Leonxlnx/taste-skill skills/brandkit skills/redesign-skill
.EXAMPLE
    pwsh scripts/Install-ExternalSkill.ps1 -SelfTest
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$RepoUrl,
    [Parameter(Position = 1, ValueFromRemainingArguments)][string[]]$SkillPath,
    [switch]$Force,
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

function ConvertTo-AiosFrontmatter([string]$Text, [string]$Source, [string]$Today) {
    if ($Text -notmatch '(?s)\A---\r?\n(.*?)\r?\n---\r?\n(.*)\z') { throw 'SKILL.md has no YAML frontmatter' }
    $head, $body = $Matches[1], $Matches[2]
    if ($head -notmatch '(?m)^name:\s*["'']?([^"''\r\n]+?)["'']?\s*$') { throw 'frontmatter has no name' }
    $name = $Matches[1]
    # description: inline (quoted or not) or a folded/literal block (> >- | |-)
    if ($head -match '(?m)^description:\s*[>|][-+]?\s*\r?\n((?:[ \t]+.*(?:\r?\n|\z))+)') {
        $desc = ($Matches[1] -split '\r?\n' | ForEach-Object Trim | Where-Object { $_ }) -join ' '
    } elseif ($head -match '(?m)^description:\s*(.+)$') {
        $desc = $Matches[1].Trim()
        if ($desc -match '^(["''])(.*)\1$') { $desc = $Matches[2] }
    } else { throw 'frontmatter has no description' }
    $desc = $desc -replace '\\"', '"' -replace '"', '\"'
    $title = (Get-Culture).TextInfo.ToTitleCase(($name -replace '-', ' '))
    $fm = @"
---
name: $name
description: "$desc"
scope: structural
type: skill
id: skill-$name
title: "$title"
kind: procedure
load: on-demand
owner: shared
verified: $Today
source: "$Source"
---
"@
    [pscustomobject]@{ Name = $name; Text = $fm + "`n" + $body }
}

if ($SelfTest) {
    $r = ConvertTo-AiosFrontmatter "---`nname: demo-skill`ndescription: >-`n  Line one`n  line two`n---`n# Body`n" 'src' '2026-01-01'
    if ($r.Name -ne 'demo-skill') { throw "name: $($r.Name)" }
    if ($r.Text -notmatch 'description: "Line one line two"') { throw 'folded description not joined' }
    if ($r.Text -notmatch '(?s)---\n\n?# Body') { throw 'body lost' }
    $r = ConvertTo-AiosFrontmatter "---`nname: 'q'`ndescription: `"Say `"hi`": now`"`n---`nx" 'src' '2026-01-01'
    if ($r.Name -ne 'q' -or $r.Text -notmatch 'description: "Say \\"hi\\": now"') { throw "quoted description: $($r.Text)" }
    Write-Host 'SelfTest passed' -ForegroundColor Green
    return
}
if (-not $RepoUrl -or -not $SkillPath) { throw 'Usage: Install-ExternalSkill.ps1 <repo-url> <path-in-repo> [<path>...] [-Force]' }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("skill-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
git clone -q --depth 1 $RepoUrl $tmp
if ($LASTEXITCODE) { throw "git clone failed: $RepoUrl" }
$sha = (git -C $tmp rev-parse --short HEAD).Trim()
$license = (Get-ChildItem -LiteralPath $tmp -Filter 'LICENSE*' | Select-Object -First 1 | Get-Content -TotalCount 1) -replace '\s+License.*', ''
$installed = @()

try {
    foreach ($rel in $SkillPath) {
        $src = Join-Path $tmp $rel
        $skillMd = Join-Path $src 'SKILL.md'
        if (-not (Test-Path -LiteralPath $skillMd)) { throw "no SKILL.md at $rel" }
        $source = "$RepoUrl ($rel, $license, commit $sha)"
        $r = ConvertTo-AiosFrontmatter (Get-Content -LiteralPath $skillMd -Raw) $source (Get-Date -Format 'yyyy-MM-dd')
        $dest = Join-Path $repoRoot ".agents/skills/$($r.Name)"
        if ((Test-Path -LiteralPath $dest) -and -not $Force) { throw "$($r.Name) already exists; pass -Force to overwrite" }
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
        Copy-Item -LiteralPath $src -Destination $dest -Recurse
        [IO.File]::WriteAllText((Join-Path $dest 'SKILL.md'), $r.Text, [Text.UTF8Encoding]::new($false))
        & (Join-Path $PSScriptRoot 'Invoke-DeEmdash.ps1') -Path $dest | Out-Null
        $exec = Get-ChildItem -LiteralPath $dest -Recurse -File -Include *.sh, *.ps1, *.py, *.js, *.mjs, *.cjs, *.bat, *.cmd, *.exe
        foreach ($e in $exec) { Write-Warning "$($r.Name) bundles $($e.Name): review before any skill step runs it" }
        Write-Host "  [VENDORED] $($r.Name) <- $rel @ $sha" -ForegroundColor Green
        $installed += ".agents/skills/$($r.Name)"
    }
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

& (Join-Path $PSScriptRoot 'Sync-AgentSkills.ps1') | Select-String 'LINKED|Complete'
& (Join-Path $PSScriptRoot 'Build-Index.ps1') | Select-Object -Last 1
Write-Host "Stage with: git add -- $($installed -join ' ') .agents/skills/skills-index.md" -ForegroundColor Cyan
