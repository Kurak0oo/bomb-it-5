# Development: restart plan (2026-11-02)

The old development narrative, interview records, specs, ADRs and verification records
are archived under the `pre-restart` tag (`git show pre-restart:DESIGN.md`). This file is
the only status document; keep it under one page.

## Why we are restarting

- Early milestones worked: a small playable slice, played by the owner, with concrete
  findings (#10–#19). Source ports (`HitMove`, pause, frame engine, Date clock, audio
  rules) are trustworthy.
- Automated checks work well for logic and kept doing so. UI and art were closed the
  same way, although no check could judge them: menus were drawn at invented
  coordinates, original art was later overlaid with ghost buttons, and a new phone
  layout replaced the original game screen. Their checks only compared the layout
  tables with themselves, so misalignment passed, and nobody looked at the result
  before more work was stacked on top.
- Owner acceptance (#20, #21) never closed while scope kept growing on top.

## What we keep and what we drop

Keep: `scripts/simulation/` (round, scheduler, command boundary, HitMove, pause, modes,
AI), audio rules, `fidelity.gd`, the seeded Ruffle reference player and its recordings,
`docs/evidence/`, and the SWF extractor in `tools/art_pipeline/` as input for the
converter.

Drop: the native menu coordinates in `app.gd`, the ghost/plate overlay
(`screen_layout.gd`), the mobile gameplay layout (`replica_layout.gd`, `replica_hud.gd`,
`replica_scenery.gd`), the Art Workbench as a delivery path, and the 1280×720 window.
Code is removed by the checkpoint that replaces it, so the game keeps running between
checkpoints. Until then it is a placeholder, not a reference.

## Rules of work

1. **One checkpoint at a time.** One screen or one mode per checkpoint. No new ticket
   until the owner has accepted the previous one.
2. **Who closes what.** Logic closes on automated checks against the reference player.
   UI and art close only when the owner has confirmed them. Until then they count as
   placeholders behind an art slot or a generated scene, so replacing them touches no
   logic or layout code. The comparison loop only decides whether a screen is ready for
   the owner to look at.
3. **Generate, don't measure.** Positions, scales, button states and frame timing come
   from the SWF data (display list, placement matrices, AS3), not from screenshots or
   values typed in by hand.
4. **Translate, don't reinvent.** Port AS3 logic close to line for line, keeping the
   original class and method names, and cite the source method in a comment.
5. **Faithful first, phone later, at one scale.** The replica shows the 700×510 stage
   scaled to fit. Phone layout is a later step on top of a matching replica.
   - Everything is placed in stage units (32 px board pitch, 30-unit cells) and reaches
     the screen through **one** scale factor. A phone layout changes that factor and
     where the HUD and controls sit, never the art.
   - Sprites draw at their original registration point and scale, never fitted into a
     cell. Robots and tall props overlap the row above, as in the original.
   - Vector art is rendered once at the largest scale needed (3× covers phones, 4×
     tablets). Bitmap art stays at source resolution and is sampled once, source to
     screen. No AI upscaling or colour remapping: details and colours must match.
6. **Short docs.** README, AGENTS.md, this file, GLOSSARY.md. Evidence is read only when
   a task needs it.

## The comparison loop

`tools/compare.sh <case>` wraps `tools/compare/compare.py` (macOS bash 3.2 and Linux).
It has two halves, so agents without the SWF can still run the node diff:

1. `record` (owner's Mac: SWF, reference player built by
   `tools/reference_player/build.sh`, Ruffle on Metal): run the case with its `seed`,
   scripted input and stepped frame count on the 700×510 stage; write the display-list
   dump as goldens in `tests/goldens/<case>/` (committed) and the captures to
   `.scratch/compare/<case>/reference/` (local).
2. `check` (anywhere with Godot 4.5; `GODOT=...`, xvfb on headless Linux): run the
   same case in a 700×510 SubViewport at the SWF frame rate, diff nodes against the
   goldens, and, where local captures exist, write SSIM, regional ΔE and a heatmap.

`tools/compare.sh main-menu` records when it can, then checks. `all` checks every case
in `tools/compare/cases/`; `accept <case>` sets the floor. Diff logic has unit checks:
`python3 -m unittest discover -s tools/compare`.

Nodes are matched by display-list path (instance name, or `@depth` for unnamed
children), never by runtime object id. Generated Godot nodes carry that path as the
`swf_path` meta; `swf_baked` marks a node that draws its whole SWF subtree. Gameplay cases use the
player's focus dump (actors, bombs, cells) instead of the display list.

Pass means **highly alike**, not identical: positions within 0.5 stage units, scale
within 0.1%, same frame and visibility; SSIM ≥ 0.98 and no region off by more than
ΔE≈2. When the owner accepts a screen, its scores become that case's floor. Every case
runs on every change.

## Checkpoints

| # | Checkpoint | Done when |
| --- | --- | --- |
| 0 | Archive old docs, tag `pre-restart`, retire `original-replica` into `main`, delete stale branches, close superseded issues | Repo has the short doc set |
| 1 | Comparison loop for one static screen (main menu); macOS-safe reference build; same-RNG check | Node diff and pixel diff run from one command |
| 2 | Render bake-off (Ruffle symbol render at 3× vs FFDec→resvg vs FFDec PNG), then display-list → Godot scene converter for the title/loading screen (`UiLoading`) and the main menu, which the case reaches through it | Both captures pass, menu buttons (timeline clips) show up/over/down, owner accepts |
| 3 | Remaining menus: Game Settings, character select, How to Play, results | Each screen passes and owner accepts |
| 4 | Gameplay screen at original layout, Cinema set | Frame-matched cases pass, owner plays it |
| 5 | Each mode × stage set against reference recordings | Diff passes per case, owner plays each mode |
| 6 | Phone fit and touch controls on top of the faithful screens | Owner plays on device |

Known for checkpoint 2: the art pipeline auto-installs Java only via apt (on macOS,
`brew install openjdk`).

## Branches and structure

Separate art, logic and UI by folder and interface, on one trunk.

- `main` is the single trunk. Feature branches last one checkpoint and merge within days.
- Retired at checkpoint 0: `original-replica` (fast-forwarded into `main`),
  `claude/adoring-gates-9eckgx` and `claude/pensive-volta-a8va4o` (no unique commits),
  `claude/bomb-it-5-art-pipeline-do9896` (new-art redesign work, kept as tag
  `archive/art-pipeline`).
- `scripts/simulation/` is logic: no nodes or art, driven by commands and snapshots.
- `scripts/ui/` holds screens and the HUD: reads snapshots, sends commands, takes layout
  from generated scenes.
- `assets/` holds art references only. Original art stays in the ignored local pack.
- Product variants (faithful replica vs. Douyin build with new art) are build profiles
  (`fidelity.gd` plus an art pack choice), not branches.

## Status

Checkpoint 0 is done: accepted by the owner on 2026-11-02; tags `pre-restart` (23d1d73)
and `archive/art-pipeline` (dc4e49a) are on GitHub and the four retired branches are
deleted (verified 2026-11-04).

Checkpoint 1 is done: accepted by the owner on 2026-11-04. The reference player's
`display` command, `tools/compare.sh` (record/check), and the Flash `Math.random` port
(`scripts/simulation/avm_random.gd`, matching 48 recorded seeded draws) are in place.
Goldens for `main-menu` (title at frame 301, menu at frame 541, 35 fps) were recorded
on the owner's Mac and checked from a machine without the SWF. The menu's buttons are
timeline clips, not Flash buttons, so their states show as clip frames.

Checkpoint 2 is done: accepted by the owner on 2026-11-04. Record of the work:

 Owner decisions on 2026-11-04:

- **Route A for the replica's art:** pieces are rendered by the reference player itself
  (`piece PATH FILE.png` at `--scale 3`), with their masks, filters and blends. The
  bake-off on the real menu showed FFDec-based pieces (B, C) losing masks (110 masked
  placements in the SWF), filters and blends (56 nodes on the menu).
- **Pixel pass line lowered, comparison kept at 1×:** SSIM ≥ 0.95 and region ΔE ≤ 8,
  from route A's measured 0.9676 / 7.44. The owner judges the rest from the heatmap.

The display dump records mask relationships (`clip_depth`, `mask`, `scroll_rect`),
filter-inclusive `render_bounds` and the stage colour; a name shared by siblings becomes
`name@depth`, so every path is unique.

Converter v1 (static screens) is in place:

- `tools/convert/layout.py` turns a golden into `scenes/swf/<screen>.json` (committed,
  generated): groups down to the screen's root clip and its interactive instances, a
  *piece* for everything else, timeline masks as undrawn nodes. Interactive instances
  and their actions are the port of `UILoading` and `MainMenuUI` (sources in the file).
- `scripts/ui/swf_screen.gd` builds the screen in Godot: one Node2D per layout node at
  its stage matrix, the whole stage fitted to the window by one scale factor, piece art
  from the local pack `original/screens/<screen>/` (premultiplied alpha, resampled once
  with Lanczos from 3× to the exact screen scale, redone on resize), an
  outline where the pack is missing, hit areas over interactive instances.
- `tools/convert/record_screen.py` records, from the reference player: each screen's
  timeline (every node's stage matrix, visibility, clip frame and character from the
  frame the screen opens, through one loop period after the capture), its interactive
  states (hover, press, and each click of a switch), and the art (every piece and
  sequence frame at 3×, self-checked against the player's own frame).
- The app opens on the title; PLAY → menu; START, HOW TO PLAY and the quality, sound
  and music switches keep their actions; MORE GAMES is drawn but inert.
  `-- --screen <name>` opens one generated screen for review.
- Node diff here (no SWF): menu 76/76, title 90/90 apart from the old golden's
  duplicate `bodyMc`, which re-recording fixes. Verified end to end on a Ruffle test
  SWF: pieces recompose to the reference frame exactly; Godot drawing them scores SSIM
  0.969 against the 1× original.

Owner, on the Mac: `RESET=1 tools/reference_player/build.sh`, then `tools/convert.sh`
(record, layout, pieces, check). Commit `tests/goldens/` and `scenes/swf/`; `original/`
stays local. Then review with `-- --screen title` / `-- --screen menu` or by playing.

Owner review of v1 (2026-11-04): the menu looks right. Owner edits, kept in
`tools/convert/owner_edits.json` and treated by the comparison as expected differences
(removed nodes and moved regions are left out of the pixel score):

- title: remove the portal preloader box in the middle;
- menu: remove the promo strip of other Bomb It games (bottom left), MORE GAMES,
  "Add to your site" and the language bar (top left); move HOW TO PLAY down half a
  button pitch (half the way to MORE GAMES' place), to balance START.

Converter v2 (behaviour), 2026-11-04: the layout splits a part whose inside animates
into its children while they stay the same, and makes it a frame sequence otherwise.
Godot plays the recorded tracks and sequences on the 35 fps clock (frame-locked in the
comparison loop), opens each screen as many frames late as the original, shows the
recorded hover and press frames, and shows the switches' frames from the session's
settings. Verified here on a generated test SWF (a tween and a frame-by-frame swap):
Godot at frame 30 matches the reference exactly (nodes 6/6, SSIM 1.0).

First full v2 run on the real SWF (2026-11-04, in the cloud session; the owner provided
the SWF, kept in the ignored `.scratch/`): title opens at frame 2, menu 226 frames after
PLAY (the original's publisher intro), both loops capped at 600 frames. Findings fixed:
START, HOW TO PLAY and PLAY act on press (the original's screen is gone after the press);
blended pieces (the menu's HardLight stars) render in their own colours and Godot blends
them against what lies below (`scripts/ui/swf_blend.gdshader`); the self-check leaves
owner edits out. Owner edits add: skip the intro pause in play (the comparison keeps the
original timing). Result: pieces recompose to SSIM 0.99998 (title) / 0.99996 (menu);
node diff with animation 185/185 and 158/158; Godot vs original SSIM 0.990 / 0.970,
max region ΔE 5.7 / 5.2: PASS.

Checkpoint 3 is in progress: Game Settings, character select, How to Play (controls and
power-ups) and the results screens, converted the same way.

Game Settings (2026-11-04): `GameSettingsUI` and `ToggletButton` are ported
(`scripts/ui/game_settings_ui.gd`, `toggle_button.gd`, AS3 listeners via `swf_events.gd`),
quirks included (Cinema on `choose` frame 5 in `initData` but 2 in `stagesHandle`; the
five-levels button sets one level). Every widget frame is rendered by the reference
player (`piece PATH FILE FRAME`); the stage dropdown, off the display list until opened,
comes from a second capture. Generic fixes from this screen: groups are split down to
every blended node unless a group composites on its own (blend or filters); animated
widgets play their recorded frame as a sequence; alpha is part of the timeline; a screen
made by a click starts on the next frame, as in the original; the pixel pass line is the
measured 3×→1× resampling ceiling minus 0.02 (this screen's thin borders cap it at
0.949). Result: settings and dropdown nodes 116/116 and 126/126, pixels within the
ceiling; title and menu still pass. Owner review: accepted, with the 2-player option removed (owner edit).

Character select (in progress): `CharacterSelectUI`, `ClothesPanel` and `Button` are
ported (a subagent did the port; `scripts/ui/character_select_ui.gd`, `clothes_panel.gd`,
`button.gd`). The case selects each of the 8 robots in turn; every robot's display and
clothes panel (`Art_clothPanel<N>`, made from the library on selection, addressed by its
class) comes from its own capture, with its own recorded loop. New pipeline pieces:
children recorded on different frames of one clip follow that clip's frame (robotMc
shows robot<N> on frame N+1); a widget that is also a group (robotStage1) draws its
frames without the parts laid out inside it (`piece … FRAME HIDE`); instances are
addressed by path relative to the screen root; live text (`set_text`) is drawn in the
SWF's embedded fonts (`record_screen.py fonts`) with each TextField's recorded format.

How to Play and Power-ups (2026-11-04): `HowToPlayUI` and `PowerUpsUI` are ported
(subagent). Both captures pass: nodes 135/135 and 91/91, pixels at the resampling
ceiling (SSIM 0.9747 / 0.9765). Generic fixes from these screens:
- a group Flash composites on its own (filters, a blend) that animates inside plays as a
  sequence instead of being split, so its filter pass survives (p2head's outline);
- each piece is padded by a few transparent pixels before resampling so its texels land
  on the screen's pixel grid, and the fit offset is whole pixels (`SwfScreen._pads`);
  pieces no longer blur by a third of a pixel, and every earlier screen moved up to its
  ceiling (menu SSIM 0.9416 → 0.9796);
- a case action may carry `godot_command` where an owner edit moved its target (the menu
  click on the moved HOW TO PLAY); the goldens' case hash ignores `godot_*` fields;
- the reference player's `piece` deadlocked on a path absent at that frame (the error
  branch re-locked the player); it now writes the `missing` marker;
- owner edit: How to Play's two 2-player key columns are removed (the empty right panel
  is part of one shape with the others and stays; owner to review);
- a piece that sticks out of the viewport is rendered with the stage content shifted by
  whole stage units so it fits, so a balloon drifting in from off-stage is no longer cut;
- unnamed siblings at one depth (the game board, the unlock tip's panels) get `#k`
  segments, their order among those siblings.

Results (in progress): case `results` (from the research case results/02) records the
score screen after a won level with the new-outfit tip on top (`unlock-tip`), after OK
(`win-score`) and after a lost level (`loss-score`). Recording replays the original-method
fixtures (`fixture` actions; the player is given a state walk first so it finds the Game).

`OnePScoreUI`, `PlayerScoreUI`, `UnlockTipScreen` and `UnlockAnimaPanel` are ported and
drive the generated `score` screen (main capture `win-score`; the failed title and the tip
are parts from the other two captures; RESTART, hidden after a win, draws its frames at
`loss-score`). Godot cannot play the original round, so the case's Godot-only `settle`
actions end each round with the points its golden shows, through the app's own round-end
path. The original opens this screen on the wall clock, so each recording opens it at a
different frame: the layout reads each capture's *capture phase* from its golden.
`-- --screen score --capture loss-score` opens it for review.

Checkpoint 3 status (2026-11-05): every case passes nodes and pixels (pixels at the
measured 3×→1× ceiling): main-menu, game-settings, character-select (8 robots),
how-to-play, results (unlock tip, level complete, level failed), game-over, game-win;
tools/run_checks.sh passes end to end. Later fixes:
- a node whose own alpha or colour changes plays as rendered frames (Flash fades each
  shape inside a clip, so overlaps compound);
- an extra part's clock starts with its capture's first frame (all its tops shown; the
  frame after a click shows it);
- a widget frame that animates in another capture (a selected robot icon blinking) plays
  that capture's sequence (`frame_sequences`);
- live text uses the SWF font's ascent and draws a TextField's GlowFilter;
- controllers are released with their screen (listeners cleared, fields nulled).
Owner review (2026-11-05): all checkpoint 3 screens accepted; the empty How to Play
panel stays. Asked for: TRY AGAIN centred on the end screens and the game-complete
confetti (FallSnow) ported; fixes for robot 6's missing head while dressing up, robot 8's
arm missing at the start of its entrance, and the pause when switching robots.
- End screens (2026-11-05, owner to review): TRY AGAIN moves half the way to MORE GAMES'
  place, the middle of the original row (owner edit); on the score screen DRESS UP and
  NEXT/RESTART move left by half a button pitch (a move may now be measured `from`
  another node). `FallSnow` is ported (`scripts/ui/fall_snow.gd`, Flash `Math.random`
  port, frames from FFDec at zoom 1 in the pack); its confetti are a *run-time effect*:
  the comparison checks them by FallSnow's rules and count, and masks them from pixels.
- Dress-up (2026-11-05, owner to review): timelines record filters, so art is rendered
  where a blur changes; a still part faded or blurred at its capture is rendered at the
  first frame its parents settle (robot 6's head). Parts removed before the capture are
  added from their tracks (robot 8's first arms). Switching robots no longer stalls: one
  update per frame, art looked up by table, decode and resize on worker threads, a
  256 MB cache. Known gap: robot 6's head misses the group blur for about 6 entrance
  frames. The results unlock-tip timeline should be re-recorded with the new recorder.
Checkpoint 3 is done: accepted by the owner on 2026-11-05, including the dress-up fixes,
the centred buttons and the confetti.

Checkpoint 4 (gameplay screen, Cinema set) started 2026-11-05. Slices: (a) the screen's
chrome and the Cinema board at the round's first frame, generated from the display list;
(b) robots, bombs, flames and items drawn from SWF clips at their registration points,
driven by simulation snapshots; (c) frame-matched cases against seeded recordings;
(d) the replica_* placeholders removed; then the owner plays it.

Slice (a), 2026-11-05 (owner to review): case `gameplay-cinema-start` (seed 42, Arcade,
Normal, Cinema, robot 0, through the real menus) captures the round's first frame, 61
frames after START: the map-loading screen (`LoadingMapUI`, UI_reading) is gone and TIME
still reads 180. `scenes/swf/game.json` is generated from it: the HUD (`GameInterFace`,
ported in `scripts/ui/game_inter_face.gd`) and the board background as pieces; the board's
row layers as empty groups, with a `board` section read from the golden (every box's cell,
`_brick5` frame and kind, the portals, the grid, the round's robots and HUD slots, its
template, CinemaStage3). The art pass renders a *board tile* per frame and box kind;
`scripts/ui/game_board.gd` ports `MapMaster.createRow` / `Box.setItem` to lay the round's own
board out of them, and `tests/game_board_check.gd` checks that port against the recorded
board. Robots, bombs, items and flames (the other row layers) are slice (b): left out of
the node diff and masked from pixels; the old view draws them as placeholders. Godot starts
the case on the *recorded round* (Godot-only `round` action) and holds the round for the
recorded 61 frames. Result: nodes 378/378, SSIM 0.942 (ceiling 0.935), max region ΔE 5.0.
Known gaps: no loading screen yet; portals, the centre marquee and the TIME flash are still;
HUD panels of robots not in the recording (1, 3, 4, 7) have no art; other stage sets keep the
placeholder page.

Slice (b), 2026-11-05 (owner to review): robots, bombs, blasts, box breaks, the portals' glow
and the centre marquee are drawn from their own SWF clips (`scripts/ui/game_actors.gd`, ports
of `RobotView`, `InvincibilityCommand`, `RobotDeadCommand`, `Bomb`; `Box.brickExp` in
`game_board.gd`). Their art comes from `record_screen.py actors`: the reference player's new
`symbol` command (patch `reference-symbol`, art pass only) constructs each library class and
renders it at every frame, robots with the round's looks (`--looks all` for every look, ~40
min). Clip timing (first frame shown twice, key press vs engine stop, nested blast frames) was
recorded and is cited in the port. New case `gameplay-cinema-bomb` (AI stopped by fixture /
Godot-only `ai-stop`; the player walks, drops a bomb, it blasts a box): every actor node
matches; `gameplay-cinema-start` now includes the robots. Owner edit: the publisher logo
(`Logo2`) is removed from the gameplay screen. Harness fix: a case's key lands after the
frame has run (it applied one frame early). Known gaps: items/pickups, vehicles, weapon
clips and the map-loading screen are still placeholders or absent; robots' own blink loops
show their first frame; looks the pack lacks show the robot's default look; TIME follows the
host's Date in the reference player, so it is not compared frame for frame.
