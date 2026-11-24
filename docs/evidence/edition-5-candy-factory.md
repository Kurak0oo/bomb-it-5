# Edition 5 Candy Factory: candy machine and belt

Recovery and runtime observation, 2026-10-21, for
[#65](https://github.com/Kurak0oo/bomb-it-5/issues/65). Script paths are under
`zlong/bombit5/`.

## Method

As for [Zoo](edition-5-zoo.md). Case
[`candy-idle`](../../tools/reference_player/cases/features/candy-idle.json) idles on
Candy Factory (Arcade, Normal). [Belt counter and items on the
track](reference-2026-10-21/features/candy-belt.json);
[capture](reference-2026-10-21/features/candy-belt.png).

## Recovered and observed

- One `ConveyorBelt` per board: the candy machine on `centerProp`, with a track from the
  `belt_<n>` cells sorted by n (`CandyFactoryMapData.as:116-154`). Layouts 1–3 share one
  33-cell loop from the exit (8,9) round to (6,11); (7,11) is a gap. Pac-Man layouts have
  no belt, so the machine does nothing. `slidePlat_*` cells exist only in unused
  Basketball layouts; Candy Factory has no sliding platforms.
- Every 210 ticks the machine makes an item at (8,9), deferred while a robot or bomb is
  there (`ConveyorBelt.as:206-226`). **Observed:** `_totalFrame` cycles 20…209, 20…; items
  appeared at ticks 210, 420, 630 and 840.
- Item: `[pickup, bomb, box]` chances easy .55/.45/0, normal .45/.55/0, hard .4/.6/0;
  Kill and Green Zone pickups only. Pickups come from the mode's pool; bombs are
  ownerless with a fuse of `int(random × 990)` and power 1/2/3 by difficulty.
- The belt moves 1 px per tick; on corners diagonally until the incoming axis aligns
  (`modifyOffest`). **Observed** (captures 7 ticks apart): a pickup's track index
  advanced in step with 15 ticks to leave the exit, 30 per straight and about 21 per
  corner.
- Bombs and pickups ride without collision; at the last cell they disappear (bombs
  without exploding; a robot owner gets its bomb back).
- Robots on belt cells ride when idle; holding a direction on a corner (and on the exit
  cell, a float quirk) or across the belt cancels the push; holding along it adds the
  push to their own movement. Horizontal pushes respect obstacles; vertical ones test the
  cell being left, so nothing ahead stops them.
- Belt cells are skipped by spawn pickers and never used as box-attack spots by the AI.
- Timed pickups: Arcade and Kill one, Green Zone one, Pac-Man two (`timePassed`).
- Vehicles: moto or car.

## Port

`scripts/simulation/features/belt.gd`, run in the engine-handler phase after bomb fuses,
blasts and weapons and before robot movement (`GameEngine.as:230-270`; the machine
registers at map build, before robots). `tests/stage_features_check.gd` covers each rule.
The desktop profile's float positions drift up to a tick against the original's twip
positions; the replica profile rides in twips and matches the
[recorded ride](edition-5-interactions.md).

## Display (checkpoint 5, 2026-11-07)

Recovered from `ConveyorBelt.initDis` / `initBeltView` and the recorded round's display
list (case `gameplay-candy-start`, golden `tests/goldens/gameplay-candy-start/candy-start.json`):

- `Art_CandyMachine` at 30/32 inside the ConveyorBelt's own container, which stays at
  xPos 0 (the board's origin); the clip sits at `_xN * GRID_WIDTH` on the centre row's
  platform layer. Its sweets are nested clips that loop over 70 frames from map load
  (frame 61 at the round's first frame).
- `Art_ConveyorBelt_1` at 30/32 on row 0's platform layer at the track's first cell
  (`"Art_ConveyorBelt_" + 1`: the layout number passed to `setBeltTrack` is never used, so
  `_2` and `_3` are never shown). One clip of 33 segment clips, each looping over 9 frames
  (frame 7 at the round's first frame); the loop does not depend on the belt's movement.
  Pac-Man layouts have no track, so no belt clip; the machine still shows.
- The centre is a hidden box: `setMidBox(x, y)` without `true` (`CandyFactoryMapData.as:109`).

## Carried items and the belt's end (checkpoint 5, feature motion, 2026-11-08)

Recovered from `ConveyorBelt.runEngine` / `bombMove` / `propMove` / `addDisappearAni`,
`Bomb.takeCount` / `resetDisplay` and `AbstractItem.resetDisplay`, and recorded in case
`gameplay-candy-belt` (round of `gameplay-candy-start`, AI stopped, 1,725 frames):

- Each tick the belt adds its offset to every carried bomb's and pickup's `xPos`/`yPos` and
  calls `resetDisplay`: the bomb's Sprite is taken off and added again, last, to the bomb
  layer (2) of the row it now stands on; the pickup's Sprite likewise to the row itself. The
  clips are not made again: a carried bomb's fuse spark and a pickup's PixelClip loop run on.
- **Observed:** item positions between cells match the replica's twip positions in every
  capture; the machine's sweets loop runs on over 70 frames (frame 6 at ticks 225 and 1275).
- A belt bomb goes off `blastTime + 2` ticks after it is made (`takeCount` blasts once
  `_time > _blastTime`, counting from 0 from the next bomb tick), like the normal 70 → 72;
  its flames are placed from its own position (`xPos + EXCURSION_X ± k * GRID_WIDTH`), off the
  grid on the belt.
- At the last cell (6,11) every bomb (`disappear`) and pickup (`dispose`) adds one
  `Art_Prop_Disappear` (30 frames, no nested clips): made stopped, at
  `(xN + 0.5) * GRID_WIDTH + EXCURSION_X - 5`, `(yN + 0.5) * GRID_WIDTH + EXCURSION_Y`, scale 1,
  rotated to `atan2D` of the last segment's direction (0°: the last segment runs right), last
  on that row's platform layer. `countDisappearAni` runs on the brick explosion handlers,
  after the engine handlers, so it is first drawn on frame 2 and leaves on the tick it reaches
  30. **Observed:** frame 11 nine ticks after a bomb left, frames 3 and 16 after a pickup.
