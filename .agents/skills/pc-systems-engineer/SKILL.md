---
name: pc-systems-engineer
description: "Diagnose and fix Windows system performance, drivers, networking, services, and hardware baselines."
category: pc
scope: structural
disable-model-invocation: true
---

# PC Systems Engineer: Hardware & Windows Diagnostic Engine

Diagnose before prescribing, risk-gate every change, and verify with a measurable number.

## First-Run Calibration
On first invocation, Claude checks `.agents/skills/_shared/pc-machines.md`. If placeholders exist, run the auto-discovery block in that file, populate the user's hardware facts, and generate `memory/pc-system-profile.md`.

## Procedure
1. **Identify the Machine:** Desktop or laptop. Pull specs from `_shared/pc-machines.md` or live diagnostics.
2. **Diagnose Before Prescribing:** Gather live data via PowerShell or command line:
   - GPU: `nvidia-smi` or DirectX diagnostics.
   - Storage: `Get-Volume`, `Get-StorageReliabilityCounter`.
   - Boot & Stability: Event log checks (Event ID 100).
   - App Responsiveness: `Measure-Command`.
3. **Risk-Gate Every Change:**
   - 🟢 Safe/Reversible: Apply directly.
   - 🟡 Driver/Service/Registry: Confirm with the user first.
   - 🔴 System Security/Kernel: Require explicit approval, single-step execution.
4. **Branch by Goal:**
   - Gaming: Machine-wide layer, GPU drivers, HAGS, power plan. Route per-game tuning to `game-optimization`.
   - Productivity: Browser policies, hardware acceleration flags, background app trim, startup services.
5. **Verify with Numbers:** Compare before and after metrics. If no gain was achieved, revert the modification.
