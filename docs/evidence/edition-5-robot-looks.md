# Robot looks and slots with no original art (#74)

Authority build `agame-bomb-it-5-zh-fix.swf` (sha256 `718c04c7…0408a2`). Static source from the
FFDec 26.3.0 script export. Timelines read from the SWF's `PlaceObject` tags
(`tools/inspect_swf_structure.timeline`).

## Hats and outfits

`RobotView` builds a robot from its direction clip `_r<n>_<Dir>`:

- It descends nested `bodyMc` children and stops the innermost one at frame `clothID + 1`.
- It then descends `hatMc` and stops the innermost one at frame `hatID + 1`. It starts from
  `bodyMc` when that holds the hat.

So a look is not a separate symbol. It is a frame of the innermost `bodyMc`/`hatMc` clip in
each direction. The innermost clips found in the timelines (character id, frame count):

| Robot | Body Down/Right/Up/Left | Hat Down/Right/Up/Left |
| --- | --- | --- |
| 0 | 6186 (7), 2809 (6), 3166 (6), 2809 | none, 2814 (4), 3172 (4), 2814 |
| 1 | 515, 419, 566, 419 (6) | 524, 427, 572, 427 (4) |
| 2 | 2781, 592, 1666, 592 (6) | 2790 (4), 604 (4), 1668 (1), 604 |
| 3 | 616, 1549, 3260, 1549 (5) | 642, 1558, 3266, 1558 (5) |
| 4 | 1612, 2104, 872, 2104 (7) | 877 (3) in every direction |
| 5 | 1093, 954, 2331, 954 (6) | 1102, 978, 2335, 978 (4) |
| 6 | 3229, 1744, 2766, 1744 (6) | 2772, 1768, 2772, 1768 (4) |
| 7 | 2037, 472, 2156, 472 (5) | 2046, 492, 2162, 492 (5) |

The frame counts are the robot's hat or outfit count plus one, matching `scripts/looks.gd`.
Each `look.<robot>.<hat|body><k>` slot takes frame `k + 1` of the four direction clips.

Two quirks of the original:

- `_r0_Down` has no `hatMc`, so the original sets the walk clip's own frame and shows no hat
  facing down. The replica's Down row repeats the side clip. This is a recorded difference.
- Robot 2's Up hat clip has one frame (no hat from behind), so every hat shows it.

## No original art

These slots have no SWF art. Each is marked `no_original` in the pipeline config:

- **`actor.<robot>.action`.** The robot clip keeps its walk frames while acting. Weapons draw
  as separate clips on the hand (`AbstractWeapon.updateWeaponDisplay`), already mapped as
  `held.*` and `attack.*`.
- **`effect.blink`.** `InvincibilityCommand` toggles a +50 colour offset on the robot every 4
  frames for 80 frames. Under the replica, `GameView` draws exactly that (as a 1.35
  brightness) with no overlay.
- **`effect.transit`.** `SendRobotCommand` fades the robot, alpha `1 − frame/35`. The replica
  draws that fade with no overlay.
- **`control.*`.** The original is keyboard-only. The touch stick and button are new to the
  phone replica (Q1).
- **`ui.frame`, `ui.roster`, `ui.timer`, `ui.button_*`.** These are desktop-adaptation panels.
  The replica page uses the original HUD (#91) and screen art (#76) instead.

With #74's earlier stage-tile work ([stage tiles](edition-5-stage-tiles.md)), every one of the
299 slots now has an SWF source or is recorded here as having none.
