# Bomb It 5

Landscape phone game. The match rules come from the original Q版泡泡堂5 (edition 5) SWF. The pictures, names, and audio in a Douyin build are original. This is not the [bomb-it-1](https://github.com/Kurak0oo/bomb-it-1) repo, and that repo stays parked.

Open `project.godot` in **Godot 4.5** with the Compatibility renderer.

The desktop game is playable: open the project and press **F6/F5**, or run `./tools/play.ps1` with the local Godot 4.5 executable. It opens in practice; choose **START MATCH** for one human against three AI. Use **Arrow keys** to move, **Space** for bombs/equipped items, and **P** or the pause button to pause/resume. The visible stick and bomb button also accept desktop-emulated touch. Practice Reset restores the recorded Cinema board; match results offer retries/play-again and a new session after game over.

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

Run `./tools/run_checks.ps1 -Godot 'path/to/Godot_4.5_console.exe'` in PowerShell for command/queue, scheduler, bomb, playable-round, regression, scene and full-board playthrough checks. The game uses the recorded 17×15 Cinema instance, continuous movement, portals, hazards/damage, conditional pickups, source-reachable weapons/rides, AI, a 180-second clock and lives/results/replay flow. The final desktop suite passes 244 checks. See [development](docs/development.md) for interfaces, verification and rendered match/result captures. Optional desktop rendering captures use `--script res://tools/capture_game.gd`; source-data reproduction uses `python tools/inspect_source_data.py` when the recorded SWF is available.
