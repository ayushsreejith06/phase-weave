# PhaseWeave UI Guide

This document describes UI behaviors and visual language.

---

## Stats Toggle

Location:
- Top-left corner of the UI overlay.

Behavior:
- When ON and paused, hovering over an agent shows stats for that agent.
- When OFF, or when not paused, hovering does nothing and shows no overlay.

Agent stats displayed when ON:
- position
- velocity
- speed
- phase
- local_density
- current steering components

---

## Hover Interaction

Expectations:
- Hover uses the current frame's data (no smoothing or historical values).
- Hover is only active while paused; it should not unpause or change the simulation state.
- Only one agent's stats are shown at a time (the agent under the cursor).

---

## Visual Language

Zone colors:
- REPULSE zone: light red glow.
- ATTRACT zone: light blue glow.

These colors should be consistent anywhere zones are displayed.
