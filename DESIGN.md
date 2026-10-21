# Design

Working title: Bomb It 5. The store name is not chosen. Do not publish under the name Q版泡泡堂.

This file owns accepted product and architecture decisions. [Development](docs/development.md) owns the decision frontier and implementation gates; [evidence](docs/evidence/README.md) owns recovered facts. Accepted decisions are not proof of original behavior.

## Settled

- This is a new game. `Kurak0oo/bomb-it-1` is parked. Do not import its scenes, its 35 Hz tick, its weapons, its AI, its maps, or its tests. That port is Godot 4.7 and its tests lock Flash parity for a different game.
- The rules authority is the retail edition 5 SWF. Portal blurbs are not rules. The 无敌版 cheat build is out. Editions 4 and 7 are later diffs, read from their own SWFs, and only for features edition 5 does not already have.
- Godot 4.5, GDScript, Compatibility renderer. Keep `config/features` at 4.5. Gameplay uses 35 logical ticks per second through an external scheduler, as accepted below. The scheduler accumulates elapsed time from a Node's `_process`; leave `physics/common/physics_ticks_per_second` unset. The logical rate does not require changing Godot's global physics setting. [Edition 5 research](docs/evidence/edition-5-input-and-timing.md) independently recovers a requested stage rate of 35 fps and frame-driven updates. Inherited platform notes live in [Douyin](docs/douyin.md).
- Phone, landscape, locked. If the exporter forces portrait, the export waits. The game does not.
- The board is centered. A translucent stick sits on the left of the playfield and a translucent bomb button on the right. Both are inside the game view. Touches on the grid do nothing. The notch and the Douyin capsule stay clear of both controls. Extra item buttons wait until the SWF says an item needs its own button.
- One human against zero to three AI, chosen in Game Settings (2026-10-21, below). The first match was one human and three AI. No second human on the same phone: the original local 2-player setting is deferred.
- Later, in order: co-op against AI across phones, then PvP. No networking in the first slice. No accounts.
- A round has a replaceable ending. The selected first ending is "all enemies are dead," source-supported for normal Arcade play in the [Dots evidence assessment](docs/evidence/edition-5-play-observations.md). For the new game, timeout is a loss while enemies remain, deliberately replacing the original anomalous timeout-completion path. Later modes and tasks are another ending plus extra rules on the same round. The first build implemented one ending; the complete game adds the other selectable edition 5 modes on the same round (2026-10-21, below).
- Before the SWF is read, the only bomb behavior that may be coded is the shared match: place a bomb, a fuse, a plus-shaped blast, and soft blocks that break. The glove, the bouncer, the magic carpet, and the heavy bomb are named empty slots. Nothing fills a slot from a portal description.
- Maps come from the original edition 5 game. Tile count, solids, soft blocks, and spawns are recovered. There is no stand-in 15×13 board and no map generator. The complete game rolls boards from recorded layouts as the original does; invented maps may later arrive through the same map-data seam (2026-10-21, below).
- The gameplay screen's layout and the elements on it come from the original gameplay screen. Painted pixels are redrawn later in that painting style. Unmodified copies of SWF sprites, music, and level art stay out of the Douyin build. SWF-derived art may be modified into candidate art. Candidates are never applied automatically; the user reviews each one before Apply to game (2026-10-21, below).
- Soft blocks drop nothing until source evidence establishes the behavior. [Conditional-drop evidence has now been supplied](docs/evidence/edition-5-play-observations.md); implementation must follow its verified conditions rather than assuming guaranteed drops.

- Each tick consumes one command per actor: a direction plus an ordered list of bomb input events. The stick fills the human command; AI will fill the other three. A later phone can replace one AI command. The first tick does not draw or use sockets.
- The clock, lives, score, and win and loss conditions come from the edition 5 match, subject to the explicit adaptations below. They stay empty until one map and one gameplay screen have been read, with behavior evidence for the relevant rules. A student remake's 15×13 board and 3-minute clock are not evidence.

The command boundary and fidelity scope were accepted by the user on 2026-10-16 in response to the two-question interview. Acceptance does not mean implementation is complete.

## Command calling contract

Accepted and confirmed in the command-boundary interview on 2026-10-16:

- An explicit `advance(commands)` call advances one logical tick when its input is accepted. Scheduling is external to this first slice; it does not automatically advance through Godot's physics loop.
- The boundary receives its actor roster at creation. The roster stays fixed for the round. The first match supplies four actors; the boundary does not hard-code that count. A later remote player replaces an actor's controller rather than adding an actor.
- Each call supplies exactly one command for every registered actor. Input producers explicitly supply idle commands when appropriate.
- Missing, duplicate, or unknown actors reject the entire tick before any state advances. Missing commands are neither treated as idle nor replaced by previous commands.

These are engineering choices for the new game, not recovered SWF facts. Implementation status and checks are tracked in [development](docs/development.md).

## Accepted adaptations (2026-10-17)

The user accepted all five recommendations in the resumed interview. These amend the earlier payload and fidelity scope; implementation status is tracked in [development](docs/development.md).

1. **Ordered bomb events:** replace the command's two bomb booleans with an ordered list of delivered down/up events. Preserve order and repeated down events, including press/release/press between ticks. An empty list means no bomb events. One command per actor, the fixed roster and atomic rejection remain unchanged.
2. **Scheduling:** an external scheduler calls `advance(commands)` at 35 logical ticks per second. Rendering may run independently. A Node accumulates rendered-frame elapsed time; catch-up policy is specified below.
3. **Round clock:** count down from 180 seconds of simulation time; stop advancing it while paused. This deliberately replaces the original Date-based seconds polling and its missed-seconds behavior during stalls.
4. **Timeout:** expiry is a loss while enemies remain. Preserve elimination of all enemies as the normal victory condition; do not copy the original timeout-win anomaly.
5. **Readable labels:** show the intended readable text rather than exposed localization keys such as `P_PAUSE` or `L_TOTAL SCORE`. The release language remains undecided.

Placement, newborn-countdown timing and bomb-input phase order are specified below. Analog-stick direction policy belongs to the later control adapter.

## Scheduling and input lifecycle (2026-10-18)

The user accepted Q6–Q8. Implementation status is tracked in [development](docs/development.md):

- **Bounded catch-up:** run at most five logical ticks per rendered frame, then discard excess accumulated time. The simulation clock advances only for accepted ticks actually processed. This is a policy for possible long update delays, not a report of an observed freeze.
- **Pause and focus:** losing focus automatically pauses gameplay. Require explicit resume and clear held controls and queued gameplay input across pause/resume; gameplay needs fresh input after resuming. Paused time does not generate simulation catch-up debt.
- **Event cutoff and ownership:** a tick takes the bomb events available at its start. Consume that captured batch only when the command batch is accepted; rejection retains it. Events arriving after the cutoff remain for the next tick, and an accepted event is consumed exactly once.

## First bomb/soft-block slice (2026-10-18)

The user accepted Q9–Q13 in the gameplay interview:

- **Placement before movement:** bomb placement uses the actor's cell before that tick's movement. Movement itself remains outside this implementation slice.
- **Newborn fuse:** a bomb created on accepted tick N receives its first countdown on accepted tick N+1. Normal timed detonation occurs on N+72 unless a chain reaction detonates it earlier. Rejected batches do not advance the countdown. The 72-callback boundary comes from [the recovered source](docs/evidence/edition-5-gameplay-phases.md); the uniform creation-tick offset is an explicit batching adaptation, not a claim of universal SWF timing.
- **Actor priority:** resolve actors' bomb input in fixed roster order, preserving each actor's event order. The caller's command-array order does not change gameplay priority. A successful placement occupies its cell immediately; if actors compete for the same free cell, the first successful placement wins.
- **Tick phase order:** after admitting the complete command batch, apply bomb input first, then advance existing bomb countdowns and resolve explosions, then move actors when movement is implemented. Newborn bombs remain excluded from their creation tick's countdown. A rejected batch changes no gameplay state. A failed placement within an accepted batch still consumes its input event; it is not deferred for automatic retry.
- **Implementation scope:** build headless placement → fuse → blast → soft-block removal using a source-verified board excerpt strictly as a test fixture. The excerpt does not certify or replace the full first board. Actor movement, damage, drops, AI, rendering and full-board certification belong to subsequent slices; deferring drops does not redefine the source-supported drop rules.

For example, with capacity one, a bomb placed on tick 1 detonates on tick 73. Another down event on tick 73 fails while that bomb still occupies capacity, then the explosion frees capacity. Placement requires another delivered down event on a later tick and must still pass the normal cell/capacity checks.

## First visible practice preview (2026-10-19)

The user accepted Q14, Q15, Q16 and Q18, and replaced Q17's recommendation:

- **Practice scope:** open directly onto a clearly labelled practice board with one controllable actor, Pause/Resume and Reset. Movement, visible bombs and breaking blocks are an intermediate milestone toward the complete runnable Godot 4.5 game. Practice alone is not the final deliverable. AI, damage and match endings remain subsequent implementation work; the accepted first full match still means one human plus three AI.
- **Temporary presentation:** use original geometric shapes and colours that distinguish floor, solids, soft blocks, actor, bombs and blasts. Preserve recovered layout relationships and the accepted phone-control placement. Finished redrawn artwork follows later; unmodified SWF artwork is not the preview's production art. Reviewed SWF-derived candidate art is permitted from 2026-10-21.
- **Desktop development input:** also support Arrow keys and Space through the same command path as touch. Preserve the recovered keyboard direction priority.
- **Eight-direction phone control:** the stick supports up, down, left, right and the four diagonals. The proposed four-direction dominant-axis mapping is rejected. This is an intentional adaptation from the original controller, with acknowledged difficulty implications. No one-cell-per-input movement rule is accepted.
- **Equal directional speed (Q19):** diagonal travel has the same top speed as straight travel. Normalize diagonal direction rather than combining two full-speed axes. Acceleration and stick-deflection response remain separate tuning decisions.
- **Diagonal collision (Q20):** respect the actor's full collision footprint. Slide along an unblocked axis when another is blocked; do not pass through solids, soft blocks, bombs or the gap between touching blocked corners. Q25 below defines departure from an already overlapping bomb.
- **Shared movement capability (Q21):** later AI and humans use the same eight-direction physical movement capability and collision rules. AI route selection and behavior remain later work, outside the one-actor practice preview.
- **Touch bomb events:** finger-down delivers one down event and release delivers one up event, without synthesized repeat while held. Another attempt requires another press. Delivered desktop key-repeat events remain preserved under the ordered-command contract.
- **Development/testing sequence (replacement Q22):** do not build an early phone-control prototype or require physical phone tests during initial development. First make the main Godot game ready for publication; phone/iOS testing follows at that stage. Desktop and automated verification still proceed during Godot development. This staging decision does not replace the existing Douyin scope with an already-designed iOS release.
- **Visible fixed stick (Q23):** keep the joystick base fixed and visible, with a generous touch area. Its demonstration and animation must respond clearly to input. Use mature mobile games such as PUBG Mobile and Honor of Kings as presentation references; [the reference record](docs/evidence/mobile-control-references.md) distinguishes verified observations from this project's own feedback choices.
- **Stick deflection (Q24):** outside the central deadzone, request normal movement speed; pushing farther does not add a speed boost. Acceleration remains separate from the input request. Visual feedback still responds to the thumb's input.
- **Bomb-overlap departure (Q25):** an actor already overlapping a bomb may leave that bomb. Once fully clear, the bomb blocks re-entry. Apply the rule to all actors regardless of ownership. This explicitly adapts the original geometric bypass to the new movement model.
- **Runnable Godot delivery (Q26 clarification):** the main deliverable is the whole runnable game implemented in Godot 4.5 within the accepted first-build scope. The practice board is an integration milestone on that path. Main Godot development precedes physical phone/iOS testing at publication readiness. This answer clarifies delivery scope; it does not approve the earlier proposed exact acceleration/heading-response profile.
- **Corridor assistance (Q27):** gently align an actor with an open corridor using part of its normal movement distance. Respect the complete collision footprint throughout, with no teleporting or blocked-corner shortcuts.
- **Recorded practice layout (Q28):** use the [reconstructed CinemaStage1 instance](docs/evidence/cinema-stage1-recorded-board.md) with its paired portals working. Reset restores that fixed layout. It is a source-derived recorded instance, not a generated replacement map.

The [source movement record](docs/evidence/edition-5-movement-and-board.md) establishes continuous original movement, acceleration and lane assistance. Q19–Q21, Q23–Q25 and Q27–Q28 were accepted on 2026-10-19; Q22 and Q26 clarify full Godot delivery before phone/iOS evaluation. The recovered movement is the baseline for implementation; exact acceleration tuning is not an independently accepted new rule. Physical phone evaluation is deferred to the accepted later stage and is not a prerequisite for initial implementation.

## Complete game specification and testing boundary (2026-10-19)

The [complete runnable Godot game specification](docs/specs/runnable-godot-game.md) consolidates the accepted scope through Q28, completion criteria and remaining source-recovery prerequisites. It does not replace evidence records or resolve unaccepted gameplay choices. The user confirmed testing through the existing scheduler and real round simulation, observing public state/results, with a small set of scene tests for controls, display and playable flow. Prefer that shared boundary over separate test interfaces for internal gameplay modules.

## Desktop assessment priorities (2026-10-19)

The user deferred further joystick polish to the physical phone-testing stage. Retain the current functional fixed eight-direction control during desktop assessment; do not make joystick refinement a new prerequisite for that stage.

Following desktop play, the user prioritizes reproducing original edition 5 gameplay feel and logic before replacing presentation with final original artwork. Audit animation-driven attack timing, movement interruption/recovery and damage geometry against the actual edition 5 SWF; replacing pictures alone is not fidelity. Use original source, animations and reference playback to establish the behavior. The edition 1 project is a workflow comparison, not a source for importing code or assets. Existing accepted timing/input/diagonal adaptations and the production asset boundary remain in effect.

The user subsequently requests reverse engineering first. Reconstruct and verify the original selected-scope ownership, execution order, command/AI lifecycles and animation-dependent behavior before further fidelity porting or final redraw. Static decompilation, bytecode corroboration, runtime observation and matched replay are different levels of evidence; do not call a source inventory or new-game test suite complete original-game parity. Keep the current playable build available while this recovery proceeds.

The subsequent implement instruction approves the 16 recovery tickets [#22–#37](https://github.com/Kurak0oo/bomb-it-5/issues/22), covering controlled original playback, bomb/fire/phase edges, movement/portals, items/vehicles/weapons, Normal AI and death/results, ending in a reviewed porting handoff. These are evidence-recovery gates before further fidelity implementation. They preserve the accepted adaptations above and do not resolve the four deferred item slots, approve finished artwork or require early phone tests.

## Decision history

### Complete original game scope (2026-10-21)

The user widened delivery from the playable arena to the complete edition 5 game.
The [source findings](docs/evidence/observations/swf-v1.6.1/source-findings.md)
list what the original offers; recovered rules still precede implementation.

- **Modes:** all four modes selectable in edition 5 ship together: Arcade, Kill
  (Battle Royale), Green Zone and Pac-Man. Each mode's ending, lives, respawn,
  pickups and drop table come from the recovered source. Mode classes that edition 5
  cannot select (Speed, Water, Collect, Painting) stay out.
- **Screens:** main menu, Game Settings (mode, enemies, levels, stage, difficulty),
  character select of the eight robots, How to Play with the power-up reference,
  desktop key rebinding, pause with Main Menu, per-level score, game-win and
  game-over screens. The publisher's MORE GAMES link is not included. Touch
  controls keep the accepted fixed layout.
- **Content:** all six stage sets and their recorded layouts, level progression
  across sets, and Easy, Normal and Hard.
- **Unlocks:** the original cloth and hat unlocks are included and saved locally
  on the device. There are no accounts.
- **Players:** one human against zero to three AI. Local 2-player is deferred;
  co-op across phones, then PvP, remain the later multiplayer order.
- **Extensibility:** future modes, maps, rules and enemy designs plug into the same
  admitted round and scheduler rather than forking it. A mode supplies its ending,
  settings, permitted pickups, drop table and respawn rules; a map is data; enemy
  behavior and difficulty are AI profiles. The accepted adaptations (35-tick
  scheduler, pause and input lifecycle, eight-direction movement, bomb batch rules,
  bomb-overlap departure) apply in every mode.
- **Boards:** each round picks one of the stage set's recorded layouts and rolls
  its soft blocks with the source probability, as edition 5 does, in every mode.
  Boards enter the round as map data, so invented maps can be added later through
  the same seam; none are built now.
- **Timeouts:** Kill, Green Zone and Pac-Man use each mode's recovered timeout
  judgment. A clear source defect is fixed only by an explicit decision, as with
  Arcade's loss-on-timeout adaptation.
- **Practice:** the fixed practice board stays a development launch, used by the
  workbench's Preview in game and by tests. It is not on the player menu.
- **Art slots:** the workbench catalogue grows to cover all eight robots, the
  unlock cosmetics, the new screens and the other stage-set skins, with native
  defaults. Finished-art gate #20 covers the larger catalogue.
- **Levels:** Game Settings offers 5, 10, 15 and 20 levels, defaulting to 5. The
  source's 5 button sets one level; that defect is deliberately fixed.
- **Enemies:** one player chooses one to three AI, as in the source. Zero enemies
  remains a deferred two-player option.
- **Evidence before porting:** each mode, difficulty and stage-set map feature is
  observed in the original game with the reference player and recorded before it
  is ported, as Normal Arcade was. Static reading alone does not certify parity.
  Recovered facts live in [modes and flow](docs/evidence/edition-5-modes-and-flow.md).
- **Tracking:** a new parent specification and its tickets carry this work. Final
  desktop acceptance #21 is blocked by them, as well as by #20, and verifies the
  complete game. #20 stays open.

This supersedes the first build's single-map Normal Arcade scope recorded below.
The recorded CinemaStage1 instance remains the practice layout.
[ADR 0007](docs/adr/0007-complete-edition-5-game.md) records the rationale; open
follow-up decisions are on the [frontier](docs/development.md).

### SWF-derived candidate art (2026-10-21)

The user permits artwork extracted from the edition 5 SWF to be modified into
candidate art for the workbench's named slots. A local batch pipeline produces
candidates with small, configurable changes and a review page. Candidates are
never applied automatically: the pipeline does not write the active manifest or
the imports folder, and the user manually reviews each candidate before choosing
it through Apply to game. A change percentage is a review aid, not approval.

The SWF and all extracted or generated images stay in ignored local storage and
are not committed. Unmodified SWF art, music and branding are not production
assets. Original screenshots remain view-only reference context. This decision
does not settle release rights, store identity or the finished-redraw gate #20.
[ADR 0006](docs/adr/0006-swf-derived-candidate-art.md) records the rationale;
[the pipeline README](tools/art_pipeline/README.md) describes the workflow.

### User-controlled artwork workbench (2026-10-20)

The user rejected the generated painted art pass and requested its rollback and
a workbench to see and replace the game's visual components by clicking. The
previous temporary presentation remains the default; the rejected art is not an
approved style. Presentation #20 is reopened, and final acceptance #21 stays open.

Provide a searchable catalogue, applied-versus-draft previews, image import,
sprite-frame/facing/scale/offset controls, animation play/pause/scrubbing, reset,
undo and a real-game preview. Changes become normal-play choices only through
Apply to game. A shared named-slot mapping feeds both the tool and the renderer;
missing replacements retain existing drawings. Original SWF screenshots are
view-only research context and cannot be selected through the reference viewer
as production replacements. The workbench does not select another art style or
alter gameplay timing, damage, collision, inputs or the fixed board.

This is a local desktop authoring workflow. Physical phone/iOS tests, export,
store identity and release-language selection remain separate. Implementation
details and launch instructions live in [the workbench guide](docs/art-workbench.md).

### Fidelity implementation conversions (2026-10-20)

The user's implement instruction approves fidelity tickets #38–#55. Recovered
ownership is represented behind the same admitted round, with no second gameplay
clock. These conversions make the accepted simulation-time, command and pause
policies concrete; they do not certify native Flash equivalence:

- Resolve an admitted nonzero heading before starting an available action, while
  retaining the tick-start placement position. A locked action can turn and start
  without displacement or an AI-only facing setter. Both controllers use this
  command path; existing actions/transit retain their input locks.
- Convert host durations to simulation deadlines with ceiling to a tick: vehicle
  recovery 1 second/35 ticks; projectile recovery 0.3 seconds/11 ticks; ending
  cartoon 3 seconds/105 ticks; AI delays 0.1/0.15/0.2/0.3/2 seconds become
  4/6/7/11/70 ticks. These are conversions, not measured universal SWF callback
  counts. Pause freezes them and resume consumes no stale input.
- Keep callback-counted hazard cleanup separate from visible animation and map
  occupancy. Preserve live removal skips within translated registries, Boolean
  overlapping fire, mine counter/scoring quirks and item-list/parser behavior.
  Original cross-registry order remains mapped to the accepted phases.
- Keep death detachment, death-movie completion, ending judgment, cartoon and
  settlement distinct. The round countdown runs until judgment and freezes during
  the cartoon; a retry heart is spent once at loss settlement. The admitted
  scheduler continues advancing the frozen-world cartoon until settlement.

The [fidelity verification record](docs/verification/fidelity-2026-10-20/README.md)
owns comparison coverage and limits. [ADR 0005](docs/adr/0005-integrate-gameplay-through-the-round.md)
records the rationale. Existing finished-redraw #20 and desktop acceptance #21
remain separate gates, followed by deferred physical phone/iOS evaluation.

Implementation policy recorded during the user's 2026-10-19 instruction to implement the complete ticket graph without permission stops:

- The playable first build uses Normal Arcade settings and the recorded Cinema board. Retry/play-again reuses that board within the selected single-map scope; it does not add a campaign or a generator. Session hearts and result totals carry across permitted retries/play-again; a new session starts fresh.
- Admitted directions must be finite vectors. After admission, expire old hazards, apply bomb/action input, resolve existing bombs/chains, advance weapon callbacks and portal transfers, move actors, evaluate ongoing fire contact, process delayed drops/collections and invincibility contact, then evaluate the ending. Human defeat has priority over simultaneous enemy elimination; elimination has priority over timeout when no enemies remain.
- Human and AI movement remains eight-direction capable. Recovered cardinal weapon effects aim on the dominant facing axis, with vertical ties. New vector animation durations and tick conversions are documented with their source; original pixel-level attack bounds and exact AI-state-machine parity are not asserted.
- Keep both unresolved glove candidates disabled under the existing named-slot deferral. A reserved candidate draw produces no item rather than changing the remaining drop weights. This explicit first-build omission does not mean those items are absent from edition 5.

[Runtime evidence](docs/evidence/edition-5-runtime-systems.md) and [round integration rationale](docs/adr/0005-integrate-gameplay-through-the-round.md) distinguish recovered rules from these implementation policies. Physical phone/iOS evaluation and export remain deferred.

[Edition 5 as the rules authority](docs/adr/0001-edition-5-authority.md) records the rationale for the source boundary. Current rules remain here; ADRs explain consequential choices.

[Adapt original input and timing for the new game](docs/adr/0002-input-and-timing-adaptations.md) records the consequential trade-offs behind the 2026-10-17 and 2026-10-18 amendments.

[Make bomb batches consistent across controllers](docs/adr/0003-bomb-batch-timing.md) records the rationale for uniform newborn countdowns and fixed roster priority.

[Permit eight-direction phone movement](docs/adr/0004-eight-direction-phone-movement.md) records the deliberate change from the original cardinal controller.

[Permit SWF-derived candidate art under manual review](docs/adr/0006-swf-derived-candidate-art.md) records the 2026-10-21 change to the production-asset boundary.

[Expand delivery to the complete edition 5 game](docs/adr/0007-complete-edition-5-game.md) records the 2026-10-21 widening of scope to every selectable mode, screen and stage set.
