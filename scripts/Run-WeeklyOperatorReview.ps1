#Requires -Version 7.0
<#
.SYNOPSIS
    Weekly operator review: scorecard + frontier watch + efficiency-findings writer, one silent run.
.DESCRIPTION
    Writes logs/operator-scorecard.jsonl, logs/operator-scorecard-report.md and logs/frontier-watch.md.
    Also runs Watch-SelfEfficiency.ps1 -Once: that script had no scheduler entry, which is why
    logs/efficiency-findings.jsonl went dormant after 2026-09-26.
    The prompt judge tries local Ollama first, then openrouter/free on redacted excerpts; the key is
    read from -EnvFile, $env:AIOS_ENV_FILE or <repo>\.env when OPENROUTER_API_KEY is not already set.
#>
[CmdletBinding()]
param([switch]$NoJudge, [string]$EnvFile)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root

if (-not $env:OPENROUTER_API_KEY) {
    foreach ($candidate in @($EnvFile, $env:AIOS_ENV_FILE, (Join-Path $root '.env'))) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            $line = Select-String -LiteralPath $candidate -Pattern '^\s*OPENROUTER_API_KEY\s*=\s*(.+)$' | Select-Object -First 1
            if ($line) { $env:OPENROUTER_API_KEY = $line.Matches[0].Groups[1].Value.Trim().Trim('"').Trim("'"); break }
        }
    }
}

$judge = if ($NoJudge) { @() } else { @('--judge') }
python (Join-Path $PSScriptRoot 'score-operator.py') @judge
python (Join-Path $PSScriptRoot 'frontier-watch.py')
$watch = Join-Path $PSScriptRoot 'Watch-SelfEfficiency.ps1'
if (Test-Path -LiteralPath $watch) { pwsh -NoProfile -File $watch -Once -HoursBack 168 }
exit 0
