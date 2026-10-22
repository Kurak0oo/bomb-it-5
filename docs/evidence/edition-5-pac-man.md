# Edition 5 Pac-Man mode

Runtime observation and source recovery, 2026-10-21, for
[#69](https://github.com/Kurak0oo/bomb-it-5/issues/69). Static rules are in
[modes and flow](edition-5-modes-and-flow.md#modes).

## Method

Linux reference player as in the [stage openings](edition-5-stage-openings.md). Case
[`pac-man-cinema-idle`](../../tools/reference_player/cases/modes/pac-man-cinema-idle.json)
enters Pac-Man on Cinema, Normal, and leaves the player idle, capturing every 175
frames. [`pac_props.py`](../../tools/reference_player/cases/modes/pac_props.py) lists
the opening props ([opening](reference-2026-10-21/pac-man/opening.json));
[`summarize.py`](../../tools/reference_player/cases/modes/summarize.py) reads the players
and robots ([summary](reference-2026-10-21/pac-man/summary.json)). The layout was
`CinemaStage_PacMan_1`.

## Findings

- The opening holds 121 `CoinProp`, three `SpeedProp`, one `ShieldProp` and the
  player's `NullWeapon` on its spawn (1,1)
  ([capture](reference-2026-10-21/pac-man/pac-man-opening.png)). The layout has 126
  empty floor cells: 126 − 4 items − the spawn's NullWeapon = 121 coins. The HUD reads
  `0/121`.
- The four items sit one per quadrant, split at x 8 and y 7 (`Math.ceil(17 / 2) - 1`,
  `Math.ceil(15 / 2) - 1`): (6,1), (13,3), (11,9), (4,7); no two are adjacent. This is
  `PacManMode.itemPosSetting`; kinds come from the PacManMode drop table (speed 40,
  life 5, shield 25, invincibility 30).
- The player's base weapon is `NullWeapon` (model weapon `speedgun`, no action); each
  ghost's is `PacModeWeapon`, an unlimited `FlamerProp` (model `thrower`). Ghost
  profiles show bomb 1, power 2, speed 6 (`030201`, move speed 2.1).
- Robots spawn at the Arcade corners (`getRobotPositions` default). The ghosts are
  already walking during the entry animation, so the first capture shows them two
  cells in; Kill and Green Zone openings show the same.
- Ghosts walk over coins without eating them and their flames leave coins standing
  ([capture after 25 s](reference-2026-10-21/pac-man/pac-man-idle-25s.png)):
  `propsEated.ai` is empty and `PacModeWeapon.changeStage` clears `destroyProp`.
- The idle player at (1,1) was never attacked. `StateFollow` only chases
  `PersonRobot`s inside the ghost's manager areas, which are the `RegionDivide` areas
  of its spawn (A x 0–10 / y 0–9, B x 0–10 / y 5–14, C x 6–16 / y 0–9, D x 6–16 /
  y 5–14). (1,1) is in A only; the ghosts spawn in C, B and D.

## Source rules ported without runtime observation

- `PacManMode.end`: a ghost returns after `reborn` (1 s); the player's death removes
  the robot and loses. `timeOut` is a loss. `judgeWin` wins once `eatNum` reaches the
  coin total; `CoinProp.eatProp` and `deleProp` both add to it.
- `countScore`: coins × 10, plus remaining seconds × 10 and the difficulty bonus on a
  win.
- `timePassed`: after 10 s, two random pickups every 15 s, none in Magic Library.
- Easy puts a shield on the player's spawn (`mapLoadOver`).
- `AbstractBomb.hitRobotUnderPoint` skips `AIRobot`s in Pac-Man, so blasts and flames
  never hurt ghosts.
- `InvincibilityCommandChain`: invincibility lasts 5 s (175 frames) in Pac-Man.
- `StateFollow`: no follow while any robot in the area is invincible; during a walk
  it gives up when any robot turns invincible, the target leaves the areas, or the
  planned cell no longer lines up with the target within flamer range.
  `StateFree`/`StateEscape` add coin cells to the free cells.

## Port

`scripts/simulation/modes/pac_man_mode.gd` holds the mode; the round gains
`pickup_removed`, `destroys_pickups`, `bomb_hits` and `invincibility_ticks` hooks.
Ghost follow and manager areas are in `ai_controller.gd`; perception reports coins
separately. A Pac-Man level loads the set's `_PacMan_` layouts. `tests/pac_man_check.gd`
covers each rule and checks that Hard ghosts catch an idle player standing in their
area.

The player catching ghosts was not observed; the port uses the shared invincibility
contact. Ghost decisions were not traced call by call.
