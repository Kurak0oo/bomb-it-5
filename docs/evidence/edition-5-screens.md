# Original screens (#76)

Authority build `agame-bomb-it-5-zh-fix.swf` (sha256 `718c04c7…0408a2`). Sources:

- the FFDec 26.3.0 script export, for the UI classes;
- the FFDec SVG export of the page sprites, for positions;
- the reference capture of the main menu
  ([main-menu.png](reference-2026-10-19/mines/pause-teardown/main-menu.png)).

## Stage

`UIManager` sets `scrollRect = (0, 0, 700, 510)` on the UI container, so the original shows
only the 700×510 stage of each page sprite. Each `screen.<page>` sheet is cropped to that
stage. On the 1280×720 page it is drawn at 720/510 and centred
(`ScreenLayout.STAGE_FRAME = (145.9, 0, 988.2, 720)`). `UI_Dress Up` has a centred
registration and is not cropped. Its page keeps the native layout.

## Positions

`tools/measure_screen_art.py` reads each page sprite's first frame from the ignored SVG
export. For every named instance it composes the instance transform with the instance's
local bounds (its own sprite export), and prints stage and page rectangles. These are the
`slots` in `scripts/art/screen_layout.gd`:

- **Main menu:** `startGame`, `howToPlay`, `quality`, `sound`, `music`.
- **Game Settings:** `arcadeMode`, `killMode`, `collectMode` (Pac-Man), `paintingMode`
  (Green Zone), `enemies*`, `levels*`, `choose` with `mapMenu`, `easy`/`normal`/`hard`,
  `back`, `confirm`.
- **Character select:** `robotIcon0`–`robotIcon7`, `robotStage1`, `backBtn`,
  `setAvatarBt`, `startBtn`.
- **Controls:** `title`, `messenge`, `save`, `defaule`, `back`, `powerUps`, and the first
  column's caps inside `ctrlField` (`onePOneUp…Bomb` and their `…Mc` backgrounds).
- **Power-ups:** `back`, `controls`.
- **Score (`UI_LEVEL_COMPLETED_ONEP`):** `title`, `text_mode`, `bonus_txt`, `kill`, `time`,
  `difficulity`, `levelScore`, `total`, `dressUpBtn`, `nextLevel`/`restartBtn`.
- **Game over / Game complete:** `score`, `back`.
- **Pause:** `mainMenu`, `resume`, `quality`, `sound`, `music`.

Captions painted without an instance name (row labels, titles) sit on their painted text.
The widgets there are ghosts.

## As the original renders it

The sheets keep the original's text as drawn, including the exposed localization keys:
`R_BATTLE ROYALE`, `P_PAUSE`, `C_P1`/`C_P2`, `C_SAVE`, `C_RESET`, `C_POWER-UPS`,
`P_POWER-UPS`, `S_POWER-UPS`, `P_CONTROLS`, `1_ENEMIES KILLED`, `L_TOTAL SCORE` and
`G_TOTAL SCORE`.

Two details also match the running original:

- The main menu's closed dropdown at the top left. It is unnamed, and the reference capture
  shows it too.
- The version text `v.1.6.1`. `MainMenuUI` draws `Root.VERSION_NUM` at stage (650, 5) in
  black bold Tahoma 11, and the replica draws it there.

## Replica changes (Q3)

- **Removed from the sheets (`source.hide`):**
  - MORE GAMES (`moregames`) on the main menu, score, game over and game complete pages.
  - The P2 card and tag (`robotStage2`, `tagP2`). `CharacterSelectUI` hides these itself
    with one player.
  - The 2-player and zero-enemy options (`playersTwo`, `enemiesZero`).
- **SET AS AVATAR** stays as an inert button.
- **Live values** are drawn over plates whose colours are sampled from the sheet:
  - the chosen stage name in the ARENA field;
  - the key names on the first column's caps and the controls message;
  - the chosen robot on the P1 card;
  - the level title with its `[X]/[X]` filled, the mode and difficulty captions, the five
    score values and the total score.
  - On a lost level, the NEXT button shows TRY AGAIN. The original shows `restartBtn` there
    instead.
- **Highlights.** Selections (mode, enemies, levels, difficulty, robot) show as a ghost
  highlight over the painted option. The original switches the clip frame, and the sheet
  holds only frame 1.
- The 2-player key columns on the Controls page stay painted and inert.

## Not reproduced

These clip frames have no sheet of their own, so the frame-1 art stays:

- the score title's second frame (loss);
- `modePic` per mode;
- the `p1head` per robot.

The main-menu `PromoFlip` and star animations are also frame 1 only.

## Title and publisher screens

The SWF opens with the portal preloader (`UILoading`) and the publisher intro sprite
`Art_A10`, which has its own timeline sounds. Both are portal branding, like MORE GAMES and
the "Add to your site" link. The replica starts at the main menu, whose painted logo is the
title. The `© SPIL GAMES` and "Add to your site" text appear only because the pack's menu
sheet paints them. The link is not active.
