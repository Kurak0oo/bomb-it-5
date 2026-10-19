> Imported Dots record; claims are retained as delivered. See the [integration assessment](../../edition-5-play-observations.md) for verification, missing files, and authority limits. Original relative paths in code spans refer to the [unaltered bundle](../../../../.scratch/edition-5-research/observations/swf-v1.6.1/REPORT.md).

# Bomb It 5 (v.1.6.1): evidence report for the Godot rebuild

Tags: **[O] observed** (seen in a frame or screen) · **[I] inferred** · **[U] unknown** · **[S] source** (static analysis, see `source-findings.md`).
Nothing in the game or in Ruffle's behaviour was changed. There are no cheat builds and no other editions. No online videos were used.

## 0. Build, players, method
| item | value |
|---|---|
| SWF | `bomb-it-5-zh-fix.swf`, 6,942,081 B, SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2` (re-verified). Menu shows `v.1.6.1`. |
| Frame-exact player | **Ruffle `ruffle_core` from source, commit `45366370ed7d1a59c89aa3cf7b765c7a274407cd`** (github.com/ruffle-rs/ruffle `master`, 2026-10-16 07:41 UTC), rustc 1.9x stable (rustup), `cargo build --release -p probe`. |
| Harness | `tools/ruffle-probe/` (`main.rs`). It is a small binary in the ruffle workspace, modelled on ruffle's `exporter`. It uses `ruffle_core::Player` and `ruffle_render_wgpu` with an offscreen `TextureTarget` on **wgpu Vulkan on llvmpipe (Mesa 25.0.7, LLVM 19, CPU)**, at 700×510 and scale 1. Commands come from stdin: `step N` (one `run_frame()` plus `update_timers(1000/frameRate)` per frame), `kd/ku <key>` (`PlayerEvent::KeyDown/KeyUp`, the same key descriptors as ruffle's test-framework automation), `click x y`, `cap <dir>` (renders and saves **every** frame as `f<frame>.png`), and `realtime`. **Frame number = number of `run_frame()` calls since boot.** An input sent "before frame N" is handled before `run_frame()` N. No desktop browser, no xdotool. Audio: none (null backend). |
| SWF frame rate | The header says 30. The game sets 35 at once (`fps_setting=35` from frame 1, `Root.GAME_FRAMERATE`). [O]/[S] |
| Speed / lag | The harness is **not real-time**. It runs about 150 frames/s without capture and **15–33 frames/s while capturing every frame**. Over the whole session it was 4,524 frames in 1,535 s of wall time (includes the operator's think time between commands, during which the game is frozen). The game logic is purely per-frame, so frame counts are exact. Only the round clock reads wall time (see §4.6). The full frame→wall-ms log is `play/harness-timeline.csv`. [O] |
| Earlier manual session | Ruffle **web** nightly 2026-10-16 (selfhosted) in Google Chrome on Xvfb (swiftshader WebGL), about 10 s of tool latency per action, normal 1× playback (`play/log.md`, `play/screens/`). Its screen flow is used; its timings are discarded. |
| Setup for all probes | Arcade, 1 player, 3 enemies, 5 levels, Arena RANDOM, **NORMAL** (confirmed by "NORMAL BONUS" on the results screens), first character (blue robot, P1). |

Frames are under `play/frames/<probe>/<run>/f<frame>.png`. They are palette-reduced to 256 colours to keep the pack small; full-colour originals are on the box under `/workspace/probe-run/frames`. Clips (MP4 and GIF, 35 fps = game speed) are in `play/clips/`. Screens from the harness are in `play/screens_harness/` (see `SCREENSHOT_INDEX.md`).

## 1. Screens and flow (harness run, frame numbers)
| # | screen | how reached | frames | ref | tag |
|---|---|---|---|---|---|
| 1 | Title: logo, empty frame, PLAY | boot | 1–301 (still waiting at 301) | h01 | [O] |
| 2 | A10.com splash animation | click PLAY (349,440) | 302–~530 | h02 | [O] |
| 3 | Main menu: START / HOW TO PLAY / MORE GAMES, v.1.6.1 | automatic | ≤541 | h03 | [O] |
| 4 | GAME SETTINGS (default EASY, Arcade, 1P, 3 enemies, 5 levels, RANDOM) | START | 571 | h04 | [O] |
| 5 | Same with NORMAL | click NORMAL | 596 | h05 | [O] |
| 6 | "Dress up your characters here!", P1 = first head | NEXT | 636 | h06 | [O] |
| 7 | Loading "R_ARCADE – Place your bombs tactically to kill all enemies!" | START | 637–696 | h07 | [O] |
| 8 | **First gameplay frame** (TIME 180) | — | **697** | h08, `play/first-board.md` | [O] |
| 9 | Death: P1 → black silhouette on the blast frame | hit | 959 | h10 | [O] |
| 10 | Field dims, "YOU LOSE!" | +~60 f | ~1019–1072 | h11 | [O] |
| 11 | "LEVEL 1 / 5 FAILED…" (ENEMIES KILLED, TIME BONUS, NORMAL BONUS, LEVEL SCORE, L_TOTAL SCORE; MORE GAMES / DRESS UP / TRY AGAIN) | automatic | 1073 | h12 | [O] |
| 12 | TRY AGAIN → loading → new board, same settings, **hearts 2** | click (543,421) | board at ~1151 | h13 | [O] |
| 13 | "P_PAUSE" screen (MAIN MENU / RESUME) | P key | key-frame +3 | h15 | [O] |
| 14 | Time up: field dims, "TIME'S UP!" with alarm clock | timer 0 | 2910–2919 | h19 | [O] |
| 15 | **"LEVEL 1 / 5 COMPLETE!"** (NEXT instead of TRY AGAIN) | automatic | 2920 | h20 | [O] |
| 16 | Level 2 board (LEVEL 2/5) | NEXT | ~3085 | h21 | [O] |
| 17 | "GAME OVER – Don't give up! Give it another bomb…", G_TOTAL SCORE, MORE GAMES / TRY AGAIN | death on the last heart | 4405 (no LEVEL FAILED screen in between) | h23 | [O] |
- Raw localisation keys show on screen: `R_ARCADE`, `P_PAUSE`, `1_ENEMIES KILLED`, `L_TOTAL SCORE`, `G_TOTAL SCORE` (and `C_P1`, `R_BATTLE ROYALE`, `C_POWER-UPS`… in the manual session). [O] See UNRESOLVED.
- No separate "win cartoon" was seen after TIME'S UP; it went straight to the results screen. [O] Whether `winCartoon` is skipped on time-up or just very short is [U].

## 2. Maps
- **First board = CinemaStage1** (Cinema skin). It matches `maps/CinemaStage1` exactly for every solid, portal, centre-building and spawn cell. 0.8-probability soft blocks account for the empty `s` cells. Full 17×15 transcription: `play/first-board.md`. [O]
- After each TRY AGAIN the layout was re-rolled inside the same set: CinemaStage3 (run 2, h13), then CinemaStage2 (run 3, h17). After the win the next level used a new set, LuxuryStores (h21). This is consistent with [S] `UIManager.gamePlay`. [O]
- Soft-block skins are set-specific and mixed (Cinema: 3D glasses, clapboards, popcorn, drinks). Solid skins are also mixed (Cinema: red seats **and** spotlights). Do not assume one sprite per type. [O]
- On screen the cell pitch is ≈30–32 px. P1's left edge is 197/227/259 at x = 1/2/3. Sprites sit bottom-aligned and stand up to ~15 px taller than a cell. [O]

## 3. Probe results (frame-exact, harness)
| # | probe | runs | result | refs | tag |
|---|---|---|---|---|---|
| 1 | Pixels per frame while holding a direction | 6 (R×2, L, D, U, R) | **≈4 px/frame** (steps of 3–5 px). The first frame after key-down moves only 2–3 px. **1 cell (≈30–31 px) takes 8 frames** (≈0.23 s at 35 fps). Movement starts on the first frame after key-down. **On key-up the robot stops at once, mid-cell, with no snap to the cell centre** (e.g. stopped at y = 111 between rows). Same in all directions. | `frames/p01_hold_dir/*`, clip `p01_hold_left_run1` | [O]. Relation to XML speed 1.6: [U] |
| 2 | Hold Left, press Up, release Up (Up blocked by the top wall) | 3 | Pressing Up stops the horizontal move within 1 frame. The sprite turns to face up and does not move (≤1–2 px drift). Releasing Up resumes Left on the next frame, still holding. 3/3 identical. | `frames/p02_left_up/run1..3`, clip `p02_left_then_up_run1` | [O]. With Up *open*: not tested [U] |
| 3 | Two directions held | 3×3 | (a) Right and Down pressed on the same frame (Right event first) → moves **Down**. (b) Right, then Down 3 frames later → it slides **back** 6 px to the column, then goes down. (c) Down, then Right 3 frames later → it slides back up to the row, then goes right. **The last-pressed direction wins, and the robot re-centres on the current cell's axis before turning.** Fully deterministic, 3/3 each. | `frames/p03_two_dirs/va|vb|vc_run1..3`, clips `p03_*` | [O] |
| 4 | Space held vs tapped vs repeated (capacity 1) | tap many, held 1, repeated 1 | Tap: a bomb appears on the next frame. **Held** (one key-down, no OS auto-repeat in the harness): one bomb only, and no new bomb after it exploded while still held. **Repeated** taps every 4 frames (on the cell, then while walking away): still one bomb. A Space press used to resume from pause placed no bomb. | `frames/p04_space/*`, clips `p04_*` | [O]. Browser auto-repeat behaviour [U] |
| 5 | Fuse, placement → blast | **6** | Bomb visible from frame P (the first frame after key-down). **First blast frame = P + 72**, 6/6: 1350→1422, 3165→3237, 3297→3369, 3499→3571, 4132→4204, 4277→4349. That is 2.06 s at 35 fps. Source: `_normalBlastTime 70`, explodes when `_time > 70` (71st tick). The extra frame is the placement tick / render order [I]. | `frames/p05_fuse/run1`, `p04_space/*`, `p08_chain/*`; clip `p05_fuse_flame_softblock_run1` | [O] |
| 6 | Flame duration | 2 measured (plus 3 chain runs, qualitative) | Flame visible **17 frames** (1422–1438; 3237–3253). Matches source `_continueTime > 15` ≈ 17 ticks. | same | [O] |
| 7 | Blast vs soft and vs solid | 3 | Soft block in range: it is destroyed (brick-break animation) and the ray stops there. Solid (spotlight/seat/wall): a small orange hit-spark and no flame past it. Matches [S] `Bomb.blast`. | `p05_fuse/run1` f1422–1438, `p04_space/*` | [O] |
| 8 | Chain reaction | 3 | Bomb B, placed 9 frames after A and inside A's range, **explodes on the same frame as A** (P_A + 72), not at P_B + 72. 3/3 (3571, 4204, 4349). | `frames/p08_chain/run1..3`, clip `p08_chain_run1`, h22 | [O] |
| 9 | Soft block break, drop, pickup | 2 | Box destroyed → owner +10 score (HUD 0→10) [O, matches S]. A drop bubble appears **11 frames after the blast** (f1433, when the brick animation ends). Walking in picks it up (f1483): HUD bombs 1→2 and score +100. Run 2 also picked Power +1 (power 2) and Bomb +1. | `frames/p09_drop_pickup/run1..2`, clip `p09_pickup_run1`, h14 | [O] |
| 10 | Damage, death, hearts | 3 | Any flame on P1 = instant death. Silhouette on the blast frame (0–1 frame). **No respawn inside the round.** "YOU LOSE!" ~60 frames later, results ~115 frames after the hit. **Hearts 3→2→1**, one per lost level; the level restarts with a new layout. Losing on the last heart goes straight to GAME OVER. **A level win does not restore hearts** (level 2 still had 1). Hearts are retries, not lives inside a round. | `frames/p10_death/run1_selfbomb` (own bomb), `run2_ai_bomb_after_pause`, `p08_chain/run3` (AI bomb, f4303/4304) + `run3_gameover`; clip `p10_death_selfbomb_to_results_run1`; h10–h13, h17, h23 | [O] |
| 11 | Pause with P and Esc | 3 | **P → PAUSE screen 3 frames after the key (key sent before f1857, screen at f1860)** (1857→1860, 4014→4017, 4048→4051). P again while paused: nothing. Esc while paused: nothing. **Esc during play: nothing (3/3)**. Space resumes on the next frame and places no bomb. Round clock frozen during pause (142→139 across 15.7 s of wall time, only the ~20 unpaused frames counted) [I]. | `frames/p11_pause/*`, clip `p11_pause_P_run1`, h15–h16 | [O] |
| 12 | Round end by timeout (hide) | 1 | P1 hid at spawn (1,1) with 0 kills. TIME reached 0 → **"TIME'S UP!" (f2910) → "LEVEL 1 / 5 COMPLETE!" (f2920)**, ENEMIES KILLED 0, TIME BONUS 0, NORMAL BONUS 2000, LEVEL SCORE 2000. **This confirms the source bug: in Arcade, time-up is a WIN.** GAME OVER later showed total 2000, so the 230 HUD points (boxes/items) were **not** added to the total. | `frames/p12_timeout_win/run1` (every 8th frame + all from 2860), clip `p12_timeout_timesup_to_complete`, h18–h20 | [O] |

**Victory reached: yes**, only by the timeout bug. A victory by killing all 3 AIs was not reached [U]. In level 2 one AI (witch) was killed by another AI's bomb.

## 4. Mechanics notes
1. **Movement**: ≈4 px/frame at speed 1 (HUD "1"). Last-pressed wins with re-centring before a turn. It stops dead on release. [O] Turn-assist around corners while offset by more than half a cell: [U].
2. **Bombs**: capacity 1 at start (HUD). One bomb per cell. Fuse 72 frames observed. Flame 17 frames. Chains detonate on the same frame. Power 1 → range 1 (and power 2 after the pickup: range 2, as the chain run shows). [O]
3. **Items**: bubble drops. Bomb +1 and Power +1 were picked; each gives +100 score. [O] Other items: see [S] table §10.
4. **Damage**: one hit kills. Your own bomb kills you (run 1). [O]
5. **Portals (Cinema)**: walking into a portal tile teleports P1 to the paired portal. The sprite disappears for several frames (`p03_two_dirs/portal_incidental_*`). [O] Exact pairing and delay: [U].
6. **Round clock vs frames**: [S] `countTime` is a tween handler that runs **every 4 engine frames** (`count == 4`). It adds 1 s whenever `new Date().getSeconds()` has changed. [O] Proof: stepping 1 frame per ~1.05 s wall gave only 21 timer seconds in 84 frames (1 per 4 frames). Stepping 4 frames per ~1 s gave ≈1 s per 4 frames (TIME 158→0 over frames 2279→2910). At a true 35 fps the clock tracks wall seconds and caps at 8.75 ticks/s. **If the game runs slower than 4 fps the clock runs slow. If it runs faster, the clock still runs at wall speed**, so a frame-based rebuild must decide which to copy. During pause the clock froze [I].

## 5. Files
`play/first-board.md` · `SCREENSHOT_INDEX.md` · `UNRESOLVED.md` · `play/frames/` · `play/clips/` · `play/screens_harness/` · `play/harness-timeline.csv` · `tools/ruffle-probe/` (harness source, helper scripts, workspace patch) · earlier `source-findings.md`, `maps/`, `setup/players.md`, `play/log.md`, `play/screens/`.
