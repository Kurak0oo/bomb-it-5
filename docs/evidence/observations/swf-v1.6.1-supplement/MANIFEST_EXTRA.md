> Imported Dots supplemental record; assertions are retained as delivered. Read the [integration assessment](../../edition-5-play-observations.md) for confidence, corrections and remaining limits. Source-relative paths in code spans refer to the [unaltered original](../../../../.scratch/edition-5-research/observations/swf-v1.6.1-supplement/MANIFEST_EXTRA.md).

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
