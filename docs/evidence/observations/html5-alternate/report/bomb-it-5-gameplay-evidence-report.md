> Imported Dots record; claims are retained as delivered. See the [integration assessment](../../../edition-5-play-observations.md) for verification, missing files, and authority limits. Original relative paths in code spans refer to the [unaltered bundle](../../../../../.scratch/edition-5-research/observations/html5-alternate/report/bomb-it-5-gameplay-evidence-report.md).

# Bomb It 5 gameplay evidence update

Controlled HTML5 play and separate exact SWF static findings

16 October 2026

## What is now established

Actual play is now captured in the Y8-hosted GameDistribution HTML5 version: a Birthday Party arena, four-player HUD, movement, placed bombs, explosions, changed obstacles, pickups, player death and failed-level results. A separate one-enemy probe reached a completion result and level two. A restarted round also supplies an apparently intact near-opening board for visual transcription. This pack prioritizes gameplay records, not the earlier loading-only sequences.

This playable HTML5 version is not the exact publisher SWF used for source analysis; its runtime revision and parity are unverified. The earliest frame of the first attempt already reads TIME 173. The near-opening frame belongs to a separate restart and reads TIME 179, with all scores zero and no visible bomb or destruction. Neither is certified simulation tick zero.

### Evidence sources

- HTML5 OBSERVED: direct interaction with the ordinary Y8 listing and its GameDistribution deployment. No cheat mode was selected; game logic and playback speed were not changed. Exact port revision is unverified.
- SWF STATIC: code and embedded configuration from the exact publisher v.1.6.1 artifact. Callback counts are not measurements of the HTML5 player.
- INFERRED: a bounded interpretation, not a demonstrated rule.
- UNKNOWN: the required observation or identity check is not established.

HTML5 source page: https://www.y8.com/games/bomb_it_5

Deployment: https://html5.gamedistribution.com/6e9fca49c39246a484f533b946210ea7/

Exact SWF: https://www8.agame.com/games/flash/b/bomb_it_5/bomb-it-5-zh-fix.swf

SWF SHA-256: 718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2

The SWF remains unable to reach gameplay in the tested players. Its failure history is provenance, not gameplay evidence. The HTML5 observations do not replace it as the accepted rules authority. [H01, I01]

<!-- PAGE -->

## Actual gameplay screen

![First observed HTML5 gameplay frame](../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/003-first-board-or-state.jpg)

Figure 1. First saved gameplay frame of the first HTML5 attempt. TIME 173 and visible bombs show that the round has progressed. This is not an initial board. [H02]

HTML5 OBSERVED: Setup was Arcade, one human, three enemies, five levels, Easy, Birthday Party and the default blue character without a costume. Opponents were pink, orange and black. Four player cards are stacked at left, with level, time and Pause below. The playfield is to their right. The party decorations and cake establish a visual theme, not each object's collision role. [H01–H02]

In the 1165 by 747 uncropped browser capture, the gameplay frame is approximately x88–748 and y67–521. The board is approximately x238–738 and y78–506; the left HUD is approximately x119–218. These are screenshot estimates, not native canvas coordinates. Website advertisements and social controls are not game HUD elements. [H01]

Pause opened a game overlay with Main Menu, Resume and sound/music icons. Resume returned to play. Precise timer suspension and input state across pause have not been measured. [H03]

<!-- PAGE -->

## Near opening board record

![Near opening board from a separate HTML5 restart](../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/019-fresh-board-006.jpg)

Figure 2. A separate restarted attempt at TIME 179, with all scores zero and no visible bomb, explosion or destruction. AI movement may already have begun. This is apparently intact, not certified tick zero. [H04]

The near-opening frame has blue near the northwest, black northeast, pink southwest and orange southeast. Its layout differs from the earlier TIME 173 frame. They remain separate board records, not one composite reconstruction. [H01, H02, H04]

Two independent, approximate 17-column by 15-row visual maps are supplied in [board-transcription.md](../runtime/html5-alternate/board-transcription.md), with separate [first observed JSON](../runtime/html5-alternate/board-grid-first-observed.json) and [near-opening JSON](../runtime/html5-alternate/board-grid-near-opening.json). The first capture is 20:39:49.960 UTC; the selected near-opening frame is 20:42:13.956 UTC. [H10]

Question marks retain occlusion or ambiguity, including the central cake around columns 7–9 and rows 5–8. Visible floor is not a traversability test. Raised art overlaps cells, and the boundary is clipped. These maps are reviewable visual records, not implementation-ready collision grids.

Visual symbols identify painted objects, not automatically solid or destructible cells. Collision and blast roles require a probe or source linkage. The SWF separately defines a 17 by 15 grid and randomized templates; that fact must not substitute for the observed HTML5 layout. [S02, S04]

<!-- PAGE -->

## Observed loss and completion

![Actual HTML5 failed level results](../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/031-level-failed-results.jpg)

Figure 3. Actual failed-level results from the second controlled three-enemy attempt. All five displayed result fields are zero despite earlier in-match points. [H07]

HTML5 OBSERVED: Movement followed by Space produced bombs in the top-left corridor. Recorded explosions changed nearby decorations and exposed pickups. A later sequence showed the blue player's skull/death state, then YOU LOSE and LEVEL 1/5 FAILED. This is a level attempt observed through failure, not a completed five-level campaign. [H01, H05–H07]

The failed result reported Enemies Destroyed 0, Time Bonus 0, Easy Bonus 0, Level Score 0 and Total Score 0. Earlier in-match points reached 120. Those points did not carry into the failed level score in this observation; one result does not recover the full scoring formula. [H01, H07]

After the first failed attempt, Try Again led through an advertisement into a retry with blue hearts reduced from three to two. The layout changed. This supports an interpretation of lives as round attempts, rather than simply three unprotected hits before failure. Further life and protection tests are needed. [H01]

A separate probe changed the enemy count to one. It reached LEVEL 1/5 COMPLETE with Enemies Destroyed 0, Time Bonus 1217, Easy Bonus 1000 and Level/Total Score 2217, then advanced to LEVEL 2/5. The cause of the enemy elimination was not captured; AI self-destruction is only a possible explanation. The non-multiple-of-ten time bonus must not be forced into the SWF scoring formula without checking port timing and rounding. [H12]

<!-- PAGE -->

## Inputs bombs and unresolved behavior

### Directly observed HTML5 behavior

Arrow input moved blue along visible cardinal paths; blocking limited some travel. Space after movement visibly placed a dark spherical bomb with a fuse. Several Space attempts near spawn did not establish a placement. Focus, occupancy, cooldown and press timing have not been isolated. An unsuccessful input is not evidence for a new control rule. [H01]

One fresh-run explosion near blue did not kill it; a later stationary placement away from the corner produced death. The earlier survival is unexplained. Do not invent invulnerability, shielding or a safe-spawn rule from that outcome. [H01, H05–H06]

Gameplay clips are assembled from screenshot sequences. Their wall-clock gaps precede screenshot requests, not instrumented game frames. They establish visible event order, not precise fuse duration, fire lifetime, movement speed or achieved FPS. Original captures remain authoritative.

### Timed and held input probes

In the one-enemy tap probe, Space was requested at 20:47:40.482 UTC. The bomb was last visible intact at 20:47:42.487 and a blast was first visible at 20:47:42.873. This brackets the captured transition at more than 2.005 and at most 2.391 seconds after the request, not a confirmed fuse duration. Input/capture latency and accepted placement were not instrumented; a bomb already exists in the first sample. Sampling was about 2.6 images per second, not achieved game FPS. [H11]

A 600-millisecond Left+Right chord at a blocked position did not establish priority. A later 4.5-second Space hold changed the scene and score, but there are no frames during the hold. No repeat was captured after release. Auto-repeat and release-trigger behavior therefore remain unknown. [H13]

### Separate SWF input and bomb findings

SWF STATIC: The most recently pressed held direction wins; release restores the preceding held direction. Movement key-down repeats are deduplicated, bomb-down events are not. Bomb down/up are distinct callbacks and weapons can replace them. Default single-human input is arrows plus Space. These rules are not parity-tested against HTML5. [I02, S06]

The SWF header says 30 fps; startup requests 35 fps and gameplay uses ENTER_FRAME. An unused Timer(25) is not evidence for a 40 Hz loop. Ordinary bomb detonation occurs on callback 72; fire cleanup occurs on ending callback 17. Neither is a measured wall-clock duration. [S01, S07, S09]

Placement requires capacity and an empty cell. Source initializes capacity and power to one, capped at nine and five. Cardinal blast rays distinguish occupied blockers, soft boxes, bombs and Crocodile exceptions. Chain triggering and damage on entering fire are source-supported, not established as complete HTML5 parity. [S06–S09]

<!-- PAGE -->

## Exact SWF rules kept separate

### Drops clock damage lives and score

SWF STATIC: Soft-block animation precedes the conditional drop attempt. Occupancy can suppress a drop; quotas, random probabilities and vehicle restrictions also apply. Easy, Normal and Hard probabilities are 0.6, 0.5 and 0.4 in configuration, not measured HTML5 drop rates. [S10]

Mode defaults are totalTime 180, personLife 3 and aiLife 1. The clock compares Date.getSeconds() and adds one on a difference rather than accumulating elapsed delta; long stalls can miss seconds. Bomb and displayed-clock timing use different mechanisms. [S11]

Shield and vehicle protection have separate damage paths. Unprotected death removes the actor; the Arcade lose handler then decrements personal-player life before restart or game over. Normal Arcade victory requires no remaining AI, loss no remaining human. The China-portal invulnerability branch does not establish invulnerability for this tween-portal build. [S12–S13]

Arcade mode points become kills multiplied by 300. A win adds remaining time multiplied by 10 and a difficulty bonus; a loss has neither bonus. Box points are not in that final sum. The observed HTML5 zero-score failure is consistent with part of this path but does not prove identical implementations. [S14]

The exported Arcade timeout judge tests the robots array against robot classes and calls winHandler unconditionally for a single human. This remains an anomaly to test, not an observed timeout outcome or a repaired bug. [S15]

### Special items

The exact-build instructions distinguish red BOXING GLOVE from white open-hand PUSH THE BOMB. BoxingProp is a two-use, range-two action-button attack, not bomb lifting or throwing. BombShoesProp hooks movement collision to kick a bomb. Paused fuse countdown during kicked flight is an inference from callbacks and needs runtime testing. [S16–S17]

Bouncer, magic carpet and heavy bomb remain unidentified. No matching English label or B5 class name was found, but that does not prove absence. No requested special-item control was established in actual HTML5 play. [S18, H01]

<!-- PAGE -->

## Decisions and remaining gaps

This revision supplies actual played scenes, a near-opening visual board record, bomb/loss sequences, failed and completed level results, and a transition to level two. It does not claim successful play of the exact SWF, a certified tick-zero frame, completion of all five levels or HTML5 parity.

The accepted DESIGN remains a new-game contract. Godot 4.5, advance(commands), the fixed roster, phone controls and no-generator decision are not recovered original behavior. Original map randomization does not silently authorize a generator in the new game. No implementation file was changed. [I01, S04]

### Next evidence gates

- Identify the HTML5 revision and compare it with the exact SWF before making parity claims.
- Obtain an untouched authority-build board, or explicitly accept a different evidence source.
- Isolate focus and occupancy from held-key, repeat and press/release behavior; test opposing directions in order.
- Audit a bomb from placement through detonation, active-fire entry, blocked rays, chains and kicked flight with reliable timing.
- Test shields, vehicles, invincibility, additional life losses, victory causes, timeout and score totals independently.
- Map requested special items from an observed icon to source class and control before filling a design slot.

Recovered code, sprites, level art and music remain references and must stay out of the Douyin release. The pack includes requested screen/video evidence, not raw SWFs, player executables or the full decompiled tree.

<!-- PAGE -->

## Compact evidence index

The main records below refer to the playable HTML5 alternate. All images preserve the uncropped browser viewport. [gameplay-evidence-index.json](gameplay-evidence-index.json) gives hashes and identifies core material versus supporting frames.

- H01: [OBSERVATIONS.md](../runtime/html5-alternate/OBSERVATIONS.md), setup, actions, outcomes and limitations.
- H02–H04: [first observed board](../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/003-first-board-or-state.jpg), [pause](../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/004-pause-overlay.jpg), [near-opening restart](../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/019-fresh-board-006.jpg).
- H05: [bomb and obstacle-change clip](../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/recordings/025-focus-bomb.mp4).
- H06: [second bomb and loss clip](../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/recordings/029-second-bomb.mp4).
- H07: [failed-level results](../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/031-level-failed-results.jpg).
- H08: [first loss through results clip](../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/recordings/010-stationary-bomb.mp4).
- H10: [visual board maps](../runtime/html5-alternate/board-transcription.md), with both JSON grids beside them.
- H11: [timed tap clip](../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/recordings/043-fuse-tap.mp4) and [timing qualifications](../runtime/html5-alternate/recordings/README.md).
- H12: [one-enemy completion](../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/045-one-enemy-victory-results.jpg) and [level two](../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/048-level2-state.jpg).
- H13: [opposed-key trial](../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/042-opposed-horizontal.jpg), [before hold](../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/049-before-long-space.jpg), [after release](../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/050-after-long-space-release.jpg) and [later state](../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/052-after-hold-end.jpg).

The four clips contain sampled gameplay, not continuous recordings or audio. Their full source frames are supporting material; extract all supplied archives into the same folder to preserve relative paths. The complete capture-time chronology also lists unsuccessful or redundant captures not selected for this compact delivery. The old loading-frame sequences are not part of the gameplay pack.


### Exact source locators

Full S01–S19 findings: [source/static-findings.md](../source/static-findings.md). Export method locators: [source/method-locators.json](../source/method-locators.json). Decompiled source was inspected locally, not bundled.

- S01–S03: Root/AbstractRootClass startup; GameConfig stage, grid, spawns and interface anchors.
- S04–S05: AbstractMapData, BirthdayPartyMapData and MapMaster; localization.
- S06–S09: PersonInteractiveController, InteractiveController, RobotController, Bomb and GetFireCommand.
- S10–S11: Box destruction/createProp, embedded configuration and Game.countTime.
- S12–S13: TryToKillCommandChain, death/removal, ArcadeMode.end and AbstractGameMode.loseHandler.
- S14–S15: ArcadeMode.countScore, timeOut and judgeHandler; separate Kill mode paths.
- S16–S18: BoxingProp, BoxingPlayCommand, BombShoesProp and complete item-name search.
- S19: UIManager.gamePlay through embedded map construction and load completion.

I01: [inputs/DESIGN.md](../../../../../.scratch/edition-5-research/observations/html5-alternate/inputs/DESIGN.md). I02: [inputs/edition-5-input-and-timing.md](../../../../../.scratch/edition-5-research/observations/html5-alternate/inputs/edition-5-input-and-timing.md). Earlier workspace paths in I02 are not newly bundled artifacts.

To reproduce static work, obtain the exact publisher binary, verify its SHA-256 and use JPEXS 26.3.0: java -Djava.awt.headless=true -jar ffdec.jar -export script decompiled bomb-it-5-zh-fix.swf. Export binaryData separately to inspect embedded XML. Official release: https://github.com/jindrapetrik/jpexs-decompiler/releases/tag/version26.3.0
