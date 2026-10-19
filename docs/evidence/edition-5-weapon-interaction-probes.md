# Original weapon interactions and animated flamer geometry

The hashed publisher SWF was exercised through **35 controlled interaction cases**, each with two legal Space actions, plus [three laser portal-ray cases](edition-5-laser-portal-probes.md), alongside the [directional action recovery](edition-5-weapon-action-recovery.md) and its lifecycle cases. This recovers original behavior for later porting; no Godot gameplay or production artwork changes here.

## Authority and reproduction

Authority SHA-256: `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`. The interaction and geometry runs use pinned Ruffle revision `45366370ed7d1a59c89aa3cf7b765c7a274407cd`, preserved player `reference-player-recovery-v2/probe.exe`, SHA-256 `5a7adba2c2781818a418f19f5976bad1917b8c64568fd7b562a7660bdc99bb74`. Every interaction bundle includes its eleven-patch build manifest. Later lifecycle builds and patch differences are identified separately in the [tooling record](edition-5-recovery-tooling.md).

[Interaction cases](../../tools/reference_player/cases/weapons/interactions/) enter Normal Arcade/Cinema using the UI and original seeded RNG. Original AI stop methods and guarded reposition calls prepare targets; constructor fixtures create pickups, which ordinary GetItem commands collect. Original block creation prepares a breakable obstacle. The bomb target is created through the existing AI actor's original controller, preserving its ownership. These are controlled setups, not input-only achievements. No health, score, result, fire, animation frame or equipped-weapon fields are assigned by the fixtures.

```powershell
./tools/reference_player/build.ps1 -Fixtures -Events -Compact -Focus
python tools/replay_reference.py --observe --focus --fixtures --case tools/reference_player/cases/weapons/interactions/hammer-enemy.json --output .scratch/edition-5-research/reference-runs/my-hammer-hit
python tools/inspect_weapon_interactions.py .scratch/edition-5-research/reference-runs/my-hammer-hit --output .scratch/edition-5-research/my-hammer-summary.json
```

The [interaction index](reference-2026-10-19/weapon-interactions/summary.json) records observed boundaries, not asserted expected outcomes. Each case folder retains exact case/manifest/command/stderr files, fixture acknowledgements, selected original screenshots, artifact hashes and losslessly compressed `observations.json.gz` containing 160 post-step actor/cell observations, state transitions and selected original execution events. Full raw frame/state/event files remain in ignored research storage. Across the 35 final runs there are **5,600 observations**, no selected execution errors and no collector overflow/stack overflow. Registration is read from the actual original `Game.robots` array. The Focus projection is a union of registered and player-owned actors and can retain an unregistered dead model during its death animation. An audit corrected 1,002 derived row flags that had conflated projection with registration; raw source artifacts and death frames were unchanged. [Registration check](reference-2026-10-19/weapon-interactions/registration-check.json) records that correction.

## Target matrix

Each of hammer, flamer, laser, triple-shot and fireball was exercised against an adjacent ordinary enemy, a co-located enemy, a shielded enemy, a soft block, an ordinary bomb, a ground capacity pickup and a solid wall. Facing Right uses the open starting corridor; the solid test faces Up into the existing boundary. Separate four-direction action and geometry cases establish directional animation/trajectory behavior. The [portal supplement](edition-5-laser-portal-probes.md) directly measures empty, occupied and shielded mouths: the bare portal is nonblocking to laser, and the existing soft box beyond it ends the single pass. This is a representative target matrix, not every target/direction/interleaving permutation.

| Observed boundary | Hammer | Flamer | Laser | Triple-shot | Fireball |
| --- | --- | --- | --- | --- | --- |
| Adjacent enemy first dead | 847 | 828 | 834 | 827 | 839 |
| Own-cell enemy first dead | 857 | 834 | 844 | 835 | 848 |
| Shield first consumed | 848 | 829 | 835 | 828 | 840 |
| Soft block removed | 847 | 828 | 834 | 825 | 838 |
| Ground pickup removed | 847 | 828 | 834 | 827 | 839 |

These are absolute harness counters for their individual recorded cases. Ordinary first input is 823; shield setup adds one frame, and the own-cell setup adds ten. Differences between columns are observed original action boundaries, not real-time latency measurements or universal tick durations. Sources are `items/weapons/*Prop`, their commands, and `bombs/AbstractBomb`, `FlamerFire`, `Laser`, `TripleShootGunBomb` and `FireballBomb`; the [action report](edition-5-weapon-action-recovery.md) supplies function-level locators and directional sequence data.

Own-cell sharing is reached by **legal human movement** into the stopped adjacent enemy: eight held Right frames followed by release produce native x positions 240.35 and 243, both logically `(2,1)`. Both actors are ordinary and damage-eligible. The fixture's no-overlap guard is not weakened. Hammer's own-cell loop excludes its owner but hits the other actor; laser and projectiles likewise distinguish the owner from other actors in that cell. Earlier attempts that moved past the target, and rejected direct overlap fixtures, remain ignored setup records and are excluded from the final index.

The shield cases separate survival from a kill: hammer and laser consume protection but their second hit occurs before the original temporary immunity ends, so the target survives both actions. Flamer, triple-shot and fireball subsequently kill their target in these two-action windows. This does not establish hitpoints or identical damage frequency among weapons. The [protection record](edition-5-protection-vehicle-probes.md) explains original eligibility and recovery.

All five weapons destroy the prepared ground pickup and soft obstacle. The flamer additionally removes a second existing soft block at `(4,1)` later in the same action: `(2,1)` clears on 828, `(4,1)` on 845. [Per-frame cells](reference-2026-10-19/weapon-interactions/flamer-soft-progression.json) retain this progression and later drop changes. This is successive animated-tip interaction, not an instant three-cell ray. Bomb-target cases invoke original BLAST/damage paths; adjacent chains can kill the firing human, so absent recovery there is recorded as death, not an infinite weapon lock. See the [late laser chain](edition-5-chain-overlap-probes.md) for explicit phase order and ownership.

For surviving two-use cases, use count reaches two and original `initWeapon` restores the default action; snapshots then show no equipped special weapon. A second legal down is distinct from holding one down. Action locks, frame thresholds, empty up handlers, source attachment/layer changes, beam damage versus visible duration and projectile cleanup are described in the [action sequence record](edition-5-weapon-action-recovery.md).

## Flamer structure, attachment and actual animated bounds

[inspect_flamer_structure.py](../../tools/inspect_flamer_structure.py) independently reads source SWF tags for four effect roots, four held weapons and four selected human directional bodies. The generated [metadata](reference-2026-10-19/weapon-survey/flamer-structure.json) contains **138 reachable definitions**, including 45 sprite timelines and 36 morph definitions, inherited source placements, named hand/gunpoint/fire_Play attachments, shape bounds and morph start/end envelopes. Independent FFDec XML agrees on **45 timelines, 1,334 placement records and all 93 shape/morph definitions' compared bounds**. This exports metadata, not painting paths, sprites or textures.

```powershell
python tools/inspect_flamer_structure.py --verify-xml .scratch/edition-5-research/structure-audit/publisher.xml --output .scratch/edition-5-research/my-flamer-structure.json
```

Static hand and gunpoint translations reproduce all four actual source-computed fire positions. [Attachment comparison](reference-2026-10-19/weapon-survey/flamer-attachment-comparison.json): Up `(14.8,10.1)`, Down `(6.75,11.5)`, Left `(9.65,13.2)`, Right `(24.65,10.2)` in actor-container coordinates. The held weapon copies the selected body's hand position/frame; `FlamerProp.countFirePos` adds the named gunpoint's local x/y. These numbers are selected human samples, not all skins/rides.

The separate native geometry observer reads bounded **Script** bounds and raw transforms without calling AS getters or transform-cache getters. [inspect_flamer_geometry.py](../../tools/inspect_flamer_geometry.py) combines those recorded widths/heights and parent scales with the source coordinate formula, then compares the result with actual original `FlamerFire.xN/yN` returns from that frame. It agrees on **88/88 sampled endpoints**, 22 frames in each direction. Each directional folder under [weapon-survey](reference-2026-10-19/weapon-survey/) retains its geometry summary and a hash-indexed `native-oracle.zip` with the complete compared native snapshots and original execution packets; archives were CRC-checked and byte-compared before consolidating them.

Source endpoint formulas are `int(robot.view.xN + direct.x * firePlay.width * weaponPlay.scaleX / 30)` and the y equivalent. They use animated inner bounds, signed direction and truncation toward zero; they are not a linear reach ramp. The same source action first shoots, then tests the inner timeline completion. The outer clip has one frame while the inner has 24. Original wall encounters change parent scale; Up/Left samples remain clipped to the neighboring boundary cell, while Down/Right progress through cells one to four. Native animated width/height includes nested placements and morph playback; the extracted start/end RECTs alone do not evaluate intermediate outlines.

The existing Godot flamer envelope remains an approximation. These comparisons verify sampled **Ruffle** timeline/bounds behavior against the original game's own calculation, not Adobe Flash rendering, every painted pixel, arbitrary skewed transforms, every obstruction or all character/vehicle attachment poses. Morph outlines and filters have not been independently rendered by a second engine. Those limits are retained rather than inventing a complete vector evaluator.

## Replacement, pause and clocks

The [lifecycle bundle](reference-2026-10-19/weapon-lifecycle/) and [action report](edition-5-weapon-action-recovery.md) retain early replacement, animation pause/resume, paced projectile recovery and pending-recovery pause cases. A pending pickup under the initial flamer is destroyed by its first own-cell tip before collection; this is **not** a successful equipment replacement. A separate late case constructs the pickup after the tip advances, and normal collection replaces/disposes the active flamer on 736, restoring control. Other early replacement cases replace on 724. The explicit active-pickup fixture permits a constructor during interruption; collection/disposal still belongs entirely to the original engine.

Original triple/fireball recovery uses a **0.3-second TweenMax clock**, not a fixed 10/11 callbacks. Host time, stepping, observation and pacing remain separately logged. Fireball's delayed recovery executes at 742 while the game is actually paused from 741; its restored listener receives the resume Space down at 798 and starts another action. Original pause's 100-ms delay and source event ordering matter. The accepted Godot simulation clock and fresh-input policy remain deliberate adaptations. No nominal frame count is silently substituted for this measured clock behavior.

## Limits

The reference player has no audio backend or native Flash comparison. Ruffle warnings remain in stderr; zero selected AS event errors does not mean zero renderer warnings. Whole-session observer equivalence is unclaimed because original Date/getTimer behavior reacts to host/observer cost. Target cases, settings, RNG calls, original-method fixtures and pointer identities are classified explicitly; they do not establish identical seeded gameplay across engines. Final redraw, joystick/device tests and release acceptance remain outside this recovery work.
