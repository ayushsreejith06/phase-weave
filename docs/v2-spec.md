# PhaseWeave v2 Specification

This document defines the v2 interaction features and how they integrate with the existing v1 simulation loop. It does not implement behavior.

---

## Feature Descriptions

### Temporary REPULSE Zone (Left Click)
- Left-click spawns a temporary REPULSE zone at the click position.
- Zone affects agents within radius R (world units).
- Zone duration: 15 seconds, then disappears.
- Visual: light red glow at the zone radius.

### Temporary ATTRACT Zone (Right Click)
- Right-click spawns a temporary ATTRACT zone (black hole) at the click position.
- Zone affects agents within the same radius R (world units).
- Zone duration: 15 seconds, then disappears.
- Visual: light blue glow at the zone radius.

### Stats Toggle (Top-Left UI)
- Toggle labeled "Stats" appears in the top-left.
- When ON and the simulation is paused, hovering an agent shows stats for that agent at that moment.
- When OFF, or when not paused, hover does nothing.

---

## Interaction Rules

### Zone Creation & Refresh
- Multiple zones can exist simultaneously.
- Clicking within an existing zone of the same type:
  - Slightly increases that zone's radius (small incremental growth).
  - Resets that zone's timer to 15 seconds from the latest click.
- Clicking elsewhere spawns a new zone with a fresh 15 second timer.
  - Holding the mouse button continuously grows the most recently created or refreshed zone of that type while held.

### Multi-Zone Influence
- If an agent is within multiple zone radii, the strongest zone dominates the direct zone force at that moment.
- Even when one zone is strongest, agent motion should still reflect the presence of nearby zones through trajectory changes over time (e.g., switching dominance as the agent moves).
- Zone force is an additional force term; it does not replace phase steering.

---

## Data Model (Zones)

Required fields per zone:
- type: enum { REPULSE, ATTRACT }
- center: Vector2
- radius: float (world units)
- start_time: float (seconds)
- duration: float (seconds, fixed at 15.0)
- strength: float (force magnitude)

Optional but useful:
- last_refresh_time: float (for tracking resets)
- radius_growth_per_refresh: float (small increment)

---

## Tick Integration Points

The zone system integrates with the existing tick order without breaking determinism:

1) Build spatial grid
2) Query neighbors for each agent
3) Compute density -> phase
4) Compute steering force for that phase
5) Compute zone force (if within any zone radius)
6) Integrate velocity with damping and speed caps
7) Update positions (bounded by the screen)
8) Request redraw

Notes:
- Zone force is computed after phase steering and added to the steering vector.
- Zone timers advance with the same simulation time step as other forces.
- Expired zones are removed before force computation in a given tick.

---

## Rendering Spec (Glowing Visuals)

### General
- Zones render as circular glows centered at the zone's center.
- Glow should be visible but not overpower agent rendering.

### Color & Style
- REPULSE: light red glow (soft edge)
- ATTRACT: light blue glow (soft edge)

### Suggested Visual Approach (non-prescriptive)
- Draw a filled circle with low alpha + a slightly larger outer ring.
- Use gradient or multiple concentric circles to imply softness.

---

## Acceptance Tests

### Left-Click Repulse Zone
- Left-click spawns a REPULSE zone at the click position.
- Zone lasts 15 seconds and disappears.
- Agents within radius R are pushed away.
- Zone is rendered with a light red glow.

### Right-Click Attract Zone
- Right-click spawns an ATTRACT zone at the click position.
- Zone lasts 15 seconds and disappears.
- Agents within radius R are pulled toward the center.
- Zone is rendered with a light blue glow.

### Multiple Zones & Refresh
- Multiple zones can exist simultaneously.
- Clicking inside a zone increases its radius slightly and resets its timer to 15 seconds.
- Holding the mouse button grows the zone continuously while held.
- When multiple zones overlap, the strongest zone governs zone force, but trajectories show influence changes as agents move between zones.

### Stats Toggle
- "Stats" toggle appears top-left.
- When ON and paused, hovering an agent shows stats (position, velocity, speed, phase, local_density, steering components).
- When OFF, or when not paused, hover shows nothing.
