# Original cinema artwork

Created for this repository on 2026-10-20 with the built-in imagegen tool. Both
atlases were generated from text descriptions of original art. No SWF image,
sprite, screenshot, audio or branding was supplied as a generation input or copied
into these production assets. The recovered screenshot is a layout/style reference
in research storage, separate from these newly generated images.

The art direction is a bright cartoon cinema arena: dark plum outlines, brushed
cel shading, glossy enamel, warm gold highlights, red theatre seats, popcorn/soda
obstacles and teal machinery. The neutral robot enamel receives four team tints.
The working screen labels do not select a store name or publication language.

| File | Actual dimensions | Regions |
| --- | --- | --- |
| `robot-atlas-v1.png` | 1254 × 1254 RGBA | 4 columns × 4 rows; proportional regions accommodate the generated dimensions |
| `cinema-atlas-v1.png` | 1536 × 1024 RGBA | 6 columns × 4 rows; 256-pixel square cells |

Robot rows face Down, Right, Up and Left. Columns are idle, alternating walking
poses and an action pose. `scripts/game_art.gd` maps props and draws atlas regions
without changing the PNGs. Four robot tints match the HUD portraits. The original
PNG alpha is preserved; RGB beneath zero alpha is not a background to remove.

Prop order by row:

1. Popcorn, soda, seat, spotlight, projector, carpet swatch.
2. Bomb, mine, hammer, flamer, laser, triple-shot.
3. Fireball, car, moto, shield, heart, Invincibility star.
4. Capacity, power, speed, portal, ghost, trophy.

The carpet swatch is retained as palette material; the board uses a restrained
native weave to keep walking lanes readable at 36 pixels. Chassis, borders,
translucent controls, labels and beam connections remain native Godot drawing.
These are intentional UI/effect elements, not copied source assets.

Gameplay never depends on raster pixels or sprite frame dimensions. Walk feedback
uses observed committed displacement; action/recovery/death/protection and effect
visibility use copied round state. Rendering does not change damage or timing.
Linear filtering is local to the painted view and controls. Import settings retain
lossless alpha and do not alter the project's simulation or global physics rate.

Hashes and inspected desktop captures are recorded in
[`docs/verification/presentation-2026-10-20`](../../docs/verification/presentation-2026-10-20/README.md).
