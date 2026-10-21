# Bomb It 5

Language for the edition 5 game and the new game's design.

## Language

**Edition 5**:
The retail original game whose SWF is the rules authority for this project.
_Avoid_: Bomb It 1, the cheat build, a portal description

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

**Candidate art**:
An unapproved image proposed for a visual slot, awaiting the user's manual review before any Apply to game.
_Avoid_: approved art, final art

**Magic carpet**:
One of the four named items whose behavior has yet to be recovered.
_Avoid_: Carpet (as a separate item)
