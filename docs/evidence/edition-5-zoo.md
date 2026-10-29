# Edition 5 Zoo: crocodiles, horse and dragon

Recovery and runtime observation, 2026-10-21, for
[#63](https://github.com/Kurak0oo/bomb-it-5/issues/63). Script paths are under
`zlong/bombit5/` in the decompiled publisher scripts.

## Method

Linux reference player as in the [stage openings](edition-5-stage-openings.md), with the
`reference-platforms` focus patch, which records every `maps.platform` object a Grid slot
references. Case
[`zoo-idle`](../../tools/reference_player/cases/features/zoo-idle.json) enters Arcade on
Zoo (Normal) and idles, capturing every 7 frames for 840 frames.
[`summarize.py`](../../tools/reference_player/cases/features/summarize.py) reduces the
captures to [crocodile states](reference-2026-10-21/features/zoo-crocodiles.json); the
opening capture is engine tick 20 (the crocodile and belt counters both read 20 there).
[Capture with mouths open](reference-2026-10-21/features/zoo-crocodiles-open.png).

## Crocodiles (`maps/platform/Crocodile.as`)

- A cell named exactly `crocodile` makes one (`ZooMapData.as:112-115`). Layouts 1–3 have
  four each (12 in all); the Pac-Man layouts none. Earlier notes said 14.
- No randomness: all start closed at frame 0 and run in lockstep. **Observed:** the four
  crocodiles share `_currState`/`_currFrame` in every capture; closed counts to
  `OPEN_DELAY` 240, then `action_open`, `open_close` counting to `CLOSE_DELAY` 60,
  `action_close`, then closed again. The closed counter repeats 2 lower every 343 frames:
  a 345-frame cycle. Mouth clip (SWF): 46 frames, `openComplete` on 25, so opening takes
  24 ticks and closing 21.
- `isDanger` is set during the 240th closed tick and cleared when the mouth shuts
  (observed true through all three open states). `eat()` runs on each of the 60 open
  ticks (`:123-146`): bombs on the cell detonate, its pickup is deleted, and every robot
  on it gets the blast kill path (shield, vehicle loss or death).
- The cell never blocks movement (`RobotController.as:42`) and blasts pass through it
  (`Bomb.as:276-296`); a bomb cannot be placed on it (`Grid.isEmpty` is false on a
  platform). Random pickups may land on it (`Grid.isBlock` ignores platforms).
- AI: an open crocodile is danger time 0, crocodile cells never enter the free list and
  are skipped as targets (`AIControl.as:330-336`, `AbstractState.as:174`).

## Horse and dragon (`items/rides/HorseProp.as`, `DragonProp.as`)

- Zoo vehicle entries pick horse or dragon 50/50 (`AbstractGameMode.as:240-328`); box
  drops cap car, moto and horse at four together, never the dragon (`Box.as:196-212`).
- Speed is the base move speed times the rules XML `rides`: horse 1, dragon 0.8 (car
  1.6, moto 1.3).
- Both act through `HitMove.hitHandleArr`, called with the **blocked cell ahead** while
  the robot pushes flush into a box, a non-landmine bomb or other blocker (never the
  map edge).
- Horse: lands on the cell beyond if it is on the map with no bomb and no box; the jump
  covers 60 px at 4 px per tick (15 ticks) with control and bombing off, correcting the
  cross axis 1 px per tick. Hit mid-jump, it stays where it was.
- Dragon: a soft box ahead is broken (normal break and drop chance) and scores 10; the
  robot stops for 17 ticks. Its `InvincibilityCommand` only flashes (no protection).
- A mounted robot hit by anything loses the ride instead of dying (shared rule,
  `TryToKillCommandChain.as:56-78`).

## Port

`scripts/simulation/features/crocodile.gd` (cycle and `eat`), crocodile tiles as walkable
non-floor cells in `movement.gd` and the blast rays, AI danger in `ai_perception.gd`;
rides in `bomb_simulation.gd` (`_ride_contact`, `_advance_jump`) and `pickups.gd`.
`tests/stage_features_check.gd` covers each rule.

The mounted-hit recovery keeps the existing 35-tick port from the
[protection probes](edition-5-protection-vehicle-probes.md). Crocodile bites and rides
were later recorded ([robot interactions](edition-5-interactions.md)); AI reactions to
crocodiles were not observed at runtime.
