# PhaseWeave

PhaseWeave is a deterministic, autonomous swarm simulation where agents shift between behavioral phases based on local density. The system is designed to oscillate between order and chaos without ever fully settling.

This README explains every core concept at a practical level. The original design spec and strict file rules have been moved to `docs/overview.md`.

---

## Concepts and How They Map to the Implementation

### 1) Agents (data-only)
Agents are plain data objects, not nodes. Each agent stores position, velocity, and a phase enum. No per-agent `_process()` or physics bodies are used. This keeps the simulation deterministic, fast, and easy to reason about.

### 2) Phases
Agents occupy one of three behavioral phases:
- Wander: noisy movement, weak alignment
- Align: strong alignment/cohesion, mild separation
- Repel: strong separation + extra noise

Agents do not choose phases. Each tick, the local density around each agent determines its phase.

### 3) Local Density
Density is computed from neighbor count within a radius and normalized by area. This value is scaled and compared to thresholds to decide the phase.

### 4) Simulation Loop (single source of truth)
A single controller advances time. Each tick runs:
1) Build spatial grid
2) Query neighbors for each agent
3) Compute density -> phase
4) Compute steering force for that phase
5) Integrate velocity with damping and speed caps
6) Update positions (bounded by the screen)
7) Request redraw

No partial state is read during a tick; changes are applied after computations.

### 5) Spatial Grid (performance)
Neighbor queries use a simple uniform grid. Agents are bucketed into cells, and each agent only checks nearby cells. This reduces the cost versus full O(n^2) checks.

### 6) Determinism
A single RNG seed makes the simulation repeatable. If you re-run with the same seed and parameters, the behavior matches.

### 7) Rendering
Rendering is a pure view of the simulation state. The renderer draws circles or velocity lines based on agent phase. Optional trails are achieved by not clearing the viewport and drawing a faint fade rectangle each frame.

### 8) UI Philosophy
By default, v1 uses minimal UI (start/restart). Debug info, pause, and trails are optional and controlled by toggles in `scripts/config.gd` for development and tuning.

### 9) Boundaries
Agents are contained within the viewport. When they hit edges, their velocity reflects so they bounce while preserving the approach angle.

---

## Files and Responsibilities

- `scripts/simulation_controller.gd`: owns the tick loop and time control
- `scripts/swarm_model.gd`: stores agents, grid, and updates movement
- `scripts/phase_rules.gd`: per-phase steering logic
- `scripts/agent.gd`: lightweight data container
- `scripts/config.gd`: all tunable parameters and feature toggles
- `render/swarm_renderer.gd`: draws the swarm
- `ui/ui_overlay.gd`: start/restart/pause UI and optional debug display

---

## Docs

- `docs/overview.md`: original design specification and strict constraints
- `docs/development.md`: living progress log and v2/v3 roadmap

---

## Running

Open the project in Godot and press Play.

For development toggles (debug UI, pause, trails), see `scripts/config.gd`.
