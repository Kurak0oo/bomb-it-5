> Imported Dots supplemental record; assertions are retained as delivered. Read the [integration assessment](../../../edition-5-play-observations.md) for confidence, corrections and remaining limits. Source-relative paths in code spans refer to the [unaltered original](../../../../../.scratch/edition-5-research/observations/swf-v1.6.1-followup/task3_victory/README.md).

# Task 3: Arcade / Normal / 1 human / 3 enemies / first character. Elimination victory

Tags: [O] observed, [S] source, [I] inferred, [U] unknown. Harness probe2, exact SWF, no cheats and no edits.
Session C. The full input log is in common/logs/sessionC_probe2_out.log and the notes in common/logs/sessionC_notes.md.

## Result: VICTORY by elimination, before time-up. Caveat: P1 killed none of the three AI
All 3 AI died during level 1 with **TIME 59 remaining**. The game then played **"YOU WIN!"** (f4908) and **"LEVEL 1/5 COMPLETE!"**, followed by **NEXT → LEVEL 2/5** [O].
This is the real elimination win path. It is **not** the time-up bug (that path shows "TIME'S UP!"; see the phase-1 evidence).
**Caveat:** P1 made **0 kills**; the results screen says "1_ENEMIES KILLED 0". Every AI died in a bomb blast while P1 sent **no input at all** from the TRY AGAIN click (f1321) to the win. So P1's bombs cannot be the cause [O from the input log].
A win where P1 personally kills all three AI was **not achieved** (see "Attempts").

### Setup (absolute frames, logged)
- step 301; click 349 440 (PLAY) → step 240; click 569 203 (START)
- click 140 180 (ARCADE); click 255 275 (1 player); click 255 312 (3 enemies); click 415 428 (NORMAL)
- click 533 477 (NEXT) → f636: character select with the first character (keyframe) → click 528 475 (START)

### Attempts
1. **Game 1, f639–1171.** BirthdayPartyStage3, an empty arena with no blocks [O+S].
   - The pumpkin AI put a bomb next to P1 at f1078. P1 dodged it.
   - In an open arena P1 could not trap any AI. I deliberately stood in the pumpkin's blast at about f1150 to re-roll the board, since hearts work as retries.
   - LEVEL FAILED; TRY AGAIN clicked at f1321.
2. **Game 2, retry board (BirthdayParty with boxes), hearts 2.** P1 stayed in the spawn pocket (1,1)–(1,2), which gift boxes at (1,3)–(1,4) closed off. No P1 input.

| AI | Death (absolute frame) | How it died | Keyframes |
|---|---|---|---|
| Pumpkin | blast f2022, silhouette **f2034** (portrait grey f2085) | caught in the blast of a bomb right next to it at about (13,12). No other robot's score jumped by a kill bonus; the pumpkin got +10 for the box that blast destroyed. So it was **its own bomb** [I] | f2016 / f2022 / f2034 |
| Witch | silhouette **f2568** in a vertical flame in column 1 at about (1,5) (portrait grey f2622) | bomb blast in column 1. Owner [U]; probably its own (the witch held 3 bombs nearby; the green AI's +100 matches a pickup) [I] | f2565 / f2568 / f2622 |
| **Green (last AI)** | flame comes down its column at f4842; silhouette **f4854** at about (13,12) | **its own bomb**: at that point the green AI was the only robot placing bombs, and P1 placed none in game 2 [O+I] | f4836 / f4842 / f4854 |

### Victory transition, results and Next (absolute frames)
- f4908: **"YOU WIN!"** banner, TIME 59 [O]
- f5010: **LEVEL 1/5 COMPLETE!** results with a "DRESS UP – New outfit unlocked!" popup [O]
- click 357 463 (popup OK) logged at counter 5576 → results screen, f5616 [O]:
  - 1_ENEMIES KILLED 0
  - TIME BONUS 590
  - NORMAL BONUS 2000
  - LEVEL SCORE 2590
  - L_TOTAL SCORE 2590
- **click 543 421 (NEXT)** logged at counter 5621 → **LEVEL 2/5** board (Cinema), hearts 2, TIME 177, at f5741 [O]

### Wall-clock pacing (the round clock comes from `Date.getSeconds`)
Settings: `realtime 1` (the harness sleeps so each frame takes at least 1/35 s) and `capevery 3`, or `capevery 6` for long waits. Capture is asynchronous on 4 writer threads.
How the timer works [S]: `Game.countTime` adds at most 1 per check, so pauses between command batches add at most 1 s each.
HUD TIME against absolute frame [O]: 1422:178, 1572:172, 1872:160, 2322:144, 2772:128, 3072:117, 3471:105, 3870:92, 4272:79, 4590:69, 4908:59. That is about 31–33 frames per in-game second (nominal 35), so the clock stayed sane.
Raw wall_ms per command is in the log.

### Frames (full colour, uncropped)
- the round start (every captured frame)
- context every 30th frame
- a full window around each death
- f4800–5568, every 6th frame, covering the last death, YOU WIN and the results
- every frame of the OK and NEXT clicks and the level-2 load

Keyframes are in keyframes/.

### Stopped here
A P1-kills-all victory was not attempted further. Two games were played. In open arenas the AIs dodge power-1 bombs reliably. On box maps P1 starts sealed in. The AIs eliminated one another within about 3500 frames.
Ideas that were not executed are in the AIControl notes:
- the danger rays above a bomb are only registered when fewer than 30 fuse frames remain;
- the blocked-direction flags are shared across all bombs in one scan.
