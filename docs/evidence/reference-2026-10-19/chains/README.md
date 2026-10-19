# Chain and overlap evidence

Read [the focused report](../../edition-5-chain-overlap-probes.md) for interpretation and limits. Six original SWF cases use the same verified v2 player; each folder contains the exact case, acknowledged protocol, fixture inputs/results, build/manifest, measured checkpoints, per-frame native extracts, selected mutation events, full raw events at decisive frames, and unmodified screenshots.

- `chain-human-first`, `chain-ai-first`: recursive listener calls, owner-preserved victim damage and live-array cleanup removal.
- `overlap-left-first`, `overlap-right-first`: shared Boolean fire cleared before younger visible explosion ends; eligible actor survives entry.
- `laser-late-chain`: bomb triggered after cleanup phase; same-frame new command chain and next-frame LaserEnd enumeration.
- `portal-command-replacement`: old immunity dispose, new command installation, original portal completion.
- `observer-off`: exact comparison case/protocol/manifest; [observer-comparison.json](observer-comparison.json) records 105 bounded per-frame comparisons and original file hashes.

`assessment.json` records 27 evidence assertions. `sources.json` records primary decompile hashes and exact function line locators. `extract.json` includes every raw event-file hash, counts, overflow checks and extraction limits. `mutation-events.json` is a selected excerpt: sequence/call/depth are original, but a parent may reference an omitted ancestor. The `raw-events` files retain the complete selected collector output at important frames. Object addresses correlate within one run only. Full raw Focus files remain in ignored investigation storage, named and hashed in the extracts.

Re-extract with `tools/inspect_chain_probe.py`. It reads recorded native state only, rejects truncated/ambiguous Focus data and rejects dropped/unbalanced event collection; it does not execute any ActionScript. These records are original-engine research evidence, not Godot runtime tests.
