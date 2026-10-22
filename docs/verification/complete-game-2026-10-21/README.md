# Complete edition 5 game: implementation verification (2026-10-21/22)

Implementation of [specification #56](https://github.com/Kurak0oo/bomb-it-5/issues/56)
tickets #57–#70 on branch `claude/adoring-gates-9eckgx`, carried out on the user's
"implement all" instruction. This record covers automated checks, reference-player
observations and desktop captures. It is not the final human desktop acceptance (#21)
and does not accept artwork (#20).

## Tickets

| Ticket | Commit | Evidence |
| --- | --- | --- |
| #57 mode, board and AI-profile seams | `335a49f` | [modes and flow](../../evidence/edition-5-modes-and-flow.md) |
| #58 recorded layouts and board rolls | `912bfaa` | [stage openings](../../evidence/edition-5-stage-openings.md) |
| #59 menu, settings, character select, session | `67d0baa` | [modes and flow](../../evidence/edition-5-modes-and-flow.md) |
| #60 Easy and Hard | `d4480a4` | [difficulty](../../evidence/edition-5-difficulty.md) |
| #61 How to Play and key rebinding | `1dd3772` | [modes and flow](../../evidence/edition-5-modes-and-flow.md) |
| #62 unlocks and local saving | `4d3f23b` | [modes and flow](../../evidence/edition-5-modes-and-flow.md) |
| #63 Zoo | `bd70698` | [Zoo](../../evidence/edition-5-zoo.md) |
| #64 Birthday Party | `bd70698` | [Birthday Party](../../evidence/edition-5-birthday-party.md) |
| #65 Candy Factory | `bd70698` | [Candy Factory](../../evidence/edition-5-candy-factory.md) |
| #66 Magic Library | `bd70698` | [Magic Library](../../evidence/edition-5-magic-library.md) |
| #67 Kill (Battle Royale) | `f5154cf` | [Kill](../../evidence/edition-5-kill-mode.md) |
| #68 Green Zone | `7e2a10f` | [Green Zone](../../evidence/edition-5-green-zone.md) |
| #69 Pac-Man | `15e5048` | [Pac-Man](../../evidence/edition-5-pac-man.md) |
| #70 Art Workbench catalogue | `3234b95` | [art workbench](../../art-workbench.md) |

The reference player gained the `reference-platforms` focus patch (`9343976`) so
map-feature objects appear in captures; see the
[reference player README](../../../tools/reference_player/README.md).

## Checks

Godot 4.5 stable on Linux (Xvfb for graphical suites), 2026-10-22:

- `tools/run_checks.sh`: 20 suites, 667 checks, all passing. The 408 pre-existing
  checks still pass unchanged in count; new suites cover mode seams (16), layouts
  (21), session (19), flow scenes (36), difficulty (15), controls (20), looks (18),
  Kill (22), Green Zone (18), Pac-Man (27), stage features (42) and the art catalogue
  (5; 262 slots).
- `tools/check_art_workbench.gd`: 38 UI and rendering checks passing (27 before
  #70), including the new categories, rendering parity for new slot families and a
  Pac-Man preview on Zoo.
- All 63 project scripts parse and type-check.
- The art pipeline resolves all 132 SWF slot sources; a trial render of six new
  slots succeeded. Candidates stay in the ignored `candidates/` folder.

## Desktop captures

Rendered with Xvfb at 1280×720 from the real scenes:
[menu](menu.png), [settings](settings.png), [character select](character-select.png),
[looks](looks-select.png), [unlock tip](unlock-tip.png),
[How to Play](how-to-play-controls.png), [power-ups](how-to-play-power-ups.png),
[score](score.png), [game over](game-over.png); modes
[Battle Royale](mode-kill.png), [Green Zone](mode-green_zone.png),
[Pac-Man](mode-pac_man.png); stage sets [Zoo](set-zoo.png),
[Candy Factory](set-candy_factory.png), [Birthday Party](set-birthday_party.png),
[Luxury Shop](set-luxury_stores.png), [Magic Library](set-magic_library.png).
Presentation is the native vector placeholder art; the checked-in active skin is
empty.

## Corrections found during the work

- Arcade soft blocks roll at 0.6, not 0.8 (#57).
- Zoo has 12 crocodile cells, not 14; Candy Factory has no sliding platforms (the
  `slidePlat_*` cells belong to unused Basketball layouts); Arcade gives Magic Library
  no timed pickups (#63, #65, #66).

## Limits

- Kill, Green Zone, Pac-Man, difficulty and the stage-set features were observed with
  an idle or scripted player. Robot pushes, belt rides, crocodile bites, horse and
  dragon rides and the Pac-Man player catching ghosts were not observed at runtime
  and are ported from source. AI decisions in the new modes were not traced call by
  call.
- The belt uses float positions; cell crossings can drift by a tick against the
  original's twip positions.
- Audio is deferred. Local 2-player, physical phone/iOS testing and export are out
  of scope.
- Final art (#20) and human desktop acceptance (#21) remain open.
