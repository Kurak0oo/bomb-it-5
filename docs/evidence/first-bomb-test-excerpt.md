# Source-verified excerpt for the first bomb checks

Prepared 2026-10-18 for the accepted headless bomb slice. This is a test-only excerpt of the recovered CinemaStage1 board, not a replacement production map or certification of the full randomized starting board.

## Source and cells

Build identity is the publisher edition 5 SWF, SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`; see [provenance](edition-5-input-and-timing.md). The source records are the [CinemaStage1 static template](observations/swf-v1.6.1/maps/CinemaStage1.txt) and the [first-board transcription](observations/swf-v1.6.1/play/first-board.md), whose rows 0–2 are high confidence. The restored [full-colour frame 697](../../.scratch/edition-5-research/observations/swf-v1.6.1-supplement/keyframes_fullcolour/first_board/f000697.png) was visually inspected during preparation.

Use original coordinates x=0–5, y=0–2:

```text
   012345
0  ######
1  #..sss
2  #.##s#
```

`#` is solid, `s` is a present soft block, and `.` is floor. The original spawn at (1,1) is floor for collision purposes. All soft cells shown here are present in the captured start; do not infer occupancy of any omitted cell. Outside the excerpt is outside the test board, not additional recovered floor.

## Fixture conditions and expected blast

Actors in tests can be initialized on the floor at (1,1) or (2,1). A test actor at (2,1) is a controlled initial condition, not a claim that the original round spawns there. Tests can likewise initialize source-supported bomb power/capacity without implementing their pickup mechanics.

For a bomb centered at (2,1) with power one, the blast covers (2,1), (1,1), and (3,1). The solid cells (2,0) and (2,2) stop the vertical rays and receive no flame. The soft block at (3,1) breaks; (4,1) and (5,1) remain. With power two, the ray still stops at (3,1), and the left ray stops at the solid (0,1). These expectations combine the literal source cells with the [recovered ray/block rules](edition-5-gameplay-phases.md); they are worked fixture cases, not new runtime observations.

Newborn countdown eligibility and input-versus-expiry ordering follow the accepted new-game adaptations in [DESIGN.md](../../DESIGN.md), not a claim of frame-exact SWF parity. Drops, actor damage/movement, animation, AI and complete-board certification remain outside this slice.

Implemented on 2026-10-19 in the [headless bomb simulation](../../scripts/simulation/bomb_simulation.gd). The [public-interface checks](../../tests/bomb_simulation_check.gd) use these literal fixture cells and worked blast expectations, alongside the accepted batching rules and real scheduler integration. Ordinary-bomb chaining follows the separately source-supported same-tick behavior in the phase record; overlap lifetime and broad simultaneous-blast parity remain unclaimed.
