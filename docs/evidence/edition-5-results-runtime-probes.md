# Original death, results, hearts and session totals

Recorded 2026-10-19 for [recovery #36](https://github.com/Kurak0oo/bomb-it-5/issues/36), using the unchanged publisher SWF. Six replayable cases cover human defeat, an elimination win with zero human kill credit, a credited weapon win, both bomb-owner variants of simultaneous human/last-enemy death, life collection, Retry, Next, three losses through Game Over, and the following fresh session.

The original distinguishes a dead robot, removal from active registries, completion of its death animation, mode judgment, the ending cartoon, and score settlement. Session hearts are not the robot's immediate health. Both simultaneous-death cases chose defeat. HUD awards and final level-score formulas are different: observed HUD score 210 became final level score 4050, rather than adding those 210 points to the final formula.

## Authority and method

Original movie: `.scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf`, SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`. Pinned Ruffle revision: `45366370ed7d1a59c89aa3cf7b765c7a274407cd`.

The first life/retry run uses preserved `reference-player-recovery/probe.exe`, SHA-256 `e9c9f65d03c3af960d84934e0becee5d65de3d23d70f9ea2e725418aabf63292`. The other five use `reference-player-recovery-v2/probe.exe`, SHA-256 `5a7adba2c2781818a418f19f5976bad1917b8c64568fd7b562a7660bdc99bb74`, under `.scratch/edition-5-research/`. Their adjacent build manifests identify the source and optional instrumentation. See [trace design](edition-5-reference-trace-design.md) for the read-only observer and active original-method fixture distinction.

All cases begin through the original Normal Arcade/Cinema menus with seed 42 applied before the first frame. Selected setup operations call the original AI stop methods, guarded view/controller reposition route, pickup constructors, or selected actor's original `controller.addBomb`. There are no health, score, outcome, budget, raw occupancy or timer writes. Human bomb placement/retreat and the hammer strike are actual key input. Enemy-owned self-bombs are explicitly controlled original-method setup, not evidence of naturally chosen AI tactics. AI stop does not cancel delayed state/Tween callbacks; existing delayed AI actions still occur in these runs.

The fixture return values refine that setup: in the zero-kill case, actors 1 and 2 already own original bombs at opening, so their requested `addBomb` calls return `placed=false`; only actor 3 returns `placed=true`. The case's `origin` text records the investigator's intention to arrange three self-bombs, not three successful new placements. In the simultaneous cases, the first two enemies likewise die from their already-existing owned bombs. The fixture-result JSON and subsequent bomb/death traces are the authority for what actually happened. These observations do not attribute those first two bomb creations to the fixture.

The driver stages byte-identical movie bytes at a safe temporary URL, verifies hashes and frame acknowledgements, and captures 700×510 original screenshots. `realtime 1` is enabled in the ending waits to let original wall-time Tween callbacks complete. Earlier frame stepping and observation remain different from realtime play; original Date time bonuses can vary with host/observation cost. Explicit seed 42 is not a deterministic-clock claim.

## Replays and retained evidence

Each curated directory contains the exact case, manifest, commands, fixture results, selected original call/return events, interpreted snapshot boundaries, and hashed original screenshots. Per-frame CSVs retain the focused death/animation state where enabled. Large raw JSON graphs remain in ignored research storage.

| Checked-in case under `tools/reference_player/cases/results/` | Final raw directory under `.scratch/edition-5-research/reference-runs/` | Curated evidence |
| --- | --- | --- |
| [01-loss-retry.json](../../tools/reference_player/cases/results/01-loss-retry.json) | `results-loss-retry-42-02` | [Life and Retry](reference-2026-10-19/results/life-and-retry/summary.json) |
| [02-zero-kill-win-next.json](../../tools/reference_player/cases/results/02-zero-kill-win-next.json) | `results-zero-win-42-01` | [Zero-kill win, Next and loss](reference-2026-10-19/results/zero-kill-win/summary.json) |
| [03-hearts-game-over.json](../../tools/reference_player/cases/results/03-hearts-game-over.json) | `results-hearts-42-02` | [Hearts, Game Over and new session](reference-2026-10-19/results/hearts-game-over/summary.json) |
| [04-simultaneous-human.json](../../tools/reference_player/cases/results/04-simultaneous-human.json) | `results-simultaneous-human-42-01` | [Human-owned simultaneous death](reference-2026-10-19/results/simultaneous-human/summary.json) |
| [05-simultaneous-enemy.json](../../tools/reference_player/cases/results/05-simultaneous-enemy.json) | `results-simultaneous-enemy-42-01` | [Enemy-owned simultaneous death](reference-2026-10-19/results/simultaneous-enemy/summary.json) |
| [06-hud-awards-win.json](../../tools/reference_player/cases/results/06-hud-awards-win.json) | `results-hud-win-42-01` | [HUD awards and credited win](reference-2026-10-19/results/hud-awards-win/summary.json) |

Example reproduction, with a new output directory:

```powershell
python tools/replay_reference.py --player .scratch/edition-5-research/reference-player-recovery-v2/probe.exe --case tools/reference_player/cases/results/04-simultaneous-human.json --observe --focus --fixtures --output .scratch/edition-5-research/reference-runs/results-simultaneous-human-new
```

[summarize.py](../../tools/reference_player/cases/results/summarize.py) rebuilds each curated directory using `--run RAW --output CURATED --pictures CAPTURE_NAMES`. It checks event overflow/drop metadata and uses [FocusGraph](../../tools/inspect_reference_focus.py) to resolve physical slots and namespace aliases without guessing omitted data. Across these six final runs there are **565 focused per-frame observations and 311,196 original execution events**, with zero drops/overflow. Curated directories have `.gdignore` files; original reference art is not production artwork.

Two winning runs each contain one **caught original sound lookup error**: `SoundManger.creatMusicClass("unlockclothes")` raises ReferenceError at frames 951 and 1060 respectively. The original `SoundManger.createSound` catches `Error`; score settlement and subsequent UI actions continue. Those error records and player logs are retained. These runs must not be described as having no original exceptions.

## Death is not immediate result settlement

Static source paths below are relative to `.scratch/edition-5-research/publisher-scripts/scripts/zlong/bombit5/`.

1. `commands/robot/TryToKillCommandChain.as:34–77` checks `isExist`, dead state, vehicle and shield before taking the death path. `isExist` is damage eligibility, not liveness.
2. `gameengine/robot/AbstractRobot.as:233–245,278–283` stops input, unregisters movement/robot callbacks and `Game.robots`, marks the model dead, removes map occupancy, and selects the death movie.
3. `commands/robot/RobotDeadCommand.as:32–58` registers `countDead`. It manually advances the original death movie and calls `Game.deleRobot` only when the movie reaches its final boundary.
4. `gameengine/Game.as:deleRobot` records `deadRobotPlayer` and calls the mode's `end`. `gamemode/ArcadeMode.as:106–137` deletes that player's robot, counts the remaining registered humans/AI, checks zero humans first, and then zero AI.

The life/retry trace illustrates the separation. Human hearts are 4 after LifeProp collection at 722; the human model becomes dead at 795 and leaves the active robot registry while hearts remain 4. Its death movie is at frame 2, then 3 on the next observed callback. The first later mode judgment is at 840, triggered by an AI's animation-completion `Game.deleRobot` callback; it already sees zero registered humans and starts defeat. **It need not wait for the human's own death animation to be the callback that triggers judgment.** The later loss callback at 944 changes hearts from 4 to 3, creates the restart result and tears down the round.

The original actor/player distinction also persists across Retry/Next: an existing player object gets a fresh robot. It is not a robot immediately respawning by spending one heart at damage time. The first life/retry run retains the same human player reference with hearts 3 after Retry and new active robots.

## Simultaneous human and last-enemy death

Both cases first remove two opponents through original enemy-owned self-bombs. The last enemy is relocated to empty adjacent floor `(2,1)` beside the human at `(1,1)`. One ordinary bomb then hits both in the same original callback; one case uses the human bomb, the other the last enemy's bomb.

| Boundary | Human-owned bomb | Enemy-owned bomb |
| --- | --- | --- |
| Frame 912 | Both normal and registered | Both normal and registered |
| Frame 913 | Both dead; active robot registry empty | Both dead; active robot registry empty |
| Frame 967 | Human death movie frame 56; no result settlement yet | Human death movie frame 56; no result settlement yet |
| Frame 972 | `Game.deleRobot` → `ArcadeMode.end` → `lose` | Same defeat branch |
| Frame 1076 | One `countScore(false)`, level/total 300, hearts 3→2 | One `countScore(false)`, level/total 0, hearts 3→2 |

The human-owned explosion processes the human death before the enemy death; the enemy-owned explosion processes the enemy death before the human death. The event order changes but both enter defeat. The source's zero-humans-first condition explains that observed result. The human-owned case still credits the enemy kill to the human and uses it in the losing score; defeat does not erase valid kill credit. This does not prove every simultaneous chain/weapon ordering; [chain recovery](edition-5-gameplay-phases.md) remains a separate source/ordering concern.

## Ordinary victory, ending controls and teardown

The zero-kill run has no human attack in its first round. At 794, all AI are dead and only the human remains registered; the original mode starts `win` at 840. `GameEndCartoon` projects `winCartoon` frame 1 at 840 and frame 4 at 841. Its completion calls `winHandler` at 939. Thus ordinary elimination victory requires no player-attributed kills and is distinct from timeout completion.

Observed calls at ending start include `Game.stopPause`, `GameEngine` teardown, pause-button disabling and `afterStopPause` actor/input shutdown. Static source `Game.as:671–694` immediately stops/disposes the engine, sets `gameOver`, disables pause, and schedules a 10 ms callback that disposes visible weapons and stops remaining actors. The recorded callback runs under the same harness frame label in these observations; that does not mean the original timer has zero delay. Surviving human state remains normal/registered during the cartoon while its damage eligibility becomes false. After settlement, `overInit` deletes remaining robots, clears per-round points, removes the world/interface, and nulls `gameEngine`; the selected result UI remains.

`ui/GameEndCartoon.as:35–59` uses a three-second TweenMax to the ending movie's last frame, then removes the cartoon and calls the supplied result handler. Measured callback frames differ by run/host cost (99–105 steps in these ending windows); a universal fixed frame duration must not be inferred. No separate held-input stress test during the ending was performed; the control/teardown claims above are the observed original calls and stored state.

## HUD awards, result formulas and cumulative totals

The HUD-award case uses a legal bomb at `(2,1)` and retreats to safety. It destroys an actual block at 804; later a naturally collected HammerProp and legal hammer strike kill the last enemy.

| Original call/frame | Human value observed |
| --- | --- |
| 804, `boxPoint` / `scoreData` | Block award +10; HUD 10 |
| 863, `itemPoint` / `scoreData` | Pickup award +100; HUD 110 |
| 887, `modePoint` / `scoreData`, `killNum` | Kill HUD award +100; HUD 210; one attributed kill |
| 1048, `countScore(true)` | Kill component 300, time 1750, Normal difficulty 2000; final level and total **4050** |

Source `AbstractPlayer.as:213–277,283–328` implements the HUD setter side effects and memorycrypto-backed level/total/kill/time values. `GameConfig` supplies block 10, pickup 100, kill HUD 100, and difficulty bonuses 1000/2000/3000. `ArcadeMode.as:139–169` independently settles:

```text
win:  kill component = killNum * 300
      time = (gameTime - pastTime) * 10
      difficulty = selected difficulty bonus
loss: kill component = killNum * 300; time = 0; difficulty = 0
both: level = kill component + time + difficulty
      total += level
```

Setting the kill component during settlement itself briefly invokes the HUD score side effect (the credited-win trace observes 310), before the explicit final level setter overwrites that same encrypted level storage with 4050. This is not another settlement. Block/pickup HUD awards are not independently added to the final formula. Private `_levelPoint`, `_totalPoint`, `_killNum` and `_timePoint` slots are not their live oracle because the actual getters/setters use memorycrypto; this report uses the executed original calls and visible result fields, not their stale private defaults.

In the zero-kill run, the first settlement writes `0 + 1740 + 2000 = 3740`, total 3740, and leaves hearts 3. Space triggers `gameReStart(false)` and a fresh level-2 round. The next loss writes level 0 and **total 3740**, then spends one heart (a prior LifeProp made hearts 4, so settlement leaves 3). Next and Retry retain session totals/player identity while recreating the round. Each traced ending executes `countScore` exactly once; neither the remaining idle result frames nor the following Space action settle that round again. The six runs contain nine settlements total.

## Hearts, Game Over and fresh session

LifeProp collection invokes `PersonRobot.addLife` → `player.life += 1`, proven here by 3→4. Death leaves that count untouched; `AbstractGameMode.loseHandler` decrements each human's heart count at settlement. Three ordinary losses from the unmodified initial hearts produce:

| Settlement frame in `results-hearts-42-02` | Hearts | Result path |
| --- | ---: | --- |
| 945 | 3→2 | `LEVEL_RESTART` (3), Space Retry |
| 1319 | 2→1 | `LEVEL_RESTART` (3), Space Retry |
| 1726 | 1→0 | `GAME_OVER` (4), immediate final Game Over UI |

[The original Game Over capture](reference-2026-10-19/results/hearts-game-over/loss-life-0.png) shows the final score and Try Again. Clicking it at 1779 enters `PlayerGameOver.backHandle`, runs `GameModel.init`, and returns to settings. The following ordinary menus start a new player/game at hearts 3 and level 1. Source defaults are Easy/Random/five levels, so this fresh-session probe is deliberately **not another Normal Cinema round**; its capture shows the generated Candy-family board and Easy's initial shield/pickup HUD award. Game disposal clears old session total storage; per-round clearing during Retry/Next does not clear accumulated totals.

`ui/PlayerScoreUI.as:187–225` maps Space/Next to restart(true), next level(false), or final Game Over according to `GameResult`. `AbstractGameMode.as:106–184` selects the result code, advances the source level on a non-final win, spends hearts on loss and invokes round teardown. These are recovered original progression facts only. They do not add campaign/map generation to the accepted single-map rebuild scope.

## Timeout and remaining limits

The existing [Dots play observations](edition-5-play-observations.md) separately retain TIME'S UP followed by level completion with enemies alive. `ArcadeMode.timeOut/judgeHandler` is a distinct anomalous source path; these new experiments establish **elimination** victory and do not reuse timeout as its substitute. Accepted remake timeout-loss and simulation-time clock rules remain in [DESIGN.md](../../DESIGN.md).

This completes the listed original-flow scenarios for one human Normal Arcade, with explicit controlled setup. It is not a native Flash comparison, a complete campaign/final campaign-win test, a proof of every multiplayer or weapon/death interleaving, or phone testing. Wall-time bonuses and cartoon completion frames belong to each recorded chronology. Original copied screenshots stay research evidence. No production gameplay, accepted adaptation, or tracker issue was modified by this investigation.
