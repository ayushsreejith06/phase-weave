# PhaseWeave Testing

Manual test cases for v2 interactions.

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
