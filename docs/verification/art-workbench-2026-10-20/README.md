# Art rollback and workbench verification

The user rejected the 2026-10-20 generated art. Commits `8a146bf` and `2d5d9c5`
were reverted by `0f41b43` and `8211c82`, without rewriting history. The gameplay
fidelity baseline remains `ca86801`; #20 is reopened and #21 stays open. The new
authoring tool implements the [accepted workbench workflow](../../../DESIGN.md),
not approval of another art style.

Implementation and independent review are complete. The normal game's checked-in
active mapping is empty. With defaults, match, pause, death, ending and settled-loss captures
match the retained pre-artwork pixels exactly (RGB comparison). The game-over
retry capture uses unseeded retry rounds, so that context is not claimed identical.

All 408 functional checks pass on Godot 4.5, and all 17 scripts under `scripts/`
parse/typecheck. The real full-board outcomes remain seed 2 win at tick1848,
seed 5 win at tick2195 and seed42 loss at tick237. No simulation, scheduler,
controller, movement or damage implementation changes are included.

`tools/check_art_workbench.gd` passes 27 desktop UI/rendering checks. Actual mouse events
exercise category/card selection, Replace, Preview in game, Apply, Use default
and Undo. Image choice completes through the file dialog's public `file_selected`
signal; this does not certify the OS/engine picker's internal mouse routing.
Checks cover draft isolation, frame/scale settings, the actual 255-cell game with
draft art and legal bomb input, reloading an applied mapping, reset/undo and
rejection of direct research-art import. Test profiles are restored; the temporary
two-colour fixture and four-colour phase fixture are removed from production imports. Its screenshots demonstrate
wiring only and are not an art proposal.

Rendered checks use distinct frame colours to compare the inspector with copied
public game snapshots. They cover bomb, hammer, aura and held-item placement,
character action phase independent of round tick, laser charge/beam/final frame
and flamer charge/active phases. These compare new replacement rendering, not
original-SWF pixels. Gameplay remains governed by the existing round.

## Standards

The independent review found one P3 normalization duplication. Editing and loading
now share the same guarded normalization helper. There are zero outstanding findings.

## Spec

The independent review found two P2 issues: character action sheets used global
time, and inspector geometry/animation could differ from live drawing. Shared
placement and live actor/weapon drawing paths now project the same action phase;
laser animation ends at frame 11 while its recovery lock continues. Failing
rendered checks reproduced the problems before the fixes and now pass. The
follow-up review confirms zero outstanding material findings.

Review totals: Standards 0 outstanding; Spec 0 outstanding. Artwork selection and
human presentation acceptance remain open in #20 and #21.

Run `tools/run_checks.ps1` for gameplay regression checks, then invoke the pinned
Godot 4.5 console executable with `--path . --resolution 1600x900 --script
tools/check_art_workbench.gd` in graphical mode. The tool captures overview,
selected component, draft replacement and the real-game preview under ignored
`.scratch/art-workbench-check/`. Launch the user tool through `Art Workbench.cmd`.

The original reference viewer reads preserved context screenshots only. Some
slots share a context and some have no exact preserved image. Those images are
not part of the active replacement manifest. No copied source sprites/audio,
phone/iOS testing, export, networking or new gameplay item is introduced.

Picker and preview APIs were checked against the official Godot 4.5
[FileDialog](https://docs.godotengine.org/en/4.5/classes/class_filedialog.html) and
[ItemList](https://docs.godotengine.org/en/4.5/classes/class_itemlist.html) documentation.
