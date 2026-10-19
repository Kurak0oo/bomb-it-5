> Imported Dots record; claims are retained as delivered. See the [integration assessment](../../edition-5-play-observations.md) for verification, missing files, and authority limits. Original relative paths in code spans refer to the [unaltered bundle](../../../../.scratch/edition-5-research/observations/swf-v1.6.1/UNRESOLVED.md).

# Unresolved / caveats ([O] observed, [I] inferred, [U] unknown, [S] source)

1. **Bouncer, magic carpet and heavy bomb are absent from this SWF.** There are no classes, symbols or strings for them in v.1.6.1 [S]. They were never seen in play [O]. Do not add them (other editions only).
2. **Glove = `BombShoesProp` (kick).** No throw/glove class exists. The "glove" help icon maps to the kick prop [S]. Kick was not exercised in the harness [U].
3. **Raw localisation keys on screen**: `C_P1`, `R_ARCADE`, `R_BATTLE ROYALE`, `P_PAUSE`, `C_POWER-UPS`, `1_ENEMIES KILLED`, `L_TOTAL SCORE`, `G_TOTAL SCORE` [O] (zh-fix build). Rebuild decision: show the keys or the cleaned text [U].
4. **Arcade timeout-win bug: CONFIRMED** [O]. Hiding with 0 kills until TIME 0 → TIME'S UP → "LEVEL 1/5 COMPLETE!" (f2910/2920). Whether to keep the bug is a product decision [U]. Only 1 run.
5. **Hearts = retries, not in-round lives** [O]. One hit = level lost. Hearts 3→2→1→GAME OVER. The level restarts with a re-rolled map. A win does not refill hearts. Hearts gained mid-game, if any: [U].
6. **7k7k link is dead, with no alternate**: 7k7k.com/swf/103707.htm embeds no SWF. Both game URLs return a generic listing page (alt/). There is no second hash [O].
7. Fuse is **72 frames observed vs `70` in source** (explodes on the 71st tick). The 1–2 frame offset is placement-tick/render order [I]. Pick one for the rebuild.
8. In first-board row 3 (CinemaStage1) the soft blocks look sparse. Some cells have ±1 uncertainty because of tall sprites [U].
9. Speed unit: XML `speed 1.6` vs HUD "1" vs observed ≈4 px/frame. The mapping is [U].
10. No win cartoon was seen on time-up. A win by killing all enemies was not reached [U].
11. The round clock uses wall time: +1 s per change of `Date.getSeconds()`, polled every 4 frames [S/O]. The harness ran below real time, so in-game seconds per frame there are not representative of 35 fps play.
12. Fewer than 3 reps: pickup ×2, Space-held ×1, Space-repeated ×1, flame measured ×2, victory ×1. Fuse ×6 and chain ×3 are complete.
13. Not probed: kick, other items' effects, AI behaviour and timing, portal pairing and delay, multi-player, Battle Royale mode, weapon stats beyond the source table [U].
14. OS/browser key auto-repeat was not emulated (one key-down per press). Held-Space behaviour under real auto-repeat [U].
15. The manual web session contradicts the harness. It believed it was on Easy and timed things with ~10 s tool lag. Use the harness numbers only.
16. Harness frames in the pack are 256-colour quantized (lossy colour). Full-colour originals were not packed (1.3 GB).
