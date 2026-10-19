# Original weapon action sequences and control recovery

The original actions combine input handlers, animation thresholds, live command dictionaries, per-frame projectile callbacks and wall-clock Tween callbacks. They cannot all be represented by one generic weapon cooldown. Twenty-four first-action surveys establish cardinal-facing sequences; separate interaction/lifecycle runs exercise targets, second-use exhaustion, replacement and pause. This report owns the action/source interpretation; [target interactions](edition-5-weapon-interaction-probes.md) and their [summary](reference-2026-10-19/weapon-interactions/summary.json) own the tested target permutations. Landmines have their own [complete lifecycle report](edition-5-landmine-probes.md).

## Authority, records and scope

All runs use the original publisher SWF SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`, with pinned Ruffle `45366370ed7d1a59c89aa3cf7b765c7a274407cd` and each manifest's research-patch build identity. The original four-direction first-action runs use the verified actors player SHA-256 `eeebea71c77ac5d9fb2f10478d225b457f61d3459387862a46cde632d19812c7`. Their cases, acknowledged protocols, screenshots and original native action summaries are retained under [weapon-survey](reference-2026-10-19/weapon-survey/). Lifecycle builds are v4 (`9c1dcc316e1344e5061194ba5062abc01396145d89318ea27582058a6bb1ea3c`) and the later active-pickup v5 (`04886c020700a6e27249d9986c4179aea8b650bb1becf1c1b34303dd1bbd104c`), with exact manifests in the lifecycle bundle.

[action-sequences.json](reference-2026-10-19/weapon-survey/action-sequences.json) indexes 24 surveys and the latest completed revisions of 15 lifecycle scenarios: native per-frame action state, observed method/receiver frame sets and original AVM2 method indices, original event-file hashes, selected argument samples, event errors and command host intervals. Generate it with `tools/inspect_weapon_action_sequences.py`. It checks zero event loss/stack overflow and balanced selected calls. Grouped method data does not replace full call order. [The separate lifecycle bundle](reference-2026-10-19/weapon-lifecycle/README.md) retains exact cases, build/protocol/fixture records, native summaries, selected paired events and decisive raw packets. Source raw directories remain in ignored investigation storage. The [late laser/chain case](edition-5-chain-overlap-probes.md#late-laser-trigger-and-dictionary-mutation) retains full selected events including file-local classes omitted from the survey prefix filter.

Original source hashes and function locators are in [action-sources.json](reference-2026-10-19/weapon-survey/action-sources.json). [action-animation-counts.json](reference-2026-10-19/weapon-survey/action-animation-counts.json) independently reads DefineSprite counts from the hashed SWF, without exporting artwork. Source-like paths below are under `.scratch/edition-5-research/publisher-scripts/scripts/`.

These are original-method pickup fixtures followed by natural collection and legal human input. The initial survey AI continue ordinary play, so nearby walls/blocks and callback mutations affect trajectories. They are not an isolated empty arena, an observer-neutral global replay, or a promise of all target combinations. No Godot timing result is used as an original oracle. Physical phone testing remains deferred.

## Shared action and presentation structure

`items/weapons/AbstractWeapon.changeStage` disposes the former equipped weapon, clears its display, sets the new model/view references, and installs both down/up handlers. Common `bombDown` checks a nondead actor, stops movement/action listening, builds and positions its play clip, adds the original command, increments **one use per action**, layers it by facing and plays sound. Common `bombUp` is empty. Therefore releasing Space is not a cancel/release-to-fire mechanism for these actions. Specific laser/flamer handlers build their own gunpoint-based displays and directions. Guarding `weaponPlay==null` prevents overlapping action starts for laser, triple, fireball and flamer; ordinary input listener interruption also matters.

The ordinary weapon-hand art follows `robot.view.mc.hand` and its animation frame. `AbstractWeapon.updateWeaponDisplay` uses a different behind/front rule for gun-like weapons (`shotgun`, `lasergun`, `thrower`, `boxing`) than hammer/fireball. It retains model equipment when riding but does not attach this ordinary hand art while a ride string is set. The [vehicle report](edition-5-protection-vehicle-probes.md) separately verifies retained action binding across ride loss. Active weapon effects and held-weapon art are distinct displays.

For common active clips, initial Up/Left insert at child index zero; Down/Right append. Laser/flamer override this: Up inserts behind, every other direction appends. The layer behavior is source-proven; Focus captures do not enumerate child-list order and therefore do not independently prove every layer transition.

## Measured first-action boundaries

All 24 surveys face once, collect once and press Space at harness counter **723**. They hold their cardinal input through the action. “Recovery” below means the first post-step native snapshot with controller `_stageFunc==null`, corroborated by the original restore callback. It is a measured boundary, not a newly invented cooldown.

| Action | Original first emission/hit stage | First observed recovery | Input-to-recovery intervals |
| --- | --- | --- | --- |
| Hammer, all directions | Impact/restore at 747 | 747 | 24 |
| Laser, all directions | Laser constructed and one hit pass at 734 | 745 | 22 |
| Triple-shot, all directions | Projectiles at 724, 739, 754 | 759; Up 760 | 36; Up 37 |
| Fireball, all directions | Projectile constructed at 737 | 743 | 20 |
| Flamer, all directions | Repeated geometry/hit work from 724 through 746 | 746 | 23 |
| Landmine, all directions | Mine constructed/default restored at 724 | 724 | 1 |

The input snapshot shows immediate interruption/use consumption at 723. The first stepped snapshot can still show play frame 1: e.g. hammer 724=1, 725=2. Hammer impact uses frame **24 of 25**, laser charge threshold uses frame **11 of 12**, and fireball emission uses the **final frame 14 of 14**. Clip frames, input counters and engine callbacks are separate observations. A generic “play the whole clip, then attack” rule shifts hammer/laser behavior.

## Hammer

`HammerProp` gives two uses, range one and `sinker` art. Its active offsets (Left, Right, Up, Down) are `(10,-15)`, `(-10,-15)`, `(15,-15)`, `(0,0)`. All four source sprites have 25 frames. `HammerPlayCommand.execute` re-inserts the Up clip at index zero on `floor(totalFrames/2)`—frame 12—then waits for `currentFrame>=totalFrames-1`.

At impact it stops/removes the clip, selects the adjacent cell from the actor's **then-current facing/position**, and performs this source priority: box → bombs → pickup → slide switch. A breakable box is deleted/scored; an unbreakable box receives `hitBox`; each bomb receives original BLAST synchronously; a pickup is deleted; a slide switch turns. Independently, it snapshots actors on the wielder's own cell (excluding the wielder), then actors on the adjacent cell, checks eligibility, applies score/protection/death through the original damage chain, and restores controls. Thus its own-cell victim path is real and distinct from an adjacent ray.

On second-use exhaustion it calls `controller.initWeapon`; its command dispose clears stored weapon/robot/map references. The guarded final remove avoids dereferencing a cleared robot. The surveys restore at 747, 24 frame intervals after input, in all directions. Target conclusions are in the interaction report; source priority alone is not proof that every branch was reached in each survey.

Sources: `items/weapons/HammerProp.as`; `commands/weapon/HammerPlayCommand.as:execute`, `dispose`; `commands/robot/TryToKillCommandChain.as:execute`; `commands/AbstractCommand.as:dispose`.

## Laser

`LaserGunProp` has two uses. Down obtains its muzzle position from the equipped art's named `gunpoint`, creates the single 12-frame `lasergun_Play`, saves a cardinal unit vector, adds `LaserGunPlayCommand`, consumes one use and plays readiness sound. The charge command stops at `>=totalFrames-1` and constructs `Laser`; it then removes itself. `Laser.init` places its container at the stored gunpoint, creates `LaserPlayCommandChain` in the actor's live command dictionary and plays shoot sound.

`ShootLaserCommand.execute` walks from the actor's own cell along the stored direction. A nonblocked cell **or one containing actors** receives drawing, `hitRobotUnderPoint(...,false)` and item interaction. Otherwise the first nonempty blocking cell receives endpoint art and `hitItem`, then terminates the ray. The false self flag protects the wielder while allowing other actors sharing the cell. The actor-occupied exception means the source is more specific than “always stop at every blocking cell.” This pass can synchronously detonate ordinary bombs; the late-trigger trace proves phase order.

Shoot constructs `LaserEndCommand`, adds it, then removes/disposes itself. In the independently filtered chain run the new chain and Shoot run in the creation frame, while LaserEnd first runs the following frame. Its `continueTime>9` test performs cleanup on its eleventh callback: remove beam container, restore robot controls, remove charge clip, call `Laser.deleFire`, and exhaust equipment if needed. Source `Laser._blastArr` is initialized empty and Shoot does not populate Boolean map fire; a visible beam is not a persistent tiled flame damage loop.

In all surveys construction and the original `Laser` receiver's hit methods occur only on 734; `renewRobot/resetPlayMc/countWeapon` occur on 745. The charge clip remains stopped at frame 11 during the intervening beam display. Survey prefixes do not include the file-local global Shoot/LaserEnd classes; the chain report supplies their direct execution evidence. Do not infer a new damage pass on every visible beam frame.

Sources: `items/weapons/LaserGunProp.as:bombDown`, `renewRobot`, `resetPlayMc`, `countWeapon`, `dispose`; `commands/weapon/LaserGunPlayCommand.as:execute`; `bombs/Laser.as:init`, `deleFire`; `commands/weapon/LaserPlayCommandChain.as` and its file-local Shoot/LaserEnd classes.

## Triple-shot

The class named `TripleShootGunProp` uses model weapon string `shotgun`, two uses and speed **5 source units per projectile callback**. It overrides play creation with an **empty MovieClip**. Although four `shotgun_*_Play` symbols of eight frames exist in the SWF, this action does not use them as an eight-frame charge. `NinjialPlayCommand` removes the empty wrapper on its first execution, starts `_count=0`, and emits when `_count%15==0` until three projectiles exist: counts 0, 15, 30. Direction/delegate is selected from the actor at each emission.

The surveys observe constructors at 724/739/754 in every direction. A projectile added during the robot engine starts its bomb-phase `[shootFunc,hitReset]` callbacks on a later frame. Each `TripleShootGunBomb` uses `bullet_fire`; the facing-specific visual frame and offsets are:

| Direction | Frame | Local x/y adjustment |
| --- | --- | --- |
| Left | 3 | −15 / +5 |
| Right | 1 | +25 / +5 |
| Up | 2 | +15 / 0 |
| Down | 4 | +5 / +5 |

It fades from alpha zero through a source `TweenMax.from(...,0.2)`. It enters the owner's model bomb array, but its overridden `setMapInfo` is empty: it does not occupy the ordinary map bomb array or increment ordinary capacity. Each update moves, evaluates original collision, interacts with its current cell and damages actors there with the owner-self flag false. On collision its overridden `blast` removes projectile art, interacts with one additional cell in the travel direction and registers cleanup; it does not construct an ordinary plus-shaped `exp0` blast or create a fresh ordinary timed fuse.

Its `ended` threshold is `>10`, giving twelve callbacks when no loop-removal skip intervenes. The Right survey's first two collisions occur at 737 and 758 and their cleanup callbacks end at 748 and 769 respectively. The third projectile is still updating at the 773 end of that survey, so that window alone does not certify every projectile's final cleanup. The longer interaction cases supply further selected trajectories.

After the third emission the command schedules `TweenMax.delayedCall(0.3,robotMove)`; it does not wait for all three projectiles to hit. The callback restores movement, removes the command, and restores default equipment after the second use. Command disposal pauses an existing delayed callback. Recovery is 759 in three surveys and 760 facing Up; the frame difference is measured, not normalized away.

Sources: `items/weapons/TripleShootGunProp.as:initWeapon`, `createWeaponPlay`, `bombDown`; `commands/weapon/NinjialPlayCommand.as:execute`, `robotMove`, `dispose`; `bombs/TripleShootGunBomb.as:init`, `createMC`, `blastMode`, `setMapInfo`, `hitReset`, `blast`, `ended`.

## Fireball

The source class `ShotGunProp` uses model weapon string `fireball`, two uses and projectile speed **10 source units per callback**. Each `fireball_*_Play` is 14 frames. Active offsets (Left, Right, Up, Down) are `(-10,-2)`, `(-5,0)`, `(20,3)`, `(3,8)`. `ShotGunPlayCommand` waits for exact equality with `totalFrames`, removes the play clip, creates one `FireballBomb`, sets its cardinal movement delegate, and schedules the same 0.3-second recovery callback. Releasing Space is still the empty common up handler.

All first-action surveys emit on 737 and first observe recovered controls on 743. On the Right trajectory, the projectile continues updating after recovery and collides on **744**, confirming that player recovery is independent of projectile collision. It receives twelve cleanup callbacks, 744–755 in that run. The clip/threshold differs from hammer and laser even though the action superficially looks like another charged weapon.

`FireballBomb` uses `ninjialBomb_fire`, fades in over source 0.2 seconds, enters the model bomb array and leaves map registration empty. Each update moves, interacts with the current cell, and calls `hitRobotUnderPoint(...,hitself)`; the ordinary inherited initial `hitself` is false. On collision it removes projectile art, interacts with the next cell in its travel direction, registers `ended`, removes its bomb handler and model entry, and clears its internal callback array. Its cleanup threshold is also `>10`. It is not an ordinary stationary timed bomb or an automatically repeated plus-shaped flame hazard.

Facing-specific projectile visual frame/offset: Left `3,(0,-5)`; Right `1,(20,-5)`; Up `4,(10,-10)`; Down `2,(0,0)`. As with triple-shot, these are original drawing adjustments, not replacements for the actor's cardinal movement/collision model.

Sources: `items/weapons/ShotGunProp.as`; `commands/weapon/ShotGunPlayCommand.as:execute`, `robotMove`, `dispose`; `bombs/FireballBomb.as:createMC`, `blastMode`, `setMapInfo`, `hitReset`, `blast`, `ended`.

## Flamer boundary and separate geometry work

The flamer is not another “fire once at end of charge” action. `FlamerProp.bombDown` constructs the effect and gunpoint display immediately. Every `FlamerPlayCommand.execute` invokes `FlamerFire.shootFire` **before** testing whether the inner animation reached `totalFrames-1`. The outer `thrower_*_Play` clips have one frame; the named inner fire animation has 24. Looking only at the outer frame would wrongly conclude the animation is frozen. The first-action surveys observe geometry/hit work from 724 through 746, then restoration at 746 in all directions. Original range is three, subject to geometry and target conditions.

The interaction report owns its target outcomes and the independent native geometry comparison; the [structure extraction](reference-2026-10-19/weapon-survey/flamer-structure.json) retains root/hand/gunpoint/morph structure. This report does not replace that geometry with a new renderer or claim all visible fire pixels are a map-fire hazard.

The [laser portal supplement](edition-5-laser-portal-probes.md) adds measured empty, occupied and shielded mouth traversal, exact ray cells/first blocker, one Shoot pass, eleven End callbacks, beam removal and restored movement. Bare portals are nonblocking to laser; ordinary-bomb blocking is a different source query.

## Clock, lifecycle and limits

The original code schedules triple/fireball recovery as **0.3 seconds**, with `useFrames` default false. `com/greensock/TweenMax.delayedCall` (164), `TweenLite.updateAll` (200), and `core/TweenCore` select a root time line driven by original `getTimer()*0.001`; the separate root frame time line is selected only for useFrames. The pinned Ruffle implementation at `core/src/avm2/globals/flash/utils.rs:get_timer` (19–27) explicitly returns `Instant::now().duration_since(start_time).as_millis()`. Rendering, screenshots, JSON observers and normal host overhead therefore affect how many stepped frames pass before that callback. A nominal `0.3×35=10.5` is not the observed recovery interval and must not be rounded into a universal 10/11-tick rule.

Each command log records player cumulative wall milliseconds and host monotonic bounds. A `step 49` command has one host interval, not per-callback timestamps. First-action triple recovers five/six frames after its third emission, and fireball six frames after emission in these runs; the paced lifecycle cases and paused observations are separately indexed in action-sequences. `realtime 1` adds pacing to an already costly capture workload, rather than removing original host-clock overhead.

Original pause has its own **100-ms delayed entry** (`Game.gamePause→doGamePause`). Actual native paused state must be observed instead of equating the P key counter with pause completion. A first paused post-step sample may still contain engine callbacks earlier in that frame, before timer processing applied pause; the flag does not classify the whole frame. Once active, `Game.doGamePause` stops the game engine, hides the game display and calls each robot's pause logic; `RobotView.robotPause` stops attached movies, and resume chooses which movies to play based on interruption state. These operations are distinct from the global Tween clock.

The initial five pause lifecycle cases request P just after the first action frame. Actual paused native frames are **728–785** in those five recordings. Hammer recovers on 804; laser on 802; flamer on 794; triple emits at 724/796/811 and recovers on 816; fireball emits on 794 and recovers on 798. The source therefore preserves animation/emission progression across pause instead of consuming the missing engine callbacks. These cases alone do not exercise a pending 0.3-second recovery during pause: triple has emitted only its first projectile when paused; fireball has not emitted yet.

The paced no-pause lifecycle observations are triple emission 724/739/754 → recovery 759, and fireball emission 737 → recovery **741**. The latter differs from the first survey's recovery 743 despite the same animation emission counter. The recorded host duration for the stepped 49-frame action window is about 3.219 seconds for triple and 4.234 seconds for fireball, with additional command/rendering overhead outside that one interval. These are measured host bounds; they are not a per-callback clock calibration.

An additional paced `lifecycle-fireball-recovery-pause-01` deliberately pauses after the projectile exists. It records emission 737, actual paused state 741–798, then the original `ShotGunPlayCommand.robotMove` on **742 while still paused**. Interruption clears despite stopped game-engine callbacks. The Space used to resume at 798 also executes the restored `ShotGunProp.bombDown` (recorded independently of the UI outcome), producing a second projectile on 812 and recovery on 817. This is a recorded resume-input/action interaction, not a speculative automatic duplicate. It directly demonstrates that this pending Tween recovery is not frozen by the game pause.

The final `lifecycle-triple-recovery-pause-02` requests pause one frame earlier than an inconclusive initial attempt. It records the actual human pause callback on **757**, then `NinjialPlayCommand.robotMove` on **758 while native pause remains true** through 814. Resume Space at 814 also starts a second action; its constructors occur on 815/830/845 and recovery on 850. Both pending-recovery cases therefore demonstrate original Tween completion during an already active game pause. The excluded revision01 had recovery before actual pause within the same frame; it remains only in ignored raw investigation storage and is not counted as this boundary's successful evidence.

Early replacement fixtures create an incoming pickup before old-action down, and ordinary next-frame collection can replace the active weapon. Hammer, laser, triple and fireball clear interruption on 724 with the replacement equipped and no selected execution errors. Triple's first projectile is already constructed on 724 and keeps original updates from 725; replacing the weapon does not retroactively erase it. The initial **flamer replacement attempt does not accomplish replacement**: the model remains `thrower` and recovers only at 746. The pending same-cell pickup disappears without Laser changeStage, while selected `shootFire/hitItem(1,1)` and original pickup-deletion source identify the earlier fire-tip interaction. Constructing a LaserGunProp alone does not prove it became equipped.

The distinct `lifecycle-flamer-late-replacement-01` waits twelve action frames before constructing the incoming LaserGunProp. Its v5 research fixture permits **only pickup construction** during an existing interruption, retaining the registered/nondead actor and empty-floor guards; it does not change the weapon or cancel commands itself. Normal next-frame collection gives native **735: thrower/interrupted →736: lasergun/uninterrupted**, with original FlamerProp, FlamerFire and AbstractWeapon dispose calls all on 736. No selected errors occur. This successful late replacement is separate evidence from the earlier destroyed-pickup case.

`AbstractWeapon.dispose→AbstractCommand.dispose→CommandChain.removeCommand` is the original cleanup route, not an agent cancellation queue. Triple/fireball command disposal additionally pauses any already-created delayed callback. The early replacement cases do not certify every possible late-pending-callback ordering. The action index retains the exact original errors array, receiver groups and native state for each lifecycle scenario; no selected errors were observed in the final 39 indexed runs. The lifecycle bundle passes 126 evidence assertions covering exact case/build/log/native-frame/screenshot integrity and actual observed callback/replacement outcomes. These checks support this bounded result, not coverage of excluded functions or a native Adobe Flash comparison.

Second-use exhaustion is tested by the interaction cases' two legal actions. Their exact target damage, obstruction, protection, pickup/bomb interaction, post-replacement state, pause results and error records remain owned by that report. Source thresholds here do not silently fill untested target permutations. Snapshot interruption state, native movie frame, selected callback execution and rendered appearance are kept separate; no complete Adobe Flash equivalence or finished Godot feel parity is claimed.
