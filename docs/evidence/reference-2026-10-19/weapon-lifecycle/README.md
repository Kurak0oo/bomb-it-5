# Original weapon lifecycle evidence

Read [the source/action recovery report](../../edition-5-weapon-action-recovery.md) and [target interaction report](../../edition-5-weapon-interaction-probes.md) for interpretation. This bundle contains the final **15 scenario stems**, choosing the latest completed revision of each. Triple's pending-recovery pause uses revision02; the inconclusive earlier revision is excluded.

- Five early-pause cases: original animation/early emission stops across actual pause/resume.
- Five early replacement cases: four replacements succeed; the flamer's pending incoming pickup is destroyed before it becomes equipped.
- Two paced first actions: triple and fireball with explicit `realtime 1` and recorded host intervals.
- Two pending-recovery pause cases: callbacks complete while already paused; resume Space also starts a second action, later exhausting the weapon.
- One later flamer replacement: original next-frame pickup collection replaces/disposes an active flamer on736. Its v5 fixture permits pickup constructors during interruption; it does not force replacement or write weapon fields.

Each run retains its exact executed `case.json`, original manifest/build, acknowledged command log, stderr, fixture inputs/results, selected unmodified screenshots, `action-sequence.json` and `action-events.json`. The per-frame native summary includes original Focus hashes, paused state, interruption, physical position, current model equipment and observed play-frame/counter data. A null matching `weapon` entry can mean the original kind was replaced; read `current_equipped_model` before concluding no equipment remains.

Method/receiver groups retain original AVM2 indices, sequence bounds, frame sets and bounded argument examples. `action-events.json` retains selected original entries and matching returns/errors in original sequence; excluded parents may still be referenced. `raw-events` retains complete collector output at recovery, actual pause and active-flamer disposal boundaries. Every raw packet's hash/count is indexed. All selected calls are balanced with zero dropped records/overflow; no selected execution errors were observed. IDs correlate only within one process.

`index.json` lists the final runs; `assessment.json` records **126 passing evidence assertions**, including exact current public case bytes, manifest player identity, command/stderr/screenshot and native-frame hashes, actual pause-versus-recovery ordering, observed replacement outcomes, final exhaustion and pacing. These assert the retained original evidence, not Godot parity. The enclosing `docs/.gdignore` keeps investigation material outside Godot resources.

Reproduce using the case's recorded player build and `tools/replay_reference.py --observe --focus --fixtures`. [The action index](../weapon-survey/action-sequences.json) additionally contains all 24 first-action surveys. `tools/inspect_weapon_action_sequences.py` regenerates native/grouped observations from immutable raw run directories and selects the latest completed lifecycle revision per stem. Full raw Focus/ordinary event histories remain in ignored `.scratch/edition-5-research/reference-runs/` under the same run names; retained summaries name/hash their source files. No AS getters or original methods are executed by extraction.
