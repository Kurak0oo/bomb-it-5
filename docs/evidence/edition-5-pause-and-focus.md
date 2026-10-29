# Pause, resume and focus loss (#81)

Authority build `agame-bomb-it-5-zh-fix.swf` (sha256 `718c04c7…0408a2`). Static source from
the FFDec 26.3.0 script export; runtime from the patched reference player built on Linux
(`tools/reference_player/build.sh`, Mesa lavapipe, probe sha256 `be900407…3e05aa`) on
2026-10-29.

## Source

- **Pause request.** The PAUSE button calls `Game.gamePause`, which only schedules
  `doGamePause` with `setTimeout(…, 100)`. `doGamePause` sets `gamePaused`, pauses a running
  end cartoon, opens `PauseUI`, hides the game, stops `GameEngine` (its `ENTER_FRAME`
  listener) and calls `robotPause` on every robot.
- **Cancel.** `gameResume` with `gamePaused` still false clears the pending timeout instead.
- **Robots.** `RobotController.robotPause` stops the view's clips and, with no stage function
  running, clears the movement stage (`clearMovStage`, `robotStop`) and releases the bomb key
  (`bombHandler_up`). `robotResume` restarts the robot; it does not restore the movement.
- **Resume.** `doGameResume` restarts the engine (or the end cartoon), destroys `PauseUI` and
  calls `robotResume`.
- **Timers that keep running.** `TweenMax.delayedCall` and `setTimeout` are not part of
  `GameEngine`, so they run on while it is stopped: the 0.3 s triple-shot and fireball
  recovery (`NinjialPlayCommand`, `ShotGunPlayCommand`), AI delays (`Action`, `StateIdel`,
  `AbstractAttackState`) and the Green Zone flag's 3 s move (`Flag.delayMax`).
- **Focus loss.** `Event.DEACTIVATE` → `gameDeactivate`: ignored after game over; in play it
  calls `gamePause` (the same 100 ms timeout); before the round starts it opens `PauseUI`
  without stopping anything (`notInGameDeactived`). `ACTIVATE` only clears `gameDeactive`, so
  play never resumes on its own.

## Runtime trace

Case `tools/reference_player/cases/pause/pause-resume.json` (Normal Arcade, generated
Cinema seed 42, AI stopped by fixture): Down pressed and PAUSE clicked at counter 721, key
held through the pause, RESUME clicked at counter 771, then the key released (782) and
pressed again (784). Per-frame summary: [pause-frames.csv](reference-2026-10-29/pause/pause-frames.csv)
(`tools/inspect_pause_trace.py`); captures [paused](reference-2026-10-29/pause/paused.png) and
[after resume](reference-2026-10-29/pause/resumed-key-still-held.png).

| Observation | Frames |
| --- | --- |
| Movement continues for four frames after the click; `gamePaused` is set at the end of the fourth (100 ms at 1000/35 ms per step). | y 31.6, 34.15, 37.25, 40.7 on 722–725; paused from 725 |
| Nothing moves and `pastTime` stays at 3 while paused. | 725–771 |
| After RESUME the still-held key moves nothing. | y 40.7 on 773–784 |
| `pastTime` counts once on the first engine frame that sees a new Date second (3 → 4), then per second. | 773, 780 |
| The speed is kept through the pause and decays only after the key-up (two `moveStop` frames), so the re-press moves `0.6·(3.4816·0.6²) + 1.6 = 2.35` px. | y 43.05 on 785 |

An earlier run (`pause-resume-01`, Right held into a box) showed the same four-frame delay.

## Port (`original` profile)

`Game.toggle_pause` waits `PAUSE_DELAY_STEPS = 4` steps before stopping the scheduler; a second
press inside the window cancels. When the pause takes effect, `BombSimulation.hold_movement`
marks every robot: it keeps its speed and ignores movement until a new press. On RESUME the
paused wall time, in steps, is passed to `pass_host_time`, which counts down weapon
recovery, the Green Zone flag move and the AI controller's delays. The round clock already
behaves as traced (#80).

## Differences kept

- The replica cannot see a key release while input is fresh after resume, so the retained
  speed does not decay between the release and the next press; the original decays it once
  per frame from the key-up. This changes only the first step of the next press (at most
  about 1.3 px).
- Focus loss in the replica pauses at once and shows the pause page (Q15): with the app in
  the background no frames run to wait 100 ms. The pinned Ruffle revision does not dispatch
  `Event.DEACTIVATE`, so the original's focus path is static evidence only.
- AI robots resume on their next decision; the original restarts their controllers through
  `robotResume`. Call-level AI traces are #84.
