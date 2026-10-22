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

## Port

`scripts/simulation/features/spellbook.gd`; the warning signs are drawn by the game view.
`tests/stage_features_check.gd` covers each rule.
