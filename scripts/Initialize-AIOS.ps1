#Requires -Version 7.0
<#
.SYNOPSIS
    Turns the AIOS template into the operator's own AIOS: copies to REPO_PATH, fills every
    {{PLACEHOLDER}} from an answers JSON, git-inits, and links skills. Idempotent.
.EXAMPLE
    pwsh -NoProfile -File scripts/Initialize-AIOS.ps1 -AnswersFile onboarding-answers.json
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$AnswersFile, [switch]$ScheduleWeeklyReview)

$ErrorActionPreference = "Stop"
$Template = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$Answers = Get-Content -LiteralPath $AnswersFile -Raw | ConvertFrom-Json -AsHashtable
foreach ($k in "AIOS_NAME", "OPERATOR_NAME", "REPO_PATH") {
    if (-not $Answers[$k]) { throw "Missing required answer: $k" }
}
if (-not $Answers.USER_HOME) { $Answers.USER_HOME = $HOME }
if (-not $Answers.MACHINE_NAME) { $Answers.MACHINE_NAME = $env:COMPUTERNAME }
if (-not $Answers.DATA_DRIVE) { $Answers.DATA_DRIVE = [IO.Path]::GetPathRoot($Answers.REPO_PATH).TrimEnd('\', '/') }

$Target = [IO.Path]::GetFullPath($Answers.REPO_PATH)
if ($Target -ne $Template) {
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
    # /XC /XN /XO: never overwrite a file that already exists at the target
    robocopy $Template $Target /E /XC /XN /XO /XD .git /XF onboarding-answers.json /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }
}

$slug = ($Answers.AIOS_NAME.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
$askOld = Join-Path $Target ".agents\skills\ask-aios"
$askNew = Join-Path $Target ".agents\skills\ask-$slug"
if ((Test-Path -LiteralPath $askOld) -and -not (Test-Path -LiteralPath $askNew)) { Rename-Item -LiteralPath $askOld -NewName "ask-$slug" }

$textExt = '.md', '.ps1', '.py', '.json', '.txt', '.tsx', '.ts', '.css', '.yml', '.yaml', '.toml', '.html', '.js'
$changed = 0
Get-ChildItem -LiteralPath $Target -Recurse -File | Where-Object { $_.Extension -in $textExt -and $_.FullName -notmatch '\\\.git\\' } | ForEach-Object {
    $raw = [IO.File]::ReadAllText($_.FullName)
    $new = $raw.Replace('ask-aios', "ask-$slug")
    foreach ($k in $Answers.Keys) {
        $v = [string]$Answers[$k]
        if ($_.Extension -eq '.json') { $v = ($v | ConvertTo-Json).Trim('"') }  # escape backslashes in JSON
        $new = $new.Replace("{{$k}}", $v)
    }
    if ($new -ne $raw) { [IO.File]::WriteAllText($_.FullName, $new); $changed++ }
}
Write-Host "[OK] Filled placeholders in $changed files at $Target" -ForegroundColor Green

$sync = Join-Path $Target "scripts\Sync-AgentSkills.ps1"
if (Test-Path -LiteralPath $sync) { pwsh -NoProfile -File $sync -RepoRoot $Target }

# Optional scheduling: opt in explicitly after reviewing the cadence.
if ($ScheduleWeeklyReview) {
try {
    $review = Join-Path $Target "scripts\Run-WeeklyOperatorReview.ps1"
    $reg = Join-Path $Target "scripts\New-AiosScheduledTask.ps1"
    if ((Test-Path -LiteralPath $review) -and (Test-Path -LiteralPath $reg)) {
        pwsh -NoProfile -File $reg -TaskName "AIOS-Weekly-OperatorReview" -ScriptPath $review -ScriptArguments "-NoJudge" -TriggerType Weekly -DaysOfWeek Sunday -At "9:00PM"
        Write-Host "[OK] Weekly operator scorecard scheduled (Sundays 9 PM)." -ForegroundColor Green
    }
} catch { Write-Warning "Could not schedule the weekly scorecard ($($_.Exception.Message)); run scripts\Run-WeeklyOperatorReview.ps1 weekly by hand." }

}

# Cloned straight from the template repo: keep its history, but pushes must never go back to it.
if ((Test-Path -LiteralPath (Join-Path $Target ".git")) -and (git -C $Target remote get-url origin 2>$null) -like 'https://github.com/ItzJsimp/aios-template*') {
    git -C $Target remote rename origin template
    Write-Host "[OK] Template remote renamed to 'template' (pull updates: git pull template main)." -ForegroundColor Green
}

if (-not (Test-Path -LiteralPath (Join-Path $Target ".git"))) { git -C $Target init -q }
git -C $Target add -A
if (git -C $Target status --porcelain) {
    git -C $Target commit -q -m "Build: initialize $($Answers.AIOS_NAME) from the AIOS template"
    if ($LASTEXITCODE) { Write-Warning "Commit failed (exit $LASTEXITCODE); run 'git commit' in $Target manually." }
    else { Write-Host "[OK] Personalization committed to git." -ForegroundColor Green }
}

$left = Get-ChildItem -LiteralPath $Target -Recurse -File | Where-Object { $_.Extension -in $textExt -and $_.FullName -notmatch '\\\.git\\' } |
    Select-String -Pattern '\{\{([A-Z_]+)\}\}' -AllMatches -CaseSensitive | ForEach-Object { $_.Matches.Groups[1].Value } | Sort-Object -Unique
$hardware = $left | Where-Object { $_ -match 'LAPTOP|GPU|CPU|RAM|STORAGE|OS_VERSION|PC_MODEL|DISPLAY|POWER_PLAN|MOTHERBOARD|URL' }
$missing = $left | Where-Object { $_ -notin $hardware -and $_ -ne 'PLACEHOLDER' }
if ($hardware) { Write-Host "[INFO] Hardware placeholders left for the PC discovery step: $($hardware.Count)" }
if ($missing) { Write-Host "[TODO] Unfilled answers: $($missing -join ', ')" -ForegroundColor Yellow } else { Write-Host "[OK] All profile placeholders filled." -ForegroundColor Green }
