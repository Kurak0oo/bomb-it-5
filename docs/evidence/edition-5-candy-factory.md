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
Float positions drift up to a tick against the original's twip positions. Robots riding
the belt were not observed at runtime.
