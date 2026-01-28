# PhaseWeave Visuals

This document describes visualization rules for PhaseWeave overlays and UI layers.

---

## Zone Visualization (v2)

Repulse / attract zones:
- REPULSE: light red glow.
- ATTRACT: light blue glow.
- Soft edge, subtle intensity.
- Visual should not overpower agents or background.

Recommended render:
- Filled circle with low alpha.
- Optional outer ring for softness.

---

## Density Glow Overlay (v3)

Layering order:
1) Background (black)
2) Density glow overlay (tinted background only)
3) Agents
4) UI overlay (UI background and text)

Toggle behavior:
- Controlled by a switch under the "Stats" toggle.
- When OFF: no glow is drawn.
- When ON: glow is drawn every tick.

Visual guidance:
- Subtle alpha so the effect is readable but not overpowering.
- Suggest alpha range: 0.2 to 0.4 depending on density.
- Optional smoothing by blending neighboring cells.

UI background rule:
- UI background should cover only the text area.
- Density glow must not tint UI background or text.

