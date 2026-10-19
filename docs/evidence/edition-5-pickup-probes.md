# Edition 5 conditional-drop and basic-pickup probes

Original-reference execution on 2026-10-19 for recovery [#27](https://github.com/Kurak0oo/bomb-it-5/issues/27). This establishes basic upgrades, collection/scoring, placement-time power, successful/failed conditional draws, occupied-cell suppression, paired human/AI eligibility for 14 pickup types, quota and vehicle exhaustion, and timed spawning. Legal input, original-method fixtures and source deductions are identified separately. This report does not close the ticket.

## Authority, tooling and retained evidence

Authority remains the untouched publisher edition5 v1.6.1 SWF, SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`; see [provenance](edition-5-input-and-timing.md). The player is pinned Ruffle `45366370ed7d1a59c89aa3cf7b765c7a274407cd`, with the recorded observer/fixture/event/compact research patches. [Trace design](edition-5-reference-trace-design.md) distinguishes passive slot reads from explicit original-method fixtures.

Preserved executables used:

| Player | SHA-256 | Uses here |
| --- | --- | --- |
| `.scratch/edition-5-research/reference-player-instrumented/probe.exe` | `152899b9661c60091ef5399af4279431259ad369253ce041787fb4481f70e0d1` | Unseeded basic limits/life case |
| `.scratch/edition-5-research/reference-player-seeded/probe.exe` | `b558d22562613586ae4ba74858ee7048ff5c91e544cda3a2daea23b30cf42609` | Placement-power and explicit-seed conditional/occupied cases |
| `.scratch/edition-5-research/reference-player-actors/probe.exe` | `eeebea71c77ac5d9fb2f10478d225b457f61d3459387862a46cde632d19812c7` | Indexed human/AI comparison and paced original-clock observation |

| `.scratch/edition-5-research/reference-player-recovery/probe.exe` | `e9c9f65d03c3af960d84934e0becee5d65de3d23d70f9ea2e725418aabf63292` | Original build/break/time callback fixtures; quota/vehicle/timed boundary cases |

The seeded build fixes the research bridge's seed-startup guard; its `build.json` records the patch identities. Two initial attempts to seed the first executable were rejected before gameplay. They are tooling failures, excluded from completed results and not attributed to original-game behavior.

Replayable input cases live under [tools/reference_player/cases/pickups](../../tools/reference_player/cases/pickups); curated records live under [the pickup evidence bundle](reference-2026-10-19/pickups). [Initial-run summary](reference-2026-10-19/pickups/summary.json) retains314 projections from the original raw graphs, with raw file hashes, player/case identities, actor/player values, grid occupancy, bombs, MapMaster counters and attributed consumed random draws. Each run directory there retains its exact executed case, command log, stderr, manifest and any fixture results (boundary runs consolidate full results in `fixture-results.jsonl`); selected original screenshots/events are retained too. A `.gdignore` keeps this research evidence out of Godot resources. Large raw graphs/full event directories remain in `.scratch/edition-5-research/reference-runs/` under the same run names.

All retained relevant graphs report nontruncation. Across recorded event files, dropped events, event overflow and selected-stack overflow are zero. This establishes the integrity of those selected recordings, not coverage of methods excluded by their prefix filters or a native Flash comparison. Raw state was read through `ReferenceGraph.node/field/array` in [inspect_reference_trace.py](../../tools/inspect_reference_trace.py) and `FocusGraph` in [inspect_reference_focus.py](../../tools/inspect_reference_focus.py); no Godot result was substituted for original evidence.

Example reproduction (use a new output directory):

```powershell
python tools/replay_reference.py --player .scratch/edition-5-research/reference-player-seeded/probe.exe --case tools/reference_player/cases/pickups/conditional-seed-2.json --observe --compact --output .scratch/edition-5-research/reference-runs/pickup-drop-new
python tools/replay_reference.py --player .scratch/edition-5-research/reference-player-instrumented/probe.exe --case tools/reference_player/cases/pickups/basic-limits.json --observe --compact --fixtures --output .scratch/edition-5-research/reference-runs/pickup-limits-new
```

`--fixtures` permits only the case's explicit original-method operations. In the basic case, an allowlisted original item constructor creates the pickup at the human's current cell; the following ordinary `GetItemCommand` performs eligibility, `changeStage`, collection and sound. No stat, score, health or result field is assigned directly. Seeding is separately an explicit initial-RNG control, even where the manifest's actor-fixture flag is false. Source/source-like paths below are beneath `.scratch/edition-5-research/publisher-scripts/scripts/zlong/bombit5/` unless otherwise stated.

## Basic upgrades and saturation

[basic-limits.json](../../tools/reference_player/cases/pickups/basic-limits.json) waits until the original human at(1,1) is active, then supplies28 pickups one at a time. `pickup-limits-02` completed at frame923. Before collection: capacity1, power1, movement acceleration1.6, player life3, item points0. The actor stays in place and alive during all28 collections.

| Effect | Original runtime result | Consumption/scoring at limit |
| --- | --- | --- |
| Capacity,10 pickups |1→9 after8 pickups; remains9 after9th/10th |Both extra pickups disappear; each still adds100 item/HUD points; stored upgrade list stays at8 capacity entries |
| Power,6 pickups |1→5 after4; remains5 after5th/6th |Both extra pickups disappear and add100 points; no extra stored power upgrade |
| Speed,10 pickups |1.6→`2.3000000000000007` after7; additional3 do not increase it |All10 are consumed/scored. Both `robotVelocity` and non-riding `velocity` match; binary floating-point value is reported without rounding it into a different bound |
| Life,2 pickups |Player `_life`3→4→5; actor remains normal |Both consumed/scored; no separate live-actor hitpoint counter was granted |

The first capacity fixture at821 leaves a `NumProp` on grid(1,1), with original stats/points unchanged. At822 the item is gone, capacity2, item points100, and one stored upgrade. Selected event records retain the original constructor, `GetItemCommand`, `changeStage`, `eatProp` and player point setters. The same before/after pattern holds across all28 items. Final raw `_itemPoint=2800`; the inspected [final original HUD](reference-2026-10-19/pickups/pickup-limits-02/final.png) independently shows2800, lives5, capacity9, power5 and speed indicator8.

Source supports this result: `NumProp.changeStage` and `PowProp.changeStage` first call `super.changeStage`, then apply their cap guard; their robot setters **add**1 despite assignment syntax (`items/tools/NumProp.as:20–27`; `PowProp.as:20–27`; `gameengine/robot/AbstractRobot.as:417–436`). Constants are9 and5 (`GameConfig.as:111–113`). Speed uses XML max2.3 and adds0.1 while below it (`SpeedProp.as:21–28`; `AbstractRobot.as:439–446`; embedded XML line7). Common `AbstractItem.changeStage` awards points before these stat guards; normal collection removes the map pickup (`items/AbstractItem.as:143–146,182–191`; `commands/robot/GetItemCommand.as:31–48`; `gameengine/AbstractPlayer.as:295–308`).

**A capped upgrade is still eligible/consumed in these observations.** It is not an uncollectible pickup and does not remain on the board. No genuinely ineligible human basic-item case was observed. The fixture's own rejected cell/actor guards would be research-tool guards, not proof of original `canEated` behavior. Paired AI acquisition is described below.

### Life belongs to the player/session

After reaching life5, the same case legally places an ordinary bomb and stands on it. At the later [lethal screenshot](reference-2026-10-19/pickups/pickup-limits-02/life-is-not-hitpoints.png) the actor is dead, `_life` still5 and item points still2800. Thus two life pickups did not create two extra hits for the current robot. Loss-cartoon settlement, next retry and eventual heart decrement are not claimed observed by this capture.

This follows `LifeProp.changeStage → PersonRobot.addLife → player.life += 1` (`items/tools/LifeProp.as:20–23`; `gameengine/robot/PersonRobot.as:24–26`). The distinct later loss settlement lives in `AbstractGameMode.loseHandler` (`gameengine/gamemode/AbstractGameMode.as:144–182`). The raw HUD after the bomb also includes a separate block award, so2800 item points must not be confused with every displayed HUD point after the lethal blast.

### Bomb power is copied when placed

[placement-power.json](../../tools/reference_player/cases/pickups/placement-power.json), run `pickup-placement-power-01`, obtains capacity2 through original collection, legally places a power1 bomb at(2,1), returns to(1,1) and collects one power pickup. Actor power becomes2 while the existing bomb remains1. A second legal Space down at(1,1) creates a power2 bomb; the two simultaneously observed owned bombs retain powers1/2. This is an actual original placement/upgrade sequence, not a direct bomb edit. The [original capture](reference-2026-10-19/pickups/pickup-placement-power-01/two-bombs-different-power.png) shows the two placements and HUD capacity/power2. `Bomb.setBombPow` copies owner power at initialization (`bombs/Bomb.as:123–131`).

## Conditional drops: consumed RNG and delay

Seven legal bomb/escape runs cover initial seeds1–5, including three seed2 repetitions. None uses an actor pickup/reposition fixture. The human places at(2,1) and safely retreats to(1,2). A25-frame compact/event window observes original block-break callbacks, drop guards, actual `Math.random` results and constructors. MapMaster is observed configured with probability0.5, quota32 and initial vehicle budget4. The ordinary weighted class list is source-reconstructed as97 entries; the generation field `Grid.unfixedBox=0.6` is a separate soft-block probability, not the drop probability or proof that a particular block exists.

Examples from `pickup-drop-seed1-02`:

| Cell / original frame | Recorded drop-probability draw | Class-selection draw | Actual original constructor |
| --- | --- | --- | --- |
| (3,13),798 |Draw571=`0.08334817178547382` |Draw572=`0.48474319837987423` |`PowProp` |
| (13,12),806 |Draw605=`0.3760763523168862` |Draw606=`0.7225339822471142` |`SpeedProp` |
| (12,13),807 |Draw608=`0.22426658822223544` |Draw609=`0.42880683671683073` |`PowProp` |

These values come from original consumed draws with selected caller chains containing that Box's `createProp`, not an extra random call made by the observer. The first class draw gives `floor(0.48474319837987423×97)=47`, within the recovered PowProp entries. The frame798 raw grid independently contains `PowProp` at(3,13), while fire there is still true. A drop can therefore be constructed while the cell's bomb fire persists; flame disappearance is not the reveal gate. The source gate is completed break animation and no actor occupancy, followed by quota/probability checks (`maps/Box.as:146–159,185–218`).

For the human's target block(3,1), `pickup-drop-seed2-02` records removal at804 and `createProp` at814. Its probability draw602=`0.6702341781929135` fails0.5; no class-selection draw, item constructor or pickup follows for that block. A [retained original event file](reference-2026-10-19/pickups/pickup-drop-seed2-02/events/f000814.json) records the guards/results and exact caller. Seed4 observes the same target's reveal at815 instead; a callback/frame boundary can vary. Do not encode a universal elapsed duration from one recorded break.

Other observed failed target draws were0.9185297298245132,0.826909139752388,0.5126438373699784 and0.6132530299946666. Seed1/3 did not have the human target soft block in their generated instances; their absence is not a failed drop. Positive conditional drops above come from independently observed other blocks, rather than forcing a successful target draw.

**The same initial seed is not sufficient to align these complete runs.** Seed2 repetitions show different consumed draw ordinals/results by reveal. Changing wall-clock-sensitive callbacks, AI decisions and runtime enumeration are possible explanations, not individually established causes here. Events begin near the drop window, so the entire startup draw stream was not recorded. Cases preserve initial seed and actual subsequent consumption; they do not claim cross-run deterministic board/action/RNG equivalence. A naturally generated `BombShoesProp` in one repetition remains original research evidence only; this does not resolve or enable an excluded production item slot.

## Occupied-cell suppression

[occupied-drop.json](../../tools/reference_player/cases/pickups/occupied-drop.json) uses seed2 and an explicit original `InvincibilityProp` construction/normal collection solely to survive its own hazard. No position is teleported or actor state directly assigned. The human stands on the bomb at(2,1), waits for destruction of the actual soft block(3,1), then legally moves right into that cleared cell before reveal completes.

In `pickup-drop-occupied-01`, the block clears904. The human is logically at(3,1) by911 and remains there, alive with the original Invincible state. The bound Box's break clip progresses through raw current frames7/8/9 at911–913; its final callback914 clears/disposes it. Events show that target's `countBrickExp` and `dispose`, but **no `createProp` invocation or corresponding probability draw**. No pickup appears in the cell through922. [The inspected original capture](reference-2026-10-19/pickups/pickup-drop-occupied-01/occupied-reveal.png) shows the protected human occupying the revealed cell amid the original hazard animation.

Combined with the matching source guard `map.getRobot(xN,yN).length == 0` before `createProp`, this establishes the occupied-case suppression path; it was not merely an unlucky probability result. Compare the separate empty-cell seed2 run, where the same source branch actually reaches `createProp`. Random/time histories differ between these cases; they are not represented as an otherwise byte-identical paired experiment.

## Human and AI acquisition

[actor-eligibility.json](../../tools/reference_player/cases/pickups/actor-eligibility.json) compares human player0 with AI player1 for landmine, hammer, flamer, laser, triple-shot, fireball, car, moto, capacity, power, speed, life, shield and invincibility. The original AI stop operations isolate current routes/listeners, but do not alter `GetItemCommand`, pickup permissions, effects or stats. AI player1 is moved through original reposition/occupancy methods to clear floor(15,1), because its prior cell(14,1) contains a bomb. The first attempt's occupied-floor rejection was a fixture guard, not a false `canEated` result.

Completed run `pickup-actor-eligibility-02` records **28 original `canEated=true` returns, no false returns**, followed by ordinary collection and no remaining pickup at each actor's cell. Each return is tied to the actual item receiver and PersonRobot/AIRobot argument. The [paired summary](reference-2026-10-19/pickups/pickup-actor-eligibility-02/summary.json) retains all28 observed effects and event locators. The [original final HUD](reference-2026-10-19/pickups/pickup-actor-eligibility-02/after-pickups.png) was opened and inspected.

Permission and effect differ:

- Life is eligible for both actors and awards100 points, but human player life changes3→4 while AI life remains1. `AIRobot` inherits empty `AbstractRobot.addLife`; `PersonRobot` overrides it (`gameengine/robot/AbstractRobot.as:302–308`; `PersonRobot.as:24–26`). This is not an ineligible AI item or a live-actor extra hit.
- Invincibility is consumed and sets both actors' original state to `Invincible`, but item points stay1300→1300 for each. Its override does not call common `AbstractItem.changeStage` (`items/tools/InvincibilityProp.as:70–99`). A blanket100-point award for every item would be incorrect.
- With both actors already on motos, the speed pickup changes base `robotVelocity`1.6→1.7000000000000002 while current riding `velocity` stays2.08. The original setter changes current velocity only when no vehicle is equipped (`gameengine/robot/AbstractRobot.as:439–446`).

All14 tested types are permitted to both actors under Normal Arcade's source lists (`embedded-6787.xml:283–297`; `items/AbstractItem.as:223–234`). There is consequently no evidence for inventing a Normal-scope permission exclusion among them. AI targeting preference is a separate policy: [later original AI probes](edition-5-ai-runtime-probes.md) observe tab-prefixed profile names failing class lookup, so speed and mine can be consumed yet are omitted from the AI targeting list. Actual use of acquired weapons, other difficulties/modes and excluded production-slot candidates remain separate questions. Original Easy-AI shield code has an additional effect guard, but Easy is outside this executed first-build comparison; it must not be relabeled as a measured Normal exclusion.

## Quota, vehicle budget and timed spawning

The boundary cases isolate original drop logic through explicit fixtures. `build-soft` invokes original `MapMaster.buildRanUnFixBox` on validated empty, actor-free floor (2,1); `break-soft` invokes original `Box.deleteBox` plus `Map.deleBox`. The original brick animation, occupied-cell guard, private `createProp`, consumed RNG and counters then run normally. Legal right/left movement collects any resulting item. **These direct breaks bypass weapon targeting, damage and attack score credit.** They do not establish legal attack scoring or natural frequency of these situations. No quota, vehicle budget, class array or time field is directly assigned. Source locators: `maps/MapMaster.as:220–223,275–297`; `maps/Box.as:85–88,134–159,185–220`.

Original AI stop/reposition operations keep opponents away from their already planted bombs. They preserve original collection and map registration; pending callbacks remain live. The first seed1050 attempt instead parked opponents in corner blast lanes and lost the active Game before cycle 2. That failed attempt is not used as budget evidence; the completed case parks them at observed empty interior cells (3,3), (5,5), (7,9).

### Actual quota boundary

[quota-boundary.json](../../tools/reference_player/cases/pickups/quota-boundary.json), completed run `pickup-quota-boundary-01`, performs 100 build/break/collect cycles with initial seed2. Before the cycles, ordinary earlier AI blasts have already produced `propCurrent=2`. Original subsequent successes advance it to 32, with no setter fixture involved. At frame3747, probability draw575=`0.07303572166711092` and class draw576=`0.7701720152981579` construct `LifeProp`; original additive `propCurrent=1` reaches 32. At the next reveal, frame3801, original `Box.createProp` is entered but produces **no RNG draw, item constructor or quota increment**. Later reveals through cycle100 likewise leave the quota at 32. The [boundary summary](reference-2026-10-19/pickups/pickup-quota-boundary-01/summary.json) retains source-state hashes, all fixture budget acknowledgements and attributed events; [frame3801](reference-2026-10-19/pickups/pickup-quota-boundary-01/events/f003801.json) retains the suppressed call.

This is the actual `propCurrent < propTotal` boundary (`maps/Box.as:190–218`), rather than merely reading the configured 32. Fixture-created basic pickups in earlier cases were not counted as evidence of this natural drop counter.

### Actual vehicle exhaustion and partial list mutation

[vehicle-boundary.json](../../tools/reference_player/cases/pickups/vehicle-boundary.json), run `pickup-vehicle-boundary-02`, uses initial seed1050. The seed was preselected by an offline transcription of the pinned Ruffle RNG to enrich rare vehicle outcomes; the runtime draws and constructors, not the offline prediction, establish the result. The source RNG is neither reseeded nor intercepted. Actual original `CarProp` constructors at frames1587,1857,2559,3045 decrement the budget 4→3→2→1→0. At frame3423, original probability draw600=`0.2517838063649833` succeeds and class draw601=`0.9747620052658021` selects `floor(draw×97)=94`, then `MotoCycleProp`. Because the budget is now zero, there is **no pickup constructor and no quota increment**; fixture acknowledgements before the following cycles still record the same count23. [The exact suppressed-call events](reference-2026-10-19/pickups/pickup-vehicle-boundary-02/events/f003423.json) are retained.

The source does not completely remove vehicles in this execution. Its `for each` loop mutates the live Array with `splice` (`maps/Box.as:204–211`). Observed `MapMaster._propArr` changes from length97 to95 and retains one final `CarProp` class entry; `MotoCycleProp` and one of two adjacent `CarProp` entries disappear. The shared object identity is unchanged, and `Game.mapPropArr` references **that same Array**, before and after mutation. This matches assignment in `gameengine/Game.as:351–357` and `MapMaster.as:335–337`. A faithful description must preserve this partial live-list mutation rather than claim that all vehicle classes were removed. The [vehicle summary](reference-2026-10-19/pickups/pickup-vehicle-boundary-02/summary.json) retains both full class-list projections and references.

### Timed callback guards and quota bypass

After quota32, the same quota case invokes original `ArcadeMode.timePassed` explicitly with arguments45,59,60,75. These are **callback fixtures**, not elapsed-time scheduling: `Game.pastTime` stays24 throughout and Date is not changed. Calls45/59 create nothing;60 creates PowProps at (1,9),(15,5);75 creates LifeProp at (5,9), NumProp at (4,1). Each eligible call invokes original `Map.createRamdonProp(2)`, while quota remains32 and vehicle budget3. The [tail event file](reference-2026-10-19/pickups/pickup-quota-boundary-01/events/tail-006221.json) retains arguments, consumed RNG and constructors; [before/after state projections](reference-2026-10-19/pickups/pickup-quota-boundary-01/summary.json) retain actual new cells. The [inspected final original capture](reference-2026-10-19/pickups/pickup-quota-boundary-01/after-time-callbacks.png) shows the original HUD and board.

This proves the callback condition and quota bypass in this original execution. It matches `seconds > 45 && seconds % 15 == 0` and Cinema count2 (`gameengine/gamemode/ArcadeMode.as:88–103`). `Map.createRamdonProp` reads `Game.mapPropArr` without consulting drop quota or vehicle budget (`maps/Map.as:73–86`), but therefore inherits the shared class-list mutation described above. Actual timed vehicle production is separately exercised by [vehicle-timed-bypass.json](../../tools/reference_player/cases/pickups/vehicle-timed-bypass.json), run `pickup-vehicle-timed-bypass-01`. It repeats initial seed1050 and uses 160 original build/break/collect cycles. The additional 60 cycles after ordinary quota exhaustion consume original box-appearance RNG; their count was selected offline from the prior observed stream, without replacing a random result or changing budgets. Before the time callback, original state records quota32, budget0, shared class-list length95 and `Game.pastTime=46`.

At frame9461, direct original `timePassed(60)` consumes position draws740/741 and class draw742=`0.9985952251590788`, selecting `floor(draw×95)=94`, the remaining Car entry. Original **CarProp is constructed at (12,13) while budget remains0 and quota remains32**. The second spawned item is BombShoesProp at (7,13), a research observation that does not authorize its excluded production slot. [Exact original calls/draws](reference-2026-10-19/pickups/pickup-vehicle-timed-bypass-01/events/tail-009461.json), [before/after summary](reference-2026-10-19/pickups/pickup-vehicle-timed-bypass-01/summary.json) and [inspected original capture](reference-2026-10-19/pickups/pickup-vehicle-timed-bypass-01/after-time-callbacks.png) are retained. This proves actual timed quota/vehicle bypass in the controlled original callback; it does not claim the session naturally elapsed to60 at that frame.

### Natural clock reaches the first timed spawn

[timed-natural.json](../../tools/reference_player/cases/pickups/timed-natural.json), run `pickup-timed-natural-02`, uses original AI stop/reposition for isolation and paced stepping for the original Date-based clock. It does **not** invoke `time-passed`. `Game.pastTime` progresses from2 at frame821 to62 at2921; samples include45 and54. Original `Game.countTime → ArcadeMode.timePassed(45)` at frame2302 creates no item. The actual clock callback reaches60 at frame2818 and invokes `Map.createRamdonProp(2)`. Position draws437/438 are followed by class draws439/440, constructing SpeedProps at (5,9),(12,9); these new cells persist in the final focused graph. [Exact frame2818 events](reference-2026-10-19/pickups/pickup-timed-natural-02/events/f002818.json), [clock summary](reference-2026-10-19/pickups/pickup-timed-natural-02/summary.json) and [inspected original capture](reference-2026-10-19/pickups/pickup-timed-natural-02/after-paced-clock.png) are retained.

The code first chooses up to two eligible distinct floor cells, then draws each class (`maps/Map.as:131–167,73–86`). Captured calls and constructor cells support that order here; the entire candidate-cell enumeration was not separately projected. The clock is original `Date.seconds` polling (`gameengine/Game.as:796–816`), so no universal detonation or spawn frame is inferred from this paced recording.

## Remaining recovery work

Source-weight distribution is recovered data, not statistically certified by these selected samples. No false Normal-scope `canEated` return was observed among the 14 tested types; capped and AI-life no-op acquisitions were consumed instead.

Pickup destruction by later blasts, every cap/eligibility combination across modes, natural AI item seeking/use and retry-life settlement require further cases. Existing [runtime systems](edition-5-runtime-systems.md) separates those source facts from conversions. No four unresolved item slots are filled, no Godot behavior is changed, and no original artwork is introduced into gameplay.

Most runs used unpaced stepping; the natural-clock case explicitly enables paced stepping. Compact observation and event logging still consume host time, and original `Date`, `getTimer`, timers and TweenMax depend on clocks beyond the frame counter. The report establishes captured state/call/draw sequences in this emulator execution, not native Flash equivalence, game-feel durations or release readiness. Original PNGs listed above were opened and inspected; manifest/command hashes permit checking which exact recordings support each observation.
