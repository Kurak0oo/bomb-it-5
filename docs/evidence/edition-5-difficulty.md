# Edition 5 difficulty

Runtime observation, 2026-10-21, for [#60](https://github.com/Kurak0oo/bomb-it-5/issues/60).
Source reading is in [modes and flow](edition-5-modes-and-flow.md#difficulty).

## Method

Same authority SWF and Linux reference player as the [stage openings](edition-5-stage-openings.md).
Cases [`arcade-cinema-easy|normal|hard`](../../tools/reference_player/cases/stages/)
take the input-only menu path to an Arcade Cinema opening on each difficulty, with
`--observe --focus`. Values read from the original's stored state:
[opening values](reference-2026-10-21/difficulty/opening-values.json).

## Findings

| | Easy | Normal | Hard |
| --- | --- | --- | --- |
| `MapMaster._propProb` (drop chance per broken block) | 0.6 | 0.5 | 0.4 |
| AI `findRange` / `aiAnswerTime` | 5 / 30 | 6 / 20 | 7 / 20 |
| Player `shieldObj` at the opening | set | none | none |
| Player HUD score at the opening | 100 | 0 | 0 |

- Easy's ShieldProp on the spawn is collected before play starts; the shield
  pickup scores 100 like any other ([capture](reference-2026-10-21/difficulty/easy-opening.png)).
- `dangePerceive` (0.9 / 0.95 / 1) is defined in the rules XML but no code reads it,
  and `AIControl.gameDiff` stays null at runtime. Neither is ported.
- The full AI state weights and delays per difficulty come from the rules XML
  (`scripts/simulation/ai_profiles.gd`). Runtime AI decisions on Easy and Hard were
  not traced; the Normal decision recovery remains the only traced profile.

## Port

`GameMode.drop_chance()` follows the difficulty; Arcade's `opening_pickups` puts a
shield on the human spawn on Easy; the difficulty bonus feeds the score screen; the
session's difficulty selects the AI profile. `tests/difficulty_check.gd` covers each row.
