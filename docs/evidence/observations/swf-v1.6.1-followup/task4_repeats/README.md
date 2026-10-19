> Imported Dots supplemental record; assertions are retained as delivered. Read the [integration assessment](../../../edition-5-play-observations.md) for confidence, corrections and remaining limits. Source-relative paths in code spans refer to the [unaltered original](../../../../../.scratch/edition-5-research/observations/swf-v1.6.1-followup/task4_repeats/README.md).

# Task 4: three runs each of pickup, Space held, Space repeated and flame duration

Tags: [O] observed, [S] source, [I] inferred. Absolute frame IDs. An input logged at counter N acts from run_frame N+1, and f<k> is the state after run_frame k.
Runs come from session A (Arcade Normal level 1, Zoo, harness `probe`; log in common/logs/sessionA_probe_out.log; extract in input_log_f843-1700.txt) and session D (Battle Royale).
Full-colour, uncropped frames:
- frames/<run>/kd_to_bomb/: from the Space press to the bomb appearing
- frames/<run>/blast_to_flame_end/: from just before the blast to 2 frames after the flame ends
- keyframes/

## Pickup: 3 runs (plus 1 extra)
| Run | Mode | Input | Pickup frame | Effect |
|---|---|---|---|---|
| 1 | Arcade (A) | walk onto potion at (1,7) | **f1882** | POWER +1 on the HUD (1→2), score +100 [O] |
| 2 | Arcade (A) | kd right @1902 onto the white hand at (2,9) | **f1910** | PUSH THE BOMB, score +100, no HUD counter; kick confirmed later (task 1) [O] |
| 3 | Battle Royale (D) | kd right @1269 onto the red glove | **f1276** | BOXING GLOVE, "2" over the head [O] |
| (4) | Battle Royale (D) | kd right @1038 onto the frog | about f1044–1050 | FROG mounted [O] |

The pickup reacts when the robot enters the item's cell [O]. In runs 1, 2 and 3 the HUD or the head icon changed within 0–2 frames of entering the cell [O]. Run 3 is in Battle Royale because it is the only mode with a common weapon drop. The pickup code path (AbstractItem) is the same in every mode [S].

## Space held: 3 runs (one Space KeyDown, held for about 117 frames, then KeyUp)
| Run | kd space | ku space | Bombs placed | Bomb visible | Blast | Fuse (blast − kd counter) | Flame frames |
|---|---|---|---|---|---|---|---|
| fl_r1_held | 844 | 961 | **1** | f845 | f917 | 73 | f917–933 = **17** |
| fl_r2_held | 979 | 1096 | **1** | f980 | f1052 | 73 | f1052–1068 = **17** |
| fl_r3_held | 1114 | 1231 | **1** | f1115 | f1187 | 73 | f1187–1203 = **17** |

Holding Space never placed a second bomb. A bomb is placed on the KeyDown event only (`bomb_down` → `addBomb`) [O+S].

## Space repeated: 3 runs (18 KeyDown/KeyUp taps, one every 4 frames, while the bomb is live; bomb limit 1)
| Run | First kd | Taps | Bombs placed | Blast | Fuse | Flame frames |
|---|---|---|---|---|---|---|
| sp_r1_repeated | 1249 | 18 | **1** | f1321 | 72 | f1321–1337 = **17** |
| sp_r2_repeated | 1405 | 18 | **1** | f1478 | 73 | f1478–1494 = **17** |
| sp_r3_repeated | 1561 | 18 | **1** | f1633 | 72 | f1633–1649 = **17** |

## Flame duration: 6 runs (3 runs required)
All 6 runs above gave **17 frames** of flame at power 1 [O]. The kicked-bomb blast (task 1) was also 17 frames (f2025–2041).

## Fuse: 72 vs 73
`Bomb.takeCount`: `if(_time > _blastTime && !_isBlast) blast else ++_time`, with _blastTime = 70, so the blast comes on the **72nd callback** [S].
That gives N+72 when no callback is skipped. When another bomb is removed earlier in the same frame's `for each` over `_bombArr` (Tool.safeRemove splice), this bomb's callback is skipped once, which gives N+73 [S].
The runs at 73 frames had other blasts during the fuse [O], which fits that explanation [I].
