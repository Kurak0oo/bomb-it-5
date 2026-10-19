> Imported Dots supplemental record; assertions are retained as delivered. Read the [integration assessment](../../edition-5-play-observations.md) for confidence, corrections and remaining limits. Source-relative paths in code spans refer to the [unaltered original](../../../../.scratch/edition-5-research/observations/swf-v1.6.1-supplement/CORRECTIONS.md).

# CORRECTIONS to the first SWF evidence pack (REPORT.md / UNRESOLVED.md of 2026-10-16)

Each line gives the old claim, the correction, and the evidence.

1. **Fuse: 72 callbacks by source, not "71st tick + render offset".**
   `zlong/bombit5/bombs/Bomb.as` `takeCount()` (lines 168–191) tests `if (this._time > this._blastTime && !this._isBlast)` **before** `++this._time` (else branch). `_time` starts at 0 (line 147) and `_blastTime = _normalBlastTime = GameConfig.FRAME_RATE * 2` = `Root.GAME_FRAMERATE * 2` = 35×2 = **70** (lines 20, 148). Calls 1–71 increment `_time` to 71, and call **72** sees 71 > 70 and blasts. `takeCount` is in the bomb's `_engineArr` (`resetEngine`, line ~167), which `GameEngine.enterFrameHandle` runs once per ENTER_FRAME through `_bombArr`. **[source, verified 2026-10-17]**
   Observed: the bomb is first visible on frame P (= the first run_frame after the Space KeyDown) and the first blast frame is **P+72** (6/6 runs). This fits 72 callbacks on frames P+1…P+72, i.e. the first callback on the frame after creation **[inferred]**. No render offset is needed. The old wording "explodes on the 71st tick; the 1–2 frame gap is render order" is **withdrawn**.
   Chain detail: `blastHandle` sets `_time = _blastTime + 1` and calls `takeCount()` at once. This fits the observed same-frame chain detonation **[source + observed]**.

2. **"Game logic is purely per-frame" needs qualifying.** Bombs, flames, movement, AI sequencing and pickups run per ENTER_FRAME **[source/observed]**. The **round clock does not**: `Game.countTime` runs from the tween list every 4th engine frame (`GameEngine` `count == 4`) and adds 1 s only when `new Date().getSeconds()` differs from the stored value. It does not accumulate elapsed time, so it **misses seconds during stalls** (at most one tick per poll) and depends on wall-clock pacing. The clips in `play/clips/` are encoded at 35 fps from per-frame captures. They show **frame cadence only**, and their timer digits do **not** reproduce the wall-clock behaviour of the stepped harness. "35 fps = game speed" in the old report should be read as "one video frame = one engine frame".
   `GameEngine.countTimer = new Timer(25)` gets a listener but is never started, so the engine is not timer-driven **[source]**.

3. **Glove identity is AMBIGUOUS. No choice is made.** The old line "Glove = BombShoesProp kick" is **withdrawn**. Two candidates exist in this exact build:
   - **BoxingProp**: help/sprite shows a red boxing glove labelled "BOXING GLOVE". The XML comment is `<!-- 拳头 -->` ("fist"). It is a weapon-class prop. Arcade drop weight 0.01; Battle Royale (KillMode) 0.15.
   - **BombShoesProp**: help shows a white hand with "PUSH THE BOMB". The XML comment is `<!-- 手套 -->` ("glove"). Arcade drop weight 0.1; KillMode 0.
   Which one a design document's "glove" means is a product decision **[unknown]**. Phase-2 play tests (follow-up archive) show acquisition and use of each.

4. **Bouncer, magic carpet and heavy bomb are UNIDENTIFIED, not proven absent.** The old "absent from this SWF" wording (UNRESOLVED #1, REPORT §0) was an inference from name searches only. No class, symbol or string carries those names **[source, name search]**, but a behaviour-level match (e.g. a vehicle prop such as DragonProp/HorseProp/MotoCycleProp/CarProp, or a weapon) was not ruled out. Attributing them to other editions is likewise **unverified**. The phase-2 follow-up maps every item and weapon by behaviour.

5. **Toolchain string.** "rustc 1.9x stable" → **rustc 1.99.1 (58cf8f9c3 2026-10-13), cargo 1.99.1, LLVM 23.1.1**, verified from the binary's `.comment` section. The system `rustc 1.85.1 (4eb161250 2025-03-15)` was NOT used (too old for the workspace). See REPRO.md §1.

6. **Pause latency wording.** "P → PAUSE on the 4th/3rd frame" is pinned down as: KeyDown logged at counter 1856 (acts from run_frame 1857), PAUSE first drawn on frame 1860. The same pattern holds at 4013→4017 and 4047→4051, i.e. visible on the 4th frame after the input boundary **[observed]**.

7. **Missing material** (screens_harness, play/frames, tools/ruffle-probe, Cargo.lock, input log) is delivered in this supplement. See MANIFEST.md.
