# Complete edition 5 game

Specification drafted on 2026-10-21 from the accepted complete-game scope
([DESIGN.md](../../DESIGN.md), [ADR 0007](../adr/0007-complete-edition-5-game.md))
and the [modes and flow recovery](../evidence/edition-5-modes-and-flow.md). Published
as [issue #56](https://github.com/Kurak0oo/bomb-it-5/issues/56) with tickets #57–#70; it extends [the runnable game specification](runnable-godot-game.md),
whose accepted rules still apply.

## Problem Statement

The runnable build is a testing arena: it opens on one fixed Cinema board in
Normal Arcade, with retry and play-again on that board. Edition 5 is a whole game,
with a main menu, settings, character select, four modes, six stage sets across a
multi-level session, three difficulties, controls help and unlockable looks. The
user wants that complete game, built so that new modes, maps, rules and enemy
designs can be added later.

## Solution

Grow the existing round into a mode-driven game without forking it. A mode
supplies its ending, settings, drop table, base action, respawn and scoring; a
board is map data rolled from recorded layouts; enemy behaviour is an AI profile
chosen by mode and difficulty. Wrap the round in the original screen flow and
session progression, add the remaining stage sets' map features and the three
other modes, and persist settings, key bindings and unlocks locally. Each mode,
difficulty and stage-set feature is observed in the original game before it is
ported.

## User Stories

1. As a player, I want the game to open on a main menu, so that I start where edition 5 starts.
2. As a player, I want Game Settings for mode, enemies, levels, stage and difficulty, so that I choose the game I play.
3. As a player, I want to choose one to three enemies, so that I control how crowded a round is.
4. As a player, I want 5, 10, 15 or 20 levels, so that a session is as long as the button says.
5. As a player, I want a random stage or a chosen stage set, so that I can vary or repeat scenery.
6. As a player, I want Easy, Normal and Hard, so that the challenge matches me.
7. As a player, I want to pick one of eight robots, so that I play as the character I like.
8. As a player, I want to wear hats and body looks I have unlocked, so that progress shows on my robot.
9. As a player, I want unlocks to persist between launches, so that I keep what I earned.
10. As a player, I want a score screen after each level with its breakdown, so that I see how I did.
11. As a player, I want to continue to the next level or retry after a loss while I have lives, so that a session flows.
12. As a player, I want game win and game over screens with my total, so that a session has an end.
13. As a player, I want random stages not to repeat until all six have appeared, so that a session tours the sets.
14. As a player, I want a retry after a loss to keep the stage set with a fresh layout, so that a retry is fair but not identical.
15. As a player, I want boards to vary between rounds as in edition 5, so that each round plays differently.
16. As a player, I want every stage set's own hazards and platforms to work, so that each set plays like the original.
17. As a player, I want each set's own vehicles, so that pickups match the scenery.
18. As a player, I want Kill mode, where the first to 10 kills wins, so that I can play a fight-to-score round.
19. As a player, I want respawns after a short delay in Kill, Green Zone and Pac-Man, so that those modes keep going.
20. As a player, I want an unlimited hammer as my action in Kill and Green Zone, so that combat works as in edition 5.
21. As a player, I want Green Zone, where holding the flag scores, so that I can play capture-the-flag.
22. As a player, I want to see each robot's flag progress, so that I know who is about to score.
23. As a player, I want Pac-Man mode, where I eat every coin while ghosts chase me, so that I can play the maze mode.
24. As a player, I want invincibility in Pac-Man to let me fight back, so that the mode has the original turnaround.
25. As a player, I want each mode's original timeout rule, so that the clock ends rounds fairly.
26. As a player, I want enemies to behave as each mode and difficulty expects, so that every mode has real opponents.
27. As a player, I want the HUD to show the score that matters in each mode, so that I can follow the round.
28. As a player, I want How to Play and a power-up reference, so that I can learn the game.
29. As a desktop player, I want to rebind keys and keep them, so that controls suit me.
30. As a player, I want Pause to offer Resume and Main Menu, so that I can leave a session.
31. As a phone player, I want every screen usable by touch, so that the phone build needs no keyboard.
32. As a project owner, I want the Art Workbench to cover the new robots, looks, screens and stage skins, so that I choose all presentation.
33. As a developer, I want the practice board to stay a development launch, so that workbench preview and tests keep a fixed board.
34. As a future designer, I want modes, maps and AI profiles to be data and modules on one round, so that I can add new ones without rewriting gameplay.

## Implementation Decisions

- **One round, pluggable rules.** The round keeps its admitted-command, scheduler,
  pause and phase contracts. Mode-specific behaviour enters through a mode module:
  ending and judgment, timeout rule, base action, respawn delay, drop table,
  permitted pickups per controller, timed pickups, point source and level score.
  Arcade is reimplemented as the first mode module with unchanged behaviour.
- **Boards as map data.** A board is data: size, cells, features, spawns, soft
  candidates and skin. Layout choice and the soft-block roll (Arcade 0.6, Kill
  0.55, Green Zone and Pac-Man none) draw from the round's controlled randomness.
  The fixed practice instance and future invented maps use the same input.
- **AI profiles.** Profiles carry the source fields per mode and difficulty
  (answer time, find range, speed, bomb power, capacity, state weights and
  delays). New states (Flag, Defence, Follow, Escape, Idle) join the existing
  controller as states, not separate controllers.
- **Session.** A session holds settings, the robot and look choice, level index,
  lives, totals and the stage rotation. Level win advances; loss with lives
  restarts in the same set; exhaustion ends the session. Lives start at three.
- **Settings.** Modes Arcade, Kill, Green Zone, Pac-Man; enemies 1–3; levels
  5/10/15/20 (default 5, fixing the source's 5-sets-1 defect); stage random or one
  of six; difficulty Easy/Normal/Hard. Pac-Man is one-player in the source and
  stays so.
- **Difficulty.** Drop chance 0.6/0.5/0.4, danger perception, the Easy spawn
  shield in Arcade and Pac-Man, difficulty bonus 1000/2000/3000 and the mode's AI
  profile.
- **Modes.** As recorded in [modes and flow](../evidence/edition-5-modes-and-flow.md):
  Kill (kills to 10, own-bomb death −1, hammer, 1 s respawn, timeout by kill
  comparison with ties to the human), Green Zone (flag capture to 10, hammer,
  1 s respawn, mode move speed 1.8), Pac-Man (coins on every free cell, human
  without an action, AI flamers and immunity to bombs, 5 s invincibility, AI
  respawn, human death loses, timeout loses). Arcade keeps the accepted
  loss-on-timeout adaptation.
- **Stage sets.** All six sets with three normal and three Pac-Man layouts each.
  Each set's features and vehicle pairs are recovered and ported per set:
  Cinema portals (done), Zoo crocodiles, Birthday Party toy hands, Candy Factory
  conveyors and sliding platforms (correction 2026-10-22: Candy layouts have no
  sliding platforms; see the [Candy Factory record](../evidence/edition-5-candy-factory.md)), Magic Library spellbooks; Luxury Stores has no
  special tile. No recorded layout places lava. Timed pickups follow each mode's per-set counts.
- **Screens.** Without sound or music switches while audio is deferred: main menu, Game Settings, character select with look choice, How to
  Play with power-ups and key rebinding, pause with Resume/Main Menu, per-level
  score, unlock tip, game win and game over. MORE GAMES, avatar upload,
  achievements and analytics are not included. Text uses readable labels.
- **Unlocks and saving.** Eight robots with three hats and five body looks each;
  look *n* unlocks for the played robot when a score screen's session total
  reaches 2,500 / 7,200 / 12,000 / 19,200 / 24,000 / 31,200 / 36,000 / 48,000. A
  local save file keeps unlocks and key bindings. No
  accounts.
- **Practice.** Remains a development launch on the recorded CinemaStage1
  instance, used by the workbench preview and tests; not on the player menu.
- **Art.** The workbench catalogue grows to all eight robots, looks, new screens
  and stage-set skins, with native defaults; #20 covers the larger catalogue.
- **Evidence gate.** Every mode, difficulty and stage-set feature ticket first
  records original-game runtime observation with the reference player, linked
  from the evidence index, then ports it. A conflict with an accepted adaptation
  goes to the user.

## Testing Decisions

- Keep the user-confirmed boundary: gameplay through the scheduler and real round,
  observing public state and results; a small set of scene tests for screens and
  flow. All 408 existing checks stay green through the mode refactor.
- Test each mode through public commands: its win, loss, timeout judgment,
  respawn delay, base action, scoring and drop table, with controlled draws.
- Test board rolling: layout choice, per-mode soft-block chance, corners kept
  clear and deterministic results for a given seed.
- Test session flow: level advance, same-set retry, life loss, game over, game win,
  random rotation without repeats and level counts.
- Test unlock thresholds, persistence round-trip and that a corrupt or missing
  save starts clean.
- Scene tests drive every screen by touch and keyboard, including key rebinding
  and pause to main menu.
- Compare each ported mode and feature against its recorded original observation;
  record differences rather than claiming parity.

## Out of Scope

- Local 2-player, zero enemies for one player, networking, co-op and PvP.
- Unselectable edition 5 modes (Speed, Water, Collect, Painting) and unused map
  symbols (Basketball, BirthdayPartyStage4).
- MORE GAMES, avatar upload, achievements, analytics, quality settings, and audio
  with its sound and music switches (deferred).
- Invented maps (the map-data seam allows them later), store name, release
  language, export and physical phone/iOS testing.
- The four unresolved named item slots.

## Further Notes

Final desktop acceptance #21 is blocked by this specification's tickets and by
finished-art gate #20, and verifies the complete game. Audio is deferred: no
replacement audio is chosen, so screens omit sound and music switches for now.
