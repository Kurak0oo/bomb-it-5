# Edition 5 Birthday Party: toy hands

Recovery and runtime observation, 2026-10-21, for
[#64](https://github.com/Kurak0oo/bomb-it-5/issues/64). Script paths are under
`zlong/bombit5/`.

## Method

As for [Zoo](edition-5-zoo.md). Case
[`birthday-idle`](../../tools/reference_player/cases/features/birthday-idle.json) uses
original-RNG seed 11, which rolls `BirthdayPartyStage2`; an unseeded run rolled the empty
layout 3. [Hand states](reference-2026-10-21/features/birthday-toy-hands.json);
[capture with hands out](reference-2026-10-21/features/birthday-toy-hands-open.png).

## Recovered and observed

- `toyHand_left/up/right/down` cells (`BirthdayPartyMapData.as:114-133`): layout 1 has
  (8,2) down, (2,7) right, (14,7) left, (8,12) up; layout 2 (8,4) up, (5,7) left,
  (11,7) right, (8,10) down. Layout 3 and the Pac-Man layouts have none. Each hand cell
  also gets an invisible indestructible box (`setMidBox`), so it blocks movement, bombs
  and blasts.
- Timing (`ToyHand.as:102-138`): the first open is at tick 105 (**observed**: all four
  open at 105, hand clip frame 7 at tick 111). On opening, the next closed period is
  drawn as `35 × (2 + int(random × 20))` (**observed** 630, 665, 700, 700); it counts only
  while closed. The open hand clip has 14 frames: the hand closes 13 ticks after opening
  (**observed** closed at 118, next open at 748 = 118 + 630).
- `handPushSetting` scans up to three cells: a box ends the reach; otherwise the arm
  stops before the farthest bomb or robot, and reaches all three cells when nothing is
  there (**observed** reach 0 with boxes in front, 1 and 2 elsewhere). Scanned cells are
  marked (A* blocked, skipped by spawn pickers); closing clears only cells 1..reach.
- On the clip's `pushComplete` frame (SWF: up 6/9/9/11, down 11/10/11/11, left and right
  9/11/11/11 for reach 0–3) it destroys pickups in reach (not in Pac-Man), then throws the
  captured bombs and pushes the captured robots at 15 px per tick. Bombs fly with their
  fuse paused until the next cell holds a box or bomb; robots lose control and stop when
  their centre enters such a cell, snapping back a cell on the push axis. Nobody is hurt.
- Vehicles: horse or moto 50/50 (`AbstractGameMode.as:328-331`).

## Port

`scripts/simulation/features/toy_hand.gd`; robot pushes and bomb flights in
`bomb_simulation.gd` (`_advance_push`, `_advance_flying`); arm cells block AI paths
(`ai_perception.gd`). `tests/stage_features_check.gd` covers each rule. Pushes were not
observed at runtime (the run is idle).

## Display (checkpoint 5, 2026-11-07)

Recovered from `ToyHand.setMc` / `runEngine` and the recorded round's display list (case
`gameplay-birthday-start`, seed 11, which rolls `BirthdayPartyStage2`; seed 42 rolls the
handless layout 3), checked by stepping that round past its first opening in the
reference player (an art-pass session, not a recording):

- `Art_ToyHand_<Direction>` at 30/32 inside its AbstractObject container on its cell, on
  that row's platform layer, stopped at frame 1 (no `hand` clip). The cell's box is hidden
  (`setMidBox` without `true`); the centre is shown (`setMidBox(x, y, true)`: the cake).
- Frames 2-5 carry the labels `g0`-`g3`, each with a 14-frame `hand` clip (all four
  directions). On opening the clip goes to `g<pushStep>` with `hand` at 1, one hand frame
  per tick; at 14 `_handMc.stop()` leaves it there and nothing sends the clip back to
  frame 1, so after the first opening the closed toy shows `g<pushStep>` with hand frame 14
  (**observed**: opening 105 frames after the capture, hand 14 thirteen frames later and
  held).
