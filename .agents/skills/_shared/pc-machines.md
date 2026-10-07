# Machine Identity & Hardware Reference: {{AIOS_NAME}}

<!-- First-Run Self-Calibration Protocol: -->
<!-- When any PC skill (pc-systems-engineer, game-optimization, windows-debloat) is first invoked in {{AIOS_NAME}}, -->
<!-- Claude must run live PowerShell discovery commands, detect the user's real hardware specs, -->
<!-- replace all {{...}} placeholders in this file, and save memory/pc-system-profile.md. -->

## First-Run Hardware Auto-Discovery Protocol
If the table below still contains `{{...}}` placeholders, Claude must automatically execute this PowerShell block:
```powershell
Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, OSArchitecture
Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed
Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, AdapterRAM
Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum | ForEach-Object { "$([math]::Round($_.Sum / 1GB)) GB" }
Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter, FileSystemLabel, SizeRemaining, Size
```
Extract the exact values, replace the placeholders in this file, and write `memory/pc-system-profile.md`.

---

## Machine Identity: Stable Baseline

| Property | Primary Workstation / Desktop | Secondary Machine / Laptop |
|---|---|---|
| Model | {{PC_MODEL}} | {{LAPTOP_MODEL}} |
| CPU | {{CPU_MODEL}} | {{LAPTOP_CPU}} |
| GPU | {{GPU_MODEL}} | {{LAPTOP_GPU}} |
| RAM | {{RAM_CAPACITY_AND_SPEED}} | {{LAPTOP_RAM}} |
| Storage Volumes | {{STORAGE_VOLUMES}} | {{LAPTOP_STORAGE}} |
| OS Version | {{OS_VERSION_BUILD}} | {{LAPTOP_OS}} |
| Primary Display | {{DISPLAY_RESOLUTION_REFRESH}} | {{LAPTOP_DISPLAY}} |
| Power Plan | {{POWER_PLAN}} | {{LAPTOP_POWER_PLAN}} |

---

## Operating Invariants
1. **Diagnose before prescribing:** Always gather live metrics (GPU load, storage reliability, event logs) before modifying settings.
2. **Risk-gate every change:**
   - 🟢 Safe, reversible, read-only: apply directly.
   - 🟡 System settings, registry, services, drivers: explain and confirm first.
   - 🔴 Security, kernel, firmware, anti-cheat trade-offs: require explicit confirmation, never batch.
3. **Verify with a number:** Record before and after metrics for every optimization applied. If no gain is measured, revert the change.
