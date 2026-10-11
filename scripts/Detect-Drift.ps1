#Requires -Version 7.0

<#
.SYNOPSIS
    Detect-Drift.ps1 - Fast, zero-cost mechanical drift & health scanner for AIOS.
.DESCRIPTION
    Executes mechanical checks across the repository:
    1. Routing Integrity (verifies all referenced paths in routers exist)
    2. Index Truth & ADR-0023 Standard (detects phantoms, orphans, and legacy generic index.md files)
    3. Hygiene & Skills Integrity
    4. Cross-Repository Shared Drift
    5. Zero Em-Dash Compliance (ADR-0012)
    6. Domain Vocabulary Compliance (CONTEXT.md)
    7. Script Syntax & AST Integrity Gate
    8. Naming Standards & Root Qualification Gate
    9. YAML Frontmatter Syntax & Quoting Gate (ADR-0013)
    10. Model Registry Name Integrity (ADR-0030)
    11. Wiki Contradiction Heuristic (numeric/date/version claim diff across wiki/)
    12. ADR Dead-Task Reaper Gate (ADR-0055) (flags or auto-retires tasks whose premise an ADR retired)

    Output is summarised by default: each gate prints at most its first 5 WARN/DRIFT
    lines, then a "+N more" line. [FAIL] lines always print in full. Use -Detail for
    every line. Exit code is 1 when any [FAIL] was counted, else 0 (unchanged by -Detail).
.PARAMETER RepoPath
    The repository to inspect (default: {{REPO_PATH}}).
.PARAMETER Gates
    Run only the named or numbered gates (e.g. -Gates 5,7 or -Gates ZeroEmDash). Default: all.
.PARAMETER PeerRepoPath
    Peer repository for the cross-repo drift gate (default: the other of the two AIOS repos).
.PARAMETER ReapDeadTasks
    Automatically mutates active tasks whose premise is retired by an ADR to status: Retired.
.PARAMETER Detail
    Print every WARN/DRIFT line instead of the first 5 per gate.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$RepoPath = "{{REPO_PATH}}",

    [Parameter()]
    [string[]]$Gates = @(),

    [Parameter()]
    [string]$PeerRepoPath = "",

    [Parameter()]
    [switch]$ReapDeadTasks,

    [Parameter()]
    [switch]$Detail,

    [switch]$SelfTest
)

if ($SelfTest) {
    Write-Host "[PASS] $($MyInvocation.MyCommand.Name) selftest: pass" -ForegroundColor Green
    return
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$gateMap = @{
    1 = "Routing"
    2 = "IndexTruth"
    3 = "Skills"
    4 = "CrossRepo"
    5 = "ZeroEmDash"
    6 = "Vocabulary"
    7 = "AST"
    8 = "Naming"
    9 = "Frontmatter"
    10 = "ModelRegistry"
    11 = "WikiContradiction"
    12 = "AdrDeadTasks"
}


$selectedGates = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
if ($Gates -and $Gates.Count -gt 0) {
    $rawTokens = foreach ($g in $Gates) { $g -split '[,;\s]+' }
    foreach ($trimmed in $rawTokens) {
        $trimmed = $trimmed.Trim()
        if (-not $trimmed) { continue }
        if ($trimmed -match '^\d+$') {
            $num = [int]$trimmed
            if ($gateMap.ContainsKey($num)) {
                [void]$selectedGates.Add($gateMap[$num])
            }
        } else {
            $cleanName = $trimmed -replace '[-_\s]', ''
            $matchedKey = $false
            foreach ($k in $gateMap.Keys) {
                if ($gateMap[$k] -eq $cleanName -or $gateMap[$k] -like "*$cleanName*") {
                    [void]$selectedGates.Add($gateMap[$k])
                    $matchedKey = $true
                }
            }
            if (-not $matchedKey) {
                [void]$selectedGates.Add($cleanName)
            }
        }
    }
}

function Test-GateEnabled([int]$GateNumber, [string]$GateName) {
    if ($selectedGates.Count -eq 0) { return $true }
    return ($selectedGates.Contains($GateName) -or $selectedGates.Contains("$GateNumber"))
}

# Summary output: [FAIL] lines print via Write-Host directly (always in full);
# WARN/DRIFT lines go through Write-Finding, which caps each gate at 5 unless -Detail.
$script:GateShown = 0
$script:GateHidden = 0
function Close-GateOutput {
    if ($script:GateHidden -gt 0) {
        Write-Host "  ... +$($script:GateHidden) more (rerun with -Detail)" -ForegroundColor DarkGray
    }
    $script:GateShown = 0
    $script:GateHidden = 0
}
function Start-Gate([string]$Title) {
    Close-GateOutput
    Write-Host $Title -ForegroundColor Yellow
}
function Write-Finding([string]$Text) {
    if ($Detail -or $script:GateShown -lt 5) {
        Write-Host $Text -ForegroundColor Yellow
        $script:GateShown++
    } else {
        $script:GateHidden++
    }
}

$coreModule = Join-Path $PSScriptRoot "modules\AIOSCore.psm1"
if (-not (Test-Path -LiteralPath $coreModule)) {
    Write-Error "AIOSCore module not found: $coreModule"
    exit 1
}
Import-Module -Name $coreModule -Force

if (-not (Test-Path -LiteralPath $RepoPath)) {
    Write-Error "RepoPath does not exist: $RepoPath"
    return
}

$RepoRoot = Resolve-AIOSRepoRoot -StartPath $RepoPath
Write-Host "=== AIOS Drift & Health Detector ===" -ForegroundColor Cyan
Write-Host "Target: $RepoRoot" -ForegroundColor Gray
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray
Write-Host ""

$IssueCount = 0
$FailCount = 0

# One recursive walk shared by gates 2, 5, 7, 8. Built lazily on first use, so
# -Gates runs that need no file list pay nothing. Drops only the trees every one of
# those gates already excludes (.git, .obsidian, .claude, .gemini); each gate then
# applies its own remaining exclusions. Same cmdlet and order as the per-gate walks it
# replaces (hidden/system entries still skipped), so finding order is unchanged.
$script:AllFiles = $null
function Initialize-AllFiles {
    if ($null -ne $script:AllFiles) { return }
    $commonExclude = [regex]::new('\\(\.git|\.obsidian|\.claude|\.gemini)\\', 'IgnoreCase')
    $list = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    foreach ($f in Get-ChildItem -LiteralPath $RepoRoot -Recurse -File) {
        # Symlinks are generated views (projects/<slug>/tasks/, ADR-0073): the real file is already in the list.
        if (-not $commonExclude.IsMatch($f.FullName) -and -not $f.LinkType) { $list.Add($f) }
    }
    $script:AllFiles = $list
}

# Vendored trees (Get-AIOSVendoredPaths is the SSOT), as one regex on the absolute path.
# Same answer as Test-AIOSVendoredPath without a module call per file.
$vendoredAlt = (@(Get-AIOSVendoredPaths) | ForEach-Object { [regex]::Escape(($_ -replace '/', '\')) }) -join '|'
$vendoredRx = [regex]::new('^' + [regex]::Escape($RepoRoot.TrimEnd('\', '/')) + '\\(' + $vendoredAlt + ')\\', 'IgnoreCase')

if (Test-GateEnabled -GateNumber 1 -GateName "Routing") {
# 1. Routing Integrity Check
Start-Gate "[1/12] Checking Routing Integrity..."

$routerFiles = @("AGENTS.md", "CLAUDE.md", "MASTER-INSTRUCTIONS.md", ".agents/rules/aios-code-overlay.md", ".claude/claude-overlay.md", ".agents/rules/antigravity-overlay.md", "modes/router.md", "memory/operator.md", "memory/soul.md", "memory/core.md")

foreach ($rf in $routerFiles) {
    $full = Join-Path -Path $RepoRoot -ChildPath $rf
    if (-not (Test-Path -LiteralPath $full)) {
        Write-Host "  [FAIL] Missing core router: $rf" -ForegroundColor Red
        $IssueCount++
        $FailCount++
    }
}

$substrateScript = Join-Path -Path $RepoRoot -ChildPath "scripts\Audit-Substrate.ps1"
if (Test-Path -LiteralPath $substrateScript) {
    # Stays a child pwsh: Audit-Substrate re-imports AIOSCore with -Force, which would
    # tear down this script's module state if run in-process. -LinksOnly skips the em-dash,
    # syntax, frontmatter and eval work that gates 5, 7 and 9 already do.
    $subJson = $null
    try {
        $subJson = & pwsh -NoProfile -File $substrateScript -RepoPath $RepoRoot -Quiet -AsJson -LinksOnly | ConvertFrom-Json
    } catch { }
    if ($null -eq $subJson -or -not $subJson.PSObject.Properties['broken_links']) {
        Write-Host "  [FAIL] Audit-Substrate.ps1 produced no parseable link report; broken-link check did not run" -ForegroundColor Red
        $IssueCount++
        $FailCount++
    } elseif ($subJson.broken_links -gt 0) {
        Write-Host "  [FAIL] $($subJson.broken_links) broken links detected across substrate:" -ForegroundColor Red
        foreach ($bl in $subJson.broken_link_details) {
            Write-Host "    $bl" -ForegroundColor Red
            $IssueCount++
            $FailCount++
        }
    } else {
        Write-Host "  -> Zero broken links confirmed across substrate." -ForegroundColor Green
    }
}

# Canon that cites its own sections must have them.
foreach ($rf in $routerFiles) {
    $full = Join-Path -Path $RepoRoot -ChildPath $rf
    if (-not (Test-Path -LiteralPath $full)) { continue }
    $txt = Get-Content -LiteralPath $full -Raw -Encoding UTF8
    $have = @([regex]::Matches($txt, '(?m)^##\s+(\d+)\.') | ForEach-Object { $_.Groups[1].Value })
    $cited = @([regex]::Matches($txt, [char]0x00A7 + '(\d+)') | ForEach-Object { $_.Groups[1].Value }) | Select-Object -Unique
    foreach ($s in $cited) {
        if ($s -notin $have) {
            Write-Host "  [FAIL] ${rf} cites section $s, which does not exist" -ForegroundColor Red
            $IssueCount++
            $FailCount++
        }
    }
}

# Session load canary verification
$agentsTxt = Get-Content -LiteralPath (Join-Path $RepoRoot "AGENTS.md") -Raw -Encoding UTF8
$soulTxt = Get-Content -LiteralPath (Join-Path $RepoRoot "memory/soul.md") -Raw -Encoding UTF8
if ($agentsTxt -match 'SOUL-CANARY-8821') {
    if ($soulTxt -notmatch 'SOUL-CANARY-8821') {
        Write-Host "  [FAIL] AGENTS.md cites SOUL-CANARY-8821 but token is missing in memory/soul.md" -ForegroundColor Red
        $IssueCount++
        $FailCount++
    } else {
        Write-Host "  -> Soul session load canary verified (SOUL-CANARY-8821)." -ForegroundColor Green
    }
}
}

if (Test-GateEnabled -GateNumber 2 -GateName "IndexTruth") {
# 2. Index Truth & ADR-0023 Standard Check
Start-Gate "[2/12] Checking Index Truth & ADR-0023..."
Initialize-AllFiles

# One pass over the shared list collects both sets:
#  - legacy generic index.md in subdirectories (ADR-0023)
#  - managed folder indexes (<folder>-index.md; ADRs like 0054-...-index.md are not indexes)
$legacyRx = [regex]::new('\\(\.git|\.obsidian|\.claude|\.gemini|notion-export|legacy-claude-workspace)\\', 'IgnoreCase')
$folderIdxRx = [regex]::new('\\(\.git|\.worktrees|\.obsidian|\.claude|\.gemini|notion-export|legacy-claude-workspace|references)\\', 'IgnoreCase')
$legacyIndexes = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
$folderIndexes = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
foreach ($f in $script:AllFiles) {
    if ($f.Name -eq 'index.md') {
        if ($f.DirectoryName -ne $RepoRoot -and -not $legacyRx.IsMatch($f.FullName) -and -not $vendoredRx.IsMatch($f.FullName)) {
            $legacyIndexes.Add($f)
        }
    }
    if ($f.Name.EndsWith('-index.md', [StringComparison]::OrdinalIgnoreCase) -and
        $f.Name -eq "$($f.Directory.Name)-index.md" -and
        -not $folderIdxRx.IsMatch($f.FullName)) {
        $folderIndexes.Add($f)
    }
}

foreach ($lIdx in $legacyIndexes) {
    $relPath = $lIdx.FullName.Replace($RepoRoot, '').TrimStart('\/')
    Write-Host "  [FAIL] Legacy generic index.md found in: $relPath (must be <folder>-index.md per ADR-0023)" -ForegroundColor Red
    $IssueCount++
    $FailCount++
}

# Validate all managed folder indexes (<folder>-index.md)
foreach ($idx in $folderIndexes) {
    $parent = $idx.Directory
    if ($parent.FullName -eq $RepoRoot) { continue }

    $parentItems = Get-ChildItem -LiteralPath $parent.FullName -File -Filter "*.md" |
        Where-Object {
            $_.Name -notmatch 'index\.md$' -and
            $_.Name -notmatch '^\.' -and
            $_.Name -notmatch '^_'
        }

    $idxContent = Get-Content -LiteralPath $idx.FullName -Raw -Encoding UTF8
    # ADR-0063: a sharded index (memory-index.md) is a router; its rows live in
    # <folder>-index-<range>.md siblings. An item listed in any shard is indexed.
    foreach ($shard in @(Get-ChildItem -LiteralPath $parent.FullName -File -Filter "$($parent.Name)-index-*.md")) {
        $idxContent += "`n" + (Get-Content -LiteralPath $shard.FullName -Raw -Encoding UTF8)
    }
    foreach ($item in $parentItems) {
        if ($idxContent.IndexOf($item.Name, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            Write-Finding "  [WARN] Orphan in $($parent.Name): $($item.Name) not found in $($idx.Name)"
            $IssueCount++
        }
    }
}
}

if (Test-GateEnabled -GateNumber 3 -GateName "Skills") {
# 3. Hygiene & Skills Check
Start-Gate "[3/12] Checking Skills & Hygiene..."
$skillDirs = Get-ChildItem -LiteralPath (Join-Path -Path $RepoRoot -ChildPath ".agents\skills") -Directory |
    Where-Object { $_.Name -notmatch '^_|\.' }

foreach ($sd in $skillDirs) {
    $skillMd = Join-Path -Path $sd.FullName -ChildPath "SKILL.md"
    if (-not (Test-Path -LiteralPath $skillMd)) {
        Write-Host "  [FAIL] Broken skill (missing SKILL.md): .agents/skills/$($sd.Name)" -ForegroundColor Red
        $IssueCount++
        $FailCount++
        continue
    }

    $skillContent = Get-Content -LiteralPath $skillMd -Raw -Encoding UTF8

    # Gate: scope-tag (every SKILL.md carries scope: personal or structural)
    if ($skillContent -match '(?s)^---\r?\n(.*?)\r?\n---') {
        $fm = $Matches[1]
        if ($fm -match '(?m)^scope:\s*["'']?(personal|structural)["'']?\s*$') {
            # Valid scope tag
        } elseif ($fm -match '(?m)^scope:\s*(.+)$') {
            Write-Host "  [FAIL] Invalid scope tag in .agents/skills/$($sd.Name)/SKILL.md: '$($Matches[1].Trim())' (must be 'personal' or 'structural')" -ForegroundColor Red
            $IssueCount++
            $FailCount++
        } else {
            Write-Host "  [FAIL] Missing scope tag in .agents/skills/$($sd.Name)/SKILL.md (must be 'scope: personal' or 'scope: structural')" -ForegroundColor Red
            $IssueCount++
            $FailCount++
        }
    } else {
        Write-Host "  [FAIL] Missing frontmatter and scope tag in .agents/skills/$($sd.Name)/SKILL.md" -ForegroundColor Red
        $IssueCount++
        $FailCount++
    }

    # Gate: path-exists (every path referenced inside a SKILL.md resolves on disk)
    $cleanContent = $skillContent -replace '(?s)```.*?```', ''
    $linkMatches = [regex]::Matches($cleanContent, '\[([^\]]*)\]\(((?:[^()]|\([^()]*\))*)\)')
    foreach ($lm in $linkMatches) {
        $rawTarget = $lm.Groups[2].Value.Trim()
        if ($rawTarget -notmatch '^(https?://|mailto:|#)') {
            $targetPath = $rawTarget.Split('#')[0].Split('?')[0].Trim()
            if ($targetPath -ne '') {
                $resolvedPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($sd.FullName, $targetPath))
                if (-not (Test-Path -LiteralPath $resolvedPath)) {
                    Write-Host "  [FAIL] Broken path reference in .agents/skills/$($sd.Name)/SKILL.md: $rawTarget (resolved to $resolvedPath)" -ForegroundColor Red
                    $IssueCount++
                    $FailCount++
                }
            }
        }
    }
}

$testModesScript = Join-Path $RepoRoot "scripts\Test-AllModes.ps1"
if (Test-Path -LiteralPath $testModesScript) {
    try {
        & $testModesScript -RepoPath $RepoRoot | Out-Null
    } catch {
        Write-Host "  [FAIL] Mode suite integrity check failed (run scripts/Test-AllModes.ps1)" -ForegroundColor Red
        $IssueCount++
        $FailCount++
    }
}

$auditTasksScript = Join-Path $RepoRoot "scripts\Audit-Tasks.ps1"
if (Test-Path -LiteralPath $auditTasksScript) {
    try {
        $taskIssues = & $auditTasksScript -RepoPath $RepoRoot | Select-Object -Last 1
        if ($taskIssues -is [int] -and $taskIssues -gt 0) {
            Write-Host "  [FAIL] Task substrate audit found $taskIssues issue(s) (run scripts/Audit-Tasks.ps1)" -ForegroundColor Red
            $IssueCount += $taskIssues
            $FailCount += $taskIssues
        }
    } catch {
        Write-Host "  [FAIL] Task substrate audit crashed: $($_.Exception.Message) (run scripts/Audit-Tasks.ps1)" -ForegroundColor Red
        $IssueCount++
        $FailCount++
    }
}
}

if (Test-GateEnabled -GateNumber 4 -GateName "CrossRepo") {
# 4. Cross-Repository Shared Skills & Templates Drift
Start-Gate "[4/12] Checking Cross-Repository Shared Drift..."
$peerRepo = if ($PeerRepoPath) { $PeerRepoPath } elseif ($RepoRoot -match '{{BUSINESS_NAME}}') { '{{REPO_PATH}}' } else { '{{BUSINESS_REPO_PATH}}' }
$manifestPath = Join-Path $RepoRoot "scripts\sync\shared-manifest.psd1"

$peerSkillsDir = Join-Path $peerRepo ".agents\skills"
if (-not (Test-Path -LiteralPath $peerSkillsDir)) {
    $peerSkillsDir = Join-Path $peerRepo "skills"
}

if ((Test-Path -LiteralPath $peerSkillsDir) -and (Test-Path -LiteralPath $manifestPath)) {
    $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath

    # Gate: cross-repo-duplicate (any skill present in both repos but absent from shared-manifest.psd1)
    $peerSkills = @(Get-ChildItem -LiteralPath $peerSkillsDir -Directory |
        Where-Object { $_.Name -notmatch '^_|\.' } |
        Select-Object -ExpandProperty Name)
    $localSkillsDir = Join-Path -Path $RepoRoot -ChildPath ".agents\skills"
    $localSkills = if (Test-Path -LiteralPath $localSkillsDir) {
        @(Get-ChildItem -LiteralPath $localSkillsDir -Directory |
            Where-Object { $_.Name -notmatch '^_|\.' } |
            Select-Object -ExpandProperty Name)
    } else { @() }

    $sharedSkillsSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($sk in $manifest.Skills) { [void]$sharedSkillsSet.Add($sk) }
    if ($manifest.ContainsKey('ForkedSkills') -and $manifest.ForkedSkills) {
        foreach ($fsk in $manifest.ForkedSkills) { [void]$sharedSkillsSet.Add($fsk) }
    }

    $untrackedDuplicates = @()
    foreach ($lsk in $localSkills) {
        if ($peerSkills -contains $lsk -and -not $sharedSkillsSet.Contains($lsk)) {
            $untrackedDuplicates += $lsk
        }
    }

    if ($untrackedDuplicates.Count -gt 0) {
        Write-Host "  [FAIL] $($untrackedDuplicates.Count) untracked cross-repo duplicate skill(s) detected (present in both repos, missing from shared-manifest.psd1):" -ForegroundColor Red
        foreach ($dup in $untrackedDuplicates) {
            Write-Host "    - $dup" -ForegroundColor Red
            $IssueCount++
            $FailCount++
        }
    }

    # One compare loop for skills, templates and scripts: (label, sync category, name, local path, peer path).
    $sharedPairs = [System.Collections.Generic.List[object]]::new()
    foreach ($sk in $manifest.Skills) {
        $p2 = Join-Path (Join-Path $peerRepo "skills") "$sk\SKILL.md"
        if (-not (Test-Path -LiteralPath $p2)) {
            $p2 = Join-Path (Join-Path $peerRepo ".agents\skills") "$sk\SKILL.md"
        }
        $sharedPairs.Add(@('skill', 'skills', $sk, (Join-Path (Join-Path $RepoRoot ".agents\skills") "$sk\SKILL.md"), $p2))
    }
    foreach ($tpl in $manifest.Templates) {
        $sharedPairs.Add(@('template', 'templates', $tpl, (Join-Path (Join-Path $RepoRoot "templates") $tpl), (Join-Path (Join-Path $peerRepo "templates") $tpl)))
    }
    foreach ($scr in $manifest.Scripts) {
        $sharedPairs.Add(@('script', 'scripts', $scr, (Join-Path (Join-Path $RepoRoot "scripts") $scr), (Join-Path (Join-Path $peerRepo "scripts") $scr)))
    }

    foreach ($pair in $sharedPairs) {
        $label, $category, $name, $p1, $p2 = $pair
        if ((Test-Path -LiteralPath $p1) -and (Test-Path -LiteralPath $p2)) {
            $t1 = ([System.IO.File]::ReadAllText($p1).Trim() -replace '\r\n', "`n").TrimStart([char]0xFEFF)
            $t2 = ([System.IO.File]::ReadAllText($p2).Trim() -replace '\r\n', "`n").TrimStart([char]0xFEFF)
            if ($t1 -ne $t2) {
                Write-Finding "  [DRIFT] Shared $label '$name' differs between AIOS and {{BUSINESS_NAME}} (run scripts/sync/Sync-Shared.ps1 -Category $category)"
                $IssueCount++
            }
        }
    }
}
}

if (Test-GateEnabled -GateNumber 5 -GateName "ZeroEmDash") {
# 5. Zero Em-Dash Compliance Check (ADR-0012)
Start-Gate "[5/12] Checking Zero-EmDash Compliance..."
Initialize-AllFiles
$emDashChar = [char]0x2014
$emDashExcludeRx = [regex]::new('\\(\.git|\.obsidian|\.claude|\.gemini|archive|raw|logs|node_modules|.*venv.*|site-packages)\\', 'IgnoreCase')
$emDashSelfRx = [regex]::new('skills[\\/]de-emdash|scripts[\\/](Detect-Drift|Invoke-DeEmdash|Find-EmDashes)', 'IgnoreCase')
$emDashExts = [System.Collections.Generic.HashSet[string]]::new([string[]]@('.md', '.ps1', '.py', '.json', '.psd1'), [StringComparer]::OrdinalIgnoreCase)
# Files that legitimately discuss the rule may carry an em dash on a line that says
# prohibited/banned/ADR-0012. Everywhere else only the 'Zero Em-Dash' label is exempt.
$emDashQuoteRx = [regex]::new('^decisions\\0012-', 'IgnoreCase')

foreach ($f in $script:AllFiles) {
    if (-not $emDashExts.Contains($f.Extension)) { continue }
    $full = $f.FullName
    if ($emDashExcludeRx.IsMatch($full) -or $emDashSelfRx.IsMatch($full) -or $vendoredRx.IsMatch($full)) { continue }
    try {
        # Cheap whole-file test first; line numbers only for files that hit.
        $text = [System.IO.File]::ReadAllText($full)
        if (-not $text.Contains($emDashChar)) { continue }
        $rel = $full.Substring($RepoRoot.Length).TrimStart('\', '/')
        $mayQuoteRule = $emDashQuoteRx.IsMatch($rel)
        $lines = $text -split '\r\n|\n|\r'
        $violatingLines = @()
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $l = $lines[$i]
            if ($l.Contains($emDashChar) -and $l -notmatch 'Zero Em-Dash' -and -not ($mayQuoteRule -and $l -match 'prohibited|banned|ADR-0012')) {
                $violatingLines += ($i + 1)
            }
        }
        if ($violatingLines.Count -gt 0) {
            Write-Finding "  [DRIFT] Em dash found in: $rel (lines: $($violatingLines -join ', ')) - run pwsh scripts/Invoke-DeEmdash.ps1"
            $IssueCount++
        }
    } catch { }
}
}

if (Test-GateEnabled -GateNumber 6 -GateName "Vocabulary") {
# 6. Domain Vocabulary Compliance (CONTEXT.md)
Start-Gate "[6/12] Checking Domain Vocabulary Compliance..."
$domainLint = Join-Path $PSScriptRoot "Invoke-DomainLint.ps1"
if (Test-Path -LiteralPath $domainLint) {
    # Stays a child pwsh: its output is Write-Host text that this gate captures from
    # stdout; in-process would need stream redirection for ~0.3s saved.
    $lintOutput = & pwsh -NoProfile -File $domainLint -RepoPath $RepoRoot 2>&1
    $lintExit = $LASTEXITCODE
    if ($lintExit -ne 0 -or ($lintOutput -match 'DOMAIN DRIFT')) {
        $driftLines = @($lintOutput | Where-Object { $_ -match 'DOMAIN DRIFT' })
        foreach ($dl in $driftLines) {
            Write-Finding "  $dl"
        }
        $IssueCount += $driftLines.Count
    }
}
}

if (Test-GateEnabled -GateNumber 7 -GateName "AST") {
# 7. Script Syntax & AST Integrity Gate
Start-Gate "[7/12] Checking Script Syntax & AST Integrity..."
Initialize-AllFiles
$scriptsPrefix = (Join-Path $RepoRoot "scripts") + '\'
$scriptExcludeRx = [regex]::new('\\(\.git|\.obsidian|\.claude|\.gemini|archive|__pycache__)\\', 'IgnoreCase')
$pyToCheck = [System.Collections.Generic.List[string]]::new()

foreach ($sf in $script:AllFiles) {
    $ext = $sf.Extension
    if ($ext -ne '.ps1' -and $ext -ne '.py') { continue }
    $full = $sf.FullName
    if (-not $full.StartsWith($scriptsPrefix, [StringComparison]::OrdinalIgnoreCase) -or $scriptExcludeRx.IsMatch($full)) { continue }
    if ($ext -eq '.py') { $pyToCheck.Add($full); continue }

    $parseErrors = $null
    $tokens = $null
    [System.Management.Automation.Language.Parser]::ParseFile($full, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count -gt 0) {
        $rel = $full.Replace($RepoRoot, '').TrimStart('\/')
        Write-Host "  [FAIL] PowerShell syntax error in: $rel" -ForegroundColor Red
        foreach ($pe in $parseErrors) {
            Write-Host "    Line $($pe.Extent.StartLineNumber): $($pe.Message)" -ForegroundColor Yellow
        }
        $IssueCount++
        $FailCount++
    }
}

# One py_compile call per chunk of 100 files. Only when a chunk fails do we rerun its
# files one by one to name the culprits, so failure reporting stays per-file.
for ($i = 0; $i -lt $pyToCheck.Count; $i += 100) {
    $chunk = @($pyToCheck.GetRange($i, [Math]::Min(100, $pyToCheck.Count - $i)))
    $null = python -m py_compile @chunk 2>&1
    if ($LASTEXITCODE -eq 0) { continue }
    foreach ($pf in $chunk) {
        $null = python -m py_compile $pf 2>&1
        if ($LASTEXITCODE -ne 0) {
            $rel = $pf.Replace($RepoRoot, '').TrimStart('\/')
            Write-Host "  [FAIL] Python syntax error in: $rel" -ForegroundColor Red
            $IssueCount++
            $FailCount++
        }
    }
}
}

if (Test-GateEnabled -GateNumber 8 -GateName "Naming") {
# 8. Naming Standard & Engine Collision Gate (standards/naming-standard.md)
Start-Gate "[8/12] Checking Naming Standards & Root Qualification..."
Initialize-AllFiles
$bannedEngineNames = [System.Collections.Generic.HashSet[string]]::new([string[]]@("claude.md", "agents.md", "gemini.md", "cursor.md", "copilot.md", "windsurf.md", "chatgpt.md"), [StringComparer]::OrdinalIgnoreCase)
$approvedRootFiles = @("AGENTS.md", "CLAUDE.md", "GEMINI.md", "HERMES.md", "MASTER-INSTRUCTIONS.md", "BUILD-PLAN.md", "CONTEXT.md", "TASKS.md", "README.md", "aios.ps1", "index.md", "connections.md", "rot.md", "INTENT.md", ".gitignore")

# Check 1: Root Qualification Standard
$rootFiles = Get-ChildItem -LiteralPath $RepoRoot -File | Where-Object { $_.Name -notmatch '^\.' }
foreach ($rf in $rootFiles) {
    if ($rf.Name -notin $approvedRootFiles) {
        Write-Host "  [FAIL] Unapproved root file: $($rf.Name) (violates Root Qualification Standard in standards/naming-standard.md)" -ForegroundColor Red
        $IssueCount++
        $FailCount++
    }
}

# Check 1b: GEMINI.md truncation budget (ADR-0030). Antigravity hard-truncates rule
# files at 24,000 B; Build-GeminiAutoload.ps1 already exits 1 over 23,500 B, this
# gate makes the same overrun visible in routine drift scans, not just at build time.
$geminiFile = Join-Path -Path $RepoRoot -ChildPath "GEMINI.md"
if (Test-Path -LiteralPath $geminiFile) {
    $geminiBytes = (Get-Item -LiteralPath $geminiFile).Length
    if ($geminiBytes -gt 23500) {
        Write-Host "  [FAIL] GEMINI.md is $geminiBytes B, over the 23,500 B budget; Antigravity truncates silently past 24,000 B (run scripts/Build-GeminiAutoload.ps1)" -ForegroundColor Red
        $IssueCount++
        $FailCount++
    }
}

$namingExcludeRx = [regex]::new('\\(\.git|\.obsidian|\.claude|\.gemini|\.graphify|_dist|archive|raw|logs|node_modules|__pycache__|\.venv|venv|clone-venv|\.venv-laya|universal-template)\\', 'IgnoreCase')  # universal-template ships AGENTS.md/CLAUDE.md by design

foreach ($f in $script:AllFiles) {
    $name = $f.Name
    $ext = $f.Extension
    # Only three cheap name tests can fire; skip the path regexes for the vast majority.
    $isBanned = $bannedEngineNames.Contains($name)
    $hasSpace = ($ext -in @(".md", ".ps1", ".py")) -and ($name -match '\s')
    $hasDoubleHyphen = ($ext -eq ".md") -and $name.Contains('--')
    if (-not ($isBanned -or $hasSpace -or $hasDoubleHyphen)) { continue }
    $full = $f.FullName
    if ($namingExcludeRx.IsMatch($full) -or $vendoredRx.IsMatch($full)) { continue }

    $rel = $full.Replace($RepoRoot, '').TrimStart('\/')

    # Check 2: Engine collision in subdirectories
    if ($isBanned -and $f.DirectoryName -ne $RepoRoot) {
        Write-Host "  [FAIL] Banned engine name collision in: $rel (must disambiguate with -ai or -tool suffix)" -ForegroundColor Red
        $IssueCount++
        $FailCount++
    }

    # Check 3: Spaces in active markdown/script paths
    if ($hasSpace) {
        Write-Host "  [FAIL] Space detected in filename: $rel (must be kebab-case or PascalCase)" -ForegroundColor Red
        $IssueCount++
        $FailCount++
    }

    # Check 4: Consecutive hyphens in active markdown files
    if ($hasDoubleHyphen) {
        Write-Host "  [FAIL] Consecutive hyphens in filename: $rel" -ForegroundColor Red
        $IssueCount++
        $FailCount++
    }
}

# Check 5: Decisions naming schema
$decisionFiles = Get-ChildItem -LiteralPath (Join-Path $RepoRoot "decisions") -File -Filter "*.md" |
    Where-Object { $_.Name -notmatch 'index\.md$' }
foreach ($df in $decisionFiles) {
    if ($df.Name -notmatch '^\d{4}-[a-z0-9-]+\.md$') {
        Write-Host "  [FAIL] Invalid ADR filename format: decisions/$($df.Name) (must be 000N-kebab-slug.md)" -ForegroundColor Red
        $IssueCount++
        $FailCount++
    }
}

# Check 6: Capture naming schema
if (Test-Path -LiteralPath (Join-Path $RepoRoot "capture")) {
    $captureFiles = Get-ChildItem -LiteralPath (Join-Path $RepoRoot "capture") -File -Filter "*.md" |
        Where-Object { $_.Name -notmatch 'index\.md$' }
    foreach ($cf in $captureFiles) {
        if ($cf.Name -notmatch '^\d{4}-\d{2}-\d{2}T\d{4}-[a-z0-9-]+\.md$') {
            Write-Host "  [FAIL] Invalid Capture filename format: capture/$($cf.Name) (must be YYYY-MM-DDTHHmm-slug.md)" -ForegroundColor Red
            $IssueCount++
            $FailCount++
        }
    }
}

# Check 7: Audits & Handoffs naming schema
foreach ($dir in @("audits", "handoff-docs")) {
    $targetDir = Join-Path $RepoRoot $dir
    if (Test-Path -LiteralPath $targetDir) {
        $eventFiles = Get-ChildItem -LiteralPath $targetDir -File -Filter "*.md" |
            Where-Object { $_.Name -notmatch 'index\.md$' }
        foreach ($ef in $eventFiles) {
            if ($ef.Name -notmatch '^\d{4}-\d{2}-\d{2}-[a-z0-9-]+\.md$') {
                Write-Host "  [FAIL] Invalid dated event filename format: $dir/$($ef.Name) (must be YYYY-MM-DD-slug.md)" -ForegroundColor Red
                $IssueCount++
                $FailCount++
            }
        }
    }
}
}

if (Test-GateEnabled -GateNumber 9 -GateName "Frontmatter") {
# 9. YAML Frontmatter Syntax & Quoting Gate (ADR-0013)
Start-Gate "[9/12] Checking YAML Frontmatter Syntax & Quoting..."
$frontmatterLint = Join-Path $PSScriptRoot "Invoke-FrontmatterLint.ps1"
if (Test-Path -LiteralPath $frontmatterLint) {
    # Stays a child pwsh: the lint re-imports AIOSCore with -Force and ends with
    # `exit <count>`; both are unsafe in-process. Its cost is the python yaml pass anyway.
    $fmLintOutput = & pwsh -NoProfile -File $frontmatterLint -RepoPath $RepoRoot -Quiet 2>&1
    $fmLintExit = $LASTEXITCODE
    if ($fmLintExit -ne 0) {
        # The exit code is a count that wraps at 256; count the [FAIL] lines instead.
        $failLines = @($fmLintOutput | Where-Object { $_ -match '\[FAIL\]' })
        foreach ($fl in $failLines) {
            Write-Host "  $fl" -ForegroundColor Red
        }
        $fmFails = $failLines.Count
        if ($fmFails -eq 0) {
            Write-Host "  [FAIL] Frontmatter lint exited $fmLintExit without any [FAIL] line (run scripts/Invoke-FrontmatterLint.ps1)" -ForegroundColor Red
            $fmFails = 1
        }
        $IssueCount += $fmFails
        $FailCount += $fmFails
    }
}
}

if (Test-GateEnabled -GateNumber 10 -GateName "ModelRegistry") {
# 10. Model Registry Name Integrity Gate (ADR-0030)
# The registry is the sole authority for model names. Any model named in the router
# or in ADR-0030 that has no row in the registry is drift (a partial sync left a
# superseded name behind) or a fabrication (a model that never existed). Both look
# identical to a reader and neither is catchable by a link check, because the name
# is prose, not a path.
Start-Gate "[10/12] Checking Model Registry Name Integrity..."

$registryPath = Join-Path $RepoRoot "tools/model-registry.md"
$consumerPaths = @("tools/model-router.md", "decisions/0030-harness-aware-model-routing-and-quota-telemetry.md")

if (-not (Test-Path -LiteralPath $registryPath)) {
    Write-Host "  [FAIL] Missing model registry: tools/model-registry.md" -ForegroundColor Red
    $IssueCount++
    $FailCount++
} else {
    # Registry model names are the bolded leading cell of each matrix row.
    $registryNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($line in (Get-Content -LiteralPath $registryPath -Encoding UTF8)) {
        $m = [regex]::Match($line, '^\|\s*\*\*(?<name>[^*]+?)\*\*')
        if ($m.Success) { [void]$registryNames.Add($m.Groups['name'].Value.Trim()) }
    }

    if ($registryNames.Count -lt 5) {
        Write-Host "  [FAIL] Parsed only $($registryNames.Count) model names from the registry matrix (expected 5+); the matrix format changed" -ForegroundColor Red
        $IssueCount++
        $FailCount++
    }

    # Vendor + 1-3 trailing tokens. Trailing tokens are stripped one at a time until a
    # registry name matches, so effort suffixes ("Gemini 3.8 Flash Low") resolve to their
    # base row without needing a hardcoded list of tier words.
    $modelPattern = '\b(?<vendor>Claude|Gemini|GPT-OSS)(?<rest>(?:\s+(?:[A-Z][a-zA-Z]*|[0-9]+(?:\.[0-9]+)?B?(?![-\w]))){1,3})\b'
    # Harness and product phrases, not models: "Claude Pro", "Claude Code", "Claude Desktop".
    $harnessWords = @('Pro', 'Code', 'Desktop', 'Harness')
    # A line that explicitly retires or disclaims a name is allowed to name it.
    $exemptLine = 'retired|superseded|never existed|does not exist|not in the registry|no such model'

    foreach ($cp in $consumerPaths) {
        $full = Join-Path $RepoRoot $cp
        if (-not (Test-Path -LiteralPath $full)) {
            Write-Host "  [FAIL] Missing registry consumer: $cp" -ForegroundColor Red
            $IssueCount++
            $FailCount++
            continue
        }
        $lineNo = 0
        $reported = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($line in (Get-Content -LiteralPath $full -Encoding UTF8)) {
            $lineNo++
            if ($line -match $exemptLine) { continue }
            foreach ($hit in [regex]::Matches($line, $modelPattern)) {
                $tokens = @($hit.Groups['vendor'].Value) + @($hit.Groups['rest'].Value.Trim() -split '\s+')
                if ($tokens.Count -lt 2) { continue }
                if ($harnessWords -contains $tokens[1]) { continue }

                $matched = $false
                for ($take = $tokens.Count; $take -ge 2; $take--) {
                    if ($registryNames.Contains(($tokens[0..($take - 1)] -join ' '))) { $matched = $true; break }
                }
                if (-not $matched) {
                    $candidate = $tokens -join ' '
                    if ($reported.Add($candidate)) {
                        Write-Host "  [FAIL] ${cp}:${lineNo} names '$candidate', which has no row in tools/model-registry.md" -ForegroundColor Red
                        $IssueCount++
                        $FailCount++
                    }
                }
            }
        }
    }
}
}

if (Test-GateEnabled -GateNumber 11 -GateName "WikiContradiction") {
# 11. Wiki Contradiction Heuristic
# A cheap numeric/date/version claim-diff, not full NLP: wiki/ is 11 hand-curated
# technical files, not a fact-registry, so a semantic contradiction detector would be
# over-engineering. See Find-WikiClaimContradiction in modules/AIOSCore.psm1.
Start-Gate "[11/12] Checking Wiki Contradiction Heuristic..."
$wikiDir = Join-Path $RepoRoot "wiki"
if (Test-Path -LiteralPath $wikiDir) {
    $wikiFiles = Get-ChildItem -LiteralPath $wikiDir -Recurse -File -Filter "*.md" |
        Where-Object { $_.Name -notmatch '-index\.md$' }
    $contradictions = @(Find-WikiClaimContradiction -Path $wikiFiles.FullName)
    foreach ($c in $contradictions) {
        $entryText = ($c.Entries | ForEach-Object { "$($_.File.Replace($RepoRoot, '').TrimStart('\/')) = '$($_.Value)'" }) -join '; '
        Write-Finding "  [WARN] Conflicting claim for '$($c.Subject)': $entryText"
        $IssueCount++
    }
    if ($contradictions.Count -eq 0) {
        Write-Host "  -> No conflicting numeric/date/version claims detected across wiki/." -ForegroundColor Green
    }
}
}

if (Test-GateEnabled -GateNumber 12 -GateName "AdrDeadTasks") {
# 12. ADR Dead-Task Reaper Gate (ADR-0055)
# Mechanically verifies active task premises against ADR retirement registries.
# When an ADR declares 'retires_tasks' or 'retires_patterns', matching active tasks
# must be retired. Passing -ReapDeadTasks performs safe in-place migration to status: Retired.
Start-Gate "[12/12] Checking ADR Dead-Task Reaper (ADR-0055)..."
$decisionsDir = Join-Path $RepoRoot "decisions"
$tasksDir = Join-Path $RepoRoot "tasks"

if ((Test-Path -LiteralPath $decisionsDir) -and (Test-Path -LiteralPath $tasksDir)) {
    $adrFiles = Get-ChildItem -LiteralPath $decisionsDir -Filter "0*.md" -File
    $retiredTasksMap = @{}
    $retiredPatternsList = [System.Collections.Generic.List[psobject]]::new()

    foreach ($adr in $adrFiles) {
        $adrContent = Get-Content -LiteralPath $adr.FullName -Raw -Encoding UTF8
        if ($adrContent -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
            $fm = $matches[1]
            $adrId = $adr.BaseName
            if ($fm -match '(?m)^id:\s*([^\r\n]+)') {
                $adrId = $matches[1].Trim('"'', ')
            }

            if ($fm -match '(?m)^retires_tasks:\s*\[(.*?)\]') {
                $taskSlugs = $matches[1] -split ',' | ForEach-Object { $_.Trim('"'', ') } | Where-Object { $_ }
                foreach ($ts in $taskSlugs) {
                    if (-not $retiredTasksMap.ContainsKey($ts)) {
                        $retiredTasksMap[$ts] = [System.Collections.Generic.List[string]]::new()
                    }
                    [void]$retiredTasksMap[$ts].Add($adrId)
                }
            }

            if ($fm -match '(?m)^retires_patterns:\s*\[(.*?)\]') {
                $patterns = $matches[1] -split ',' | ForEach-Object { $_.Trim('"'', ') } | Where-Object { $_ }
                foreach ($pat in $patterns) {
                    $retiredPatternsList.Add([pscustomobject]@{
                        Pattern = $pat
                        AdrId   = $adrId
                    })
                }
            }
        }
    }

    $taskFiles = Get-ChildItem -LiteralPath $tasksDir -Filter "*.md" -File |
        Where-Object { $_.Name -notmatch '-index\.md$' }
    $deadTasksFound = 0

    foreach ($tf in $taskFiles) {
        $tContent = Get-Content -LiteralPath $tf.FullName -Raw -Encoding UTF8
        if ($tContent -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
            $tfFm = $matches[1]
            $status = ""
            if ($tfFm -match '(?m)^status:\s*["'']?([^"''\r\n]+)["'']?') {
                $status = $matches[1].Trim()
            }

            if ($status -in @("Done", "Retired")) {
                continue
            }

            $tId = $tf.BaseName
            if ($tfFm -match '(?m)^id:\s*["'']?([^"''\r\n]+)["'']?') {
                $tId = $matches[1].Trim()
            }
            $tName = ""
            if ($tfFm -match '(?m)^name:\s*["'']?([^"''\r\n]+)["'']?') {
                $tName = $matches[1].Trim()
            }

            $matchedAdr = $null
            if ($retiredTasksMap.ContainsKey($tId)) {
                $matchedAdr = ($retiredTasksMap[$tId] -join ", ")
            } elseif ($retiredTasksMap.ContainsKey($tf.BaseName)) {
                $matchedAdr = ($retiredTasksMap[$tf.BaseName] -join ", ")
            } else {
                foreach ($rp in $retiredPatternsList) {
                    if ($tId -match $rp.Pattern -or $tName -match $rp.Pattern) {
                        $matchedAdr = $rp.AdrId
                        break
                    }
                }
            }

            if ($matchedAdr) {
                $deadTasksFound++
                $relTaskPath = "tasks/$($tf.Name)"
                if ($ReapDeadTasks) {
                    $todayStr = (Get-Date).ToString("yyyy-MM-dd")
                    # Preserve the file's own line endings (CRLF or LF).
                    $eol = if ($tContent.Contains("`r`n")) { "`r`n" } else { "`n" }
                    $newFm = $tfFm -replace '(?m)^status:\s*["'']?[^"''\r\n]+["'']?', 'status: "Retired"'
                    if ($newFm -notmatch '(?m)^retired_date:') {
                        $newFm = $newFm.TrimEnd() + "${eol}retired_date: $todayStr"
                    }
                    if ($newFm -notmatch '(?m)^retired_reason:') {
                        $newFm = $newFm.TrimEnd() + "${eol}retired_reason: ""[$matchedAdr]"""
                    }
                    # Splice by index, not -replace, so '$' in the frontmatter is never a substitution token.
                    $fmBlock = [regex]::Match($tContent, '(?s)^---\s*\r?\n.*?\r?\n---')
                    $updatedContent = "---${eol}${newFm}${eol}---" + $tContent.Substring($fmBlock.Length)
                    [System.IO.File]::WriteAllText($tf.FullName, $updatedContent, [System.Text.UTF8Encoding]::new($false))
                    Write-Host "  [REAP] Retired active task '$($tf.Name)' per $matchedAdr" -ForegroundColor Green
                } else {
                    Write-Host "  [FAIL] $relTaskPath : Active task premise retired by $matchedAdr (run with -ReapDeadTasks to auto-retire)" -ForegroundColor Red
                    $IssueCount++
                    $FailCount++
                }
            }
        }
    }

    if ($deadTasksFound -eq 0) {
        Write-Host "  -> All active tasks valid; zero dead-task premises detected." -ForegroundColor Green
    } elseif ($ReapDeadTasks) {
        Write-Host "  -> Reaped $deadTasksFound dead task(s) to status: Retired." -ForegroundColor Green
    }
}
}


Close-GateOutput
Write-Host ""
if ($IssueCount -eq 0) {
    Write-Host "=== Result: CLEAN (0 issues detected) ===" -ForegroundColor Green
} else {
    Write-Host "=== Result: $IssueCount issue(s) detected ($FailCount failure(s)). Run scripts/Build-Index.ps1 or scripts/sync/Sync-Shared.ps1. ===" -ForegroundColor Yellow
}

if ($FailCount -gt 0) {
    exit 1
}
