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

## Open questions for #74

- The `_brick5` frames exported by FFDec are nested `<use>` graphs that render as
  near-empty images through plain resvg; the pipeline's own renderer flattens them.
  Rendering the frames for mapping needs that path, not a quick `resvg` call.
- `_SKIP_FRAMES` and `unfixedFrameArr` need to be read per set before the soft-block
  pairs can be named `soft_a`/`soft_b` with confidence.
- The two floor tones must be cut from the background bitmap; the Cinema slot currently
  uses a flat `#888` source, which is why floors look native in a session.
- Hats and outfits (64 slots) live in the robot clips' `hatMc`/`bodyMc` frames, not in
  separate symbols.
