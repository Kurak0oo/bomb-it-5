# Independently replayed protection and Cinema vehicles

These are controlled runs of the publisher SWF through the original engine. They verify shield replacement/consumption, Invincibility introduction/contact/expiry, both Cinema rides through destruction/recovery, retained equipment, Normal AI collection, and an ordinary human-owned bomb killing an unprotected enemy. They do not claim complete Flash-player equivalence or change the accepted Godot adaptations.

## Authority, fixtures and reproduction

- Original: `.scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf`, SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`.
- Player: `.scratch/edition-5-research/reference-player-actors/probe.exe`, SHA-256 `eeebea71c77ac5d9fb2f10478d225b457f61d3459387862a46cde632d19812c7`, pinned Ruffle `45366370ed7d1a59c89aa3cf7b765c7a274407cd`. Each curated directory includes its build record.
- Conditions: one human, three Normal AI, Arcade, Cinema; initial seed 12345. Original methods stop/park existing AI away from their planted bombs, then 100 original frames let spawn protection and those bombs finish. No robots, health, damage flags, score, weapon states or outcomes are synthesized. The [actor-fixture record](edition-5-reference-events.md#indexed-actor-fixtures-and-ai-control) explains surviving delayed callbacks and settling limits.
- [Five executable input cases](../../tools/reference_player/cases/protection/) contain the full setup and subsequent inputs. Pickups use original constructors and normal GetItemCommand collection. Repositioning uses original setters/occupancy callbacks and validates empty cells. Self-bomb tests with an equipped hammer explicitly invoke the existing ordinary-bomb fixture, bypassing the equipped action binding; the unprotected-enemy baseline uses **legal Space input**.

Example:

```powershell
python tools/replay_reference.py --player .scratch/edition-5-research/reference-player-actors/probe.exe --case tools/reference_player/cases/protection/car-shield-weapon-lifecycle.json --output .scratch/edition-5-research/reference-runs/my-car-run --observe --focus --fixtures
python tools/inspect_protection_probe.py .scratch/edition-5-research/reference-runs/my-car-run --output .scratch/edition-5-research/my-car-extract
```

The driver loads a byte-identical temporary SWF to avoid SharedObject rejection of dot-prefixed URL paths. [Curated evidence](reference-2026-10-19/protection/README.md) includes actual cases, acknowledged protocols, fixture results, source-state hashes, extracted timelines, selected screenshots and original-method score events. Full per-frame Focus files remain in ignored investigation storage. The extractor rejects truncated or ambiguous Focus data and reads stored `_moveSpeed`, rather than invoking its AS3 getter or treating an absent public-property slot as zero.

## Shield and vehicle lifecycle

Primary original locators: `items/tools/ShieldProp.as:changeStage`/`addUseNum`; `items/rides/CarProp.as:changeStage`; `MotoCycleProp.as:changeStage`; `commands/robot/TryToKillCommandChain.as:execute`/`vehicleComplete`; `InvincibilityCommand.as:execute`; `robot/RobotController.as:resetStage`, `robotMoveStop`, `robotMoveStart`; `robot/RobotView.as:setRobotMc`; embedded XML `<rides>`.

Both independent ride runs show:

| Observation | Car | MotoCycleProp |
| --- | --- | --- |
| Original model vehicle string | `_Car` | `_Skateboard` |
| Base stored speed / acquired velocity | 1.6 / 2.5600000000000005 | 1.6 / 2.08 |
| Original XML multiplier | 1.6 | 1.3 |
| Six right-input frames, native x displacement | 29.15 px | 23.60 px |
| Self-bomb damage begins | frame 923 | frame 923 |
| First observed vehicle cleared / controls recovered | frame 952 | frame 953 |
| Post-vehicle damage eligibility restored | frame 1033 | frame 1034 |
| Later self-bomb consumes shield | frame 1125 | frame 1125 |
| Post-shield damage eligibility restored | frame 1206 | frame 1206 |

Shield collection at frames 823 and 824 changes `model.shieldObj` to a **different original ShieldProp object**. There is one equipped reference. Acquiring either ride at 825 leaves that second shield reference and `weapon="sinker"` intact. The original action binding remains `HammerProp.bombDown` through acquisition, destruction and immunity expiry; this establishes retained equipment and handler, not a new test of hammer damage.

The first self-bomb starts vehicle loss while retaining the shield. The actor remains normal/alive, `isExist=false`, velocity returns to 1.6, and `_stageFunc` becomes `RobotController.robotMoveStop`. During recovery the ride string remains set; completion clears it and restores the normal control stage, followed by the original blinking immunity command. **Vehicle loss precedes shield consumption.** The later self-bomb, after vehicle immunity expires, clears the shield and gives another temporary immunity period. Neither event kills the actor or clears the retained hammer.

The protection command is observed through its `>80` boundary. In these runs it expires **81 frame intervals after creation**, because its first callback can execute in the creation frame. Do not translate that into an unconditional 82-following-frame rule. This is the same phase-sensitive distinction exposed by the [bomb callback traces](edition-5-reference-events.md#callback-mutation-observed-in-legal-play).

Right input held during vehicle loss does not move the recovered actor in these cases. Releasing and pressing again moves it 10.70 px over four frames at normal speed. This matches the source sequence: `robotMoveStart` can restore a deferred movement function, then `resetStage` selects `moveStop`. The observed fresh-input behavior is desktop original-engine evidence; physical phone controls remain deferred.

Normal AI player 1 also collects the hammer and each ride through the original eligibility/collection path, retaining `weapon="sinker"` and acquiring the same `_Car`/`_Skateboard` velocity values. The shielded AI contact case below independently verifies Normal AI shield collection. Easy-AI ShieldProp's source early return is **not** a runtime-tested condition here.

### Recovery uses host time

`TryToKillCommandChain` uses `TweenMax.to(..., 1, ...)`. Both lifecycle cases explicitly set `realtime 1` while stepping their 359 traced frames. The command interval from enabling to disabling pacing lasts approximately 11.28 seconds for Car and 10.93 seconds for Moto, including screenshots and observations. Recovery lands 29 and 30 frame intervals after the hit, rather than a certified fixed 35-frame boundary. Rendering, captures and Focus extraction consume host time too. These values corroborate completion/recovery under paced original playback; they do not replace the one-second source tween with a new fixed tick count.

## Invincibility introduction, contact and expiry

Original locators: `items/tools/InvincibilityProp.as:changeStage`; `commands/weapon/InvincibilityCommandChain.as`, including its file-local `CountMcPlayCommand` and `CountInvincibilityCommand`; `TryToKillCommandChain`; `AbstractBomb.as:hitRobot`/`hitRobotUnderPoint`.

The human collects Invincibility at frame 823: `state="Invincible"`, `isExist=false`. The projected introduction command remains present for 29 sampled frames, 823–851. The first observed active counter is `_time=1, _totalTime=350` at 852; it reaches 351 at 1202 and is removed at 1203, when state returns to normal and damage eligibility becomes true. The empty wrapper chain can remain; its presence alone is not active protection. This is an observed callback boundary, not just the nominal ten seconds or a painted effect duration.

The target AI at `(1,2)` is normal, damage-eligible and shielded before the human moves down into its cell. The original active contact effect consumes that shield at frame 864 and makes the target temporarily ineligible for damage. The target becomes eligible again at 945; continued contact kills/unregisters it at 946. It is still projected as `state="dead", isExist=true` during the death animation, with registered robots reduced from four to three. This directly demonstrates why `isExist` is not a liveness test. Its player's robot reference is cleared later. The protected human survives and subsequently expires normally at 1203.

No bomb is placed by the human in this contact case. Its damage therefore exercises Invincibility's original overlap callback, rather than inferring contact behavior from a bomb kill.

## Pause and observed teardown

Original locators: `Game.as:onKeyDownHandler`, `gamePause`, `doGamePause`, `doGameResume`, `mainMenu`, `overInit`; `ui/PauseUI.as:keydownHandler`/`onMainClickHandler`.

P schedules the original 100 ms pause. In the recorded case the active counter is 6 at frame 856, reaches 10 before the engine stops at 860, then stays 10 across paused checkpoints 866 and 896. Space resumes at 897; the counter is 15 at 901. A second P pauses at 905; the counter is 19 at checkpoint 911. The actual pause screenshot was inspected, and its visible Main Menu button is clicked at `(234,414)`.

At frames 931 and 1031 the menu is visible and Focus reports no available old Game. This establishes observed return to menu and loss of the prior projected session. It does **not** inspect the entire pending timer/Tween queue, prove garbage collection, or certify every asynchronous callback was canceled. Mid-vehicle-recovery pause and Invincibility-introduction pause were not exercised.

## Ordinary bomb kills an unprotected enemy

This additional [input case](../../tools/reference_player/cases/protection/ordinary-enemy-bomb.json) supplies the separate ordinary-bomb damage path required by the recovery work. See [curated frames and selected original score calls](reference-2026-10-19/protection/ordinary-enemy/).

- At 841, the controlled target at `(2,1)` is `state="normal", isExist=true`, with no shield or ride. The human at `(1,1)` has capacity free, life 3 and `_modePoint=0`.
- Legal Space creates an original bomb owned by that exact PersonRobot. At 842 it has `_time=1`, power 1, and owner `bombNum=1`. The human is then repositioned safely to `(1,3)` through the recorded fixture.
- At 912 the counter is 71 and the target is alive. At 913 the bomb is blasted, the target is dead/unregistered, and the surviving human's capacity is already free (`bombNum=0`). The bomb's stored counter remains 71 on its threshold branch; this is 72 executed countdown callbacks, not a claim of a 71-callback fuse.
- Original game execution calls `AbstractPlayer.set scoreData(100)` and `set killNum(1)` for the human; the corresponding original getters return the previous zero values. These are observed game calls, not observer-invoked getters. Human `_modePoint` changes 0→100 and its stored life remains 3. The victim's stored `_life` remains 1 at the hit; no decrement is invented from death state.
- A second legal Space at 934 successfully creates a new owner-matching bomb at `(1,3)`, confirming released capacity. The other two parked AI remain alive, so this is not a forced victory/result case.

Primary source path: `Bomb.as:bombEngine`/`takeCount`/`blast` → `AbstractBomb.as:hitRobotUnderPoint`/`hitRobot` → `AbstractRobot.as:bombRobotScore` and `TryToKillCommandChain` → `RobotDeadCommand`; `AbstractPlayer.as:modePoint`, `scoreData`, `killNum`. [Score events](reference-2026-10-19/protection/ordinary-enemy/score-events.json) include original receiver identities and bounded-buffer status (zero discarded events).

## Limits and failed setups retained

These tests use Ruffle's AVM2/timeline implementation, not the Adobe retail player. Date/getTimer and Tween behavior remain host-time-sensitive. Seeded whole-session equivalence has already [failed independently](edition-5-reference-events.md#equivalence-check-did-not-pass). Focus intentionally omits native display children/bounds, arbitrary referenced objects, Box/HitMove internals, complete navigation graphs and pending timer/Tween queues. An omitted shield object's private counter or encrypted score store is not silently treated as observed state. The curated per-frame timeline retains players 0/1; checkpoints retain all projected actors and every raw state is hash-addressed.

The first Car setup (`protection-car-01`) left stopped AI near their already-planted bombs; all three were removed and the later reposition fixture rejected the ended round. Its logs remain in ignored storage. Subsequent cases park those original actors on verified empty floor first. Earlier completed Car/Moto runs without the fresh-input checkpoint and the pause run without menu teardown also remain, rather than being relabeled as the final protocols. No Godot behavior, production artwork, phone testing, or tracker state is changed by this evidence package.

[The recorded assessment](reference-2026-10-19/protection/assessment.json) passes 83 observation and artifact-integrity checks, including original SWF/player identities, byte-identical committed cases, protocol/stderr hashes, selected image dimensions, ride ratios, shield precedence, protection expiry, contact death, pause/teardown observations and the ordinary bomb's owner/score/capacity results. These are checks of the recorded original runs, not 83 new Godot tests or proof of unexercised cases.
