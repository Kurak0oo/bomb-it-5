# Edition 5 reference tracing and fixture-control investigation

Current combined capabilities, later runtime validations and historical provenance corrections are in the [recovery tooling record](edition-5-recovery-tooling.md). Earlier sections below describe their named build boundaries.

Investigation on 2026-10-19 for the reverse-engineering-first work. This record separates tested bytecode instrumentation from a compiled runtime observer and separately compiled active fixtures. The parent has since captured a live observer graph; fixture execution remains to be checked. Neither changes the production Godot game. Follow the [structural audit](edition-5-structure-reconstruction.md) and [runtime gaps](edition-5-reverse-engineering-audit.md) for the behavior these facilities need to establish.

## Authority and primary sources

The untouched publisher SWF is `.scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf`, SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`. The [provenance record](edition-5-input-and-timing.md) owns its acquisition/build identity. This investigation rehashed it after all experiments and obtained the same digest.

Tooling sources inspected directly:

- JPEXS Free Flash Decompiler 26.3.0, the existing local distribution. Its own `-help -replace`, `-help -importScript`, and Java library API inspected with `javap` are the authority for the commands below; the project is [JPEXS/FFDec](https://github.com/jindrapetrik/jpexs-decompiler).
- Pinned Ruffle commit `45366370ed7d1a59c89aa3cf7b765c7a274407cd`, now available locally as `.scratch/edition-5-research/ruffle-runtime`. All Ruffle source links below pin that revision rather than following master.
- The publisher's decompiled `Game`, `GameEngine`, `Main`, `UIManager`, `AbstractRobot`, `RobotView` and `AbstractObject`. Locators below use the existing `publisher-scripts/scripts` export. Decompiled source remains reconstructed source; method-body injection was checked against fresh P-code from the SWF itself.

## Tested: a single-method trace injection without recompiling the game

JPEXS `-replace` accepts an **AS3 code-only `.pcode` file and a method-body index**. A complete decompiled class, a whole class P-code export, and a method-info index are not required for this route. This avoids recompiling a decompiled class and its dependencies.

The isolated experiment lives under `.scratch/edition-5-research/trace-design/`. It used these commands from the repository root:

```powershell
java -jar .scratch/edition-5-research/ffdec/ffdec.jar -selectclass zlong.bombit5.gameengine.GameEngine,zlong.bombit5.bombs.Bomb -format script:pcode -export script .scratch/edition-5-research/trace-design/original .scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf
```

The method body was located through the installed Java API, not guessed from the exported order:

```java
SWF swf = new SWF(new FileInputStream(args[0]), false);
for (var tag : swf.getAbcList()) {
    var abc = tag.getABC();
    System.out.println(abc.findMethodBodyByName(
        "zlong.bombit5.gameengine.GameEngine", "enterFrameHandle"));
}
```

Compiled/run in Java's source-file mode with the local `ffdec/lib/*` classpath, this reported `-1`, `-1`, `3846` for ABC blocks 0, 1, 2. The helper is retained as `trace-design/LocateBody.java`.

The original callback's code was extracted between its `code` and `end ; code` directives. Immediately after its existing `getlocal0; pushscope`, this stack-balanced sequence was inserted:

```text
findpropstrict QName(PackageNamespace(""),"trace")
pushstring "B5TRACE|phase|enterFrameHandle"
callpropvoid QName(PackageNamespace(""),"trace"), 1
```

The inserted sequence needs stack depth two; the existing method's maximum is three. The original labels and remaining instructions were retained, and the assembler recalculated byte offsets. This marker is **callback entry before the pause guard**, not evidence that gameplay phases executed.

```powershell
java -jar .scratch/edition-5-research/ffdec/ffdec.jar -replace .scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf .scratch/edition-5-research/trace-design/phase-traced.swf zlong.bombit5.gameengine.GameEngine .scratch/edition-5-research/trace-design/phase-code.pcode 3846
java -jar .scratch/edition-5-research/ffdec/ffdec.jar -selectclass zlong.bombit5.gameengine.GameEngine -format script:pcode -export script .scratch/edition-5-research/trace-design/patched .scratch/edition-5-research/trace-design/phase-traced.swf
```

Both commands completed successfully. The fresh export contains the marker at callback entry. The instrumented copy has SHA-256 `252de57c92ee72e86f912cbc6f684abf256fb9c066e6e4dcd391ccd42b2971f8`. A separate Java comparison of `getCodeBytes()` for every body in all three ABC blocks reports **7,141 bodies compared, one changed: ABC 2/body 3846**. The helper is `trace-design/CompareBodies.java`.

This comparison establishes the scope of code-byte changes, not binary identity of every SWF tag or constant pool: the marker necessarily introduces constants. The original file was not overwritten. No runtime execution of the patched copy has been established by this experiment, so a fresh P-code marker is not a captured runtime event.

`-importScript <infile> <outfile> <scriptsfolder>` is available, but was only inspected in the tool's help. Bulk source/P-code import was not tested and is unnecessary for the demonstrated one-body route. There is no need to invent a `-replaceCLI` switch: this distribution exposes `-replace`.

## Untouched-SWF observation: what Ruffle exposes and what it does not

The existing supplied probe protocol calls `run_frame`, advances emulator timers, and delivers input. It does not expose arbitrary AVM2 objects. The public [`Player::mutate_with_update_context`](https://github.com/ruffle-rs/ruffle/blob/45366370ed7d1a59c89aa3cf7b765c7a274407cd/core/src/player.rs#L2297) allows an internal observation operation, but [`core/src/lib.rs`](https://github.com/ruffle-rs/ruffle/blob/45366370ed7d1a59c89aa3cf7b765c7a274407cd/core/src/lib.rs#L17) keeps the `avm2` module private. An external probe cannot simply import `Activation`, `TObject` and private AVM2 machinery as if these were a stable public API.

The game also has **no `Game.instance` singleton**. `Main.instance` exists, but `Main.init` constructs `UIManager` without retaining it in a field. `UIManager.game` is public, yet the manager itself is not added to the display list by its constructor. Resolving the `Game` class through the application domain yields a class definition, not a current session object. Source locators: `Main.as:14–52`; `zlong/bombit5/ui/UIManager.as:20,56–77`; `gameengine/Game.as:40–133`.

A concrete alternative is reachable through existing callbacks:

1. Ruffle records broadcast listeners independently of display-list attachment. `GameEngine.start` registers its `ENTER_FRAME` listener; the engine itself need not be attached as a visible child. See [`Avm2::register_broadcast_listener` and broadcast storage](https://github.com/ruffle-rs/ruffle/blob/45366370ed7d1a59c89aa3cf7b765c7a274407cd/core/src/avm2.rs#L365), and original `GameEngine.start`.
2. `Game.gameStartHandler` installs `this.countTime` into `gameEngine._tweenArr` before starting normal gameplay. Source locator: `gameengine/Game.as:494–499`.
3. That entry is a bound function. Ruffle's [`FunctionObject::executable`](https://github.com/ruffle-rs/ruffle/blob/45366370ed7d1a59c89aa3cf7b765c7a274407cd/core/src/avm2/object/function_object.rs#L150) exposes a `BoundMethod`; its [`bound_receiver`](https://github.com/ruffle-rs/ruffle/blob/45366370ed7d1a59c89aa3cf7b765c7a274407cd/core/src/avm2/function.rs#L31) is the `Game` object. Access to that private field needs a narrow internal accessor.
4. `Game.robots`, `players`, `map`, `gameEngine`, `modeController` and the other session fields are raw slots. Following those fields reaches models/views, equipment, command dictionaries, AI state and grid data.

This path is source-derived and implemented in the observer below. The parent subsequently reports a live capture containing 6,204 objects without truncation from the built observer; interpreting individual scenario fields remains separate work. The final observer caches discovered `Game` objects as weak references to continue observing a still-live session after its engine callbacks are cleared. It does not keep that session alive or resurrect it after garbage collection; results after session disposal can therefore still require a different observation root.

## Compiled: bounded read-only runtime graph bridge

The reproducible [reference-observer.patch](../../tools/reference_player/reference-observer.patch) applies to the pinned Ruffle source. After the parent established a playable baseline with its saved original-core binary, this investigation applied the observer to the local checkout and compiled it. It adds:

- `Player.reference_state(max_depth, max_objects) -> serde_json::Value`, so the probe receives owned JSON rather than GC-lifetime-bound game objects.
- An internal AVM2 graph reader that finds `GameEngine` broadcast objects and follows raw slots, dynamic properties, array elements and bound-function receivers.
- A read-only `BoundMethod` receiver accessor. No interpreter phase, game bytecode, RNG implementation, callback array, or production Godot interface is changed.
- An observer-owned weak `Game` cache inside AVM2. This changes observer metadata, not game fields or strong reachability. Weak entries are pruned after their target is collected.

The reader records class names, namespaces and slot IDs, function names and receivers, native display x/y and MovieClip current frames, display children, cycles/references, and explicit depth/object/array truncation. Generic fields are retained rather than guessing a game-specific schema. This supports discovering the exact runtime layouts before publishing stable bomb/actor/AI event fields.

The observation strategy is copied from Ruffle's own [`debug_ui/avm2.rs`](https://github.com/ruffle-rs/ruffle/blob/45366370ed7d1a59c89aa3cf7b765c7a274407cd/core/src/debug_ui/avm2.rs#L260): inspect `vtable().resolved_traits()`, then read `Property::Slot`/`ConstSlot` via `get_slot`. The bridge **does not execute Virtual getters or methods**, invoke `toString`, use an ActionScript object enumerator, or coerce an object through game code. Direct [`DynamicMap::iter`](https://github.com/ruffle-rs/ruffle/blob/45366370ed7d1a59c89aa3cf7b765c7a274407cd/core/src/avm2/dynamic_map.rs#L79) avoids changing Flash enumeration cursors, unlike using the native `next` mechanism. Private/protected namespaces are retained instead of inventing their numeric identities or collapsing identically named traits.

Apply-check was successful against the local Windows checkout with CRLF-aware matching:

```powershell
git -C .scratch/edition-5-research/ruffle-runtime apply --check --ignore-space-change ../trace-design/reference-observer.patch
```

`cargo check -p probe --features reference-state` completed successfully with no warnings/errors on the locally installed Rust 1.97.0 toolchain. The resulting lockfile is retained with the reference-player tools. The final patch also passes reverse apply-check against the changed checkout. `reference_trace.rs` and the initial patch generator remain in ignored investigation storage; the tracked patch is the final source of the observer implementation, including the later weak cache. The parent later built and captured the graph described above; this investigator did not independently run that capture. The probe call, after an explicit `run_frame`/timer boundary, is:

```rust
let state = player.lock().unwrap().reference_state(12, 10000);
serde_json::to_writer(&mut trace_file, &state)?;
```

That snippet requires the bridge; it is not available in stock Ruffle. Pointer-based object references are process-local identities, not replay-stable IDs. Graph depth/size limits can omit fields; consumers must reject a truncated result for scenarios requiring those omitted fields. A snapshot after stepping cannot reveal transient intermediate callback phases; those need selected entry/exit hooks or the separately identified P-code instrumented copy.

## Fixture control and remaining validation

Read-only observations should be established before control mutations. Calling original placement, movement, item acquisition and disposal functions preserves substantially more state than overwriting a visual coordinate or `model` field independently. Original setters may update occupancy, listeners, commands, animation and equipment together; direct raw field writes bypass those effects. This investigation has not implemented or verified a fixture mutation API and does not claim a position/weapon/AI fixture already works.

The next checks for the bridge are: compile the patch; run an untouched original menu-to-Normal-Cinema session; prove it finds the live `Game`; record selected primitive actor/bomb/map fields through a legal placement; and compare the same input/screenshot sequence with observation disabled. Host observation cost can still affect original `Date`, `Timer`, timeout and Tween behavior even if no game method is called. Repeated deterministic scenarios and runtime provenance are needed before trusting those timing measurements.

## Follow-up: control-screen startup and storage/logging prerequisites

Source investigation after the independently built baseline reached menus but did not advance past the controls screen identifies a specific **path-dependent hypothesis**, not a missing default storage backend:

- [`PlayerBuilder::build`](https://github.com/ruffle-rs/ruffle/blob/45366370ed7d1a59c89aa3cf7b765c7a274407cd/core/src/player.rs#L3058) defaults to `MemoryStorageBackend`. Its [`put`](https://github.com/ruffle-rs/ruffle/blob/45366370ed7d1a59c89aa3cf7b765c7a274407cd/core/src/backend/storage.rs#L36) returns true. The pinned source does not use a default null-storage implementation, so merely adding `with_storage` is not a supported fix for this symptom.
- `UIManager.gamePlay` temporarily constructs `HowToPlayUI`, calls `saveKeys`, and destroys it **before** constructing the loading screen and `Game`. Source locator: `zlong/bombit5/ui/UIManager.as:315–325`. An uncaught error in that temporary construction leaves the control screen visible and prevents creating the game.
- `HowToPlayUI.initData` calls `SharedObject.getLocal(GameConfig.GAME_NAME)` without `localPath`, then immediately reads `.data["key"]`. `saveKeys` repeats that call and writes the key array before flushing/closing. Source locators: `HowToPlayUI.as:304–336,483–508`; `GameConfig.as:60` supplies safe name `Bomb_It_5`.
- Ruffle [`SharedObject::get_local`](https://github.com/ruffle-rs/ruffle/blob/45366370ed7d1a59c89aa3cf7b765c7a274407cd/core/src/avm2/globals/flash/net/shared_object.rs#L149) rejects any computed path component starting with a dot, returning `null`. Therefore a SWF URL containing this repository's **`.scratch`** directory fails that default-path call, even though its filename and SharedObject name are valid. `.data` then has no receiver. Earlier `Cookie.init` can work because `SharedObjectUtil.getLocal` explicitly supplies localPath `/`, excluding the `.scratch` segment.
- [`movie_from_path`](https://github.com/ruffle-rs/ruffle/blob/45366370ed7d1a59c89aa3cf7b765c7a274407cd/core/src/tag_utils.rs#L103) canonicalizes the disk path and uses it as the SWF URL. Its second argument is `loader_url`, so changing only that argument does not replace the root movie URL.

The minimally invasive test is to copy the **same hashed bytes** to an investigation directory whose complete canonical path has no dot-prefixed component, then run the unchanged harness there. The parent subsequently reports successful Cinema startup with this byte-identical temporary copy and its saved original-core binary, corroborating this failure explanation; the reference driver now uses that strategy. This investigator did not independently run that session. Alternatively, constructing `SwfMovieData::from_data` with an explicit recorded safe movie URL changes the runtime URL context without changing bytes. Both options change URL/SharedObject scope and must be included in provenance.

For diagnostic output, `PlayerBuilder.with_log` installs a `LogBackend` with `avm_trace` and `avm_warning`; a stderr/file implementation is straightforward. However, [`Avm2::uncaught_error`](https://github.com/ruffle-rs/ruffle/blob/45366370ed7d1a59c89aa3cf7b765c7a274407cd/core/src/avm2.rs#L682) always reports to `tracing::error!`; it additionally sends a string to `avm_trace` only in debug player mode. Initialize a tracing subscriber to retain release-mode errors. Switching to debug mode is unnecessary merely to obtain that diagnostic and can itself change error-stringification behavior.

## Source-preserving fixture routes identified, not yet executed

Once the observer finds the live `Game`, fixture commands can use existing original constructors and public methods from inside a separate runtime bridge. This is **active fixture instrumentation**, distinct from the read-only observer and from naturally achieved unmodified play. It must log its exact command, boundary and pre/post state.

| Scenario | Concrete original route | Why raw-field replacement would be incomplete |
| --- | --- | --- |
| Ordinary bomb | Deliver the configured key via the existing probe, or explicitly call `robot.controller.addBomb()` as a fixture operation | `addBomb` checks capacity and `map.isEmpty`, constructs `Bomb`, appends `model.bombArr`, increments capacity usage; constructing a bomb alone omits owner bookkeeping |
| Weapon pickup | Resolve e.g. `zlong.bombit5.items.weapons.HammerProp`, construct it with `(game, x, y)` at a verified suitable cell, then let normal `GetItemCommand.execute` collect it | `AbstractItem.init` installs map/display state; collection calls eligibility, `changeStage`, `eatProp`, score and sound. Writing `model.weapon` alone installs neither weapon commands nor key callbacks |
| Weapon activation | After natural collection, deliver ordinary key down/up and step frames | `AbstractWeapon.changeStage` installs original `bombDown`/`bombUp`; activation creates the original animation and temporary command and disables/restores control through its normal path |
| Repositioning | Prefer legal input; if a controlled relocation is required, use view `xPos`/`yPos` setters followed by `robot.updateRobotPosition` at a declared boundary | `currentX/currentY` setters only change cached model cells. `updateRobotPosition` updates map occupancy and executes position-change commands, which can themselves cause fire damage/portal effects |
| Disable AI decisions | Call the specific `AIControl.stop()`/`start()` functions if a scenario explicitly requires frozen decisions | These remove/reinsert the original rotating brain callback; they do not necessarily stop existing route following. Clearing the engine array indiscriminately would erase other lifecycle behavior |

Primary locators: `gameengine/robot/RobotController.as:154–166`; `items/AbstractItem.as:34–54,143–146,182–192,223–237`; `commands/robot/GetItemCommand.as:31–48`; `items/weapons/AbstractWeapon.as:82–101,112–152`; `gameengine/robot/AbstractRobot.as:167–190,381–388`; `AbstractObject.as:66–84`; `gameengine/ai/AIControl.as:123–130`.

The pinned Ruffle mechanisms for such a bridge are `Activation::from_domain`, `Domain::get_defined_value_handling_vector`, `ClassObject::construct`, and `Value::call_public_property`. These execute original class initialization/constructor/method code and therefore belong to explicit fixture operations, never to supposedly passive observations. Implement an allowlist of concrete fixture operations rather than arbitrary evaluation, and validate the map cell and actor before mutation. This investigation has compiled those operations below but has not executed them yet.

### Optional fixture bridge compiled separately

The separately applicable [reference-fixtures.patch](../../tools/reference_player/reference-fixtures.patch) adds `Player.reference_fixture(&str) -> Result<serde_json::Value, String>`. It depends on the read-only observer patch and a preceding snapshot that discovered a live session. After the parent's observer capture, it was applied to the local core checkout and **`cargo check --offline --locked -p probe --features reference-state` passed without warnings/errors**. Reverse apply-check passes. Runtime fixture execution remains unverified. No probe, production Godot, authority SWF, Cargo manifest or lockfile was changed by this fixture preparation/compile check.

The command is strict JSON with one of these forms:

```json
{"op":"pickup","kind":"hammer"}
{"op":"reposition","x":1,"y":1}
{"op":"bomb"}
```

Pickup kinds are an explicit class allowlist: hammer, flamer, laser, triple, fireball, landmine; capacity, power, speed, life, shield, invincibility; car and moto. These map to the recovered selected-scope original classes. No arbitrary class name, function, expression, model/health/score/outcome write or unresolved item is accepted. The original constructor is invoked at the live human's current logical cell only if original `Map.isEmpty` succeeds and no pickup is already present. Equipment is **not** assigned directly: normal subsequent `GetItemCommand` performs eligibility and collection. A failed natural eligibility check remains visible as an uncollected pickup; successful construction alone is not reported as successful equipping.

Repositioning checks original `Map.isEmpty`, rejects existing pickups and other actors' overlapping cell-width footprints, reads original `GameConfig.GRID_WIDTH`, uses original view `xPos`/`yPos` setters, calls **`AbstractRobot.updateRobotPosition`** (not a controller method), and restores the display row through `RobotView.resetMainContainer`. This is fixture teleportation to a clear destination, not proof of collision-safe travel along the intervening route. It does not clear held input or velocity. Target fire is allowed and recorded because original position-change commands can immediately damage or kill the actor. Portals are rejected by `isEmpty`; that operation cannot be used to force an actor through a portal lifecycle.

Bomb creation calls original `RobotController.addBomb`, retaining its capacity/cell checks and owner bookkeeping. It explicitly bypasses the equipped action callback, so that fixture is not equivalent to pressing Space while holding another weapon. Prefer the normal key protocol when input dispatch itself is under investigation.

The bridge rejects a missing/finished session, a human absent from `Game.robots` or whose model state is `dead`, or an actor whose controller has an active movement/action interruption. The initial fixture guard incorrectly required `isExist`; the parent's live graph revealed that this rejects a protected but living human. The guard was corrected, and offline locked compilation passes again. Original `AbstractRobot.init` sets `isExist = false` while registering the robot, and `InvincibilityCommand.execute` eventually restores it; `kill`/`fall` instead unregister the robot and set `model.state = RobotState.DEAD`. Thus `isExist` is damage/contact eligibility, **not a general alive flag**. Source locators: `AbstractRobot.as:84–105,221–241,270–282`; `commands/robot/InvincibilityCommand.as:40–76`. The value remains recorded in fixture output under its literal source name, without treating it as liveness.

All fourteen allowlisted fully qualified pickup class names were checked against the existing publisher decompile; all are present. Successful calls return the requested command, primitive before/after actor state and explicit side-effect notes. Rejected syntactic/guard checks perform no intended fixture mutation; errors from an original constructor or method can occur after partial original side effects and are **not transactionally rolled back**. Run controlled fixtures in fresh replay sessions and retain both command logs and snapshots. Compilation and runtime acceptance remain separate gates.

### Compact observation option compiled for long traces

The parent measured a full 6,204-object snapshot at roughly 4.3 MB and 0.25 seconds per frame; continuously saving these snapshots makes the original Date-based round clock expire after far fewer game frames. This is an observation-cost effect on a wall-clock-driven original, not grounds to rewrite its clock or claim its simulation normally runs that slowly.

The separate [reference-compact.patch](../../tools/reference_player/reference-compact.patch) prepares `Player.reference_compact_state(max_depth, max_objects)` while retaining the full `reference_state` API and its original graph schema. In compact mode only, native display objects become leaf summaries of class, x/y and current MovieClip frame. Painting traits/dynamic child references/display-list traversal are omitted. `GameEngine` is explicitly exempt from that leaf rule because its logical callback registries live on a Sprite subclass. Logical source objects, map grids, AI/state/search objects, weapons/commands, arrays/dictionaries and bound-function receivers retain their ordinary raw graph traversal. Directly referenced `_mc` timelines still have their frame number; unreferenced nested painting timelines do not appear.

The compact patch was applied and `cargo check --offline --locked -p probe --features reference-state` passed without warnings/errors. The complete patch order **observer → fixtures → events → compact** was independently apply-checked and applied in an isolated minimal Git tree populated from the pinned checkout's `HEAD`; all eight resulting source files matched the live checkout after newline normalization. The event/RNG patch is maintained separately by its investigating agent; this check establishes integration order, not validation of its runtime claims.

The built all-feature reference executable was then independently exercised by this investigator. Its SHA-256 is `152899b9661c60091ef5399af4279431259ad369253ce041787fb4481f70e0d1`. The untouched authority bytes were verified and copied to a fresh non-dot temporary directory; the recorded Normal Arcade/Cinema input case was played through opening-board frame **721**. Three pairs of `state FILE` and `compact FILE` commands were issued **without advancing another frame**. The commands include graph traversal, JSON serialization and synchronous disk output in their measured acknowledgement latency.

| Observation | Full graph | Compact graph |
| --- | --- | --- |
| Objects at this boundary | 6,000 | 4,341 |
| Saved JSON bytes | 4,194,387–4,196,574 | 2,806,443 |
| Three command latencies | 344, 329, 328 ms | 234, 234, 250 ms |
| Median | 329 ms | 234 ms |
| Truncated | No | No |

All **3,885 retained logical nodes** matched the full snapshot on class, slots, dynamic entries, array elements/lengths, function names and receiver references. All **456 native display leaves** matched on class and their retained x/y/current-frame fields. Pointer IDs established same-process identity; discovery depth and root ordering are intentionally not compared because the weak session cache and omitted display traversal change the route by which an object is reached. This comparison verifies retained data at one boundary, not every future gameplay scenario or native Flash equivalence.

The reproducible investigation driver is `trace-design/check_compact.py`; the run is retained as `.scratch/edition-5-research/trace-design/compact-benchmark-01/` with commands, logs, six raw graphs and `comparison.json`. It was invoked as:

```powershell
python .scratch/edition-5-research/trace-design/check_compact.py --player .scratch/edition-5-research/reference-player-instrumented/probe.exe --output .scratch/edition-5-research/trace-design/compact-benchmark-01
```

This is a useful reduction but **does not solve the cost of per-frame long traces**. The compact graph still spends most of its representation on logical Box/Grid/AI Node state and associated geometry arrays: in this run, 193 Box instances occupy approximately 828 KB, 255 Grids 711 KB, 255 search Nodes 322 KB, and 200 HitMove instances 211 KB when re-encoded for this size inspection. These are not merely native painting children. Some inherited protected traits alias the same slot ID, duplicating representation; future deduplication must preserve the namespace/slot relationship rather than conflating distinct slots.

Use focused callback/event logs for every-frame sequences, with compact graphs sampled at declared boundaries or every several frames. A smaller source-aware per-cell/actor projection would need its own field-coverage checks before substituting for the raw logical graph. Compact mode is suitable for logical state tracing rather than per-painted-frame bounds reconstruction; full observation remains available for visual/timeline investigations. Neither mode changes the original clock, and three paired local samples are not a device-performance guarantee.

### Purpose-built focused projection compiled

The additional [reference-focus.patch](../../tools/reference_player/reference-focus.patch) introduces `Player.reference_focus_state()` and the separate `bombit5-reference-focus-v1` schema. It is not another generic graph walk. It reads a previously observed weak `Game` and explicitly projects game/mode/player/robot/model/controller/view/equipment data, command chains, AI controllers/state machines/states/settings/actions/search working state, engine callback registries, all map cells, cell block/cost search flags, and active bomb objects discovered through cell arrays or original callback receivers. Native display references carry x/y/current-frame summaries. Arbitrary referenced Box/HitMove/display/node-parent graphs are not traversed.

Each projected source record contains `id`, `class` and raw values indexed by **physical slot ID**. One shared `layouts[class]` entry maps those IDs to all local-name/namespace aliases and lists genuinely ambiguous local names. Inherited aliases of the same physical slot cause one read and one value, without discarding the alias evidence. Slot layout formatting is cached only within that snapshot; no strong session roots or cross-frame game-state cache are introduced. Raw arrays preserve order, holes, IDs and nested values with explicit length/depth bounds. Original command dictionaries are read through native storage iterators, not AVM2 enumeration cursors.

The API never calls original getters/methods, changes the source clock, draws random numbers or writes game fields. It intentionally does not inspect pending timer/tween queues, painted bounds, arbitrary dynamic object graphs or every shared search-node parent. Each search working object is the stored result of whichever original search last touched it, not automatically attributable to an AI's currently followed path; see the [AI trace plan](edition-5-ai-trace-plan.md). Full/compact observation and focused execution events remain separate supporting evidence.

This fifth patch follows **observer → fixtures → events → compact → focus**. The five-patch chain was apply-checked/applied in a fresh minimal tree built from the pinned `HEAD`; all nine resulting source files matched the live checkout. `cargo check --offline --locked -p probe --all-features` passes without warnings/errors.

The parent built and preserved `.scratch/edition-5-research/reference-player-focused/probe.exe`, SHA-256 `9325accaea56e401b14133842e0a23c77a0e0b2dc96ec31b0423b4cddf0f4168`. This investigator then ran the isolated `trace-design/check_focus.py` against it, using another verified byte-identical safe temporary SWF copy and the recorded Normal Arcade/Cinema opening through frame721. Three pairs of full/focused observations were taken without intervening steps.

| Same-boundary observation | Full graph | Focused projection |
| --- | --- | --- |
| Saved JSON | 4,163,621–4,165,808 bytes | 339,783 bytes |
| Size/count | 5,966 objects | 397 record emissions, 379 distinct recorded objects |
| Three command latencies | 312,312,312 ms | 15,16,31 ms |
| Median latency | 312 ms | 16 ms |
| Truncation | No | No |

All projected physical-slot values and the complete per-class slot/namespace alias layouts matched the full snapshot: **379 unique records**, **10,161 recursive value checks**, **781 array occurrences**, **57 function occurrences**, **45 native display occurrences**, and all **255 map cells / 255 cell block-cost entries**. Array and reference checks include ID/class identity, numeric storage order/holes, function/receiver identities, native x/y/frame fields and Point coordinates. Counts of occurrences/checks are not counts of unique arrays/functions/displays. These checks establish retained raw data at this one opening boundary, not complete selected-scope parity or every later object's coverage.

The measured local median is approximately **19.5 times lower**, with acknowledgement latency including projection, serialization and synchronous file output. One focused sample took31ms, so the three samples do not prove every trace frame stays below the nominal35Hz budget. The focused projection is substantially more practical for per-frame logical bomb/AI/death traces than the full/compact graphs; pair it with original execution/RNG events and declared host/frame timing. Source wall-clock behavior can still be affected by observer cost.

Artifacts remain under `.scratch/edition-5-research/trace-design/focus-benchmark-01/`: six snapshots, command/stderr logs and `comparison.json`. Reproduction:

```powershell
python .scratch/edition-5-research/trace-design/check_focus.py --player .scratch/edition-5-research/reference-player-focused/probe.exe --output .scratch/edition-5-research/trace-design/focus-benchmark-01
```

The focused v1 intentionally omits named dynamic properties on Array references (for example directional weapon attachment-offset entries), unexpanded `Game.endCartoon` internals, native painting children/bounds, Box/HitMove internals, shared search-node parent graphs and pending timer/tween queues. Equipment class/use counts, actor view `_mc` frames, action/path arrays, command dictionaries, callback identities and bomb counters/blast-cell arrays are projected. Full or compact observations at selected boundaries remain necessary for animation attachment/geometry, result-cartoon internals and arbitrary omitted objects. The probe's `focus` helper may bootstrap a full observation when no weak session has been discovered; that expensive bootstrap is explicitly marked `bootstrap_full_graph=true` and must not be mistaken for steady-state focused timing.

Where an intermediate phase cannot be observed through a post-step snapshot, the tested one-body P-code route can add a marker plus relevant primitive values immediately before/after a selected callback. Every such SWF must have its own hash and recorded patch. Instrumented-copy findings remain distinct from untouched-reference playback and from native Flash observations. No new native Flash comparison, complete animation-bound evaluator, RNG replay, controlled weapon fixture, or complete reverse-engineering acceptance is claimed by this report.

### Native Class references for drop-pool inspection

The separate [reference-class-names.patch](../../tools/reference_player/reference-class-names.patch), applied after the existing observer/fixtures/events/compact/focus/actors/geometry/drops/session-state chain, adds `defined_class` to focused reference metadata whenever the referenced object is a native AVM2 `ClassObject`. This distinguishes entries such as CarProp and MotoCycleProp in the original ordered `MapMaster.propArr` and `Game.mapPropArr`; their existing instance class is merely `Class` and cannot identify the constructor represented by the array entry.

Primary pinned source: `core/src/avm2/object/class_object.rs:762–793` defines `inner_class_definition()` and `name()`, the latter returning the class definition's QName. The focused `reference()` helper uses `Object.as_class_object()` and that native `name().to_qualified_name_no_mc()` path. It invokes no AS getter, constructor or method, does not enumerate AS properties, and writes no game/array fields. Non-Class references retain their existing metadata. Physical array order and original duplicate entries remain intact; the observer does not normalize the weighted pool.

The patch was applied to the live research checkout, reverse-apply checked, and compiled with `cargo +stable check --offline --locked -p probe --features reference-fixtures,reference-events,reference-compact,reference-focus` (success, 7.74 seconds). Runtime pool-class verification awaits the parent-owned next preserved build; compile success alone does not establish a particular pool index or splice outcome. The existing recovery executable remains unchanged.

A controlled random-input queue was investigated for the rare vehicle-budget branch, but no interception has been implemented: the pickup investigator reported an actual seed-1050 execution reaching four vehicle creations, zero remaining vehicle budget, and a subsequent naturally drawn ride selection suppressed by the original code. Actual random-draw evidence is preferable for that acceptance case. `maps/Box.as:createProp` (185–222) contains the quota gate, probability draw, weighted-pool index draw, vehicle budget branch, and original for-each/splice mutation. Exact draw/index/pool claims belong to the pickup runtime record, not to this compile-only metadata addition. There are no controlled RNG inputs, additive budget setters or new source-game exceptions in this patch.
