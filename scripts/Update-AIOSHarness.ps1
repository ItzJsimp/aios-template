#Requires -Version 7.0
<#
.SYNOPSIS
    Add the Leonidas Code operating layer to an existing AIOS, preserving personal files.
.DESCRIPTION
    Run with -WhatIf first. Changed instruction files receive timestamped backups.
    Copies shared instructions and adds a managed section to AGENTS.md and an
    import to CLAUDE.md. Does not install accounts, modify memory, or run agents.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$AiosRoot,
    [string]$SourceRoot = (Join-Path $PSScriptRoot '..')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$target = (Resolve-Path -LiteralPath $AiosRoot).Path
$source = (Resolve-Path -LiteralPath $SourceRoot).Path
$agentsPath = Join-Path $target 'AGENTS.md'
if (-not (Test-Path -LiteralPath $agentsPath -PathType Leaf)) { throw "No AGENTS.md at $target" }
$overlayRel = '.agents/rules/aios-code-overlay.md'
$overlayPath = Join-Path $source $overlayRel
if (-not (Test-Path -LiteralPath $overlayPath -PathType Leaf)) { throw "Missing shared operating layer: $overlayPath" }
$backup = Join-Path $target ('.aios-backups/harness-' + (Get-Date -Format 'yyyyMMdd-HHmmss-ffff'))
$writes = 0
function Set-MigratedFile([string]$RelativePath, [string]$Content) {
    $path = Join-Path $target $RelativePath
    $old = if (Test-Path -LiteralPath $path -PathType Leaf) { [IO.File]::ReadAllText($path) } else { $null }
    if ($old -ceq $Content) { return }
    if ($PSCmdlet.ShouldProcess($path, 'Back up existing file and write Leonidas Code instructions')) {
        if ($null -ne $old) {
            $save = Join-Path $backup $RelativePath
            New-Item -ItemType Directory -Path (Split-Path -Parent $save) -Force | Out-Null
            [IO.File]::WriteAllText((Join-Path $target '.aios-backups/.gitignore'), "*`n")
            Copy-Item -LiteralPath $path -Destination $save
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
        [IO.File]::WriteAllText($path, $Content, [Text.UTF8Encoding]::new($false))
        $script:writes++
    }
}
Set-MigratedFile $overlayRel ([IO.File]::ReadAllText($overlayPath))
$resident = @('memory/core.md', 'memory/soul.md', 'modes/router.md') |
    Where-Object { Test-Path -LiteralPath (Join-Path $target $_) -PathType Leaf } |
    ForEach-Object { "[$_]('./$_')".Replace("'", '') }
$section = @"
<!-- aios-code-harness:start -->
## Current workspace: Leonidas Code

Use Leonidas Code as the daily harness. This section supersedes older standalone
Claude Code, Clio and Antigravity frontend workflow advice in this AIOS.
Before acting, read the [shared operating layer](./$overlayRel) and resident
canon: $($resident -join ', '). Follow core's pointer to this user's full profile.
CLAUDE.md and provider discovery folders remain runtime compatibility adapters.
Provider availability and account selection come from the running app.
Keep this user's private memory, tasks and project code in their existing homes.
<!-- aios-code-harness:end -->
"@
$agents = [IO.File]::ReadAllText($agentsPath)
$pattern = '(?s)<!-- aios-code-harness:start -->.*?<!-- aios-code-harness:end -->'
if ($agents -match $pattern) {
    $agents = [regex]::Replace($agents, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($m) $section.TrimEnd() })
} else { $agents = $agents.TrimEnd() + "`n`n" + $section.TrimEnd() + "`n" }
Set-MigratedFile 'AGENTS.md' $agents
$claudePath = Join-Path $target 'CLAUDE.md'
$claude = if (Test-Path -LiteralPath $claudePath) { [IO.File]::ReadAllText($claudePath) } else { "@AGENTS.md`n" }
$import = '@' + $overlayRel
if ($claude -notmatch ('(?m)^' + [regex]::Escape($import) + '\s*$')) { $claude = $claude.TrimEnd() + "`n$import`n" }
Set-MigratedFile 'CLAUDE.md' $claude
if (Test-Path -LiteralPath (Join-Path $target '.claude/claude-overlay.md')) {
    Set-MigratedFile '.claude/claude-overlay.md' "# Claude provider compatibility`n`nUse the [shared operating layer](../$overlayRel) in Leonidas Code.`n"
}
Write-Host "Updated $writes instruction files. Personal memory and project files were not modified."
if ($writes) { Write-Host "Backups: $backup" }
Write-Host 'Open this AIOS in Leonidas Code and verify its identity in a fresh session for each connected provider.'
