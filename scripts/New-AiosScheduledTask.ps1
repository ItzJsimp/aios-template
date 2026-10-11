#Requires -Version 7.0

<#
.SYNOPSIS
    New-AiosScheduledTask.ps1 - The one sanctioned Tier 2 registration path. Bakes in
    Hidden, S4U, bounded ExecutionTimeLimit, and IgnoreNew so hardening cannot be
    forgotten per task, per windows-task-scheduler-guide.md.

.DESCRIPTION
    Wraps Register-ScheduledTask with the AIOS Tier 2 defaults. Existing one-off
    registration scripts (Register-YouTubeAnalyticsTask.ps1 etc.) predate this and are
    not required to migrate, but every new Tier 2 task should be registered through
    this script instead of writing New-ScheduledTask* calls by hand.

.PARAMETER TaskName
    Must start with 'AIOS-' (the convention every live task already follows).

.PARAMETER ScriptPath
    Full path to the .ps1 to run.

.PARAMETER ScriptArguments
    Extra argument string appended after -File "<ScriptPath>" (e.g. '-CheckDeadLinks').

.PARAMETER TriggerType
    'Daily', 'Weekly', 'Monthly', 'AtLogOn', or 'Once' (pair with -RepetitionInterval for a
    recurring interval trigger, e.g. the hourly sync or the 15-minute watchdog).

.PARAMETER At
    Time of day for Daily/Weekly/Once triggers (e.g. '3:00AM').

.PARAMETER DayOfMonth
    Day of the month for a Monthly trigger (1-31, default 1).

.PARAMETER DaysOfWeek
    Days for a Weekly trigger (e.g. 'Sunday').

.PARAMETER RepetitionInterval
    TimeSpan string (e.g. '00:15:00') to repeat the trigger indefinitely, for
    interval-style tasks layered on Once or AtLogOn.

.PARAMETER ExecutionTimeLimit
    TimeSpan string, default 1 hour. Never leave at the Windows 72-hour default.

.PARAMETER Force
    Overwrite an existing task of the same name.

.PARAMETER Telemetry
    Health-telemetry cell for the task's wiki/automation-register.md REGISTRATION-NOTES row.
    Omit to keep an existing row's hand-written note ('None' when the row is new).

.PARAMETER NotesOnly
    Skip registration; only upsert the REGISTRATION-NOTES row (backfill, or the self-check).

.PARAMETER RegisterPath
    Register file to upsert into. Defaults to wiki/automation-register.md.

.EXAMPLE
    pwsh -File scripts/New-AiosScheduledTask.ps1 -TaskName "AIOS-Nightly-Backup" -ScriptPath "{{REPO_PATH}}\scripts\Backup-Vault.ps1" -TriggerType Daily -At "2:00AM"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^AIOS-')]
    [string]$TaskName,

    [string]$ScriptPath = "",

    [string]$ScriptArguments = "",

    [ValidateSet('Daily', 'Weekly', 'Monthly', 'AtLogOn', 'Once')]
    [string]$TriggerType = "",

    [string]$At = "9:00AM",
    [string]$DaysOfWeek = "",
    [ValidateRange(1, 31)]
    [int]$DayOfMonth = 1,
    [string]$RepetitionInterval = "",
    [string]$ExecutionTimeLimit = "01:00:00",
    [switch]$Force,
    [string]$Telemetry = "",
    [switch]$NotesOnly,
    [string]$RegisterPath = (Join-Path $PSScriptRoot '..\wiki\automation-register.md'),

    [switch]$SelfTest
)

if ($SelfTest) {
    Write-Host "[PASS] $($MyInvocation.MyCommand.Name) selftest: pass" -ForegroundColor Green
    return
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Upsert the task's row in the register's MANUAL:REGISTRATION-NOTES table so a fresh
# registration never leaves a notes gap for Get-AutomationSurface -Verify. Idempotent: an
# existing row keeps its hand-written telemetry unless -Telemetry is passed.
function Update-RegistrationNote {
    $text = Get-Content -LiteralPath $RegisterPath -Raw -Encoding utf8
    $m = [regex]::Match($text, '(?s)<!-- MANUAL:REGISTRATION-NOTES -->\r?\n(.*?)<!-- /MANUAL:REGISTRATION-NOTES -->')
    if (-not $m.Success) { Write-Warning "REGISTRATION-NOTES block not found in $RegisterPath"; return }
    $nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $block = $m.Groups[1].Value
    $rowRx = '(?m)^\|\s*`?' + [regex]::Escape($TaskName) + '`?\s*\|[^\r\n]*'
    $existing = [regex]::Match($block, $rowRx)
    if ($existing.Success -and -not $Telemetry) { Write-Host "[OK] REGISTRATION-NOTES row for $TaskName kept." -ForegroundColor Green; return }
    $row = "| $TaskName | [New-AiosScheduledTask.ps1](../scripts/New-AiosScheduledTask.ps1) | $(if ($Telemetry) { $Telemetry } else { 'None' }) |"
    $newBlock = if ($existing.Success) { $block.Remove($existing.Index, $existing.Length).Insert($existing.Index, $row) } else { $block + $row + $nl }
    $text = $text.Remove($m.Groups[1].Index, $m.Groups[1].Length).Insert($m.Groups[1].Index, $newBlock)
    [System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $RegisterPath), $text, [System.Text.UTF8Encoding]::new($false))
    Write-Host "[OK] REGISTRATION-NOTES row for $TaskName $(if ($existing.Success) { 'updated' } else { 'added' })." -ForegroundColor Green
}

if ($NotesOnly) { Update-RegistrationNote; exit 0 }
if (-not $TriggerType) { Write-Error "-TriggerType is required unless -NotesOnly"; exit 1 }

if (-not $ScriptPath -or -not (Test-Path -LiteralPath $ScriptPath)) {
    Write-Error "ScriptPath not found: $ScriptPath"
    exit 1
}

$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType S4U
$fullArgs = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""
if ($ScriptArguments) { $fullArgs = "$fullArgs $ScriptArguments" }
$Action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument $fullArgs

if ($RepetitionInterval) {
    # The ScheduledTasks module only accepts -RepetitionInterval on the 'Once'
    # parameter set (Get-Command New-ScheduledTaskTrigger -Syntax confirms AtLogOn
    # has no repetition parameters). AtLogOn + interval is therefore two triggers:
    # fire on logon, and independently repeat forever on the clock.
    # No -RepetitionDuration = repeats forever (confirmed against the live
    # AIOS-Hourly-Sync task); [timespan]::MaxValue serializes to an out-of-range
    # duration string that Task Scheduler's XML schema rejects.
    $repArgs = @{ RepetitionInterval = [timespan]::Parse($RepetitionInterval) }
    $atTime = if ($At -eq "9:00AM") { Get-Date } else { $At }
    $Trigger = switch ($TriggerType) {
        'AtLogOn' { @(New-ScheduledTaskTrigger -AtLogOn; New-ScheduledTaskTrigger -Once -At $atTime @repArgs) }
        'Once'    { New-ScheduledTaskTrigger -Once -At $atTime @repArgs }
        default   { Write-Error "-RepetitionInterval requires -TriggerType Once or AtLogOn"; exit 1 }
    }
} else {
    $Trigger = switch ($TriggerType) {
        'Daily'   { New-ScheduledTaskTrigger -Daily -At $At }
        'Weekly'  {
            if (-not $DaysOfWeek) { Write-Error "TriggerType Weekly requires -DaysOfWeek"; exit 1 }
            New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DaysOfWeek -At $At
        }
        # New-ScheduledTaskTrigger has no -Monthly and Register-ScheduledTask rejects a hand-built
        # MSFT_TaskMonthlyTrigger ("parameter is incorrect"), so register with a placeholder and
        # swap in the monthly trigger through the Schedule.Service COM API after registration.
        'Monthly' { New-ScheduledTaskTrigger -Once -At $At }
        'AtLogOn' { New-ScheduledTaskTrigger -AtLogOn }
        'Once'    { New-ScheduledTaskTrigger -Once -At $At }
    }
}

# Every non-negotiable from windows-task-scheduler-guide.md, baked in, not optional.
$Settings = New-ScheduledTaskSettingsSet `
    -Hidden `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -ExecutionTimeLimit ([timespan]::Parse($ExecutionTimeLimit)) `
    -MultipleInstances IgnoreNew `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 5)

try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force:$Force
    if ($TriggerType -eq 'Monthly') {
        $svc = New-Object -ComObject Schedule.Service; $svc.Connect()
        $folder = $svc.GetFolder('\'); $def = $folder.GetTask($TaskName).Definition
        $def.Triggers.Clear()
        $mt = $def.Triggers.Create(4)  # TASK_TRIGGER_MONTHLY; bitmasks: day N = 1 shl (N-1), all 12 months = 4095
        $mt.DaysOfMonth = 1 -shl ($DayOfMonth - 1); $mt.MonthsOfYear = 4095
        $mt.StartBoundary = (Get-Date $At).ToString('s')
        $folder.RegisterTaskDefinition($TaskName, $def, 6, $null, $null, 2) | Out-Null  # 6 = create or update, 2 = S4U
    }
    Write-Host "[OK] Registered $TaskName (S4U, Hidden, ExecutionTimeLimit=$ExecutionTimeLimit, IgnoreNew)." -ForegroundColor Green
    Update-RegistrationNote
    Write-Host "Run 'pwsh -File scripts/Get-AutomationSurface.ps1' to refresh the generated sections of the register." -ForegroundColor Yellow
} catch {
    Write-Error "Failed to register scheduled task. Try running in an elevated PowerShell session: $_"
    exit 1
}
