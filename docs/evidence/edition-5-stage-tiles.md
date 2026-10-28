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

Each `<Set>MapData.init` declares the choices: `_loc1_` feeds `_unfixedArr` (soft
blocks), `_loc2_` feeds `_fixedArr` (fixed props).

| Set | fixed choices | soft choices |
| --- | --- | --- |
| BirthdayParty | 1, 2, 3 | 1–8 |
| CandyFactory | 1, 2, 4 | 1–6 |
| Cinema | 1, 3 | 1–4 |
| Zoo | 1, 5 | 1–4 |
| LuxuryStores | 1, 3 | 1–6 |
| MagicLibrary | 1, 2, 4 | 1, 3 |

`MapMaster` reads those as `frame = beginNum - 1 + fixedChoice` and
`frame = beginNum + fixedPropNum - 1 + softChoice`. The recorded layouts store their
own variant numbers, so the pack maps `solid_N` to the consecutive frame
`beginNum - 1 + N` (what `Box.gotoAndStop` would draw) and the two soft slots to the
set's first two soft choices.

## Floors and walls

The floor and the board border are the 576×544 `BackGround_<Set>` image, tiled at 32px.
The pack cuts 32×32 tiles from it: `floor_even` at (32,32), `floor_odd` at (64,32),
`wall` at (0,0). Cinema's background is uniform, which is why its floor slot previously
used a flat `#888` stand-in.

The pipeline's config gained a `source.crop` region for this: it renders one declared
box of a source asset instead of the asset's content bounds.

## Still open for #74

- 64 hat/outfit slots: the art is drawn inside the robot clips (`hatMc`/`bodyMc`), not
  in separate symbols.
- Character action poses, protection blink, portal transit, the five touch controls and
  seven interface panels.
