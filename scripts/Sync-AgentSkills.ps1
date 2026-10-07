#Requires -Version 7.0
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)
$SkillsSrc = Join-Path $RepoRoot ".agents\skills"
$ClaudeSkills = Join-Path $RepoRoot ".claude\skills"
if (-not (Test-Path $SkillsSrc)) { exit 1 }
if (-not (Test-Path $ClaudeSkills)) { New-Item -ItemType Directory -Path $ClaudeSkills -Force | Out-Null }
$Skills = Get-ChildItem -Directory $SkillsSrc | Where-Object { $_.Name -notlike '_*' }
$Linked = 0
foreach ($s in $Skills) {
    $target = Join-Path $ClaudeSkills $s.Name
    if (-not (Test-Path $target)) {
        try {
            New-Item -ItemType Junction -Path $target -Target $s.FullName -Force | Out-Null
            $Linked++
        } catch {
            Copy-Item -Path $s.FullName -Destination $target -Recurse -Force
            $Linked++
        }
    }
}
Write-Host "[OK] Linked $Linked skills into Claude Code (.claude\skills)." -ForegroundColor Green
