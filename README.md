# PhaseWeave

### A Swarm Phase-Transition Simulation

PhaseWeave is an autonomous swarm-based simulation where thousands of simple agents continuously shift between behavioral “phases” based on local density.
The system never converges to a final state. Instead, it oscillates between order and chaos, producing evolving, painterly structures that feel alive.

This is not a game.
There are no goals, no player control during execution, and no win conditions. The project exists as a generative system and an artwork engine driven entirely by local rules.

---

## Core Concept

Each agent belongs to one of several behavior phases (e.g. wander, align, repel).
Agents switch phases dynamically based on local neighborhood density.

The feedback loop is:

local density → phase → movement → new density

This creates spontaneous:

* flock formation
* collapse events
* shockwave-like dispersals
* reorganization into new structures

The system is designed to never fully settle.

---

## Design Principles (Non-Negotiable)

* Agents are data, not Nodes
* No physics bodies
* No per-agent _process() calls
* One centralized simulation loop
* Deterministic given RNG seed
* Visuals derive directly from simulation state
* Minimal UI (start / restart only)

If a feature violates these principles, it does not belong in v1.

---

## Agent Model

Each agent stores only:

* position : Vector2
* velocity : Vector2
* phase : int (enum-style)
* energy or age (optional, slow-changing)

Agents have:

* no memory
* no goals
* no global knowledge

All behavior is reactive and local.

---

## Phases (v1)

### Phase 0 — Wander

* Noisy motion
* Weak neighbor influence
* Injects entropy

### Phase 1 — Align

* Align velocity with nearby agents
* Mild cohesion
* Produces structured flow

### Phase 2 — Repel

* Strong repulsion from nearby agents
* Higher noise
* Breaks up clusters

Agents transition between phases based on local density thresholds.
No agent “chooses” a phase — phase emerges from conditions.

---

## File Structure (STRICT)

Codex must follow this structure exactly.
No additional folders or scripts unless explicitly approved.

res://

* main.tscn
* scripts/

  * simulation_controller.gd
  * swarm_model.gd
  * agent.gd
  * phase_rules.gd
  * config.gd
* render/

  * swarm_renderer.gd
* ui/

  * ui_overlay.gd

---

## File Responsibilities

### scripts/simulation_controller.gd

* Owns the simulation loop
* Advances discrete ticks
* Calls update phases in strict order
* Handles restart and RNG seeding
* Only script allowed to advance time

No rendering code here.

### scripts/swarm_model.gd

* Stores the list of agents
* Handles spatial queries (neighbor lookups)
* Updates agent positions and velocities
* Does NOT draw anything

Pure simulation state.

### scripts/agent.gd

* Lightweight data container
* No _process() or _physics_process()
* No scene tree awareness

### scripts/phase_rules.gd

* Encapsulates behavior per phase
* Given an agent + neighbors, returns steering forces
* No direct state mutation outside agent passed in

Keeps behavior modular and swappable.

### scripts/config.gd

* Central place for tunable parameters:

  * density thresholds
  * force strengths
  * noise magnitude
  * max speed

No logic.
Codex must never hardcode magic numbers outside this file.

### render/swarm_renderer.gd

* Node2D
* Renders agents in _draw()
* Visuals derived strictly from agent state
* No simulation logic

### ui/ui_overlay.gd

* Minimal UI only:

  * start
  * restart

No live parameter tweaking in v1.

---

## Simulation Loop (Conceptual)

Each tick executes in this order:

1. Query neighbors for each agent
2. Determine phase transitions
3. Compute steering forces based on phase
4. Integrate velocity (with damping)
5. Update positions
6. Request redraw

No step may read partially updated state.

---

## Rendering

* Agents drawn as points, small circles, or short velocity lines
* Optional:

  * color by phase
  * color by speed
* Background remains static or empty in v1

No post-processing, no shaders in v1.

---

## Determinism

* Use RandomNumberGenerator
* Seed explicitly at start
* Same seed → same behavior

Seed may be printed to console for debugging.

---

## Definition of Done (v1)

The project is considered complete when:

* Swarms visibly form, dissolve, and reform
* Phase transitions are observable and frequent
* No single configuration is permanent
* Simulation can run indefinitely without freezing
* File structure remains clean and minimal
* Behavior is explainable by local rules

---

## Explicitly Out of Scope (v1)

* Obstacles
* Pathfinding
* Goals or objectives
* User control during simulation
* Physics bodies
* Optimization passes
* Shaders or post-processing

These may be explored later, but not now.

---

## Philosophy

PhaseWeave is about process, not outcomes.

If you can pause at any moment and explain:

* why agents are moving the way they are
* why a cluster formed or exploded
* why order turned back into chaos

Then the system is working.

If it merely looks cool but feels arbitrary, it is not.
