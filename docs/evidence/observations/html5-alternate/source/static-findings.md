> Imported Dots record; claims are retained as delivered. See the [integration assessment](../../../edition-5-play-observations.md) for verification, missing files, and authority limits. Original relative paths in code spans refer to the [unaltered bundle](../../../../../.scratch/edition-5-research/observations/html5-alternate/source/static-findings.md).

# Exact-build static evidence supplement

Evidence type: STATIC INSPECTION of decompiler output, not direct play. None of the findings below claims a runtime measurement. Source: https://www8.agame.com/games/flash/b/bomb_it_5/bomb-it-5-zh-fix.swf . SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`; 6,942,081 bytes. Root.VERSION_NUM is v.1.6.1. Analysis date 2026-10-16.

## Reproduction and interpretation

JPEXS Free Flash Decompiler 26.3.0 from official release https://github.com/jindrapetrik/jpexs-decompiler/releases/tag/version26.3.0 was downloaded and run with user permission. Script export completed: 1068 scripts; see decompile.log. Commands: `java -Djava.awt.headless=true -jar ffdec.jar -export script decompiled bomb-it-5-zh-fix.swf` and `-export binaryData binaryData bomb-it-5-zh-fix.swf`. All paths below are relative to `decompiled/scripts/`; namespace prefix `zlong/bombit5/` is abbreviated B5. Methods are durable locators, since export line numbers may change. Binary XML is `binaryData/6787_zlong.bombit5.utils.XmlManager_xmlClass.bin` (UTF-8 XML).

Recovered source, XML, art and audio are reference only. No implementation was modified. Do not include the SWF or recovered source/assets in the Douyin release.

## Screen and map

S01: Root metadata and independently parsed binary header specify 700×510 pixels, header rate 30 fps, three ROOT timeline frames (not three gameplay frames). `Root.GAME_FRAMERATE=35`; `AbstractRootClass.initLoadSetting` assigns this to stage.frameRate. Actual achieved rate is unknown from static inspection. Header details and tag offsets: swf-header-manifest.json.

S02: `GameConfig` constants specify MAP_WIDTH=17, MAP_HEIGHT=15, GRID_WIDTH=30, EXCURSION_X=183, EXCURSION_Y=40. Arcade spawn grid coordinates are (1,1), (15,1), (1,13), (15,13), zero-based. These support the grid-coordinate model; do not infer painted board bounding-box edges without the screenshot, since placement may be cell-origin versus art offset.

S03: `GameConfig` interface anchors: (31,24), (31,120), (31,215), (31,309); robot UI anchors (24,21), (24,116), (24,211), (24,308). These are code constants, not screenshot measurements.

S04: `B5/maps/mapData/AbstractMapData.data` chooses one of the non-final data functions randomly; Pac-Man chooses final data function. `BirthdayPartyMapData.init/normalOne/normalTwo/normalThree` reference BirthdayPartyStage1/2/3; each reads named `editorGridMc` children `grad_x_y`. Tile-name categories include fixedProp, unfixedProp, centerProp, holdProp, toyHand_direction and lavaOrgan. `unfixNum=.8` default in AbstractMapData; `MapMaster` row construction draws Math.random and compares fixed/null/unfixed intervals. Thus choosing an arena does not by itself identify an exact board. The first runtime screenshot must remain authority for its particular board; no stand-in board is justified.

S05: `ui-text-en-zh.csv` preserves all recovered English/Chinese localization IDs and their constant-pool provenance. Screen texts include ARCADE / DESTROY ALL ENEMIES; BATTLE ROYALE / DESTROY 10 ENEMIES; PAC-MAN / COLLECT ALL COINS; GREEN ZONE / OCCUPY THE GREEN ZONE. Chinese Green Zone text explicitly mentions 10 zones. Six arena labels are Birthday Party, Candy Factory, Zoo, Luxury Shop, Magic Library, Movie Theater. These are embedded strings, not proof a particular screen was reached.

## Input and bomb

S06: Earlier input evidence is supported by the same exported `PersonInteractiveController` and `InteractiveController`: latest-held cardinal direction wins, releasing it restores previous held direction; down and up bomb events are distinct and movement deduplication is not applied to bomb-down events. No OS repeat cadence is implied. `RobotController.addBomb` requires bombNum < allowBomb and current map cell isEmpty. `RobotModel.initModel` initializes one allowed bomb and power 1. `GameConfig` caps power 5 and capacity 9. Weapon-specific down/up callbacks replace default behavior (`AbstractWeapon.changeStage`).

S07: `B5/bombs/Bomb` normal fuse threshold `_normalBlastTime=GameConfig.FRAME_RATE*2` =70. blastMode starts `_time=0`; takeCount tests `_time > _blastTime` BEFORE increment. Uninterrupted ordinary countdown therefore explodes on invocation 72, not invocation 70. This is a static callback count, not a measured 2 seconds. Creation phase relative to frame processing can shift wall-clock interval. `blastHandle` sets time to threshold+1 and calls takeCount immediately: source supports chain-trigger detonation.

S08: `Bomb.blast` marks center fire then scans four cardinal directions up to bombPow. At nonempty non-Crocodile item it stops that ray and calls hitItem. Destructible occupied cells can receive fire graphics; bombs are explicitly excluded from that graphical condition. `AbstractBomb.hitItem` handles prop deletion, bomb BLAST events, boxes and slide switches. Solid Box (`isExist=false`) uses hitBox feedback instead of deleteBox; destructible Box (`isExist=true`) is deleted and removal earns boxPoint. Crocodile is an explicit exception to ordinary blocking. Do not generalize this to every platform without checking its class.

S09: `Bomb.ended`: continueTime starts zero, removal condition is >15, then increment; cleanup on the 17th ended callback. Blast callbacks run after bomb callbacks in the same engine handler, so callback count is not a standalone duration measurement. `GetFireCommand.execute` checks current tile fire and invokes damage, supporting injury on entering active fire, not only at initial blast.

S10: `Box.deleteBox/brickExp/countBrickExp` waits for the destruction animation near its last frame before cleanup and createProp, and skips createProp if a robot occupies the cell at that point. `Box.createProp` requires propCurrent<propTotal and a random test against propProb. `MapMaster.init` starts propTotal=32 and vehicleNum=4; XML difficulty probabilities are easy .6, normal .5, hard .4, with code fallback .6 if zero. Then a class is chosen from propArr; vehicles have additional availability restrictions. These are conditional drops, not guaranteed drops. UI icon or apparent drop rate alone cannot identify the class.

## Clock, damage, lives, score, ending

S11: Embedded XML sets totalTime=180, personLife=3, aiLife=1 for Arcade, Kill, PacMan and GreenZone. `AbstractGameMode.init` reads these values. 180 is supported by this exact edition, unlike importing a student remake's clock. `Game.countTime` does NOT add elapsed delta: it compares `new Date().getSeconds()` to pastSecond and adds exactly 1 on a difference. It is called from the tween phase of GameEngine (periodic frame callbacks). Long stalls can miss seconds; the bomb and display clock are different timing mechanisms. No achieved cadence is asserted.

S12: `TryToKillCommandChain.execute` checks existence and not-dead state. Shield consumes a use and enables temporary invincibility; vehicle branch destroys vehicle animation then resumes with invincibility; unprotected path invokes RobotDeadCommand. There is a China-portal invulnerability early return, but exact `Root.PORTAL_TYPE=PortalType.PORTAL_TYPE_TWEEN` and PortalType value is `tween`, NOT `china`. This is useful nuance beyond the earlier `__cheat__=true` constant; do not mislabel publisher build invincible from the flag alone.

S13: Life is not simply three hit points inside one Arcade battle. `RobotDeadCommand` → AbstractPlayer.robotDead → AbstractRobot.kill marks dead and unregisters. After death animation, Game.deleRobot invokes mode end. ArcadeMode.end deletes the actor, loses if no PersonRobot remains and wins if no AIRobot remains. `AbstractGameMode.loseHandler` then decrements every personal player's life and offers level restart if any life remains, otherwise game-over results. PersonRobot.minLife exists, but no call sites to minLife were found in complete export search. Runtime shield/vehicle/life paths must be distinguished.

S14: `AbstractRobot.bombItemScore` adds BOX_POINT=10 to boxPoint; bombRobotScore adds ROBOT_POINT=100 to modePoint and increments killNum. ArcadeMode.countScore later overwrites modePoint with killNum*300; winning level score=modePoint + (gameTime-pastTime)*10 + difficulty bonus (1000/2000/3000); losing gets killNum*300, zero time and difficulty bonus. Do not assume every accumulated field feeds final total: Arcade countScore sums only those three fields. Runtime results should verify this.

S15: Arcade timeout deserves targeted testing. `ArcadeMode.timeOut` plays time-up then judgeHandler; exported judgeHandler tests `game.robots is PersonRobot` and `game.robots is AIRobot` (array rather than indexed element), unlike normal end's indexed checks. Single-player path calls winHandler unconditionally. This is a source anomaly, not a correction to make or an asserted observed timeout result. `KillMode.end` uses Game.judgeGameWin and schedules ReliveThread; `AbstractPlayer.killSelfHandler` can decrement positive kill score in Kill mode. Do not transfer Arcade elimination semantics to other modes.

## Special item identity: separate, unresolved where necessary

S16: BOXING GLOVE is embedded localized label PowerUps_11. `BoxingProp.initWeapon` names weapon `boxing`, propNum=38, weaponRange=2 and totalUseNum=2. bombDown starts BoxingPlayCommand, stops movement/bomb action while playing and consumes a use. Command attacks adjacent tile then second tile if first did not stop it, at animation end; can damage robots, break soft Box, trigger bomb BLAST, collect an item, or toggle SlideSwitch. It is an attack weapon, not evidence for lifting/throwing a bomb. Controls use the existing bomb/action callback, not an independently established extra button.

S17: Distinct from boxing is BombShoesProp, propNum=6, with UI label PUSH THE BOMB (PowerUps_8); XML comment calls it 手套. It hooks movement hit callback when not riding, kicks encountered bomb in facing direction with speed magnitude7. It clears bomb engineArr before startFly; Bomb.kickedFly restores countdown callbacks after collision. This suggests fuse countdown pauses while kicked flight is active; requires runtime test before claiming measured behavior. Do not merge boxing glove and push-bomb equipment based on translation or icon.

S18: No bouncer, magic carpet or heavy-bomb string/class-name match was found in full B5 script search, and these are absent from the English localization item list. UNKNOWN identities, controls and behavior. Absence of a matching name is not proof of absence: decompiler names and visible names can differ. JumpTable, ToyHand and Spellbook exist as map platforms, but are not equated to the user's slots without visual/source mapping. Vehicles in labels are frog, sports car, mammoth and skateboard; code internal names differ. No other edition substituted.

## Contradictions and open questions

- Accepted DESIGN is a new-game contract, not recovered behavior. Original maps have randomized template/occupancy logic; exact observed board can be recovered without implementing a generic generator.
- 'No drops until evidence' now has a static conditional-drop path; runtime evidence still needed.
- All-enemies-dead is supported for normal Arcade end; timeout is a separate anomalous path.
- Earlier timing note correctly recovers frame-driven engine but explicitly did not audit independent systems. The Date-based display clock is added evidence, not proof 35 achieved fps.
- Need runtime verification of two-key order, key repeat, fuse onset/end, chain rays, kicked-fuse pause, shield/vehicle absorption, Arcade level-life decrement and timeout, score totals, and visual identity of all four special-item slots.

## Loading blocker triage (static only)

S19: UIManager.gamePlay constructs LoadingMapUI then Game. Game.init performs dataInit, displayInit, modeController.init, mapInit. AbstractMapSet.create uses embedded mapData then MapMaster.createBoxes. The latter uses Timer(100), creates one row per event until MAP_HEIGHT=15, then mapLoadComplete → firstMapLoadOver → robotInit / gameStartHandler. Background uses getDefinitionByName on embedded class, not URLLoader. Root.__loadXML__ is false, and XmlManager uses embedded XML. This path provides no evidence of an external arena-file download requirement. A loop lasting a minute is not explained by the nominal row timer, but exact runtime cause is UNKNOWN. No console access or SWF modification was used for this inference.

`method-locators.json` gives line numbers for exported methods, supplementing the durable class/method citations above. `decompile.log` preserves export outcome.
