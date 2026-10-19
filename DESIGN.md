# Design

Working title: Bomb It 5. The store name is not chosen. Do not publish under the name Q版泡泡堂.

This file owns accepted product and architecture decisions. [Development](docs/development.md) owns the decision frontier and implementation gates; [evidence](docs/evidence/README.md) owns recovered facts. Accepted decisions are not proof of original behavior.

## Settled

- This is a new game. `Kurak0oo/bomb-it-1` is parked. Do not import its scenes, its 35 Hz tick, its weapons, its AI, its maps, or its tests. That port is Godot 4.7 and its tests lock Flash parity for a different game.
- The rules authority is the retail edition 5 SWF. Portal blurbs are not rules. The 无敌版 cheat build is out. Editions 4 and 7 are later diffs, read from their own SWFs, and only for features edition 5 does not already have.
- Godot 4.5, GDScript, Compatibility renderer. Keep `config/features` at 4.5. Gameplay uses 35 logical ticks per second through an external scheduler, as accepted below. The scheduler accumulates elapsed time from a Node's `_process`; leave `physics/common/physics_ticks_per_second` unset. The logical rate does not require changing Godot's global physics setting. [Edition 5 research](docs/evidence/edition-5-input-and-timing.md) independently recovers a requested stage rate of 35 fps and frame-driven updates. Inherited platform notes live in [Douyin](docs/douyin.md).
- Phone, landscape, locked. If the exporter forces portrait, the export waits. The game does not.
- The board is centered. A translucent stick sits on the left of the playfield and a translucent bomb button on the right. Both are inside the game view. Touches on the grid do nothing. The notch and the Douyin capsule stay clear of both controls. Extra item buttons wait until the SWF says an item needs its own button.
- One human and three AI on the first match. No second human on the same phone.
- Later, in order: co-op against AI across phones, then PvP. No networking in the first slice. No accounts.
- A round has a replaceable ending. The selected first ending is "all enemies are dead," source-supported for normal Arcade play in the [Dots evidence assessment](docs/evidence/edition-5-play-observations.md). For the new game, timeout is a loss while enemies remain, deliberately replacing the original anomalous timeout-completion path. Later modes and tasks are another ending plus extra rules on the same round. The first build implements one ending.
- Before the SWF is read, the only bomb behavior that may be coded is the shared match: place a bomb, a fuse, a plus-shaped blast, and soft blocks that break. The glove, the bouncer, the magic carpet, and the heavy bomb are named empty slots. Nothing fills a slot from a portal description.
- Maps come from the original edition 5 game. Tile count, solids, soft blocks, and spawns are recovered. There is no stand-in 15×13 board and no map generator.
- The gameplay screen's layout and the elements on it come from the original gameplay screen. Painted pixels are redrawn later in that painting style. Copied SWF sprites, music, and level art stay out of the Douyin build.
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

## Decision history

[Edition 5 as the rules authority](docs/adr/0001-edition-5-authority.md) records the rationale for the source boundary. Current rules remain here; ADRs explain consequential choices.

[Adapt original input and timing for the new game](docs/adr/0002-input-and-timing-adaptations.md) records the consequential trade-offs behind the 2026-10-17 and 2026-10-18 amendments.

[Make bomb batches consistent across controllers](docs/adr/0003-bomb-batch-timing.md) records the rationale for uniform newborn countdowns and fixed roster priority.
