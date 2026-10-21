# Edition 5 Kill mode (Battle Royale)

Runtime observation, 2026-10-21, for [#67](https://github.com/Kurak0oo/bomb-it-5/issues/67).
Static rules are in [modes and flow](edition-5-modes-and-flow.md#modes).

## Method

Linux reference player as in the [stage openings](edition-5-stage-openings.md). Cases
[`kill-cinema-idle`](../../tools/reference_player/cases/modes/kill-cinema-idle.json)
(captures every 350 frames for a minute) and
[`kill-cinema-long`](../../tools/reference_player/cases/modes/kill-cinema-long.json)
(every 1,050 frames until the ending) enter Kill on Cinema, Normal, and leave the
player idle. [`summarize.py`](../../tools/reference_player/cases/modes/summarize.py)
reads each capture's players and robots: [summary](reference-2026-10-21/kill/summary.json).

## Findings

- Every robot's `_baseWeapon` is `KillModeWeapon` and its model weapon `sinker` (the
  hammer); picked-up weapons (`thrower`, `boxing`, `shotgun`, `fireball`) replace it
  and the hammer returns afterwards.
- The opening rolls soft blocks at 0.55 (54 and 55 of 104 candidates, stored
  `unfixedBox` 0.55); the AIs smash most of them early.
- A killed robot shows `dead`, then disappears (`isExist` false) and reappears at
  its own spawn corner in the `Invincible` state (InvincibilityCommand, 81 frames).
- The HUD shows each player's kills out of 10. After about 2,100 frames the AIs had
  3, 3 and 4 ([capture](reference-2026-10-21/kill/kill-60s.png)); the idle player was
  never attacked. At about 5,250 frames an AI reached 10
  ([capture](reference-2026-10-21/kill/kill-ai-ten.png)) and the level ended
  "LEVEL 1 / 5 FAILED…" ([capture](reference-2026-10-21/kill/kill-failed.png)).
- `_killNum` and `_levelPoint` slots stay 0 in the focus state: the game keeps them in
  `memorycrypto`, so the HUD, not the slot, is the observed kill count.
- `pastTime` follows the host clock (`Date` seconds): only 21 seconds had passed
  after 21,000 emulated frames. The accepted adaptation counts simulation time.

## Port

`scripts/simulation/modes/kill_mode.gd`: unlimited hammer for everyone, 35-tick
respawn at the spawn with 81 ticks of protection, kills as points, own-attack deaths
cost a point, first human to 10 wins and an AI at 10 loses (judged after the death
animation, human first), timeout by kill comparison with ties to the human, the
KillMode drop table, 0.55 soft blocks, timed pickups, and the level score (kills ×
100 plus time and difficulty bonuses on a win). Non-Arcade deaths scatter collected
power-ups and up to two kept weapons (`RobotDeadCommand.spitProp`). Kill AI targets
every robot (`allAttactRobot = AbstractRobot`). `tests/kill_check.gd` covers each rule.

With the player idle, the port's Normal Kill AIs end the level in 2,659–4,214 ticks
over four seeds, also by an AI reaching 10 and also without attacking the idle
player. Kill AI decisions were not traced call by call; only the Normal Arcade
profile has that recovery.
