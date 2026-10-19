> Imported Dots record; claims are retained as delivered. See the [integration assessment](../../../../edition-5-play-observations.md) for verification, missing files, and authority limits. Original relative paths in code spans refer to the [unaltered bundle](../../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/board-transcription.md).

# Visual board transcriptions: alternate HTML5 runtime

These are approximate visual symbol maps, not collision maps and not the publisher SWF. Both maps independently use a 17-column × 15-row lattice suggested by screenshot artwork. Zero-based coordinates: c0–c16, r0–r14. Approximate column anchors x=245+30c; row artwork anchors y=79+30r. Visible playfield is x238–738, y79–505; raised sprites overlap and boundary artwork is clipped. These anchors must not be mistaken for hitboxes.

## First actually observed playable board
003-first-board-or-state.jpg, captured 2026-10-16T20:39:49.960Z, timer173. This is the requested first observed board, not an untouched opening. Visible bombs/effects, moved characters and scores (pink30, orange110, blue0, black0) demonstrate activity. Its motif/layout differs from019. Blue P1 is near(c1,r1), pink near(c15,r1), black near(c15,r11), orange near(c2,r12–13).

```
00 #################
01 #?..P#CCP.PJ#..?#
02 #.J.#JP#CJC#J.#.#
03 #..P.PPPPCC..CP.#
04 #.JP#JPJ##PJJ.JC#
05 #P.S.P.???...S.P#
06 #.J.##P???PJ#.J.#
07 ##C.P.C???..CCP##
08 #P#.JJ.???P#J.#!#
09 #C.S.CPPPP.P.S..#
10 #PJ.J#CJ##P##.J.#
11 #P.PCC..CCP.PPC?#
12 #.#bJJ.JP#P##CJ.#
13 #?..C#CPPCP#.b..#
14 #################
```

## Selected near-opening retry
019-fresh-board-006.jpg, captured 2026-10-16T20:42:13.956Z, timer179; all displayed scores0. No visible bombs or obvious destroyed blocks in this frame, but AI may already have moved. This is expressly not the first observed board and cannot be called fully untouched. Blue P1 near(c1,r1); black AI(c15,r1); yellow/pink AI(c1,r13); orange AI(c15,r13), approximate.

```
00 #################
01 #?.PRP...PPP.R.?#
02 #.JJPJJPRP##.JJ.#
03 #RRJ.JRPJ..J.J..#
04 #JP.S..J#JR.S..##
05 #RR#.JP???.J.JPP#
06 #.JPP..???PR..JP#
07 #RPP#P.???RPJR.R#
08 #RJRPPR???R.P.#P#
09 #..#.#RRPRR#PJPP#
10 #J..S.P###P.S.P##
11 #P.J.JPRJRP#.JPR#
12 #.##P##R.RJ#RJJ?#
13 #?.PRRPR..RPP..?#
14 #################
```

## Legend and confidence
- # = red cylindrical can in019 / red topped cup in003; likely solid, not collision-tested here.
- P = purple/yellow-bow gift; R = pale/red-bow gift; J = orange drink. Likely obstacles; breakability is not proved by appearance. R is absent in003, whose round clusters use C instead.
- C = multicolored round cluster in003, role unknown.
- S = white-topped mouth-like special pedestal, role unknown. 019 has four near(c4,r4),(c12,r4),(c4,r10),(c12,r10);003 has the upper pair near r5 instead. Raised sprites limit exact attribution; do not treat these as validated collision coordinates.
- . = visible floor/no object assigned, not a traversability test.
- ? = occlusion/ambiguous underlying cell. The central cake covers roughly c7–9,r5–8; cells are not inferred from symmetry. Character-covered ambiguous cells also use?.
- b = visible dark bomb; ! = bright effect; neither establishes the underlying cell.

The large central decorated cake is a separate multi-cell visual feature, not an invented set of ordinary solid tiles. Exact obstruction footprint and whether some artwork is decorative are unresolved. Individual rows, especially overlapping tall objects and lower-edge characters, are approximate and should be verified against gameplay before implementation. Machine-readable maps include the same caveats; do not collapse visual symbols into solid/breakable classes as established facts.
