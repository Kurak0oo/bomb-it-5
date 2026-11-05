# Bomb It 5

Language for the edition 5 game and the new game's design.

## Language

**Edition 5**:
The retail original game whose SWF is the rules authority for this project.
_Avoid_: Bomb It 1, the cheat build, a portal description

**Original replica**:
The Godot build that reproduces edition 5 exactly, showing the original 700×510 stage through one scale factor. Phone fit comes later on top of it.
_Avoid_: reference, clone

**Reference player**:
The instrumented player that runs the actual edition 5 SWF for research and comparison.
_Avoid_: replica, emulator build

**Fidelity profile**:
The choice between following edition 5 exactly (original) and the accepted new-game adaptations (adapted).

**Stage unit**:
One unit of the original 700×510 stage coordinate space, in which all art and layout are placed.

**Checkpoint**:
One screen or one mode of work, finished only when its checks pass and, for UI and art, the owner accepts it.

**Placeholder**:
UI or art that the owner has not confirmed as matching the original, kept swappable behind an art slot or generated scene.
_Avoid_: final, approved

**Comparison case**:
A scripted run with fixed seed, input and frame count, played in both the reference player and Godot and diffed.

**Golden dump**:
The committed node data recorded from the reference player for a comparison case.

**Capture phase**:
How many frames a screen had been open when a capture was taken, read from that capture's golden dump rather than from a run. Needed where the original opens a screen on the wall clock, so each recording opens it at a different frame.

**End screen**:
The screen that closes a one-player session with its final score and TRY AGAIN: Game Over after the last heart, congratulations (GAME COMPLETE!) after the last level.
_Avoid_: results screen, score screen

**Owner edit**:
A change the owner made on top of a faithful screen (a part removed or moved), applied by the converter and treated by the comparison as an expected difference.

**Run-time effect**:
Display objects a ported screen makes at random while it runs (the congratulations screen's falling confetti), checked against the original by the effect's rules rather than node by node.

**Board tile**:
The art of one box kind on the gameplay screen: a `_brick5` frame, shrunk and centred or not as a breakable box is, rendered once and placed on any cell of the round's board.

**Actor art**:
The images of a library clip the round makes at run time (a robot in a direction and look, a bomb, a blast), rendered alone by the reference player at every frame the round can show, and placed by the clip's registration point.

**Recorded round**:
The board and robots a gameplay capture recorded, which the comparison loop starts its Godot round on because the original's random draws before the map are not reproduced yet.

**Original pack**:
The art and audio taken from the user's own SWF, kept on their machine and never committed.
_Avoid_: assets, candidate art

**Actor**:
A participant in the round, controlled by a human or AI.

**Actor roster**:
The set of actors participating in a round, independent of who controls them.

**Cell**:
One location in the board's rectangular grid, containing floor, a blocker or a map feature.

**Diagonal movement**:
Movement along both board axes at once, toward one of the four diagonal directions.

**Wall sliding**:
Movement along an unobstructed axis while the requested direction also points toward a blocker.

**Corridor assistance**:
A small alignment adjustment toward an open lane during requested movement.

**Portal**:
A paired map feature that transfers an actor to its linked location.

**Practice preview**:
A local play space for trying controls and bomb interactions before a complete match is available.

**Deadzone**:
The central area of the virtual stick that represents no movement request.

**Command**:
One actor's direction and ordered bomb input events for a tick.

**Bomb input event**:
A delivered down or up input for an actor's bomb/action control. Repeated down events are distinct events even when the control remains held.

**Round**:
A unit of play governed by an ending condition and the rules of its mode.

**Mode**:
A selectable rule set that gives rounds their ending, lives, respawn and pickups, such as Arcade or Kill.
_Avoid_: game type

**Stage set**:
A themed group of recorded board layouts sharing one skin, such as Cinema.

**Level**:
One position in a session's sequence of rounds, played on a layout from a stage set.

**Difficulty**:
The Easy, Normal or Hard setting that selects AI profiles and the source tuning for a session.

**AI profile**:
The behavior and tuning that an AI-controlled actor uses.
_Avoid_: enemy type

**Unlock**:
A cosmetic cloth or hat that play earns, kept on the device.

**Session**:
A sequence of rounds sharing retry hearts and a cumulative result score.

**Retry heart**:
An opportunity to attempt another round after defeat, distinct from an actor's ability to survive a hit.

**Pickup**:
A collectible board item that grants an actor an upgrade, protection, a vehicle or a weapon.

**Vehicle**:
A ride carried by an actor, with its own movement and damage state.

**Weapon**:
An equipped item that gives the actor an action in place of ordinary bomb placement.

**Fuse**:
A bomb's delay before timed detonation. A chain reaction can detonate it earlier.

**Blast**:
The explosion produced by a bomb, covering its cell and rays in the four cardinal directions.

**Soft block**:
A breakable obstacle on the board.

**Magic carpet**:
One of the four item names from the portal description. Edition 5 has no such item, and likewise no bouncer or heavy bomb.
_Avoid_: Carpet (as a separate item)

**Push the bomb**:
The edition 5 pickup (`BombShoesProp`) that lets a robot kick a bomb by walking into it.
_Avoid_: Bomb shoes, glove

**Boxing glove**:
The edition 5 weapon pickup (`BoxingProp`) that punches up to two cells ahead.
_Avoid_: Fist, glove

**Map-loading screen**:
The screen START shows while the board is built row by row (`LoadingMapUI`), gone when the round starts.

**Round draws**:
The original's `Math.random` calls made before a round starts; a recorded round's own draws continue after them.
