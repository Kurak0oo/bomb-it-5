# Sound and music (#75)

Authority build `agame-bomb-it-5-zh-fix.swf` (sha256 `718c04c7…0408a2`). Static source from the
FFDec 26.3.0 script export. Sounds were exported with FFDec
(`tools/art_pipeline/original_audio.py`).

## Pack

The SWF has 52 `DefineSound` tags:

- **37 class-linked sounds, all MP3.** `original_audio.py` copies them unmodified to the
  ignored `original/audio/<Class>.mp3` and lists them in `original/audio/index.json`.
- **15 timeline sounds.** These have no class and play only inside the publisher intro
  sprite `Art_A10`, along with three stream sounds in its sub-sprites. They are not copied.

`scripts/original_audio.gd` plays sounds by class name. Without the pack, or for a class the
SWF never defines, it stays silent.

## Sound manager (`ui/SoundManger.as`)

- **`createSound(name)`.** Plays only while the sound switch is on. It looks the class up by
  name and drops it silently if the lookup fails (`try`/`catch`). Sounds are keyed by name in
  `_soundArr` and played by a `setTimeout(…, 0)` after the current frame, so one class plays
  at most once per step. The replica de-duplicates each step's list
  (`BombSimulation.play_sound`) and plays it when the step is committed.
- **Switches.** `soundSwitch` and `musicSwitch` are stored as `Cookie.soundEnable` and
  `Cookie.musicEnable`, which default to true. They are a local `SharedObject`, so they
  persist across sessions. The replica saves them in the local save file (`SaveStore`
  `sound`, `music`).
- **Menu music.** `createUiMusic` loops `uiMusic`:
  - It starts on the first menu (`UIManager`). The original waits for a mouse move when the
    game is not the first load; the replica starts at once.
  - It starts again on returning to the main menu (`firstUi`), after `mainMenu` has dropped
    the round's music.
  - `gameStart` stops it before the board loads (`nullUiMusic`).
  - On the main menu, the music switch also stops it (`closeUiMusic`) or starts it
    (`startUiMusic`).
- **Round music.** `createMusicOrder` puts `gameMusic_1` first, then `gameMusic_2` and
  `gameMusic_3` in an order drawn once per run. `createGameMusic` loops the current track and
  moves `levelMusicNum` on, modulo 3, even with music off.
  - Rounds start it in `gameStartHandler`.
  - `pauseGameMusic` stops the channel. `restartGameMusic` plays the same track again from 0,
    even though the paused position is stored.
  - A pause cancelled inside its 100 ms window calls `createGameMusic` again.
  - The pause screen's music switch only sets the flag. Turned off there, the round stays
    silent after resume. Turned on there, the paused track resumes.
- **Endings.** `win` and `lose` call `stopPause` (which pauses the music), then
  `playWinMusic` or `playLoseMusic`. Those drop the round music and play `levelComplete` or
  `levelFailed` once. `OnePGameOverUI` calls `createOverUiMusic`: the menu music starts at once,
  or after the jingle if it is still playing. The score screen between levels has no music
  call.

## Event map

| Class | Source | Replica event |
| --- | --- | --- |
| `addBomb` | `Bomb.init` → `addBombSound`; also landmines, fireballs and triple shots, which subclass `Bomb` | bomb placed; mine laid; each projectile |
| `bomb` | `Bomb.takeCount` on detonation (chains via `BLAST`); `LandmineBomb`, `FireballBomb` and `TripleShootGunBomb` on a hit | every detonation; a projectile stopping |
| `dead` | `AbstractRobot` death | a robot dies |
| `useNombril` | `TryToKillCommandChain` with a shield | a shield absorbs a hit |
| `eatProp` | `GetItemCommand` | any pickup collected by walking onto it |
| `getCar`, `getPlane`, `getFog`, `getDragon` | `CarProp`, `MotoCycleProp`, `HorseProp`, `DragonProp` `changeStage` | car, moto, horse, dragon taken (also when punched in) |
| `InvincibilitySound` | `InvincibilityProp.changeStage` | invincibility taken |
| `useSinker` | `HammerProp`/`LandmineProp` `_weaponSound`, played in `AbstractWeapon.bombDown` | hammer swing, mine laid |
| `useThrower` | `FlamerProp.bombDown` | flamer |
| `useLaserReady`, `useLaserShoot` | `LaserGunProp.bombDown`, `Laser.init` | laser charge, laser beam |
| `useShotgun` | `TripleShootGunProp` | triple shot |
| `useBoxing` | `BoxingProp.bombDown` | punch |
| `lavaOpen` | `Crocodile`, when the mouth opening completes | crocodile frame 264 |
| `toyHandOpen` | `ToyHand` opening | toy hand opens |
| `spellOpen` | `Spellbook` flip after `FLIP_DELAY` | spellbook flip |
| `menuTouch`, `menuPress` | menu buttons on `MOUSE_OVER` and `MOUSE_DOWN` | `UiKit.button` hover and press |
| `uiMusic`, `gameMusic_1–3`, `levelComplete`, `levelFailed` | `SoundManger` (above) | menus, rounds, endings |

## Silent in the original

These names are called but no class exists, so `createSound` drops them:

- `useBowling`, the fireball weapon's sound (`ShotGunProp`).
- `robotfall` (`AbstractRobot.fall`).
- `sheepfall`, `piranhaOpen`, `fireworkExp`, `passCheckPoint`, `unlockclothes` and
  `useWatergun`. These come from unported modes and stages.

The replica raises the same names, and they stay silent.

These classes exist but no code plays them: `selectPress`, `selectTouch`, `conveyorOpen`,
`light1`, `light3`, `unlock`, `useNinja`, `useGrenade` and `useLauncher`. Grenade and
launcher are unported weapons. `loadingBomb` plays on `LoadingMapUI`, and the replica has no
loading screen.

## Not ported

- The publisher intro's timeline sounds go with the publisher screen (#76).
- The original's wait for a first mouse move before menu music on a reload has no
  equivalent. The replica starts the music with the first menu.
