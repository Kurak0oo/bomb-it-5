# Bomb It 5

Landscape phone game. The match rules come from the original Q版泡泡堂5 (edition 5) SWF. The pictures, names, and audio in a Douyin build are original. This is not the [bomb-it-1](https://github.com/Kurak0oo/bomb-it-1) repo, and that repo stays parked.

**This is the `original-replica` branch:** a faithful reproduction of edition 5, run under the `original` fidelity profile ([ADR 0008](docs/adr/0008-original-replica-build.md)). To see the original art, build the local pack from your own SWF with `python tools/art_pipeline/original_pack.py`; it stays out of git.

Open `project.godot` in **Godot 4.5** with the Compatibility renderer.

The desktop game is playable: open the project and press **F6/F5**, or run `./tools/play.ps1` with the local Godot 4.5 executable. It opens on the main menu: **START** leads to Game Settings (Arcade, Battle Royale, Pac-Man or Green Zone; one to three enemies; 5–20 levels; a random or chosen stage set; Easy, Normal or Hard) and character select, then a multi-level session across the six stage sets. **HOW TO PLAY** shows the controls, key rebinding and power-ups; looks unlock as your session total grows and are saved locally. Default keys are **Arrow keys** and **Space**, with **P** or the pause button to pause. The visible stick and bomb button also accept desktop-emulated touch. The fixed practice board is a development launch: `./tools/play.ps1 -Practice` (or `-- --practice`).

Physical phone/iOS testing and export are deferred. The four unresolved named item slots remain empty; see [runtime evidence and adaptation limits](docs/evidence/edition-5-runtime-systems.md).

## Where knowledge lives

| Need | Read / update |
| --- | --- |
| Accepted product and architecture decisions | [DESIGN.md](DESIGN.md) |
| Complete runnable Godot game delivery specification | [Game specification](docs/specs/runnable-godot-game.md) |
| Ready questions, blocked branches, next development step | [Development](docs/development.md) |
| Domain terms | [GLOSSARY.md](GLOSSARY.md) |
| Why a consequential choice was made | [Decision records](docs/adr/0001-edition-5-authority.md) |
| Verified original behavior and its source | [Evidence](docs/evidence/README.md) |
| Export constraints and platform verification | [Douyin](docs/douyin.md) |
| Agent reading and update workflow | [AGENTS.md](AGENTS.md) |

Configuration and scenes describe what is implemented. The documents distinguish accepted intent from recovered facts; neither implies implementation is complete.

## Checks

Run `./tools/run_checks.ps1 -Godot 'path/to/Godot_4.5_console.exe'` in PowerShell (or `tools/run_checks.sh` on Linux) for the 20 suites: command/queue, scheduler, bomb, round, regression and fidelity checks, scenes and screen flow, modes, difficulty, layouts, stage-set features, looks, controls, the art catalogue and full-board playthroughs (667 checks). See [development](docs/development.md) and the [complete-game verification](docs/verification/complete-game-2026-10-21/README.md). Optional desktop rendering captures use `--script res://tools/capture_game.gd`; source-data reproduction uses `python tools/inspect_source_data.py` when the recorded SWF is available.
