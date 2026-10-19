# Edition 5 original bomb contact probes

Executed and inspected 2026-10-19 for recovery [#23](https://github.com/Kurak0oo/bomb-it-5/issues/23). These probes use legal keyboard input in the **original publisher SWF**. They establish self-damage, destruction/capacity observations and late entry into existing fire. They do not complete all callback-order, enemy-damage or instrumented-phase requirements of that ticket.

## Identity and protocol

The unchanged authority SWF is `.scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf`, SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`. [Provenance](edition-5-input-and-timing.md) owns the build identity. Every run manifest records the same SWF hash and observer executable `.scratch/edition-5-research/reference-player-base/observer.exe`, SHA-256 `f9ba16ba9c54b2f4f743a83423fb48aa2552936906d414b15da1ec0ae96021be`. This is the pinned Ruffle observer, **without fixture operations**, described in [reference tracing](edition-5-reference-trace-design.md).

[replay_reference.py](../../tools/replay_reference.py) rejects other SWF bytes, copies the exact authority bytes to a temporary non-dot path for original SharedObject setup, verifies command acknowledgements/frame accounting and validates700×510 PNG output. It records case/player/SWF hashes, input chronology, host monotonic times and player wall times. No gameplay fields, RNG or original functions were directly set/invoked by these cases; input consists of original menu clicks and key down/up. Rendering and post-step slot observation are separate protocol commands.

The reproducible stationary-self case is [bomb-self-contact.json](../../tools/reference_player/cases/bomb-self-contact.json):

```powershell
python tools/replay_reference.py --player .scratch/edition-5-research/reference-player-base/observer.exe --case tools/reference_player/cases/bomb-self-contact.json --observe --output .scratch/edition-5-research/reference-runs/contact-self-new
```

Output paths must be new. The case enters one-human Normal Arcade/Cinema, moves right for10 frames from the opening, places a bomb at logical(2,1), releases Space and stands on it. Per-frame graph/PNG tracing covers frames799–823 only. Other captures retain placement, pre-window and later death-animation state. No fixture flag is enabled.

Late-entry variants legally retreat left/down to(1,2), wait, then press Up at counter812,813 or814, tracing801–824. A capacity variant stays safely at(1,2), waits until805, then presses Space again. Each raw run below contains its exact `case.json`, `commands.jsonl`, manifest, PNGs, graphs and player log; these retained case copies reproduce the variant without inferring inputs from prose.

## Observed results

| Raw directory under `.scratch/edition-5-research/reference-runs/` | Main observation |
| --- | --- |
| `contact-self-01` | Placement at731 has counter0; frame803 counter71;804 is blasted, human state dead and owned bomb count0. Fire clears821. Candidate soft block(3,1) was absent from this random board, so this run does not verify its destruction |
| `contact-self-02` | Same legal input chronology; soft block(3,1) is present through803 and removed804. Human dies804 and capacity releases. Fire clears821 |
| `contact-entry-812-01` | Human safely waits at(1,2) through detonation804. Up input delivered812; physical motion begins813, logical entry into(1,1) and death are observed819 while its fire is true. Fire clears821 |
| `contact-entry-813-01` | Up delivered813; the starting physical y differs from other runs. Logical entry occurs821 with fire false and human still normal; remains alive through824 |
| `contact-entry-813-02` | Same input case as preceding row, different generated state. Logical entry occurs820, fire remains true and human becomes dead. Cleanup821 |
| `contact-entry-814-01` | Up delivered814; logical entry821 has fire false and human remains normal through824 |
| `contact-capacity-01` | At805 human is alive at(1,2), capacity count0, original fire still true. Another delivered Space down immediately creates a second ordinary bomb at(1,2), counter0 and count1; after806 its counter1 while the old visible blast persists |

These are original-reference observations, not Godot expectations or a deterministic replay claim. Board generation, visual variants, AI behavior and initial physical offsets differ. In particular, the two counter813 cases produce different contact frames; input counter alone is not a universal safe-entry recipe.

### Self-damage and capacity are separate from flame disappearance

In both stationary cases, frame803 has the human normal and damage-eligible (`isExist=true`), model `bombNum=1`, and the owned bomb `_time=71`, `_isBlast=false`. At804, the same bomb is `_isBlast=true`, `_continueTime=1`; human model state is `dead`; `bombNum=0`; one death-animation handler is registered; center and left-ray fire are true. The dead robot's `isExist` field remains true in these snapshots: eligibility also tests the model's dead state, so that flag alone is insufficient.

This matches the inspected source paths `Bomb.takeCount` (capacity release before `blast`), `AbstractBomb.hitRobotUnderPoint` (owner invokes `killSelf`), `AbstractPlayer.killSelfHandler`, `TryToKillCommandChain`, and `RobotDeadCommand`. Locators under `zlong/bombit5`: `bombs/Bomb.as:168–185,244–268`; `bombs/AbstractBomb.as:38–91`; `gameengine/AbstractPlayer.as:358–368`; `commands/robot/TryToKillCommandChain.as:34–77`; `RobotDeadCommand.as:32–58`.

The capacity-reuse run provides an actual second legal placement, rather than merely assuming count0 permits it. At805 the old blast at(2,1) has `_continueTime=2`; the living human at(1,2) has `allowBomb=1,bombNum=0`. Space down at the same counter produces another owned ordinary bomb(1,2), `_time=0`, `bombNum=1`. Its first following frame has `_time=1`. Thus the player can reuse capacity **before the previous flame ends**, when normal placement guards permit the new cell. This does not imply that every still-burning cell permits placement.

At the later878 stationary capture, the player's robot has been removed, the death callback is gone and the dimmed ending presentation is visible. Retry life still reads3 in that snapshot. It is not evidence that loss settlement, results or heart consumption already finished; those occur on later ending callbacks and belong to the separate session-flow recovery.

### Soft-block occupancy and collision-node removal

`contact-self-02` has an actual soft `Box` reference in grid(3,1), its `isExist=true`, and path node `isBlock=true` through803. At804 that grid's box reference is null, its node becomes `isBlock=false`, and its fire flag is true. Frame804's inspected original screenshot shows the adjacent popcorn obstruction replaced by flame. The first run had `unfixedBox=0.6` but no actual box there: that field is a generation probability, not proof of rendered occupancy.

This supports synchronous removal of the block occupancy/search blocker at detonation, consistent with `AbstractBomb.deleBox` and `Map.deleBox` (`bombs/AbstractBomb.as:129–151`; `maps/Map.as:206–212`). A separate controlled physical traversal through that newly cleared cell was not performed here. Break animation, conditional-drop completion and later pickup behavior are not inferred from occupancy clearing.

### Final lethal and first safe entry

The two boundary runs establish adjacent observed entry outcomes on the same target cell(1,1) of the human's own bomb:

| Run/frame | Raw display-container y | Model logical y | Fire(1,1) | Human model state |
| --- | --- | --- | --- | --- |
| `contact-entry-813-02`,819 |81.6 |2 |true |normal |
| same,820 |81.6 |1 |true |dead |
| same,821 |81.6 |1 |false |dead |
| `contact-entry-814-01`,820 |81.6 |2 |true |normal |
| same,821 |77.7 |1 |false |normal |
| same,824 |77.7 |1 |false |normal |

Positions are native display-container coordinates, including game offsets, not getter-evaluated source-local `yPos`. The visible foot/body overlap does not itself determine the logical damage cell. In the lethal run the physical move crosses the boundary before the following robot-engine occupancy update; that update changes logical y and applies existing fire. In the safe run cleanup has cleared the cell when logical entry is observed. The source supports this ordering: `GameEngine.enterFrameHandle` runs blasts, general/robot engines, then movement; `AbstractRobot.updateRobotPosition` invokes its position-change chain containing `GetFireCommand` (`gameengine/GameEngine.as:239–251`; `gameengine/robot/AbstractRobot.as:158–208`; `commands/robot/GetFireCommand.as:33–40`). The snapshots corroborate the end states; no new intermediate-phase hook was used.

Original frame PNGs were opened and inspected: both stationary pre-window/detonation sequences show the actor-to-skull change; the late lethal case shows death near the top-left fire; safe821/824 captures show the blue actor alive in the cleared top-left cell. The second-bomb capture shows the living actor and new placement while previous flames remain. Visual evidence is the original SWF rendering, not recreated art.

## Timing and interpretation limits

All traced ordinary detonations occur at804 in these runs, but source bomb counters can miss a callback during live-array mutation: stationary-self01 has `_continueTime=1` at both804 and805; stationary-self02 repeats7 at810/811. Both reach16 at820 and clear821. Thus this measured path has17 frame-counter intervals from detonation804 to cleanup821, with a skipped cleanup opportunity. The loop's live registry mutation is a source-grounded explanation, **not a directly instrumented identification of the responsible callback/removal**. Do not generalize these durations to every bomb creation/chain/weapon phase. See [gameplay phases](edition-5-gameplay-phases.md).

At the configured35fps,17 nominal frame intervals would be about0.486seconds. These executions were unpaced frame stepping with observation/render overhead, so that is not measured wall time: the25-frame stationary tracing windows consumed approximately10.14/11.95 host seconds. Original `pastTime` advanced from3 to9 within each window. The24-frame late-entry windows consumed approximately10.72–11.94 host seconds and advanced the original elapsed clock by6seconds. `Date`, original timer/Tween callbacks and AI therefore cannot be treated as real-time-equivalent in these runs. Per-frame fuse/fire state is valid evidence of these recorded executions; source-feel timing still requires a paced/low-overhead comparison.

No enemy hit, protected hit, destination portal hazard, stationary protection-expiry edge, second-bomb simultaneous chain, RNG alignment, native Flash comparison or exact callback mutation cause was verified here. Source hashes are unchanged; these probes made no production changes and do not alter accepted batching/scheduling/diagonal adaptations.

## Retained run manifests

The manifests' SHA-256 values pin the complete capture/input/state inventories (raw directories are ignored research storage):

| Run | Manifest SHA-256 |
| --- | --- |
| `contact-self-01` | `37296891c243d6f66f688c0291f15ae52c5f41ef0d1965f957ae48ddd61fcf91` |
| `contact-self-02` | `e516189f8c9f35ad20c64d2446ad1cccbfd7d1ceb63913b182645c711dad076d` |
| `contact-entry-812-01` | `fde9b6f3e63a0c4e9604cabace58ecd4fd6d890c079996e4bf17cf02b898b648` |
| `contact-entry-813-01` | `929074528f5aae247ce6fb85534cbb02d0333161f1a434d87040b814b6167502` |
| `contact-entry-813-02` | `496d552b0057d0001bcd0327c55efa2b53853e66e6aeca3b7e5708a53928dd16` |
| `contact-entry-814-01` | `8848d7be59512dd83381a41fbc17f93862d8384c881d4737abea75fd04311060` |
| `contact-capacity-01` | `3a963cf03c510bfd557e66f5b8c308dc68c9cb6c895d56185c37a0a7e6728085` |

The stored graph fields were inspected using `ReferenceGraph.node/field/array` from [inspect_reference_trace.py](../../tools/inspect_reference_trace.py), selecting `Game.personalPlayers[0]._robot`, its model, its owned Bomb objects, `Game.map.mapArr` and corresponding search nodes. All relevant snapshots were complete/nontruncated. No simulation-only regression or substituted inferred actor state was used as original evidence.
