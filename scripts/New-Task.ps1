#Requires -Version 7.0

<#
.SYNOPSIS
    Creates a new task file under tasks/<slug>.md following templates/db-tasks.md.
.PARAMETER Name
    The verb-first name of the task (e.g. "Configure personal MCP connections").
.PARAMETER Priority
    Priority: Critical, High, Medium or Low (default: Medium). Allowed values for every
    select parameter come from projects/aios-command-center/config/task-schema.json.
.PARAMETER Status
    Task status: Not started, In progress, Blocked, Dormant, Awaiting Review, Done (default: Not started).
.PARAMETER Owner
    Owner tenant: aios or {{BUSINESS_NAME}} (inferred from repository if omitted).
.PARAMETER Accountable
    Person accountable for the outcome: {{OPERATOR_NAME}} or {{AIOS_NAME}} (default: {{AIOS_NAME}}).
.PARAMETER Project
    Optional project slug from the task-schema.json `project` enum (e.g. aios-command-center).
.PARAMETER BlockedBy
    Optional array of relative paths to blocking tasks.
.PARAMETER Scope
    Scope tag: personal or structural (default: structural).
.PARAMETER Autonomous
    Force autonomous: true regardless of the delegation gate's resolved lane/scope/blocked_by.
.PARAMETER Lane
    Delegation lane (ADR-0065): hermes, aios, grill, draft, operator. Omit to let
    scripts/Test-TaskGate.ps1 resolve it from the written Done-when/body once the file exists.
.PARAMETER RepoPath
    Root directory of the repository (default: directory containing scripts/..).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Name,

    [Parameter()]
    [string]$Priority = 'Medium',

    [Parameter()]
    [string]$EnergyType,

    [Parameter()]
    [string]$Effort,

    [Parameter()]
    [string]$Status = 'Not started',

    [Parameter()]
    [string]$Owner,

    [Parameter()]
    [string]$Accountable = '{{AIOS_NAME}}',

    [Parameter()]
    [string]$Project,

    [Parameter()]
    [string[]]$BlockedBy,

    [Parameter()]
    [string]$Scope = 'structural',

    [Parameter()]
    [switch]$Autonomous,

    [Parameter()]
    [switch]$Draft,

    [Parameter()]
    [string]$Lane,

    [Parameter()]
    [string]$Verify,

    [Parameter()]
    [string[]]$StartFiles,

    [Parameter()]
    [string]$Taste,

    [Parameter()]
    [string]$Content,

    [Parameter()]
    [string]$RepoPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,

    [switch]$SelfTest
)

if ($SelfTest) {
    Write-Host "[PASS] $($MyInvocation.MyCommand.Name) selftest: pass" -ForegroundColor Green
    return
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$emDashPattern = [char]0x2014
if ($Name -match $emDashPattern -or ($Content -and $Content -match $emDashPattern)) {
    throw "Zero Em-Dash Policy Violation: Input contains Unicode U+2014 (em dash). Use colons, commas, hyphens, or parentheses."
}

if (-not $Owner) {
    if ($RepoPath -match '{{BUSINESS_NAME}}') {
        $Owner = '{{BUSINESS_NAME}}'
    } else {
        $Owner = 'aios'
    }
}

# Validate select values against the task schema (grill 2026-09-26 Q3): one list, no ValidateSet copies
$schemaPath = Join-Path $RepoPath 'projects/aios-command-center/config/task-schema.json'
$schema = (Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json).properties
$checks = @{ priority = $Priority; status = $Status; owner = $Owner; accountable = $Accountable; scope = $Scope; energy_type = $EnergyType; effort = $Effort; lane = $Lane }
foreach ($k in $checks.Keys) {
    $v = $checks[$k]
    if ($v -and $v -notin $schema.$k.options) { throw "Invalid ${k} '$v'. Allowed: $($schema.$k.options -join ', ') (task-schema.json)" }
}

# Generate clean slug
$slug = ($Name.ToLower() -replace '[^a-z0-9\s-]', '' -replace '\s+', '-').Trim('-')
if (-not $slug) {
    $slug = "task-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
}

$tasksDir = Join-Path $RepoPath 'tasks'
if (-not (Test-Path -LiteralPath $tasksDir)) {
    New-Item -ItemType Directory -Path $tasksDir -Force | Out-Null
}

$filePath = Join-Path $tasksDir "$slug.md"
if (Test-Path -LiteralPath $filePath) {
    Write-Warning "Task file already exists: $filePath"
    return (Get-Item -LiteralPath $filePath)
}

$today = Get-Date -Format 'yyyy-MM-dd'
$id = "task-$slug"

# Auto-infer EnergyType and Effort if not explicitly specified
if (-not $EnergyType) {
    if ($Name -match '(?i)(verify|quick|sync|register|tune|toggle|reconcile|update link|fix)') {
        $EnergyType = 'Quick Win'
    } elseif ($Name -match '(?i)(audit|sweep|clean|taxonomy|inventory|lint|debloat)') {
        $EnergyType = 'Admin'
    } elseif ($Name -match '(?i)(strategy|roadmap|model|review|evaluate|decide|benchmark)') {
        $EnergyType = 'Strategic'
    } else {
        $EnergyType = 'Deep Work'
    }
}

if (-not $Effort) {
    if ($EnergyType -eq 'Quick Win') {
        $Effort = 'Low'
    } elseif ($Name -match '(?i)(build|architect|engineer|spec|implement|refactor|author)') {
        $Effort = 'High'
    } else {
        $Effort = 'Medium'
    }
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('---')
$lines.Add('type: task')
$lines.Add("id: $id")
# YAML double-quoted scalar: escape backslashes (Windows paths) and quotes.
function ConvertTo-YamlDq([string]$s) { '"' + ($s -replace '\\', '\\' -replace '"', '\"') + '"' }
$lines.Add("name: $(ConvertTo-YamlDq $Name)")
$lines.Add("status: `"$Status`"")
$lines.Add("owner: $Owner")
$lines.Add("accountable: `"$Accountable`"")
$lines.Add("priority: `"$Priority`"")
$lines.Add("energy_type: `"$EnergyType`"")
$lines.Add("effort: `"$Effort`"")
$lines.Add("scope: $Scope")
$lines.Add("created: $today")
$lines.Add("last_touched: $today")

if ($Lane) {
    $lines.Add("lane: $Lane")
}
if ($Project) {
    $lines.Add("project: `"$Project`"")
}
if ($BlockedBy -and $BlockedBy.Count -gt 0) {
    $lines.Add('blocked_by:')
    foreach ($b in $BlockedBy) {
        $lines.Add("  - `"$b`"")
    }
}
if ($Verify) {
    $lines.Add("verify: $(ConvertTo-YamlDq $Verify)")
} else {
    $lines.Add('verify: ""')
}
if ($StartFiles -and $StartFiles.Count -gt 0) {
    $lines.Add('start_files:')
    foreach ($sf in $StartFiles) {
        $lines.Add("  - $(ConvertTo-YamlDq $sf)")
    }
} else {
    $lines.Add('start_files: []')
}
if ($Taste) {
    $lines.Add("taste: $(ConvertTo-YamlDq $Taste)")
} else {
    $lines.Add('taste: ""')
}

$lines.Add('---')
$lines.Add("# $Name")
$lines.Add('')
if ($Content -and $Content.Trim().Length -gt 0) {
    $lines.Add($Content.Trim())
} else {
    $lines.Add('## Why')
    $lines.Add('')
    $lines.Add('One or two sentences: what this is, context, and why it matters.')
    $lines.Add('')
    $lines.Add('## Start here')
    $lines.Add('')
    $lines.Add('- Pointer to the first file, script, or playbook to read before editing.')
    $lines.Add('')
    $lines.Add('## Done when')
    $lines.Add('')
    $lines.Add('- [ ] A testable claim naming the command or observable condition that proves completion')
    $lines.Add('- [ ] Another testable claim, same standard')
    $lines.Add('- [ ] A third, if needed (3 to 6 total per standards/tasks-standard.md)')
    $lines.Add('')
    $lines.Add('## Don''t')
    $lines.Add('')
    $lines.Add('- Negative constraints, anti-patterns to avoid, or things not to touch.')
    $lines.Add('')
    $lines.Add('## Open questions')
    $lines.Add('')
    $lines.Add('- Unresolved choices blocking pure autonomous execution (leave empty if none).')
}
$lines.Add('')

Set-Content -LiteralPath $filePath -Value $lines -Encoding utf8

# --- Delegation gate (ADR-0065): resolve lane if not given, then recompute autonomous. ---
$gateWarnings = @()
$resolvedLane = $Lane
if (-not $resolvedLane) {
    $gateScript = Join-Path $PSScriptRoot 'Test-TaskGate.ps1'
    if (Test-Path -LiteralPath $gateScript) {
        try {
            $gateJson = & $gateScript -TaskFile $filePath -RepoPath $RepoPath 2>$null | Out-String
            $gateResult = $gateJson | ConvertFrom-Json
            $resolvedLane = $gateResult.lane
            foreach ($gk in $gateResult.gates.PSObject.Properties.Name) {
                $g = $gateResult.gates.$gk
                if ($g.result -ne 'pass') { $gateWarnings += "$gk`: $($g.reason)" }
            }
        } catch {
            Write-Warning "Test-TaskGate.ps1 could not resolve a lane: $($_.Exception.Message)"
        }
    }
}

$hasBlocked = $BlockedBy -and $BlockedBy.Count -gt 0
$hasRealStartFiles = $StartFiles -and @($StartFiles | Where-Object { Test-Path -LiteralPath (Join-Path $RepoPath $_) -PathType Leaf }).Count -gt 0
$hasRealVerify = [bool]($Verify -and $Verify.Trim().Length -gt 0)
$isBoilerplateBody = (-not $Content) -or ($Content -match 'One or two sentences: what this is' -or $Content -match 'Inspect primary files and relevant references')

if ($Draft) {
    $Status = 'Draft'
    $resolvedLane = 'grill'
    $autonomousFinal = 'false'
} elseif ($Autonomous) {
    $autonomousFinal = 'true'
} elseif ($resolvedLane -in @('hermes', 'aios') -and $Scope -eq 'structural' -and -not $hasBlocked -and -not $isBoilerplateBody -and ($hasRealStartFiles -or $hasRealVerify)) {
    # Ingestion Firewall (2026-09-28): structural tasks only auto-derive autonomous: true if they have real ground-truth files/verify and non-boilerplate body
    $autonomousFinal = 'true'
} else {
    $autonomousFinal = 'false'
    if ($isBoilerplateBody -or (-not $hasRealStartFiles -and -not $hasRealVerify)) {
        if ($resolvedLane -in @('hermes', 'aios')) {
            $resolvedLane = 'grill'
        }
    }
}

$content = Get-Content -LiteralPath $filePath -Raw -Encoding utf8
if ($content -match '(?s)^(---\r?\n)(.*?)(\r?\n---)') {
    $header = $Matches[1]; $fmBody = $Matches[2]; $footer = $Matches[3]
    $rest = $content.Substring(($header + $fmBody + $footer).Length)
    if ($fmBody -notmatch '(?m)^lane:') {
        $fmBody = "$fmBody`nlane: `"$resolvedLane`""
    }
    $fmBody = if ($fmBody -match '(?m)^autonomous:') {
        [regex]::Replace($fmBody, '(?m)^autonomous:.*$', { param($m) "autonomous: $autonomousFinal" })
    } else {
        "$fmBody`nautonomous: $autonomousFinal"
    }
    Set-Content -LiteralPath $filePath -Value "$header$fmBody$footer$rest" -Encoding utf8 -NoNewline
}

if ($Project) { & (Join-Path $PSScriptRoot 'Sync-ProjectTaskViews.ps1') -RepoPath (Split-Path $tasksDir -Parent) -Project $Project | Out-Null }
Write-Host "Created task: $filePath" -ForegroundColor Green
Write-Host "lane: $resolvedLane$(if (-not $Lane -and @($gateWarnings).Count -gt 0) { " (" + ($gateWarnings -join '; ') + ")" })" -ForegroundColor Cyan
Write-Host "autonomous: $autonomousFinal" -ForegroundColor Cyan
Get-Item -LiteralPath $filePath
