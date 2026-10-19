# Dots delivery assessment and play observations

Updated 2026-10-17 after importing the 11-part supplement and 17-part follow-up. **The three previously highlighted gaps are now closed or narrowed:** all 23 indexed harness screenshots are present; the playback harness, lockfile, patches and input logs are supplied; both glove candidates have captured controls, and normal Arcade elimination victory is captured.

**2026-10-19 occupancy update:** a [repeated two-frame pixel audit](cinema-stage1-recorded-board.md) resolves the previously uncertain rendered first-board occupancy and corrects cell (14,10) to soft. It yields a canonical 255-cell reconstruction with 68 soft blocks; it is not a runtime-state extraction. The sections below retain the import-time assessment for context; current occupancy status comes from that newer record. Three item identities remain unresolved.

## Locations and preservation

| Material | Canonical location |
| --- | --- |
| Initial exact-SWF report and source findings | [SWF report](observations/swf-v1.6.1/REPORT.md), [source findings](observations/swf-v1.6.1/source-findings.md) |
| Static map templates and reported first board | [44-map index](observations/swf-v1.6.1/maps/INDEX.md), [CinemaStage1 transcription](observations/swf-v1.6.1/play/first-board.md) |
| Restored captures, corrections and harness reproduction | [Supplement manifest](observations/swf-v1.6.1-supplement/MANIFEST.md), [corrections](observations/swf-v1.6.1-supplement/CORRECTIONS.md), [reproduction record](observations/swf-v1.6.1-supplement/REPRO.md) |
| Screenshots, full-colour keyframes and clip ranges | [23-still index](observations/swf-v1.6.1-supplement/SCREENS_HARNESS_INDEX.md), [keyframe index](observations/swf-v1.6.1-supplement/KEYFRAMES_INDEX.md), [clip manifest](observations/swf-v1.6.1-supplement/CLIPS_MANIFEST.md) |
| Item controls, mapping, normal victory and repeated probes | [Follow-up report](observations/swf-v1.6.1-followup/REPORT.md), [file index](observations/swf-v1.6.1-followup/INDEX.md) |
| HTML5 alternate runtime and exact-SWF static supplement | [HTML5 report](observations/html5-alternate/report/bomb-it-5-gameplay-evidence-report.md), [static findings](observations/html5-alternate/source/static-findings.md) |
| Initial per-file provenance and validation | [Original inventory](observations/artifact-inventory.json), [original audit](observations/import-audit.json) |
| Supplemental per-file provenance, archive hashes and validation | [Supplemental inventory](observations/supplemental-artifact-inventory.json), [supplemental audit](observations/supplemental-import-audit.json) |

Raw media, delivered scripts and lockfiles remain under ignored `.scratch/edition-5-research/observations/`, in distinct `swf-v1.6.1/`, `swf-v1.6.1-supplement/`, `swf-v1.6.1-followup/` and `html5-alternate/` directories. All 28 new ZIPs are retained under `archive-deliveries/drive-download-20261017T120705Z-1-001/` with their hashes. Supplemental series were merged only within their own series; duplicate manifest/checksum entries were byte-identical. Existing raw packs were not overwritten.

The first intake preserved 318 files and imported 123 text/data documents. The supplement adds 2,354 unique files and the follow-up 1,255, totaling 3,609 new expanded files (484,695,602 bytes), plus the 28 original archives. Nineteen new Markdown/CSV/TSV records are copied into the evidence tree. Imported Markdown carries a notice pointing to the unaltered raw record; original claims remain intact. Code-span paths retain the original Dots workspace context. Checksum lists apply to raw originals, not rewritten Markdown copies. A fresh clone needs the ignored evidence restored to resolve raw links.

## Authority and confidence

The reports identify the publisher SWF by SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`, matching [the provenance record](edition-5-input-and-timing.md). Exact-SWF observations use custom Ruffle harnesses at commit `45366370ed7d1a59c89aa3cf7b765c7a274407cd`. HTML5 play remains a separate alternate build with unverified parity.

Import validation checks archive integrity, supplied checksums, file decoding and representative visuals. I inspected the first Cinema board, help page, glove acquisition/punch, passive kick, YOU WIN with TIME 59, results and next-level board. The delivered session-C log contains no player key input between the retry at counter 1321 and the win sequence. These corroborate the reported elimination path; individual bomb ownership remains partly inferred.

The supplied harness source was read statically, **not built or independently replayed**. It explicitly steps `run_frame`, advances emulator timers and records inputs between frames. `probe2` adds asynchronous capture, capture stride and synchronization. These artifacts make the observations inspectable; they do not establish native Flash equivalence, measured phone cadence, or successful reproduction on our machine. The exact compiler is reported as rustc/cargo 1.99.1; a compiler-comment dump and lockfile are supplied, but were not independently authenticated against a rebuilt binary.

## Previously missing material

| Earlier gap | Current assessment |
| --- | --- |
| 23 `h01`–`h23` screenshots | **Restored.** All 23 full-colour native 700×510 stills are in [raw screens_harness](../../.scratch/edition-5-research/observations/swf-v1.6.1-supplement/screens_harness/). |
| First-board frame 697 and adjacent loading frame | **Restored.** [Frame 696](../../.scratch/edition-5-research/observations/swf-v1.6.1-supplement/keyframes_fullcolour/first_board/f000696.png), [frame 697](../../.scratch/edition-5-research/observations/swf-v1.6.1-supplement/keyframes_fullcolour/first_board/f000697.png) and frame 698 are delivered. The transcription's uncertain soft-block cells still need a focused check. |
| Probe frame sequences | **Substantially restored with limits.** 2,146 uncropped probe PNGs retain frame numbering; most are palette-quantized rather than original full colour. Chain and timeout sequences are intentionally sampled outside their key windows. One hundred full-colour keyframes supplement these; three boot images are wider composites, so the manifest's blanket native-width claim is too broad. |
| Custom harness and reproducibility data | **Delivered.** Rust source, Cargo manifest/lockfile, workspace and checkout patches, compiler/adapter records, command logs, timeline, helper scripts and clip manifest are supplied. Build/launch details and crop rectangles are partly reconstructed, explicitly marked. Independent replay remains unperformed. |
| Glove identity and controls | **Both candidates demonstrated.** Choosing what the accepted empty slot means remains a product decision. |
| Normal all-enemies-dead victory | **Demonstrated.** All three AI die before timeout, then YOU WIN, results and NEXT to level two. Player kill credit is zero; personal kills were not required by the requested ending test. |

## Fulfillment of the investigation priorities

| Requested priority | Assessment after supplement |
| --- | --- |
| 1. Screen flow | Substantially fulfilled: manual/harness stills cover selections, instructions, pause, defeat, timeout and ordinary elimination victory/results/Next. No complete campaign was requested. |
| 2. Complete match and untouched first board | Start capture and a normal terminal outcome are supplied with setup and inputs. The first CinemaStage1 transcription still contains uncertain soft-block cells; it is not yet a certified collision map. The elimination win occurs on a retry BirthdayParty board, not that first Cinema instance. |
| 3. Layout and uncropped screenshots | Native full-screen starts, help, HUD and endings are restored alongside static anchors. Verify final board/HUD geometry against these before implementing. Cropped clips and the three boot composites cannot establish native screen bounds. |
| 4. Systematic mechanic probes | Much stronger: logged original probes and three-run pickup/held/repeated-input cases now accompany captures. Not exhaustive: no OS auto-repeat, broad portal/protection/lifecycle tests or independent replay. The claim that concurrent bomb-array removal explains a one-frame fuse delay remains an inference for the observed run. |
| 5. Animation and feedback | Frame sequences and original 12 MP4/GIF pairs support local visual comparisons; sparse sections and palette conversion are documented. No captured audio; a 35-fps encoding is not measured game speed. HTML5 sparse captures remain unsuitable for FPS measurement. |
| 6. Four named items | Both glove candidates have acquisition/use captures and a source/icon mapping. Bouncer, magic carpet and heavy bomb have a broader behavior search and explicit unknown verdicts; they have not become verified usable mechanics. |

The five requested deliverables are present: reports, numbered screenshot indices, recordings/frame sequences, a first-board transcription, and unresolved questions/contradictions. The remaining limitations are evidence certainty and unidentified behavior, rather than the three originally missing artifact groups. The request is substantially fulfilled, with these limits still preventing a complete reconstruction. Continue scoped design using the relevant records; do not treat every reported detail as proven parity.

## Recovered behavior and corrections

1. **Two glove candidates have different controls.** [Task 1](observations/swf-v1.6.1-followup/task1_gloves/README.md) and the captured help page distinguish red BOXING GLOVE (`BoxingProp`, propNum 38) from white-hand PUSH THE BOMB (`BombShoesProp`, propNum 6, XML comment 手套). Captures show acquisition and two Space punches in Battle Royale; Arcade captures show the white-hand pickup followed by walking into a bomb to kick it without pressing Space. Exact damage attribution in the simultaneous boxing exchange is partly inferred. All four design item slots remain empty until the glove identity choice and relevant implementation scope are accepted.
2. **Three slots remain unidentified.** [Task 2](observations/swf-v1.6.1-followup/task2_mapping/README.md) maps classes, sprite numbers, help labels and drop weights. It reports carpet art at sprite frame 40 and a large black-ball icon at frame 27 without a discovered reachable item class. Grenade, ride, map-device and kick behaviors were considered for bouncer. Neither absence nor equivalence is proved. The two derived sprite sheets remain reference-only raw media.
3. **Normal elimination victory is distinct from timeout completion.** [Task 3](observations/swf-v1.6.1-followup/task3_victory/README.md) provides the last AI death at frame 4854, YOU WIN at 4908 with TIME 59, results with zero credited kills/time bonus 590/Normal bonus 2000/total 2590, and NEXT to Cinema level two at 5741. Some bomb-owner explanations are inferred; the visible ending does not depend on assigning the player those kills.
4. **Fuse callbacks and visible intervals differ.** `Bomb.takeCount` tests `_time > _blastTime` before incrementing from zero; threshold 70 means the 72nd countdown callback triggers the blast. The old "71st tick plus render offset" explanation is withdrawn in [CORRECTIONS](observations/swf-v1.6.1-supplement/CORRECTIONS.md). [Repeated probes](observations/swf-v1.6.1-followup/task4_repeats/README.md) report 72-or-73-frame intervals measured from logged input counters and 17 visible flame frames. Input-counter time, first-visible bomb time and callback count are different measurements; normalize their origins before comparing runs. A skipped callback during concurrent removal is a proposed source explanation, not an independently reproduced cause.
5. **Round time is wall-clock dependent in the original.** Local `Game.countTime` compares `Date.getSeconds()` and increments once on change; it can miss seconds during stalls. Manually stepping frames and encoding them at 35 fps does not reproduce that clock. The timeout clip still shows TIME'S UP followed by LEVEL COMPLETE with enemies alive, corroborating the source anomaly. Current remake choices belong in [DESIGN.md](../../DESIGN.md), separate from these original facts.
6. **Drops and maps have conditional source behavior.** Conditional drops are source-supported and visually captured; quotas, suppression and protection still require the relevant trace. All 44 map CSVs passed the prior structural check for 255 unique x0–16/y0–14 cells. That does not certify every tile interpretation or the occupancy of one randomized start. Restoring frame 697 removes the missing-image blocker, not the transcription's author-marked uncertainty.

## Integrity and remaining work

- All 28 ZIPs pass CRC checks and extraction path checks; there were no conflicting duplicate members. All 3,605 listed SHA-256 entries pass. The four unlisted files are each series' manifest and checksum file; all 3,609 expanded files and all original ZIPs have independently recorded inventory hashes.
- All 3,532 supplemental images (including 12 GIFs) pass structure and pixel decoding, and all 12 supplemental MP4s decode without errors. Original-art and tooling remain outside production assets. See the [machine-readable audit](observations/supplemental-import-audit.json).
- Recheck uncertain CinemaStage1 soft-block occupancy against the restored full-colour start and static source before accepting a concrete first collision board. Keep template randomization separate from the accepted no-generator rule.
- Decide which glove candidate, if either, fills the accepted named slot. Keep bouncer, carpet and heavy bomb unresolved until an exact behavior mapping is established or a deliberate scope choice is accepted.
- Build/replay the delivered harness only when reproducibility or a targeted timing/lifecycle question requires it. Its source is now available; this import did not execute supplied code. Full-colour originals for every probe, unsampled helper runs, map-extraction helpers and some HTML5 assembly/failure logs remain undelivered, as the manifests state.

No additional Dots request is needed just to restore the three earlier headline gaps. Further requests should target a specific remaining uncertainty rather than re-requesting the delivered screenshots, harness or ordinary victory.
