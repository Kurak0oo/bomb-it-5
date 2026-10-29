# Stage-set tile art: brick frames and map cells

Recovered from the decompiled ActionScript of the authority build
(`agame-bomb-it-5-zh-fix.swf`, sha256 `718c04c7…0408a2`) on 2026-10-28, while working
#74. Source files were exported with FFDec 26.3.0 (`-export script`) and are not
committed.

## One clip holds every set's tiles

`zlong.bombit5.maps.Box` draws a board cell from a single clip:

```actionscript
private static const _BRICK:Class = getDefinitionByName("_brick5") as Class;
...
var _loc2_:MovieClip = MovieClip(new _BRICK());
_loc2_.gotoAndStop(param1);          // param1 = the cell's item number
```

`_SKIP_FRAMES = [24,61,62,63,64,72,86,96,112,113]` marks frames that are not tile art.

Each set declares the first frame of its own range in
`zlong.bombit5.maps.mapData.<Set>`:

| Set | `beginNum` | `fixedPropNum` | `unfixedPropNum` | background |
| --- | --- | --- | --- | --- |
| BirthdayParty | 1 | 4 | 8 | `BackGround_BirthdayParty` |
| CandyFactory | 25 | 4 | 6 | `BackGround_CandyFactory` |
| Cinema | 49 | 4 | 4 | `BackGround_Cinema` |
| Zoo | 73 | 7 | 4 | `BackGround_Zoo` |
| LuxuryStores | 97 | 4 | 6 | `BackGround_LuxuryStores` |
| MagicLibrary | 121 | 5 | 3 | `BackGround_MagicLibrary` |

Ranges are 24 frames apart, so `beginNum + 23` ends each set.

## Which frame a cell uses

`zlong.bombit5.maps.MapMaster.createRow` decides the frame per cell:

- `beginNum + 23`: the outer wall (cell value 3, and value 2 with the box hidden).
- `beginNum - 1 + getFixedBoxMc(row, column)`: a placed fixed prop, i.e. frames
  `beginNum … beginNum + fixedPropNum - 1`; `-1` picks randomly from that run.
- Soft blocks: `_unfixedFrameArr[...] + beginNum + fixedPropNum - 1`, or, when the
  layout marks an area 1–4, `setRadomNum(2, beginNum + 3, 0)`, `+5`, `+7`, `+9` — two
  variants per area at frames `beginNum+3/+4`, `+5/+6`, `+7/+8`, `+9/+10`.
- Empty cells get no box; the floor is the 540×540 `BackGround_<Set>` bitmap that
  `AbstractMapSet.init` draws beneath the grid, not a brick frame.

So the per-set tile art is: 2 floor tones hidden in the background bitmap, one wall
frame, `fixedPropNum` solid/decoration frames, and up to eight soft-block frames in
four area pairs.

## Variant lists per set

Each `<Set>MapData.init` (run once per round, when `Game` builds its `worldSet`) splices
**two distinct** entries, in random order, from a fixed list into `_fixedArr` and from a
soft list into `_unfixedArr` (passed to `MapMaster.unfixedFrameArr`):

| Set | fixed list (`_loc2_`) | frames | soft list (`_loc1_`) | frames |
| --- | --- | --- | --- | --- |
| BirthdayParty | 1, 2, 3 | 1–3 | 1–8 | 5–12 |
| CandyFactory | 1, 2, 4 | 25, 26, 28 | 1–6 | 29–34 |
| Cinema | 1, 3 | 49, 51 | 1–4 | 53–56 |
| Zoo | 1, 5 | 73, 77 | 1–4 | 80–83 |
| LuxuryStores | 1, 3 | 97, 99 | 1–6 | 101–106 |
| MagicLibrary | 1, 2, 4 | 121, 122, 124 | 1, 2, 3 | 126–128 |

`setData` / `setDataByPacMan` then assign each cell:

- `fixedProp_r`: `_fixedArr[int(Math.random() * 2)]`, either of the round's two choices.
- any other `fixedProp_<n>`: `_fixedArr[0]`. **The layout's own number is never read**
  (`split("_")[1]` is only compared with `"r"`). The outer ring is made of numbered fixed
  props, so it always shows the round's first fixed choice.
- `unfixedProp_r`: a soft candidate; `createRow` draws its frame from
  `_unfixedFrameArr[int(Math.random() * 2)] + beginNum + fixedPropNum - 1`. Areas 1–4
  are never set by these sets (`setUnfixedProb` passes the default area -1).

Frame contents (rendered from the FFDec frame export, 2026-10-29): Magic Library fixed
121 books, 122 pencil cup, 124 mushroom lamp; soft 126 glasses, 127 scroll and quill,
128 witch hat (125 is a coffee cup no layout reaches). Cinema fixed 49 spotlight, 51 red
seat; soft 53 3D glasses, 54 popcorn, 55 drink, 56 clapperboard. Candy Factory fixed 25
and 26 sweet jars, 28 pudding cup; soft 29 candy cane to 34 lollipop.

This matches the reference openings: [Magic Library layout 2](reference-2026-10-21/stage-openings/magic-layout2.png)
shows a lamp ring and lamp pillars (first fixed choice 4), pencil cups on `_r` cells
(second choice 2) and glasses and witch hats as soft blocks (soft choices 1 and 3);
[Candy Factory layout 2](reference-2026-10-21/stage-openings/candy-layout2.png) shows a
pudding ring (choice 4), jars and two soft kinds.

The first #74 mapping read `fixedProp_<n>` as frame `beginNum - 1 + n`, rolled `_r`
cells over 1–7 and used the first two soft frames, so boards showed art the round could
not draw and the ring fell back to a background crop. Corrected on 2026-10-29:
`Layouts.roll` draws the two choices per round, the renderer draws `solid_<choice>` on
every fixed cell including the ring and `soft_<choice>` on soft blocks, and the pack has
one `soft_<n>` slot per soft-list entry.

## Floors

Empty cells get no box; the floor is the `BackGround_<Set>` bitmap that
`AbstractMapSet.init` cuts at 540×540 and draws beneath the grid at 30/32 scale. The pack
cuts 32×32 tiles from it: `floor_even` at (32,32), `floor_odd` at (64,32). The `wall`
slot (a crop at (0,0)) is drawn only where a board has no rolled art.

## Still open for #74

- 64 hat/outfit slots: the art is drawn inside the robot clips (`hatMc`/`bodyMc`), not
  in separate symbols.
- Character action poses, protection blink, portal transit, the five touch controls and
  seven interface panels.
