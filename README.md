# Bomb It 5

Landscape phone game. The match rules come from the original Q版泡泡堂5 (edition 5) SWF. The pictures, names, and audio in a Douyin build are original. This is not the [bomb-it-1](https://github.com/Kurak0oo/bomb-it-1) repo, and that repo stays parked.

Open `project.godot` in **Godot 4.5** with the Compatibility renderer.

## Where knowledge lives

| Need | Read / update |
| --- | --- |
| Accepted product and architecture decisions | [DESIGN.md](DESIGN.md) |
| Ready questions, blocked branches, next development step | [Development](docs/development.md) |
| Domain terms | [GLOSSARY.md](GLOSSARY.md) |
| Why a consequential choice was made | [Decision records](docs/adr/0001-edition-5-authority.md) |
| Verified original behavior and its source | [Evidence](docs/evidence/README.md) |
| Export constraints and platform verification | [Douyin](docs/douyin.md) |
| Agent reading and update workflow | [AGENTS.md](AGENTS.md) |

Configuration and scenes describe what is implemented. The documents distinguish accepted intent from recovered facts; neither implies implementation is complete.

## Checks

Run `./tools/run_checks.ps1 -Godot 'path/to/Godot_4.5_console.exe'` in PowerShell for the headless command, scheduler/pause and bomb-simulation checks. The simulation places bombs, advances their fuses, chains ordinary bombs and breaks soft blocks on a source-verified test excerpt. The main scene remains empty. See [development](docs/development.md) for the interfaces and remaining evidence prerequisites.
