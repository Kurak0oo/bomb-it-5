# Reproducible original-reference tooling

This package executes the original publisher SWF in pinned Ruffle, observes it without changing the SWF, and optionally invokes explicitly recorded original-method fixtures. It is research tooling, excluded from Godot gameplay. The [session record](edition-5-reference-session.md), [trace design](edition-5-reference-trace-design.md) and [event record](edition-5-reference-events.md) retain the initial builds, benchmarks, failed observer-equivalence experiments and limits.

## Canonical build

[Source, lockfile, patches, setup and protocol](../../tools/reference_player/README.md) are committed. Ruffle revision is `45366370ed7d1a59c89aa3cf7b765c7a274407cd`; authority SWF SHA-256 is `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`. Rebuild with Rust/MSVC and Vulkan using:

```powershell
./tools/reference_player/build.ps1 -Fixtures -Events -Compact -Focus
python tools/replay_reference.py --observe --focus --case tools/reference_player/cases/normal-arcade.json --output .scratch/edition-5-research/reference-runs/my-final-reference
```

The canonical final Windows executable was preserved as `.scratch/edition-5-research/reference-player-recovery-v6/probe.exe`, SHA-256 `33d2791282aa7d93d5b9bfe7a1ce166a31e155355e02c8bd584b08a60354ffe8`. It passed locked Rust check/build and replayed the unchanged input-only Normal Arcade case through counter824. [Canonical evidence](reference-2026-10-19/tooling/canonical-final/) retains original inputs, command/stderr logs, manifest, selected images and an opening native state. All 97 weighted-pool references expose their actual represented native class. The three ride entries in this unseeded run are MotoCycleProp; startup randomly selects each ride entry, so this does not contradict the seed1050 two-Car/one-Moto pool in the [pickup probes](edition-5-pickup-probes.md). Source: `gamemode/AbstractGameMode.as:initMap`, ride selection during weighted-array construction.

Build manifests and exact patch archives are preserved under [tooling](reference-2026-10-19/tooling/). The package's Rust source hash matches all v2–v6 manifests. Earlier manifests preserve the exact patch-file bytes used at their build, including historical line endings; the final patch files use LF. The corresponding `exact-patches.zip` archives reproduce each historical patch hash. Versioned executables are kept immutable in ignored investigation storage; they are not production binaries.

| Preserved build | Capability boundary | Executable SHA-256 |
| --- | --- | --- |
| v2 | First eleven patches, through indexed-actor bombs | `5a7adba2c2781818a418f19f5976bad1917b8c64568fd7b562a7660bdc99bb74` |
| v3 | Actual AI-return snapshots added | `ad5a666f20db340b3d21a29c000ba59d8d90f666e21ff5e24ce503fdf4b31ae9` |
| v4 | Original movement-callback fixture added | `9c1dcc316e1344e5061194ba5062abc01396145d89318ea27582058a6bb1ea3c` |
| v5 | Pickup construction during an active action | `04886c020700a6e27249d9986c4179aea8b650bb1becf1c1b34303dd1bbd104c` |
| v6 | Same fourteen-patch semantics, normalized patch bytes and final rebuild | `33d2791282aa7d93d5b9bfe7a1ce166a31e155355e02c8bd584b08a60354ffe8` |

## Ordered research patches

The setup script reverses only exact matching patches in reverse order, rejects unrelated core changes, then reapplies the ordered chain. It touches copied package sources because Copy-Item preserving old timestamps previously allowed Cargo to reuse a stale probe binary. A baseline requires a separate unchanged-core checkout and `-Baseline`; fixture/event/focus features cannot be requested with it.

Review found that a worktree-versus-index check could miss staged core changes. The setup now rejects staged core edits before setup, checks remaining core changes against pinned HEAD and records tracked provenance against HEAD plus untracked core filenames. An actual staged-comment probe reproduced the old omission and the fixed script rejected it before Cargo; the original baseline file/index were restored and verified clean. [Guard evidence](reference-2026-10-19/tooling/build-guard-check.json) and a successful [unchanged-core check manifest](reference-2026-10-19/tooling/baseline-final-check.json) retain the result. No staged contamination of an earlier preserved build was found. Check-only manifests identify the dev check operation and do not attach an executable hash.

1. `reference-observer.patch`: bounded native slots/dynamic storage/arrays/display metadata and weak Game discovery. No AS enumeration cursors, getters or game-field writes.
2. `reference-fixtures.patch`: opt-in allowlisted constructors, guarded original reposition and ordinary controller bomb invocation. Results classify original side effects separately from input-only play.
3. `reference-events.patch`: original AVM2 body entry/return/error, actual consumed Math.random raw/results/caller chains, bounded buffers, explicit loss/truncation and initial-seed control. Collection defaults off; no RNG interception/replay queue exists.
4. `reference-compact.patch`: logical graphs with native display leaves rather than full painting trees. Same-boundary full/compact data were compared.
5. `reference-focus.patch`: explicit physical-slot projection of selected Game/actor/equipment/AI/callback/cell/bomb state. Same-boundary full/focus values and namespace layouts were compared. Automatic weak-Game bootstrap is marked separately.
6. `reference-actors.patch`: optional current Game.players index0–3 for pickup/reposition and original AI stop/start methods. Registration and nondead model state establish liveness; `isExist` is damage eligibility.
7. `reference-geometry.patch`: bounded native Script bounds and raw transforms. No AS property calls, scale-cache getters or Engine-mode morph-bound reads. The [88-endpoint comparison](edition-5-weapon-interaction-probes.md) verifies sampled original endpoint calculations.
8. `reference-drops.patch`: original block creation/break-animation callback and Arcade timePassed callback experiments. They do not assign budgets, RNG, Date, pastTime, score or outcomes; direct breaking bypasses legal attack targeting/credit.
9. `reference-session-state.patch`: focused map-master, world-set and ending records.
10. `reference-class-names.patch`: represented native ClassObject definition names, preserving order/duplicates. Runtime opening-pool validation is retained above.
11. `reference-actor-bombs.patch`: optional indexed actor for the existing original addBomb operation. Both-owner recursive chains validated ownership and guard/capacity effects.
12. `reference-ai-returns.patch`: copy stored AstartPath cost/path at actual RoadSearch.findPath return and AI perception arrays at actual updatePerceptions return, before later selectors mutate them. No receiver is retained in event State/Token. Bounds are128 array entries/depth3, with explicit truncation; the [AI record](edition-5-ai-runtime-probes.md) validates actual return metadata and bounded old/new native projections.
13. `reference-move-step.patch`: one original selected RobotController cardinal callback, including model acceleration, HitMove and occupancy effects, without advancing a frame. Listener/input scheduling is explicitly bypassed. Mine contact and portal approach cases validate it.
14. `reference-active-pickups.patch`: permits only pickup construction while the selected living actor is interrupted; movement/control fixture guards remain. Normal GetItem collection owns replacement/disposal. The successful late-flamer replacement validates that boundary.

A [fresh patch check](reference-2026-10-19/tooling/fresh-patch-check.json) applies all fourteen patches to pristine files extracted from the pinned revision. All nine resulting Rust source files match the live compiled checkout after line-ending normalization. This supplements successful locked checks and the canonical original-game replay.

All these helpers read native metadata or call the named original methods; none patches game algorithms or supplies private health, score, result, fire, velocity or AI-state assignments. Fixture calls can legitimately consume original RNG, invoke damage, dispose equipment or end a round. Those effects are recorded, not relabeled as passive observation. The default original-RNG seed and event modes are untouched unless explicitly requested.

## Provenance corrections and measurement limits

The earlier focused binary `9325acc…` supports the benchmark taken after an explicit full observation, but did **not** contain the source's automatic bootstrap change: preserved source timestamps let Cargo skip that probe rebuild. Its recorded source hash therefore must not be used as proof that automatic bootstrap ran in that binary. The later actor build verified bootstrap at runtime, and the setup script now prevents that stale-copy problem. This does not invalidate the same-boundary data comparisons actually performed after full observation.

The driver hash-checks the authority and stages a byte-identical temporary SWF under a path without dot-prefixed components. Loading from `.scratch` itself makes original SharedObject initialization fail in Ruffle. Captured case bytes are frozen before execution; manifests use those bytes, matching acknowledged inputs, image dimensions/frame counters, fixture results and clean child exit. Output directories must be new. Host monotonic and player wall time remain in command logs; rendering/capturing/state serialization cost real host time.

Original Date/getTimer/Tween behavior remains active. Equal seeds do not establish equal complete sessions; event-OFF runs also diverge later. The event report preserves the failed whole-session equivalence experiment, while AI and chain records retain narrower successful comparisons. No blanket observer neutrality, Adobe Flash equivalence, deterministic cross-engine RNG or complete pending-timer-queue inspection is claimed. Bounded schemas, missing roots and source backing slots are not treated as evidence of an object's absence or actual physical position.

Independent metadata checks include original-source hashes, static timeline/placement comparison with FFDec XML, and actual getter versus native-bound measurements. The unchanged Godot suite remains functional verification of the rebuild; it is not reclassified as original-SWF parity.
