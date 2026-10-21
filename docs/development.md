# Development and decision frontier

## Current boundary

The generated art pass was rejected by the user on 2026-10-20 and reverted in
`0f41b43` / `8211c82`; the gameplay fidelity commits remain. Presentation #20 is
reopened and #21 remains open. The user now owns art selection through the
[Art Workbench](art-workbench.md): 89 visual slots, native default previews,
applied/draft comparison, view-only original context, imported images and sheets,
animation/facing/placement controls, undo/reset and preview in the actual game.
The checked-in active manifest is empty, so normal play keeps the earlier native
presentation. The workbench passes 27 UI/rendering checks and independent Standards
and Spec review, with no outstanding findings. Status and verification are recorded
in [the workbench verification](verification/art-workbench-2026-10-20/README.md).

Fidelity implementation #38–#55 is implemented, desktop-verified and reviewed on
2026-10-20, approved by the user's implement instruction. The graph has 18 tickets and 32 native blocker
edges; #20 additionally waits for #55. Source-grounded regressions use the real
scheduler/round with copied controller observations and focused scene checks.
See [verification](verification/fidelity-2026-10-20/README.md) for coverage,
conversions and completed Standards/Spec reviews. All 408 checks pass, including
164 focused fidelity checks and three full-board playthroughs; 14 production
scripts parse/typecheck. These counts are not a claim of complete original-runtime
parity. DESIGN.md records the implementation conversions
under its decision history. Finished original artwork #20, final desktop/human
acceptance #21 and later physical phone/iOS evaluation remain separate.

The 2026-10-16 repository audit found an empty main scene and project configuration, with no gameplay scripts, tests, SWF, or recovery records. Inspect the files for subsequent implementation state.

The Godot 4.5 desktop game is runnable. It opens in one-actor practice and offers a local match against three AI on the recorded Cinema board. Continuous cardinal/diagonal movement, collision/corridor assistance, paired portals, ordinary bombs/chains, persistent hazards, damage/protection, conditional pickups, source-reachable weapons/rides, round time/endings, lives/score/HUD, results/retry/new-session flow and temporary original vector presentation are integrated. The scene drives one scheduler and consumes owned round results. The original 244-check baseline is extended to 408 passing checks by the reviewed fidelity work, with inspected rendered captures in the linked verification record; physical phone/iOS testing and export remain deferred. The four named unresolved item slots remain empty. Read [runtime evidence](evidence/edition-5-runtime-systems.md) for source mappings, explicit omissions and parity limits.

The [complete runnable Godot game specification](specs/runnable-godot-game.md) consolidates the accepted delivery scope through Q28, with user-confirmed tests through the existing scheduler/real round and a small scene-test layer. It preserves practice as an intermediate milestone and physical phone/iOS testing after publication-ready Godot development. Source-recovery prerequisites are explicit rather than treated as settled behavior. GitHub Issues and the default triage vocabulary are configured; the specification is published as [issue #1](https://github.com/Kurak0oo/bomb-it-5/issues/1) with `ready-for-agent`. The approved 20-ticket implementation graph is published as issues #2–#21 with 29 native blocking edges. Gameplay functionality is implemented and desktop checks pass; presentation #20 and final acceptance #21 remain open pending source-feel parity work, the finished redraw and desktop play-quality assessment. Further joystick polish is deferred to physical phone testing by the user. Consult live issue states before claiming subsequent work.

The reverse-engineering-first recovery and selected fidelity port are complete. The [first audit](evidence/edition-5-reverse-engineering-audit.md) is historical static/source preparation. Independent original playback and controlled dynamic traces are recorded in the [evidence index](evidence/README.md); the [fidelity verification](verification/fidelity-2026-10-20/README.md) records which recovered behavior is now ported, comparison coverage and bounded remaining differences. Final artwork and human desktop acceptance are the next delivery gates.

The user approved the 16 recovery-ticket breakdown by invoking implement. Issues [#22–#37](https://github.com/Kurak0oo/bomb-it-5/issues/22) are published with 29 verified native blocking edges. #22–#37 now meet the reviewed selected-scope recovery criteria. The [acceptance audit](evidence/edition-5-recovery-verification.md) records the evidence, review findings/fixes and checks. The [reviewed handoff](evidence/edition-5-porting-handoff.md) maps recovered behavior to current Godot differences. The [canonical tooling record](evidence/edition-5-recovery-tooling.md) preserves builds, exact patches and instrumentation limits. Parent #1 is unchanged, and presentation #20/final acceptance #21 stay open. Complete original-runtime evidence against each ticket's criteria before closure; the new-game tests do not substitute for it.

## Decision tree

| Branch | State | Prerequisite / next action |
| --- | --- | --- |
| Rules authority | Settled | Edition 5; see DESIGN.md and ADR 0001 |
| Reverse engineering before fidelity rebuilding | Recovery #22–#37 complete; fidelity #38–#55 implemented and reviewed on 2026-10-20 | Read the [porting handoff](evidence/edition-5-porting-handoff.md), [evidence index](evidence/README.md) and [port verification](verification/fidelity-2026-10-20/README.md). Finished redraw #20 precedes final human desktop acceptance #21; 408 passing checks are not complete paired parity |
| Command calling contract | Implemented and checked on 2026-10-16 | See DESIGN.md for accepted behavior and the interface below |
| Fidelity of clock, lives, score and endings | Settled on 2026-10-16 | Recover exact behavior before implementation |
| Original input and timing | Static source recovered on 2026-10-16 | Read [the evidence](evidence/edition-5-input-and-timing.md); runtime cadence and lifecycle edge cases remain unmeasured |
| Ordered commands and event capture | Implemented and checked on 2026-10-18 | Ordered down/up lists preserve repeats; tick-start captures retain their cutoff through rejection and commit once after acceptance |
| Tick scheduling and pause/focus reset | Implemented and checked on 2026-10-18; bomb target integrated on 2026-10-19 | One scheduler drives 35 logical ticks/sec with bounded catch-up, cleared input and explicit resume after focus loss; visible controls and AI producers are integrated |
| First bomb/soft-block batch semantics | Implemented and checked on 2026-10-19 | Input before existing countdowns/blasts, newborn countdown from the following tick, roster priority and test-only board excerpt. Real scheduler integration includes pause/focus and bounded catch-up; see [phase evidence](evidence/edition-5-gameplay-phases.md) |
| First visible controllable board | Implemented, reviewed and desktop-verified on 2026-10-19 | Whole runnable Godot 4.5 game is the delivery target; practice is an intermediate milestone. Corridor assistance and full recorded CinemaStage1 with working portals are accepted. Physical phone/iOS tests follow publication-ready Godot development |
| Complete runnable game specification | Published on 2026-10-19; test boundary confirmed | [Specification](specs/runnable-godot-game.md) covers full delivery and source prerequisites; [issue #1](https://github.com/Kurak0oo/bomb-it-5/issues/1) carries `ready-for-agent`. Approved implementation tickets #2–#21 are published |
| Complete game implementation graph | 20 tickets and 29 native blocking edges verified on 2026-10-19 | Gameplay tickets #2–#19 are complete; presentation #20 and final acceptance #21 remain open. Passing functional checks does not accept the finished artwork or release readiness. [Issue #21](https://github.com/Kurak0oo/bomb-it-5/issues/21) is the complete desktop Godot acceptance gate before deferred physical phone/iOS testing |
| First board and gameplay screen | Rendered CinemaStage1 audited and selected for practice on 2026-10-19 | [Canonical 255-cell reconstruction](evidence/cinema-stage1-recorded-board.md): all 110 soft candidates resolved, (14,10) corrected. Paired portals are in practice scope. This is image evidence, not a runtime collision dump |
| Bomb, soft block, damage, clock, lives and score | Static findings, logged probes and repeats imported | Read the assessment: 72 countdown callbacks; distinguish input-counter and first-visible-frame timing. Quantized/sampled probes and no independent replay limit generalization |
| Original items and AI | Glove candidates demonstrated; other slots unidentified | BoxingProp uses Space punches; BombShoesProp passively kicks on contact. Choose which fills the empty glove slot; keep bouncer/carpet/heavy bomb unresolved despite broader search. The source-grounded Normal controller is implemented; exact original state-machine parity is not claimed |
| Arcade timeout, clock and text fidelity | Implemented and checked on 2026-10-19 | 180 simulation seconds, pause stops clock; timeout loses if enemies remain; readable labels. Clock and timeout deliberately depart from original behavior; release language remains open |
| Store name | Open, independent | Decide before publishing; does not block the first slice |
| Art selection and replacement workflow | User rejected generated art; desktop workbench implemented on 2026-10-20; SWF-derived candidate art permitted on 2026-10-21 | Choose and preview replacements per visual slot, then Apply to game. The [art pipeline](../tools/art_pipeline/README.md) produces ignored candidates for manual review only; it never applies them. No art style is approved by tooling checks. #20 stays open until presentation acceptance; #21 follows |
| Complete edition 5 game scope | Accepted on 2026-10-21, follow-ups settled; specification not yet drafted | All four selectable modes, original board rolls with a seam for invented maps, per-mode source timeouts, practice as a development launch, an extended workbench catalogue, menu/settings/character select/How to Play/key rebinding/pause/score screens, six stage sets with levels, three difficulties and local cloth/hat unlocks; one human against 0–3 AI. See DESIGN.md and ADR 0007. Next: recover mode/difficulty/unlock rules, then draft a new parent specification and tickets for approval. #21 will be blocked by them; #20 stays open |
| Co-op, then PvP | Deferred | First local slice precedes networking design. Local 2-player on one device is deferred (2026-10-21) |
| Douyin export | Deferred | Consult douyin.md when export work is requested |

The Q1–Q13 command/bomb decisions are implemented. Subsequent decisions through Q28 settle the preview/input/collision scope, including replacement Q17 (eight directions), replacement Q22 (late phone/iOS testing), and Q26's complete runnable Godot 4.5 delivery target. Practice is an intermediate integration milestone. Corridor assistance and the reconstructed CinemaStage1 board with working portals are accepted; exact acceleration tuning is implementation work grounded in the recovered source, not an approved new profile. Main Godot development uses desktop and automated verification and does not wait for a phone prototype. AI, damage, round clock, endings, score/lives, HUD and complete playable flow are now integrated and desktop-verified. Glove-slot identity and three unidentified item slots remain separate later branches. Store name and release language can remain deferred. Runtime facts still need investigation where they affect a proposed choice.

## Interview updates

### 2026-10-21 complete edition 5 game scope

The user asked to turn the playable arena into the complete game, with the
original menus and modes. Accepted answers: all four selectable modes together,
with future modes, maps, rules and enemy designs kept easy to add; menu, settings,
character select, How to Play with key rebinding, and cloth/hat unlocks; local
2-player deferred; a new specification whose tickets block final acceptance #21.
#20 stays open. DESIGN.md and [ADR 0007](adr/0007-complete-edition-5-game.md)
record the scope. No implementation or tracker changes were made.

The follow-ups were settled in the same interview: original layout picks and
soft-block rolls in every mode, with a map-data seam for invented maps later;
each mode's recovered timeout judgment; practice as a development launch only;
and a workbench catalogue extended to eight robots, cosmetics, new screens and
stage-set skins. Next: recover the mode, difficulty, stage-set and unlock rules
not yet in evidence, then draft the parent specification and ticket graph for
approval.

### 2026-10-21 SWF-derived candidate art

The user decided that art extracted from the edition 5 SWF may be modified into
candidate art for the workbench slots, with every candidate manually reviewed
before Apply to game. DESIGN.md and [ADR 0006](adr/0006-swf-derived-candidate-art.md)
record the boundary. The batch pipeline in `tools/art_pipeline/` writes only to
ignored `.scratch/` and `candidates/` storage; it does not write the active
manifest or imports. Release rights, store identity and #20 acceptance remain open.

### 2026-10-19 approved ticket publication

The user approved the 20-ticket breakdown of specification #1. Issues #2–#21 cover visible practice, continuous/diagonal movement, hazards, portals, desktop-verified touch controls, clock/outcomes, conditional drops and upgrades, AI navigation/combat, source-reachable Cinema vehicles and weapon effects, session accounting/flow, original presentation and complete desktop acceptance. Every ticket carries `ready-for-agent`; 29 native blocking edges match the approved graph. Ticket bodies, labels and exact blocker sets were read back and verified. Specification #1's body, title, state, labels and other checked fields were left unchanged. The four unresolved named item slots, physical phone testing and export remain outside this graph. No gameplay implementation changed during publication.

### Settled interview: first visible controllable board (2026-10-19)

The user invoked grill-with-docs after the committed headless bomb slice. The next milestone is a visible practice board where one actor can move, place a bomb and see a soft block break. This is distinct from the accepted first full match with one human and three AI.

The user accepted Q14, Q15, Q16 and Q18 on 2026-10-19: direct-entry practice scope with Pause/Resume/Reset, temporary original geometric presentation, an Arrow-key/Space development adapter preserving original keyboard priority, and one down/up pair per touch press/release without synthetic held repeat. The user explicitly rejected Q17's cardinal-only mapping and requires eight phone directions, including diagonals. DESIGN.md and ADR 0004 record that adaptation; diagonal movement and practice preview are now glossary terms.

The source investigations are complete and recorded in [movement and board evidence](evidence/edition-5-movement-and-board.md). Original motion is continuous, cardinal and accelerating, with collision-dependent lane assistance; it is not one cell per input. The user's concern about grid stepping therefore does not require copying a nonexistent original stepping rule. Eight directions are a deliberate new control choice, not proof that joystick hardware requires diagonals. The user explicitly notes balance implications and wants later phone playtests.

The user answered "all yes" to Q19–Q21 on 2026-10-19: equal straight/diagonal top speed, full-footprint collision with sliding and no blocked-corner shortcuts, and shared human/AI eight-direction physical movement capability. DESIGN.md and ADR 0004 record the decisions; the glossary now defines wall sliding. AI route selection and behavior remain outside the practice slice.

The user rejected Q22 on 2026-10-19: all physical phone-related testing waits until the main Godot game is ready for publication, followed by iOS testing. Do not require or propose an early phone-control prototype again. This does not disable desktop/automated checks or decide a replacement export platform. The user accepted Q23 and emphasized that the fixed stick remains visible and its demonstration/animation responds to input, with PUBG Mobile, Honor of Kings or similar mature games as presentation references. Q24's normal-speed request outside the deadzone and Q25's owner-independent bomb departure followed by blocked re-entry once fully clear are accepted. DESIGN.md and ADR 0004 are updated; [reference notes](evidence/mobile-control-references.md) separate official sources from our own visual-feedback contract.

The follow-up board audit now resolves all candidate cells in frames 697/698 and independently reproduces one correction: (14,10) is soft. The [canonical rendered-instance record](evidence/cinema-stage1-recorded-board.md), CSV and audit preserve this result without rewriting the original delivered transcription. It is a rendered-image reconstruction, not runtime collision-state extraction.

The user answered Q26 with a delivery clarification: the whole runnable game is to be implemented in Godot 4.5. This is recorded as the primary deliverable; the practice board remains an intermediate integration milestone, not completion of that objective. The answer does not select the exact acceleration/heading-response profile previously recommended, so do not attribute that profile to the user. Use the recovered movement as the baseline and identify any deliberate adaptation separately.

The user accepted Q27 and Q28 on 2026-10-19: smooth collision-safe corridor alignment within the movement budget and a fixed practice layout using the corrected captured CinemaStage1 instance with its paired portals working. Reset restores that instance. DESIGN.md and ADR 0004 are updated; corridor assistance and portal are glossary terms.

The next planning step is to consolidate the complete accepted Godot first-build deliverable and its dependency graph: visible board/control integration, full local match with three AI and damage/endings, clock/lives/score/HUD/flow, then publication readiness. The main Godot build should not be replaced by another isolated phone prototype. Numeric input-feedback/deadzone/acceleration tuning can proceed during Godot development, with physical device validation at the accepted later stage. Source-recovered mechanics need evidence-linked implementation, not repeated interviews asking the user to supply facts. The main scene and gameplay implementation remain unchanged during this interview.

### Settled interview: first bomb/soft-block slice (2026-10-18)

The user resumed grill-with-docs after the scheduler slice. Read-only source investigations established immediate human bomb placement, later frame movement, phase-dependent eligibility for a newborn bomb's first countdown, and synchronous collision-map mutation during explosions. See [the focused evidence record](evidence/edition-5-gameplay-phases.md); these findings do not choose batching semantics.

The user answered "all yes" to Q9–Q12 on 2026-10-18. DESIGN.md records placement before movement, the first newborn countdown on the following tick with timed detonation on N+72, fixed roster action priority, and a headless placement/fuse/blast/soft-block-removal slice using a source-verified excerpt strictly as a test fixture. Movement, damage, drops, AI, rendering and full-board certification are deferred. ADR 0003 records the batching trade-off; GLOSSARY.md now defines fuse and blast.

The user then answered "yes" to Q13 on 2026-10-18: input first, then existing bomb countdowns/blasts, then movement when movement is implemented. With capacity one, a down event on the existing bomb's expiry tick fails and is consumed; another delivered down is needed after capacity is available. DESIGN.md and ADR 0003 record the accepted rule and consequence.

The product-decision frontier is empty for this headless slice. All five recommendations and the concrete expiry example have been confirmed; do not ask them again before implementation. A later TDD invocation must establish its public gameplay observation seam before writing tests. Item identity, release language, store name and the other explicitly deferred gameplay branches remain outside this slice.

### Active interview: adapting recovered behavior (2026-10-17)

The user accepted all five recommendations on 2026-10-17: ordered bomb events preserving repeated downs/ups replace the two booleans; external scheduling runs 35 logical ticks/sec; the round clock counts 180 simulation seconds and stops paused; timeout loses with enemies remaining; visible labels use intended readable text. These are accepted requirements, not implemented behavior. DESIGN.md and ADR 0002 own the contract and rationale. The delivered supplement now restores the captures/harness, demonstrates both glove candidates, and captures a normal all-enemies-dead victory. Three named item slots and the glove-slot selection remain unresolved.

On 2026-10-18 the user also accepted Q6–Q8: bounded catch-up, pause/focus input reset with explicit resume, and tick-start event capture consumed only after acceptance. DESIGN.md owns the exact rules. The stall scenario was hypothetical; no game freeze was diagnosed or observed in this implementation.

Ask the whole ready frontier for the branch under discussion, with a recommendation for each decision. Keep downstream questions blocked until prerequisites settle. After an answer, update the accepted rule in DESIGN.md, record the answer date here, and recompute the frontier. Update resolved domain terms in GLOSSARY.md immediately. Use ADRs only for consequential trade-offs whose rationale would otherwise be lost.

Before starting implementation from an interview, confirm the shared understanding if it has not already been confirmed. A request to maintain these documents authorizes recording settled answers and organizing knowledge; it does not settle unanswered gameplay choices.

## Checks and handoff

The confirmed test seam is roster construction followed by `advance(commands)`. Tests observe public results (acceptance, logical tick, and consumed commands), without inspecting private state or invoking gameplay. Work one failing behavior and its implementation at a time.

The ordered-command slice requested on 2026-10-18 adds the agreed test seam of bomb-event enqueue, tick-start capture and acknowledgement after the actual `advance(commands)` result. Tests use the real command module, with no internal mocks or private-state access. Scheduling and gameplay phases remain outside this slice.

For the requested scheduler and pause/resume slice, tests use a scheduler Node with the real command module and event queues: construction with a roster, elapsed-time advancement, per-actor direction/bomb input, pause/resume, and public Godot focus notifications. The observed result is paused state and the accepted tick results. Supplied elapsed time makes timing checks deterministic; tests do not reach into accumulators or mock internal modules. The main scene stays empty.

The implement request on 2026-10-19 proceeds with the proposed first-bomb seam: construction of a headless bomb simulation with a fixed actor roster, starting cells/settings and the [source-verified board excerpt](evidence/first-bomb-test-excerpt.md), followed by `advance(commands)` using the existing command format. Public observations are acceptance, logical tick, copied board/bomb state, blast cells and broken soft blocks. The simulation uses the real command boundary; the scheduler accepts the real simulation as its tick target so integration checks exercise elapsed time and pause/catch-up without mocks. The pre-implementation baseline was 69 passing assertions on Godot 4.5 stable. The three proposed behavior slices are implemented directly from DESIGN.md; no tracker tickets have been published.

The command checks verify that a valid explicit call advances exactly one tick and consumes one command per registered actor without rendering. They verify that missing, duplicate, and unknown actors leave state unchanged, and that roster size is not hard-coded to four. Scheduler checks cover partial intervals, 35 ticks across different render rates, stall limits and discarded debt, per-actor held direction, ordered events consumed once, invalid intake, pause/resume and focus notifications. One short live SceneTree check verifies automatic Node processing; timing assertions otherwise supply elapsed time directly.

Run `./tools/run_checks.ps1 -Godot 'path/to/Godot_4.5_console.exe'` from PowerShell. Without `-Godot`, the runner uses the local ignored `.scratch/godot-4.5/Godot_v4.5-stable_win64_console.exe` if present. It requires a Godot 4.5 executable, successful exits, no engine/script errors, and all eight suites' success markers.

## Implemented interface

Load [command_boundary.gd](../scripts/simulation/command_boundary.gd) and construct it with an `Array[StringName]` of unique actor IDs. The boundary copies the roster. Its only advancing operation is `advance(commands: Array[Dictionary])`.

Each command has `actor_id: StringName`, `direction: Vector2`, and `bomb_events: Array`. Every event must be the StringName `&"down"` or `&"up"`. Order and repeated down/up events are preserved; no held-state deduplication occurs. Idle commands use `Vector2.ZERO` and an empty array. The former two booleans are no longer the payload. The command boundary transports these values; the round interprets movement and actions. Non-finite direction vectors reject the batch before any state advances.

The public result contains `accepted: bool`, `tick: int`, and `commands: Array[Dictionary]`. It reports the last accepted batch (empty at tick 0), preserving supplied order; order does not define gameplay resolution. Rejection leaves that state unchanged. Input and result command values are copied so callers cannot rewrite consumed ticks. Missing fields or incorrect field types also reject the batch.

### Per-actor bomb-event queue

Load [bomb_event_queue.gd](../scripts/simulation/bomb_event_queue.gd) and create one instance per actor that needs buffered bomb input. Its public interface is:

- `enqueue(event: StringName) -> bool`: append a down/up event; reject unknown names without changing the queue.
- `capture() -> Dictionary`: capture the pending prefix for a tick, returning `token: int` and a copied `events` array. Repeated capture calls return the same active token and events until acceptance, including when that capture is empty. Later enqueues remain outside its cutoff.
- `acknowledge(token: int, accepted: bool) -> bool`: pass the token back to the same queue with the actual command result's `accepted` value. Acceptance consumes only that prefix and closes the capture; rejection retains it for retry. Stale, duplicate or inactive tokens cannot consume anything. Tokens are local to their queue.

The caller captures all actors at tick start, supplies one command for each registered actor to `advance`, then acknowledges each capture using that same batch's result. A rejected batch must not be acknowledged as accepted. Events arriving after a cutoff become available after the active capture succeeds. Returned event arrays do not expose the queue's owned arrays. The queue has no OS input hookup or pause method; its owning scheduler clears queued input across pause/resume.

The [command checks](../tests/command_boundary_check.gd) exercise these public interfaces with 28 assertions.

### Scheduler and pause/resume

Load [tick_scheduler.gd](../scripts/simulation/tick_scheduler.gd) and construct it with an `Array[StringName]` of unique actor IDs and an optional `RefCounted` tick target. It copies the roster and owns one queue per actor. With no target it creates the real command boundary as before. A supplied target must implement `advance(commands)` with the same fixed roster and return command-admission results; the real bomb simulation supplies that interface. Its public interface is:

- `advance_time(elapsed_seconds: float) -> Dictionary`: one frame's elapsed time returns `paused: bool` and `ticks: Array[Dictionary]` of command-boundary results. Fractions accumulate at 35 ticks/sec; at most five ticks are attempted, and all excess credit, including a stall remainder, is discarded. Negative or non-finite elapsed time is ignored without changing valid accumulated time.
- `set_direction(actor_id: StringName, direction: Vector2) -> bool`: replace that actor's held direction. Values are transported without interpreting analog-stick policy.
- `enqueue_bomb_event(actor_id: StringName, event: StringName) -> bool`: buffer a down/up event for tick-start capture. Each capture is acknowledged with the real batch's admission result. Catch-up ticks do not replay accepted events.
- `pause() -> void`: pause and clear held direction, queued events and time credit. Paused updates add no debt. Actor roster and accepted tick count remain intact.
- `resume() -> bool`: explicitly resume only when paused and focused, clearing input/time again. Calling it while running or unfocused returns false. Gameplay needs fresh input after resume.

Unknown actors, invalid bomb events and input while paused return false. Idle actors receive explicit zero-direction, empty-event commands from the scheduler. Godot application focus-out notifications pause automatically; focus-in only permits explicit resume. This is scheduler state, not a global SceneTree pause.

Attach the Node to a scene tree for automatic `_process(delta)` scheduling. For manual elapsed-time driving, keep it detached or call `set_process(false)` before attaching; do not also drive an automatically processing Node manually. Automatic updates advance the configured target; manual `advance_time` returns per-frame results. The gameplay scene attaches the scheduler with automatic processing disabled and drives that same interface once per rendered frame. Desktop/touch adapters feed the human; registered AI producers supply proposals at tick capture. `set_controller(actor_id, producer)` binds a callable returning direction/events; its captured proposal is copied and held through rejection, and reset across pause/resume.

The [scheduler checks](../tests/scheduler_check.gd) contain 41 assertions; the command suite has 28.

### Round simulation and the compatible bomb slice

Load [bomb_simulation.gd](../scripts/simulation/bomb_simulation.gd) and construct it with `actor_ids: Array[StringName]`, `actors: Dictionary` and `board: Dictionary`. IDs must be unique; each ID needs a settings dictionary with `cell: Vector2i`, optional positive integer `power` (default 1) and `capacity` (default 1). Board keys are `Vector2i` coordinates; values are StringNames `&"floor"`, `&"solid"` or `&"soft"`. Omitted cells bound the supplied board. Construction owns copies of all input values. A fourth optional rules dictionary enables movement, damage, portals, drops and round endings; the original three-argument headless bomb setup remains compatible. The production scene enables the complete round. Portal cells are also represented as `&"portal"`; they are walkable but reject ordinary placement and stop ordinary blast rays.

Its advancing interface is the existing `advance(commands: Array[Dictionary]) -> Dictionary`, composed with the real command boundary. The result retains `accepted`, `tick`, and copied `commands` and adds:

- `board: Dictionary`: a copied current collision board.
- `bombs: Array[Dictionary]`: copied live bombs containing `actor_id`, `cell`, and captured `power`, without private timer fields.
- `blasts: Array[Dictionary]`: this call's detonation records, each containing `actor_id`, origin `cell`, and footprint `cells`.
- `broken_soft_blocks: Array[Vector2i]`: soft cells removed by those detonations.

Rejection preserves board, bombs and logical time and returns no new blast/break records. Accepted gameplay failures still consume the input batch. Placement runs in roster order at pre-movement actor cells and checks capacity and floor/bomb occupancy. Ordinary up events do not place bombs; equipped actions use their recovered handlers. With movement enabled, directions move actors after bomb/weapon/portal phases.

Timed bombs expire on placement tick plus 72, after that tick's input phase. Detonation immediately frees bomb capacity; rays include floor and the first soft cell, exclude solids, and stop at the board boundary, soft cells or another bomb. A hit ordinary bomb chains synchronously; each bomb detonates once. Soft collision cells clear immediately. The source-verified excerpt and worked footprints are test fixtures, not a full production board.

Blast records remain per-call detonation events. Additional copied state includes actors (continuous position, facing, life/protection, movement and equipment statistics), visible flames, active fire cells, pickups, weapon actions/projectiles, remaining ticks, outcome and result score. `snapshot()` returns current state without advancing; a terminal round no longer accepts ticks. The [bomb checks](../tests/bomb_simulation_check.gd) retain 43 assertions for the compatible foundational slice. New round/scene/regression/playthrough checks verify the integrated game through the agreed seam. Exact SWF AI-state-machine and painted attack-bound parity are not claimed; see the evidence record.

## Current gameplay integration

The scene host owns session retry hearts and cumulative result totals; the round owns actor life loss, gameplay and each result. The production setup uses Normal Arcade and reuses the recorded map for permitted retries/play-again within this first single-map scope. The [phase policy](../DESIGN.md) and [integration ADR](adr/0005-integrate-gameplay-through-the-round.md) record new deterministic phases and source conversions. The source-linked [runtime record](evidence/edition-5-runtime-systems.md) covers portal blast blocking, overlapping fire cleanup, protection, conditional drops, weapon/riding callbacks, scoring and AI adaptation limits.

Run `./tools/play.ps1` to play using the local 4.5 engine, or open the project in Godot 4.5. Desktop-rendered captures and deterministic playthrough records are in ignored game-capture storage. They are development evidence, not physical phone validation.

## Handoff history

Once the tick and the relevant recovered behavior exist, add a headless check for one bomb blast and one broken soft block, linked to the SWF evidence. Until that evidence exists, do not turn assumptions into parity tests.

At handoff, record completed work, remaining prerequisites, and verification performed here. Keep product rules in DESIGN.md and recovered observations in the evidence records rather than copying them into the handoff.

### 2026-10-16 documentation handoff

Recorded the two accepted interview answers, added the knowledge map, glossary and source-authority ADR, separated recovery evidence from inherited export notes, and replaced stale agent instructions with document-specific pointers. All relative Markdown links across the eight documents resolved; `git diff --check` passed. Project configuration and the main scene were unchanged. The command slice and SWF recovery remain unimplemented.

### 2026-10-16 command-boundary interview

The user accepted the recommendations for rejection of incomplete input, explicit advancement, and a fixed per-round roster, then confirmed the combined contract and its recording. The accepted rules are in DESIGN.md under "Command calling contract." This resolves the calling-contract branch; original input semantics and tick frequency still await evidence. Documentation was updated without implementing the boundary.

### 2026-10-16 TDD implementation

Implemented the boundary and headless runner through eight red-to-green behavior slices: explicit advancement, missing actors, duplicate actors, unknown actors, roster ownership, consumed-command ownership, required fields, and field types. All 13 assertions passed on Godot 4.5 stable. Configuration and the main scene were unchanged. SWF recovery remains the prerequisite for original input semantics and gameplay parity checks.

### 2026-10-16 input and timing research

Recovered a publisher-distributed edition 5 build and documented provenance, hashes, source locators, input handling, and timing in [one research record](evidence/edition-5-input-and-timing.md). The earlier claim that 35 was only inherited from bomb-it-1 is superseded by independent edition 5 evidence. No gameplay, command implementation, or engine configuration was changed. The next design discussion is how to adapt the original event stream and frame-driven updates to the accepted explicit command boundary.

### 2026-10-17 Dots evidence intake

Organized the repo-root SWF pack and both Downloads HTML5 packs into source records under `docs/evidence/observations/` and raw reference storage under `.scratch/edition-5-research/observations/`. Inventory: 318 preserved files, 123 imported text/data documents. The [assessment](evidence/edition-5-play-observations.md) concludes that the request is partially fulfilled and lists the exact follow-up. Source claims are separated from alternate-build observations and unsupported probe details. All file hashes, 174 images, 16 video decodes, 44 map-coordinate grids and local documentation links passed verification. Gameplay code, scene and engine settings were not changed.

### 2026-10-17 supplemental Dots evidence and accepted adaptation choices

Organized the 11-part supplement and 17-part follow-up from the root download directory. Preserved all 28 original archives and 3,609 expanded files under ignored investigation storage; imported 19 documentation/data records with separate provenance inventory and audit. All 28 ZIP CRCs, 3,605 supplied checksums, 3,532 image decodes and 12 MP4 decodes passed. All 23 missing harness stills, first-board frames, harness source/lock/patches/logs are now delivered. Captures demonstrate both glove candidates and normal elimination victory with TIME 59, results and Next; zero player kill credit does not invalidate the all-enemies-dead ending. Raw probes are partly palette-quantized/sampled, the first-board occupancy remains partly uncertain, and three item identities remain unresolved. Supplied tooling was inspected statically and not executed. See the current evidence assessment for confidence limits.

The user accepted all five adaptation recommendations during intake. The new command events, scheduler, simulation clock, timeout rule and readable labels remain unimplemented. Existing boolean-payload checks are the current implementation baseline. No gameplay, scene or project configuration changes were made during organization.

### 2026-10-18 scheduling and lifecycle interview

Recorded acceptance of Q6–Q8 in DESIGN.md and updated ADR 0002 and the frontier. No gameplay implementation changed; the boolean-based boundary and its checks remain the existing baseline.

### 2026-10-18 ordered-command TDD upgrade

Completed eight red-to-green slices: ordered payload migration, atomic event validation, ordered queue capture, accepted consumption, rejected retention, cutoff through retry, stale/duplicate acknowledgement protection, and intake rejection of unknown events. Migrated the existing roster, advancement and ownership checks to the ordered payload. All 28 assertions pass through public interfaces on Godot 4.5 stable. Updated the implemented interface and frontier. Scheduler/catch-up, pause/focus reset, clock and gameplay remain pending; project configuration and the main scene were unchanged.

### 2026-10-18 scheduler and pause/resume TDD slice

Completed eleven red-to-green slices through the scheduler's public elapsed-time, input and lifecycle interfaces, using the real command boundary and queues. The attached Node processes rendered-frame time, limits catch-up to five ticks, discards excess time, transports held direction and consumes ordered events once. Pause and focus loss clear input/time; focus return requires explicit resume. Invalid elapsed values cannot poison the clock. A 90-frame timing check exposed floating-point undercounting, corrected with a tiny tick-boundary tolerance. Both suites pass 69 assertions on Godot 4.5 stable (28 command/queue, 41 scheduler). The runner now requires both success markers. Configuration and the empty main scene remain unchanged.

Next work is the evidence-linked gameplay slice: the subsequent Q9–Q13 interview has settled its event phases; implement and check one bomb blast and one broken soft block with a source-verified test excerpt. Verify the uncertain first-board cells before certifying its full layout. Controller adapters, round countdown, timeout and readable labels are still unimplemented; item identity decisions remain separate prerequisites for their behavior.

### 2026-10-19 first-bomb implementation

Implemented the three proposed behavior slices directly from the accepted design: ordinary placement with atomic admission, timed blast/soft-block removal, and real scheduler input/lifecycle integration. Eight red-to-green changes established placement, repeated-event occupancy protection, roster priority, floor guards, the N+72 fuse, source-derived blast/block rules, scheduler target binding, and source-supported synchronous chaining. Additional public-interface checks cover rejection without fuse aging, owned snapshots, expiry-tick input consumption, power-two blocker stopping, paused fuses and discarded catch-up time. There are 43 bomb-simulation assertions and 112 across the three suites on Godot 4.5 stable. Runtime script parsing/typechecking is included in the single-suite runs and an explicit check-only pass.

The concrete fixture remains a source-verified excerpt. This implements detonation records and collision changes, not persistent flames, movement, damage, drops, AI, visuals or a complete first board. The next visible-play milestone needs its board occupancy verified and its movement/control/presentation decisions settled. Project settings and the empty main scene are unchanged. No tracker configuration or published issues were created; local DESIGN.md is the originating specification. Review compares the staged project against initial commit `f4491e12481055d6faf090968728921c45357d9f`, including the pre-existing uncommitted foundation and organized evidence needed for a reproducible checkout.

Final verification: the full runner passes 28 command, 41 scheduler and 43 bomb assertions (112 total), with no engine/script errors; both changed runtime modules also pass Godot's check-only parsing/typechecking. Local links in all 14 authored documentation records resolve. Authored-file whitespace checks pass; four existing whitespace warnings in imported evidence remain preserved, including literal multiline localization text. Parallel review found no specification gaps or substantive standards violations; its one stale scheduler-table sentence was corrected. The reviewed project is committed on the current branch without publishing or pushing.


### 2026-10-19 playable desktop implementation and functional verification

Implemented gameplay functionality across the approved graph through the real scheduler/round, preserving the 112 foundational assertions. Presentation #20 and final acceptance #21 were initially closed prematurely; see the correction below. The final full runner passes **244 checks** on Godot 4.5 stable: 28 command/queue, 41 scheduler, 43 ordinary-bomb, 16 feature tracer, 84 regression, 29 scene and three full-board playthrough checks. Runtime scripts pass parsing/type checks; no engine/script errors were reported. Public scene input checks cover all eight stick sectors, deadzone, unrelated board touches, concurrent controls, desktop key priority and lifecycle reset.

The full-board fixture drives ordinary legal commands for all four actors, without changing private round state. Seed 2 reaches elimination victory at tick 2828, one player kill and result score 3300; seeds 5 and 42 reach defeat at ticks 1309 and 2022, each with one kill and score 300. Timeout and simultaneous-ending precedence have separate public round checks. These are deterministic desktop correctness scenarios, not a device performance or difficulty benchmark.

The actual Compatibility-rendered game was captured and visually inspected at 1280×720: [active match](verification/desktop-2026-10-19/match.png), [pause](verification/desktop-2026-10-19/pause.png), [defeat/results](verification/desktop-2026-10-19/results.png), [game over](verification/desktop-2026-10-19/game-over.png) and [legitimate victory](verification/desktop-2026-10-19/victory.png). `tools/capture_game.gd` reproduces these through the scene and existing scheduler producer interface. It takes over human commands for the victory capture, without forcing actor deaths or outcomes. Layout, hearts, readable labels, controls and next actions are visible. The heading LOCAL ARCADE describes the development build; it is not a selected store identity.

Parallel Standards and Spec reviews found no outstanding material findings after fixes. Review prompted one shared public-state projection, round-published flamer display geometry, removal of inactive AI from decision rotation, and preservation of multi-cell escape movement between brain turns. The latter two have regression coverage. Exact retail AI-state-machine/difficulty parity and SWF painted attack bounds remain unclaimed. The four unresolved named item slots remain excluded; physical phone/iOS tests, export/signing, store identity and release language remain later work.


### 2026-10-19 presentation and final-acceptance correction

The current procedural vector art provides playable integration visuals. It has not fulfilled the accepted finished redraw in the original painting style. Closing presentation #20 and final desktop acceptance #21 was premature; those tickets are reopened. The 244 functional checks and rendered captures remain valid evidence of the implemented desktop behavior, not proof of finished visual quality or publication readiness. The earlier two-axis review missed this presentation gap.

Assess the desktop build now for movement/corridor feel, bomb/weapon timing and feedback, understandable damage/protection/portal states, AI activity and challenge, match pacing, and retry/result clarity. Compare source-grounded rules with the recovered evidence and separate accepted adaptations from unresolved parity limits. The recorded full-board runs are automated command-driven playthroughs, not human usability validation.

Finish and assess the original art/animation pass under #20, then repeat integrated desktop acceptance under #21 with the resulting visuals. Retain the existing functional evidence and add coverage for any discovered defects. Physical phone/iOS testing stays deferred until the main Godot build passes that gate. The working title and Bomb It 5 references in project metadata/research remain; source sprites and audio are not loaded by gameplay, but the game is intentionally derived from edition 5 rules and map design.


### 2026-10-19 desktop feel feedback and source audit

The user defers joystick improvement until phone testing. They report a roughly half-second lethal explosion tail and incomplete/stiff weapon animation/use, and prefer establishing the original edition 5 logic/feel before the final original-art replacement. DESIGN.md records this priority. Most implemented behavior felt acceptable to the user; diagonal movement has not yet been assessed in actual play. The current Arrow-key adapter intentionally accepts one cardinal direction; synthetic/mouse-emulated stick input supports diagonals, but the recorded board's narrow lanes restrict opportunities. Open-board automated motion checks do not establish real play feel.

The [control-timing diagnostic](../tools/inspect_control_timing.gd) drives the real public round with legal commands. In an isolated ordinary explosion at tick 73, entry at tick 89 remains lethal with a flame present; entry at tick 90 is safe with no flame/fire. This reproduces the current 17-tick (0.486 s) tail and finds no hidden lethal interval after the round removes its flame. It is not an SWF parity test. The original retains fire until Bomb.ended's greater-than-15 boundary; GameEngine calls blast cleanup after bomb handlers, so the ordinary timed-detonation path's first cleanup callback can occur in its creation frame. Trace/replay that phase and later weapon-triggered chains before claiming exact parity or changing every hazard to a single different duration. See the evidence clarification below.

The same diagnostic measures movement interruption from action input to the next movement: hammer 24 ticks (0.686 s), flamer 23 (0.657 s), laser 22 (0.629 s), triple-shot 41 (1.171 s), fireball 24 (0.686 s). Original AbstractWeapon.robotMoveStop/Start and weapon commands establish that Arcade actions do stop movement, but these coarse replacement durations are not complete frame/geometry/state-machine parity. Rendering is simplified, and flamer endpoint growth is reconstructed. No rendering-performance hitch has been established. In follow-up, the user attributes the weapon stiffness primarily to incomplete animation and asks not to spend further effort on weapon-specific lag diagnosis now; retain the fidelity findings for the later rebuild/animation pass.

Next fidelity work: compare original and rebuilt per-action sequences (input, animation, hit/projectile creation, collision/damage, recovery and movement resumption), resolve callback-phase differences, replace approximations with source-derived behavior where not deliberately adapted, and add public seam regressions. Use the original assets/animation as reference during this work; shipping art remains the final original redraw. Do not infer a fidelity percentage from passing the new-game suite or from class/line counts. Current GDScript is a new implementation with source-derived rule/data translations; no original ActionScript runtime is embedded. AI, animation-dependent weapon geometry and presentation are reconstructed and not full original ports. Functional feature coverage and source-feel fidelity are separate gates.


### 2026-10-19 reverse-engineering-first structural audit

Following the user's request, reconstructed the original selected Normal Arcade/Cinema structure before further fidelity porting. The source-linked [reconstruction](evidence/edition-5-structure-reconstruction.md) covers startup, map/player/robot ownership, engine phases, command chains, animation-dependent weapons, AI states/search and death/result staging. Newly checked facts include conditional position/state/vehicle-triggered fire checks, dictionary command enumeration, ordered Normal AI states, delayed mode/result checks and live callback mutation. Targeted fresh P-code from the hashed SWF corroborates the AI accumulator's missing reset and a large unused allocation embedded in StateAttack; the latter is not an invitation to copy unrelated filler into gameplay.

Added [inspect_swf_structure.py](../tools/inspect_swf_structure.py) and a generated [inventory](evidence/edition-5-structure-inventory.json): 218 game-package ActionScript files with hashes/declaration metadata, three ABC block hashes, 635 named symbols, 2,098 sprite definitions and 18 selected timelines. An independent JPEXS XML export agrees on all 18 frame totals and 336 placement records' containing frames and compared identity/geometry fields. Deterministic regeneration, authority-hash rejection and authored links are checked. The parser explicitly does not evaluate live bounds, every optional tag field or runtime scheduling.

The [audit and verification gaps](evidence/edition-5-reverse-engineering-audit.md) records the supplied harness inspection and readiness limits. No new original-SWF playback, full pinned Ruffle build, native Flash comparison or game-state tracing was performed. No gameplay code or production artwork changed; the previous 244 gameplay checks are not reclassified as SWF parity. The next recovery gate is an independently reproduced reference session and controlled traces for fire/phase edges, action timelines/bounds, AI transitions and death/results. Joystick polish and physical phone/iOS testing remain deferred.


### 2026-10-19 original-runtime recovery and porting handoff

Implemented the approved recovery graph through the publisher SWF, with a pinned locked Windows reference player, acknowledged input replay, read-only state/event/RNG/geometry observation and explicit original-method fixtures. The [tooling record](evidence/edition-5-recovery-tooling.md) preserves the fourteen-patch chain, canonical build, historical exact patch bytes, failed whole-session equivalence and narrower successful comparisons. Authority bytes are unchanged; generated templates and host clocks remain observable differences rather than hidden assumptions.

The [evidence index](evidence/README.md) links ordinary bombs, both-owner chains/overlap, all-cardinal movement and both portal pairs, conditional drops/caps/budgets, protection/vehicles, ten mine scenarios, 24 directional weapon actions, 35 two-action target cases, three laser portal rays, 15 weapon lifecycle cases, 88 measured flamer endpoints, representative Normal AI decisions and complete selected result/retry flows. Curated bundles retain original cases/logs/frames, source locators, hashes, selected native observations and actual execution/RNG events. Bounded untested permutations, emulator warnings, source bugs and observation costs remain explicit.

The [source-to-Godot map](evidence/edition-5-porting-handoff.md) classifies current behavior and orders later faithful porting. It preserves accepted scheduling/batching, eight directions/full footprint, simulation clock/timeout, fresh-input pause, the fixed recorded board and readable labels. No new original rules or artwork were ported during recovery. Final redraw #20, desktop publication acceptance #21, physical phone/iOS testing and the four unresolved slots remain separate. The full unchanged Godot 4.5 runner passes all 244 functional checks; these are not relabeled as SWF parity.

Final independent Standards/Spec review found one material issue on each axis: staged-core provenance and missing laser/portal measurement. Both are fixed and verified; the final [acceptance record](evidence/edition-5-recovery-verification.md) reports zero outstanding material findings. A derived actor-registration projection was corrected separately and rechecked against raw Game.robots. Authority bytes and production gameplay remain unchanged.
