# Original laser rays through Cinema portals

Executed 2026-10-19 to close the portal-measurement gap in [#32](https://github.com/Kurak0oo/bomb-it-5/issues/32). The original laser passes through a bare Cinema portal both when empty and when occupied. An unprotected occupant dies; a shielded occupant loses its shield and survives. The ray stops at the existing soft box beyond the portal in all three runs.

The source's actor-present blocking exception is **not needed on these bare portal cells**. The actual recorded `Map.isBlock` result is false at the portal, so the `!isBlock || actorsPresent` condition short-circuits before its actor-presence query. Occupancy is subsequently queried by the damage method. This distinguishes the two queries rather than inferring a blocking exception from visible overlap.

## Authority and controlled setup

- SWF: `.scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf`, SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`.
- Player: `.scratch/edition-5-research/reference-player-recovery-v6/probe.exe`, SHA-256 `33d2791282aa7d93d5b9bfe7a1ce166a31e155355e02c8bd584b08a60354ffe8`. Its adjacent build manifest identifies the unchanged 14-patch research player, pinned Ruffle revision `45366370ed7d1a59c89aa3cf7b765c7a274407cd`.
- One human, three Normal AI, Arcade, Cinema, explicit initial seed 42. This chronology generates CinemaStage3; the [movement record](edition-5-movement-runtime-probes.md) establishes its portal mapping and selection evidence.
- Human is relocated through the original guarded floor fixture to `(13,11)` and naturally collects the original laser, facing the verified original Down direction. Source AI stop operations are explicit setup. No portal, map geometry, health, score, outcome or weapon-use fields are written.
- Occupied variants relocate AI1 to empty `(3,3)` and invoke eight original Up movement callbacks, with normal frames between them. The source portal transfers it to `(13,12)`. The shield variant naturally collects an original ShieldProp before travel. No actor is directly positioned on a portal.

Send completion restarts the AI controller. The final cases stop it again immediately after physical arrival and allow two normal frames for destination occupancy before the charge. This matters: an earlier unprotected setup waited six frames after arrival and let the AI drift toward the shooter during charge. That attempt remains ignored raw storage and is not the final occupied-portal evidence. AI stop does not imply cancellation of every delayed callback; final per-frame positions prove the target actually remains on the portal for the shot.

## Replay and evidence

| Case | Final raw directory under `.scratch/edition-5-research/reference-runs/` | Curated evidence |
| --- | --- | --- |
| [01-empty-portal.json](../../tools/reference_player/cases/laser-portals/01-empty-portal.json) | `laser-empty-portal-42-02` | [Empty](reference-2026-10-19/laser-portals/empty/summary.json) |
| [02-occupied-portal.json](../../tools/reference_player/cases/laser-portals/02-occupied-portal.json) | `laser-occupied-portal-42-03` | [Occupied](reference-2026-10-19/laser-portals/occupied/summary.json) |
| [03-shielded-portal.json](../../tools/reference_player/cases/laser-portals/03-shielded-portal.json) | `laser-shielded-portal-42-03` | [Shielded](reference-2026-10-19/laser-portals/shielded/summary.json) |

Each curated directory retains exact case/manifest/protocol/fixture results, native/raw frame summaries, boundary snapshots, paired selected calls and the **complete selected subtree of the actual Shoot execution** in `ray-call-tree.json`. Twelve original screenshots retain before/beam/cleanup/fresh-movement views and hashes. `.gdignore` keeps reference art outside production resources.

```powershell
python tools/replay_reference.py --player .scratch/edition-5-research/reference-player-recovery-v6/probe.exe --case tools/reference_player/cases/laser-portals/02-occupied-portal.json --observe --focus --fixtures --output .scratch/edition-5-research/reference-runs/laser-occupied-portal-new
```

The event command is below; the full label is under 256 bytes and explicitly includes both file-local command classes:

```text
events laser-events 20000 zlong.bombit5 ShootLaserCommand LaserEndCommand flash.display::DisplayObjectContainer/removeChild
```

[curate.py](../../tools/reference_player/cases/laser-portals/curate.py) rebuilds each bundle using `--run RAW --output CURATED`. [assess.py](../../tools/reference_player/cases/laser-portals/assess.py) checks the recorded observations and identities. The [assessment](reference-2026-10-19/laser-portals/assessment.json) passes **124 checks**, covering 93 focused frames and 35,912 original events. All selected calls balance; discarded events, stack overflows and original recorded errors are zero. This is evidence validation, not new Godot simulation testing.

## Actual traversal and the actor-presence condition

The synchronized Shoot subtrees show the same direct ray queries in every case:

| Cell | Direct `Map.isBlock` | Conditional direct `Map.getRobot` | Interaction |
| --- | --- | --- | --- |
| `(13,11)` shooter | false | Not evaluated by OR | `hitRobotUnderPoint(...,false)` and `hitItem` |
| `(13,12)` portal | **false** | **Not evaluated by OR** | `hitRobotUnderPoint(...,false)` and `hitItem` |
| `(13,13)` existing soft box | true | Empty Array, length 0 | `isEmpty=false`; endpoint/item hit, then stop |

No cell beyond `(13,13)` is queried by this ray. The soft box is present before the shot and removed in the same damage pass. Its removal does not extend that already-terminating pass. Actor-hit calls cover only the shooter cell and portal; item-hit calls additionally cover the first blocker. The false self flag excludes the shooter while permitting other occupants.

The nested damage query at `(13,12)` returns an empty Array in the empty case, and exactly the source AI1 reference in both occupied cases. That exact reference receives one `AbstractBomb.hitRobot` call from this Laser object. Before charge, the target is physically anchored at `(390,360)`, logically `(13,12)`, normal and damage-eligible. At the pass:

- Unprotected target: becomes dead at `(13,12)`; it did not move into the shooter's cell.
- Shielded target: shield reference clears, model remains normal and damage eligibility becomes false. It survives the remaining visible-beam/cleanup interval.

The original laser does not create persistent map fire on the portal in these runs. This differs from ordinary bomb-ray blocking and from the mine's damaging portal-center blast, which are independently recorded in the movement supplement.

Primary source, relative to `.scratch/edition-5-research/publisher-scripts/scripts/zlong/bombit5/`: `commands/weapon/LaserPlayCommandChain.as:86–218` contains the exact ray condition and first-blocker branch; `maps/Grid.as:140–164` implements different `isBlock` and `isEmpty` queries. A bare Portal has no box/bomb/tramcar, so the observed block result is false even though its platform makes `isEmpty` false. A **blocked** cell containing an actor could exercise the OR exception, but these bare-portal measurements do not claim to force that different branch.

## Charge, single pass, visible interval and recovery

| Original boundary | Empty | Occupied | Shielded |
| --- | ---: | ---: | ---: |
| Delivered Space / use 0→1 | 722 | 761 | 762 |
| First stepped charge frame 1 | 723 | 762 | 763 |
| Charge frame 11, Laser construction and one Shoot pass | **733** | **772** | **773** |
| First LaserEnd callback | 734 | 773 | 774 |
| Eleventh LaserEnd callback, beam removal and recovery | **744** | **783** | **784** |
| Fresh legal Down movement checked | 753 | 792 | 793 |

Creation and Shoot execute in the same original engine frame as the charge threshold; the new End command begins the following frame. There is one Shoot execution per action, followed by eleven End callbacks. These are executed command counts, not a claim that the visible beam continuously damages for eleven frames.

At cleanup, the recorded native `DisplayObjectContainer.removeChild` argument is the **same Laser container reference** observed during the beam. The original `renewRobot`, `resetPlayMc`, `Laser.deleFire` and `countWeapon` calls execute in that cleanup frame. Subsequent snapshots show no charge play, a cleared control-interruption stage and the Laser's owner reference cleared. One of the two uses has been consumed. Three fresh Down frames then move the surviving human from `(390,330)` to `(390,337.25)`, verifying physical movement after restoration without entering the portal yet.

Source paths: `LaserGunPlayCommand.as:39–60` checks `>=totalFrames-1`; `bombs/Laser.as:33–67` creates the chain and clears owner/game/map during cleanup; file-local `LaserEndCommand.execute` at `LaserPlayCommandChain.as:240–259` uses `_continueTime > 9` before incrementing. Original callback/event order and snapshots corroborate those boundaries; screenshots separately show the beam and its absence after cleanup.

The original SWF bytes and preserved executable remain unchanged. These are local Ruffle observations, not native Adobe Flash parity or phone-feel claims. Only reachable vertical portal approaches were used; fixed map walls were not removed. Broader direction, blocker and replacement coverage remains in the existing weapon recovery records; this report adds the measured portal cases and does not alter accepted adaptations or production gameplay.
