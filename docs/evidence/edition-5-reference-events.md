# Original method and random-draw observation

Current combined capabilities, later runtime validations and historical provenance corrections are in the [recovery tooling record](edition-5-recovery-tooling.md). Earlier sections below describe their named build boundaries.

The optional [event collector patch](../../tools/reference_player/reference-events.patch) observes the original AS3 execution inside the pinned Ruffle player. It does not change the publisher SWF. It is research instrumentation, separate from Godot gameplay and from the explicit original-method fixtures described in [reference trace design](edition-5-reference-trace-design.md).

## Authority and status

- Publisher SWF: `.scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf`, SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`.
- Player source: Ruffle commit `45366370ed7d1a59c89aa3cf7b765c7a274407cd`, local checkout `.scratch/edition-5-research/ruffle-runtime`.
- The patch was prepared against that checkout with the reference graph observer and fixture bridge already present. Apply the reference graph/fixture patches first, then `git apply --check --ignore-space-change <reference-events.patch>` and apply the event patch. The graph observer supplies the context anchors; these patches are not independent upstream features.
- Preparation on 2026-10-19 passed `git apply --check`; after application, `cargo check --locked -p probe --features reference-fixtures` passed in 12.47 seconds. The first runtime seed probe exposed a bootstrap guard error, corrected below; the all-feature locked check then passed in 7.09 seconds. The subsequent original-session probes verify event collection and RNG output, but **do not establish equivalent whole-session playback with observation enabled**.

## What the hook covers

Ruffle's [`core/src/avm2/function.rs`](https://github.com/ruffle-rs/ruffle/blob/45366370ed7d1a59c89aa3cf7b765c7a274407cd/core/src/avm2/function.rs), `BoundMethod::exec` and free `exec`, dispatch bound function calls. [`value.rs`](https://github.com/ruffle-rs/ruffle/blob/45366370ed7d1a59c89aa3cf7b765c7a274407cd/core/src/avm2/value.rs), `call_method_with_args`, also calls the free `exec` directly for methods that do not need an arguments object. The patch wraps this common entry and retains its entire previous implementation in `exec_reference_inner`. Return values and `Error` values pass through unchanged, including the original implementation's early returns during verification or argument coercion.

Every selected call records an `enter`, followed by `return` or `error`, with a monotonic sequence and call ID, selected-call parent/depth, method display name and ABC method index, receiver reference, at most eight supplied arguments, and the returned or thrown value. The arguments are observed **before** the original coercion/default-argument logic. Error rendering never calls AS3 `toString`; an AVM-thrown value is summarized directly and an internal Rust error receives a marker.

Selection accepts at most 32 prefixes, each at most 256 bytes. A call matches its method display name or receiver's class name. The default is `zlong.bombit5`; narrow prefixes reduce capture cost. This can include inherited native calls on a game-class receiver. It records calls which the original game actually makes, including getter calls; the observer never invokes additional getters.

Relevant original-source locators are `gameengine/GameEngine.as:enterFrameHandle` and its add/remove methods; `bombs/Bomb.as:bombEngine`, `blast`, `ended`, `deleFire`; `maps/Map.as:addBomb`, `deleBomb`, `moveBomb`, `setFire`; `gameengine/robot/AbstractRobot.as:robotEngine`, `updateRobotPosition`, `kill`; and `gameengine/ai/{AIControl,AIEngine,Action}.as`, `ai/state/*.as`, `ai/astar/RoadSearch.as`. Method traces can establish the order of callbacks and synchronous mutations reached through these methods. They do not directly label inline phase boundaries or assignments which make no method call. Correlate object references with the separate graph snapshots for slot state and animation frames.

## Random draws and deterministic setup

[`activation.rs`](https://github.com/ruffle-rs/ruffle/blob/45366370ed7d1a59c89aa3cf7b765c7a274407cd/core/src/avm2/activation.rs), `op_call_native`, bypasses free `exec` for optimized native fast calls. [`optimizer/type_aware.rs`](https://github.com/ruffle-rs/ruffle/blob/45366370ed7d1a59c89aa3cf7b765c7a274407cd/core/src/avm2/optimizer/type_aware.rs), `maybe_optimize_static_call`, explains that path. Consequently method events are not a complete VM/native-call trace.

The patch separately observes [`globals/math.rs`](https://github.com/ruffle-rs/ruffle/blob/45366370ed7d1a59c89aa3cf7b765c7a274407cd/core/src/avm2/globals/math.rs), `random`, immediately after its **existing single** RNG draw and division. Each enabled RNG event includes the original raw integer, exact returned `f64`, Math.random draw ordinal and currently selected call chain. No additional draw or substitute result is introduced. The ordinal counts AVM2 `Math.random` calls, including calls while collection is disabled; it does not count other users of the shared RNG or AVM1 random functions.

Optional `Player::reference_rng_seed(seed)` is an explicit fixture, not unseeded original playback. The core API rejects zero and a generator already initialized; the harness additionally rejects `seed` after its first `step`. It calls the same original `AvmRng::init_with_seed`; the LFSR/hasher algorithm and subsequent draws in [`avm_rng.rs`](https://github.com/ruffle-rs/ruffle/blob/45366370ed7d1a59c89aa3cf7b765c7a274407cd/core/src/avm_rng.rs) remain unchanged. The seed is recorded in drained output. A fixed seed does not itself prove repeatability: dictionary enumeration, host time, input ordering and unrelated generator users still require measurement.

The first executed seed probe used player SHA-256 `152899b9661c60091ef5399af4279431259ad369253ce041787fb4481f70e0d1` and failed at harness frame zero with `seed must be set before the first run_frame`. Raw logs are in `.scratch/edition-5-research/reference-runs/events-validation-01/off/`. The erroneous core guard used `Player.current_frame`, which is already populated when the builder installs the root movie; it is a timeline playhead, not a count of executed frames. Removing that guard preserves the RNG-unused validation and the harness's actual step counter boundary. This is a failed instrumentation probe, not a game observation.

## Public research API and capture bounds

`Player::reference_events_enable(enabled, capacity, prefixes)` defaults to disabled and clears the previous buffer when reconfigured. `reference_events_mark(frame, label)` labels the following events; labels are supplied by the harness, not recovered SWF clocks. `reference_events_drain()` returns owned JSON with schema `bombit5-reference-events-v1`, events, draw count, seed, capacity, limits and explicit overflow counters. Configuration and marking require an outer command boundary. Drain after each frame or short input command.

The collector stores no `Object`, `Value`, `Gc` or weak GC roots. Primitive data is copied; objects are class names and process-local pointer strings. Dense/sparse array storage is read directly, capped at 16 elements and two levels. Strings are capped at 1,024 UTF-16 units, arguments at eight, selected stack metadata at 256 calls. No dictionary enumeration cursor, property lookup or AS3 conversion is invoked. Event count is clamped to 1–200,000, with a separate 32 MiB cap on serialized event payload. Every discarded event increments `dropped`; sequence gaps and stack truncation are explicit. Overflow invalidates any claim of a complete order for that capture interval.

Pointer identities can be reused after collection and are not stable across runs. The event list owns JSON only; it does not keep original objects alive to make IDs convenient. A Rust panic or process abort does not produce a normal exit event. Instrumentation allocates and costs host time, so it can affect execution timeouts or wall-clock-dependent game code even without original-state writes. Compare seeded collector-off/on snapshots and screenshots before accepting trace-derived outcomes, then repeat relevant unseeded legal-input cases. That comparison and the scenario-specific recovery tickets remain necessary.

## Executed original-session checks

The corrected player is preserved at `.scratch/edition-5-research/reference-player-seeded/probe.exe`, SHA-256 `b558d22562613586ae4ba74858ee7048ff5c91e544cda3a2daea23b30cf42609`; `build.json` beside it records tools and installed patch hashes. The event patch used here has SHA-256 `82a2fd7c45ffb573a85ca7a441c1b777f5672a699cd8b85365c1319a73cf45dc`.

Raw evidence is `.scratch/edition-5-research/reference-runs/events-validation-02/`. `off/`, `on/` and `off-repeat/` each contain acknowledged input logs, stderr, a case, manifest, 12 screenshots and matching compact graph snapshots. Both comparison modes use the exact original SWF and initial seed 12345; no actor, board, weapon or outcome fixture is invoked. They follow the existing Normal Arcade/Cinema entry, movement, Space placement and escape protocol. The comparable interval ends at harness frame 824. The ON run then advances one additional frame for the deliberately overflowing capture.

To reproduce, copy `tools/reference_player/cases/normal-arcade.json`, prepend `seed 12345`, and run it through `tools/replay_reference.py --observe --compact` with the corrected all-feature player. For ON, additionally prepend `events events 200000 zlong.bombit5.gameengine::GameEngine zlong.bombit5.bombs::Bomb zlong.bombit5.maps::Map` after the seed. Append `events off`, `events on 1`, `step 1`, `events-dump overflow.json`, `events off` after the last checkpoint to test overflow. For OFF, append `events-dump disabled.json`. Use fresh output directories; the replay driver stages a byte-identical SWF outside dot-prefixed paths to avoid the original SharedObject URL rejection. The exact executed cases are `off-case.json` and `on-case.json` in the raw evidence directory.

Observed collector checks:

| Check | Result |
| --- | --- |
| Selected original method events | 169,726 entries and 169,726 returns; no observed method errors |
| Ordering and nesting | Strictly increasing sequence; balanced call IDs across all 825 event files; no unclosed or mismatched selected calls |
| Normal capture limits | Zero discarded events and zero selected-stack overflows |
| Actual Math.random events | 1,149 consecutive draw ordinals; every result equals its captured raw integer divided by 2,147,483,648 |
| Independent algorithm cross-check | First six raw draws are 81,666,754; 1,538,388,318; 922,769,477; 1,491,069,488; 474,929,855; 2,121,471,306, matching a separate integer transcription of the pinned algorithm with seed 12345 |
| Disabled collector | Empty events, `enabled=false`; the separately counted Math.random calls and explicit seed remain reported |
| Capacity-one overflow | Exactly one retained event, `overflow=true`, 7,469 explicitly discarded events |

`assessment.json` records these checks. This verifies the exercised return path, original method correlation, seeding and RNG hook; it does not exercise every error path, array limit or byte-budget limit.

Evidence SHA-256 values: `assessment.json` is `0036c79a4a46c377573d42638d2a4e66aa6d98fbe50a0926a01ffd092a5c8c94`; `baseline-repeat-comparison.json` is `367460b204281c835bea1f97a694e8ab96e311fa3c7f38c61006316d2f050384`; `bomb-callback-summary.json` is `ab1ca4552028ee082847d12e121dbc3f4debb58faa1cb8201ca8dd0207e1efec`. The per-frame event JSON totals 83,738,852 bytes. Host elapsed time to the final command was 3,018 ms OFF, 8,013 ms ON and 3,470 ms for the OFF repeat; these timings include captures and snapshots as well as gameplay.

### Equivalence check did not pass

OFF and ON screenshots are byte-identical through the first eight checkpoints, including the opening board. The four later screenshots (`moved`, `bomb`, `explosion`, `after-fire`) differ. The compact graphs contain the same 4,363 nodes at the opening checkpoint, but their primitive node multisets differ. In particular, `Game.pastSecond` is 38 versus 42; `AIControl._time`/`_lastTime` and timer IDs also differ. The primitive comparison deliberately removes pointer identity and does not prove graph isomorphism; even that weaker comparison fails.

A second **collector-OFF** replay with the same seed matches the first OFF run's first ten screenshots, including `moved` and `bomb`, but differs at `explosion` and `after-fire`. Therefore seed-only baseline playback itself is not fully repeatable. OFF/ON divergence cannot be attributed solely to the collector. The source independently explains two relevant clocks: `gameengine/Game.as:countTime` reads `new Date().getSeconds()`, and `gameengine/ai/AIControl.as:update` reads `getTimer()`. The latter leaves `_time` over its threshold after warmup, so differing numeric timestamps alone do not prove differing decision cadence. Dictionary ordering and timer registration also remain uncontrolled. Do not replace this failed comparison with an assertion of observer neutrality or exact full AI parity. The per-run traces remain useful observations of the instrumented original under their recorded conditions.

### Callback mutation observed in legal play

The ON trace supplies a concrete corroboration of synchronous callback-array mutation. The first four bombs that complete each receive **72 `bombEngine` calls and 17 `ended` calls**, but those calls do not always occupy consecutive frames:

| Bomb owner / creation frame | Countdown call frames | `blast` frame | `ended` frames / `deleFire` frame |
| --- | --- | --- | --- |
| AI / 713 | 714–785, consecutive | 785 | 785–801, consecutive / 801 |
| AI / 715 | 716–788, skipping 785 | 788 | 788–805, skipping 801 / 805 |
| AI / 717 | 718–790, skipping 788 | 790 | 790–807, skipping 805 / 807 |
| Human / 731 | 732–804, skipping 790 | 804 | 804–821, skipping 807 / 821 |

For the first bomb, `ended` runs in the detonation frame and cleanup follows 16 frame intervals later. Later bombs lose a callback in the frame an earlier entry removes itself, so a fixed wall-duration inferred from a single bomb would be wrong for this run. This is consistent with `GameEngine.as:enterFrameHandle`, `Bomb.as:takeCount`, `blast`, `ended` and `deleFire`; `bomb-callback-summary.json` preserves object references, owner classes and frame lists. It corroborates the mutation concern from the [structural reconstruction](edition-5-structure-reconstruction.md), without claiming every chain/overlap permutation is verified.

## Indexed actor fixtures and AI control

The separate [actor fixture patch](../../tools/reference_player/reference-actors.patch) applies after observer → fixtures → events → compact → focus. It changes only `core/src/avm2/reference_fixtures.rs`; the read-only Focus projection remains intact. Its SHA-256 is `c2396e1c92a952ee0731bc99b64e2d99dbb9ae1b4d6fd541804e93f6c58f4bcf`. The applied patch passed `cargo check --locked -p probe --features reference-fixtures,reference-events,reference-compact,reference-focus` in 6.95 seconds. Runtime scenarios below verify indexed and protected actors.

`pickup` and `reposition` accept an optional integer `actor` from 0 through 3. This is an index into the **current original `Game.players` array**, not a robot ID, character appearance or synthetic actor. Resolution reads that player's protected `_robot` slot, then verifies the same object belongs to `Game.robots` and has a non-dead string `model.state`. An absent index, null robot, unregistered/dead actor, fractional/negative/out-of-range index or unknown field rejects the fixture. Existing commands without `actor` continue selecting the registered original `PersonRobot`. The ordinary direct-bomb operation's JSON remains unchanged and has no actor override.

Original ownership locators are `gameengine/Game.as:addRobot` (player-array construction), `AbstractPlayer.as:addRobot`/`createRobot` (`_robot` ownership), `robot/AbstractRobot.as:registRobot`/`unRegistRobot`, and `data/RobotState.as:DEAD`. `isExist` is **damage eligibility**, not liveness: protection and vehicle states can make it false while a registered living robot still exists. The fixture therefore reports it but does not reject on that value. The original interrupted-action `_stageFunc` guard remains in place. Results add selected player index, robot class/reference, model state and registration before/after; any hazard damage caused by original reposition callbacks remains an observed side effect.

Examples:

```json
{"op":"pickup","kind":"shield","actor":1}
{"op":"reposition","x":1,"y":1,"actor":1}
{"op":"ai-control","actor":1,"mode":"stop"}
{"op":"ai-control","actor":1,"mode":"start"}
```

The narrowly scoped `ai-control` operation requires a selected registered `AIRobot`. Stop calls original `AIControl.stop()`, then `Action.stop()`, then `AbstractRobot.robotStop()`. Start calls original `AbstractRobot.robotStart()` and `AIControl.start()`. These are deliberate target-control fixtures; they are not evidence that the original UI offers per-enemy pause.

The three responsibilities are distinct in the original source:

- `AIPlayer.as:fsmAIController` owns `AIControl`. `AIControl.as:start`/`stop` add/remove its `update` function from the GameEngine AI callback list through `AIRobot.addAiFunc`/`deleAiFunc`. Those operations leave the actor's normal engine, movement registration and map occupancy registered.
- `Action.as:stop` removes its current `orienta` route-following callback and dispatches a current-direction `KEY_UP`. It does not invoke the cancel callback or restore an earlier route. Delivering this before listener removal lets `AIInteractiveController.stopHandle` call `InteractiveController.moveStop`, remove the held direction and select the original decelerating movement function.
- `AbstractRobot.as:robotStop` calls the AI interactive controller's `stop`. `AIInteractiveController.as:stop` removes movement and bomb listeners. Its paired `start` reinstalls them. This does not itself remove the AI brain callback; hence the explicit separate brain stop. `robotFrozen` would unregister the actor and is deliberately not used.

No timers or TweenMax callbacks are canceled. `AbstractAttackState.as:turnAndAttack`, `attackAndEscape`, `resetEscape` and `AbstractState.as:actionTimer` show why delayed state callbacks can remain live: they may later alter state/route metadata, register a route callback, perform a turn, or attempt a key dispatch. Removed listeners block their ordinary movement/bomb key delivery during this controlled stop, but this is not a guarantee of immutable AI metadata. Weapon recovery or another original lifecycle path may also reinstall behavior. Start enables current behavior; it is not a rewind or a restoration of an earlier route. No raw position, velocity, protection, health, score, weapon or outcome writes are introduced by `ai-control`.

### Executed indexed/protected actor checks

The original-session test used `.scratch/edition-5-research/reference-player-actors/probe.exe`, SHA-256 `eeebea71c77ac5d9fb2f10478d225b457f61d3459387862a46cde632d19812c7`. Its `build.json` records the exact patch set. Raw cases, input logs, fixture results, eight PNGs and compact snapshots are in `.scratch/edition-5-research/reference-runs/actors-validation-02/`; the comparable original match reaches frame 731. `assessment.json` SHA-256 is `b25b92c8f268fddb03827edcb223f5df2f52b20c8e6d091bb3526c756911266a`.

Observed results:

- Selected players 1, 2 and 3 resolve to three distinct original `AIRobot` objects. Stopping them changes `_aiSequenceArr` from three brain callbacks to zero while `Game.robots` remains four.
- Indexed actor 1 is repositioned to floor `(1,2)` while its `isExist` is false; it remains registered and non-dead. After three original frames its logical cell remains `(1,2)`.
- An unchanged default-human pickup command supplies Invincibility through the original constructor and next-frame GetItemCommand. The human's state becomes `Invincible`; indexed actor 0 then moves to `(2,1)` through the original fixture path, retaining `isExist=false` and registration.
- Indexed actor 1 collects HammerProp normally (`model.weapon="sinker"`), then Invincibility (`model.state="Invincible"`). Its subsequent indexed reposition to `(1,1)` succeeds while damage eligibility is false. The fixture does not assign either protection or weapon state directly.
- Starting actor 1 restores exactly one brain callback; all four robots remain registered. This verifies enabling the original brain, without claiming it restores an old route or guarantees immediate movement.
- Independent protocol processes reject selector values `4`, `-1`, `1.0`, `true` and `"1"` with the expected integer-range message and exit code 1 before active-game lookup.

The delayed-callback caveat is actually observed: while stopped, actor 1's `_aiMoveArr` gains a route callback after three frames; by the protected-AI checkpoint, all three stopped AI have a route callback again, while the brain registry remains empty and their logical cells remain fixed. Existing timers can therefore repopulate route metadata despite the initial `Action.stop`. `registry-summary.json` records the per-checkpoint counts. The earlier `actors-validation-01` attempt is retained: repositioning actor 2 to `(2,13)` rejected because that cell was not original empty floor. The successful retry leaves actors 2 and 3 in place rather than bypassing the occupancy guard.

## Native display geometry proposal

The separate [geometry patch](../../tools/reference_player/reference-geometry.patch) extends existing Focus display values with native dimensions, bounds and matrices. Its SHA-256 is `9e65ca113cc29529089fba8904e738cf2a0d86f8a19c2d826b8de9479c658c72`. It applies after Focus; application and the all-feature locked check passed in 6.83 seconds. Runtime flamer scenarios remain pending. It adds no renderer or SWF script. It traverses at most 512 render-list descendants with depth/ancestor limits of 64 before reading recursive bounds; limit failures explicitly return `truncated=true`.

The pinned player's `core/src/display_object.rs:TDisplayObject.width`/`height` are exactly `local_bounds(BoundsMode::Script).width/height.to_pixels()`. `avm2/globals/flash/display/display_object.rs:get_width`/`get_height` use those same native methods. `bounds(Script)` gives untransformed child-inclusive bounds, `local_bounds(Script)` gives parent-space bounds, and `world_bounds(Script)` gives stage-space bounds. The proposal uses **Script bounds only**. In `display_object/morph_shape.rs:self_bounds`, Engine bounds call `get_frame`, which can populate the interpolated-frame cache; Script bounds directly read the start-shape metadata and match the original AS3 dimension access. `base().matrix()` and `local_to_global_matrix()` expose native affine transforms with translation converted from twips to pixels. These reads do not execute AS3 getters or methods. Native scale/rotation accessors are also avoided because they update transform-decomposition caches; the raw matrices are reported without inventing a signed scale decomposition.

The original `items/weapons/FlamerProp.as:bombDown` stores the current `weaponPlay` and `_fireMc` (`fire_Play`) clips; `commands/weapon/FlamerPlayCommand.as` advances the action. `bombs/FlamerFire.as:xN`/`yN` use `firePlay.width`/`height` multiplied by `weaponPlay.scaleX`/`scaleY`, and `shootFire` can clamp those scales against a blocking box. Native script dimensions, per-frame clip identity, local/stage transforms and bounds therefore supply the missing geometry evidence through the original player. This proposal does not substitute painted-pixel dimensions or a new rectangle simulation for those reads. Exact signed AS3 scale semantics, blocker cases, four facings and target-hit boundaries still require scenario-specific observation.
