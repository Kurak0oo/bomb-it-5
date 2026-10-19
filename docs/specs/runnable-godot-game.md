# Complete runnable Godot 4.5 game

Specification synthesized on 2026-10-19 from the accepted design through Q28. The user confirmed the testing boundary on the same date. Published as [GitHub issue #1](https://github.com/Kurak0oo/bomb-it-5/issues/1) with `ready-for-agent`.

## Problem Statement

The project has a tested headless command, scheduling and ordinary-bomb foundation, but a player cannot yet play a game. The main scene is empty. Movement, visible controls, hazards and damage, opponents, round outcomes, HUD and the surrounding playable flow are missing.

The user needs the complete runnable Godot 4.5 game within the accepted first-build scope: one human against three AI, edition 5 rules and maps subject to the agreed adaptations, and clear input feedback. A one-actor practice board is an integration milestone. Physical phone and iOS testing must wait until the main Godot game is ready for publication.

## Solution

Build a local landscape game in Godot 4.5 with continuous movement, ordinary bombs and chains, destructible soft blocks, source-supported damage and pickups, three AI opponents, a 180-second simulation clock, readable HUD, pause/resume, results and replay/retry flow. Use the recovered edition 5 game as the rules authority while preserving the explicitly accepted changes to timing, timeout and eight-direction phone movement.

First integrate a clearly labelled practice preview using the reconstructed CinemaStage1 board, working paired portals, original geometric presentation and desktop controls. Continue through the full playable match and original presentation needed for publication readiness. Develop and verify on desktop and through automated checks before the later physical phone/iOS stage.

## User Stories

1. As a player, I want to launch the project in Godot 4.5, so that I can play the complete first-build game.
2. As a player, I want a local match against three AI, so that I can play without accounts or another person.
3. As a player, I want a landscape board centered in the game view, so that I can understand the play space.
4. As a player, I want recognizable edition 5 board geometry and spawns, so that the recovered game design guides play.
5. As a developer testing controls, I want direct entry to a clearly labelled one-actor practice preview, so that I can inspect movement and bombs before full-match integration.
6. As a developer testing controls, I want Reset to restore the same recorded practice layout, so that comparisons are reproducible.
7. As a player, I want Arrow keys and Space on desktop, so that I can play and verify the game before phone testing.
8. As a desktop player, I want the latest pressed held direction to take priority and the older held direction to resume on release, so that keyboard control follows the recovered rule.
9. As a phone player, I want a fixed visible stick on the left, so that I can find the movement control consistently.
10. As a phone player, I want the stick to show pressed, dragged and released input clearly, so that I can see how it responds.
11. As a phone player, I want four cardinal and four diagonal directions, so that the stick supports eight-direction movement.
12. As a player, I want continuous movement within cells, so that control is not one cell per input.
13. As a player, I want equal straight and diagonal top speed, so that diagonal input does not add a speed advantage.
14. As a phone player, I want a central deadzone and normal-speed movement outside it, so that pushing farther does not unexpectedly accelerate me.
15. As a player, I want my full collision footprint to respect obstacles, so that visible routes remain trustworthy.
16. As a player, I want to slide along an open axis when another is blocked, so that diagonal input remains useful near walls.
17. As a player, I want blocked corners to remain impassable, so that diagonal input cannot cut through obstacles.
18. As a player, I want gentle corridor alignment within my movement distance, so that entering narrow lanes is manageable.
19. As a player, I want to leave a bomb I already overlap, so that placing a bomb does not trap me immediately.
20. As a player, I want that bomb to block re-entry after I clear it, so that bomb collision remains consistent.
21. As a player, I want working paired portals on the Cinema board, so that its special routes function.
22. As a player, I want portal transfer and temporary protection to follow the recovered conditions, so that transfers do not invent unexplained behavior.
23. As a phone player, I want a visible bomb button on the right, so that movement and bomb actions are clearly separated.
24. As a phone player, I want one down event and one up event per bomb-button press and release, so that holding the button does not invent repeated attempts.
25. As a desktop player, I want delivered repeated bomb-key events preserved, so that the command path does not silently discard input.
26. As a player, I want bombs placed in my cell before that tick's movement, so that placement is predictable.
27. As a player, I want capacity and occupied-cell checks to prevent invalid placement, so that bombs obey the round rules.
28. As a player, I want timed fuses and visible blasts, so that I can understand danger and escape.
29. As a player, I want blasts to stop at solids and the first soft block, so that cover behaves consistently.
30. As a player, I want bombs hit by blasts to chain immediately, so that linked explosions form one interaction.
31. As a player, I want soft blocks to break and cease blocking movement, so that explosions open routes.
32. As a player, I want source-supported conditional drops and pickup effects, so that progression follows verified rules.
33. As a player, I want my own and enemy blasts to cause the appropriate damage, so that danger applies consistently.
34. As a player, I want protection and death states to be visible, so that I can understand why a hit does or does not eliminate an actor.
35. As a player, I want three active AI opponents using the same physical movement and collision rules, so that opponents participate fairly in the match.
36. As a player, I want the countdown to start at 180 simulation seconds, so that time follows actual gameplay progress.
37. As a player, I want victory when all enemy AI are dead, so that eliminating enemies completes the round.
38. As a player, I want defeat when time expires with enemies remaining, so that timeout follows the accepted new-game rule.
39. As a player, I want loss and retry opportunities to follow the recovered lives rules, so that hearts are meaningful rather than an invented health meter.
40. As a player, I want current time, lives, score and relevant actor statistics displayed clearly, so that I can understand the match state.
41. As a player, I want readable result labels and score totals, so that exposed localization keys do not obscure the outcome.
42. As a player, I want a route from a completed or lost round to the next allowed action, so that play never ends at a dead screen.
43. As a player, I want Pause and explicit Resume, so that I can stop and continue safely.
44. As a player, I want focus loss to pause the game and focus return to wait for Resume, so that unattended play does not continue.
45. As a player, I want fresh controls required after resume, so that stale held input or queued bombs do not fire unexpectedly.
46. As a player, I want paused time and excessive frame delays not to create a long unseen catch-up sequence, so that resuming remains understandable.
47. As a phone player, I want controls clear of platform cutouts and the Douyin capsule, so that essential input stays accessible.
48. As a player, I want touches on the grid to have no gameplay effect, so that incidental board touches do not create commands.
49. As a player, I want clear original visuals and responsive animation, so that floor, blockers, actors, bombs, blasts and controls are distinguishable.
50. As a project owner, I want the complete Godot game verified before physical phone/iOS testing, so that device testing evaluates an integrated game.

## Implementation Decisions

- **Authority and scope:** the retail edition 5 publisher SWF is authoritative, with accepted design and ADRs 0001–0004 documenting deliberate departures. Do not import implementation, maps or tests from the parked edition 1 project. The first build is local, one human and three AI, with the selected elimination ending. Complete delivery does not imply all retail modes, every map or a five-level campaign.
- **Engine:** Godot 4.5, GDScript and Compatibility renderer. An external scheduler uses rendered-frame elapsed time to drive 35 logical ticks/sec; leave the global physics tick rate unchanged. Rendering and logical cadence are independent.
- **Existing foundation:** preserve the fixed actor roster, atomic command admission, ordered bomb events, captured queue ownership, scheduler lifecycle and ordinary-bomb behavior. At the synthesis baseline, 28 command/queue, 41 scheduler and 43 bomb assertions pass. This is implemented foundation, not a claim that movement or a game scene exists.
- **Round boundary:** evolve the real tick target behind the existing scheduler into the complete round simulation. Keep one per-actor command containing direction and ordered down/up bomb events, and explicit idle commands for every actor. Invalid, missing, duplicate or unknown actor commands reject the whole tick without gameplay advancement. Dead or temporarily unavailable actors remain represented in the fixed roster; their permitted gameplay actions follow their state.
- **Input lifecycle:** capture events at tick start; consume only the captured prefix after acceptance, once. Rejection retains it; later arrivals belong to a later tick. Gameplay failure inside an accepted tick consumes the attempt. Do not add automatic placement retries.
- **Existing tick phases:** admit the batch, resolve bomb input in fixed roster order, advance existing bombs and explosions, then movement. A newborn bomb placed on N first counts down on N+1 and normally detonates on N+72. Submission-array order does not replace roster priority. A press on an expiry tick can fail before the old bomb releases capacity.
- **Additional phases:** persistent hazards, damage, pickups, portals and ending evaluation need documented placement relative to those accepted phases. Trace their source conditions and add public-behavior checks before integration. This specification does not invent precedence for simultaneous player death, enemy elimination and clock expiry; resolve such a conflict from evidence or record an explicit adaptation before claiming it is settled.
- **Observation and presentation:** publish owned public round state/results sufficient for actors, board, bombs, active hazards, pickups, clock, lives, score and outcome. Keep drawing and UI from advancing independent gameplay clocks. The scheduler's automatic process currently discards its returned tick results; the gameplay integration must deliberately expose committed results or drive the existing elapsed-time interface from the scene host. Avoid a second simulation loop.
- **Movement:** continuous sub-cell position with a source-grounded movement baseline. Original movement accelerates and stops displacement on release; the user's delivery clarification did not approve a new exact acceleration or reversal curve. Implement eight-direction capability with normalized diagonals and equal straight/diagonal top speed. Record tuning without claiming exact cardinal SWF parity for the new diagonal behavior.
- **Collision:** respect the full footprint against solids, soft blocks and ordinary bombs. Allow wall sliding, reject blocked-corner shortcuts, and spend only the normal movement budget on corridor assistance. Any actor already overlapping a bomb may leave it; complete clearance ends that departure permission regardless of ownership. Ordinary actor-to-actor blocking is not established by the recovered collision path and must not be silently added.
- **Controllers:** preserve the desktop Arrow-key last-pressed cardinal policy and Space bomb events. The phone stick quantizes to eight directions, requests normal speed outside its central deadzone and has no deflection speed boost. Human and AI share physical capabilities; their input-selection logic differs. Phone adapters can be verified with synthetic input on desktop before physical device testing.
- **Touch feedback:** fixed visible translucent left stick and right bomb button inside the view, generous touch area, clear idle/press/drag/release response, thumb feedback and return to center. Preserve independent movement/action contact handling. Drawing feedback must not create extra bomb events. Mature mobile games guide presentation; their unmeasured numeric thresholds, easing and latency are not project facts.
- **Practice board:** use the audited recorded CinemaStage1 instance: 17×15 cells, 125 solids, 68 soft blocks, 58 floor cells and four portals. The center 3×3 is solid and cell (14,10) is soft. Reset restores this instance and a fresh practice session, clearing live bombs, hazards, actor/controller state and queued input. The board is reconstructed image evidence, not a runtime collision dump. Do not fill every template candidate or introduce a map generator.
- **Portals:** implement pairs (8,1)↔(8,13) and (4,7)↔(12,7). Preserve source eligibility, temporary removal/control interruption, transfer, protection and the latch preventing immediate return until leaving the portal. Source findings identify a 30-callback transfer and 45-callback protection; trace their exact start/expiry phases before translating them to accepted ticks. Flattening portals to ordinary floor is not the agreed preview.
- **Ordinary bombs and blocks:** preserve capacity, copied placement-time power, plus-shaped rays, solid exclusion, first-soft inclusion/stop, synchronous occupancy removal and same-tick recursive chains. Distinguish current detonation-event records from the persistent flame field still to be implemented. Supplied observations show 17 visible flame frames; exact hazard expiry and overlapping cleanup require the relevant source trace rather than merely a visual timer.
- **Damage and protection:** implement source-supported Arcade damage, self-hit, elimination and protection conditions. Ordinary unprotected flame contact is observed to kill, with no in-round respawn. Vehicles, shields and portal protection must use their verified conditions when reachable; do not invent a general health pool or universal invulnerability rule.
- **Drops and progression:** soft blocks do not guarantee drops. Recover quotas, suppression, animation delay and pickup effects for reachable first-build drops before enabling them. Bomb-capacity and power pickups have observed behavior, but that does not establish every item identity. The glove slot remains unselected between boxing and passive bomb-kick candidates; bouncer, magic carpet and heavy bomb remain unresolved. Do not fill these four slots from another edition or a portal blurb.
- **AI:** recover and record relevant edition 5 decision behavior before implementing the three controllers. Feed legal commands through the common round boundary; do not bypass collision or placement rules. Shared eight-direction movement does not specify routing, danger prediction, difficulty or personality. These remain a source/design prerequisite, not permission to invent a generic personality.
- **Clock and outcomes:** 180 seconds means 6,300 accepted simulation ticks. Pause and rejected ticks do not age it; discarded scheduler time does not count. Normal elimination victory is supported even with zero player-attributed kills. Timeout with enemies remaining is deliberately a loss. Outcome transitions and result accounting occur once; exact simultaneous-ending precedence remains subject to the additional-phase prerequisite above.
- **Lives and score:** source observations distinguish three retry hearts from in-round health, one lost opportunity per failed round, no in-round respawn and game over at exhaustion. Recover exact scoring/ownership and session-total formulas before implementing accounting. Observed block and pickup awards do not justify simply adding every HUD point to the result total. Keep practice Reset separate from source-supported retry/session behavior.
- **Playable flow:** practice provides direct entry, Pause/Resume and Reset. The complete first-build game also needs match entry, active play, readable victory/defeat/results, retry/game-over handling and a way to start another permitted game. Recover relevant original screen behavior; do not make the intermediate direct-entry practice screen the final delivery. Campaign Next/map progression beyond the selected first-build scope is not implied by an observed Next button.
- **Presentation:** use original geometric visuals during integration. Preserve recovered gameplay-screen layout relationships and distinguish every gameplay state required to make decisions. Publication readiness includes the agreed original redrawn presentation rather than copied SWF art, music or branding. Exact final art content and release language are not resolved by this specification.
- **Pause and stalls:** run at most five logical ticks per rendered frame, discarding all excess accumulated time. Focus loss pauses; focus return only permits explicit resume. Pause/resume clears held controls, queued gameplay input and elapsed-time credit. Simulation timers and portal/damage progression stop with the round. UI may animate independently without advancing gameplay.
- **Delivery order:** integrate visible practice, then complete the remaining simulation and AI, HUD/session flow and presentation. Dependencies can be split into vertical tickets, but none can redefine practice as completed delivery. Physical phone/iOS testing follows publication-ready Godot development. This staging preserves the existing Douyin scope and does not select an iOS export architecture.

## Testing Decisions

- **User-confirmed primary boundary:** exercise gameplay through the existing scheduler and real round simulation, observing public state and results. Use a small set of scene tests for controls, display and playable flow. Prefer this existing high-level seam over new testing accessors for each internal subsystem.
- Good tests submit public commands or input, advance supplied time and assert player-visible outcomes. Use real collaborators, deterministic board/setup data and controlled randomness where required. Do not inspect private fields, mock the simulation or assert internal helper call sequences.
- Existing command/queue, scheduler and bomb checks are prior art: atomic rejection, ownership, captured events, accepted-tick fuse progression, pause/focus lifecycle, capped catch-up and source-linked blast geometry. Preserve them unless an explicitly accepted contract change requires a corresponding update.
- Test the round through continuous movement, equal diagonal/straight top speed, full-footprint blockage, sliding, corner safety, corridor-assistance budget and bomb departure/re-entry. Test both cardinal and diagonal approaches around the recovered board geometry.
- Test bomb placement before movement, roster conflicts, expiry-tick failed attempts, chain reactions, persistent hazards, soft-block clearing and movement into newly opened routes. Establish damage timing, protection and overlapping-flame behavior through the public round before asserting parity.
- Test both portal pairs, transfer interruption, protection expiry and latch release. Pause/focus changes must not age transfers or leak stale movement/bomb input.
- Test source-conditioned drops, pickup effects and score attribution using reproducible eligible and suppressed cases. If randomness is involved, select controlled draws through round setup without creating a test-only gameplay path.
- Test AI through observable legal actions and recovered decision scenarios, not private pathfinding details. Verify three controllers remain active in the full match and obey the same movement, collision and bomb rules as the human.
- Test 6,300 accepted ticks to timeout, rejected/paused time exclusion, all-enemies-dead victory, player defeat, one-time result accounting, lives/retries and exhaustion. Add explicit edge cases once simultaneous-ending precedence is resolved.
- Scene tests cover desktop key priority, touch-sector/deadzone mapping with synthetic events, concurrent movement and bomb control, no grid-touch commands, readable HUD/results, Pause/Resume/Reset, focus loss and fresh input. Verify real scene output rather than duplicating gameplay logic in UI tests.
- Run appropriate Godot 4.5 parsing/type checks and the complete headless suite for implemented slices. Add desktop visual inspection of layout, control animations, bombs/blasts, portals, outcome transitions and replay. A headless green suite alone does not establish usable presentation.
- Physical phone input, safe-area validation, performance and iOS behavior belong to the deferred device-testing stage. Their absence must not block desktop implementation or be misreported as completed device validation.

## Out of Scope

- Accounts, networking, same-phone second human, cross-phone co-op and PvP. Co-op precedes PvP in later work.
- Additional retail modes/endings, full campaign progression, all 44 map templates or a map generator as implicit requirements of this first build.
- Filling the four unresolved named item slots or choosing a glove candidate without the required evidence/design decision.
- Copying the parked edition 1 implementation or using editions 4/7 as substitutes for edition 5 behavior.
- Copied SWF art, audio and level artwork in the production build; publishing under the unchosen store name.
- An early physical phone-control prototype or physical phone testing before publication-ready main Godot development.
- Selecting the final store name, release language, signing/distribution configuration or an iOS exporter through this spec. Actual export work requires current official platform verification.
- Exact reproduction of deliberately replaced wall-clock/timeout quirks, original cardinal-only phone control or other timing behavior contradicted by the accepted adaptations.

## Further Notes

Completion requires a runnable full match with one human and three AI, continuous legal movement, functioning bombs/hazards/damage and reachable pickups, working board features, the 180-second clock and selected endings, correct lives/score/HUD, pause/focus lifecycle and repeatable playable flow. Original presentation must support publication readiness. Practice, isolated tests or a visible board alone do not satisfy this gate. Verify all implemented behavior on Godot 4.5 through automated checks and desktop play before scheduling physical phone/iOS evaluation.

Source-recovery work remains part of implementation preparation: AI decisions; precise persistent-hazard/damage/protection phases; reachable drop conditions; scoring/session totals; and simultaneous-ending precedence. Trace facts available in the original source instead of interviewing the user for them. If a recovered rule conflicts with an accepted adaptation, record the conflict and obtain a design decision rather than silently changing either account. Do not declare these prerequisites already solved merely because media and source have been delivered.

The accepted design owns requirements; the development frontier owns remaining gates; the glossary owns domain definitions; ADRs own consequential rationale. Supporting evidence includes the edition 5 input/timing and gameplay-phase records, movement/board findings, canonical CinemaStage1 reconstruction, Dots delivery assessment and mobile-control reference record. Imported historical claims must be read with their corrections and newer assessments.

The configured tracker is GitHub Issues for Kurak0oo/bomb-it-5, with the default triage vocabulary. [Issue #1](https://github.com/Kurak0oo/bomb-it-5/issues/1) contains the published specification and carries `ready-for-agent`. Derive dependency-linked vertical implementation tickets from this scope, retaining both source-recovery prerequisites and the complete-game completion gate.
