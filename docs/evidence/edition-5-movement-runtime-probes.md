# Original movement, contact and Cinema portal probes

Recorded 2026-10-19 for [#25](https://github.com/Kurak0oo/bomb-it-5/issues/25) and [#26](https://github.com/Kurak0oo/bomb-it-5/issues/26). These are observations of the unchanged original SWF in the pinned instrumented Ruffle player. They establish several original-system behaviors; they do not establish native Flash equivalence or complete gameplay parity.

The original accelerates while a direction is held, stops displacement immediately on release while retaining decaying velocity, assists alignment in narrow corridors, and lets the owner leave an ordinary newly placed bomb while blocking re-entry. Both generated Cinema portal pairs transferred in both directions. Each transfer used 30 original command callbacks, with physical arrival one observed frame before destination map occupancy. Damage eligibility returned before the remaining blink animation ended.

## Authority, method and reproduction

| Input | Identity |
| --- | --- |
| Original SWF | `.scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf` |
| SWF SHA-256 | `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2` |
| Preserved player | `.scratch/edition-5-research/reference-player-actors/probe.exe` |
| Player SHA-256 | `eeebea71c77ac5d9fb2f10478d225b457f61d3459387862a46cde632d19812c7` |
| Ruffle source commit | `45366370ed7d1a59c89aa3cf7b765c7a274407cd` |
| Opening | Arcade, Normal, Cinema; explicit original RNG seed 42 |

Instrumentation and its limits are described in [reference trace design](edition-5-reference-trace-design.md). The driver loads a verified byte-identical copy from a safe temporary URL; dot-prefixed URL path segments break the original SharedObject initialization under this Ruffle version. No SWF bytes or Godot gameplay were changed for these experiments.

The executable's research fixture calls original AI stop methods for players 1–3. Delayed AI state/Tween callbacks remain live; this is not a claim that every AI callback was removed. Motion uses the human's ordinary starting position. Portal setup additionally relocates the human through the guarded original view/controller route to two empty neighboring floor cells, `(3,3)` and `(13,3)`. Every portal entry, exit and return uses ordinary keyboard input. No fixture writes portal associations, health, timers, occupancy, weapons or outcomes.

The checked-in cases are [motion/contact](../../tools/reference_player/cases/movement/01-motion-contact.json) and [both portal round trips](../../tools/reference_player/cases/movement/02-portals.json). Run [replay_reference.py](../../tools/replay_reference.py) with the preserved player, the original movie, and `--observe --focus --fixtures`; its CLI provides `--case` and output-directory options. The exact successful commands, fixture results and case copies are preserved in the curated manifests below. Seed 42 is applied before any frame. Captured frame numbers refer to explicit harness steps, not wall-clock time. The driver's generic manifest status remains `executed_reference_case_not_yet_behavior_verified`; the field-level analysis in this report supplies the narrower verified claims.

Final raw runs, intentionally ignored because they contain large per-frame graphs:

- `.scratch/edition-5-research/reference-runs/movement-contact-42-02`: frames 722–811, 90 focused snapshots.
- `.scratch/edition-5-research/reference-runs/movement-portals-42-05`: frames 722–965, 244 focused snapshots plus opening full graph.

Curated evidence is in [movement/](reference-2026-10-19/movement/summary.json): [motion frame CSV](reference-2026-10-19/movement/motion-frames.csv), [portal frame CSV](reference-2026-10-19/movement/portal-frames.csv), [opening board CSV](reference-2026-10-19/movement/opening-board.csv), [selected original events](reference-2026-10-19/movement/selected-events.jsonl), [motion manifest](reference-2026-10-19/movement/motion-manifest.json) and [portal manifest](reference-2026-10-19/movement/portals-manifest.json). The summary indexes 13 original screenshots with hashes. A `.gdignore` keeps these reference images outside Godot resources.

Rebuild the curated outputs from the final raw runs with:

```powershell
python tools/reference_player/cases/movement/summarize.py --motion .scratch/edition-5-research/reference-runs/movement-contact-42-02 --portals .scratch/edition-5-research/reference-runs/movement-portals-42-05 --output docs/evidence/reference-2026-10-19/movement
```

Original event collection reported 13,852 motion events, 16,726 portal events and 451 template-selection events, with zero dropped/overflow events in each channel. Object addresses are process-local identities, not portable fixture IDs.

## Which Cinema board was actually generated?

The template event stream entered `CinemaMapData.normalThree()` exactly once. Its original implementation instantiates `CinemaStage3`. `currentLevel == 1` therefore does **not** identify `CinemaStage1`.

Static source: `maps/mapData/AbstractMapData.as:data` selects a random non-PacMan entry from `_dataArr`; `CinemaMapData.as:init` places `normalOne`, `normalTwo`, `normalThree`, and `pacManData` into that array. Their constructors select CinemaStage1, 2, 3 respectively. These paths are relative to `.scratch/edition-5-research/publisher-scripts/scripts/zlong/bombit5/`. This layout selection is separate from round-level numbering.

The actual opening full graph resolves `_associatedPortal`, `_colorId`, `_xN` and `_yN` as:

| Color | Original paired cells |
| --- | --- |
| 1 | `(3,2)` ↔ `(13,12)` |
| 2 | `(13,2)` ↔ `(3,12)` |

These cross-pairs differ from the previously recorded fixed Godot board. The accepted fixed board remains an adaptation of its recorded instance; this experiment does not replace it or imply that all Cinema sessions share one topology. The opening CSV preserves raw grid flags, actual boxes, platforms and occupancy for this generated instance.

## Movement and contact observations

Coordinates here are local board pixels: native actor container position minus `(183,40)`, with 30-pixel cell spacing. They come from native stored display position, not from the lagging logical cell fields.

| Probe | Measured result |
| --- | --- |
| Right held, frames 722–729 | Velocity `1.6, 2.56, 3.136, 3.4816, 3.68896, 3.813376, 3.8880256, 3.93281536`; local x `31.6` through `55.9`. |
| Release, frames 730–733 | x remains `55.9` throughout; velocity decays from `2.359689216` to `0.509692870656`. |
| Left wall, frame 749 | x clamps to `30`; residual x velocity is approximately `-3.998727766`. |
| Immediate right reversal | Frame 750 x becomes **29.2**, with velocity `-0.79923666`; frame 751 returns to `30.3`, then 752 reaches `32.55`. |
| Turn down into narrow corridor | x shifts from `32.55` to `30.95` while y initially remains `30`, then downward movement proceeds at x `30.95`. This assists alignment but does not exactly reach the grid axis. |
| Ordinary bomb walk-off | Bomb created at `(1,1)` on frame 787; right movement reaches x `60` by frame 799. |
| Attempted bomb re-entry | Twelve left-held frames leave x `60` at frame 811; bomb count is still one and the bomb has not detonated. |

Static source explains the acceleration and release behavior: `RobotModel.as:moveLeft/moveRight/moveStop` (114/122/146) updates velocity, while `RobotController.as:moveLeft/moveRight/moveStop` (79/88/115) chooses which collision movement to execute. `HitMove.as` implements direction-specific collision and corridor assistance. The model's recurrence for this unmodified actor is `v_next = 0.6*v + 1.6` while moving right, approaching four pixels per callback.

The reversal's brief movement beyond the nominal left boundary is a measured original-system quirk. The source passes the still-negative residual velocity into `rightAfoul` after a right press; that is a source-supported explanation, not proof of all collision edge cases. Do not turn these observations into a claim that the original always enforces a strict complete actor footprint at walls. Ruffle quantizes observed native positions to 0.05 pixels here; native Flash numeric equivalence was not tested.

Logical map/contact state can trail physical position. At frame 727, x is `48.15` but `currentX` and map membership remain cell `(1,1)`; at 728 they become `(2,1)`. Another crossing is physical x `45.3` with old membership at 792, updated membership at 793. `AbstractRobot.as:robotEngine/updateRobotPosition` (158/167) checks logical position before executing the actor command chain; position/state/vehicle changes trigger its position-change chain.

The human's actual `GetFireCommand.execute` entries occurred only on frames **728, 739, 759, 771 and 793** in the 90-frame motion trace. None occurred in the four stationary release frames 730–733. This supports conditional contact evaluation through the original position-change chain, rather than an unconditional per-frame fire poll. These cells contained no fire: lethal contact, a stationary actor in newly created fire, and expiry-boundary safety remain separate experiments.

## Both portal lifecycles

| Transfer | First count 1 | Last projected count 29 | Physical arrival | Destination map occupancy | Blink command removed |
| --- | ---: | ---: | ---: | ---: | ---: |
| `(3,2)` → `(13,12)` | 729 | 757 | 758 | 759 | 775 |
| `(13,12)` → `(3,2)` | 797 | 825 | 826 | 827 | 843 |
| `(13,2)` → `(3,12)` | 857 | 885 | 886 | 887 | 903 |
| `(3,12)` → `(13,2)` | 925 | 953 | 954 | 955 | Not reached before trace ends at 965 |

Each transfer has **30 original `SendRobotCommand.execute` entries**, 120 total. Focus snapshots see counts 1–29 because the command removes itself in callback 30. Physical position remains fixed during each projected transit, then changes to the destination cell anchor (`grid * 30`). At arrival, map occupancy still names the source cell; it changes the following frame. This ordering is observed; its explanation follows the original callback/update order rather than an invented teleport implementation.

Original alpha setter events contain one change per send callback: `1 - count/35`, beginning at approximately `0.9714285714` and ending at `0.1428571429`. The actor fades but the command does not make it completely invisible. See [first transit](reference-2026-10-19/movement/portals-pair1-transit-frame1.png) and [arrival](reference-2026-10-19/movement/portals-pair1-physical-arrival.png).

During the first transit, Right and Space were delivered and held for three frames. Physical position remained fixed, the controller stayed in its stopped movement mode, no bomb appeared, and the event stream contained no `PersonInteractiveController.bombDownHandle` entry for that Space input. Placement failure alone would be inconclusive because a portal is not empty floor; the handler trace and original listener-removal path provide additional evidence of the lock. Ordinary arrow events outside transit do enter that registered key handler, which then checks the key code.

The human remained on the destination portal without bouncing back. After walking out, `curOrgan` cleared; walking back in triggered the return transfer. Both pairs were tested through legal neighboring-cell movement, including both directions.

Static source:

- `maps/platform/Portal.as:runEngine` (62–83) reads occupants, checks state and both `curOrgan` exclusions, records the destination portal, stops movement/bomb input, adds Send(30) and Invincibility(45), and sets `isExist=false`.
- `commands/robot/SendRobotCommand.as:execute/sendEnd` (38–58) increments the count, changes alpha, restores controls on callback 30, sets `isExist=true`, writes original view position, removes itself and adds the portal-exit check.
- `commands/map/CheckRobotInPortalCommand.as:execute` clears the latch after leaving the portal.
- `commands/robot/InvincibilityCommand.as:execute` (41–76) removes itself only after its counter exceeds the total and alternates color offsets while running.

Observed `isExist` is false throughout projected transit and **true at arrival**, while the blink command is still present with count 30/total 45. The first three blink commands disappear 17 observed frames after arrival. Thus remaining blink animation is not evidence of continuing universal invulnerability. `isExist` denotes damage eligibility in these paths, not actor liveness. No damaging fire/weapon contact was introduced during transit or arrival, so these observations do not establish every hazard interaction.

## Inspection helper and remaining boundary

[inspect_reference_focus.py](../../tools/inspect_reference_focus.py) resolves physical slot layouts, namespace aliases, record references, primitive fields, arrays and native positions. Ambiguous names, incomplete arrays, truncation and missing referenced records fail explicitly instead of guessing. Its same-boundary comparison was run against the actual earlier full/focus capture in `.scratch/edition-5-research/trace-design/focus-benchmark-01`: 379 unique records, 10,161 recursive values, 781 array occurrences, 57 functions, 45 display references, 134 shared display fields, and 255 map/search cells matched. The later recovery player's extra geometry is explicitly reported as `unverified_native_fields`; the full observer cannot serve as its geometry oracle.

The initial cases above support source-linked assertions for the particular ordinary actor, bomb and generated Cinema board. The subsequent supplement below addresses the initial gaps in hazardous arrivals, stationary expiry, actor overlap, the other cardinal departures and corridor approaches. They do not test Godot diagonal movement, mobile joystick behavior or phone feel. No original behavior described here silently replaces an accepted design adaptation.

## Supplement: cardinal edges, contact expiry and hazardous portals

Thirteen additional cases were executed against preserved `.scratch/edition-5-research/reference-player-recovery-v4/probe.exe`, SHA-256 `9c1dcc316e1344e5061194ba5062abc01396145d89318ea27582058a6bb1ea3c`. Its adjacent build manifest identifies the 13 research patches. The authority SWF/hash, original Normal Arcade/Cinema seed-42 menu chronology and Stage3 layout are unchanged. These runs contain **892 additional per-frame focused observations and 155,534 original events**, with no dropped/overflow events or recorded errors. Some independent runs overlapped on the host; none of their host durations is claimed as a realtime gameplay benchmark.

All new cases are under [cases/movement](../../tools/reference_player/cases/movement/). Use the same replay CLI with the v4 player and `--observe --focus --fixtures`. [summarize_supplement.py](../../tools/reference_player/cases/movement/summarize_supplement.py) reconstructs the smaller per-actor/per-cell CSVs, boundaries, original selected call/return events, fixture results and screenshot inventories. Every curated directory below preserves the executed case and manifest; raw runs remain under `.scratch/edition-5-research/reference-runs/`.

[The recorded assessment](reference-2026-10-19/movement/supplement/assessment.json) passes 245 artifact-integrity and observation checks. Reproduce it with `python tools/reference_player/cases/movement/assess_supplement.py`. The checks include source/player/case/command/fixture/screenshot identities, original acceleration/release, live-bomb re-entry blocks, stationary expiry in fire, actor overlap, protected portal entry, ordinary blast blocking, frozen/resumed Send/blink counters, and mine arrival/death ordering. These are checks of the recorded original runs, not new Godot simulation tests or native Flash parity.

| Case | Final raw run | Curated supplement |
| --- | --- | --- |
| `03-cardinal-down.json` | `movement-cardinal-down-42-01` | [Down](reference-2026-10-19/movement/supplement/cardinal-down/summary.json) |
| `04-cardinal-left.json` | `movement-cardinal-left-42-01` | [Left](reference-2026-10-19/movement/supplement/cardinal-left/summary.json) |
| `05-cardinal-up.json` | `movement-cardinal-up-42-01` | [Up](reference-2026-10-19/movement/supplement/cardinal-up/summary.json) |
| `06-protected-portal.json` | `movement-protected-portal-42-01` | [Protected traveler](reference-2026-10-19/movement/supplement/protected-portal/summary.json) |
| `07-portal-ordinary-bomb.json` | `movement-portal-bomb-42-01` | [Ordinary bomb and portal](reference-2026-10-19/movement/supplement/portal-bomb/summary.json) |
| `08-portal-pause.json` | `movement-portal-pause-42-01` | [Pause during transfer](reference-2026-10-19/movement/supplement/portal-pause/summary.json) |
| `09-portal-mine-hazard.json` | `movement-mine-hazard-42-01` | [Hazardous destination](reference-2026-10-19/movement/supplement/mine-hazard/summary.json) |
| `10-ordinary-overlap.json` | `movement-ordinary-overlap-42-01` | [Ordinary actor overlap](reference-2026-10-19/movement/supplement/ordinary-overlap/summary.json) |
| `11-stationary-fire-expiry.json` | `movement-stationary-expiry-42-01` | [Expiry while stationary in fire](reference-2026-10-19/movement/supplement/stationary-expiry/summary.json) |
| `12`–`15-corridor-{right,left,up,down}.json` | `movement-corridor-{right,left,up,down}-42-01` | [Right](reference-2026-10-19/movement/supplement/corridor-right/summary.json), [Left](reference-2026-10-19/movement/supplement/corridor-left/summary.json), [Up](reference-2026-10-19/movement/supplement/corridor-up/summary.json), [Down](reference-2026-10-19/movement/supplement/corridor-down/summary.json) |

### Four cardinal departures and source numeric coordinates

Together with the original rightward case, the three additional cases measure direction acceleration, immediate displacement stop on release, retained decaying velocity, reversal, wall/block clamping and ordinary bomb departure/re-entry in all four directions. Bottom-corner setup first moves the existing AI3 to verified empty floor `(13,11)`, then relocates the human to the freed `(15,13)` using the original guarded fixture. Subsequent motion and bomb placement are legal input. No fractional position/speed values are assigned.

| Outward direction | Bomb cell/anchor | After departure | After reversing toward the still-live bomb |
| --- | --- | --- | --- |
| Right, initial case | `(1,1)` / `(30,30)` | `(60,30)` | `(60,30)`, blocked |
| Down | `(1,1)` / `(30,30)` | `(30,87)` | `(30,60)`, blocked |
| Left | `(15,13)` / `(450,390)` | `(420,390)` | `(420,390)`, blocked |
| Up | `(15,13)` / `(450,390)` | `(450,360)` | `(450,360)`, blocked |

Each new departure ends with original `bombNum=1`; none depends on waiting for its fuse. Four frames after releasing the first held direction, the physical coordinate remains unchanged in each case even though speed decays. Source collision uses `itemWid/itemHei`, `-1` edge calculations and direction-specific `HitMove` queries; neither visible sprite overlap nor centered logical cell alone defines the complete collision footprint. The original brief reversal penetration and fractional corridor result from the initial case remain relevant counterexamples to a universal strict-footprint claim.

The four perpendicular-turn cases create real fractional offsets through three input frames. Right/down first produce local-axis positions `31.6,34.15,37.25`; left/up from the opposite corner produce `448.4,445.8,442.65` or `388.4,385.8,382.65`. Speed magnitudes begin `1.6,2.56,3.136`, but native display quantization makes opposite-direction positions asymmetric. After turning, several callbacks adjust the old axis before forward movement resumes. These four longer turns reach the grid axis exactly; the earlier smaller-offset example retains 0.95 pixels. Do not simplify either observation into an unconditional snap rule.

Static `AbstractObject.as:xN/yN` returns `int(Math.floor((xPos + itemWid/2) / GRID_WIDTH))` and its y equivalent; `HitMove` separately floors prospective leading/trailing edges. Controlled positive crossings in the traces fall on opposite sides of the resulting 45-pixel boundary (for example 44.35 versus 48.15), with the already-recorded next-callback map update. These are source-coordinate anchors and center-biased logical queries, not a license to replace the formulas with Godot rounding. The observed 0.05-pixel native precision belongs to this pinned Ruffle run. Negative/off-board actor coordinates were not synthesized and native Flash coordinate conversion was not compared.

### Ordinary overlap and stationary expiry inside existing fire

In the ordinary overlap case, AI3 is placed on adjacent empty floor `(1,2)`. Eight legal Down frames move the human to local `(30,55.9)`; releasing and waiting leaves both actors in map cell `(1,2)`. At 799 both are normal and damage-eligible, with the stationary AI anchored at `(30,60)`, and neither is dead. This separates ordinary actor overlap from fixed-terrain physical collision and from offensive Invincibility contact. `HitMove.fixedHitArr` contains platform/bomb/box/tractor types, not an ordinary robot-body blocker. Offensive overlap is independently demonstrated in the [Invincibility contact record](edition-5-protection-vehicle-probes.md).

The stationary-fire case uses two original ShieldProp collections, one human at `(1,1)` and one surviving AI at `(2,1)`. Its first AI-owned bomb consumes both shields at 795 and adds the original 80-count immunity. That same living AI is relocated to empty `(1,2)` and creates a second ordinary bomb; the human receives no movement input at any point.

| Frame | Human state/eligibility | Fire `(1,1)` | Protection |
| --- | --- | --- | --- |
| 795 | Normal / false | true | New shield immunity, count 1 |
| 812 | Normal / false | false | First flame cleared |
| 867 | Normal / false | true | Second bomb, count 73 |
| 875 | Normal / false | true | Count 81 |
| **876–882** | **Normal / true, alive** | **true** | Immunity command removed |
| 883 onward | Normal / true, alive | false | Second flame cleared |

The human remains at `(30,30)`, without a newly executed human `GetFireCommand` at expiry. This is an observed original edge: damage eligibility returning does not by itself force stationary fire damage. Source `AbstractRobot.updateRobotPosition` gates the position-change chain on logical cell/state/vehicle changes, while `InvincibilityCommand` changes `isExist` at expiry without changing this actor's normal model state. The original bomb hit already occurred while protected, and its visible-fire cleanup does not continuously poll every actor. This does not generalize to an Invincibility-item expiry that changes model state, to a later crossing, or to other repeated-attack callbacks. Late entry into existing fire is separately demonstrated by the [bomb contact probes](edition-5-bomb-contact-probes.md).

### Portal placement and blast blocking are different from walkability

The original Grid's `isEmpty` requires no platform, whereas its physical/block query permits ordinary Portal traversal. `RobotController.addBomb` checks `Map.isEmpty`. A latched actor standing on destination `(13,12)` therefore fails ordinary bomb placement through both delivered Space and the direct original addBomb fixture (`placed=false`, `bombNum=0`).

For blast behavior, an AI naturally collects power 2 at empty `(13,11)` and places an original ordinary bomb there. At human physical arrival 798, `(13,11)` and the destroyed soft block `(13,10)` have fire; portal `(13,12)` has **no fire**, and the soft box beyond it at `(13,13)` remains. The portal both excludes the ordinary ray's flame cell and stops continuation. The human survives that arrival. Static `Grid.isEmpty/item`, default-false `AbstractObject.isExist`, `Portal`, and `Bomb.blast` implement these separate queries. Traversable does not mean empty-for-placement or transparent-to-blast.

### Protected entry, mine hazard, dead actors and arrival timing

A naturally collected Invincibility item makes the human model `Invincible` and `isExist=false` before entry. The portal accepts that protected actor at 730. Physical arrival 759 sets `isExist=true` while the model is still **Invincible**, and that combination remains at 767. This is the original Send completion write overriding eligibility, not proof that the item has expired or that its painted effect guarantees continued immunity.

The hazardous-destination case uses the equipped **landmine**, whose original action bypasses the ordinary empty/capacity placement guard. The human collects it on empty source-neighbor floor before transfer; it is not constructed on the portal by a fixture. Legal Space after arrival constructs the mine on `(13,12)` at 760. Ordinary addBomb on that same platform still fails. The human legally exits upward, and the original mine arms at 767 after owner occupancy leaves. An AI is then moved into source `(3,2)` by eight explicit original movement callbacks with normal frames between them; these are controlled fixture callbacks, not AI key decisions.

| AI-traveler boundary | Observed original state |
| --- | --- |
| 781 | Send begins, count 1, `isExist=false` |
| 810 | Physical arrival `(390,360)`, eligibility true; logical/map cell still source `(3,2)` |
| 811 | Destination occupancy `(13,12)`; still alive |
| **812** | Armed mine contact; actor becomes dead/unregistered; portal fire true; blink command still present at count 31/45 |

The mine also kills its owner on adjacent `(13,11)` through its original blast. A remaining AI elsewhere keeps this from being a synthesized result transition. The dead traveler has no destination map membership and no new Send command through the last sampled 821 boundary. Static `Portal.runEngine` excludes model state dead, and death also removes occupancy before later portal queries; this experiment does not fabricate a dead robot left inside the portal registry merely to force that predicate.

The mine's original contact path leaves `_isBlast=false` despite creating its blast/fire, so that flag alone is not an active-mine or safety oracle. See the independently recovered [mine lifecycle](edition-5-landmine-probes.md) for its broader arming/contact behavior. This case supplies an actual damaging arrival while the portal's blink is still present; it does not infer damage from animation or use an ordinary bomb that the portal blocks.

### Pause and interrupted input during transfer

P is delivered after the first Send callback. The original delayed pause takes effect at 733 with Send/blink counts 5, then both counters and physical position stay fixed through 779. This includes forty steps with Right delivered while paused. Space resumes at 780 using the **same Send object**, now count 6; physical arrival occurs at 804 and destination occupancy at 805. Right held through resume and arrival does not move the actor or create a bomb in this recorded interrupted-input path. A released/new Up input then leaves the portal normally, reaching the neighboring cell by 822.

Source paths are `Game.gamePause/doGamePause/gameResume/doGameResume`, the person input controller's listener lifecycle, and the preserved Send command. These source events/counters establish pause and recovery of the actual transfer, not a restarted teleport. No conflict with the accepted fresh-input pause rule was observed in this particular path; this is not a proof that every original held-input/repeat combination follows that new-game policy.

The selected portal mouths have fixed boxes to their left/right in this generated layout, so the reachable cardinal approaches exercised here and in the four round trips are vertical. The supplement does not remove those walls to create nonexistent horizontal approaches. Remaining limits are arbitrary untested collision geometries, off-board/negative-coordinate behavior, other platforms/vehicles, other simultaneous damage orderings, native Flash comparison and phone/diagonal feel. Source observations and accepted departure/diagonal/pause adaptations remain separate.
