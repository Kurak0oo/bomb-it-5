# Edition 5 modes, menus, progression and unlocks

Static recovery, 2026-10-21, for the [complete-game scope](../../DESIGN.md)
(ADR 0007). It covers what the current evidence did not: the four selectable
modes, difficulty, the menu and settings flow, level and stage progression, scoring
per mode, unlocks and saved data. Only Normal Arcade on Cinema has runtime
observation; everything else here is static source reading and needs runtime
confirmation before parity is claimed.

## Source

- Build: publisher SWF `agame-bomb-it-5-zh-fix.swf`, SHA-256
  `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`, 6,942,081
  bytes, the retail build recorded in [input and timing](edition-5-input-and-timing.md).
- Scripts: JPEXS FFDec 26.3.0 `-export script` into
  `.scratch/edition-5-research/publisher-scripts/` (1,068 `.as` files). Locators
  below are relative to `scripts/zlong/bombit5/`; class and method names are the
  durable locators.
- Embedded data: `-export binaryData` into `.scratch/edition-5-research/publisher-binary/`:
  the mode/AI rules XML (`XmlManager_xmlClass`, 26,904 bytes) and the unlock XML
  (`XmlManager_unlockXMLClass`, 2,724 bytes).
- Bytecode: `-format script:pcode -selectclass zlong.bombit5.gameengine.Game,zlong.bombit5.gameengine.gamemode.AbstractGameMode`
  for the XML lookups noted under soft blocks.

## Screens and flow

`ui/UIManager.as` wires the screens:

- Main menu (`MainMenuUI`): START → Game Settings; HOW TO PLAY → controls;
  MORE GAMES opens a publisher URL. Sound, music and quality toggles.
- Game Settings (`GameSettingsUI`): players, mode, enemies, levels, stage,
  difficulty → character select.
- Character select (`CharacterSelectUI`, `unlockCloth/ClothesPanel`): robot,
  body icon and hat per player; START builds the game (`UIManager.gamePlay`).
- How to Play (`HowToPlayUI`): key rebinding for 1P and both 2P players, saved
  with `saveKeys`; `PowerUpsUI` describes the pickups.
- Pause (`PauseUI`, P key or HUD button): RESUME, MAIN MENU, sound/music/quality.
- Score screen per level (`OnePScoreUI` via `PlayerScoreUI`): NEXT LEVEL or
  RESTART (also Space), DRESS UP, MORE GAMES. Game over / game win
  (`OnePGameOverUI`) returns to Game Settings.
- Portal-only features also exist (avatar upload screens, `AwardSender`
  achievements, analytics); they are not game rules.

## Controls and rebinding

`HowToPlayUI` defaults are arrows and Space for one player (`38,37,40,39,32`). A
control may take a key from `_asciiMove` (letters, digits, arrows, `~ , . ; ' [ ] - +
\ /`); the bomb key also takes `_asciiBomb`'s Space, numpad, F1–F8, Tab and Esc.
`MyTextField` refuses a key already used by another control or P (80, pause), with
"This key is not possible.Please choose a different key." SAVE writes the keys to
the SharedObject ("Custom controls saved."); BACK without SAVE restores the keys
the screen opened with (`saveDefaultData`). Power-up guide names are in the static
texts: BOMB +1, POWER BLAST +1, SPEED +10%, LIFE +1, SHIELD, INVINCIBILITY, PUSH THE
BOMB, BOXING GLOVE; weapons LANDMINE, FLAMETHROWER, LIGHTNING GUN, HAMMER, MACHINE
GUN, FIREBALL LAUNCHER; vehicles SPORT CAR (`CarProp`), SKATEBOARD
(`MotoCycleProp`), FROG (`HorseProp`), MAMMOTH (`DragonProp`, `_Elephant`).

## Settings

`GameModel` defaults (`GameModel.init`): 1 player, Arcade, 3 enemies, 5 levels,
random stage, **easy**. `GameSettingsUI`:

- Modes: Arcade, Kill, Pac-Man (1 player only; selecting it forces 1P), Green Zone.
  Speed, Water, Collect and Painting classes exist but have no button.
- Enemies 1–3 for one player. Zero enemies is only enabled for two players outside
  Arcade (`initData` enables/disables the toggles).
- Levels: buttons named five/ten/fifteen/twenty set **1**/10/15/20
  (`levelsHandle`). The default of 5 is reachable only by never touching the
  levels row. Treat the "5 sets 1" mapping as a source defect.
- Stage: random or one of Birthday Party, Candy Factory, Cinema, Zoo, Luxury
  Stores, Magic Library.
- Difficulty: easy, normal, hard.

## Levels, stage sets and lives

- A session is `levels` rounds. Winning a round before the last level shows
  LEVEL_WIN and advances; winning the last shows GAME_WIN (`AbstractGameMode.winHandler`).
- Every mode starts humans with 3 lives (`personLife="3"`). Each lost round costs
  every human one life; with lives left the round restarts (LEVEL_RESTART),
  otherwise GAME_OVER (`loseHandler`). Life pickups add lives.
- Random stage: the first set is drawn from all six; each level win draws another
  set without repetition, refilling the six when exhausted (`gamePlay`,
  `gameReStart(false)`). A restart after a loss keeps the set
  (`gameReStart(true)`) and re-rolls its layout, matching the observed Cinema
  re-rolls in the [Dots report](observations/swf-v1.6.1/REPORT.md). The
  `gameLostStages` branch is dead: nothing assigns it. A chosen stage repeats its
  set every level.
- Layouts: each set has three normal layouts and three Pac-Man layouts, all
  transcribed in [the recovered maps](observations/swf-v1.6.1/maps/INDEX.md); a
  round picks one at random (`AbstractMapData.data`).

## Soft blocks (correction)

`Game.mapInit` overwrites the 0.8 default in `AbstractMapData.unfixNum` with
`XmlManager.xml.box[difficulty][gameMode]`. The bytecode reads the last step as a
runtime attribute (`MultinameLA`). XML `box`: Arcade **0.6**, Kill **0.55**,
Pac-Man and Green Zone **0** (no soft blocks), identical across difficulties.

Runtime agrees: the recorded CinemaStage1 start has 68 soft blocks in 110
candidate cells ([board record](cinema-stage1-recorded-board.md)), 62%. A 0.6
roll expects about 66 (σ≈5); 0.8 expects about 88 (σ≈4). This corrects the 0.8
probability stated in the [movement/board record](edition-5-movement-and-board.md)
and the imported Dots report. The fixed practice instance is unaffected.

## Modes

All four use `totalTime=180`, `personLife=3`, `aiLife=1`, `propborn=200`
(rules XML). Respawn delay is `reborn` = 1 second in every mode and difficulty,
read through the same attribute pattern (`AbstractGameMode.init`, `ReliveThread`).
Spawns are the four corners (`GameConfig.ROBOT_*_POSITION`).

| | Arcade | Kill | Green Zone | Pac-Man |
| --- | --- | --- | --- | --- |
| Soft blocks | 0.6 | 0.55 | none | none |
| Respawn | none in the round | AI and humans after 1 s | AI and humans after 1 s | AI after 1 s; human death loses the round |
| Base action | bombs | unlimited hammer (`KillModeWeapon`) | unlimited hammer | human: none (`NullWeapon`); AI: unlimited flamer (`PacModeWeapon`) |
| Round point | — | kills; own-bomb death −1 (`killSelfHandler`) | flags captured | coins eaten |
| Win | all AI dead | first human to 10 | first human to 10 flags | every coin eaten |
| Lose | all humans dead | an AI reaches 10 first | an AI reaches 10 first | human dies |
| Timeout | source: always a win (defect; the accepted adaptation makes it a loss while enemies remain) | win unless some AI has more kills than the human; ties win | same comparison on flags | loss |

Sources: `gamemode/ArcadeMode.as`, `KillMode.as` (`end`, `judgeHandler`),
`GreenZoneMode.as` (`judge`, `judgeHandler`, `mapLoadOver`), `PacManMode.as`,
`Game.judgeGameWin` (point ≥ `levelWinNum` → human WIN, AI LOSE),
`AbstractPlayer.updateGameModeData` / `PersonPlayer.updateGameModeData`.

Mode details:

- **Kill:** points are `killNum` (`AbstractPlayer.killNum` setter); a robot that
  dies to its own bomb loses one point if it has any. The HUD score turns
  highlighted at `textColNum=8`.
- **Green Zone:** one Flag spawns at a free cell at least two cells from the
  edges (`AbstractMoveObject.containerMove(map,2,2,2,2)`), plus two random
  pickups. Standing on it fills a per-robot progress bar by 1 per frame and
  leaving drains it by 1; a full bar (`flag` × 35 = 105 frames on every
  difficulty) scores +1, and the flag moves after a 3-second host delay
  (`maps/platform/Flag.as`). Player move speed is 1.8 in this mode (rules XML
  `player`).
- **Pac-Man:** coins fill every empty cell after four pickups are placed in
  separate non-adjacent quadrant cells (`itemPosSetting`). Bombs and blasts skip
  AI robots (`AbstractBomb.as:64`). Invincibility lasts 5 seconds instead of the
  usual duration (`InvincibilityCommandChain`). AI eat no pickups (empty
  `propsEated.ai`). Easy places a shield on the human spawn, as Arcade does.
- **Arcade:** unchanged from the [runtime systems record](edition-5-runtime-systems.md).

Timed pickups (`timePassed`): Arcade after 45 s, Kill after 45 s, Green Zone and
Pac-Man after 10 s, then every 15 s: two pickups, one in Candy Factory, none in
Magic Library (Arcade gives Magic Library one; Pac-Man gives Candy Factory two).
Drop tables per mode are in the rules XML `prop` blocks: Kill and Green Zone
favour weapons, Pac-Man only speed, life, shield and invincibility.

## Difficulty

From the rules XML unless noted:

- Drop chance per broken block: easy 0.6, normal 0.5, hard 0.4 (`propProp`,
  `MapMaster`).
- Danger perception: 0.9 / 0.95 / 1 (`dangePerceive`).
- Easy Arcade and Easy Pac-Man give each human a shield on its spawn cell.
- Level bonus `DIFF_POINT`: 1000 / 2000 / 3000 (`GameConfig`).
- AI profile per mode and difficulty (`<ai>` ids `MMDD01`, mode 01 Arcade,
  02 Kill, 03 Pac-Man, 04 Green Zone): answer time, find range, speed, bomb power,
  and weighted states. Arcade uses Attack/Evade/GetItem/Box/Free (hard adds
  Idle), Kill adds Idle, Green Zone adds Flag/Defence, Pac-Man uses
  Follow/Escape/Free. Each AI picks a random robot and look
  (`AbstractGameMode.createAIPlayer`).

## Scoring

Arcade is in the [runtime systems record](edition-5-runtime-systems.md). Other
modes compute a level score at the end (`countScore`): Kill `kills × 100`, Green
Zone `flags × 100`, Pac-Man `coins × 10`; a win adds remaining seconds × 10 and
the difficulty bonus, a loss adds neither. Totals carry across the session.

## Unlocks and saved data

- Eight robots (`TOTAL_ROBOT`), each with eight unlockable looks from the unlock
  XML (`sets id = robot + 1`). Most robots have `hat1`–`hat3` then `icon1`–`icon5`
  (body outfits); robots 3 and 7 have four hats and four outfits, robot 4 two hats
  and six outfits.
- `ClothesPanel` wears one hat and one outfit at a time; clicking the worn one
  removes it (id 0); locked looks cannot be chosen and show "Score [x] points to
  unlock this outfit". AI players get a random outfit and hat 0–6 without unlocks
  (`AbstractGameMode.createAIPlayer`); the port keeps them within the robot's set.
- `Cookie.unlockAvatar` only unlocks for a logged-in portal user when
  `Root.__lockContent__` is set; the port has no accounts and always unlocks.
- On each score screen, the robot's look *n* unlocks when the session total
  reaches `UNLOCK_SCORE_n`: 2,500, 7,200, 12,000, 19,200, 24,000, 31,200, 36,000,
  48,000 (`GameConfig`, `OnePScoreUI.unlockCloth`). A tip screen announces it;
  DRESS UP opens the clothes panel.
- A local SharedObject (`data/Cookie.as`) keeps music/sound toggles and unlocks;
  key bindings are saved separately (`HowToPlayUI.saveKeys`).

## Stage-set map features

Only Cinema portals are implemented today. Recorded layout tiles
(cell counts over the [recovered maps](observations/swf-v1.6.1/maps/INDEX.md))
and the map-data classes give, per set: Zoo crocodiles (14 cells; blasts pass
through), Birthday Party toy hands (9), Candy Factory conveyor belts (99) and
sliding platforms (28), and Magic Library spellbooks, which
`MagicLibraryMapData` creates on its center-building cells. Luxury Stores has no
special tile. Five map-data classes can create a `LavaOrgan` from a `lavaOrgan`
instance, but no recorded layout contains one. Vehicles differ per set
(`AbstractGameMode.initMap`). Each feature needs its own recovery record before
porting.

## Uncertain or unobserved

- No runtime observation of Kill, Green Zone, Pac-Man, Easy or Hard yet.
- How a Pac-Man human removes an AI (invincibility contact is the likely path) is
  not traced.
- The 1-second respawn relies on the same attribute lookup that runtime confirms
  for soft blocks; it is not separately observed.
- Character-select look restrictions and AI look choice need a closer read.
- MORE GAMES, avatar upload, achievements and analytics are excluded by the
  accepted scope.
