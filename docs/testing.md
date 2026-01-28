# PhaseWeave Testing

Manual test cases for v2 and v3 interactions.

---

## Zone Creation & Expiration

1) Left-click in the simulation area.
   - A REPULSE zone appears at the click position.
   - The zone disappears exactly 15 seconds later.

2) Right-click in the simulation area.
   - An ATTRACT zone appears at the click position.
   - The zone disappears exactly 15 seconds later.

3) Click multiple times within the same zone.
   - The zone's radius expands slightly each time.
   - The zone's timer resets to 15 seconds on each click.

---

## Zone Influence

1) Place a REPULSE zone near a cluster.
   - Agents within radius R move away from the zone center.

2) Place an ATTRACT zone near a cluster.
   - Agents within radius R move toward the zone center.

3) Place two zones so their radii overlap.
   - The strongest zone dominates direct zone force.
   - As agents move, trajectories reflect shifting dominance between zones.

---

## Stats Toggle & Hover

1) Turn "Stats" ON.
   - Hovering an agent shows live stats (position, velocity, speed, phase, local_density, steering components).

2) Turn "Stats" OFF.
   - Hovering does nothing and shows no overlay.

---

## Pause/Resume & Timers

1) Spawn a zone, then pause.
   - The remaining time on the zone does not decrease while paused.

2) Resume.
   - The zone's remaining time continues from where it left off.

---

## v3 Memory Field

1) Restart clears memory.
   - After a restart, trails are gone and memory bias is no longer visible.

2) Pause freezes memory.
   - Pause while trails are visible.
   - Trails remain static; no decay or new deposits.

3) Memory bias is observable.
   - Phase-dependent behavior is visible:
     - Wander shows mild trail-following.
     - Align shows neutral behavior.
     - Repel shows mild trail-avoidance.

---

## v3 Zone Blending

1) Overlapping zones blend smoothly.
   - Create overlapping attract and repel zones.
   - Movement shows continuous influence rather than abrupt dominance switches.

2) Zone force cap holds.
   - Stack multiple zones.
   - Overall steering does not exceed the configured max.

---

## v3 Density Glow Overlay

1) Toggle ON/OFF.
   - Use the density glow switch under "Stats".
   - OFF: no background glow.
   - ON: glow appears and updates.

2) Glow updates with density changes.
   - As clusters form, glow increases locally.
   - As clusters dissolve, glow fades.

3) Background-only effect.
   - Agents and UI remain unaffected by glow tint.
   - UI background still covers only the UI text area.

4) Performance sanity check.
   - With same agent count as v2, FPS drop is not significant.
