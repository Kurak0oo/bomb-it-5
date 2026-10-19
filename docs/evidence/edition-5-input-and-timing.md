# Edition 5 source, input and timing

Research date: 2026-10-16. This is a static inspection of a publisher-distributed Flash build, not a runtime parity capture. It records evidence for [the accepted edition boundary](../../DESIGN.md) and the [development frontier](../development.md); it does not change the command contract or project configuration.

## Source identity and acquisition

The analyzed artifact is **Bomb It 5, `v.1.6.1`**, distributed by Agame at [`bomb-it-5-zh-fix.swf`](https://www8.agame.com/games/flash/b/bomb_it_5/bomb-it-5-zh-fix.swf). Its decompiled `Root.as` identifies `GAME_NAME = "Bomb it 5"`, `VERSION_NUM = "v.1.6.1"`, the `zlong.bombit5` loading class and SPIL identifier. These are artifact observations, not claims taken from a portal blurb. [S1]

The acquisition chain establishes a public retail distribution:

1. The [archived Agame page of 2014-01-22](https://web.archive.org/web/20140122215706id_/http://www.agame.com/game/bomb-it-5) is titled Bomb It 5 and directly embeds `http://www8.agame.com/games/flash/b/bomb_it_5/bomb-it-5-zh-fix.swf`. Saved locally as `.scratch/edition-5-research/agame-20140122.html`; the relevant locators are the page title, `param name="movie"`, object `data`, and `gameUrl` assignment. [S2]
2. The bytes downloaded from that publisher URL over HTTPS on the research date have SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2` and length **6,942,081 bytes**. They are saved as `.scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf`. [S1]
3. Their SHA-1, encoded as base32, is `QQJG775EJ4JRLNNDQW3LQ7HK6LOBWJBI`. This matches the Internet Archive CDX digest for the publisher URL's **2013-10-05 23:28:57** capture. The [CDX query](https://web.archive.org/cdx/search/cdx?url=www8.agame.com/games/flash/b/bomb_it_5/*&output=json&filter=statuscode:200&collapse=digest) is saved as `.scratch/edition-5-research/agame-swf-cdx.json`. Thus the live file's content also has a historical publisher capture, rather than relying solely on today's URL. [S3]

This identifies a particular publicly distributed edition 5 revision. It does not establish that all edition 5 revisions are byte-identical. The filename's `zh-fix` suffix is not interpreted as a gameplay change without a comparison. No cheat-portal build was used as rules authority.

There is a potentially misleading constant: `Root.__cheat__` is `true`, while `Root.__debug__` is `false`. A search of the complete exported ActionScript found no other `__cheat__` reference. `PersonRobot.minLife()` decrements `player.life`. The flag alone therefore does not establish an invincibility modification, and its historical publisher distribution is the identity evidence. This is not an exhaustive audit of every health or debug path. [S1: `Root.as:12–26`; `zlong/bombit5/gameengine/robot/PersonRobot.as:20–23`]

Two additional artifacts were acquired for provenance comparison, **not substituted for the analyzed build**:

| Artifact | Local path under `.scratch/edition-5-research/` | Bytes / SHA-256 |
| --- | --- | --- |
| [Publisher SWF archived 2013-01-11](https://web.archive.org/web/20130111075920id_/http://www8.agame.com/games/flash/b/bomb_it_5/bomb_it_5.swf), linked by the [Agame page archived 2013-01-02](https://web.archive.org/web/20130102010326id_/http://www.agame.com:80/game/Bomb-It-5.html) | `agame-20130111-bomb_it_5.swf` | 8,260,379 / `926a6c59e06b4a541d43aa9c587a1f1fe60afd6eb8d45dec3ffa9828f53d33ec` |
| [RTL mirror candidate](https://igre.rtl.hr/games/2014/bomb-it-5.swf) | `rtl-bomb-it-5.swf` | 8,276,415 / `3a1a22a95a4fde7fea2824def50f6edde0025fa2352b37e09f05b10cb9313185` |

These outer SWFs differ from the analyzed build and from each other. The RTL candidate needed nested loader unpacking; no equivalence of its game logic to the publisher build is claimed. The analyzed publisher build exports directly. The January publisher artifact's base32 SHA-1 also matches its CDX record (`V4RLS2WD6TMMDDO3IFOD3AL5F4DLKKN7`). [S3]

## Reproduction and source locators

All ActionScript locators below refer to the analyzed SHA-256 above, exported with **JPEXS Free Flash Decompiler 26.3.0**, obtained from the [official release](https://github.com/jindrapetrik/jpexs-decompiler/releases/tag/version26.3.0). The exported tree is `.scratch/edition-5-research/publisher-scripts/scripts/`. The upstream SWF is the primary source; the `.as` files are decompiler output, not original author source. Line numbers are conveniences for this export; class and method names are the durable locators. [S1]

To reproduce, download the publisher SWF, verify its SHA-256, and run JPEXS's script export:

```powershell
java -jar .scratch/edition-5-research/ffdec/ffdec.jar -export script .scratch/edition-5-research/publisher-scripts .scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf
```

The scratch directory is ignored by Git. Recovery assets and extracted art are investigation material and are not added to the game package. No files from bomb-it-1 were used.

## Timing recovered from the execution path

**The game requests a 35 FPS stage and advances its gameplay engine on frame events.** This number is recovered independently from edition 5; it is not imported from another edition. The SWF header and `Root` metadata say 30 FPS, but startup explicitly overrides that value. [S1]

The call path is:

- `Root extends AbstractRootClass`; `Root.GAME_FRAMERATE` is **35** (`Root.as:9,26`).
- `AbstractRootClass`'s constructor calls `initRootSetting()`, which obtains the concrete root class using `getQualifiedClassName(this)` and `getDefinitionByName`. If already on stage it calls `init()`, otherwise it registers `init` for `ADDED_TO_STAGE` (`zlong/Template/AbstractRootClass.as:52–67,227–234`).
- `init()` calls `initLoadSetting()`. That method executes `stage.frameRate = this._childClass["GAME_FRAMERATE"]` (`AbstractRootClass.as:173–177,207–214`).
- `GameEngine.start()` registers `enterFrameHandle` for `Event.ENTER_FRAME` and clears its pause flag. `stop()` removes the listener and sets the flag. `Game` invokes `gameEngine.start()` on its start/resume paths (`zlong/bombit5/gameengine/GameEngine.as:55–65`; `Game.as:535,541,609`).
- `enterFrameHandle()` only processes gameplay while `_pauseGame` is false. It does not use elapsed-time compensation in this method (`GameEngine.as:230–269`).

The active handler runs these phases in order: one sequence callback, bomb callbacks, blast callbacks, one AI-sequence callback, engine callbacks, movement callbacks, periodic tween callbacks, brick-explosion callbacks, then dead callbacks. Sequence and AI-sequence processing each rotate through their arrays one callback per invocation. This is an ordered frame-driven engine, not the newly designed all-actor command batch. [S1: `GameEngine.as:230–303`]

A `Timer(25)` exists and is wired to the same handler, but no `countTimer.start()` call appears in the exported code. The observed `start()` path uses `ENTER_FRAME`. The timer declaration is therefore **not evidence for a 40 Hz gameplay tick**. Likewise, the header alone is not evidence for a 30 Hz gameplay tick. [S1: `GameEngine.as:39,55–65,227`; complete-export search]

**Limit:** 35 is the requested stage cadence, not a measured guarantee of 35 updates per wall-clock second. No playback capture, browser throttling study, dropped-frame test, or complete audit of all independent animation/timer systems was performed. This evidence supports a later scheduling decision; it does not silently set Godot's physics rate.

## Input recovered from the controller path

These observations concern the normal active human controller. Pause/resume, focus loss and every item-specific callback have not been traced completely.

**Default keys are configurable.** `HowToPlayUI` first reads saved key configuration from `SharedObject`; when absent it uses the numeric key-code array `38,37,40,39,32,87,65,83,68,32,38,37,40,39,13`. Its associated arrays identify the actions and players. `Game` installs the chosen configuration in the human controller. [S1: `zlong/bombit5/ui/HowToPlayUI.as:302–319`; `zlong/bombit5/gameengine/Game.as:566–598`]

| Mode | Movement defaults | Bomb/action default |
| --- | --- | --- |
| One human | Arrow keys | Space |
| Two humans, player 1 | W/A/S/D | Space |
| Two humans, player 2 | Arrow keys | Enter |

**Movement remembers held directions and gives priority to the most recently pressed one.** On movement `KEY_DOWN`, `PersonInteractiveController` checks the corresponding held flag before calling the direction method, then sets that flag. This suppresses repeated down handling for an already-held direction. The base controller appends the direction to `robot.model.movArr` and replaces the robot's movement callback. On `KEY_UP` it clears that direction's flag, removes the direction from the array, then selects its last remaining entry or the stop callback when empty. Thus, while these listeners are active, holding Left, pressing Up, then releasing Up selects Left again. This path selects one cardinal movement callback; it does not combine two keys into a diagonal vector. [S1: `zlong/bombit5/gameengine/robot/PersonInteractiveController.as:49–109`; `InteractiveController.as:21–85`]

The movement callback is used by the frame engine: the robot registers its movement array, its `moveFunc` setter changes the array entry, and `GameEngine` invokes that entry in its movement phase. A key transition selects ongoing movement rather than executing all movement immediately in the keyboard handler. [S1: `zlong/bombit5/gameengine/robot/AbstractRobot.as:270–275,454–457`; `zlong/bombit5/gameengine/GameEngine.as:248–251`]

**Bomb down and up are distinct events.** Matching `KEY_DOWN` dispatches `RobotAction.BOMB`; matching `KEY_UP` dispatches `RobotAction.BOMB_UP`. Unlike the movement handler, the bomb handler has no held-key deduplication flag. Every matching delivered down event therefore reaches dispatch. This is not a measured operating-system repeat cadence or proof of a fixed auto-repeat interval. [S1: `PersonInteractiveController.as:130–156`; `InteractiveController.as:88–96`]

The robot listens for both action events; `RobotController` invokes its current down/up callbacks. The default down callback is `addBomb`; placement checks capacity and the current map cell before adding a bomb. Weapons can replace the down and up callbacks, so an up event cannot be globally discarded just because ordinary bomb placement is on down. Item-specific effects remain outside this record. [S1: `AbstractRobot.as:120–126`; `RobotController.as:43,141–166`; `zlong/bombit5/items/weapons/AbstractWeapon.as:99–100`]

## Implications and remaining work

The accepted new-game boundary batches one direction and two bomb booleans per actor per explicit tick. The original uses keyboard events, remembered movement, and frame callbacks. These are different representations. The record supplies facts for a later adapter decision; it does not replace the accepted boundary. [Accepted contract: `DESIGN.md`, "Command calling contract"; S1 controller and engine paths above]

Before implementing that adapter, decide how to preserve or deliberately simplify **ordered/repeated bomb events between ticks**, including a press and release in the same interval. Two booleans cannot express arbitrary ordering or multiple repeats. The touch stick also needs a deliberate cardinal-direction policy; the keyboard's last-pressed priority does not itself define analog-stick diagonals. These are open design questions, not recovered rules.

Still needed before broader fidelity claims: executable observations of input and cadence, pause/resume and focus-loss traces, the first board and gameplay-screen transcription, and separate source-linked records for bomb fuse/blast, soft blocks, clock/lives/score/endings, items and AI. No gameplay parity test or fixed Godot schedule is introduced by this research.

## Source references

- **S1:** [Publisher SWF](https://www8.agame.com/games/flash/b/bomb_it_5/bomb-it-5-zh-fix.swf), identity/hash and decompilation procedure above. Every script-based observation in this record applies to that exact artifact.
- **S2:** [Archived publisher embed page, 2014-01-22](https://web.archive.org/web/20140122215706id_/http://www.agame.com/game/bomb-it-5), saved HTML SHA-256 `59ad458779630a8b3387449665c3de2a5c49d220daa8ae94c0fb4893baddf8fc`.
- **S3:** [Internet Archive CDX records for publisher assets](https://web.archive.org/cdx/search/cdx?url=www8.agame.com/games/flash/b/bomb_it_5/*&output=json&filter=statuscode:200&collapse=digest), saved JSON SHA-256 `b81758d5604e570d7f3347c5206e1186ddece1d7496c1365c6cb96d23098e3c2`. This is archival provenance metadata; gameplay claims come from S1.
