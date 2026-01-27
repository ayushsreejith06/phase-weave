# PhaseWeave Development Notes

This is a living log for development progress and version goals.
Update as changes land, especially when moving toward v2 and v3.

---

## v1 Status (Current)

Completed:
- Core agent model (data-only agents)
- Centralized simulation loop
- Phase transitions (density-driven)
- Steering per phase (wander/align/repel)
- Spatial grid neighbor queries
- Deterministic RNG seeding
- Renderer drawing from simulation state
- Minimal UI controls (start/restart) + optional pause/debug toggles

Notes:
- Tune parameters for visible phase cycling, flock formation, and breakup.
- Keep runtime stable and deterministic when toggles are disabled.

---

## v2 Roadmap (Proposed)

Ideas (not yet implemented):
- Optional obstacles or fields (if permitted)
- Performance profiling and optimization pass
- Alternative phase sets (e.g., orbit, pulse, drift)
- Multiple render styles selectable at runtime
- Exporting frames or recording sequences

---

## v3 Roadmap (Proposed)

Ideas (not yet implemented):
- Multi-swarm interactions (separate populations)
- External input fields (audio-driven or scripted density shifts)
- Extended determinism controls (record/replay system)
- Advanced rendering experiments (if allowed later)

---

## Changelog (Append as you go)

- 2026-01-27: v1 core loop + renderer + UI + debug toggles + trails.
