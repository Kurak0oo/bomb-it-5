# Selected original-game recovery acceptance

Accepted 2026-10-19 after independent Standards and Spec review and correction of their findings. This closes the **recovery** boundary of #22–#37. The current Godot implementation is preserved; these findings have not been ported. [The handoff](edition-5-porting-handoff.md) owns the ordered fidelity work, while #20/#21, final redraw, phone/iOS testing and four unresolved slots remain separate.

## Ticket acceptance map

| Ticket | Evidence and review basis |
| --- | --- |
| #22 Original session | [Pinned original playback](edition-5-reference-session.md), repeated legal movement/bomb/explosion, settings, captures, host/frame logs and emulator limits. |
| #23 Ordinary bomb/fire | [Legal contact probes](edition-5-bomb-contact-probes.md), [callback events](edition-5-reference-events.md) and [enemy damage/score/capacity](edition-5-protection-vehicle-probes.md). Last lethal/first safe, self/enemy hits, callback eligibility and immediate soft collision changes are distinguished. |
| #24 Chains/overlap | [Both owner orders, delayed overlap, late laser and command replacement](edition-5-chain-overlap-probes.md); 27 evidence checks and a bounded event-OFF comparison. |
| #25 Movement/contact | [All-cardinal motion and supplement](edition-5-movement-runtime-probes.md), fractional turns, footprint/occupancy, bomb departure/re-entry, actor overlap and stationary protection expiry in fire. |
| #26 Portals | [Four original transfers and supplement](edition-5-movement-runtime-probes.md), eligible/protected/hazardous arrivals, ordinary bomb rejection/blast blocking and paused transit; supplement 245 checks. |
| #27 Drops/upgrades | [Actual draw/cap/budget/quota/timed probes](edition-5-pickup-probes.md), [pickup destruction](edition-5-weapon-interaction-probes.md) and [life/result ownership](edition-5-results-runtime-probes.md). Shared-list mutation and timed bypass remain source facts. |
| #28 Protection/vehicles | [Collection, precedence, Car/Moto loss/recovery, contact, expiry and pause/teardown](edition-5-protection-vehicle-probes.md), with [portal arrival](edition-5-movement-runtime-probes.md); 83 primary evidence checks. |
| #29 Mine | [Ten lifecycle scenarios](edition-5-landmine-probes.md), including departure latch, contact/protection, occupancy/capacity, external BLAST underflow and teardown; 63 checks. |
| #30 Hammer | [Four-facing action sequences](edition-5-weapon-action-recovery.md), [target/two-use matrix](edition-5-weapon-interaction-probes.md) and replacement/pause lifecycle evidence. |
| #31 Flamer | [Animated geometry/targets](edition-5-weapon-interaction-probes.md): 88/88 endpoint comparisons, four attachment matches, independent XML comparison of 45 timelines/1,334 placements/93 shape-morph bounds, successive soft destruction and active replacement. |
| #32 Laser | [Actions/targets](edition-5-weapon-action-recovery.md), [late chain](edition-5-chain-overlap-probes.md), and [three portal-ray measurements](edition-5-laser-portal-probes.md): 124 checks over 93 frames/35,912 events, single Shoot pass, first blocker, protection, beam removal and restored movement. |
| #33 Projectiles | [Four-facing emissions/collision/cleanup](edition-5-weapon-action-recovery.md), [target matrix](edition-5-weapon-interaction-probes.md), paced and pending-Tween pause/replacement/exhaustion scenarios; shared lifecycle bundle 126 checks. |
| #34 AI navigation | [Twenty representative AI runs](edition-5-ai-runtime-probes.md), actual returned perceptions/paths, profile/parser quirks, ranking/danger/cancellation and stop/death/transfer registration. |
| #35 AI combat | [Ordinary opportunities/escape, unsafe rejection and all six equipment families](edition-5-ai-runtime-probes.md), actual delayed controls, damage and subsequent navigation. |
| #36 Death/results | [Six selected result flows](edition-5-results-runtime-probes.md): 565 observations/nine settlements, zero-kill victory, both simultaneous-death orders, life/retry/game-over, HUD versus final totals and control staging. |
| #37 Handoff | [Evidence index](README.md), [instrumentation provenance](edition-5-recovery-tooling.md), this acceptance audit and [source-to-Godot classifications/port order](edition-5-porting-handoff.md). No material unexplained selected-scope behavior remains identified by review. |

Counts above belong to their named bundles; overlapping observations are not added into an invented total. Representative state/target/direction scenarios do not claim every possible permutation or a retail campaign audit. Native Flash, audio, arbitrary morph/filter/skin/ride transforms and all late callback interleavings remain bounded limits. They are not silently promoted to verified equivalence.

## Standards review

The independent reviewer found one P2: staged Ruffle core edits could evade worktree-only provenance guards. The fix rejects staged core changes before setup, compares remaining changes with pinned HEAD and records provenance against HEAD plus untracked filenames. An actual staged-comment experiment reproduced the old omission and verified rejection before Cargo; the baseline file/index were restored clean. Follow-up review found no remaining material Standards finding or actionable smell judgment. [Guard evidence and build details](edition-5-recovery-tooling.md) preserve the result.

## Spec review

The independent reviewer found one P2: the laser's required portal traversal had no direct measurement. Three new original-reference cases cover empty, occupied and shielded portal mouths, exact ray cells/first blocker, one Shoot pass, eleven cleanup callbacks and fresh movement. Follow-up review independently reproduced all 124 checks, compared 155 paired occupied-ray calls with raw events and regenerated decisive native projections. It confirmed the portal's nonblocking query and its distinction from ordinary blast blocking. No material Spec finding remains.

A final self-audit also corrected derived weapon interaction registration: Focus includes player-owned death-animation objects after actual Game.robots removal. The helper now records `projected` separately from actual `registered`; all 5,600 observations were checked against raw registries, correcting 1,002 flags without changing raw inputs/artifacts or death frames. Independent follow-up verified the decisive raw/curated frames and every updated bundle hash. This correction is disclosed in the [interaction record](edition-5-weapon-interaction-probes.md).

Review outcome: initial findings **Standards 1 / Spec 1**, both resolved; **0 outstanding material findings** on either axis. Parent issue #1's title, body, state, labels and comments were compared with their saved pre-work values and remain unchanged. #20/#21 remain open.

## Verification

- Authority SWF hash remains `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`; replay and static extraction reject another hash before use.
- The canonical fourteen-patch player passes locked Rust check/build and a fresh original Normal Arcade replay. The unchanged-core, observation-disabled package passes locked Rust checking independently. Check-only manifests identify their operation and carry no executable hash.
- All fourteen patches apply to pristine pinned sources; all nine resulting Rust files match the live checkout after line-ending normalization. Historical exact patch bytes and executable/build identities remain preserved, including the earlier stale-Cargo bootstrap correction.
- Authored Python tools parse; JSON artifacts parse; gzip/ZIP bundles decode and ZIP CRCs pass. Indexed reference/case/patch/package bytes match worktree bytes under scoped Git attributes. Local authored report links and whitespace checks pass. Native case/log/fixture/image hashes and collector loss/balance are checked by the named bundle assessors.
- The unchanged **Godot 4.5 full runner passes 244 functional checks**: 28 command/queue, 41 scheduler, 43 bomb, 16 round, 84 regression, 29 scene and three full-board playthrough checks. No production gameplay, scene, project setting or art changed. These remain functional verification, not paired original-SWF parity tests.

Whole-session observer neutrality was **not** established: the recorded failed comparison and event-OFF divergence remain disclosed. Narrower successful comparisons, actual consumed RNG, source callback ordering, native timeline bounds and actual method returns support their stated claims. Original clocks are not replaced by observation. The handoff therefore identifies approximations and accepted adaptations explicitly, with no overall fidelity percentage.
