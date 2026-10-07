#Requires -Version 7.0

<#
.SYNOPSIS
    Delegation Gate (ADR-0065): evaluates a task file against 5 heuristics and resolves
    which lane it routes to: hermes, aios, grill, draft, or operator.
.DESCRIPTION
    Deterministic heuristics, no LLM. See ADR-0065 for the full rationale.
    G1 Done-when testability, G2 quality/taste codified, G3 INTENT.md autonomy allowance,
    G4 digital and reachable, G5 right-sized for a cheap worker.
.PARAMETER TaskFile
    A single task filename (e.g. some-task.md) or full path, relative to tasks/.
.PARAMETER All
    Evaluate every tasks/*.md file with status not Done (skips tasks-index.md and _staged/).
.PARAMETER Apply
    With -All: write resolved lane/autonomous into frontmatter for clear results; queue
    unclear results into tasks/_staged/review-queue.md instead of mutating them.
.PARAMETER Force
    With -Apply: overwrite an existing lane: value instead of respecting it.
.PARAMETER Report
    Per lane/energy_type Done-task counts and send-back (bounces) rate, flagging >=5
    sample groups with >10% bounce rate as "DEMOTE TO grill".
.PARAMETER SelfTest
    Run assert-based checks over in-memory fixtures. Exits non-zero on failure.
.PARAMETER RepoPath
    Root directory of the repository (default: directory containing scripts/..).
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TaskFile,

    [Parameter()]
    [switch]$All,

    [Parameter()]
    [switch]$Apply,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$Report,

    [Parameter()]
    [switch]$SelfTest,

    [Parameter()]
    [string]$RepoPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Gate logic (pure functions over name/frontmatter/body so -SelfTest can run
# without touching disk).
# ---------------------------------------------------------------------------

$script:HermesParked = $true

function Get-DoneWhenClaims([string]$Body) {
    if ($Body -notmatch '(?is)##\s*Done when\s*\r?\n(.*?)(\r?\n##\s|\z)') { return @() }
    $section = $Matches[1]
    $lines = [regex]::Matches($section, '(?m)^\s*-\s*\[[ xX]\]\s*(.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() }
    return @($lines)
}

function Test-ProbeClaim([string]$Claim) {
    if ($Claim -match '`[^`]+`') { return $true }
    if ($Claim -match '\b[\w\-/\.]+\.\w{1,5}\b') { return $true }
    if ($Claim -match '(?i)\b(exit(s|ed)?|returns?|shows?|prints?)\b') { return $true }
    if ($Claim -match '\d+') { return $true }
    return $false
}

function Get-GateG1([string]$Body) {
    $claims = @(Get-DoneWhenClaims $Body)
    if ($claims.Count -eq 0) {
        return @{ result = 'fail'; reason = 'No `## Done when` section or zero claims' }
    }
    if ($claims.Count -lt 2) {
        return @{ result = 'fail'; reason = "Only $($claims.Count) claim(s), need >=2" }
    }
    $probeCount = @($claims | Where-Object { Test-ProbeClaim $_ }).Count
    # "Most claims contain a probe": pass at a majority, unclear below it, matching the
    # gate's own wording ("unclear if claims exist but few probes").
    $majority = [Math]::Ceiling($claims.Count / 2.0)
    if ($probeCount -lt $majority) {
        return @{ result = 'unclear'; reason = "$probeCount/$($claims.Count) claims have a probe (below majority)" }
    }
    return @{ result = 'pass'; reason = "$($claims.Count) claims, $probeCount probed" }
}

function Get-GateG2([string]$Name, [hashtable]$Fm, [string]$Body) {
    if ($Name -match '(?i)^(Decide|Choose|Pick|Review)\b') {
        return @{ result = 'fail'; reason = 'Name opens with an open-decision verb' }
    }
    if ($Fm['taste'] -and [string]$Fm['taste'] -ne '') {
        return @{ result = 'fail'; reason = '`taste:` frontmatter present' }
    }
    if ($Body -match '(?i){{OPERATOR_NAME}} decides|pending decision') {
        return @{ result = 'fail'; reason = 'Body names an open decision' }
    }
    # "## Open questions" is a standard scaffold heading (templates/db-tasks.md); only
    # a fail when real unresolved content sits under it, not the boilerplate heading.
    if ($Body -match '(?is)##\s*Open questions\s*\r?\n(.*?)(\r?\n##\s|\z)') {
        $oq = $Matches[1].Trim()
        if ($oq -and $oq -notmatch '(?i)^(-\s*)?\(?(none|leave empty if none)\)?\.?$' -and $oq -notmatch '(?i)^-?\s*avoid unapproved') {
            return @{ result = 'fail'; reason = 'Open questions section has unresolved content' }
        }
    }
    return @{ result = 'pass'; reason = 'No open taste/decision signal' }
}


# ponytail: bare "post"/"reply" collide with HTTP POST / API reply in nearly every
# backend task; scoped to human-facing publish/message phrasing instead.
$script:G3Pattern = '(?i)\b(pay|payment|purchase|buy|bank|portal|transfer|send (an? )?email|reply to (the |an? )?(email|message|dm)|post (on|to) (twitter|x\.com|instagram|linkedin|social|the blog)|publish (a |the )?(blog|post|article|page|site)|\blogin\b|log in|re-auth|rotate (\w+ ){0,4}keys?|api keys?|credential|password|re-?authori[sz]e|sign in|oauth|delete permanently|force push)\b|{{BUSINESS_NAME}} write|{{BUSINESS_NAME}} aios|peer[- ]repo|agents\.md|master-instructions\.md|intent\.md|needs? operator.{0,2} approval'

function Get-GateG3([string]$Name, [string]$Body) {
    $hay = "$Name`n$Body"
    if ($hay -match $script:G3Pattern) {
        return @{ result = 'fail'; reason = 'Matches an INTENT.md ask-level signal' }
    }
    return @{ result = 'pass'; reason = 'No ask-level signal' }
}


# ponytail: bare "call"/"visit" collide with "function call"/"API call"/"revisit the
# design" in nearly every software task; scoped to human-contact phrasing instead.
$script:G4Pattern = '(?i)\b(clean the|dishes|laundry|organize (the )?(dresser|room|closet)|move furniture|pick up (the )?(kids|dry cleaning|groceries|prescription|package|mail)|drop off|\berrand|phone call|call (the|my) (bank|doctor|dentist|landlord|insurance)|give .* a call|visit (the|a|my) (doctor|dentist|bank|office|store)|in-person|appointment|book a flight|catch a flight|\bflight to\b|build (a |the )?pc\b|pc build|new pc\b|dressers?|furniture|bedroom|kitchen|garage|lawn|yard work|vacuum|groceries|errands|dentist|pharmacy|drive to|{{CITY}} property|install (a |the )?(hardware|graphics card|gpu|ram)|property cleanup)\b'

function Get-GateG4([string]$Name, [string]$Body) {
    $hay = "$Name`n$Body"
    if ($hay -match $script:G4Pattern) {
        return @{ result = 'fail'; reason = 'Matches a physical/human-only signal' }
    }
    return @{ result = 'pass'; reason = 'Digital and reachable' }
}

function Get-GateG5([hashtable]$Fm, [string]$Body) {
    $effort = [string]$Fm['effort']
    if ($effort -eq 'High') {
        return @{ result = 'fail'; reason = 'Effort High' }
    }
    if ($Body -match '(?i)across all|every file|entire codebase') {
        return @{ result = 'fail'; reason = 'Body implies a sweeping change' }
    }
    $fileMentions = @([regex]::Matches($Body, '`[\w\-/\.]+\.\w{1,5}`') | ForEach-Object { $_.Value } | Select-Object -Unique)
    if ($fileMentions.Count -gt 5) {
        return @{ result = 'fail'; reason = "$($fileMentions.Count) distinct files mentioned (>5)" }
    }
    if ($effort -notin @('Low', 'Medium')) {
        return @{ result = 'unclear'; reason = "Effort '$effort' not Low/Medium/High" }
    }
    return @{ result = 'pass'; reason = "Effort $effort, <=5 files" }
}

. (Join-Path $PSScriptRoot 'Test-CommandCenterDesign.ps1')

function Resolve-Lane([string]$Name, [hashtable]$Fm, [string]$Body) {
    $g1 = Get-GateG1 $Body
    $g2 = Get-GateG2 $Name $Fm $Body
    $g3 = Get-GateG3 $Name $Body
    $g4 = Get-GateG4 $Name $Body
    $g5 = Get-GateG5 $Fm $Body

    $gates = [ordered]@{ G1 = $g1; G2 = $g2; G3 = $g3; G4 = $g4; G5 = $g5 }
    $unclear = @($gates.Values | Where-Object { $_.result -eq 'unclear' }).Count -gt 0

    if ($g4.result -eq 'fail') { $lane = 'operator' }
    elseif ($g3.result -eq 'fail') { $lane = 'draft' }
    elseif ($g1.result -eq 'fail' -or $g2.result -eq 'fail') { $lane = 'grill' }
    else {
        $energyType = [string]$Fm['energy_type']
        $verbHit = $Name -match '(?i)^\s*(audit|triage|research|sweep|prune|reconcile|verify|extract|fix link|harvest|dedupe|check)\b'
        if ($g5.result -eq 'pass' -and ($energyType -in @('Quick Win', 'Admin') -or $verbHit)) {
            $lane = 'hermes'
        } else {
            $lane = 'aios'
        }
    }

    # Hermes is parked (manual-only) until OpenRouter is funded (grill 2026-10-02 Q2); flip to $false to resume.
    if ($lane -eq 'hermes' -and $script:HermesParked) { $lane = 'aios' }

    # Invariant: Command Center design work is Claude Code only, never an OpenRouter worker.
    if ($lane -eq 'hermes' -and (Test-CommandCenterDesign $Name $Body ([string]$Fm['project']))) { $lane = 'aios' }

    # A weak G4 and weak G3 signal together is a conflicting-signal case per spec.
    if ($g4.result -eq 'unclear' -and $g3.result -eq 'unclear') { $unclear = $true }

    return @{ lane = $lane; unclear = $unclear; gates = $gates }
}

# ---------------------------------------------------------------------------
# Frontmatter helpers (regex-based, preserves the rest of the file untouched).
# ---------------------------------------------------------------------------

function Get-TaskFrontmatter([string]$Content) {
    $fm = @{}
    if ($Content -match '(?s)^---\r?\n(.*?)\r?\n---') {
        foreach ($line in ($Matches[1] -split '\r?\n')) {
            if ($line -match '^([A-Za-z_]+):\s*(.*)$') {
                $key = $Matches[1]
                $val = $Matches[2].Trim().Trim('"')
                $fm[$key] = $val
            }
        }
    }
    return $fm
}

function Get-TaskBody([string]$Content) {
    if ($Content -match '(?s)^---\r?\n.*?\r?\n---\r?\n(.*)$') { return $Matches[1] }
    return $Content
}

function Set-FrontmatterField([string]$Content, [string]$Key, [string]$Value) {
    if ($Content -notmatch '(?s)^(---\r?\n)(.*?)(\r?\n---)') { return $Content }
    $header = $Matches[1]; $body = $Matches[2]; $footer = $Matches[3]
    # Capture the original matched span length BEFORE any further -match call, since
    # -match overwrites the shared $Matches automatic variable (a real bug once: a
    # later -match on $body with no capture groups nulled $Matches[2] here, so $rest
    # started mid-document instead of after the frontmatter, duplicating the file).
    $origSpanLength = ($header + $body + $footer).Length
    $newLine = "$Key`: $Value"
    $pattern = "(?m)^$Key`:.*$"
    if ($body -match $pattern) {
        $body = [regex]::Replace($body, $pattern, { param($m) $newLine })
    } else {
        $body = "$body`n$newLine"
    }
    $rest = $Content.Substring($origSpanLength)
    return "$header$body$footer$rest"
}

# ---------------------------------------------------------------------------
# -SelfTest
# ---------------------------------------------------------------------------

if ($SelfTest) {
    $failures = [System.Collections.Generic.List[string]]::new()

    function Assert-Lane([string]$Case, [string]$Name, [hashtable]$Fm, [string]$Body, [string]$Expected) {
        $r = Resolve-Lane $Name $Fm $Body
        if ($r.lane -ne $Expected) {
            $failures.Add("$Case`: expected lane '$Expected', got '$($r.lane)' (gates: $($r.gates.Keys | ForEach-Object { "$_=$($r.gates[$_].result)" } | Join-String -Separator ', '))")
        }
    }

    $nl = [Environment]::NewLine
    $b1 = (@('## Done when', '- [ ] dishes are done', '- [ ] kitchen counter clear') -join $nl)
    $b2 = (@('## Done when', '- [ ] payment of `$60` confirmed', '- [ ] receipt saved to `receipts/2026-09.pdf`') -join $nl)
    $b3 = (@('## Done when', '- [ ] logo chosen', '- [ ] {{OPERATOR_NAME}} approves') -join $nl)
    $b4 = (@('## Done when', '- [ ] `scripts/Detect-Drift.ps1` shows 0 broken links', '- [ ] `wiki/index.md` has no 404s', '- [ ] link count logged in `logs/sync.log`') -join $nl)
    $b5 = (@('## Done when', '- [ ] `src/auth.ts` returns 200 for valid tokens', '- [ ] `src/session.ts` exits 0 on `npm test`') -join $nl)

    $bN = (@('## Done when', '- [ ] `config.json` holds the new value', '- [ ] `pwsh -File scripts/Check.ps1` exits 0', '- [ ] status shows ok') -join $nl)
    Assert-Lane 'dresser chore' 'Organize and swap bedroom dressers' @{ effort = 'Medium'; energy_type = 'Admin' } $bN 'operator'
    Assert-Lane 'key rotation' 'Rotate Scribe Groq and Gemini API keys' @{ effort = 'Low'; energy_type = 'Admin' } $bN 'draft'
    Assert-Lane 'protected root' 'Update AGENTS.md rule 14 wording' @{ effort = 'Low'; energy_type = 'Admin' } $bN 'draft'
    Assert-Lane 'dishes chore' 'Do the dishes and clean the kitchen' @{ effort = 'Low'; energy_type = 'Quick Win' } $b1 'operator'
    Assert-Lane 'pay bill' 'Pay the internet bill' @{ effort = 'Low'; energy_type = 'Admin' } $b2 'draft'
    Assert-Lane 'open decision' 'Decide on the new logo direction' @{ effort = 'Medium'; energy_type = 'Strategic' } $b3 'grill'
    Assert-Lane 'link sweep' 'Sweep dead links in wiki' @{ effort = 'Low'; energy_type = 'Quick Win' } $b4 $(if ($script:HermesParked) { 'aios' } else { 'hermes' })
    Assert-Lane 'cc design pinned' 'Audit and redesign Command Center layout' @{ effort = 'Low'; energy_type = 'Quick Win' } $b4 'aios'
    Assert-Lane 'multi-file refactor' 'Refactor the auth module across the API layer' @{ effort = 'High'; energy_type = 'Deep Work' } $b5 'aios'

    if ($failures.Count -gt 0) {
        Write-Host "[FAIL] $($failures.Count) self-test assertion(s) failed:" -ForegroundColor Red
        $failures | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        exit 1
    }
    Write-Host "[PASS] Test-TaskGate self-test: 9/9 fixtures routed correctly." -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------
# Single-file mode
# ---------------------------------------------------------------------------

function Invoke-GateOnFile([string]$Path) {
    $content = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    $fm = Get-TaskFrontmatter $content
    $body = Get-TaskBody $content
    $name = if ($fm['name']) { $fm['name'] } else { [System.IO.Path]::GetFileNameWithoutExtension($Path) }
    $r = Resolve-Lane $name $fm $body
    return @{
        file    = [System.IO.Path]::GetFileName($Path)
        lane    = $r.lane
        unclear = $r.unclear
        gates   = $r.gates
        fm      = $fm
    }
}

$tasksDir = Join-Path $RepoPath 'tasks'

if ($Report) {
    $files = @(Get-ChildItem -LiteralPath $tasksDir -Filter '*.md' | Where-Object { $_.Name -ne 'tasks-index.md' })
    $groups = @{}
    foreach ($f in $files) {
        $content = Get-Content -LiteralPath $f.FullName -Raw -Encoding utf8
        $fm = Get-TaskFrontmatter $content
        if ($fm['status'] -ne 'Done') { continue }
        $lane = if ($fm['lane']) { $fm['lane'] } else { 'none' }
        $energy = if ($fm['energy_type']) { $fm['energy_type'] } else { 'none' }
        $bounces = 0
        if ($fm['bounces'] -and [int]::TryParse($fm['bounces'], [ref]$bounces)) { } else { $bounces = 0 }
        foreach ($key in @("lane:$lane", "energy_type:$energy")) {
            if (-not $groups.ContainsKey($key)) { $groups[$key] = @{ total = 0; bounced = 0 } }
            $groups[$key].total++
            if ($bounces -gt 0) { $groups[$key].bounced++ }
        }
    }
    Write-Host "=== Delegation Gate Report ===" -ForegroundColor Cyan
    foreach ($key in ($groups.Keys | Sort-Object)) {
        $g = $groups[$key]
        $rate = if ($g.total -gt 0) { [Math]::Round(100 * $g.bounced / $g.total, 1) } else { 0 }
        $flag = if ($g.total -ge 5 -and $rate -gt 10) { '  <-- DEMOTE TO grill' } else { '' }
        Write-Host ("  {0,-24} done={1,-4} bounced={2,-4} rate={3}%{4}" -f $key, $g.total, $g.bounced, $rate, $flag)
    }
    exit 0
}

if ($All) {
    $files = @(Get-ChildItem -LiteralPath $tasksDir -Filter '*.md' | Where-Object {
        $_.Name -ne 'tasks-index.md' -and $_.DirectoryName -notmatch '_staged'
    })
    $laneCounts = @{}
    $changed = 0
    $queued = 0
    $flipTrueToFalse = 0
    $flipFalseToTrue = 0

    foreach ($f in $files) {
        $content = Get-Content -LiteralPath $f.FullName -Raw -Encoding utf8
        $fm = Get-TaskFrontmatter $content
        if ($fm['status'] -eq 'Done') { continue }

        $res = Invoke-GateOnFile $f.FullName
        $laneCounts[$res.lane] = ($laneCounts[$res.lane] ?? 0) + 1

        if (-not $Apply) {
            Write-Host "$($res.file): lane=$($res.lane) unclear=$($res.unclear)"
            continue
        }

        if ($res.unclear) {
            $reviewPath = Join-Path $tasksDir '_staged/review-queue.md'
            $failing = ($res.gates.Keys | Where-Object { $res.gates[$_].result -ne 'pass' } | ForEach-Object { "$_`: $($res.gates[$_].reason)" }) -join '; '
            $entry = "`n## [ ] [GATE] $($res.file) -> proposed lane $($res.lane) ($(Get-Date -Format 'yyyy-MM-dd'))`n- failing gates: $failing`n"
            Add-Content -LiteralPath $reviewPath -Value $entry -Encoding utf8
            $queued++
            continue
        }

        if ($fm['lane'] -and -not $Force) { continue }

        $newAutonomous = 'false'
        $hasBlockedBy = $content -match '(?m)^blocked_by:\s*\r?\n\s*-\s*\S'
        if ($res.lane -in @('hermes', 'aios') -and -not $hasBlockedBy) {
            if ($fm['scope'] -eq 'structural' -or $fm['autonomous'] -eq 'true') {
                $newAutonomous = 'true'
            }
        }
        $oldAutonomous = if ($fm['autonomous']) { $fm['autonomous'] } else { 'false' }
        if ($oldAutonomous -eq 'true' -and $newAutonomous -eq 'false') { $flipTrueToFalse++ }
        if ($oldAutonomous -eq 'false' -and $newAutonomous -eq 'true') { $flipFalseToTrue++ }

        $newContent = Set-FrontmatterField $content 'lane' "`"$($res.lane)`""
        $newContent = Set-FrontmatterField $newContent 'autonomous' $newAutonomous
        # Lane metadata is not a touch: last_touched stays the staleness signal (task-health-sweep retire bucket).
        Set-Content -LiteralPath $f.FullName -Value $newContent -Encoding utf8 -NoNewline
        $changed++
    }

    Write-Host "`n=== Delegation Gate: -All$(if ($Apply) { ' -Apply' }) ===" -ForegroundColor Cyan
    foreach ($lane in ($laneCounts.Keys | Sort-Object)) {
        Write-Host "  $lane`: $($laneCounts[$lane])"
    }
    if ($Apply) {
        Write-Host "Changed: $changed | Queued to review: $queued | autonomous true->false: $flipTrueToFalse | false->true: $flipFalseToTrue" -ForegroundColor Yellow
    }
    exit 0
}

if (-not $TaskFile) {
    throw "Specify -TaskFile, -All, -Report, or -SelfTest."
}

$path = if (Test-Path -LiteralPath $TaskFile) { $TaskFile } else { Join-Path $tasksDir $TaskFile }
if (-not (Test-Path -LiteralPath $path)) { throw "Task file not found: $path" }

$res = Invoke-GateOnFile $path
$out = [ordered]@{
    file    = $res.file
    lane    = $res.lane
    unclear = $res.unclear
    gates   = [ordered]@{}
}
foreach ($k in $res.gates.Keys) { $out.gates[$k] = $res.gates[$k] }
$out | ConvertTo-Json -Depth 5
