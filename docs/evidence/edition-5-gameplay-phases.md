# Edition 5 gameplay phases and first-blast boundary

Inspected 2026-10-18 for the first bomb/soft-block design interview. These are static findings from the publisher SWF identified in [the provenance record](edition-5-input-and-timing.md), SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`. They do not settle the new game's batching policy. No additional runtime replay was performed.

Source paths below are relative to `.scratch/edition-5-research/publisher-scripts/scripts/`. Line numbers refer to that decompile; class and method names are the durable locators.

## Input and frame order

Human bomb down/up dispatches immediately from `PersonInteractiveController.bombDownHandle` / `bombUpHandle` through `InteractiveController.bomb_down` / `bomb_up` into the current controller handlers. Ordinary down calls `RobotController.addBomb`, checks capacity and the actor's current map cell, and constructs a bomb there. Movement input instead selects an ongoing movement callback; it does not execute movement immediately.

Locators: `zlong/bombit5/gameengine/robot/PersonInteractiveController.as:142–155`, `InteractiveController.as:21–46,88–95`, `AbstractRobot.as:125–126,270–275,454–457`, `RobotController.as:141–165`.

`GameEngine.enterFrameHandle` runs these phases in order: one sequence callback, bombs, blasts, one AI-sequence callback, engine callbacks, movement, periodic tweens, brick-explosion animation callbacks, then dead callbacks (`zlong/bombit5/gameengine/GameEngine.as:230–268`).

Consequently, human movement and bomb input delivered before a frame place an ordinary bomb at the pre-movement cell. AI actions can originate after the bomb phase. The source does not define simultaneous all-actor batches or their total event order.

Repeated downs reach the handler separately, but a successful ordinary placement immediately occupies the cell, preventing another ordinary bomb there. An up calls an optional release handler; it is not a second ordinary placement. Weapons can replace these handlers. Locators: `RobotController.as:141–165`, `zlong/bombit5/bombs/Bomb.as:113–115`, `zlong/bombit5/maps/Map.as:325–330`.

## Countdown origin

`Bomb` registers its bomb-engine callbacks during construction. Its counter begins at zero; `takeCount` tests `_time > _blastTime` before incrementing, with normal threshold 70. The uninterrupted bomb therefore detonates on countdown callback **72**. Locators: `zlong/bombit5/bombs/Bomb.as:20,67–85,145–191`.

A human bomb constructed before a frame is eligible for that frame's bomb phase. A bomb constructed in a later phase misses that phase. This conditional source order does not establish a universal placement-tick offset for the new batch model. Mutation of callback arrays during iteration has not been independently reproduced.

The delivered observations use different timing origins: [the corrections](observations/swf-v1.6.1-supplement/CORRECTIONS.md) report first-visible frame P to blast P+72, while [repeated probes](observations/swf-v1.6.1-followup/task4_repeats/README.md) report 72/73 input-counter intervals. Callback count, logged input time and first-visible time must remain distinct. The proposed callback-skip explanation is still an inference.

## Blast and soft-block facts

- Bomb power is copied from the owner at creation; default power is one. `Bomb.blast` visits the center and four orthogonal rays up to that power (`Bomb.as:123–131,244–418`).
- A ray hits and stops at the first blocking cell, even if that hit removes its blocker. A soft-block cell receives flame and breaks; a solid receives a hit effect without flame. Crocodile platforms are an explicit exception. Ordinary pickups alone do not block rays: `Grid.isEmpty` and `getItem` exclude pickup `prop` (`zlong/bombit5/maps/Grid.as:154–181`).
- Soft-block collision occupancy clears synchronously during detonation. Break animation and conditional drops occur later (`zlong/bombit5/bombs/AbstractBomb.as:129–151`, `zlong/bombit5/maps/Map.as:206–212`, `Box.as:134–159`).
- Bomb hits synchronously dispatch another bomb's blast and invoke its countdown immediately; supplied probes corroborate same-frame chains (`AbstractBomb.as:155–165`, `Bomb.as:162–165`; [SWF report](observations/swf-v1.6.1/REPORT.md), probe 8).

These mutations mean a later blast can see a soft block already removed by an earlier blast. A shared pre-blast board snapshot would be a deliberate adaptation. Multi-blast shared-block order and overlapping flame cleanup are not established by the supplied probes; investigate them before claiming parity for those interactions.

The [delivery assessment](edition-5-play-observations.md) owns overall confidence limits. Drops have source-supported conditions and must not be described as universally absent. Their implementation can remain a separate slice without changing the original-game finding. Likewise, the [first-board transcription](observations/swf-v1.6.1/play/first-board.md) still marks uncertain occupancy; source-verified test cells do not certify the full starting board.
