# Painted desktop presentation

Implementation of [#20](https://github.com/Kurak0oo/bomb-it-5/issues/20), starting
from `ca86801`. Implementation, verification and both review axes are complete. Final human desktop
acceptance remains [#21](https://github.com/Kurak0oo/bomb-it-5/issues/21).

## Delivered presentation

Two original generated painted atlases replace the temporary integration symbols:
four-direction robot idle/walk/action poses, cinema obstacles, bombs, mines,
reachable pickup/weapon icons, rides, portal, ghost and trophy. The production
renderer preserves the recovered left roster/central board relationships, the
fixed 255-cell layout and the accepted separated side controls. Polished native
chassis, panels, carpet weave, beam connections and typography surround the art.

The [asset record](../../../assets/art/README.md) documents generation, alpha,
actual atlas sizes and ownership. No SWF raster, sprite, audio or branding is
packaged. `LOCAL ARCADE` and `CINEMA` are descriptive development labels, not an
unchosen store identity. Release language, store identity and export remain open.

## Animation contract

| Feedback | Authoritative input |
| --- | --- |
| Facing and team portrait | Copied actor facing and fixed roster identity |
| Alternating walk frames / blocked input | Changes in committed position; consumed directional commands |
| Held weapon and action-button icon | Equipped weapon and ammo; button contact affects only presentation |
| Windup, hammer layer/swing, laser pass, flamer tip, projectile emissions | Public action frame, attachment, layer, cells and projectile phase |
| Shield, Invincibility introduction/active, independent blink | Public protection fields; visible blink does not grant immunity |
| Ride and damage shake, then recovery completion | Vehicle and recovery deadline; weapon retained |
| Portal swirl, transit fade and arrival blink | Admitted tick and separate portal/transit/protection fields |
| Live flame versus cleared visual tail | Logical fire presence plus retained effect callback count |
| Ghost/death, ending progress, settled trophy/results | Death frame, round stage/progress, outcome and one-time session settlement |

No simulation, controller, command, scheduler or damage code changes. All game
animation samples simulation time or committed positions. Repeating a paused
render is pixel-identical and leaves the public round snapshot unchanged. Thumb
easing and press feedback are UI responses and do not advance gameplay. No input
areas, joystick direction policy, deadzone or event delivery rules change.

## Desktop verification

All 408 functional checks pass; all 15 production scripts parse/typecheck. The
real full-board outcomes are unchanged from the fidelity baseline: seed 2 wins at
tick 1848/score 3310; seed 5 wins at tick 2195/score 3210; seed 42 loses at tick
237/score 0. Both victories have zero human kill credit. These use legal scripted
human commands and three production AI, not a substitute for human play assessment.

Actual Compatibility-rendered images cover the production match, pause, death,
ending, defeat/results, game over and victory; selected action phases; a labelled
open fixture for all reachable items/rides/protection; and four desktop layouts.
The comparison fixture is not a replacement production map or a naturally
achieved original-game state.

Thirty captures are retained with hashes. Representative production, weapon,
item/ride/protection and layout images were visually inspected, including
[match](desktop/match.png), [victory](desktop/victory.png),
[item/ride/shield fixture](states/items-rides-shield.png),
[pressed controls](layouts/controls-pressed.png) and
[ultrawide layout](layouts/1800x720.png).

`capture_presentation.gd` passes two checks for frozen pixels and state immutability.
`capture_layout.gd` checks desktop edge clearance, non-overlap with the board,
button containment and enabled-input state at 1280×720, 1600×900, 1280×800 and
1800×720, plus actual press/drag/release through the production intake: 18 checks
pass. Those synthetic contacts request a diagonal plus one down event, then idle
plus one up event; corresponding pressed/released feedback is captured. Its
24-unit desktop reservation is a development check, not measured
phone notch/platform-chrome geometry. No physical phone/iOS test or export occurs.

## Standards

No outstanding findings. The independent reviewer inspected the diff against
`ca86801` and governing repository instructions. Presentation consumes copied
state, preserves scheduler/damage ownership and keeps phone/input-policy
boundaries unchanged. No material actionable smell was found.

## Spec

No outstanding material findings. The independent reviewer checked issue #20,
the implementation and representative actual production, action, state and
desktop-layout captures. No missing implementation requirement, scope creep or
incorrect rendering/input change was found. Human art/play-quality acceptance
remains #21. No claim of source pixels, native Flash equivalence or device-safe
areas is made.

Review totals: Standards 0 outstanding; Spec 0 outstanding.

## Reproduction

Use the pinned Godot 4.5 console executable with `--path . --script` followed by
`tools/capture_game.gd`, `tools/capture_fidelity.gd`,
`tools/capture_presentation.gd` or `tools/capture_layout.gd` (graphical mode).
Run `tools/run_checks.ps1` for functional regression checks. Then run
`python tools/collect_presentation_verification.py`; `verification.json` pins
the art, script and capture hashes. Earlier fidelity screenshots remain intact
in their historical verification directory.
