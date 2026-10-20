# Painted desktop presentation

Implementation of [#20](https://github.com/Kurak0oo/bomb-it-5/issues/20), starting
from `ca86801`. Review and final verification are in progress. Final human desktop
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

Actual Compatibility-rendered images cover the production match, pause, death,
ending, defeat/results, game over and victory; selected action phases; a labelled
open fixture for all reachable items/rides/protection; and four desktop layouts.
The comparison fixture is not a replacement production map or a naturally
achieved original-game state.

`capture_presentation.gd` verifies frozen pixels and state immutability.
`capture_layout.gd` checks desktop edge clearance, non-overlap with the board,
button containment and enabled-input state at 1280×720, 1600×900, 1280×800 and
1800×720. Its 24-unit desktop reservation is a development check, not measured
phone notch/platform-chrome geometry. No physical phone/iOS test or export occurs.

## Reproduction

Use the pinned Godot 4.5 console executable with `--path . --script` followed by
`tools/capture_game.gd`, `tools/capture_fidelity.gd`,
`tools/capture_presentation.gd` or `tools/capture_layout.gd` (graphical mode).
Run `tools/run_checks.ps1` for functional regression checks. Then run
`python tools/collect_presentation_verification.py`; `verification.json` pins
the art, script and capture hashes. Earlier fidelity screenshots remain intact
in their historical verification directory.
