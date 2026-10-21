# Edition 5 Green Zone

Runtime observation, 2026-10-21, for [#68](https://github.com/Kurak0oo/bomb-it-5/issues/68).
Static rules are in [modes and flow](edition-5-modes-and-flow.md#modes).

## Method

Linux reference player as in the [stage openings](edition-5-stage-openings.md).
[`green-zone-cinema-long`](../../tools/reference_player/cases/modes/green-zone-cinema-long.json)
enters Green Zone on Cinema, Normal, leaves the player idle and captures every 525
frames for about 16,000 frames. Each capture's flag cell comes from the grid's
platform slot: [summary](reference-2026-10-21/green-zone/summary.json).

## Findings

- No soft blocks at any point (`box` 0 for Green Zone).
- Every robot carries the hammer (`sinker`) as its base action; picked-up weapons
  replace it, as in Kill.
- 14 distinct flag positions, all within x 3–14 and y 3–12, matching
  `containerMove(map, 2, 2, 2, 2)`; the flag moves after each capture.
- The HUD counts flags out of 10. The player's speed stat reads 3 (move speed 1.8)
  and Normal AIs read 2 (1.7), matching the rules XML.
- Holders show progress bars over the flag
  ([capture](reference-2026-10-21/green-zone/green-zone-capture.png)); robots
  contest it with hammers and respawn at their spawns.
- After about 16,000 frames the AIs had 7, 3 and 5 flags and the idle player 0
  ([capture](reference-2026-10-21/green-zone/green-zone-16000-frames.png)); the
  level had not ended. The idle player was killed once.

## Port

`scripts/simulation/modes/green_zone_mode.gd`: at map load a flag on an empty floor
cell inside the two-cell margin plus two random pickups; robots on the flag gain 1
progress per tick and others lose 1 (bars vanish at 0); 105 ticks (`flag` 3 × 35)
capture it for one point; the flag moves after 105 ticks (TweenMax's 3 s, as
simulation ticks) and the mode then judges: a human at 10 wins, an AI at 10 loses.
Timeout compares flags with ties to the human. Hammer base action, 35-tick respawn,
death scatter, player speed 1.8, the GreenZone drop table and timed pickups after
10 s. AI gains StateFlag (walk to a visible flag) and StateDefence (hold it, leave
when in danger, strike rivals in line). `tests/green_zone_check.gd` covers each rule.

With the player idle, the port's Normal AIs capture 7–16 flags in 6,300 ticks over
four seeds, faster than the observed 15 in about 16,000 frames; AI decisions were
not traced call by call.
