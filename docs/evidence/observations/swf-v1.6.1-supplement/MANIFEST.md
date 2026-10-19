> Imported Dots supplemental record; assertions are retained as delivered. Read the [integration assessment](../../edition-5-play-observations.md) for confidence, corrections and remaining limits. Source-relative paths in code spans refer to the [unaltered original](../../../../.scratch/edition-5-research/observations/swf-v1.6.1-supplement/MANIFEST.md).

# MANIFEST: Bomb It 5 SWF evidence: supplement (phase 1)

11 standalone zip parts, each ≤ 23,000,000 bytes, split by directory (not byte-split). Extract all parts into one folder to rebuild the tree. MANIFEST.md and SHA256SUMS.txt (covering every file in every part) are in each part. Verify with `sha256sum -c SHA256SUMS.txt` after extracting all parts.

| part | contents | files | bytes (uncompressed) |
|---|---|---|---|
| bombit5-supplement-part01.zip | docs (top-level files) | 6 | 122,249 |
| bombit5-supplement-part01.zip | tools/ | 12 | 11,647 |
| bombit5-supplement-part01.zip | ruffle-checkout/ | 8 | 189,778 |
| bombit5-supplement-part01.zip | logs/ | 5 | 115,413 |
| bombit5-supplement-part01.zip | screens_harness/ | 23 | 9,409,082 |
| bombit5-supplement-part01.zip | keyframes_fullcolour/boot/ | 18 | 4,496,449 |
| bombit5-supplement-part02.zip | keyframes_fullcolour/events/ (files chunk 1) | 36 | 20,362,182 |
| bombit5-supplement-part03.zip | keyframes_fullcolour/events/ (files chunk 2) | 37 | 16,549,074 |
| bombit5-supplement-part03.zip | keyframes_fullcolour/first_board/ | 9 | 3,059,155 |
| bombit5-supplement-part04.zip | clips/ | 24 | 11,662,123 |
| bombit5-supplement-part04.zip | frames_256colour/p00_first_board/ | 22 | 2,091,268 |
| bombit5-supplement-part04.zip | frames_256colour/p01_hold_dir/ | 139 | 8,437,840 |
| bombit5-supplement-part05.zip | frames_256colour/p02_left_up/ | 99 | 6,104,185 |
| bombit5-supplement-part05.zip | frames_256colour/p03_two_dirs/ | 195 | 11,606,467 |
| bombit5-supplement-part06.zip | frames_256colour/p04_space/ | 260 | 15,520,198 |
| bombit5-supplement-part06.zip | frames_256colour/p05_fuse/ | 111 | 6,991,415 |
| bombit5-supplement-part07.zip | frames_256colour/p08_chain/ | 303 | 18,011,424 |
| bombit5-supplement-part08.zip | frames_256colour/p09_drop_pickup/ | 84 | 5,071,265 |
| bombit5-supplement-part08.zip | frames_256colour/p10_death/run1_selfbomb/ | 200 | 11,260,790 |
| bombit5-supplement-part09.zip | frames_256colour/p10_death/run2_ai_bomb_after_pause/ | 150 | 9,112,074 |
| bombit5-supplement-part09.zip | frames_256colour/p10_death/run3_gameover/ | 120 | 5,376,893 |
| bombit5-supplement-part10.zip | frames_256colour/p11_pause/ | 176 | 9,658,265 |
| bombit5-supplement-part11.zip | frames_256colour/p12_timeout_win/ | 287 | 15,347,264 |
| bombit5-supplement-part11.zip | manual_session_screens/ | 28 | 5,831,303 |

## What each item is
| path | content |
|---|---|
| CORRECTIONS.md | Corrections to the first report (fuse = 72 callbacks by source, wall-clock round timer, glove ambiguity, bouncer/carpet/heavy bomb UNIDENTIFIED, exact rustc 1.99.1) |
| REPRO.md | Exact toolchain, build and launch commands, command/frame semantics, per-probe key frames, and the **full LOGGED input log** (all 924 harness commands with absolute frame numbers), segmented by capture directory. Reconstructed items are marked. |
| CLIPS_MANIFEST.md | Every clip: source dir, first/last absolute frame, crop rectangle (RECONSTRUCTED by image matching) |
| SCREENS_HARNESS_INDEX.md / KEYFRAMES_INDEX.md | Indexes of the full-colour stills and keyframes |
| screens_harness/ | the 23 h01–h23 stills, **full colour, uncropped, original bytes** |
| keyframes_fullcolour/ | first board f000696/f000697 (+ loading samples), boot/menu shots, 73 full-colour event frames (HUD, pause, every end state: YOU LOSE, LEVEL FAILED, TIME'S UP, LEVEL COMPLETE, GAME OVER) |
| frames_256colour/ | **ALL probe frame sequences** of the first pack (the old play/frames/, 2,146 PNGs; same names and frame numbers). **These are 256-colour palette-quantized (median cut) copies, lossy in colour, full 700×510, uncropped.** Full colour for all 2,843 captured frames would be ~1.4 GB (~530 MB even losslessly re-optimised, i.e. 24+ parts), so only the keyframes above are full colour. p12 is every 8th frame below 2860 plus all frames ≥2860. p08 is A−5…A+95 around each first bomb. Everything else is complete. The p00_first_board f000696/f000697 in this folder are full colour. |
| clips/ | the 12 MP4 + 12 GIF clips (unchanged) |
| manual_session_screens/ | the manual Ruffle-web/Chrome screenshots, including the help screens (screen flow only) |
| tools/ruffle-probe/ | main.rs, Cargo.toml, workspace-members.patch, c.sh, slow.sh, clip.sh, export.py, track.py, track2.py, flame.py, sheet.py, rows.py (byte-identical to the built checkout's probe/) |
| ruffle-checkout/ | exact Cargo.lock, git HEAD, git status, full git diff, diff stat, remote, probe binary sha256 and its .comment (compiler) section |
| logs/ | harness stdout command log (verbatim), stderr (adapter line), harness-timeline.csv, slow.log (pacing), first failed cargo attempt |

Not included: the helper captures `/workspace/probe-run/start|run2_start|run3_start|lvl2_start` beyond the listed keyframes, full-colour copies of every frame, and the source/map-extraction outputs (those are in the first pack: `maps/`, `source-findings.md`). The asset folder reference-assets-NOT-FOR-RELEASE is NOT in this supplement.
