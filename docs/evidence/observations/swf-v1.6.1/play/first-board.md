> Imported Dots record; claims are retained as delivered. See the [integration assessment](../../../edition-5-play-observations.md) for verification, missing files, and authority limits. Original relative paths in code spans refer to the [unaltered bundle](../../../../../.scratch/edition-5-research/observations/swf-v1.6.1/play/first-board.md).

# First board (frame-exact, harness run 1)

- **Build:** `bomb-it-5-zh-fix.swf` (SHA-256 718c04c7…08a2), v.1.6.1. Player: Ruffle `ruffle_core` commit `45366370ed7d1a59c89aa3cf7b765c7a274407cd` (2026-10-16), custom headless probe harness (`tools/ruffle-probe/`), wgpu Vulkan on llvmpipe (Mesa 25.0.7), 700×510 offscreen, no audio.
- **Setup:** boot → PLAY (click frame 301) → A10 splash → main menu (~frame 541) → START (frame 541) → GAME SETTINGS: ARCADE, PLAYERS 1, ENEMIES 3, LEVELS 5, ARENA RANDOM, DIFFICULTY NORMAL → NEXT → character select, first character (blue robot, P1) → START (clicked before frame 637).
- **Frames:** loading screen ("R_ARCADE … Place your bombs tactically to kill all enemies!") frames 637–696; **first gameplay frame = 697** (60 frames = 1.71 s at 35 fps after START). No input was sent between START and frame 697.
- **Image:** `play/frames/p00_first_board/f000697_first_gameplay_frame.png` (and `f000696_last_loading_frame.png`).

## Arena
**Cinema** (red cinema seats, stage spotlights, 3D glasses, film clapboards, a central "cinema screen" building with three stars). The layout matches **`maps/CinemaStage1`** (portals at (8,1), (4,7), (12,7), (8,13)). [observed]
HUD at frame 697: LEVEL 1/5, TIME 180, P1 hearts 3 / bombs 1 / power 1 / speed 1 / score 0; the three AIs show 1/1/1/1/0. [observed]

## Grid (x = 0..16 left→right, y = 0..14 top→bottom)
Legend: `#` solid (skin: red seat **or** spotlight; both are on `#` map cells only) · `s` soft block present (skin: 3D glasses **or** clapboard) · `.` empty floor · `P` spawn with a robot on it · `O` portal · `C`/`H` the 3×3 centre building (cols 7–9, rows 6–8).

```
   01234567890123456
 0 #################
 1 #P.sss..Osss.s.P#
 2 #.##s###s###s##.#
 3 #s..s.ss......ss#
 4 ##s###.#s#.###.##
 5 ##.ss.sssssss.s##
 6 #.s#.#sCHH.#s#s.#
 7 #s##O..HHH..O##s#
 8 #.s#.#sHHHs#.#ss#
 9 ##.sss..s.s....##
10 ##s###.#s#.###.##
11 #sssssssss..sss.#
12 #.##.###.###s##.#
13 #P.ssss.O.ssss.P#
14 #################
```
Spawns: P1 blue robot (1,1); purple witch-hat girl (15,1); orange feather-headdress character (1,13); white/red helmet (15,13). [observed]

How it was read: the board was read by eye from 2× crops with a cell grid fitted to a bomb dropped at (1,1) (bomb centre ≈ screen (208,62)) and to the outer walls. Sprites are drawn bottom-aligned and up to ~15 px taller than a cell, so a tall solid on row y+1 overlaps the lower part of row y. Rows 1, 2, 4, 10, 12, 13 and 14 are high confidence. In rows 3, 5, 6, 8, 9 and 11 a few `s`/`.` calls could be off by one cell [inferred]. Screen pitch is ≈30–32 px per cell (P1 left edge 197 → 227 → 259 at x = 1, 2, 3).

## Check against `maps/CinemaStage1.txt`
- Every `#` cell of the map shows a solid skin, and no solid skin sits on a non-`#` cell. [observed]
- Portals O, the centre building C/H and the four spawns are exactly where the map says. [observed]
- Every soft block sits on a map `s` cell. Some map `s` cells are empty: (6,1), (12,1); (2,3), (3,3), (5,3), (8,3)–(13,3); (6,4), (10,4), (14,4); (2,5), (5,5), (13,5); (1,6), (4,6), (10,6), (15,6); (6,7), (10,7); (1,8), (4,8), (12,8); (2,9), (6,9), (7,9), (9,9), (11,9)–(14,9); (6,10), (10,10), (14,10); (10,11), (11,11), (15,11); (4,12), (8,12); and (2,13), (7,13), (9,13), (14,13), which are `.` in the map anyway. This fits `unfixedProp_r` being created with probability 0.8 [source]. Row 3 is emptier than 0.8 predicts (9 of 15 empty). That is either chance or a misread of row 3 behind the row-4 sprites [unknown].
- **No mismatch** with the static map was found. [observed]
- In the other runs, after TRY AGAIN the arena re-rolled to **CinemaStage3** (run 2, portals (3,2)/(13,2)/(3,12)/(13,12), with popcorn/drink skins for soft blocks) and to **CinemaStage2** (run 3). That is consistent with "lost stage is retried, layout re-picked from 1..3" [source: `UIManager.gamePlay`, `AbstractMapData.data`]. [observed]
