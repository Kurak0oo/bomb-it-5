# Design

Working title: Bomb It 5. The store name is not chosen. Do not publish under the name Q版泡泡堂.

## Settled

- This is a new game. `Kurak0oo/bomb-it-1` is parked. Do not import its scenes, its 35 Hz tick, its weapons, its AI, its maps, or its tests. That port is Godot 4.7 and its tests lock Flash parity for a different game.
- The rules authority is the retail edition 5 SWF. Portal blurbs are not rules. The 无敌版 cheat build is out. Editions 4 and 7 are later diffs, read from their own SWFs, and only for features edition 5 does not already have.
- Godot 4.5, GDScript, Compatibility renderer. Official Douyin Godot export lists 4.5 only and rejects custom export templates. WebSocket exists there. TCP, UDP, WebRTC, threads, GDExtension, and C# do not.
- Phone, landscape, locked. The official Godot Douyin table still says portrait only. The game does not flip to portrait. `game.json` `deviceOrientation` is `landscape` when that export is tried. If the exporter forces portrait, the export waits. The game does not.
- The board is centered. A translucent stick sits on the left of the playfield and a translucent bomb button on the right. Both are inside the game view. Touches on the grid do nothing. The notch and the Douyin capsule stay clear of both controls. Extra item buttons wait until the SWF says an item needs its own button.
- One human and three AI on the first match. No second human on the same phone.
- Later, in order: co-op against AI across phones, then PvP. No networking in the first slice. No accounts.
- A round has a replaceable ending. The first ending the original uses for this mode is "all enemies are dead." Later modes and tasks are another ending plus extra rules on the same round. The first build implements one ending.
- Before the SWF is read, the only bomb behavior that may be coded is the shared match: place a bomb, a fuse, a plus-shaped blast, and soft blocks that break. The glove, the bouncer, the magic carpet, and the heavy bomb are named empty slots. Nothing fills a slot from a portal description.
- Maps come from the original edition 5 game. Tile count, solids, soft blocks, and spawns are recovered. There is no stand-in 15×13 board and no map generator.
- The gameplay screen's layout and the elements on it come from the original gameplay screen. Painted pixels are redrawn later in that painting style. Copied SWF sprites, music, and level art stay out of the Douyin build.
- Soft blocks drop nothing until the SWF says otherwise.

## Open

These two were not answered. Do not fill them with a guess.

1. **Commands.** Recommended: each tick consumes one command per actor, a direction plus bomb press and release. The stick fills the human command. Something else fills the three AI commands. A later phone replaces one AI command. No socket in this slice.
2. **How far "use the original" goes.** The map and the gameplay screen already come from edition 5. Recommended: the clock, the lives, the score, and the exact win and loss conditions come from that match too, and stay empty until one map and one gameplay screen have been read. A student remake's 15×13 board and 3-minute clock are not evidence.

## Asked of the next session

Settle the two open items with the user. Then build the tick and the command boundary only if item 1 is accepted. Leave the board, the HUD, the timer, the lives, the score, and the four item slots empty until the SWF is read. Do not write an AI personality. Bomb It 1's AI is the wrong game.
