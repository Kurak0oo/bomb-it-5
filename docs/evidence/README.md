# Original-game evidence

The evidence starts with the hashed publisher build and separates static findings, supplied play observations, and independently checked artifacts. The Dots delivery adds source support for normal Arcade endings, conditional drops and other systems, with supplemental captures, tooling and an observed normal elimination win; some map occupancy and item identities remain uncertain. Read the integration assessment before treating imported claims as verified.

## Records

- [Edition 5 input and timing](edition-5-input-and-timing.md): publisher-build provenance, reproducible source extraction, input event handling, and configured frame timing. Static findings are separated from unmeasured runtime behavior.
- [Edition 5 gameplay phases and first-blast boundary](edition-5-gameplay-phases.md): immediate human bomb handling versus frame movement, the 72-callback countdown, synchronous blast/block mutations, and the limits of mapping these to all-actor ticks.
- [First-bomb test excerpt](first-bomb-test-excerpt.md): source-verified CinemaStage1 cells, controlled actor setup and worked blast expectations for the headless slice; not a certified complete map.
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
