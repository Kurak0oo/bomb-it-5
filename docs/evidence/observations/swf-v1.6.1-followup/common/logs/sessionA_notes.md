> Imported Dots supplemental record; assertions are retained as delivered. Read the [integration assessment](../../../../edition-5-play-observations.md) for confidence, corrections and remaining limits. Source-relative paths in code spans refer to the [unaltered original](../../../../../../.scratch/edition-5-research/observations/swf-v1.6.1-followup/common/logs/sessionA_notes.md).

fl_r1_held: kd space @844 -> bomb 845, blast 917, flame 917-933 (17f), held until ku @961; one bomb only; (5,1) cactus destroyed; P1 at (4,1)->(2,1)
fl_r2_held: kd space @979 -> bomb 980, blast 1052, flame 1052-1068 (17f); held to ku; one bomb
fl_r3_held: kd space @1114 -> bomb 1115, blast 1187, flame 1187-1203 (17f); held to ku @~1231; one bomb
sp_r1_repeated: kd space @1249 -> bomb visible 1250, blast 1321 (=N+72, one frame EARLIER than held runs N+73), flame 1321-1337 (17f); taps every 4f (18 extra kd) -> no 2nd bomb
sp_r2_repeated: kd space @1405 -> bomb 1406, blast 1478 (N+73), flame 1478-1494 (17f); no 2nd bomb
sp_r3_repeated: kd space @1561 -> bomb 1562, blast 1633 (N+72), flame 1633-1649 (17f); no 2nd bomb. NOTE: 73-runs coincide with other blasts during fuse (for-each splice skip, Tool.safeRemove) [inferred]
pk_r1: walk-over pickup of POWER potion dropped by (1,7) cactus; HUD change (power 1->2, +100) at f1882 (cap pk_r1b). cactus +10 at 1821.
pk_r2 / glove-B: PUSH THE BOMB (white hand bubble, BombShoesProp) at (2,9), picked f1910 (cap pk_r1c) score +100; no HUD counter for it.
kick_r1 (BombShoes use): kd space @1933 -> bomb at (1,9) 1934; P1 up to (1,8); kd down @1944 -> P1 walks into bomb, bomb starts sliding 1946, ~7 px/frame, stops at (1,13) wall ~1961-1965. No Space involved: kick = walking into a bomb. Blast 2025 = N+92 (fuse paused ~19 frames during flight; source Bomb.kickedFly / engineArr.splice(0)). Flame 2025-2041 (17f).
f~2484: green AI died at (4,13) (silhouette), orange score +300 -> killed by the pumpkin AI's bomb [inferred from score]; black AI died earlier (~f2000, by AI)
P1 died ~f2590 at (1,6) by pumpkin AI bomb chain (flames (1,6)-(1,13)); my bomb had been kicked up col 1 to (1,1) (by the pumpkin? it may hold BombShoes) [inferred]. Hearts 3->2 expected.
f4023-4093: 70 frames stepped with realtime 0 (35 frames uncaptured 137 ms, 35 captured 1507 ms) as a capture-speed test. Session A ended at f4093 (level 1 retry, hearts 2, TIME ~122); harness restarted as probe2 (async PNG writer) in /workspace/probe3.
