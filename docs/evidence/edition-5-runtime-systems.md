# Edition 5 runtime systems

Static source inspection and independent data extraction on 2026-10-19, for the playable Godot build. Authority: publisher v1.6.1, SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`. Source locators below are beneath the extracted `zlong/bombit5` package unless stated otherwise. These findings supplement the imported reports; Godot checks verify the new implementation, not an independently replayed SWF.

## Reproducible data

[inspect_source_data.py](../../tools/inspect_source_data.py) reads SWF tags directly, checks the publisher hash, extracts DefineBinaryData 6787 and sprite frame counts, and writes the [data record](edition-5-runtime-data.json). Run it from the repository root with the recorded SWF in investigation storage. It exports data, not production artwork. The embedded XML hash is `6bd8fe14a186e49dbb77ea3412d93549bd212bd56e0265f632f3d9de6ea6cf22`.

The production [board CSV](../../assets/maps/cinema-stage1.csv) is a copy of the independently audited recorded-instance CSV. The game does not need the SWF, decompiler or playback harness to run. Investigation storage has a Godot ignore marker and is outside the game's resource tree.

## Portals and ordinary bombs

`maps/Grid.isEmpty` excludes every platform, even a nonblocking portal. `AbstractObject.isExist` defaults false and `AbstractPlatForm.init`/`Portal` do not set it true. Consequently `RobotController.addBomb` rejects ordinary placement on a portal; `Bomb.blast` stops its ray there without adding flame. Walking and laser traversal use different conditions. Treating every walkable cell as an ordinary-bomb floor would be incorrect.

`Portal.runEngine` interrupts movement/action, queues `SendRobotCommand` with 30 callbacks and `InvincibilityCommand` with parameter 45, and sets `isExist=false`. `SendRobotCommand.sendEnd` restores `isExist=true` at arrival; the blink command has not necessarily ended. Thus the nominal 45 parameter is not proof of 45 callbacks of damage immunity after arrival. `CheckRobotInPortalCommand` releases the return latch only after leaving a portal.

## Hazards, protection and elimination

`Bomb.ended` clears its fire when `_continueTime > 15`; the supplied captures show 17 visible frames. `Bomb.deleFire` writes shared grid booleans false, without reference counting overlapping flames. The new round retains this shared-fire cleanup behavior while keeping each visible flame record until its own expiry. Visible flame overlap therefore does not imply a separately counted hazard reference.

`AbstractBomb.hitRobotUnderPoint` attributes immediate non-self hits; `GetFireCommand` applies ongoing grid-fire contact through `TryToKillCommandChain` without adding bomb-owner credit. Own blasts use `AbstractPlayer.killSelfHandler`, which delegates to the same damage chain in Arcade. Ordinary actors occupy their logical cell for these queries; movement collision still uses their full footprint.

`TryToKillCommandChain` handles vehicle loss before shield use, then death. `ShieldProp` has one use. `InvincibilityCommand` defaults to 80 and expires after its greater-than counter boundary; the conversion uses 82 following callbacks. Vehicle-loss animation lasts one second before this protection command; the new simulation expresses that recovery as 35 ticks rather than a renderer tween.

`InvincibilityProp` is not just a 350-tick shield: its introduction sprite has 30 frames, after which `CountInvincibilityCommand` counts through `>350` and can attack other actors sharing the cell. The new art uses a 29-tick introduction and 352-tick active counter; immunity covers both, contact damage starts after the introduction. This is an explicit frame-to-tick conversion, not a measured universal SWF input-to-effect interval.

`ArcadeMode.end` checks surviving humans before surviving AI. The new batch evaluates human death before elimination victory and evaluates timeout with enemies remaining afterward. This resolves simultaneous batch endings consistently with that source priority. Death consumes a retry heart; timeout defeat consumes one too under the accepted timeout adaptation. There is no in-round respawn.

## Drops and scoring

`Box.countBrickExp` considers a drop only after the break animation and only if no actor occupies the cell. `Box.createProp` checks the cumulative 32-item quota, Normal probability 0.5 and integer-weighted choices. `MapMaster.propCurrent` adds to the cumulative count; it is not decremented on collection. Soft-block vehicle choices have a four-vehicle budget.

The XML weights are rounded with ActionScript `Math.round(value*100)`: each 0.005 entry becomes one, not zero. The resulting list has 97 entries. Cinema vehicle entries choose MotoCycle/Car. `ArcadeMode.timePassed` uses `>45` and multiples of 15: first timed spawning is at 60 seconds, not 45. `Map.createRamdonProp` chooses unoccupied, nonblocked cells without the soft-block quota or vehicle budget. Portals can qualify; existing fire is not itself a blocking cell.

The two glove candidates remain excluded under the approved unresolved-slot scope. Their original weighted draws produce no item in this build; other weights are not renormalized. This is a declared scope adaptation, not evidence that the original lacks either item. Bouncer, magic carpet and heavy bomb are not filled. Follow-up work must resolve the named-slot decision before enabling either candidate under that slot.

`AbstractPlayer` adds 10 block, 100 pickup and 100 immediate kill HUD points. `ArcadeMode.countScore` replaces the result calculation: victory is kills×300 + difficulty bonus + remaining integer seconds×10; loss is kills×300, accumulated into session total. The Normal bonus is 2000 (`GameConfig.DIFF_POINT`). The result's remaining seconds match the countdown display. Example: three kills at tick 73, shielded human alive, gives 900 + 2000 + 1780 = 4680. HUD pickup/block points are not simply added to that result.

## Weapons and vehicles

| Effect | Source locators and recovered behavior |
| --- | --- |
| Landmine | `LandmineProp`, `LandminePlayCommand`, `LandmineBomb`: one use, power two, no ordinary countdown, armed after its owner leaves the logical cell; a returning actor triggers it. It is not an ordinary movement blocker or ordinary capacity occupant |
| Hammer | `HammerProp`, `HammerPlayCommand`: two uses; a 25-frame animation hits at `totalFrames-1`; adjacent block/bomb/item interaction plus actors on the adjacent and wielder cells |
| Flamer | `FlamerProp`, `FlamerFire`, `FlamerPlayCommand`: two uses, three-cell maximum; solid geometry truncates animated fire, soft blocks can be removed successively. Parent sprite has one frame; its inner sprite 2212 has 24 |
| Laser | `LaserGunProp`, `LaserGunPlayCommand`, `LaserPlayCommandChain`: two uses; 12-frame charge; one ray hit pass stops at its first blocking item and leaves a short visible beam; it does not turn every visible beam frame into a new damage pass |
| Triple-shot | `TripleShootGunProp`, `NinjialPlayCommand`, `TripleShootGunBomb`: two uses; three sequential projectiles at counts 0, 15 and 30, speed five source units/update, then a 0.3-second recovery |
| Fireball | `ShotGunProp`, `ShotGunPlayCommand`, `FireballBomb`: two uses; one projectile after its 14-frame animation, speed ten, then 0.3-second recovery. The class name does not justify inventing a pellet fan |
| Cinema rides | `CarProp`/`MotoCycleProp`: base acceleration multipliers 1.6/1.3; vehicle acquisition resets riding state, not the equipped weapon. Damage removes the ride and temporarily interrupts controls |

Projectile classes do not register as stationary map bombs. They hit traversed actor cells excluding their owner and strike the next blocker; they do not produce an ordinary plus-shaped timed explosion. Action locks prevent repeated delivered downs from spending a second use during an existing action. The new vector animations have explicit simulation durations; exact original per-frame painted bounds, especially the flamer's animated endpoint, are not asserted as pixel parity.

## AI and adaptation limits

`GameEngine.runAISeq` evaluates one AI brain per frame. `AIRobot` separately maintains path-following callbacks. `AIControl.update` uses `getTimer()` around the XML `aiAnswerTime` field; that field is not a tick count. Normal XML specifies range six, attack 0.6, evade/get-item/free 0.8, box attack 0.7, and a 150 ms weapon delay; the extracted record preserves the complete definitions.

The reconstructed controller rotates brain decisions among active AI (dead, transferring and action-locked handlers leave the rotation) while following paths every logical tick. It uses source-grounded attack, escape, pickup and free-route goals, range six and attack/block probabilities. Eight-direction route selection and its collision constraints are adaptations; the controller is not a line-for-line port of the original state machine, all its transition probabilities, or its path-cost ranking. The shared movement, legal commands, safe-corner rules and source-supported combat effects are exercised through the real round. Difficulty parity is not claimed, particularly after the accepted diagonal adaptation; physical phone evaluation remains deferred.

## Implementation and checks

[The round](../../scripts/simulation/bomb_simulation.gd) owns admitted gameplay state. Movement, AI, pickup data and weapon callback modules support it; the scene consumes copied snapshots. The [round tracer checks](../../tests/round_play_check.gd), [regressions](../../tests/round_regression_check.gd), [scene checks](../../tests/game_scene_check.gd) and [full-board playthrough fixture](../../tools/playthrough_check.gd) use public production interfaces. Passing them establishes the specified new-game behavior, not independent replay of every original source edge case.


## Desktop feel audit clarification (2026-10-19)

The source's persistent lethal fire is real, not an invented half-second cooldown: Bomb.init initializes `_continueTime=0`; Bomb.blast sets grid fire and registers `ended`; `ended` clears fire when the counter is greater than 15, then increments. GetFireCommand reads the same grid fire for ongoing damage. GameEngine.enterFrameHandle runs bomb handlers before blast handlers, so a normal timed detonation can receive cleanup callback one in its creation frame. Under that phase order cleanup callback 17 occurs 16 frame intervals later (about 0.457 s at the configured 35 fps). A blast created after the blast-handler phase can start counting the next frame instead. This is a static phase trace, not a new independent SWF playback measurement. The earlier reference to 17 visible frames must not be interpreted as proof of 17 full elapsed intervals for every source creation path. The current round uses a uniform detonation+17 expiry (0.486 s), so exact phase parity remains incomplete even though both retain dangerous fire for roughly half a second.

The reproducible new-game [timing diagnostic](../../tools/inspect_control_timing.gd) checks entry during the final hazardous tick and the first safe tick, plus each weapon's observable movement lock. Original `items/weapons/AbstractWeapon.robotMoveStop/robotMoveStart` intentionally interrupts/restores movement and bomb input in Arcade; `commands/weapon/HammerPlayCommand`, `FlamerPlayCommand`, `LaserGunPlayCommand`/`LaserPlayCommandChain`, `NinjialPlayCommand` and `ShotGunPlayCommand` restore control through animation/counter/tween events. Thus a movement lock is not itself evidence of a performance hitch.

Original FlamerFire.xN/yN derives the hit cell from the current `firePlay.width/height`, weapon scale and actor grid position. The new linear three-cell envelope is an approximation of behavior, not merely replacement artwork. The current renderer shows circles/arcs/lines and basic actor bobbing rather than complete directional attack animations, hand/gunpoint alignment, original hit/recovery feedback or weapon audio. Original fireball/triple-shot have an explicit 0.3-second TweenMax recovery; converting that to logical ticks deliberately differs from a renderer tween's scheduling. Exact source-feel parity needs a sequence/geometry comparison, not just replacing the displayed sprites.
