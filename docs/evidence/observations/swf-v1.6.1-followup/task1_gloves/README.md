> Imported Dots supplemental record; assertions are retained as delivered. Read the [integration assessment](../../../edition-5-play-observations.md) for confidence, corrections and remaining limits. Source-relative paths in code spans refer to the [unaltered original](../../../../../.scratch/edition-5-research/observations/swf-v1.6.1-followup/task1_gloves/README.md).

# Task 1: the two "glove" items in play (BoxingProp and BombShoesProp)

Tags: [O] observed in captured frames, [S] read from decompiled source, [I] inferred, [U] unknown.
Harness: probe2 (Ruffle 45366370, exact SWF sha256 718c04c7…8a2). No cheats, no memory edits, no SWF edits.
Frame numbering: f<k> = the state after run_frame k. An input logged at counter N takes effect from run_frame N+1.
All frames are full-colour, uncropped 700x510 RGBA. They were losslessly re-encoded with PNG optimize, and sample pixel comparisons against the originals came out identical.

## Result
BOTH items were obtained by P1 and used in play. Neither is a cheat build. The help label for each:
- red glove icon = **BOXING GLOVE** = `BoxingProp` (propNum 38) [S+O]
- white hand icon = **PUSH THE BOMB** = `BombShoesProp` (propNum 6) [S+O]

The XML comment 手套 ("glove") belongs to BombShoesProp. 拳头 ("fist") belongs to BoxingProp [S].

| | BOXING GLOVE (BoxingProp) | PUSH THE BOMB (BombShoesProp) |
|---|---|---|
| Category | weapon (replaces the bomb or hammer action) | power-up (passive) |
| Control | **Space (bomb key), on KeyDown** | **no button: walk into a bomb** |
| Effect | punches up to 2 cells ahead (weaponRange 2), 2 uses (totalUseNum 2); the HUD bubble over the head shows uses left; after the last use the robot reverts to its default action [S+O] | the bomb you walk into slides at kickSpeed 7 until it hits something; the fuse is paused while it flies [S+O] |
| Drop weight | Arcade 0.01, Battle Royale (KillMode) 0.15 [S] | Arcade 0.10, Battle Royale 0 [S] |
| Where demonstrated | Battle Royale, session D (it is too rare in Arcade) | Arcade Normal, session A |

## BOXING GLOVE: session D, Battle Royale, 1 human vs 1 enemy, Easy (difficulty seeded down; allowed)
In Battle Royale the default action is a hammer (`KillModeWeapon extends HammerProp`) [S].
Space swings it: the cell in front loses its box, any bomb there is detonated, any item there is destroyed, and a robot there is killed [S].
Inputs (absolute frames; full log in common/logs/sessionD_probe2_out.log):

| Frame | Input | Result |
|---|---|---|
| 1006–1008 | kd right, then kd space @1007 | hammer breaks the box at (3,1). A FROG item is revealed (f001038) [O] |
| 1038–1046 | kd right | P1 walks onto the item and mounts the FROG (`HorseProp`, vehicle "_forg") (f001050) [O] |
| 1238 | kd space (facing right) | hammer breaks a cupcake box in row 1. A **BOXING GLOVE** item is revealed (f001262) [O] |
| 1269–1277 | kd right | P1 steps onto the glove (f001274). At **f001276 P1 has the BOXING GLOVE**: red glove icon with "2" over the head [O] |
| **1278** | **kd space** (facing right) | **punch**. The fist effect travels right (f001282–f001296) and the counter drops 2→1. No target in range, so nothing was hit [O] |
| ~1350–1376 | none (AI action) | the black AI also holds a BOXING GLOVE: it picked one up about f1078 (f001078 shows the glove and "2"). It punched P1, its counter went 2→1, and P1 lost the FROG with no death [O]. Why P1 survived: per the source, a rider is protected by the vehicle, which is lost instead [I] |
| **1382** | kd down + **kd space** | **P1's second punch, downward** (f001386; counter 1→0). The black AI 2 cells below flashes and loses its skateboard (f001394) [O]. That the punch caused this is [I]: the black AI punched back at the same moment (its counter reaches 0 at f001398) |
| 1424 | none | both robots are back to the default hammer once their glove uses are spent [O+S] |

The keyframes are in keyframes/BR_*.png. Every second frame of D8–D12 is in frames_BR_boxing_glove/, and every frame of D13.
An observed side note: inputs given from f779 to f796, right after the round started, had no effect [O]. The cause is [U]. Key input works from f866 on.

## PUSH THE BOMB: session A, Arcade Normal, level 1 (Zoo)
| Frame | Input | Result |
|---|---|---|
| 1902–1912 | kd right | P1 walks onto the white-hand item at (2,9). Picked up at **f001910**: score +100, no HUD counter [O] |
| 1924–1932 | kd left | move to (1,9) |
| **1933** | **kd space** | bomb placed at (1,9). Visible at f001934 [O] |
| 1934–1942 | kd up | step off the bomb |
| **1944** | **kd down** (walk into the bomb; Space not pressed) | **kick**: the slide starts at f001946 at about 7 px/frame and the bomb stops against the (1,13) wall at about f1961–1965 [O] |
| 2025 | none | blast at f002025, which is N+92 instead of the normal N+72/73, because the fuse is paused during the flight (`engineArr.splice(0)`) [O+S]. Flame lasts f2025–2041 (17 frames) [O] |

The keyframes are in keyframes/ARC_*.png. Every frame is in frames_arcade_push_the_bomb/. An earlier potion pickup (f1860–1902) is included for context.
Not repeated: a second, cleaner PUSH THE BOMB demonstration was not captured. Battle Royale has drop weight 0 for it.
