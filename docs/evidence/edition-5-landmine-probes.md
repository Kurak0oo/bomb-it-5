# Original landmine lifecycle and its distinct trigger paths

Ten controlled original-SWF cases verify acquisition, replacement, one-use restoration, non-timed arming, owner return, other-actor contact/protection, fixed power two, ordinary placement guards, external bomb chains and menu teardown. A mine is not an ordinary timed bomb: its contact path and inherited BLAST-event path leave different flags and capacity effects. The latter can underflow the original ordinary bomb count and permit an extra ordinary bomb.

## Authority and reproduction

Publisher SWF SHA-256: `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`; pinned Ruffle `45366370ed7d1a59c89aa3cf7b765c7a274407cd`. The seven owner/guard/chain/lifecycle cases use `.scratch/edition-5-research/reference-player-recovery-v2/probe.exe`, SHA-256 `5a7adba2c2781818a418f19f5976bad1917b8c64568fd7b562a7660bdc99bb74`. The three controlled AI-contact cases use `reference-player-recovery-v4/probe.exe`, SHA-256 `9c1dcc316e1344e5061194ba5062abc01396145d89318ea27582058a6bb1ea3c`. Their exact eleven-/thirteen-patch build manifests accompany each run.

[Executable cases](../../tools/reference_player/cases/mines/) enter one-human/three-Normal-AI Arcade/Cinema with original UI input and initial seed 12345. Original methods stop and park existing AI while their already planted bombs and spawn protection finish. Pickups are constructed through allowlisted original constructors and collected by ordinary `GetItemCommand`; positions use original setters/occupancy callbacks and validated empty floor. Human actions and movement use legal Space/cardinal input. Two external triggers use AI1’s original `RobotController.addBomb` explicitly. No raw actor, health, protection, score, weapon or outcome field is written.

For other-actor contact, a stopped AI receives seven explicit `move-step` fixtures, each followed by an ordinary frame. Each fixture invokes its original `RobotController.moveRight` once, preserving model acceleration, collision and later normal occupancy processing. It bypasses listener/brain scheduling and is labeled a controlled callback, **not** a naturally chosen AI route. It does not teleport onto an occupied mine. Position updates are observed before the following bomb-phase contact. The fixture's interruption and actor bounds remain enforced.

```powershell
python tools/replay_reference.py --player .scratch/edition-5-research/reference-player-recovery-v4/probe.exe --case tools/reference_player/cases/mines/other-shield-contact.json --output .scratch/edition-5-research/reference-runs/my-mine --observe --focus --fixtures
python tools/inspect_mine_probe.py .scratch/edition-5-research/reference-runs/my-mine --output .scratch/edition-5-research/my-mine-extract
```

[Durable evidence](reference-2026-10-19/mines/README.md) includes exact cases, acknowledged commands, explicit fixture effects, manifests/build records, native state/checkpoint extracts, event excerpts, complete original collector files and Focus checkpoints at decisive boundaries, actual screenshots and executable evidence assertions. Source hashes/function locators are in [sources.json](reference-2026-10-19/mines/sources.json); [abc-methods.json](reference-2026-10-19/mines/abc-methods.json) records original AVM2 method indices observed at execution. This research changes no Godot behavior.

## Reachability, use and replacement

The embedded edition-5 XML's `ArcadeMode.prop.LandmineProp` has weight `0.01` (line 269); human and AI `propsEated` lists include it. This proves source reachability through the configured weighted drop system, not a guaranteed drop or a one-percent per-block probability. The [pickup probes](edition-5-pickup-probes.md#human-and-ai-acquisition) separately execute paired human/AI mine acquisition. These lifecycle cases use explicit constructors to isolate the later behavior; they do not claim a newly observed random mine drop.

Original `LandmineProp.initWeapon` sets one use and `shootSpeed=0`. `AbstractWeapon.changeStage` installs down/up handlers. Legal Space down immediately changes `currentUseNum` from 0 to 1 and queues `LandminePlayCommand`. The next original robot engine executes that command, removes its empty play clip, constructs `LandmineBomb` at the actor's **current** logical cell, restores movement, removes itself, and restores default ordinary-bomb action because one use is exhausted. Native `model.weapon` becomes null and the handler becomes `RobotController.addBomb`. Holding Space for 20 further frames creates no second mine; key-up invokes the original empty weapon `bombUp`, and another down invokes default placement.

`replacement-down-up` also equips mine → hammer → mine through ordinary collection. The replaced mine's original `AbstractWeapon.dispose` runs; no mine is planted by replacement. The second mine then plants once and exhausts normally. Four initial directional surveys are retained separately under [weapon-survey](reference-2026-10-19/weapon-survey/); the mine's live placement cell does not depend on a projectile trajectory. These new cases establish down/up lifecycle, rather than infer it from those surveys.

Sources: `items/weapons/LandmineProp.as:initWeapon`, `createWeaponPlay`, `bombDown` (63); `AbstractWeapon.as:changeStage` (83), `bombDown` (112), `bombUp`, `dispose` (248); `commands/weapon/LandminePlayCommand.as:execute` (37); `RobotController.as:initWeapon` (48), `initBombHandle`; `RobotView.as:clearWeapon` (188).

## No timed fuse; departure, return and power two

In `owner-return-power`, the human has ordinary power one and a shield. A mine is placed at (1,1) on frame 844. It remains unarmed with `_time=0`, `_blastTime=0`, `_continueTime=0` while its owner stays there through frame 924—already longer than an ordinary bomb's countdown. Original Right input takes the owner out of the cell; `_hasOutLandBomb` first becomes true on 932. It remains armed without detonating through 1039. These sampled waits establish no ordinary timed countdown, not an experiment of infinite duration.

Original Left input returns the owner. Contact on 1053 consumes the shield, leaves the human alive/damage-ineligible, and blasts. An unprotected existing AI at (3,1), two cells from the mine, dies; the human's original `_modePoint` gains 100. The native mine power is **2** although its owner's is **1**. The map rays and actual screenshot corroborate that reach. Cleanup removes the mine and its fire on 1069, its seventeenth `ended` call including the trigger frame. Ordinary `bombNum` stays zero throughout this contact path.

Native display evidence identifies `mine_bomb`, current frame 1 on placement, with script bounds 28.6 × 21.6 pixels. Screenshots show the placed mine, owner departure, retained armed mine and later blast. Display snapshots do not enumerate all native display children or substitute for the native arming latch.

Source: `LandmineBomb.as:blastMode` (46) installs **only `hitReset`**, not `takeCount`; `setBombPow` (51) forces two; `hitReset` (56) tests original map robot occupancy. The first callback that sees the owner absent sets the latch and returns through the `else` branch; contact is evaluated on a later callback. `GameEngine` runs bomb callbacks before robot engines, so a logical entry recorded during a robot engine is normally seen in the next bomb phase. Movement permits mine entry explicitly in `HitMove.as:636`.

## Other-actor contact and protection

The three contact cases place the human's mine at (2,1), park the human safely at (1,3), and walk the existing stopped AI1 from (1,1) with original movement callbacks. Seven callbacks move native x from 213 to 228.9; the final approach checkpoint shows normal map registration in the mine cell while `_continueTime` is still zero. The following original bomb phase triggers contact.

| AI1 state before contact | Trigger frame | Original result | Human `_modePoint` |
| --- | --- | --- | --- |
| Normal, eligible, no shield | 852 | Dead, removed from registered robots | 100 |
| Normal, eligible, one shield | 853 | Shield consumed, normal/alive, `isExist=false` | 0 |
| Original Invincibility active, `isExist=false` | 873 | Still Invincible/alive; mine nevertheless blasts | 100 |

The last row is an original scoring quirk. `hitReset` marks contact for any map occupant, and its manual award tests only no vehicle, no shield and occupant ≠ owner. It does **not** check damage eligibility/state before awarding. `TryToKillCommandChain.execute` then honors `isExist` and the protected actor survives. Thus this score is not evidence of a kill. Source and traces separate those operations. `isExist` alone is never treated as liveness; the unprotected dead actor retains true in its detached record.

All three contact-triggered mines retain `_isBlast=false` while their visible explosion and original cleanup callback are active. This is expected from the actual path: `hitReset` calls `blast()` directly without assigning `_isBlast`. It then removes the bomb handler and the owner's model bomb-array entry, but does not decrement ordinary `bombNum`. Cleanup still occurs via the inherited `ended`. A port that recognizes mine detonation solely through the ordinary `_isBlast` flag would miss this path.

Sources: `LandmineBomb.as:hitReset`; `commands/robot/TryToKillCommandChain.as:execute` (29); `Bomb.as:blast`, `ended` (430); original event call/parent/depth and actor receiver IDs establish the direct-contact versus nested-blast paths.

## External blast, counter underflow and placement guards

`bomb-trigger-unarmed` leaves the owner standing on the unarmed mine; an adjacent original AI1 bomb detonates on 896. `bomb-trigger-armed` first moves the owner away, observes the latch true on 825, then the adjacent AI bomb detonates on 897. **Both mines detonate recursively**, without requiring departure/contact. The inherited BLAST listener sets `_time=1` against `_blastTime=0`, runs ordinary `takeCount`, sets `_isBlast=true`, and decrements their owner's `bombNum` from zero to **−1**. The source's default int fields are real observed zeros, not omitted values.

After the armed mine has cleaned up on checkpoint 917, legal ordinary Space input creates a bomb at (1,3): `bombNum=-1→0`. Another legal placement at (3,1) makes `0→1`. At checkpoint 919 there are **two simultaneous ordinary Bomb objects** although `allowBomb=1`. A third legal attempt on empty (1,2) is then blocked at count one. This is an observed gameplay consequence of the original inherited decrement, not a proposed adaptation or a raw counter edit. The unarmed case independently retains the negative count after cleanup.

Two separate guard cases distinguish capacity from occupancy:

- `capacity-and-occupancy`: mine placement leaves `bombNum=0` and adds the mine to the owner's bomb array. Restored ordinary Space down on that same cell creates nothing because `Map.isEmpty` is false. After walking away, an ordinary bomb is allowed while the mine remains present; count becomes one. A later ordinary attempt at capacity creates no additional ordinary bomb. The mine remains armed after that non-adjacent ordinary bomb cleans up.
- `mine-on-existing-bomb`: while an ordinary bomb already occupies (1,1), count/allow are 1/1. Legal equipped mine action still creates a mine on the **same cell**. There are two map bomb-array entries, while ordinary count stays one. The ordinary bomb later explodes and cleans up, but this colocated unarmed mine remains. Its source explains the difference from an adjacent chain: the ordinary bomb's `hitItem` skips its own stored previous-grid cell, so it does not dispatch BLAST to the second bomb on its own center. This case does not imply all overlapping explosions ignore mines.

Mine action has no `RobotController.addBomb` empty/capacity guard; its placement command directly constructs the mine. Ordinary action has both guards. Mines permit actor movement through them, while still occupying the map bomb array and making ordinary placement nonempty. Those are distinct notions of movement blocking, map occupancy and ordinary capacity.

Sources: `RobotController.as:addBomb` (154), `deleteBomb` (168); `LandmineBomb.as:init`, `hitReset`, `blastMode`; `Bomb.as:blastHandle` (162), `takeCount` (168), `updateBombPos`; `AbstractBomb.as:hitItem` (85), `deleBomb`; `Grid.as:isEmpty` (154); `HitMove.as:636`. The [ordinary chain report](edition-5-chain-overlap-probes.md) establishes the underlying synchronous callback/cleanup mutation separately.

## Pause and teardown

`pause-teardown` places a mine on 823 and observes it armed on 824. Pause checkpoints 834 and 864 retain the same mine, zero countdown/cleanup counters and original paused state; no mine `hitReset` executes between those two paused checkpoints. The original 100-ms pause-entry timer matters: the first paused post-step sample on 828 still includes a mine callback earlier in that frame before pause took effect; the second pause has the same boundary on 873. Do not equate an end-of-frame paused flag with an entirely paused frame. Resume leaves the mine armed. At frame 879 the actual pause-menu click invokes original teardown and `GameEngine.clearEngine`; the main-menu snapshots on 899 and 999 report the old game unavailable. No further mine callback is recorded during that later wait, and screenshots show the menu.

No `LandmineBomb.dispose` invocation was observed on this menu path. The evidence establishes original engine/display teardown and loss of the old projected game, **not** individual object disposal or a garbage-collection deadline. Sources: `Game.as:dispose` (544), `overDisplay`; `GameEngine.as:clearEngine`; `LandmineBomb.as:dispose` (32) is a source-defined method, not an executed claim here.

## Integrity and remaining limits

Implementation cross-check, 2026-10-20 (static source, not another runtime probe):
`AbstractRobot.bombRobotScore` adds both `modePoint += ROBOT_POINT` and
`killNum += 1`. Therefore the manually awarded protected-contact case above
also follows the source kill-counter increment despite survival. The port
preserves that counter quirk; a displayed kill counter is not proof that the
corresponding actor died. The public scheduler/round regression distinguishes
the surviving target, 100-point award and incremented counter.

Each completed event collection has zero dropped records, zero stack overflow and balanced original call/return pairs. The read-only extractor rejects truncated/ambiguous Focus data, duplicate checkpoint names and hash mismatches. Original-method events carry method indices, primitive args, selected depth and process-local receiver IDs; mutation excerpts retain original sequence numbers but may omit ancestors. Full raw collector files at decisive frames and selected raw Focus checkpoints support independent inspection. General observer/fast-call and host Date/getTimer/Tween limits remain in the [instrumentation record](edition-5-reference-events.md); no whole-session determinism or native Adobe Flash equivalence is claimed.

Failed/preliminary attempts remain in ignored raw storage: two contact setup attempts were rejected because a requested actor cell overlapped the human; moving the human first fixed the fixture precondition. Five movement callbacks stopped short of entering the mine; the final cases use seven and record the actual approach/contact boundary. An initial capacity run reused generic capture names and overwrote two checkpoint paths; it is excluded and replaced with unique names and matching manifest hashes. Earlier armed-chain evidence was extended with the subsequent legal capacity consequence and re-curated from its final case.

These cases cover the selected mine criteria in Arcade/Cinema, with normal/shield/Invincible contacts, both armed states for external blast, and owner return. They do not survey every mode, ride contact, all multiple-occupant orderings, a natural random mine drop in these specific lifecycle runs, every possible occupied solid/platform placement, or native-player equivalence. The separate original portal research may add a platform example. Phone controls/testing remain deferred; no release/parity claim follows from this evidence.
