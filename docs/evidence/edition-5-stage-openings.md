# Edition 5 stage-set openings

Runtime observation, 2026-10-21, for [#58](https://github.com/Kurak0oo/bomb-it-5/issues/58):
which layout a round uses, how soft blocks are rolled and what each set's opening
contains. It confirms the static reading in [modes and flow](edition-5-modes-and-flow.md#soft-blocks-correction).

## Method

- Authority SWF SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`.
- Player: the canonical fourteen-patch reference player, built on Linux with
  [`build.sh`](../../tools/reference_player/build.sh) (Ruffle `45366370…`, all
  research features, Mesa lavapipe Vulkan). Probe SHA-256
  `5ee25f8e11e161e360a22103aca4b8edb58d7d0b4db6234c001b8fcbd72c5ef0`. The
  unchanged [normal-arcade case](../../tools/reference_player/cases/normal-arcade.json)
  replays through frame 824 with all 12 captures.
- Cases: [stage cases](../../tools/reference_player/cases/stages/) are input only:
  menu → Game Settings (Arcade, 1 player, 3 enemies, 5 levels, chosen arena,
  Normal) → character → opening board, captured with `--observe --focus`.
  36 runs use original-RNG seeds 11–66 per set; 12 runs are unseeded (Cinema and
  Luxury Shop, six each).
- Assessment: [`assess.py`](../../tools/reference_player/cases/stages/assess.py)
  reads each cell's Grid slots (1 box, 9 fixedBox, 11 unfixedBox, 13 midBox,
  6 platform) and matches the opening against the set's three recorded templates.
  Results: [seeded](reference-2026-10-21/stage-openings/seeded-assessment.json),
  [unseeded](reference-2026-10-21/stage-openings/unseeded-assessment.json).

## Findings

- **Templates hold exactly.** All 48 openings match one recorded layout with zero
  mismatches: every template solid and center cell is blocked, soft blocks occur
  only on `unfixedProp_r` candidates, and nothing else is blocked.
- **Soft-block chance is 0.6 in Arcade.** Every candidate cell's stored
  `unfixedBox` is 0.6 at runtime. Unseeded openings fill 789 of 1,300 candidates
  (0.607). Seeded runs give 0.577 and only ever pick layouts 2 and 3; small
  original-RNG seeds produce correlated early draws, so seeded runs are not used
  for rates. Unseeded runs pick all three layouts
  ([Cinema layout 1](reference-2026-10-21/stage-openings/cinema-layout1-unseeded.png)).
- **Spawn corners start empty.** No template places a block on a spawn or its two
  neighbours.
- **Birthday Party layout 3 is an empty arena.** Its template has only the outer
  wall, and the game plays it that way: no center, no blocks, no toy hands
  ([capture](reference-2026-10-21/stage-openings/birthday-layout3-empty.png)).
  It was chosen in four of six seeded runs. Ported as recorded.
- **Platforms per set.** The focus state's platform objects are Portal (Cinema),
  Crocodile (Zoo) and ToyHand (Birthday Party layouts 1–2). Candy Factory belts
  and sliding platforms and Magic Library spellbooks are created by other objects
  and are not in the platform slot; their tickets observe them directly.
- **Luxury Shop has no special tiles** in any layout
  ([capture](reference-2026-10-21/stage-openings/luxury-layout2-unseeded.png)).

Selected captures: [Zoo](reference-2026-10-21/stage-openings/zoo-layout2.png),
[Candy Factory](reference-2026-10-21/stage-openings/candy-layout2.png),
[Magic Library](reference-2026-10-21/stage-openings/magic-layout2.png),
[Birthday Party](reference-2026-10-21/stage-openings/birthday-layout2.png).
Captures are view-only research context.

## Port

`assets/maps/layouts.json` holds the 36 used templates verbatim (instance names per
cell). `scripts/simulation/layouts.gd` rolls them: template solids and the center
are solid, `unfixedProp_r` cells are soft with the mode's chance, portals pair by
name, set-specific tiles stay marked features that block until their ports.
Pac-Man layouts never roll soft blocks (`setDataByPacMan`). Layout choice and the
roll use one RandomNumberGenerator seeded from the session seed; the original
consumes `Math.random` in its own order, so individual boards are not reproduced,
only the rules. `tests/layout_check.gd` covers the rules.

## Limits

- Ruffle is an emulator; layout and roll rules are read from the original's own
  stored state, not inferred from pixels.
- Only Arcade on Normal was run. Other modes' chances (Kill 0.55, none in Green
  Zone and Pac-Man) remain static readings until their tickets observe them.
