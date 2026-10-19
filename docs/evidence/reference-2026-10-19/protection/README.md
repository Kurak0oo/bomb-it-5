# Protection and Cinema-ride reference captures

Read the [assessment and primary-source locators](../../edition-5-protection-vehicle-probes.md) before using these files as a parity oracle. Every case runs the exact original publisher SWF through the same pinned, explicitly instrumented player. Fixtures call original operations and are recorded separately from ordinary keyboard inputs.

| Directory | Raw run in `.scratch/edition-5-research/reference-runs/` | Purpose |
| --- | --- | --- |
| [car](car/) | `protection-car-03` | Car, replacement shield, self-bombs, recovery, retained weapon/input, Normal AI collection |
| [moto](moto/) | `protection-moto-02` | MotoCycleProp (`_Skateboard`), same lifecycle and eligibility checks |
| [invincibility](invincibility/) | `protection-invincibility-01` | Introduction, shielded contact, subsequent enemy death, active-counter expiry |
| [pause](pause/) | `protection-pause-02` | Counter pause/resume and original menu return |
| [ordinary-enemy](ordinary-enemy/) | `protection-enemy-bomb-01` | Legal human bomb kills eligible enemy; owner/score/life/capacity observations |

Each directory contains:

- `case.json`, `commands.jsonl`, `player-build.json` and the original stderr. `raw-manifest.json` is the unmodified raw-run manifest; its full list of snapshots/captures refers to the raw run, including files intentionally not duplicated here.
- All `fixture-*.json` requests/results, showing original calls and before/after states.
- `checkpoints.json` for all recorded checkpoints, plus a concise per-frame timeline retaining players 0/1. Every row includes the SHA-256 of its raw Focus observation; other actors are not implied absent or zero. Checkpoints retain all projected actors.
- Selected PNGs, including actual collection, damage, recovery/contact and menu states.
- `extract.json` identifies the source run and hashes. `files.json` hashes the curated files in this directory.
- `ordinary-enemy/score-events.json` retains the original game's actual score/kill getter and setter calls, plus hashes of all source event chunks and their discarded-event count.

The full native Focus files remain in ignored storage because they repeatedly include static grid/layout data. Regenerate the extracts with `tools/inspect_protection_probe.py`; regenerate original observations with the committed cases under `tools/reference_player/cases/protection/` and `tools/replay_reference.py --observe --focus --fixtures`. Both tools validate source schema/truncation rather than filling missing values.

These are investigation assets. They are not production Godot art, an Adobe-player equivalence certificate, a phone test, or proof that queued asynchronous work is fully paused/disposed.
