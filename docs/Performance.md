**Performance Report**

**Before Optimization (baseline)**
- Device: RTX 3050 Ti laptop GPU, Godot 4.5.1 (user-provided console log)
- Scenario: default 1000 agents, density grid 128x128, memory grid 96x96, zones 0–1
- FPS observed: ~19–76 fps (most lines stabilized ~21–26 fps)
- Tick time (simulation): ~29–36 ms (peaks ~45 ms early in run)
- Render time (last draw): ~6.6–7.9 ms

**Likely hot paths (from code + baseline)**
- Simulation step dominates frame budget (tick_ms >> render_ms).
- Neighbor search + steering per agent: `scripts/swarm_model.gd` `_build_grid()`, `_get_neighbors()`, `PhaseRules.compute_steering()`.
- Memory decay + diffusion: full-grid pass each tick in `_apply_memory_decay()` + `_apply_memory_diffusion()`.
- Density deposit kernel per agent: `_deposit_density_at()` when density enabled.
- Rendering per-agent draw + density glow: `render/swarm_renderer.gd` `_draw()` and `_draw_density_glow()`.

**Notes**
- Baseline is at 1000 agents; target is 5k. Subsequent measurements will target 5k where possible.
