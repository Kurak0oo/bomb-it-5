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

Checkpoint 2 is in progress. Owner decisions on 2026-11-04:

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

Owner, on the Mac: `RESET=1 tools/reference_player/build.sh` (new `down`/`up`
commands), then `PYTHON=… tools/convert.sh`. Commit `tests/goldens/` (now with
`.timeline.json` and `.states.json`) and `scenes/swf/`.
