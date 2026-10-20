# Desktop fidelity implementation

Implementation of approved tickets [#38–#55](https://github.com/Kurak0oo/bomb-it-5/issues/38),
starting from `74ab044`. Verification/review is in progress; this record does not
close finished-redraw #20 or final desktop/human acceptance #21.

## What changes in play

Ordinary fire contact follows position/state/vehicle registration instead of
unconditional polling. Bomb capacity, map occupancy, visible flames and Boolean
fire cleanup are distinct. Live callback removal preserves the observed overlap
and chain skips within the accepted phases. Physical movement can precede logical
contact by one tick. Portals retain their separate arrival, registration and blink.

Shield, Invincibility and ride loss have distinct stages. Vehicle art remains
attached during recovery; LifeProp affects human retry hearts rather than AI
survival. Drop construction samples the shared weighted class list once per round,
preserves partial zero-budget mutation and draws timed positions before classes.

Hammer, laser, flamer, triple-shot, fireball and mine use owned action lifecycles.
Held equipment persists through a final action; replacement cancels its old action.
Laser damage runs once; flamer interaction uses animated tip bounds; projectiles
separate emission, movement, collision, cleanup and independent actor recovery.
Temporary original drawings now respond to these phases. They are not the finished
painting-style redraw and do not reproduce source pixels or audio.

Normal AI uses the recovered ordered states, parser exclusions, ring perception,
carried ray flags, asymmetric upward danger, shared node costs, custom estimate
search, random first-acceptable item targeting, delayed attacks and escape, and
per-step route cancellation. It submits ordinary commands. Brain opportunities
remain separate from route following; actor stop/death/transfer affects registration.

Death detaches an actor before its movie finishes. Ending judgment can be triggered
by another completed death movie. The cartoon precedes one settlement, which
spends a loss heart and replaces HUD awards with the final result formula.

## Comparison coverage and source locators

All behavior checks use the existing real scheduler/round public seam, with copied
controller observations on returned results and focused scene tests. Initial
actors, board, equipment, rules, clock mapping and RNG tapes are retained per
fixture in [comparisons.json](comparisons.json). A failing check records the first
public difference and the corresponding public state. Source expectations are
independent literals or recorded original getter results, not current Godot output.

| Ticket | Recovered authority | Focused public checks |
| --- | --- | --- |
| #38–#39 | Contact, events and chain/overlap probes; Bomb.takeCount/ended, GetFireCommand | Stationary expiry; retained occupancy; both overlap orders; shared fire clear and skipped callback |
| #40 | Movement runtime probes; RobotModel/HitMove/updateRobotPosition | Stop/acceleration/collision baseline; delayed logical registration; accepted diagonal and footprint checks |
| #41–#42 | Protection/vehicle probes; TryToKillCommandChain, Invincibility chains | Introduction/active stages, zero pickup award, retained ride/recovery, shield precedence |
| #43 | Movement/portal probes; Portal/SendRobotCommand | Four directed fixed-board transfers, interrupted held movement, physical/logical arrival, vulnerable blink |
| #44–#45 | Pickup probes; Box.createProp, Map.createRamdonProp | Caps, AI LifeProp, reveal in fire, partial class-list mutation and timed budget bypass |
| #46–#47 | Action/laser reports; HammerPlayCommand, LaserPlayCommandChain | Frame thresholds, Up layer, two-use exhaustion, replacement, single ray through portal to first soft blocker |
| #48 | Mine probes; LandmineBomb.hitReset and inherited BLAST | Deferred one-use placement, external underflow, contact counter and protected-contact score/kill counter |
| #49 | Interaction report and four native geometry summaries; FlamerFire getters | 88/88 actual recorded endpoints, including clipped Up/Left and advancing Down/Right; own-cell pickup destruction |
| #50–#51 | Projectile/action reports; Ninjial/ShotGun commands and projectile classes | Three emissions, final-frame fireball, independent recovery/pause and retained twelve-callback cleanup |
| #52 | Results probes; RobotDeadCommand, ArcadeMode, GameEndCartoon | Simultaneous defeat, staged judgment/cartoon, one heart at settlement and no repeated credit |
| #53–#54 | AI runtime probes; AIControl/AIEngine/Action/RoadSearch/states | Parser defect, strict upward threshold, randomized item/cost 62, every selected equipment family through real damage |
| #55 | Reviewed porting handoff and accepted DESIGN | Integrated full-board playthroughs, scene flow, pause/focus/input/reset and actual rendered captures |

[verification.json](verification.json) pins script/case/manifest/artifact hashes and
playthrough results. Its recovery inventory is provenance, not a claim that this
port re-ran every original recording. The reviewed evidence index remains the
authority for each original player's build and instrumentation limits.

## Explicit conversions and limits

DESIGN and ADR 0005 retain atomic admission, 35Hz scheduling, uniform newborn bomb
countdowns, fixed roster priority and the accepted phase order. AVM2 registries
are translated into owned GDScript lifecycles; a second ActionScript engine is not
embedded. Mixed registry/animation interleavings are not universally equivalent.

Host durations become simulation deadlines: vehicle 35 ticks, projectile recovery
11, ending cartoon 105, and AI 4/6/7/11/70 as documented. These preserve the accepted
frozen-pause/fresh-input policy and explicitly differ from the original paused
Tween recovery/resume-Space behavior. Source callback observations are not wall
time benchmarks. The admitted direction resolves heading before action input for
both controllers without moving a locked actor or granting private AI powers.

Flamer bounds match 22 independently observed frames per direction. The terminal
callback retains the last measured cell extent; its exact final vector outline,
arbitrary skin/ride transforms and native Flash rendering remain unverified.
Scripted drop/AI RNG tapes align selected decisions; stochastic full sessions do
not share an equivalence guarantee. A declared route excerpt reproduces source
cost 62; it does not claim the entire generated original board was paired.

Original reference playback is the preserved Ruffle build, not native Adobe Flash.
Full-board input drivers demonstrate legal state transitions, not human play quality.
The four reserved item slots remain excluded, the production board remains fixed,
and physical phone/iOS/joystick polish, export and store choices remain deferred.

## Reproduction

Run `tools/run_checks.ps1` with the pinned Godot 4.5 console executable. The focused
suite is `tests/fidelity_check.gd`; it writes the raw public comparison artifact
under ignored investigation storage. `tools/capture_game.gd` renders real production
matches/results; `tools/capture_fidelity.gd` renders explicitly labelled controlled
action fixtures. Run `python tools/collect_fidelity_verification.py` after successful
checks and captures to curate the hash-indexed evidence here. Source images remain
in research storage; these screenshots show only the new original presentation.
