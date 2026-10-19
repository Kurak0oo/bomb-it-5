> Imported Dots record; claims are retained as delivered. See the [integration assessment](../../edition-5-play-observations.md) for verification, missing files, and authority limits. Original relative paths in code spans refer to the [unaltered bundle](../../../../.scratch/edition-5-research/observations/swf-v1.6.1/source-findings.md).

# Bomb It 5: source findings (static analysis)

Source: `bomb-it-5-zh-fix.swf` (SHA-256 718c04c7…08a2, matches). Decompiled with FFDec 26.3.0.
Paths are relative to `reference-assets-NOT-FOR-RELEASE/scripts/`. The `zb/` prefix means `zlong/bombit5/`.
Embedded balance XML: `reference-assets-NOT-FOR-RELEASE/binaryData/GameConfig.xml` (written `XML:` below).
Tags: **[S]** observed in source · **[I]** inferred · **[U]** unknown. No implementation was changed.

## 0. Global / timing
- [S] Stage is 700×510. The SWF metadata says frameRate 30 (`Root.as:8`). `Root.GAME_FRAMERATE = 35` (`Root.as:26`) is applied through `stage.frameRate = _childClass["GAME_FRAMERATE"]` (`zlong/Template/AbstractRootClass.as:209`). This matches the research.
- [S] The game tick is `GameEngine.enterFrameHandle` on `Event.ENTER_FRAME` (`zb/gameengine/GameEngine.as:57`). `countTimer = new Timer(25)` (`:39`) gets a listener at `:227` but `start()` is never called anywhere. This matches the research.
- [S] `Root.__cheat__ = true` (`Root.as:20`). It has no other reference in any script, so it is unused. This matches. Unrelated: `GameConfig.CHEAT_UNLOCK_ALL_CLOTHES = false`.
- [S] The round clock is wall-clock time, not frames. `Game.countTime` compares `new Date().getSeconds()` with the last second (`zb/gameengine/Game.as:~796`), increments `pastTime`, and calls `modeController.timeOut()` when `pastTime >= gameTime` (`:801-816`).
- [S] `PORTAL_TYPE = "tween"` (`Root.as:30`). `TryToKillCommandChain.execute` has a branch that makes human players unkillable when PORTAL_TYPE == "china" (`zb/commands/robot/TryToKillCommandChain.as`). It does not trigger in this build.

## 1. Screens and flow (`zb/ui/UIManager.as`)
UIManager listens on the UI container for `UIEvent`s (`:83-91`):

| From | Event | To |
|---|---|---|
| boot | — | `UILoading` (Root.LOADING_CLASS_NAME) → `MainMenuUI` (`:73`) [S] |
| MainMenuUI (title + main menu) | GAME_SETTING (`MainMenuUI.as:183`) | `GameSettingsUI` (mode select: players, mode, enemies, levels, stage, difficulty) (`UIManager:225`) [S] |
| MainMenuUI | CONTROLS (`:195`) | `HowToPlayUI` (key rebinding / controls) (`:231`) [S] |
| HowToPlayUI | POWER_UPS (`HowToPlayUI:473`) | `PowerUpsUI` (item help); its back/controls buttons return (`PowerUpsUI:52,59`) [S] |
| HowToPlayUI / GameSettingsUI / PowerUpsUI | CHANGE_BACK | `MainMenuUI` [S] |
| GameSettingsUI | SELECT_CHARACTER (`GameSettingsUI:805`) | `CharacterSelectUI` (incl. dress-up `ClothesPanel`) [S] |
| CharacterSelectUI | GAME_START (`:313`) / GAME_SETTING back (`:388`) | `LoadingMapUI` + `new Game` (`UIManager:288-324`) [S] |
| Game | P key (keyCode 80, `Game.as:185`) or HUD pause button (`GameInterFace:334`) | `PauseUI`: RESUME (`PauseUI:127`; Space also resumes, `:103`) or MAIN_MENU (`:121`) [S] |
| round win | `GameEndCartoon("winCartoon")` → `AbstractGameMode.winHandler` | `OnePScoreUI`/`TwoPScoreUI` with LEVEL_WIN, or GAME_WIN after the last level [S] |
| round lose | `"loseCartoon"` → `loseHandler` | score UI with LEVEL_RESTART while any player has life > 0, otherwise GAME_OVER plus `OnePGameOverUI`/`TwoPGameOverUI` (`UIManager:386-417`) [S] |
| time up | `"timeUpCartoon"` (`ArcadeMode.timeOut`) | judgeHandler → win/lose [S] |
| GameOver UI | GAME_SETTING (`PlayerGameOver:68`) | GameSettingsUI [S] |
- [S] There is no separate "settings" (audio/quality) screen class. Music toggle and quality live on the main/in-game UI (`UIManager.enableMusic`). [I] "Settings" in the brief corresponds to `GameSettingsUI` (match setup).
- [S] Avatar/Spil upload screens (`zb/ui/avatar/*`) are portal features and are out of scope.

## 2. Modes, settings, round rules
- [S] Modes reachable from GameSettingsUI: ARCADE (`:447`), KILL ("Battle Royale", `:482`), PAC_MAN (1P only, `:520-523`), GREEN_ZONE (`:558`). `SpeedMode`, `WaterMode`, `CollectMode`, `PaintingMode` classes exist but are not selectable [S, from the setter list].
- [S] Settings: players 1/2; enemies 0–3 (2P forces at least 1, `:440-442`); levels 1/10/15/20 (`:680-689`, default 5 in `GameModel`); stage random or one of 6; difficulty easy/normal/hard.
- [S] Per-mode XML: all four modes have `totalTime=180`, `personLife=3`, `aiLife=1`, `propborn=200`. Kill/GreenZone have `levelWinNum=10`, PacMan has 100.
- [S] Arcade win: all AI robots dead (`ArcadeMode.end` `:106-136`). Arcade lose: all human robots dead.
- [S] Arcade time-up: `judgeHandler` (`ArcadeMode:54-86`) tests `game.robots is PersonRobot` (the array itself, which is always false), so both counters stay 0. 2P: 0>=0 → win. 1P: always win. **Time-up is therefore always a WIN in Arcade.** This is a source bug and should be copied only on purpose.
- [S] "Lives" (`personLife=3`) are retries across levels. `loseHandler` decrements every human's life and restarts the level while any life > 0 (`AbstractGameMode:144-183`). Within an Arcade round there is no respawn: `ReliveThread` is only created in Kill/PacMan/GreenZone (`KillMode:45`, `PacManMode:63`, `GreenZoneMode:38`), after `reborn` seconds (XML: 1 s) × FRAME_RATE frames (`zb/gameengine/ReliveThread.as`).
- [S] Easy Arcade puts a ShieldProp on each human's spawn cell at map load (`ArcadeMode.mapLoadOver :28-41`).
- [S] Arcade adds random props over time: after 45 s, every 15 s, 2 props (1 in CandyFactory, 0 in MagicLibrary) (`ArcadeMode.timePassed :88-104`).
- [S] HUD timer turns into a warning style when fewer than 10 s remain (`Game.as:805`). [U] The exact visual.

## 3. Score (`GameConfig.as`, `ArcadeMode.countScore :139-163`, `AbstractRobot`)
- [S] Constants: BOX_POINT 10, ROBOT_POINT 100, PROP_POINT 100. DIFF_POINT easy/normal/hard = 1000/2000/3000.
- [S] Destroying a soft box gives the owner `boxPoint += 10` (human players only). Killing with a bomb gives `modePoint += 100` and `killNum++` (only if the victim has no vehicle and no shield, `AbstractBomb.hitRobot`).
- [S] Arcade level score on win = killNum×300 + DIFF_POINT + (gameTime−pastTime)×10. On loss = killNum×300 only. Totals accumulate. [U] Where `boxPoint` is added into the total (it is not in countScore).
- [S] Outfit unlock thresholds: UNLOCK_SCORE_1..8 = 2500, 7200, 12000, 19200, 24000, 31200, 36000, 48000.

## 4. Map grid and maps (see `maps/`)
- [S] Grid is 17×15 cells (`GameConfig.MAP_WIDTH/HEIGHT`). Cell is 30 px (`GRID_WIDTH`). The playfield is offset to (183,40) on stage (`EXCURSION_X/Y`, `Map.as:62-65`). That gives a 510×450 px field inside the 700×510 stage. The left strip (x<183) holds the HUD.
- [S] Layouts are not in code. They are timeline symbols `<Set>Stage1..3` and `<Set>Stage_PacMan_1..3`, each with child `editorGridMc` holding `grad_x_y` cells. The top-most child's instance name sets the cell type (`ZooMapData.setData :68-129` and the other *MapData). I read them from the FFDec XML dump with `tools/parse_swfxml.py` and `tools/gen_maps.py`.
- [S] Cell meaning (MapMaster.createRow `:135-203`, Box.as). The SWF's own editor legend texts back this up (`strings/static-texts.tsv`: 不可摧毁建筑物 / 可摧毁建筑物 / 中央建筑物 / 占位格):
  - `fixedProp_*` → solid block (Box with `isExist=false`, indestructible. The bomb only plays a hit spark, `AbstractBomb.deleBox`). Suffix `_r` = random skin, `_N` = skin N.
  - `unfixedProp_r` → soft block, created with probability `unfixNum = 0.8` (`AbstractMapData`). In PacMan maps unfixed cells become empty (`setDataByPacMan`).
  - `centerProp` → central building (solid). MagicLibrary: `Spellbook` platform plus a hold box. CandyFactory: `ConveyorBelt` controller.
  - `holdProp` → invisible solid placeholder for a large building (midBox 2, `setBoxVisible(false)`).
  - Special tiles: `crocodile` (Zoo, `maps/platform/Crocodile`. Blast passes through it, `Bomb.blast`), `lavaOrgan` (eruptDelay random 5–15), `toyHand_<dir>` (BirthdayParty), `portal_<pair>_<n>` (Cinema), `belt_<n>` (CandyFactory conveyor path), `slidePlat_<dir>` (CandyFactory). Other platform classes exist: Rail, Tractor, Flag, SlideSwitch, JumpTable, WaterSlide, Piranha, BlackHole, CheckPoint. [I] Mostly for unused modes.
  - Anything else → empty.
- [S] Spawns for all used modes: (1,1), (15,1), (1,13), (15,13) (`GameConfig.ROBOT_*_POSITION`). The four corners are kept free of soft boxes in createRow (`:192`).
- [S] Map pick: a random one of the 3 normal layouts per set (`AbstractMapData.data`). PacMan picks a random `_PacMan_1..3`. In Random stage mode the 6 sets rotate without repeats, and a lost stage is retried (`UIManager.gamePlay :288-312`).
- [S] Unused symbols: Basketball Stage1-7 and BirthdayPartyStage4 are not referenced by any class (`maps/INDEX.md`).
- [S] Files: `maps/<Symbol>.txt` (ASCII grid + legend) and `maps/<Symbol>.csv` (x, y, instance_name, code, spawn), 44 symbols in total.

## 5. Bombs (`zb/bombs/Bomb.as`, `AbstractBomb.as`, `zb/gameengine/robot/RobotController.as`)
- [S] Fuse: `_normalBlastTime = FRAME_RATE*2 = 70`. `takeCount` runs once per engine tick and explodes when `_time > 70`, which is the 71st tick (about 2.03 s at 35 fps) (`Bomb.as:20,145-191`).
- [S] Flame stays for `_continueTime > 15`, about 17 ticks, then the fire flags clear (`ended :430-443`).
- [S] Range = owner's `bombPow` (start 1, `RobotModel:100`). It goes one cell at a time in 4 directions up to bombPow (`blast :269-417`).
- [S] Blocking: a ray stops at the first non-empty cell that is not a Crocodile. That cell is still hit (box destroyed/sparked, prop removed, bomb chained), but no flame is drawn past it. Map edges also stop rays.
- [S] Chain reaction: `hitItem → deleBomb` dispatches `StringConstData.BLAST` on any bomb in the cell. `blastHandle` forces `_time = blastTime+1` and detonates on the same tick (`:162-166`).
- [S] Soft block breaking: `Box.deleteBox` plays the brick explosion. When it ends, if no robot stands on the cell, it calls `createProp` (`Box.as:134-222`).
- [S] Damage: any robot in a flame cell → `TryToKillCommandChain`. No vehicle and no shield → dead (one hit). With a vehicle: the vehicle is lost and a temporary invincibility command runs. With a shield: the shield use is consumed and an invincibility command runs. The owner's own bomb calls `killSelf` (`AbstractBomb.hitRobotUnderPoint :51-83`). In PacMan the AI cannot be hit by bombs.
- [S] Placement: bomb key down → `RobotAction.BOMB` → `_bombHandler` (default `addBomb`). It is placed only if `bombNum < allowBomb` (start 1) and the robot's cell is empty (`RobotController:154-166`). Key up → `BOMB_UP` → `_bombHandler_up` (weapons only). This matches the research: there is no event dedup, and key auto-repeat fires repeated BOMB events. [S] In practice, stacking is prevented because the cell is no longer empty.
- [S] Caps: MAX_BOMB_POWER 5, MAX_BOMB_ALLOW 9.

## 6. Drops (`MapMaster.as`, `AbstractGameMode.initMap :240-345`, XML)
- [S] Per box: if `propCurrent < propTotal (32)` and `random < propProp[difficulty]` (easy 0.6 / normal 0.5 / hard 0.4), pick uniformly from a weighted list where each item appears round(weight×100) times. At most 4 vehicles (`vehicleNum`). After that, vehicle entries are removed from the list.
- [S] Arcade weights (XML `ArcadeMode/prop`): NumProp 0.28, PowProp 0.24, SpeedProp 0.22, BombShoesProp 0.10, Vehicle 0.03, ShieldProp/Boxing/Landmine/Flamer/LaserGun/TripleShootGun/ShotGun 0.01 each, LifeProp/Invincibility/Hammer 0.005. Kill and GreenZone favour weapons. PacMan has Speed 0.4, Invincibility 0.3, Shield 0.25, Life 0.05.
- [S] The vehicle class depends on the stage: Zoo Horse/Dragon, CandyFactory/Cinema Moto/Car, BirthdayParty/MagicLibrary Horse/Moto, LuxuryStores Car.
- [S] On death in non-Arcade modes, the robot spits its collected props and up to 2 weapons (`RobotDeadCommand.spitProp`).

## 7. Controls / input (`zb/gameengine/robot/PersonInteractiveController.as`, `zb/ui/HowToPlayUI.as`)
- [S] Defaults, if nothing is saved in the SharedObject "Bomb_It_5": `[38,37,40,39,32, 87,65,83,68,32, 38,37,40,39,13]` (`HowToPlayUI.as:309`). 1P: arrows + Space. 2P P1: WASD + Space. 2P P2: arrows + Enter. This matches. `UIManager.gamePlay` always runs `HowToPlayUI.saveKeys()` before a game (`UIManager:316-318`), so defaults are applied even if the controls screen was never opened.
- [S] Movement: each KEY_DOWN starts that direction once (latched with `_XStage` flags, `:49-84`). KEY_UP stops that direction (`:86-109`). A second listener pair keeps `funcDelay` = last pressed direction and clears it only if the released key is that one (`:170-215`). This matches last-pressed priority. [U] How `funcDelay` is consumed (e.g. at cell alignment), see `RobotController`.
- [S] Rebinding allows letters, digits, arrows, punctuation, and for bomb also Space/Enter/Tab/Esc/F1–F8/numpad (`HowToPlayUI:160-240`).
- [S] P pauses. Space resumes from PauseUI.

## 8. HUD (`zb/ui/GameInterFace.as`, `GameConfig.INTERFACE_*`)
- [S] 4 player panels down the left side at x=31, y = 24/120/215/309 (robot icon at 24, 21/116/211/308). Each shows life, bomb count, power, speed, score (or coins / tiles depending on mode via `scoreStr`), and a face MC (frame 4 = dead).
- [S] Global: time (`set time`), current level, pause button. [U] Exact pixel layout of the time/level fields. See the `UI_interface` symbol and images.

## 9. Characters
- [S] 8 robots `_r0`..`_r7` (`TOTAL_ROBOT = 8`). They have walk, dead, and ride animations (Car, Elephant, Skateboard, forg = frog) and `r*_progress` symbols. They have cloth and hat unlocks (`Unlock.xml`, `zb/ui/unlockCloth`). [U] Display names. No name strings were found; names may be baked into art.
- [S] AI in Arcade: speed 1.6, bombPow 1, and it reacts every 30/20/20 (aiAnswerTime) with findRange 5/6/7 by difficulty (XML `GameAI`).

## 10. Items
| Item (class, `_propNum` icon frame) | Effect [S] |
|---|---|
| NumProp (1) "BOMB +1" | allowBomb +1 up to 9 |
| PowProp (2) "POWER BLAST +1" | bombPow +1 up to 5 |
| SpeedProp (3) "SPEED +10%" | robotVelocity +0.1 up to XML max 2.3 (base 1.6) |
| LifeProp (4) "LIFE +1" | `addLife()` |
| BombShoesProp (6) "PUSH THE BOMB" (XML comment 手套 = glove) | **Glove = kick.** Walking into a bomb launches it at speed 7 in the facing direction until it hits something (`items/tools/BombShoesProp.as`, `Bomb.startFly/kickedFly :512-535`). Has no effect while riding a vehicle. |
| InvincibilityProp (7) | 10 s × FRAME_RATE frames invincible (`:51`) |
| ShieldProp (22) | absorbs a hit (`shieldObj`). Easy AI cannot take it. |
| CoinProp (36) | Collect mode coins |
| Weapons: Boxing (38) "BOXING GLOVE", LaserGun (20) "LIGHTNING GUN", TripleShootGun (50) "MACHINE GUN", Hammer (15), Launcher (16) "FIREBALL LAUNCHER", Grenade (26), Flamer (21) "FLAMETHROWER", ShotGun (49), WaterGun (25), Landmine (39) | They replace the bomb key: down = `bombDown` (plays the weapon and consumes a use), up = `bombUp` (`items/weapons/AbstractWeapon.as:~85-140`). [U] Per-weapon range, uses, and damage. Not extracted yet. |
| Rides: Car (45), Horse (46), Moto (48), Dragon (47) | Change speed (XML rides: car 1.6, dragon 0.8, hoover 1.2, horse 1, moto 1.3) and absorb one hit |
- **Glove / bouncer / magic carpet / heavy bomb:** I searched all identifiers and strings (case-insensitive glove|bounce|bouncer|carpet|heavy). [S] There is no bouncer, magic carpet, or heavy bomb class or string in this SWF. The only "glove" items are BombShoesProp (kick, labelled 手套 in XML) and BoxingProp ("BOXING GLOVE", a melee weapon). [I] Those four items come from a different Bomb It entry, so the research list does not match BI5.
- [S] JumpTable redirects kicked bombs at speed 10 (`Bomb.changeBombDirection`).

## 11. Localized text
- `strings/localizationpack-zh-en.tsv`: the LocalizationPack has only 4 zh-CN entries (loader/branding: 载入中…, 炸弹人5, 开始游戏 …). The other locales cover the same Spil branding.
- `strings/static-texts.tsv`: all 492 DefineText strings. In-game UI text is English (e.g. "GAME SETTINGS", "PUSH THE BOMB", "TIME'S UP!", "LEVEL [X]/[X] COMPLETE!"). The 82 CJK strings are map-editor legend labels inside the stage symbols. [I] The "zh-fix" build is the English game with a Chinese loader/portal wrapper.

## 12. Contradictions / additions vs existing research
- All six research claims are confirmed. Nuances: the SWF header says 30 fps before the 35 is applied; bomb has no dedup, but there is a one-bomb-per-cell guard; and `__cheat__` is unused, but there is also `CHEAT_UNLOCK_ALL_CLOTHES=false`.
- New: the round timer uses wall-clock seconds, not frames. Arcade time-up always counts as a win (bug). "Lives" are level retries in Arcade. The glove/bouncer/carpet/heavy-bomb set is not in BI5.

## Open unknowns
- Player base movement units: moveSpeed 1.6 is px/tick? Cell alignment and turn-assist behavior (`HitMove.as`, `RobotController`), and how `funcDelay` is applied.
- Duration of the post-hit invincibility (`InvincibilityCommand`). Shield use count.
- Per-weapon stats. Vehicle hit and dismount details.
- Where `boxPoint` enters the score totals. Kill/GreenZone/PacMan scoring and win checks (only Arcade was read in depth).
- Character display names. Exact HUD and timer art layout.
- Map skin frame numbers (`beginNum`, `fixedPropNum` per set) only affect visuals and are not mapped to images.
- Runtime confirmation of the static map reading (needs a playable Ruffle session; the web build works).
