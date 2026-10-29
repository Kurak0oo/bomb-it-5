# Original-game evidence

The evidence starts with the hashed publisher build and separates static findings, supplied play observations, and independently checked artifacts. The Dots delivery adds source support for normal Arcade endings, conditional drops and other systems, with supplemental captures, tooling and an observed normal elimination win. A later two-frame pixel audit reconstructs the recorded first-board occupancy with one correction; runtime-state corroboration and several item identities remain open. Read the integration assessment and its newer linked records before treating imported claims as verified.

## Records

- [Edition 5 input and timing](edition-5-input-and-timing.md): publisher-build provenance, reproducible source extraction, input event handling, and configured frame timing. Static findings are separated from unmeasured runtime behavior.
- [Edition 5 gameplay phases and first-blast boundary](edition-5-gameplay-phases.md): immediate human bomb handling versus frame movement, the 72-callback countdown, synchronous blast/block mutations, and the limits of mapping these to all-actor ticks.
- [Edition 5 runtime systems](edition-5-runtime-systems.md): source-traced portals/hazards, protection, drops, scoring, reachable weapon/vehicle effects, AI reconstruction and explicit conversion/parity limits; includes independently extracted rule/animation data.
- [Edition 5 structure reconstruction](edition-5-structure-reconstruction.md): primary-source startup/ownership/phase/actor/command/weapon/AI/death reconstruction, including newly corroborated bytecode findings.
- [Reverse-engineering audit and verification gaps](edition-5-reverse-engineering-audit.md): reproducible source/timeline inventory, independent XML comparisons, supplied playback-harness audit and the remaining runtime-reference gate.
- [Independent original reference session](edition-5-reference-session.md): pinned Windows player build, repeated original Normal Arcade/Cinema entry, legal movement/bomb/explosion, synchronized logs and emulator limits.
- [Reference trace design](edition-5-reference-trace-design.md): separate read-only player observation and explicit original-method fixtures, source locators and instrumentation limits.
- [Recovery tooling and build provenance](edition-5-recovery-tooling.md): canonical fourteen-patch player, historical exact patch archives, runtime validation, fixture boundaries and instrumentation corrections.
- [Reference execution/RNG events](edition-5-reference-events.md): actual calls/draws, bounded buffers, callback skips and failed whole-session observer-equivalence checks.
- [Ordinary bomb/contact probes](edition-5-bomb-contact-probes.md): legal placement, last lethal/first safe entry, capacity and soft-block changes.
- [Chain/overlap probes](edition-5-chain-overlap-probes.md): both owner orders, shared Boolean fire cleanup, late laser phase and command replacement.
- [Pause, resume and focus loss](edition-5-pause-and-focus.md): the 100 ms pause timeout, cleared movement and kept speed, host timers that run while paused, and the static focus path (#81).
- [Robot looks](edition-5-robot-looks.md): hats and outfits as frames of each direction clip's innermost `hatMc`/`bodyMc`, and the slots with no original art (action pose, blink, transit, touch controls, desktop panels) (#74).
- [Quality switch](edition-5-quality.md): `qualityCtlHandle`'s HIGH/MEDIUM/LOW cycle kept for the session, mapped to bitmap smoothing and shape anti-aliasing in the Compatibility renderer (#86).
- [Original screens](edition-5-screens.md): the 700×510 stage crop, instance positions measured from the SVG export, exposed keys as rendered, and what the replica hides, keeps inert or draws live (#76).
- [Sound and music](edition-5-audio.md): the class-linked sounds, `SoundManger`'s music rules and switches, the event-to-sound map and the names that are silent in the original (#75).
- [Item slots](edition-5-item-slots.md): reachability of the glove, bouncer, magic carpet and heavy bomb; PUSH THE BOMB and BOXING GLOVE ported, the other three unreachable (#85).
- [Robot interactions](edition-5-interactions.md): belt rides in twips, toy-hand pushes with the stale checked cell, crocodile bites, horse jumps, dragon crashes and the Pac-Man catch, each recorded in the reference player (#83).
- [Movement/portal runtime probes](edition-5-movement-runtime-probes.md): all cardinal directions, four transfers, hazardous arrival, ordinary portal bomb blocking, stationary immunity expiry and paused transit.
- [Pickup/drop probes](edition-5-pickup-probes.md): actual randomness, upgrade caps, quota/vehicle exhaustion, partial shared-list mutation and timed-spawn bypasses.
- [Protection/vehicle probes](edition-5-protection-vehicle-probes.md): shield, Invincibility, Car/Moto, contact, expiry, pause and original enemy bomb scoring.
- [Landmine lifecycle](edition-5-landmine-probes.md): one-use placement, owner departure/contact, protection, external chains, capacity underflow and teardown.
- [Weapon action recovery](edition-5-weapon-action-recovery.md): directional timelines, actual hits/emissions, control recovery, replacement and host-clock pause behavior.
- [Weapon interaction/geometry probes](edition-5-weapon-interaction-probes.md): 35 target cases, two-use exhaustion, 88 measured flamer endpoints, hand/gunpoint and source morph/timeline metadata.
- [Laser portal rays](edition-5-laser-portal-probes.md): empty, occupied and shielded portal traversal, first blocker, single damage pass, beam removal and restored movement.
- [AI trace plan](edition-5-ai-trace-plan.md) and [AI runtime probes](edition-5-ai-runtime-probes.md): profile/parser quirks, perception/search/ranking, state/route decisions, original controls and all selected weapons.
- [Death/results runtime probes](edition-5-results-runtime-probes.md): zero-kill victory, simultaneous defeat, retry hearts, HUD versus result totals and game over.
- [Stage-set openings](edition-5-stage-openings.md): 48 original Arcade openings matched exactly to the recorded templates; soft-block chance 0.6 at runtime (0.607 unseeded); Birthday Party layout 3 is an empty arena; Linux reference-player build.
- [Difficulty](edition-5-difficulty.md): observed Easy/Normal/Hard drop chance, AI range/answer time and the Easy spawn shield; `dangePerceive` is never read.
- [Kill mode](edition-5-kill-mode.md): observed hammer base action, 0.55 soft blocks, respawn at the spawn with protection, AI-versus-AI kill race and the ending at 10 kills.
- [Green Zone](edition-5-green-zone.md): observed flag placement inside the two-cell margin, no soft blocks, player speed 1.8 and the AI flag race.
- [Pac-Man](edition-5-pac-man.md): observed opening (four quadrant items, 121 coins), NullWeapon player, flamer ghosts that neither eat nor burn coins, and manager-area follow recovered from source.
- [Zoo](edition-5-zoo.md): lockstep crocodiles (observed 345-tick cycle), horse jump and dragon crash recovered from source.
- [Birthday Party](edition-5-birthday-party.md): toy hands (observed first open at 105 and drawn delays), reach, throws and pushes.
- [Candy Factory](edition-5-candy-factory.md): candy machine every 210 ticks (observed) and the 33-cell belt; no sliding platforms in Candy layouts.
- [Magic Library](edition-5-magic-library.md): spellbook drops at 481 + 518k (observed two ownerless bombs), quadrant targets, no timed pickups.
- [Stage-set tiles](edition-5-stage-tiles.md): `_brick5` holds every set's tiles; each set starts at its own `beginNum` (1, 25, 49, 73, 97, 121) and `MapMaster` picks wall, fixed-prop and soft-block frames from that run. Floor tones come from the `BackGround_<Set>` bitmap.
- [Modes, menus, progression and unlocks](edition-5-modes-and-flow.md): static recovery of Kill, Green Zone, Pac-Man, difficulty, settings, level/stage progression, per-mode scoring, unlocks and saved data, with a soft-block probability correction (Arcade 0.6, not 0.8).
- [Recovery-to-porting handoff](edition-5-porting-handoff.md): source-to-Godot classifications, accepted adaptations and the ordered fidelity implementation boundary.
- [Recovery acceptance and verification](edition-5-recovery-verification.md): ticket-by-ticket evidence, independent Standards/Spec findings and fixes, integrity checks and the unchanged 244-check Godot baseline.
- [First-bomb test excerpt](first-bomb-test-excerpt.md): source-verified CinemaStage1 cells, controlled actor setup and worked blast expectations for the headless slice; not a certified complete map.
- [Edition 5 movement and visible-board facts](edition-5-movement-and-board.md): continuous original motion, acceleration, collision/lane assistance, bomb walk-off, exact board geometry, portals and remaining occupancy uncertainty. Eight-direction phone rules are a separate adaptation.
- [CinemaStage1 recorded-board reconstruction](cinema-stage1-recorded-board.md): independently repeated two-frame image audit, corrected cell (14,10), canonical 255-cell CSV and confidence limits. Supersedes the earlier rendered-occupancy uncertainty.
- [Mobile-control design references](mobile-control-references.md): official PUBG Mobile/Wild Rift references and limits, plus the user-requested visible responsive joystick and deferred phone-testing stage. These are presentation references, not SWF rules.
- [Dots play observations and delivery assessment](edition-5-play-observations.md): organized SWF/HTML5 reports, maps, text, captures, source corrections, request fulfillment, restored supplemental evidence and remaining uncertainty.
- [Imported observation index](observations/README.md): source records and per-file inventory, with media retained in ignored investigation storage.

## Recording a finding

Create a focused Markdown record here when evidence is recovered. Include:

- Source identity: edition/build, acquisition source, local artifact location and content hash when available. Establish that it is the retail edition 5 build.
- Exact locator: script/symbol/frame, or a reproducible observation sequence and capture location.
- Observed behavior, including relevant conditions and edge cases.
- Uncertainties and inferences, separated from directly observed facts.
- Links to the affected design decision, implementation, and check as those exist.

For a map, record tile count, solids, soft blocks and spawns. For a gameplay screen, record layout and visible elements. For timing and endings, record behavior rather than inferring it solely from a screenshot.

Keep unknowns in the development frontier. When a finding conflicts with an accepted design choice, expose the conflict and ask whether a deliberate deviation is intended; do not silently replace either account. Source assets used for investigation remain subject to the packaging boundary in DESIGN.md.
