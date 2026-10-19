# Original-game evidence

The evidence starts with the hashed publisher build and separates static findings, supplied play observations, and independently checked artifacts. The Dots delivery adds source support for normal Arcade endings, conditional drops and other systems, with supplemental captures, tooling and an observed normal elimination win. A later two-frame pixel audit reconstructs the recorded first-board occupancy with one correction; runtime-state corroboration and several item identities remain open. Read the integration assessment and its newer linked records before treating imported claims as verified.

## Records

- [Edition 5 input and timing](edition-5-input-and-timing.md): publisher-build provenance, reproducible source extraction, input event handling, and configured frame timing. Static findings are separated from unmeasured runtime behavior.
- [Edition 5 gameplay phases and first-blast boundary](edition-5-gameplay-phases.md): immediate human bomb handling versus frame movement, the 72-callback countdown, synchronous blast/block mutations, and the limits of mapping these to all-actor ticks.
- [Edition 5 runtime systems](edition-5-runtime-systems.md): source-traced portals/hazards, protection, drops, scoring, reachable weapon/vehicle effects, AI reconstruction and explicit conversion/parity limits; includes independently extracted rule/animation data.
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
