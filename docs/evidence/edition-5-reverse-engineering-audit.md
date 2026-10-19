# Edition 5 reverse-engineering baseline and verification gaps

First structural audit, 2026-10-19, following the user's request to reverse-engineer the original before further fidelity rebuilding. Scope: the accepted Normal Arcade/Cinema first build. This is not a claim that the complete retail game, all maps/modes, or runtime parity have been reconstructed.

## Source identity and reconstructed structure

The publisher SWF remains 6,942,081 bytes with SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`; it was rehashed in this audit. [Provenance](edition-5-input-and-timing.md) identifies the build and export method. The [structural reconstruction](edition-5-structure-reconstruction.md) traces startup, ownership, update phases, actors/input, commands, weapons, AI/search, death and results directly through that source, with exact class/method/line locators. Two unusual AI findings were independently corroborated with fresh P-code from the hashed SWF.

[inspect_swf_structure.py](../../tools/inspect_swf_structure.py) produces the [machine-readable inventory](edition-5-structure-inventory.json) from the original SWF and existing decompile. It records:

- 218 ActionScript files under `zlong/bombit5`, with file hashes, lexical class/base declarations and method-declaration counts. This excludes the external libraries and most root/symbol classes; it is not a complete resolved call graph.
- Three ABC bytecode blocks with individual hashes, 635 named symbols and 2,098 sprite definitions.
- Eighteen selected bomb, explosion, block-break, invincibility and weapon timelines. Frame placement/removal events, instance names, transforms, ratios and immediate child metadata are retained. The flamer's four one-frame directional wrappers all reference the 24-frame inner sprite 2212, rather than themselves supplying its attack duration.

The placement decoder uses the maintained [Ruffle SWF reader](https://github.com/ruffle-rs/ruffle/blob/master/swf/src/read.rs) (`read_place_object_2_or_3`) and [placement flag definitions](https://github.com/ruffle-rs/ruffle/blob/master/swf/src/types.rs) as format cross-references, checked on the audit date. A newly generated JPEXS SWF-to-XML export independently agrees on all 18 selected declared frame counts and 336 placement records for the compared fields: containing frame, depth, move flag, present character ID/ratio/name, and affine matrix terms. This does not verify a complete Flash renderer or live bounds evaluator.

The decoder explicitly leaves filter/blend/cache/visibility fields, clip actions and unsupported tag types unevaluated. Display-list inheritance, nested timeline stepping, morph geometry, frame scripts and runtime scaling still need reconstruction before these data can replace original animation-dependent collision behavior. Static shape rectangles are not claimed as live MovieClip bounds.

## Reproduction

Run from the repository root with the existing ignored authority SWF, decompile and JPEXS jar restored:

```powershell
python tools/inspect_swf_structure.py
java -jar .scratch/edition-5-research/ffdec/ffdec.jar -swf2xml .scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf .scratch/edition-5-research/structure-audit/publisher.xml
python tools/inspect_swf_structure.py --verify-xml .scratch/edition-5-research/structure-audit/publisher.xml
```

The XML export completed locally and is retained only in ignored audit storage. The verification command reports `PASS: 18 timelines and 336 placement records agree with FFDec XML for compared fields`. Normal inventory generation is deterministic for the recorded input files; no asset images/audio are exported or added to production.

## Playback harness audit

The supplied reference material is usable preparation, not an independently reproduced runtime baseline yet:

| Artifact / observation | What was checked now | Limit |
| --- | --- | --- |
| Supplemental `tools/ruffle-probe/main.rs` | Reads an SWF path; constructs a 700×510 offscreen player; delivers key/mouse events between explicit `run_frame` calls; advances emulator timers using the player's requested frame rate; captures rendered frames | No game-state field tracing, RNG replay or collision/animation state inspection is provided by this protocol |
| Supplied `ruffle-checkout/git-diff.patch` | Its two tracked hunks add the probe package and workspace member; no core/renderer modification appears in this patch | This is not proof that a supplied binary was built from exactly that tree; only a hash/comment dump is supplied here, not a locally reproduced build |
| Follow-up `common/tools/probe2.rs` | Same explicit stepping/input/timer sequence; asynchronous PNG writing, capture stride and `sync` were inspected | Capture sampling and host time affect what can be inferred; no audio backend is attached |
| Local prerequisites | `cargo` and `rustc` both report 1.97.0; supplied reproduction record reports a Linux build made with 1.99.1 | The supplied folder is not the complete pinned Ruffle checkout or an executable Windows build. Compatibility/build success has not been established locally |
| Existing logs and captures | Already imported with provenance and integrity audits | They remain supplied observations, not a fresh replay performed during this audit |

Primary locators are under `.scratch/edition-5-research/observations/`: `swf-v1.6.1-supplement/tools/ruffle-probe/main.rs:42–125`, `ruffle-checkout/git-diff.patch`, and `swf-v1.6.1-followup/common/tools/probe2.rs:50–137`. The imported [reproduction record](observations/swf-v1.6.1-supplement/REPRO.md) supplies the claimed pinned revision and commands; [the integration assessment](edition-5-play-observations.md) preserves earlier confidence limits. Unknown native AVM2 versus emulator behavior must not be converted into source facts.

## What reverse engineering must establish before the faithful port

| Work | Current evidence | Remaining verification |
| --- | --- | --- |
| Construction and ownership | Class/method reconstruction and hash inventory | Trace runtime creation, replacement and disposal for the selected path |
| Update phases and live mutation | Ordered engine registries, dictionary command chains, callback registrations/removals located | Replay reentrant creation/removal, simultaneous chains and dictionary enumeration effects |
| Fire/contact/protection | Original position/state-change trigger and cleanup counters located | Measure first/final lethal entry, stationary protection expiry, and early/late-phase explosions |
| Weapon timelines | Commands, frame thresholds, source transforms and selected placement timelines recovered | Reconstruct nested bounds, hit/animation/control timing in every direction; compare traces |
| AI | XML state ordering, state/action/search relationships and unusual cadence corroborated | Trace transitions, path choices, cancellation, RNG draws and active-handler rotation |
| Session/ending flow | Player versus robot life state, death animation, mode/end-cartoon/results paths located | Record their actual event delays and one-time accounting in controlled scenarios |

For each scenario, preserve the SWF hash, settings, starting state, frame/input chronology, random draws where relevant, screenshots and structured events/state. Keep an untouched reference separate from any instrumented copy, documenting instrumentation patches and their effects. Compare the rebuilt behavior only after aligning those conditions and explicitly excluding accepted adaptations. The same nominal seed in two different RNG implementations is insufficient.

The 244 Godot checks establish selected new-game behavior; they are not these missing original-reference comparisons. No gameplay behavior or production artwork was changed in this audit. The next gate is controlled reference playback plus reconstruction of the identified dynamic behavior, followed by replacing the corresponding Godot approximations. [Development](../development.md) owns that gate; [DESIGN.md](../../DESIGN.md) owns accepted adaptations and presentation/testing priorities.
