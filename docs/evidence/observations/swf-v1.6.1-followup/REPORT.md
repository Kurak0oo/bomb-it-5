> Imported Dots supplemental record; assertions are retained as delivered. Read the [integration assessment](../../edition-5-play-observations.md) for confidence, corrections and remaining limits. Source-relative paths in code spans refer to the [unaltered original](../../../../.scratch/edition-5-research/observations/swf-v1.6.1-followup/REPORT.md).

# Bomb It 5 v1.6.1, phase 2 follow-up report

Exact SWF only: bomb-it-5-zh-fix.swf, sha256 718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2.
Harness:
- `probe2` (Ruffle 45366370ed7d1a59c89aa3cf7b765c7a274407cd; rustc 1.99.1; wgpu Vulkan on llvmpipe, Mesa 25.0.7)
- binary sha256 108294555d3a2a242f36b096ea12fc8b066d594998b543f8d31d85f47f6d8ebf
- source in common/tools/probe2.rs
- earlier session A used the phase-1 `probe` binary

Constraints: no cheats, no memory edits, no SWF edits, no other editions.
Tags: [O] observed, [S] source, [I] inferred, [U] unknown.
All frames are full-colour, uncropped 700x510 RGBA, losslessly re-encoded. Inputs are logged with absolute frame counters.
reference-assets-NOT-FOR-RELEASE is not included. The only SWF-derived art is the "prop" sprite sheet in task2_mapping/evidence, marked NOT FOR RELEASE.

| Task | Result | Folder |
|---|---|---|
| 1. Glove identity and controls | **Done.** BOXING GLOVE = BoxingProp (red glove, Space, 2 punches, range 2): P1 picked it up at f1276 in Battle Royale and punched at f1278 (no target) and f1382 (the AI below lost its skateboard [I]). PUSH THE BOMB = BombShoesProp (white hand, passive, walk into a bomb): picked up at f1910 in Arcade, kicked at kd down @1944, slide f1946–1965, fuse paused, blast f2025 | task1_gloves/ |
| 2. Item map and behaviour search | **Done.** Full map of help label ↔ class ↔ propNum ↔ sprite frame ↔ drop weight. Bouncer: **UNIDENTIFIED** (closest is GrenadeProp's thrown grenade, which needs modes with no menu entry). Magic carpet: **UNIDENTIFIED as a usable item**, though carpet art exists as sprite frame #40 with no class found using it. Heavy bomb: **UNIDENTIFIED** (frame #27 is a large black-ball icon with no class found). Not proven absent. FROG and SKATEBOARD seen in play | task2_mapping/ |
| 3. Arcade/Normal/1P/3 enemies/first character victory | **Victory by elimination**: all 3 AI died before time-up (last one at f4854, TIME 59), then YOU WIN f4908, LEVEL 1/5 COMPLETE, OK, NEXT → LEVEL 2/5 at f5741. **Caveat:** ENEMIES KILLED 0, because the AIs died in their own or each other's bombs while P1 was idle. A win where P1 kills all three was not achieved in 2 games; stopped with what was tried recorded | task3_victory/ |
| 4. Three runs each | **Done.** Pickup 3 runs (+1); Space held 3/3 placed one bomb; Space repeated 3/3 placed one bomb; flame 17 frames in 6/6 runs; fuse 72 or 73 | task4_repeats/ |

Logs and tools are in common/:
- input logs and notes for sessions A, B0, C and D
- probe2.rs with its sha
- helper scripts
- the frame selection script and selection table
- git status

The index is in INDEX.md.
