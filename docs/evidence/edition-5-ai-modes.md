# AI in every mode and difficulty (#84)

Authority build `agame-bomb-it-5-zh-fix.swf` (sha256 `718c04c7…0408a2`). Runtime from the
patched reference player built on Linux (`tools/reference_player/build.sh`; its `events` and
`focus` commands) on 2026-10-29. Static source from the FFDec 26.3.0 script export. This
extends the Normal Arcade work in [AI runtime probes](edition-5-ai-runtime-probes.md) and the
[trace plan](edition-5-ai-trace-plan.md).

## Traces

`tools/reference_player/cases/ai-modes/make_cases.py` writes one case per mode and
difficulty (12 in all). Each case uses original menu inputs only:

- seed 2, Cinema, 3 enemies;
- the mode card and difficulty clicked at their measured positions;
- 420 frames of play (702–1141) with no human input.

Each run records:

- call events for the whole `zlong.bombit5.gameengine.ai` package, with no event loss;
- a focused snapshot at the opening and every 70 frames.

`summarize.py` reduces each run to:

- each AI's live profile (answer time, find range, ordered states and their `StateSettings`);
- the decision cadence;
- the transition checks made and passed per state;
- the states entered;
- the path searches.

The result is [summary.json](reference-2026-10-29/ai-modes/summary.json). `fixture.py` writes the
live profiles to `tests/fixtures/ai-profiles-traced.json`. Raw events and snapshots stay in
`.scratch/edition-5-research/reference-runs/ai-<mode>-<difficulty>-01/`.

Run it with:

```
python tools/replay_reference.py --player .scratch/edition-5-research/ruffle-runtime/target/ci/probe --observe --focus --case tools/reference_player/cases/ai-modes/ai-kill-normal.json --output .scratch/edition-5-research/reference-runs/ai-kill-normal-01
```

| Mode / difficulty | Answer ms | Range | Checks passed / made (per state) | Entered |
| --- | --- | --- | --- | --- |
| Arcade easy | 30 | 5 | Attack 0/85, Evade 0/85, GetItem 6/85, Box 12/79, Free 56/67, Escape 0/11 | Free 52, Box 24, GetItem 6 |
| Arcade normal | 20 | 6 | Attack 0/93, Evade 0/93, GetItem 2/93, Box 13/91, Free 64/78, Escape 0/14 | Free 59, Box 26, GetItem 2 |
| Arcade hard | 20 | 7 | Attack 0/99, Evade 0/99, GetItem 0/99, Box 11/99, Free 70/88, Idle 0/18, Escape 0/18 | Free 69, Box 22 |
| Battle Royale easy | 30 | 5 | Attack 2/42, Evade 0/40, GetItem 3/40, Box 20/37, Free 14/17, Idle 0/3, Escape 1/3 | Free 20, Box 26, Attack 4, GetItem 3, Escape 1 |
| Battle Royale normal | 20 | 6 | Attack 1/49, Evade 0/48, GetItem 6/48, Box 30/42, Free 9/12, Idle 0/3, Escape 0/3 | Free 19, Box 34, GetItem 5, Attack 2 |
| Battle Royale hard | 10 | 7 | Attack 4/47, Evade 0/43, GetItem 7/43, Box 32/36, Free 1/4, Idle 0/3, Escape 0/3 | Free 14, Box 32, GetItem 7, Attack 6 |
| Pac-Man easy | 2 | 8 | Follow 0/47, Escape 0/47, Free 36/47 | Follow 42, Free 20 |
| Pac-Man normal | 1 | 9 | Follow 0/49, Escape 0/49, Free 35/49 | Follow 42, Free 17 |
| Pac-Man hard | 0 | 10 | Follow 0/47, Escape 0/47, Free 37/47 | Follow 40, Free 17 |
| Green Zone easy | 30 | 5 | Flag 7/26, Defence 9/19, Attack 1/10, Evade 0/9, GetItem 2/9, Box 0/7, Free 5/7, Escape 2/2 | Defence 12, Free 9, Flag 6, Attack 2, Escape 2, GetItem 1 |
| Green Zone normal | 20 | 6 | Flag 8/26, Defence 10/18, Attack 0/8, Evade 0/8, GetItem 3/8, Box 0/5, Free 5/5 | Defence 12, Free 10, Flag 7, GetItem 3 |
| Green Zone hard | 10 | 7 | Flag 8/25, Defence 15/17, Attack 1/2, Evade 0/1, GetItem 0/1, Box 0/1, Free 1/1 | Defence 18, Free 7, Flag 6, Attack 2 |

"Entered" counts include returns to the default state. Pac-Man's default is Follow, which is
why Follow is entered even though its check never passed: the human never shared a ghost's
manager areas in these runs.

## Findings

- **Profiles.** Every AI in a run had the same live profile. All twelve match the replica's
  `ai_profiles.gd`: answer time, find range, default state, state order, percentages, weapon
  delay and advance chances. `tests/ai_trace_check.gd` compares them to the traced fixture.
  The `hasWeapon`/`target` filters (Battle Royale Attack `-bricker|-throw`,
  `player1|phip`) are kept in the fixture for reference.
- **Answer time (`getTimer`).** `AIControl.update` computes `_time = getTimer() - _lastTime`
  with `_lastTime` still 0, and never resets `_time`. In every trace, each AI's first selected
  update runs no perception and every later one does, even at answer time 0. The cached
  value is the player's whole running time, menus included. The replica used round ticks and
  could wait one more opportunity at 30 ms. It now marks the AI ready on that first
  opportunity.
- **Cadence.** Exactly one `AIControl.update` per frame in every mode, rotating through the
  living AIs. This matches the existing port.
- **Flag and Defence.** `StateFlag.checkTransitions` and `StateDefence.checkTransitions` draw
  no random number; their `precentage` is never read. Flag returns null on the flag cell and
  otherwise takes `getBestPosition(flagArr, 100)`. Defence holds while the robot is on a
  live Flag. The traces show Flag checked first and Defence checked only when Flag fails. The
  replica drew a number and applied a chance for both; it now does neither.
- **Defence attack.** `StateDefence.update` bombs its own cell when another robot shares it
  (`map.getRobot` has more than one robot). Otherwise it attacks a rival in line within
  weapon range with a clear line. The replica lacked the shared-cell bomb; it is added.
- **Follow.** `StateFollow.checkTransitions` draws its gate, collects the humans in its
  manager areas (none if any robot there is `RobotState.INVINCIBLE`), draws one at random,
  and returns itself even when `searchAttackPosition` finds no cell. `update` then finishes
  at once when every bomb is out or no position was found. The replica skipped Follow in
  both cases and moved on to Escape or Free. It now enters Follow and walks nowhere.
- **Invincibility.** Only the invincibility pickup sets `RobotState.INVINCIBLE`
  (`InvincibilityProp.changeStage`). Spawn protection (`InvincibilityCommand`) does not. The
  replica's Follow treated spawn protection as invincible; it no longer does.
- **Escape and Idle.** These match the existing port.
  - `StateEscape` draws its gate, then passes on a dangerous cell or when any other robot is
    INVINCIBLE. It picks a free (Pac-Man: free or coin) cell at Manhattan distance more than
    4 from every invincible robot (`getBestPosition(…, 1500, true)`).
  - `StateIdel` passes only below a percentage of 0, so it never runs, but it still consumes
    its draw. The traces show Idle checked and never passed.

## Remaining differences (not measurable here)

- **Random draws.** `Math.random` in the original and the replica's seeded generator never
  produce the same numbers. Draw counts and order per decision follow the source. Exact
  choice sequences are not comparable.
- **Wall-clock timers.** TweenMax and `setTimeout` delays (the 0.3 s escape retry, the 2 s
  action timer, the 0.5 s idle) run on host time in the original. The replica converts them
  to steps.
- **Defence line check.** A blocked vertical line `continue`s past the horizontal check for
  that rival. Positions where a rival is in line on both axes are impossible, so this cannot
  be observed.
- **Emulation.** The traces come from Ruffle, not the native Flash Player, and dense event
  capture costs host time. The checks compare structure and decisions, not timing.
