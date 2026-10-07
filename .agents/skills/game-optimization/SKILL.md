---
name: game-optimization
description: "Research and tune game engine settings, launch options, shader caches, and graphics benchmarks."
category: pc
scope: structural
disable-model-invocation: true
---

# Game Optimization Profile Builder

Evidence-first performance tuning. One page, one game, verified benchmarks only.

## First-Run Calibration
On first use, Claude inspects `.agents/skills/_shared/pc-machines.md` to confirm the user's active GPU and display refresh rate.

## Procedure
1. **Identify the Target:** Game title, engine (Unreal, Unity, proprietary), API (DirectX 11, DirectX 12, Vulkan).
2. **Baseline Assessment:**
   - Check user's native resolution and target FPS.
   - Inspect existing configuration files and in-game presets.
3. **Structured Optimization Ladder:**
   - Tier 1 (Engine Configs): Texture pools, shadow resolution, volumetric fog, post-processing.
   - Tier 2 (Launch Flags): Memory allocation, thread count, borderless vs exclusive fullscreen.
   - Tier 3 (Shader Cache & Driver Settings): Shader cache size, low-latency mode, Reflex, G-Sync/FreeSync sync caps (FPS cap = refresh rate - 3).
4. **Output Profile:** Save the game profile to `memory/games/<game-slug>.md` with exact before/after frame times and 1% lows.
