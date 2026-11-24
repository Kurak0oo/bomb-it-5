# Edition 5 Magic Library: spellbook

Recovery and runtime observation, 2026-10-21, for
[#66](https://github.com/Kurak0oo/bomb-it-5/issues/66). Script paths are under
`zlong/bombit5/`.

## Method

As for [Zoo](edition-5-zoo.md). The spellbook is not referenced by any Grid slot, so the
case [`magic-idle`](../../tools/reference_player/cases/features/magic-idle.json) is read
through the bombs it makes ([spellbook bombs](reference-2026-10-21/features/magic-spellbook.json));
[capture with warning signs](reference-2026-10-21/features/magic-spellbook-signs.png).

## Recovered and observed

- `centerProp` makes the spellbook; with the eight `holdProp` cells it forms an
  indestructible 3×3 block at x 7–9, y 6–8 in all six layouts (`MagicLibraryMapData.as:104-111`).
- Closed for `FLIP_DELAY` 450 ticks, then a 69-frame flip (SWF): targets are chosen and
  signs shown on frame 2, items drop on frame 32 (`Spellbook.as:137-169`). The cycle is
  518 ticks: drops at 481, 999, …
- **Observed:** at tick 482 two bombs owned by the `Spellbook` appeared at (12,3) and
  (7,9), fuse 70, while red signs showed on the board shortly before.
- Targets (`:171-253`): at most two empty cells (no box, bomb, belt, arm, pickup or
  robot), none if fewer than 10 exist; from different quadrants (split at x 8, y 7) and
  not touching. Each is a pickup, a bomb or nothing: Arcade easy .5/.5/0, normal .4/.6/0,
  hard .3/.7/0; Kill, Green Zone and Pac-Man always a pickup. Bombs are ownerless with the
  normal fuse and power 1/2/3 by difficulty. A robot on a target cell at drop time
  cancels that item; signs are cosmetic.
- Timed pickups: none in any mode (`ArcadeMode.timePassed` and the others skip Magic
  Library). The [modes record](edition-5-modes-and-flow.md) previously said Arcade gives
  one; corrected.
- Vehicles: horse or moto. `lavaOrgan` is never placed by any recorded layout.

## Display (2026-11-07, checkpoint 5)

Observed in the reference player on the `gameplay-library-start` round (seed 42, Normal, AI
stopped), one `display` dump per tick after the capture:

- `Art_Spellbook` (69 frames, at 30/32 in its container on the centre row's platform layer,
  `Spellbook.initDis`) stays on frame 1 to tick 450; its nested loop `@42` (50 frames) plays
  from map load (frame 11 at the capture, 1 at tick 440). Ticks 451–518 show frames 2–69,
  one per tick; `@42` carries on over frames 2–9 (12 … 19) and is gone from frame 10. On tick
  519 the book is back on frame 1 and `@42` starts over at frame 1.
- Signs (`signItemPosition`): `Art_Sign_Red` (bomb) and `Art_Sign_Blue` (pickup), 64 frames,
  appear on tick 451 as the last child of their row's platform layer (the spellbook's
  container becomes `@0#0` when one joins its row), show frame 1 on 451 and 452, then one
  frame per tick, hold 64 from tick 515, and are gone on tick 518 (`deleSign` on frame 69),
  so they stay after the drop on frame 32. The simulation's `signs` used to end at frame 32;
  it now follows `deleSign`.

## Port

`scripts/simulation/features/spellbook.gd`; `tests/stage_features_check.gd` covers each rule.
On the gameplay screen `GameBoard._spellbooks` draws the book and its signs from their clips
(record_screen.py `sets`), `tests/flow_scene_check.gd` checks the paths above; without the
set's art the placeholder layer draws them.
