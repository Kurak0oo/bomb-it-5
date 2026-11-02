# Bomb It 5

A faithful Godot 4.5 replica of Q版泡泡堂5 (edition 5), later fitted to landscape phones.
A Douyin build with original art is a separate build profile on the same code. This is
not the [bomb-it-1](https://github.com/Kurak0oo/bomb-it-1) repo, and that repo stays
parked.

**Status:** restarting on 2026-11-02. See [docs/development.md](docs/development.md)
for the plan and current checkpoint. The previous state is tagged `pre-restart`.

Open `project.godot` in **Godot 4.5** with the Compatibility renderer. The current menus
and gameplay screen are placeholders that later checkpoints replace. To see original
art, build the local pack from your own SWF with
`python tools/art_pipeline/original_pack.py`; it stays out of git.

## Docs

| Need | Read |
| --- | --- |
| Plan, rules of work, current checkpoint | [docs/development.md](docs/development.md) |
| Domain terms | [GLOSSARY.md](GLOSSARY.md) |
| Recovered original behavior and its source | [docs/evidence/README.md](docs/evidence/README.md) |
| Reference player (Ruffle) | [tools/reference_player/README.md](tools/reference_player/README.md) |
| Export constraints | [docs/douyin.md](docs/douyin.md) |
| Agent workflow | [AGENTS.md](AGENTS.md) |

## Checks

`GODOT=/path/to/godot tools/run_checks.sh` (macOS/Linux) or
`./tools/run_checks.ps1 -Godot 'path/to/Godot_4.5_console.exe'` (Windows).
