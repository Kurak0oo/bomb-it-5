# Stage-set tile art follows the round's choices (#74)

Captured 2026-10-29 in a cloud session with Godot 4.5 (`4.5.stable.official.876b29033`,
Linux, Xvfb, OpenGL 3) at 1280×720 under the `original` profile, with the original pack
rebuilt from the recorded SWF (`718c04c7…0408a2`, 195 slot sheets). The fixture calls the
round host's `_start_round` per stage set and advances 40 steps; it is a scratch script,
not part of the suite.

- [Magic Library, seed 231](magic-library-seed231.png): the seed rolls layout 2 with
  fixed choices 4, 2 and soft choices 1, 3, the same draws as the
  [original opening](../../evidence/reference-2026-10-21/stage-openings/magic-layout2.png).
  Both show a mushroom-lamp ring and lamp pillars, pencil cups on random fixed cells, and
  glasses and witch hats as soft blocks. The [earlier capture](../original-replica-2026-10-28/match-tiles.png)
  showed scrolls, books and coffee cups, and a floor-coloured ring.
- [Other sets, seed 42](other-sets-seed42.png): Birthday Party (empty arena, layout 3),
  Candy Factory, Cinema, Zoo and Luxury Shop, each drawing only art its round can draw.

Remaining differences, not covered by this fix:

- The pack fits each frame inside its cell. The original draws `_brick5` at 30/32 scale
  from the frame's own registration, so tall props (lamps, jars) are larger and overlap
  the row above.
- Floors are two 32 px crops of `BackGround_<Set>`, not the whole background bitmap.
- The page, HUD and controls are still the pre-#89 layout.

Checks: `tools/run_checks.sh` passes all 20 suites (690 checks, `layout_check` adds five
for the art choices), and `tools/check_art_workbench.gd` passes 38 checks under Xvfb.

## Replica page (#89–#92, #78)

Captured with the scratch fixtures under `.scratch/capture/` at 1558×720 (the logical
viewport of a 2532×1170 phone under `canvas_items`/`expand`) and 1280×720 (1920×1080).

- [Magic Library at phone size](page-magic-library-1558x720.png): the 48 px board fills
  the page height with half-cropped ring columns, the set background continues into the
  side scenery, the compact HUD (status pill, time, rivals, pause icon) and the
  mockup-style stick and bomb button. Compare the accepted
  [mockup](../../design/replica-layout-phone.png).
- [All six sets, phone size](page-six-sets-1558x720.png) and
  [16:9](page-six-sets-1280x720.png).
- [Pause](page-pause-1558x720.png): the original `UI_pause` page (exposed key `P_PAUSE`)
  with MAIN MENU and RESUME as ghost buttons over its painted buttons.
- [Ending](page-ending-1558x720.png): the original `winCartoon` over the map at 26 % of
  the 3-second ending.

The end cartoons' FFDec frame export has content only on frames 1–20 of 100 (frame 15
drops out; win and lose are empty afterwards), so the sheet holds those frames and the
replica keeps frame 20 for the rest of the tween. Whether the original also clears the
title after frame 20 needs a reference-player recording.
