# PhaseWeave v3 Specification

This document defines the v3 interaction features and how they integrate with the existing v2 simulation loop. It does not implement behavior.

---

## v3 Overview

New v3 features:

1) Force Memory Field: agents deposit force memory into a decaying grid that biases steering.
2) Zone Interference & Blending: overlapping attract/repel zones combine smoothly (capped sum).
3) Density Glow Overlay: toggleable visualization (green = low density, red = high density) that affects the black background only.

Design constraints remain unchanged:
- Agents are data, not Nodes.
- No per-agent _process() calls.
- One centralized simulation loop.
- Deterministic given RNG seed.

---

## Data Model — Memory Field

### Grid & Resolution
- Grid resolution: 128 x 128 (low-res).
- Grid bounds: same world bounds as the agent simulation area.
- World-to-grid mapping:
  - Normalize agent position into [0, 1] based on simulation bounds.
  - Map to grid indices via floor(pos_normalized * grid_size), clamped to [0, grid_size - 1].

### Stored Data
- memory_grid: float[grid_w][grid_h]
  - Units: abstract memory strength.
  - Range: clamped to [0, memory_max].

### Parameters (config.gd)
- memory_grid_size: Vector2i = (128, 128)
- memory_max: float
- memory_deposit_per_unit: float (per unit distance)
- memory_decay_rate: float (exponential)
- memory_force_strength: float
- memory_sample_radius_cells: int (optional smoothing radius)

---

## Memory Field Update Rules

### Deposit (per distance traveled)
- For each agent, compute distance_traveled in the tick (length of delta position).
- Deposit amount = distance_traveled * memory_deposit_per_unit.
- Deposit into the grid cell under the agent's current position.
- Optional: if smoothing is desired, distribute deposit into nearby cells with a simple kernel.

### Decay (exponential)
- Every tick, apply exponential decay:
  - memory_grid[x][y] *= exp(-memory_decay_rate * dt)
- After decay, clamp:
  - memory_grid[x][y] = min(memory_grid[x][y], memory_max)

### Clamping
- Always clamp to [0, memory_max] after deposit and decay.

---

## Memory Influence on Steering

Memory influence is phase-dependent.

### Direction Rules
- Phase 0 (Wander): mild attraction to higher memory.
- Phase 1 (Align): neutral (no memory bias).
- Phase 2 (Repel): mild repulsion from higher memory.

### Force Term
- Sample local memory gradient (finite difference on grid).
- Convert gradient to a force vector in world space.
- Apply phase-specific sign:
  - attract: +gradient (toward higher memory)
  - repel: -gradient (away from higher memory)
- Scale by memory_force_strength and clamp to max steering force.

### Integration Point
Add memory force as an additional term in the steering sum, after phase steering and before zone forces.

---

## Zone Interference & Blending

### Falloff Function (per zone)
- Let d = distance to zone center, r = zone radius.
- If d > r: force = 0.
- If d <= r: force magnitude = strength * (1 - (d / r))^2 (smooth falloff).
- Direction:
  - REPULSE: away from center
  - ATTRACT: toward center

### Combining Multiple Zones
- For each agent, sum all zone force vectors.
- Apply a cap to the resulting magnitude:
  - zone_force = clamp_length(sum_forces, zone_force_max)
- This replaces v2 "strongest wins" behavior.

---

## Density Glow Overlay

### Density Metric
- Kernel-smoothed count per cell:
  - Use the same grid resolution as memory (128 x 128).
  - Each agent contributes to nearby cells with a small kernel (e.g., radius 1–2 cells).

### Color Mapping (Green → Red)
- Compute per-frame density range with percentile mapping.
- Let p95 = 95th percentile density.
- Normalize: t = clamp(density / p95, 0, 1).
- Color:
  - green = (0, 1, 0)
  - red = (1, 0, 0)
  - color = lerp(green, red, t)

### Background-Only Effect
- The density glow should only modulate the black background.
- The glow must not wash out agents or UI overlays.
- Recommended approach:
  - Render glow as a background layer (behind agents).
  - Keep UI overlay background covering only the UI text region.

### Toggle Behavior
- Toggleable via a UI switch placed under the existing "Stats" switch.
- When OFF: no density computation or rendering (save performance).
- When ON: density grid updates and renders every tick.

---

## Determinism Requirements

Determinism must be preserved:
- Use the same RNG seed logic as v2.
- Memory deposit, decay, and density glow must be driven only by simulation state and dt.
- Percentile computation must be deterministic:
  - Use stable iteration order.
  - Avoid non-deterministic floating point reductions.

---

## Restart and Pause Rules

### Restart
- Memory grid resets to all zeros.
- Density grid resets to all zeros.
- Zone list clears (as in v2).

### Pause
- Zone timers freeze.
- Memory grid stops updating.
- Density grid stops updating.
- Rendering can continue (static).

---

## Implementation Notes (Non-Executable)

1) UI overlay background:
   - Ensure the UI background rectangle covers only the UI text area.
   - Density glow must not tint UI background or text.

2) Grid mapping:
   - Use the same simulation bounds used for agent clamping to map grid cells.

3) Performance:
   - If density glow is OFF, skip density grid updates.
   - If memory force is OFF (future toggle), memory grid may still decay for determinism.
