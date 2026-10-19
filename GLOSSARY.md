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

**Command**:
One actor's direction and ordered bomb input events for a tick.

**Bomb input event**:
A delivered down or up input for an actor's bomb/action control. Repeated down events are distinct events even when the control remains held.

**Round**:
A unit of play governed by an ending condition and the rules of its mode.

**Fuse**:
A bomb's delay before timed detonation. A chain reaction can detonate it earlier.

**Blast**:
The explosion produced by a bomb, covering its cell and rays in the four cardinal directions.

**Soft block**:
A breakable obstacle on the board.

**Magic carpet**:
One of the four named items whose behavior has yet to be recovered.
_Avoid_: Carpet (as a separate item)
