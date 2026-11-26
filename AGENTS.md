# Agent notes

Read [docs/development.md](docs/development.md) first: it holds the restart plan, the
rules of work and the checkpoints. Then read the current checkpoint's issue (linked under
Status there): it is the handoff between sessions. Work only on the current checkpoint.

- **One feature per session.** Start from the checkpoint issue's three lists (owner reports
  awaiting confirmation first, owner decisions not to reopen, what changed), finish one
  verified increment, and end by commenting the updated lists on that issue. Do not add a
  status log to docs/development.md or any other file.
- **Never close a `ui-art` issue.** Post results with `python3 tools/compare/post_review.py
  ISSUE CASE... --post` (it labels the issue `ready-for-owner-review`); the owner closes it.
  A close through an app is reopened by `.github/workflows/owner-gate.yml`.
- **State before pixels.** Fix the comparison's first divergence before anything else; use a
  `trace` action for behaviour between captures. Pixels are scored only once nodes match.
- **Look before you report.** Load the case in the playground
  (`tools/playground.sh --case C --capture X`) or run it, and do not report a UI or
  behaviour fix from checks alone.
- **Goldens are compressed.** Read and write them through `tools/golden_io.py` (Python) or
  `GoldenFile` (GDScript), never with plain file reads.
- **Godot upstream.** Godot's contribution rules forbid AI-authored engine code and agent
  pull requests: report an engine bug to the owner instead of patching the engine.

- UI and art are placeholders until the owner confirms them. Never close a UI or art
  ticket on automated checks alone; the comparison loop only says a screen is ready
  for review.
- Generate positions, scales, button states and timing from SWF data. Do not type in
  coordinates or measure screenshots.
- Port AS3 close to line for line, keep the original class and method names, and
  cite the source method in a comment.
- Before implementing recovered behavior or parity checks, read
  [docs/evidence/README.md](docs/evidence/README.md) and the relevant records. Link
  behavior to its source.
- Use and update [GLOSSARY.md](GLOSSARY.md) for domain terms; it holds definitions only.
- Older decisions, specs, ADRs and verification records are under the `pre-restart`
  tag. Read them there when a task needs history; do not restore them.
- Before export work, read [docs/douyin.md](docs/douyin.md) and verify its platform
  claims against current official documentation.
- Original art, audio and the SWF stay in the ignored local pack; never commit them.

Do not copy files from `C:\Users\Eiji\Github\bomb-it-1`.

## Orchestrator

**Orchestrator** (the session that plans and delegates): work here runs through the `orchestrator` skill; read it before changing code. Every source change goes through a subagent profile, and every task carries a gate.

**Generated art is the orchestrator's own work.** Art the orchestrator makes from its own ability (for example, drawing a new character or map that no code can derive from the SWF) is done by the orchestrator, not a worker. Art that code or another model can produce goes to a worker like any other task: `tools/convert/record_screen.py` passes (`actors`, `sets`, `modes`, `shots`) and SWF conversions. The orchestrator owns those passes' flags in its briefs (`actors` keeps `--looks all`).

**Worker** (you were started with a brief that has Objective, Files and Gate): ignore the paragraph above. Do the brief yourself, directly; never run `devspace agents` or hand work to another agent. The sections below are reference for you too.

There is no `package.json`. Checks are Godot 4.5 scripts, run from the repo root. Godot is `/Applications/Godot.app/Contents/MacOS/Godot` (4.5.stable). Timed 2026-11-18.

## Gates

- One file (worker gate, must finish in under 50 seconds). Pass the check that covers the files you changed:

  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/<check>.gd`

  Timed passes, slowest first: `flow_scene_check.gd` 13.56s, `looks_check.gd` 10.21s, `controls_check.gd` 6.14s, `difficulty_check.gd` 2.04s, `quality_check.gd` 1.35s, `game_board_check.gd` 1.26s, `stage_features_check.gd` 1.17s, `game_scene_check.gd` 0.88s, `fidelity_check.gd` 0.77s, `round_play_check.gd` 0.58s, `layout_check.gd` 0.48s, `round_regression_check.gd` 0.39s, `pac_man_check.gd` 0.39s, `green_zone_check.gd` 0.38s, `command_boundary_check.gd` 0.31s, `scheduler_check.gd` 0.29s, `bomb_simulation_check.gd` 0.29s, `mode_seam_check.gd` 0.29s, `kill_check.gd` 0.29s, `hitmove_check.gd` 0.29s, `audio_check.gd` 0.29s, `ai_trace_check.gd` 0.29s, `session_check.gd` 0.19s, `art_catalog_check.gd` 0.19s, `avm_random_check.gd` 0.19s. `tools/playthrough_check.gd` passed in 9.7s (7 playthroughs, 2026-11-22) (`res://tools/playthrough_check.gd`). Compare-tool unit tests: `python3 -m unittest discover -s tools/compare` (about 4s) and `python3 -m unittest tools/test_golden_io.py`.

  Do not give a worker `res://tools/smoke_playthrough.gd`. It passed in 242.71s, which is past both the 50-second gate budget and dsh's 60-second shell limit. It runs only inside the full suite, with `--fixed-fps 35`.

- Playground checks, before reporting a UI or behaviour fix:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 35 --script res://tests/playground_check.gd`,
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 35 --script res://tests/playground_plugins_check.gd`,
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 35 --script res://tests/playground_tools_check.gd`.
  Each prints its own PASS line. Pixel scoring is `compare.py check --pixels` at acceptance only.

- Launch gate (before any other check): `GODOT=... tools/launch_gate.sh` boots the main scene and every generated screen headless for 120 frames and fails on any script or engine error (about 20 s). It always passes `--quit-after` and never `-d`; a headless run without `--quit-after` never ends, and one under `-d` stops at an interactive `debug>` prompt on a script error.
- Typecheck: none. This repo has no typecheck script. Godot parses each script when its check runs; the launch gate catches errors in scripts no check loads.
- Full suite, run once at close: `GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/run_checks.sh`

## Seams

- `scripts/ui/` ↔ `scripts/simulation/` through `scripts/simulation/command_boundary.gd` (input) and the round snapshot on `scripts/simulation/bomb_simulation.gd`. `scripts/game.gd` and `scripts/game_view.gd` own the scene wiring.
- Modes register only through `scripts/simulation/modes/modes.gd`. Cut a mode slice at that file plus the one mode module.
- Stage features register only through `scripts/simulation/features/features.gd` (`belt`, `toy_hand`, `crocodile`, `spellbook`).
- Weapons, movement, and pickups stay behind `scripts/simulation/bomb_simulation.gd` (`weapons.gd`, `movement.gd`, `pickups.gd`).
- Art and screen layout (`scripts/art/catalog.gd`, `scripts/art/screen_layout.gd`, `scripts/art/skin.gd`) feed UI. Simulation reads board data, not scenes.
- Settings and unlocks cross `scripts/session.gd` and `scripts/save_store.gd`.
- Visual parity crosses `tools/compare.sh` and `tests/goldens/<case>/`. The differ's own tests are `python3 -m unittest discover -s tools/compare`.

## Risky areas

These get a `ds-reviewer` pass after merge:

- `scripts/simulation/` (shared damage, scoring, movement, and modes)
- `scripts/save_store.gd` (persisted settings and unlocks)
- `scripts/ui/` (owner confirms UI; automated checks do not close those tickets)
- `tests/goldens/` and `tools/compare/` (accepted visual floors)
- `tools/reference_player/` (original-behavior probes)

## Untouched

No task changes these:

- `original/`, `candidates/`, and `candidates*.zip` (local SWF-derived art; gitignored)
- `.scratch/`, `.godot/`, and `.import/`
- `docs/evidence/` (source records; do not rewrite them to make a check pass)
- Anything under the `pre-restart` tag, and anything copied from `bomb-it-1`

## Agent skills

### Issue tracker

For specs and tickets, use GitHub Issues in `Kurak0oo/bomb-it-5`. Read
[tracker conventions](docs/agents/issue-tracker.md) before tracker operations.

### Triage labels

For triage roles and issue labels, use the [label mapping](docs/agents/triage-labels.md).

### Domain docs

This is a single-context project. Before domain exploration, read the
[domain documentation rules](docs/agents/domain.md).
