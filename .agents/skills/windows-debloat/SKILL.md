---
name: windows-debloat
description: "Inventory, audit, and clean Windows packages, background services, startup bloat, and telemetry."
category: pc
scope: structural
disable-model-invocation: true
---

# Windows Software Stack & Debloat Manager

Audit installed packages, clean startup load, manage background services, and eliminate telemetry bloat. Package manager of record is `winget`.

## First-Run Calibration
On first execution, Claude scans the local machine's startup applications and installed packages using:
```powershell
Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location
winget list
```

## Optimization Workflow
1. **Startup Trim:** Identify high-impact startup items. Categorize as Essential, Optional, or Bloat.
2. **Background Services Audit:** Audit non-Microsoft background services. Provide safe recommendations to disable or set to Manual.
3. **Pre-Installed App Cleanup:** Safely remove unneeded Windows consumer bloatware using `winget uninstall` or `Remove-AppxPackage`.
4. **Safety Gate:** Create a Windows restore point before applying bulk removals:
   ```powershell
   Checkpoint-Computer -Description "Pre-Debloat Baseline" -RestorePointType MODIFY_SETTINGS
   ```
