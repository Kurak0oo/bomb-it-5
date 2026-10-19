# Edition 5 movement and visible-board facts

Inspected 2026-10-19 for the visible-practice interview. This record uses the publisher SWF identified in [the provenance record](edition-5-input-and-timing.md), SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`. Source paths below are relative to `.scratch/edition-5-research/publisher-scripts/scripts/`; shortened `gameengine/`, `maps/` and `commands/` paths are beneath `zlong/bombit5/`. These are static findings, not an independently replayed movement test or a phone-control specification.

## Continuous movement on a grid

Ordinary movement changes Number-valued positions within the board. It is cardinal but **not one-cell stepping**. `zlong/bombit5/AbstractObject.as:51–90` gives the inherited 30×30 collision footprint, board-relative positions, and logical cell lookup `floor((position + 15) / 30)`. `GameConfig.as:45` defines the 30-unit cell. `gameengine/PersonPlayer.as:24–32` initializes position at cell coordinate times 30 and loads the movement parameter from XML.

The embedded XML (DefineBinaryData ID 6787, linked by `zlong/bombit5/utils/XmlManager_xmlClass.as:5`) specifies `moveSpeed=1.6` for human Arcade settings at each difficulty. `Root.as:18` disables external XML loading. `zlong/bombit5/maps/Grid.as:79–88` initializes ordinary floor resistance to 0.6; the robot reads that resistance at spawn (`gameengine/robot/AbstractRobot.as:98–99`).

`gameengine/robot/RobotModel.as:114–143` applies acceleration and resistance. Straight rightward movement follows `next_speed = 0.6 * speed + 1.6`: from rest, 1.6, 2.56, 3.136, approaching four source units per update. The derived nominal limit at 35 updates/sec is 140 source units/sec, about 4.667 cells/sec. These are static arithmetic consequences, not measured device cadence or pixel rounding.

`gameengine/robot/RobotController.as:79–119` sends the resulting displacement to collision handling. Idle decays stored speed without updating position, so release stops displacement immediately. Same-axis reversal initially retains signed velocity; changing axes clears perpendicular speed. The recovered path does not reset stored speed merely because a wall blocks movement.

Keyboard input selects the most recently pressed held cardinal direction, falling back to an older held direction on release (`PersonInteractiveController.as:49–108`, `InteractiveController.as:21–85`). The original selects one direction even if multiple keys are held. That is a controller rule, not a restriction imposed by having four physical buttons.

## Collision, turning and bombs

`gameengine/HitMove.as` handles left/right/up/down at lines 102–180, 227–305, 352–430 and 477–555. It samples the leading footprint and neighboring lane cells. When the intended lane is passable but part of the footprint overlaps a blocked side cell, it can spend that update's movement aligning perpendicular to the requested direction. This is collision-dependent lane assistance, not universal snapping to a cell center.

Blocked requested movement clamps or stops. There is no ordinary pending-turn buffer that automatically keeps travelling straight; holding a direction requests it again on each update. `RobotController.funcDelay` concerns special movement interruptions, not ordinary early-turn buffering.

Ordinary bomb placement uses the actor's center-rounded current cell (`RobotController.as:154–165`), before movement under the accepted new-game phase order. Bombs block traversal (`HitMove.as:634–637`), with an explicit landmine exception. The current-cell/leading-cell bypass in the directional collision paths permits departure from an overlapping newly placed bomb. This is geometric, not an owner-specific immunity flag. Fine-grained reversal while overlapping has not been independently replayed.

Ordinary actors do not block one another in the recovered path. Fixed collision checks boxes, bombs and platforms; grid item/emptiness queries exclude actors (`maps/Grid.as:154–183`). The separate dynamic collision list is registered by Tractor, not ordinary actors (`maps/platform/Tractor.as:54`; `gameengine/Game.as:820–822`). This is a static call-path finding.

There is no original ordinary diagonal movement path to copy. Eight-direction collision, acceleration, analog-sector selection and fairness between controllers require explicit adaptation or runnable evaluation; static cardinal evidence does not settle them.

## Full CinemaStage1 certainty and special cells

The source board has 17×15 cells and corner spawns at (1,1), (15,1), (1,13), (15,13) (`GameConfig.as:29–45`). `gameengine/Game.as:263–267` scales the gameplay container by 32/30, so the rendered pitch is 32 pixels, with container offset (-32,-30). Tall sprite edges are not reliable collision anchors.

`maps/mapData/CinemaMapData.as:43–47` loads the exported CinemaStage1 template (symbols 4792/4791). Candidate soft cells use probability 0.8 (`AbstractMapData.as:40`, `CinemaMapData.as:101–106`, `MapMaster.as:133–190`). Template soft candidates are not proof that a particular captured start contains those blocks.

Initial visual inspection of restored frames 697 and 698 left some sprite-overlapped cells unresolved, as the [imported transcription](observations/swf-v1.6.1/play/first-board.md) records. A subsequent [focused two-frame pixel audit](cinema-stage1-recorded-board.md) now resolves all 110 candidate cells: 68 present soft blocks and 42 empty candidates. It confirms the formerly uncertain rows and corrects (14,10) from floor to soft. This is a rendered-instance reconstruction with a canonical CSV, not an independent runtime collision-state dump. Choosing another template realization remains distinct from recreating this captured instance.

The center occupies the entire solid 3×3 region x=7–9, y=6–8, including eight invisible hold cells (`CinemaMapData.as:109–115`, `MapMaster.as:142–149,247–256`). The portal pairs are (8,1)↔(8,13) and (4,7)↔(12,7). Pairing and transfer behavior are source-supported: `CinemaMapData.as:122–142`, `maps/platform/Portal.as:62–75`, `commands/robot/SendRobotCommand.as:23–64`, `CheckRobotInPortalCommand.as:25–31`. The ordinary transfer defaults to 30 callbacks and queues 45-callback protection; controls are interrupted and re-entry is latched until the actor leaves the portal.

A full traversable Cinema board therefore needs portal behavior or an explicitly accepted temporary deviation. Neither flattening portals to floor nor filling every candidate soft cell has been accepted by this factual investigation.
