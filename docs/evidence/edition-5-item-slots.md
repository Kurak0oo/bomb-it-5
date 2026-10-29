# The four named item slots (#85)

Authority build `agame-bomb-it-5-zh-fix.swf` (sha256 `718c04c7…0408a2`). Static source from the
FFDec 26.3.0 script export. Embedded rules XML and symbol table read with
`tools/inspect_source_data.tags`. Runtime from the
[glove demonstrations](observations/swf-v1.6.1-followup/task1_gloves/README.md).

DESIGN.md held four named empty slots: the glove, the bouncer, the magic carpet and the heavy
bomb. The names came from a portal description, not from the SWF. Each slot is decided here
by whether edition 5 can produce it in a selectable mode.

## What edition 5 can produce

- **Drop tables.** `AbstractGameMode.initMap` builds `game.mapPropArr` from 15 entries:
  `NumProp`, `PowProp`, `SpeedProp`, `LifeProp`, `ShieldProp`, `BombShoesProp`,
  `InvincibilityProp`, `LaserGunProp`, `FlamerProp`, `HammerProp`, `ShotGunProp`,
  `LandmineProp`, `TripleShootGunProp`, `BoxingProp` and the stage set's vehicle. Each entry is
  weighted `round(value × 100)` from the mode's `prop` XML. `CollectMode` and `PaintingMode`
  use the same classes, but they are not selectable.
- **Rules XML.** The `prop` elements name only the classes above, plus `propProp`.
- **Classes.** The items under `zlong/bombit5/items/` are the props above, the rides (car,
  moto, horse, dragon), `CoinProp` (Pac-Man) and `eatProp`. No class, symbol or XML element
  matches carpet, bounce/bouncer or heavy. The only "kick" code is `BombShoesProp` and the
  bomb's `kickedFly`.

Drop weights for the two glove classes:

| Mode | `BombShoesProp` | `BoxingProp` |
| --- | --- | --- |
| Arcade | 10 | 1 |
| Battle Royale (Kill) | 0 | 15 |
| Green Zone | 0 | 15 |
| Pac-Man | 0 | 0 |

## Decisions

| Slot | Edition 5 class | Reachable | Result |
| --- | --- | --- | --- |
| Glove: PUSH THE BOMB | `BombShoesProp` (propNum 6, white hand) | Arcade drops | Ported |
| Glove: BOXING GLOVE | `BoxingProp` (propNum 38, red glove) | Arcade, Battle Royale and Green Zone drops | Ported |
| Bouncer | none | No | Unreachable; stays out of the replica |
| Magic carpet | none | No | Unreachable; stays out of the replica |
| Heavy bomb | none | No | Unreachable; stays out of the replica |

Both glove candidates are real, separate items. The "glove" slot was a guess at one of them.

## Port (`glove_items`, set by the replica host)

**Push the bomb** (`BombShoesProp.changeStage`, `kickBomb`; `Bomb.startFly`, `kickedFly`):

- The kick handler is set only if the robot has no vehicle.
- When the robot's `HitMove` touches a bomb in its leading cell, every bomb there leaves the
  map and flies at 7 px per bomb step in the robot's direction. The bomb uses its own
  `HitMove`, so robots do not stop it.
- The bomb stops on touching a box or bomb (`hasHit`) and re-registers in its cell.
- `engineArr.splice(0)` removes the fuse callback for the flight, so the fuse pauses. The
  recording shows a blast at N+92 instead of N+72.
- Picking up a vehicle (`resetStage`), losing one, or respawning (`initReliveStage`) clears
  the handler.

**Boxing glove** (`BoxingProp`, `BoxingPlayCommand`):

- It is a weapon with two uses. Space stops movement and plays the 14-frame
  `boxing<Dir>_Play` clip.
- The punch resolves at `totalFrames − 1` (13 steps). The Up clip moves behind the robot on
  frame 7.
- `tryToDestory` runs on the first cell ahead, then on the second unless the first held a box
  (fixed or soft), a bomb or a switch. A soft box breaks for score; a bomb is set off.
- Robots on the wielder's cell and on each tried cell are hit.
- A pickup in reach is collected by the wielder, not destroyed. If that punch spent the glove,
  `initWeapon` then also drops a weapon it just collected.
- The AI's reach for it is `weaponRange` 2.

`tests/hitmove_check.gd` covers the kick (7 px slide to the wall, fuse paused for the flight)
and the punch (13 steps, two-cell reach, box stop, remote pickup, two uses).

Art slots: `item.kick` (prop frame 6), `item.boxing` (prop frame 38), `held.boxing`
(`boxing_<Dir>`, 24 frames) and `attack.boxing` (`boxing_<Dir>_Play`, 14 frames). The
`_Play_2` and `_Play_3` variants shorten the punch art when the first or second cell is
blocked. They are not separate slots.

## Not ported

- Bomb shoes change the robot's foot clip (`footMcNum = 2`). The replica has no separate
  foot art.
- A belt's `HitMove` calls also run the kick handler in the original. The replica's belt
  push does not kick.
- `JumpTable` redirects (`changeBombDirection`) and `SlideSwitch` hits are skipped. Neither
  exists in a selectable stage.
- The desktop adaptation keeps both glove draws as empty slots (DESIGN.md first-build
  policy).
