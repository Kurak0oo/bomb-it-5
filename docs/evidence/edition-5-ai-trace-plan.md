# Edition 5 Normal AI: observation paths and trace plan

Prepared 2026-10-19 for recovery tickets [#34](https://github.com/Kurak0oo/bomb-it-5/issues/34) and [#35](https://github.com/Kurak0oo/bomb-it-5/issues/35). This is a primary-source investigation and proposed execution protocol, **not completion evidence for those tickets**. No live player, reference bridge, authority SWF, Godot gameplay or tracker state was changed for this report.

## Authority and evidence levels

Authority is the publisher edition5 v1.6.1 SWF, SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`; see [provenance](edition-5-input-and-timing.md). ActionScript locators below are relative to `.scratch/edition-5-research/publisher-scripts/scripts/zlong/bombit5/`, unless marked XML/P-code. [Structural reconstruction](edition-5-structure-reconstruction.md) records the broader execution graph and freshly corroborated P-code findings.

Evidence labels used here:

- **Static:** inspected decompile or P-code from the authority SWF. This establishes code/data, not complete measured execution.
- **Observed:** a value read from the parent's saved reference graphs. This investigator did not execute those sessions; snapshot interpretation is independently repeated here.
- **Inferred:** an explanation connecting source and snapshots; a transient callback sequence is not directly observed by one post-step graph.
- **Unverified:** a proposed case or instrumentation capability requiring execution and comparison.

The saved reference player uses pinned Ruffle `45366370ed7d1a59c89aa3cf7b765c7a274407cd`. [Trace design](edition-5-reference-trace-design.md) and the [player README](../../tools/reference_player/README.md) define its bridge and limitations. Graphs are after a frame **and timer advancement**, do not execute getters, and identify objects by process-local pointers. Ruffle findings are emulator observations, not an established native Flash comparison.

## What the existing graphs already expose

Inspected `.scratch/edition-5-research/reference-runs/cinema-observed-01/opening-board.json`: SHA-256 `113a5e9b1f9821f8ea1c10e8e5038f42abff7a48f2df5a346112f28ac34483d6`,6204 objects, `truncated=false`. The [run manifest](reference-2026-10-19/cinema-observed-01/manifest.json) records opening frame721, then moved731, bomb732, explosion804 and after-fire824. Raw graphs stay in investigation storage. These are sparse observations from a real session, not isolated AI experiments.

Use `ReferenceGraph` in [inspect_reference_trace.py](../../tools/inspect_reference_trace.py) to follow raw references and reject truncation/ambiguous namespace aliases. Its existing `summary()` does not project AI state; the underlying graph already contains it. There is no need to invoke original getters merely to locate it.

Semantic path definitions: locate the sole `zlong.bombit5.gameengine::Game` object as `G`; `E=G.gameEngine`; for each `G.aiPlayers[i]`, let `P` be the player, `R=P._robot`, `M=R.model`, `C=P.fsmAIController`, `S=C.machine`, `A=C.action`. Arrays are observed references, not inline JSON lists. Resolve each reference through `objects`.

| Semantic path | Raw contents available now | Source locator |
| --- | --- | --- |
| `P.aiID`, `P._uiId`, `P._robotID` | Profile and useful within-session actor key; all observed AI names are null, so names are unsuitable keys | `gameengine/AIPlayer.as:13–24,66–69`; `Game.as:406–414` |
| `C._time`, `_lastTime`, `aiAnswerTime`, `findRange` | Cached gate accumulator, last `getTimer`, configured threshold and range | `gameengine/ai/AIControl.as:62–84,141–157` |
| `S.states`, `_defaultState`, `_currentState`, `_goldState`, `nextState`, `stateRepeat` | Ordered state references and identity-dependent selection | `gameengine/ai/AIEngine.as:38–90`; `AIFactory.as:62–74` |
| State `actionComplete`, `_settings`, `targetedPosition`, `aimBox` | Completion gate, probabilities, selected action destination and attacked target | `ai/state/AbstractState.as:22–48`; `AbstractAttackState.as:162–260` |
| Attack state `_addBombPos`, `_escapePosArr`, `_escapePos`, `_bombDownHandler`, `weaponObj`, `weaponRange`, `shootDistance`, `timeoutID` | Planting cell, planned escape, actual escape, ordinary/weapon action dispatch and pending timeout ID | `ai/state/AbstractAttackState.as:25–43,67–89,322–457`; `StateAttack.as:30–141`; `StateBox.as:30–138` |
| `C.bombArr`, `dangerArr`, `dangerArrAttack`, `freeArr`, `boxArr`, `otherRobotArr`, `propArr`, `weaponArr`, `vehicleArr` | Perception arrays; nested cell records include bomb/fire timing where applicable | `ai/AIControl.as:160–396` |
| `A._stepArray`, `_step`, `_direct`, `aimX`, `aimY`, `_endX`, `_endY`, `nextStep`, `orientaCount` | Stored route and per-step progression; may outlive the action that created them | `ai/Action.as:61–171` |
| `A._arriveCallback`, `_stepCallback`, `_cancelCallback`; `R._aiMoveArr` | Callback method plus receiver and whether route-following callbacks remain registered | `ai/Action.as:61–75,144–204`; `robot/AIRobot.as:34–51` |
| `C.pathFinder` and `G.map.nodes[x][y]` | Search working fields and shared cell cost/block/parent data | `ai/astar/RoadSearch.as:49–105,108–243`; `Node.as:6–26` |
| `E._aiSequenceArr`, `aiIndex`, `aiSequenceLength`; `_engineArr`, `_moveArr` | Current bound receivers, roster order and brain versus route/movement registries | `gameengine/GameEngine.as:150–165,230–301` |
| `R.controller._bombHandler`, `_bombHandler_up`, `_funcDelay`, `_stageFunc`; `M` counters/state; `R.view._container` display | Actual equipped-action callback, interruptions, physical/logical position and ammunition/capacity | `robot/RobotController.as:141–165,197–279,292–327`; `AbstractWeapon.as:65–101` |

Paths abbreviated `ai/` and `robot/` in the table live beneath `gameengine/`. Match both class and slot namespace when necessary; inherited protected aliases can repeat one slot, while differing values with the same simple name must remain ambiguous. Do not bake the following addresses into replay tooling.

Opening-snapshot examples:

| Player UI ID / robot ID | AIControl reference | Current state | Cached gate / last time | Logical cell / bomb count |
| --- | --- | --- | --- | --- |
| 1 /5 | `0x14a4f9b2290` | StateBox, incomplete |1228 /1294 |(14,1) /0 |
| 2 /3 | `0x14a4f9b8eb0` | StateBox, incomplete |1232 /1297 |(2,13) /1 |
| 3 /4 | `0x14a4f9bce70` | StateBox, incomplete |1234 /1292 |(14,13) /1 |

All have profile`010201`, threshold20,range6. All observed state lists are Attack, Evade, GetItem, Box, Free, Escape. Each default Free state is a **different object** from the Free entry in `states`. For player1, listed Free is `0x14a4f9b5f30`, default Free is `0x14a4f9b6890`. These are observed structural confirmations of XML/factory behavior, not observations of every transition.

Across the five sparse captures, each `_time` stays1228/1232/1234 respectively while `_lastTime` increases; by frame804 the states are Free/GetItem/Free, and by824 Free/GetItem/Box. At731 players2/3 have registered path callbacks while brain count remains3. This supports live AI activity and the cached accumulator finding, but does not determine every-frame cadence, RNG choices or intervening transitions.

### Two traps for a projector

**A stored path can be stale.** Opening player1 has current Box destination[14,1], attacked box[13,1], candidate escape[[15,2]], no `_aiMoveArr` callback, yet `A._arriveCallback` still points to Free.onComplete and the stored path is[[15,1],[14,1]]. Static `Action.setAction` calls `TweenMax.delayedCall(0.1,param3)` for an already-reached destination and does not replace stored action callbacks/path in that branch (`Action.as:61–75`). That supplies a plausible explanation, not direct evidence that a specific delayed callback ran. Project both current state and registered/pending action identities; never infer active routing solely from `_stepArray`.

**A perception array can be consumed by selection.** `AbstractState.getBestPosition` removes randomized candidate elements using `param1.splice` (`AbstractState.as:152–216`). Free/Evade commonly pass `controller.freeArr` directly. A post-step array can therefore reflect selection mutation, not the fresh full perception set. Observe immediately after `updatePerceptions` and before state selection when exact sensor reconstruction matters.

## Static decision rules the traces must discriminate

Normal Arcade XML chooses AI profile`010201`; its state order is Attack → Evade → GetItem → Box → Free → Escape; default Free is constructed separately. Normal probabilities include attack0.6,evade/get-item/free0.8,box0.7; weapon attack delay150ms. Locators: embedded XML242–247,319–330 and matching action definitions in [runtime data](edition-5-runtime-data.json); `AIFactory.as:23–100`.

`AIEngine.update` does not reconsider transitions while current `actionComplete=false`. When available, first passing transition wins; same-instance selection twice resets to default. `AbstractState.onStep` shares one random draw between dodge and attack checks. Action timers use2000ms, attack delay uses `setTimeout`, and route/current-cell callbacks can use TweenMax. Exact callback entry, `getTimer`, timer advancement and host pacing are separate measurements (`AIEngine.as:38–90`; `AbstractState.as:52–78,109–145`; `AbstractAttackState.as:322–350,419–438`).

`AIControl.update` only updates `_time` in its false branch; once greater than threshold, the successful branch updates `_lastTime` without resetting `_time`. Fresh authority P-code confirms this (`structure-audit-pcode/.../AIControl.pcode:374–427`). Do not redesign it into a repeating20ms throttle while recovering original behavior. The saved graphs corroborate unchanged cached values after threshold, but exact rotating opportunity timing still needs dense traces.

Perception scans square rings, writes shared search node costs for bomb rays, records fire separately and excludes dangers from free positions. Ray-continuation flags are initialized outside the per-bomb loop, and upward danger entries additionally check remaining time`<30` (`AIControl.as:189–291,371–395`). Escape-feasibility searches use four neighbors and reject existing danger coordinates without checking their remaining-time threshold (`StateBox.as:112–215`; `StateAttack.as:114–141,155–229`). Distinguish these predicates instead of assuming one common safety calculation.

`RoadSearch` checks neighbors Up/Down/Left/Right, respects directional platform restrictions, uses `costMultiplier` in estimated ranking and chooses the first strictly smallest remaining estimate. Its returned cost sums node estimates, with same-cell special cost−2 (`RoadSearch.as:76–105,131–215,231–242`). `getBestPosition` performs randomized destructive candidate selection and may stop as soon as cost<100. Pickup filtering samples with replacement, at most candidate-count attempts, accepting a path cost<100 (`StateGetItem.as:31–53`). These are not ordinary shortest-distance or uniformly best-target policies.

Attack-position selection examines target array order and candidate directions Right/Left/Up/Down, distances `shootDistance..weaponRange`, accepts cost<500, preserves a strictly better candidate and immediately prefers current-cell cost−2. Targets with a neighboring bomb can be skipped (`AbstractAttackState.as:162–260,288–319`). Ordinary attacks plant down/up then wait300ms before escape; weapon attacks wait configured150ms, turn toward `aimBox`, then down/up and complete the state. The destination must still qualify when `turnAndAttack` is reached (`AbstractAttackState.as:322–390,394–457`). Actual equipped callbacks determine effect; do not assume every weapon triggers an ordinary bomb.

## Proposed scenarios for #34

Each case needs a fresh reference session or an explicitly recorded original-method fixture. Record SWF/player/observer hashes, original and fixture board occupancy, frame/input chronology, paced versus unpaced stepping, host monotonic time, observed `getTimer` values, and random calls. Prefer legal gameplay; label fixture teleports/pickup construction separately. Existing human-only fixture operations do **not** establish AI repositioning/equipping capability.

| Case | Concrete setup and observations | Acceptance discriminator |
| --- | --- | --- |
| AI-N01: startup/cadence | Capture12 consecutive active frames immediately after start, before human input, then another12 after the first threshold. Track each AI's `_time/_lastTime`, state identities and all bound brain receivers, plus `E.aiIndex` before/after each frame | Identify selected opportunities versus actual state updates; confirm cached threshold behavior. Run paced and unpaced variants; snapshots alone cannot establish multiple transient method entries |
| AI-N02: routes independent of brains | Select a naturally occurring multi-cell Free or Box route; trace every frame from selection through arrival. Record route callbacks, orientation margin positions, physical x/y, logical cell, requested movement and AI receiver rotation | Physical/path progression must be explainable on frames when that AI's brain is not selected. A stored route without registered orienta is not ongoing navigation |
| AI-N03: attack/evade priority | Put a legal human bomb so a reachable AI is simultaneously threatened and has an attack opportunity; capture state checks and each consumed gate draw, including current `actionComplete` | Distinguish Attack-first pass, failed Attack followed by Evade, and incomplete-action early return. Surviving or dying does not identify which branch ran |
| AI-N04: danger asymmetry | Compare one ordinary bomb with a blocker on each ray, then two bombs scanned in different orders; include an upward target at remaining29/30/31 callbacks. Snapshot raw grid, bombs and node multipliers before/after perception | Explain upward threshold and ray flags carried across bombs. Record actual board scan order; do not manufacture symmetric danger output |
| AI-N05: pickup/free target ranking | With two reachable ordinary allowed pickups and different route costs, record fresh perception, each random candidate index, path cost and chosen target. Repeat with one blocked/unreachable candidate and no pickups | Distinguish randomized first acceptable candidate from global minimum, replacement sampling and Free fallback. Record pre-selection arrays because selection mutates them |
| AI-N06: evade/escape distinction | Threaten an AI with a ticking bomb, then separately with a human carrying invincibility. Record Evade/Free/Escape check order, invincible actor cells and candidate distance filters | Explain when Escape is reached after preceding states and how Manhattan≤4 exclusion differs from imminent bomb danger |
| AI-N07: cancellation and recovery | During an active route, introduce a legal bomb into its next/current step and trace onStep cancel. Separately capture a naturally blocked orientation callback beyond10 attempts, and the2000ms state timer | Attribute completion to actual arrival, cancellation, lack of progress or timer. More than10 checks and2000ms are different thresholds; don't force them to one tick duration |
| AI-N08: active rotation | Follow an AI entering a portal, firing a movement-locking weapon, and dying; capture registry receiver list and `aiIndex` at boundaries, then recovery where applicable | Show removal/reinsertion order, rotating population and route-callback lifecycle. Post-index implies next candidate only when list mutation is accounted for |

## Proposed scenarios for #35

Complete weapon lifecycle prerequisites before interpreting AI execution failures as AI decision bugs. Human/AI share controller dispatch; route/movement remains cardinal in the original. The accepted Godot eight-direction capability is a separate adaptation, not a demand that this reference choose diagonal paths.

| Case | Concrete setup and trace | Decision explanation required |
| --- | --- | --- |
| AI-C01: safe ordinary block attack | Reuse the observed opening Box opportunities (player1 [14,1]→box[13,1], escape[15,2]; other corners differ). Start before placement, capture `_escapePosArr`, destination, callback entry, down/up, capacity/occupancy and300ms escape retry | Explain candidate safety, actual placement success, delay origin and eventual escape route; source-feasible escape does not guarantee survival |
| AI-C02: unsafe/failed opportunity | Compare an otherwise similar attack with no reachable cell outside proposed blast, then a target adjacent to an existing bomb; also record capacity exhausted and occupied placement failure | Identify which guard rejected opportunity and whether delivered input occurred. An absent bomb alone cannot distinguish no decision from failed placement |
| AI-C03: opportunistic path-step attack | Human crosses same row/column within weapon range while AI routes elsewhere; include a blocker and a shared-cell encounter | Trace shared onStep RNG, `stepAttack`, `turnAntHit`, route stop and subsequent dispatch, rather than attributing action exclusively to current state's update |
| AI-C04: each selected weapon | Let AI collect mine/hammer/flamer/laser/triple/fireball through original eligibility/collection. For each, record `weaponObj`, range/shotDistance, attack-position candidates, target validity,150ms delayed turn, down/up and current equipped handler | Explain weapon-specific range and effect, movement/brain interruption, uses and recovery; mine's handler remains a weapon action, not generic ordinary placement |
| AI-C05: target changes during delay | Human leaves the targeted cell or a bomb occupies it between route arrival and delayed attack; trace `turnAndAttack` checks separately from later `delayAttack` | Establish which validity checks happen before scheduling versus on firing. Do not infer revalidation merely because the target moved |
| AI-C06: completion/teardown | During delayed attack or escape, pause, kill actor or end round using original pathways. Observe timeout/tween registration, command disposal, active brain/movement callbacks and any later delivered action | Explain normal cancellation and any late callback with actual chronological evidence; leave unverified disposal interactions open |

AI-C04 currently requires a validated AI-targeted fixture or naturally captured acquisition. The compiled fixture described in the trace-design record targets the human and cannot be relabeled as an AI pickup test. Any added operation must retain original constructors, `canEated`, collection and controller logic, record actor selection and reject dead/busy actors; direct `model.weapon` or private actionComplete writes would bypass the behavior under investigation.

## Observation gaps and minimum instrumentation

Post-step graphs already establish stored state, identities, callbacks, path arrays and grid data. They cannot reveal every state considered, rejected gate, transient pathfinding result, synchronous down/up, or exact RNG draw. Instrument **consumed** values at original call sites; never call `Math.random` again to observe it. A per-process random ordinal with caller identity and returned number, plus frame/phase/method entry and source-actor key, is the minimum explanation record. Fresh authority P-code or narrow pinned-runtime hooks can support it, but neither capability is claimed implemented here.

Needed event points are `AIControl.update` gate/entry and perception completion; `AIEngine` current-action guard and each `checkTransitions` result; state gate RNG/target selection; `RoadSearch.findPath` request/result cost/path; `Action` arrival/cancel/orientation; original bomb down/up; original timeout/tween registration/invocation; brain add/remove. Protect interpreter evaluation order: logging must not repeat getters, enumerate game dictionaries through new cursors, recalculate routes or execute state methods. Observe calls' existing primitive values and receiver identities.

Validate an instrumented copy against the untouched observer session for board, inputs, bomb/movement timing and screenshots. Dense full graphs/logging consume host time and can change the source's `getTimer`, `Date`, timers and TweenMax behavior even without game writes. Record observation duration and distinguish fast frame stepping from paced play. A sparse observation is not adequate proof that observer overhead has no effect.

Retain arrays exactly (including duplicates/order), nonfinite values and nulls. Search nodes are shared and reset repeatedly, so a post-frame node graph can describe the most recent search, not necessarily the path followed by that particular AI. Path costs/results need observation at return to attribute them correctly. Timer IDs alone do not establish pending/expired status. Pointer identity is valid only within one process; correlate actors through session/player UI ID/robot ID rather than replaying addresses.

The unrelated252-object allocation in `StateAttack.escapeRouteAnalysis` is bytecode-confirmed source filler, not an AI gameplay requirement. Exclude reproducing it from port requirements while keeping its possible observation/performance impact unmeasured. No overall fidelity percentage or ticket completion follows from these plans or the five sparse snapshots.
