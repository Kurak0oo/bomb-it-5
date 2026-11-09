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

Slice (b2), 2026-11-05 (owner to review): pickups, the map-loading and pause screens, every
robot's HUD panel and the TIME flash.
- Pickups are ports of `AbstractItem`/`PixelClip`: the bitmaps are the original's own, made
  per kind by the `pickup` fixture (`record_screen.py items`, all 16 Cinema kinds; patch
  `reference-item-kinds` adds BombShoesProp and BoxingProp to the fixture). Recorded: bitmap
  k shows from age 4k + 1; eaten on the frame the robot enters the cell. Fixes from the longer case: blast arms play to their empty last frame
  after the bomb is gone, and the centre's art is one nested key ahead.
- The round draws from the Flash `Math.random` port: a recorded round continues where the
  original's stood (`tools/compare/round_draws.py` -> `tests/goldens/gameplay-cinema-start/
  math_random.json`: 411 draws before the round, the drop pool's vehicles at 15-17), and the
  drop pool follows `AbstractGameMode.initMap`'s class order (it did not). Case
  `gameplay-cinema-item` matches the drop roll at frame 815 (draws 412-413: a SpeedProp),
  its pickup at 848 and the HUD after it; `gameplay-cinema-pause` matches PauseUI's random
  robot (draws 412-413 again, no drop before it).
- `LoadingMapUI` and `PauseUI` are generated screens over the gameplay screen
  (`loading_map`, `pause`); under the loading screen the rows are built on the recorded Timer
  ticks and the robots and counters appear at `firstMapLoadOver`. Its progress bar (TweenMax)
  and TIME follow the host clock in the reference player, so neither is compared frame for
  frame (`wall_clock_frame`, `wall_clock_text`).
- HUD panels of robots 1, 3, 4, 7 come from the art-only case `tools/convert/cases/
  hud-robots.json` (`record_screen.py panels`, after `art`); TIME turns red/white every 4th
  engine tick under 10 s (`changeTimeCol`), not frame-checked (TIME is on the wall clock).
Results: every case passes; gameplay-cinema-item nodes 382/391/389/389/386, pixels at the
3×→1× ceiling (SSIM 0.935, ΔE 5.0; loading 0.974); gameplay-cinema-pause nodes 515/515.
Known gaps: robots' own eye/hat loops (85-131 frames inside each clip) still show frame 1;
vehicles, weapon clips and the portal fade are still placeholders; AI and the session's AI
robots/looks do not draw from the Flash generator, so cases stop the AI.

Slice (c) and (d), 2026-11-05 (owner to review):
- Rides and weapons from their SWF clips (`scripts/ui/game_actors.gd`): a ride swaps the robot's
  clip for `_r<n>_Car_*` / `_r<n>_Skateboard_*` (`CarProp`/`MotoCycleProp.changeStage`), a hit
  sends it to `dead` and tweens to its last frame; a weapon pickup adds `showTimes` with its count
  and the held clip at the hand (`AbstractWeapon.changeStage`, `updateWeaponDisplay`, in front of
  or behind the robot as the AS3 orders them); the hammer's `sinker*_Play` swing and recovery
  (`HammerProp.bombDown`, `HammerPlayCommand`). Other weapons' swings and shots stay on the
  placeholder layer. Art: `record_screen.py actors --parts robots,plays,weapons` (every robot
  clip on foot and on both rides, how each plays, every weapon clip; ~20 min).
- Robots' own loops (eyes, feathers) are *clip loops*: left out of the clip's images and drawn as
  their own node at their recorded place per root frame (cost: root + loop frames).
- New cases (the `pickup` fixture; Godot `pickup KIND`): `gameplay-cinema-ride` (mount, drive),
  `gameplay-cinema-hammer` (held, turned, swing, swing-late, after), `gameplay-cinema-ai` (AI
  running: every node matches through round frame 30). All pass: nodes 385-391 each, SSIM
  0.936-0.938 at the 3×→1× ceiling. Known: after a key release the ride's clip advances once
  more in the original than in Godot (recorded, not explained), so the ride case ends at drive.
- AI draws: the AI's choices draw from the round's `Math.random`; `CharacterSelectUI.startFunc`
  draws the AI robots and `createAIPlayer` each AI's look per level, in the original's order
  (the map's own draws are still Godot's). The original's AI cannot be frame-matched further:
  its callbacks run on the host clock (`Action.setAction`'s `TweenMax.delayedCall(0.1)`,
  `AbstractState`'s `Timer(2000)`, `setTimeout` weapon delays), so two recordings of one case
  differ from round frame 10; Godot first leaves this recording between frames 30 and 60
  (robot 6 on another row).
- Removed: the mobile page (`replica_layout/hud/scenery.gd`), touch controls, the 1280×720 page
  view and its buttons, `--practice`, the Art Workbench and the page capture tools. Every stage
  set now plays on the generated screen; a set other than Cinema has no board art in the pack,
  so its boxes and features are drawn by the placeholder layer over Cinema's floor (known gap).
- `tools/smoke_playthrough.gd` (in run_checks) plays a normal launch with keyboard events:
  menus by clicks, Cinema levels, pause/resume, score screens, game over, a Zoo level.

Play-test fixes, 2026-11-06:
- Stage sets other than Cinema showed an empty board: the placeholder layer that draws their
  boxes and features was moved to the board container's first child, under Cinema's floor art
  (`@0#0`, `@0#1`). It is now a board-only layer just under the first row layer, and the effects
  layer (weapon actions and shots, mode objects) stays over every row
  (`Game.attach_swf`, `swf_board_view`; checked in `tests/flow_scene_check.gd`).
- The shield, invincibility and portal-transit effects had no drawing since the robots moved to
  their SWF clips (slice c); the effects layer draws placeholders for them again
  (`GameView._protection`). Still placeholders: `ShieldProp`'s `nombril_<direction>`,
  `InvincibilityProp`'s `invincibityPlay` and colour filter, other weapons' action clips and
  shots (need the reference player's art pass).
- Localised text showed its authoring placeholders (`U_TOTAL SCORE:`, `L_TOTAL SCORE`,
  `P_PAUSE`, `R_ARCADE` ...): the original's branding system runs `NewTransText.updateText` on
  every `translation_*` field (en-US string from `LocalizationPack`, font shrunk to fit,
  recentred), but the reference player has none, so the goldens and the art kept them. The
  player's `localize` command (patch `reference-localize`) replays updateText through the
  TextField API; the art passes use it (`record_screen.py`, not timeline) on the fields still
  showing a placeholder (a letter or digit and `_`: 15 fields on how-to-play, game over/win,
  score, settings, loading and pause, including `1_ENEMIES KILLED` -> `ENEMIES DESTROYED`).
  `tools/convert/localization.py` writes the strings (`scenes/swf/localization.json`); layout.py
  writes the en-US `text` (golden's as `golden_text`); the comparison expects it and leaves those
  fields out of the pixel score (the 1x reference still shows the placeholder). Goldens kept;
  the results timelines were re-recorded (the unlock tip's robot had no eyes). Open for the
  owner: other en-US strings differ from the authored English too (`START` -> `START GAME`,
  `CINEMA` -> `MOVIE THEATER`, `LIGHTNING GUN` -> `LASER GUN`, `SPORT CAR` -> `SPORTS CAR`,
  setting and loading hints); `localize FILE` without `placeholders` would apply them all.
- No end cartoon when a round ended: `GameEndCartoon` is ported (`scripts/ui/game_end_cartoon.gd`).
  When the simulation enters `ending`, the cartoon is added as the UI container's last child
  (`GameMc/@0#1/@0#1`, over the HUD, which becomes `@0#0`): `winCartoon` for `win`,
  `loseCartoon` for `lose`, `timeUpCartoon` whenever the ending began on the round clock (every
  edition-5 mode's `timeOut`; new snapshot field `ending_timed_out`). Its frame is the tween's
  (`TweenMax.to(mc, 3, {frame: 100})`: default ease `TweenLite.easeOut`, FramePlugin rounds)
  after the elapsed share of the simulation's 105-tick ending; it is taken off when the round
  settles (`animationComplete`), before the score screen. A pause during the ending leaves it
  under PauseUI (added after it), frozen with the ending. Fixed with it: `timeOut` plays the
  lose jingle whoever wins (`playLoseMusic`), so an Arcade time-out no longer plays the win
  jingle. Art: `record_screen.py cartoons gameplay-cinema-start` (after `art`) makes each class
  with `symbol` in the UI container and renders its 100 frames (whole stage: the clips dim it
  with black at alpha 0.2), only placeholder text localised as in every art pass: the owner
  keeps the authored texts (`YOU LOSE!`, not the en-US `YOU LOSE.`; likewise START, CINEMA,
  LIGHTNING GUN, SPORT CAR stay as authored). Checked in `tests/flow_scene_check.gd`,
  `fidelity_check`, `kill_check`.
- The HUD kept the path `@0#0` after the first pause: `App._hud_path` read the layout entry,
  which `rename_node` rewrites, so unpausing renamed `@0#0` to itself. The HUD's own path is
  remembered, and the map-loading screen, the pause screen and the end cartoon count as one set
  of children beside it (`SwfScreen.add_ui_child` / `remove_ui_child`): `@0#0` while any is up,
  `@0` when it is alone again (also with a pause during the end cartoon). Checked in
  `tests/flow_scene_check.gd`.

Checkpoint 5 (each mode × stage set) started 2026-11-06 with the stage sets' board art.

Zoo slice, 2026-11-06 (owner to review):
- Case `gameplay-zoo-start`: gameplay-cinema-start with Zoo picked in Game Settings' stage list
  (`weddingStages`, the centre of its bounds in the dropdown golden); 61 frames after START as
  for Cinema; `round_draws.py` gives its `math_random.json` (409 draws before the round).
- One gameplay screen carries every set: `game.json` `board` stays the screen's own (Cinema,
  `board.set`) and gains `board.sets.<set>` (layout.py `_set_board`): that set's golden, its
  `begin_num`, matched template (crocodile cells count as platforms), boxes, features
  (`Art_Crocodile` beside `Art_Portal_`), robots, looks, round start and `floor` (the board
  container's children before the rows). The shared geometry (container, rows, layers, grid,
  excursion) must equal the screen's or the converter stops.
- Art: `record_screen.py sets` (after art) renders, from the set's own round, the floor
  (bgContainer with `BackGround_Zoo`), the 46 tiles of `_brick5` 73-96 (the ZOO centre at 96 has
  no loops), and each feature class by `symbol`: Art_Crocodile frame 1 at its water loop's 20
  frames, frame 2's body and its own clips (`@3` splash 20, `mouthOpen_mc` 46) apart, into
  `original/screens/game/sets/zoo/`. The actors pass now renders every set's recorded looks and
  the Zoo rides' clips (`_forg`, `_Elephant`).
- Godot: `GameBoard.new(screen, board, set)` merges the set's fields, takes its art (`art_of`:
  the screen's pack for its own set, `sets/<set>/` for another), puts the set's floor on the
  floor piece, and lays rolled rounds out with the set's `begin_num` (crocodile cells become
  Art_Crocodile). `own_art` is `board.has_art()`: sets without a pack keep the placeholder layer.
  Crocodiles follow the simulation's crocodile frame (`Crocodile.runEngine`: mouth 1 at the 240th
  closed tick, 25 at `openComplete`, held while eating, 26-46 closing). `round CAPTURE` finds the
  set whose golden it is (`App.round_as_recorded`).
- Results: gameplay-zoo-start nodes 383/383, SSIM 0.941 (ceiling 0.939), ΔE 5.0; every other case
  passes. Rolled Zoo rounds (three runs, frames 150-400) show both ring choices, the soft
  variants, the ZOO centre and open crocodiles as in the reference capture
  (`docs/evidence/reference-2026-10-21/features/zoo-crocodiles-open.png`).
Known gaps: crocodile timing is mapped from the source, not frame-matched (no case runs to tick
240); the water loop's phase after the first opening is inferred (frame 1 made again); horse and
dragon rides draw their clips but their jump and crash are not checked against recordings;
other sets still use the placeholder layer. The next set needs its own case and `board.sets`
entry, plus its features' classes (toy hands, belt, spellbook) and any behaviour they drive
on screen (Candy's belt moves the robots' clips; Birthday's hands throw).

Candy Factory slice, 2026-11-07 (owner to review):
- Case `gameplay-candy-start`: as the Zoo case with `basketballStages` (Candy Factory) picked,
  the centre of its bounds in the dropdown golden; 393 draws before the round.
- `board.sets.candy_factory` (begin_num 25, template CandyFactoryStage3). Features now record
  where the AS3 puts them (layout.py): the cell of the feature's clip, its layer's `row` when
  another (the belt: `game.getDisArr(0)`), its scale (`linear`, 30/32), its frame, and for a clip
  inside a container left elsewhere the container's `origin` and the clip's `node`
  (`ConveyorBelt.initDis`: Art_CandyMachine in a container at xPos 0). Template matching places
  the machine on `centerProp` and the belt on the track's first cell.
- Art: `record_screen.py sets --sets candy_factory`: floor, 48 tiles, Art_CandyMachine (70-frame
  sweets loop) and Art_ConveyorBelt_1 (33 segments, 9-frame loop; `_2`/`_3` are never shown,
  `initBeltView` always makes `_1`). The actors pass was re-run for the round's looks.
- Godot: `GameBoard` lays features on their own layer at their scale and frame; a rolled Candy
  round gets the machine on the centre and, with a track, the belt at `track[0]` (snapshot
  feature state); both loops play from the recorded phase as the portals' glow. The centre is a
  hidden box for Candy Factory and Magic Library (`setMidBox` without `true`).
- Results: gameplay-candy-start nodes 366/366, SSIM 0.899 (ceiling 0.901), ΔE 5.0; all 16 cases and tools/run_checks.sh (27 suites) pass.
  Rolled Candy rounds (frames 250-550) show the belt, machine, both fixed and soft choices, a
  carried bomb and pickup, as in `docs/evidence/reference-2026-10-21/features/candy-belt.png`.
Known gaps: no compare case of a robot riding the belt (the ride is matched frame by frame by
the `belt-ride` fixture replay, edition-5-interactions.md; the screen only draws the
snapshot's position); carried pickups step cell to cell and restart their bitmap loop on each
cell; `Art_Prop_Disappear` at the belt's end is not drawn; the loops' phase in rolled rounds is
the recorded one. Birthday Party needs its toy hands' clips and throw/push display; Luxury
Stores only the case, set entry and art pass; Magic Library its spellbook clip and a hidden
centre (already ported).

Magic Library slice, 2026-11-07 (owner to review):
- Case `gameplay-library-start`: as the Zoo case with `caveStages` (Magic Library) picked, the
  centre of its bounds in the dropdown golden; 413 draws before the round.
- `board.sets.magic_library` (begin_num 121, template MagicLibraryStage3): `Art_Spellbook` is a
  feature like the candy machine (`Spellbook.initDis`: at 30/32 in a container left at the
  board's origin, on the centre row's platform layer); a feature's `loop_frame` is now its
  nested loop's under the clip (the book's own frame is the AS3's to set; unchanged for the
  other sets).
- Art: `record_screen.py sets --sets magic_library`: floor, 48 tiles, Art_Spellbook frame 1 by its
  50-frame loop (`@42`), frames 2-69 (the loop apart on 2-9), and the signs (`RUNTIME_CLASSES`:
  `Art_Sign_Red`/`_Blue` made playing, 65 ages). Robots 5 and 6's round looks were rendered and
  added to actors.json.
- Recorded in the reference player (edition-5-magic-library.md): the flip runs ticks 451-518,
  the loop carries on through frames 2-9 and restarts when the book is back on 1; signs show
  frames 1, 1, 2 … 64 and leave on frame 69, after the drop.
- Godot: `GameBoard._spellbooks` shows the book's frame from the simulation's spellbook state
  (new display fields: `closed`, and `signs` kept until frame 69 as `deleSign` does) and the
  signs on their rows' platform layers (`tests/flow_scene_check.gd` checks the paths).
- Results: gameplay-library-start nodes 385/385, SSIM 0.905 (ceiling 0.906), ΔE 5.0; all 17 cases and
  tools/run_checks.sh (27 suites) pass.
  Rolled rounds (nine runs, and three stopped at flip frames 6, 21, 40) show the book, its
  glow, the pages turning and red/blue signs as in the reference capture and
  `docs/evidence/reference-2026-10-21/features/magic-spellbook-signs.png`.
Known gaps: no compare case runs to a flip (checked against the reference player's display
dump, not frame-matched pixels); the dropped items' fade-in (`itemsDrop`: `TweenLite.from(mc,
1, {alpha: 0})`) is not checked; the shared actors pack is rewritten by each set's actors pass,
so a pass must keep every set's looks (`board.sets` of all branches).

Luxury Stores slice, 2026-11-07 (owner to review):
- Case `gameplay-luxury-start`: as the Zoo case with `mysteriousStages` (Luxury Shop) picked,
  the centre of its stage bounds in the dropdown golden; 416 draws before the round
  (template LuxuryStoresStage3).
- `board.sets.luxury_stores` (begin_num 97). No features (`LuxuryStoresMapData.setData`'s
  `lavaOrgan` branch is never reached: no Luxury layout has that cell) and the centre shows
  (`setMidBox(x, y, true)`): frame 120, a shop window with no loops of its own.
- Art: `record_screen.py sets --sets luxury_stores`: floor and 44 tiles (frame contents in
  edition-5-stage-tiles.md). The robots' actors pass was re-run with the round's looks
  (robots 2, 6, 5 at [5, 3], [3, 2], [1, 1]); the shared pack's pass now takes every working
  copy's set looks. No Godot code change: `GameBoard` draws any set with a pack.
- Results: gameplay-luxury-start nodes 386/386, SSIM 0.897 (ceiling 0.895), ΔE 5.0; all 18
  cases and tools/run_checks.sh (27 suites) pass. Rolled Luxury rounds (frames 200-600) show
  both ring choices (ring box, necklace bust), the shown centre, the soft variants and
  robots, as in the reference capture.
Known gaps: the round's car drops and rides are not checked against a Luxury recording; a
robots-only actors pass drops the clips' `next` (`--parts plays`), which only rides use.

Birthday Party slice, 2026-11-07 (owner to review):
- Case `gameplay-birthday-start`: as the Candy case with `restaurantStages` (Birthday Party,
  `GameSettingsUI`: `_birthdayPartyStages`) picked, but seed 11: seed 42 rolls the handless
  BirthdayPartyStage3, seed 11 BirthdayPartyStage2 with its four toy hands; 402 draws before
  the round.
- `board.sets.birthday_party` (begin_num 1, template BirthdayPartyStage2, the cake centre shown:
  `setMidBox(x, y, true)`). layout.py takes `Art_ToyHand_` as a feature, matches `toyHand_<dir>`
  cells (hidden box + hand) and gives a clip scaled inside a container on its own cell its own
  `node` (`ToyHand.setMc`: 30/32), so its frames draw at the clip's scale.
- Art: `record_screen.py sets --sets birthday_party`: floor, 48 tiles, the four hand clips
  at frame 1 and each label `g0`-`g3` (frames 2-5) with its 14-frame `hand` clip. The actors pass
  (robots) was re-run with every working copy's recorded looks (Birthday, Luxury, Magic).
- Godot: `GameBoard._toy_hands` follows `ToyHand.runEngine`: frame 1 until the first opening,
  then `g<pushStep>` with the hand one frame per tick, left on frame 14 (never back to 1); the
  simulation's toy hand reports `push_step` for it (display field only). Rolled rounds lay the
  hands and their hidden boxes out from the feature state. Every set now has art, so
  `flow_scene_check` tests the placeholder board only on a set whose pack is missing.
- Results: gameplay-birthday-start nodes 388/388, SSIM 0.937 (ceiling 0.937), ΔE 5.0; all 19 cases
  and tools/run_checks.sh (27 suites) pass.
  Rolled rounds (six runs: Stage1, Stage2, Stage3) show the hands opening, reaching 0-3 cells and
  retracting at tick 105-118 as in the reference (`birthday-toy-hands-open.png` and a reference
  run stepped past the opening).
Known gaps: no compare case past tick 105 (opening and push are checked against the reference
by eye only); pushed robots and thrown bombs move as the snapshot gives them (no own display);
the toy's `toyHandOpen` sound is the simulation's.

Robot effects slice, 2026-11-08 (owner to review):
- Shield, invincibility and portal transit are drawn from the original's clips
  (`scripts/ui/game_actors.gd`); the placeholders in `GameView._protection` are removed.
  - Shield (`ShieldProp.initMc`, `RobotView.setRobotMc`): a pickup remakes the robot's clip;
    each new clip with a `hand2` child gets `nombril_<direction>` at hand2's x and y, under
    the robot facing right and on top otherwise. It plays when the robot turns and stops at
    `normalStop`. A key for the way the robot already faces plays only the robot's clip
    (recorded). `addUseNum` takes it off.
  - Invincibility (`InvincibilityProp.changeStage`, `CountMcPlayCommand`): `invincibityPlay`
    in the `itemMc` Sprite on top of the container shows frames 1, 1, 2 … 28 and is taken off
    on tick 30. The empty Sprite stays until death (`clearDisplay`).
    `CountInvincibilityCommand`'s GradientGlowFilter (colours turned every 2nd tick, ratios
    + `_colortime`) goes on the clip and weapon until `invincible_until`. Godot draws it
    with `swf_gradient_glow.gdshader` on a CanvasGroup (`SwfScreen.set_node_filter`).
  - Transit (`SendRobotCommand`): the clip's alpha is 1 - count / 35 (count 1 on the send
    tick), the clip stops (`robotMoveStop`), and callback 30 makes a new clip at alpha 1.
  - The simulation now sets `blink_until` (display only) after a shield is used and after
    a ride's recovery (`TryToKillCommandChain`'s InvincibilityCommand).
- Art: `record_screen.py actors gameplay-cinema-start --parts effects` (key `effects`:
  nombril clips, `invincibityPlay`, each robot clip's `hand2`; 3× shots of the new cases).
- New cases: `gameplay-cinema-shield` (held, turned, walk, used),
  `gameplay-cinema-invincible` (intro, intro-late, glow, glow-turned) and
  `gameplay-cinema-portal` (fade, fade-late, arrive; Godot `reposition X Y`). All nodes
  match, including the transit alpha. All 22 cases and tools/run_checks.sh pass.
- Comparison: the reference player draws no GradientGlowFilter (Ruffle's wgpu backend skips
  it), so a golden node carrying one is left out of the pixel score (`UNRENDERED_FILTERS`).
  `composite_alpha` (portal case) does the same for a faded baked clip: Flash applies the
  alpha per shape, so overlapping shapes add up, while the baked image fades as one.
- HUD portraits: `GameInterFace.setMC` runs `stopMC` over the whole HUD, so the panels'
  85-frame eye loops stay on frame 1. Stepped 150 frames in the reference player, no HUD
  clip changed frame. Nothing to animate.
Known gaps:
- The glow is checked by eye only; there is no reference render of it.
- A faded robot's overlapping shapes are lighter than in Flash.
- Godot blasts a bomb dropped this way one tick after the original. The shield's `used`
  capture is therefore after the blast.
- Invincibility's end is not captured: after 10 s the Arcade timed drops (host clock in
  the reference) differ.
- Re-picking invincibility mid-introduction is mapped from source and not recorded.

Feature motion, 2026-11-08 (checkpoint 5, owner to review):
- Candy Factory belt (`ConveyorBelt.runEngine`, `bombMove`/`propMove`, `Bomb`/`AbstractItem.resetDisplay`):
  a carried bomb or pickup is one view from cell to cell at its twip position, its clip and
  PixelClip loop running on; each tick it is re-added last to its row's bomb layer / row in the
  belt's order (display fields: bombs' `bomb_display` serials, the belt's `carried`, `moved`).
  `addDisappearAni`: `Art_Prop_Disappear` (30 frames, art pass `sets` `stopped`) on the last
  cell's platform layer, turned to the last segment, frames 2-29. Blast arms sit at the bomb's
  own position. Source fixes found by the case: belt bombs go off `blastTime + 2` ticks after
  they are made (`Bomb.takeCount`), and set features are made column by column (`setData`),
  which orders the toy hands' interval draws. The sets pass now records one age past each
  played loop (the candy machine's 70-frame sweets and the belt's 9-frame segments were a frame
  short and drifted).
- Birthday Party toy hands: a pushed robot moves as `PushRobotCommand.moveFuc` moves it and
  `resetRobot` makes its clip again where it stops; a thrown bomb keeps its clip and is re-added
  to the row it stood on each tick (`kickedFly` -> `shootFunc`).
- Zoo crocodile: no clip of its own for what it eats (bombs blast, a pickup goes by `deleProp`'s
  `brickExp`, now drawn so, robots die); nothing is spat out.
- Cases: `gameplay-candy-belt` (1,725 frames: bomb out of the exit, pickup sliding, a bomb and a
  pickup leaving with the disappear clip; `--frame-clock` keeps the round's Date on the frames),
  `gameplay-birthday-push` (`reposition` fixture, Godot `reposition X Y`: the snapped first push
  and the stale-check second push at tick 548), `gameplay-zoo-crocodile` (first opening, ticks
  240-354). All 25 cases pass (belt SSIM 0.898 at a 0.900 ceiling, push 0.935-0.939, crocodile
  0.941; ΔE ≤ 6.4); tools/run_checks.sh (27 suites) passes.
Known gaps: no case throws a bomb with a toy hand (its display is ported, not checked against
a recording; Stage2's hands all face boxes); a robot pushed while a key is held keeps its playing clip as
the snapshot's commands give it; the push end re-adds the weapon clip through `setRobotMc` only.

Weapons slice, 2026-11-08 (owner to review): every weapon's action and shots from their SWF clips.
- Ported in `scripts/ui/game_actors.gd` (`_start_action` = each `*Prop.bombDown`, `_advance_action`
  = its command, cited per weapon): BoxingProp (`boxing<D>_Play`, `_Play_2`, `_Play_3` by
  `checkAttactDistance`, under the robot at frame 7 facing up), LaserGunProp (`lasergun_Play` at the
  held clip's `gunpoint`, stopped at 11; ShootLaserCommand's laserCartoon start, middle pieces in a
  Sprite scaled to the last cell's edge and end piece, walked over the board of that tick;
  LaserEndCommand's eleventh run), FlamerProp (`thrower<D>_Play` at the gunpoint, its `fire_Play`
  by age, scaled by FlamerFire from the snapshot's `scale`), ShotGunProp (`fireball<D>_Play`, off at
  frame 14), TripleShootGunProp and LandmineProp (their empty play clips live within one tick),
  LandminePlayCommand's `mine_bomb` (looping, then the ordinary blast); the projectiles
  `TripleShootGunBomb` (`bullet_fire`) and `FireballBomb` (`ninjialBomb_fire`, nested 35-frame loop)
  from the snapshot's `projectiles`: frame and offset by direction, `resetDisplay` on each move,
  clip off at `blast`, Sprite off at `ended`, the 0.2 s fade-in on the game clock (7 ticks). Every
  weapon's placeholder in `scripts/game_view.gd` is removed.
- Art: `record_screen.py actors gameplay-cinema-start --parts weapons` adds each held clip's
  `gunpoint`, `weapons.played` (made playing, by age: `thrower<D>_Play`, `mine_bomb`),
  `weapons.aged` (stopped at a frame while nested clips play, by age: laserCartoon, lasergun_Play,
  ninjialBomb_fire, bullet_fire) and `weapons.bounds` (laserCartoon `width`/`height` per frame). Only
  the `weapons` key of actors.json and `weapon-*.png` change.
- New cases (pickup fixture, then the action): `gameplay-cinema-flamer`, `-laser`, `-boxing`,
  `-landmine` (right, at the boxes ahead) and `-fireball` (its charge, down). All pass at the 3×→1×
  ceiling; nodes match exactly (the laser's scaled Sprite and end piece included).
Known gaps: the simulation runs each weapon's callbacks one tick after the original in play (its
weapon timings count from the input counter, but the game consumes a key on the next frame:
`weapons.gd` emits the first triple shot, fires the laser, ends the hammer/flamer a tick late), so a
moving projectile stands one move behind the original's and boxes broken by a weapon break a tick
late; the clips count their own frames from the action's start as the commands do, so they match.
No case captures a shot for that reason (a scratch run, right and down, matched every shot node but
its position, one move behind, and its fade): the triple gun has no case. The
triple/fireball recovery and the shots' fade-in run on the host clock in the reference player
(TweenMax), so they are not captured. The burnt pickup's `brickExp` (pickups slice) does not show
its sparkles as the original's at frame 9 (found by the flamer case; captures moved off the burn, whose score also lands a tick late).

Timing and random draws, 2026-11-08 (checkpoint 5, owner to review). Traced first in the reference
player (`trace-focus` per frame: shield, hammer, boxing, fireball, triple, ride).
- Weapons a tick late: a key reaches the original between frames, so `*Prop.bombDown` adds its
  command before the next frame and the command first runs on that frame (the *key's tick*) with
  the play clip on frame 1. `weapons.gd` counted its waits from the input counter (hammer 24,
  laser 11 ...) but from the key's tick: every weapon acted a tick late. Now a command waiting
  for clip frame f acts at age f - 1 (hammer blow 23, laser 10, boxing 12, fireball 13); flamer
  fire, the landmine and the first triple shot act on the key's tick, the triple's at 0/15/30
  (recorded: key 705 -> hammer back 729, boxing 718; key 702 -> triple shots 703/718/733,
  fireball 716). Also from the traces: a hit projectile's `ended` counts on the hit's own tick
  (gone 11 ticks on), and its handler's removal skips the next projectile's move that tick
  (`GameEngine` bomb loop; the third triple shot stands still when the second hits). The
  display's laser walk treats the cells its own tick's laser pass broke as still blocking; a
  landmine's one-tick action shows through the actor's `action_started_tick`.
- Bomb blast a tick late: `Bomb.init` registers `takeCount` before the key's tick, so a keyed
  bomb counts on that tick and blasts on its 72nd (recorded: key 721, `_time` 1 at 722, blast
  793; chain probe: fixture bomb 822, blast 894). The simulation skipped every bomb's first tick;
  now only a controller's (AI) bomb, made during the frame's scripts, counts from the next tick
  (`in_frame` on scheduler commands). Checks moved to the source timing (bomb_simulation,
  round_play, round_regression, fidelity, hitmove).
- Map draws: `Layouts.roll_set` ports `MapMaster.init`, `<Set>MapData.init`, `AbstractMapData.data`
  / `pacManData`, `setData` (column by column) and `MapMaster.createRow` (row by row, one draw per
  cell without a mid box, one more per soft block) onto the round's `Math.random`; a rolled round
  draws the pool's vehicles (`initMap`) first. All six recorded rounds roll again exactly from
  their seeds, on the original's draw ordinals (`tests/layout_check.gd`). The recorded cases now
  roll their board from the replayed draws too (`Game._recorded_draws`); they still start there
  because the app does not reproduce the menus' draws (UILoading, SoundManger, MainMenuUI,
  GASender: draws 1-11).
- Ride clip after release: `_r<n>_Car_<dir>` has a frame script on frame 11, `gotoAndPlay(1)`,
  which runs after the engine's `moveStop` and restarts the clip, so it shows one frame more
  (recorded: 10, then 1 and 2, stopped). Not a port error of the clip itself: the art pack had
  lost the clips' `next` (a robots-only actors pass dropped it; now kept, `--parts plays`
  re-run), and the display now restarts a clip whose step was a frame-script jump.
- Cases: new `gameplay-cinema-triple` (first, second, third), `gameplay-cinema-fireball` adds
  shot and blast, `gameplay-cinema-shield` captures the blast (72 frames after the key) before
  used, `gameplay-cinema-ride` adds release and parked. `wall_clock_alpha` (compare.py) leaves a
  host-clock fade (`TweenMax.from` on the shots) out of the alpha compare and the pixel score.
Host-clock only (not frame-matched): the shots' 0.2 s fade-in, the triple/fireball 0.3 s
recovery (`delayedCall`), the AI's delayed callbacks, TIME and the loading bar.
