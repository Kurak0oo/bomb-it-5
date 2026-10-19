# Original recursive chains, overlapping fire and callback mutation

The publisher SWF was replayed in six controlled cases. Both bomb-owner orders recurse synchronously, preserve the individual bomb’s owner for damage credit, and mutate live callback arrays. Two flames do **not** share a reference-counted hazard: the older cleanup clears their shared Boolean fire even while the younger explosion remains visible. A laser can add a blast callback after that frame’s cleanup loop, delaying its first cleanup count until the following frame.

## Reproduction and authority

Original SWF SHA-256: `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`. Player: `.scratch/edition-5-research/reference-player-recovery-v2/probe.exe`, SHA-256 `5a7adba2c2781818a418f19f5976bad1917b8c64568fd7b562a7660bdc99bb74`, pinned Ruffle `45366370ed7d1a59c89aa3cf7b765c7a274407cd`. Each curated run includes its eleven-patch build manifest.

[Cases](../../tools/reference_player/cases/chains/) enter original Arcade/Cinema through UI inputs, seed the original RNG with 12345, stop existing AI using original methods, park them away from already planted bombs, and let spawn protection and those bombs finish. Repositioning calls original validated setters and occupancy callbacks; pickups use original constructors followed by ordinary collection. Selected actors create bombs through their original `RobotController.addBomb`, preserving owner, bomb guard and capacity effects. No actor, health, score, outcome or weapon state is synthesized. These are explicit controlled fixtures, not input-only achievements.

```powershell
python tools/replay_reference.py --player .scratch/edition-5-research/reference-player-recovery-v2/probe.exe --case tools/reference_player/cases/chains/chain-human-first.json --output .scratch/edition-5-research/reference-runs/my-chain --observe --focus --fixtures
python tools/inspect_chain_probe.py .scratch/edition-5-research/reference-runs/my-chain --output .scratch/edition-5-research/my-chain-extract
```

[Curated evidence](reference-2026-10-19/chains/README.md) retains cases, acknowledged commands, fixture results, native state extracts, mutation events, full event files at decisive frames, actual screenshots, source hashes and 27 passing evidence checks. Full Focus frames remain in ignored investigation storage; the extracts record each original file hash. This is original-engine research, not Godot parity verification.

## Recursive chain and damage ownership, both creation orders

`chain-human-first` creates the human bomb at (1,1), then AI1’s at (2,1) ten frames later. `chain-ai-first` reverses their creation order. Both actors leave safely. Existing AI2 is positioned at (3,1), normal and damage-eligible, outside the human bomb’s power-one reach but inside AI1’s. AI3 remains safe, so the round continues.

In **both** runs the older bomb detonates on frame 913. Its `Bomb.blast` enters at selected depth 3, dispatches the neighbor’s original BLAST listener at depth 8, and recursively enters that neighbor’s `Bomb.blast` at depth 10 before returning. The younger bomb’s timer was only 61 immediately before this frame; the listener forces it to 71 and detonates it synchronously. AI2 dies during the AI-owned blast in both orders. Registration changes from four robots to three; `model.state="dead"` while its stored `isExist` remains true. **`isExist` denotes damage eligibility, not liveness.** AI1’s original `_modePoint` becomes 100 and the human’s remains zero, including when the human initiated the chain. Their life fields are unchanged in this Arcade example; do not infer life decrement from death.

Both owners’ bomb counts drop to zero during detonation. Both bomb objects remain in their original map bomb arrays while fire is active. Recursive completion registers the **child’s** `ended` callback before the parent’s; both run once in frame 913. The child removes itself on frame 929. Removing index zero from the live blast array skips the parent for that frame, so the parent cleans up on 930. Both map bomb arrays are empty by checkpoint 932. The created actor-one bomb fixture records its selected player, original robot reference, controller call and capacity transition, providing the runtime validation of optional actor selection.

Source locators: `bombs/AbstractBomb.as:deleBomb` dispatches original BLAST events synchronously; `bombs/Bomb.as:blastHandle`, `takeCount`, `blast`, `ended`; `commands/robot/TryToKillCommandChain.as:execute`; `gameengine/GameEngine.as:enterFrameHandle` (230), `addBlast` (132), `removeBlastHandler` (137). Exact decompile hashes and function lines are in [sources.json](reference-2026-10-19/chains/sources.json).

## Older cleanup removes a shared hazard before the newer visual ends

The two overlap cases acquire capacity two and place power-one bombs at (1,1) and (3,1), reversing which location is older. The flames overlap at (2,1), while the two bombs are too far apart to chain directly.

| Native observation | Both spatial orders |
| --- | --- |
| Older blast / first `ended` call | frame 894 |
| Younger blast / first `ended` call | frame 905 |
| Both visible and shared `Grid.fire=true` | frame 905 |
| Older cleanup / shared `Grid.fire=false` | frame 910 |
| Younger remains registered, blasted, `continueTime=5` | frame 910 |
| Eligible human moved into shared (2,1), remains normal | frame 910 |
| Younger cleanup | frame 922 |
| Human still alive after further stepping | frame 927 |

The 11-frame blast separation despite a ten-frame creation gap is another live-array effect: the older bomb removes its bomb callback during the bomb loop, skipping the younger timer on frame 894. Removing the older cleanup callback on 910 also skips the younger cleanup callback that frame. The screenshots show the newer explosion still rendered when the eligible human enters the cleared shared cell. This directly distinguishes active hazard state from visible flame lifetime; it is not merely an inference from animation.

Source: `Bomb.as:deleFire` (445) calls `Map.setFire(x,y,false)` separately for every stored blast cell; `Map.as:setFire` stores one Boolean through `Grid.fire`. There is no per-bomb ownership count. The overlap’s `true,true,false,false` writes and cleanup receiver IDs are retained in the event records.

## Late laser trigger and dictionary mutation

`laser-late-chain` places one older bomb at (1,3), another at (2,1), then collects Invincibility and laser through original collection and fires using legal directional/Space inputs. The older bomb naturally blasts on 895. On frame 896 its `ended` executes **before** `ShootLaserCommand.execute`. The laser invokes the young bomb’s BLAST listener synchronously in the robot engine phase, after the ordinary blast loop. End-of-frame native state is older `continueTime=2`, newly triggered `continueTime=0`. The young bomb first receives `ended` on 897, misses one cleanup call when the older removes itself on 911, and cleans up on 914.

The same frame records `LaserGunPlayCommand` constructing/adding a new `LaserPlayCommandChain`, removing/disposing itself, and the new chain executing `ShootLaserCommand` that frame. Shoot adds `LaserEndCommand`, then removes/disposes itself. **In this Ruffle run LaserEnd does not execute until 897**; its self-completion is recorded on 907, including the explicit dispose and removal/dispose path. These are observed enumeration results, not a promised cross-player dictionary ordering rule. The case intentionally uses Invincibility to survive the adjacent blast; it does not claim laser damage against an unprotected human.

Sources: `GameEngine.as:enterFrameHandle`; `commands/weapon/LaserGunPlayCommand.as:execute`; `bombs/Laser.as:init`; `commands/weapon/LaserPlayCommandChain.as:ShootLaserCommand.execute`, `LaserEndCommand.execute`. The file-local Shoot/LaserEnd classes are separately included in event filters.

## Command replacement and disposal through an original portal

`portal-command-replacement` consumes a shield with an ordinary self-bomb at frame 894, installing the original 80-frame `InvincibilityCommand`. It moves to empty (3,1) and uses legal Down input to enter the real Cinema portal at (3,2). On 902 the original portal adds `SendRobotCommand(target=13,12)` and a new 45-frame `InvincibilityCommand`. `CommandChain.addCommand` calls `removeCommand` on the old object, sets its chain null and executes **that old object’s dispose**, then installs the new object. Original receiver IDs distinguish replacement from a changed counter on the same object.

Both new commands execute in frame 902. Send completes on 931, restores movement/action listeners, sets damage eligibility true, removes itself, and adds `CheckRobotInPortalCommand`. The separate blinking command is still present at checkpoint 939 and disposes on 948; it is absent at 954. Therefore portal arrival can restore eligibility **before** the 45-frame command finishes. This is not the same protection lifecycle as a plain shield hit. The actual arrival screenshot shows the actor at the paired bottom-right portal.

Sources: `maps/platform/Portal.as:runEngine`; `commands/CommandChain.as:addCommand` (36), `removeCommand` (66), `execute` (84); `commands/robot/SendRobotCommand.as:execute`, `sendEnd`; `InvincibilityCommand.as:dispose`, `execute`.

## Observer boundary, failed attempts and remaining limits

The observer does not sort or enumerate original dictionaries to produce these events. The function wrapper preserves original inner calls, return/errors, and selected parent depth; snapshots read bounded native slots into owned JSON without AS getters or persistent object roots. Every retained run’s event files have zero dropped records, no stack overflow and balanced entry/return pairs. The [instrumentation record](edition-5-reference-events.md) documents fast-call blind spots and its unsuccessful claim of whole-session deterministic equivalence.

A separate event-collector-OFF overlap run retains the same Focus observer and fixtures. All **105 measured frames** match the ON run for bomb coordinates/counters/blast/cleanup, every Boolean fire cell, and human state/eligibility/grid/native position/capacity. [The comparison](reference-2026-10-19/chains/observer-comparison.json) explicitly excludes AI routes, host timers and dictionary-wide equivalence. This supports this bounded observation; it does not establish zero instrumentation cost or a universal AVM2 enumeration order. Concurrent replay host durations and original Date/getTimer/Tween overhead also preclude real-time duration claims here.

Uncurated first attempts remain under `.scratch/edition-5-research/reference-runs`: one event command exceeded the harness’s 256-byte mark-label limit before gameplay collection; shortened prefixes fixed it. Initial chain captures named “after” landed one frame before detonation and had no victim; final cases add the eligible target and correct frame. An initial portal attempt used a coordinate belonging to a different layout and met a solid cell; final native platform references establish this layout’s actual portal at (3,2), paired with (13,12). No failed attempt is relabeled as successful evidence.

Coverage meets the narrow chain/overlap/callback criteria for these controlled original states. Remaining limits: not every topology, bomb power, mode, owner combination, native Flash player, or dictionary allocation order is surveyed; source-only disposal/clear paths not exercised above remain source evidence. The desktop Godot behavior has not been changed or assessed by these runs. Phone testing remains deferred.
