# Art pipeline

Batch tool that turns artwork from the edition 5 SWF into lightly modified
**candidate art** for the Art Workbench's 89 named slots. It never applies
anything: it does not write `assets/skins/active.json` or `assets/skins/imports/`.
Review every candidate yourself, then import the ones you choose in the workbench
with **Replace image…** ([ADR 0006](../../docs/adr/0006-swf-derived-candidate-art.md)).

## Run

```
python tools/art_pipeline/run.py [--swf PATH] [--only TOKENS] [--resume] [--jobs N] [--no-zip]
```

- `--swf`: the SWF to use. Without it the tool looks for
  `.scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf`, then `research/*.swf`,
  and stops if none exists. It never downloads the game. A different input is
  copied to the canonical path; a hash other than the recorded publisher build is
  warned about.
- `--only`: comma-separated filters: `slots`, `assets`, `mapped`, `unmapped`, a
  slot id or prefix (`actor.human`, `board.`), an asset key or name substring
  (`_r0_Down`, `bitmap_97`), or a type (`bitmap`, `sprite`, `shape`).
- `--resume`: skip jobs whose candidate already matches the current inputs and
  settings. Every stage is deterministic and idempotent; failures are logged and
  the batch continues.

Requirements: Python 3.11+, `numpy pillow resvg-py vtracer spandrel torch`
(`cairosvg` is a rendering fallback). Java is found or installed (apt, then a
Temurin JRE from GitHub). JPEXS FFDec 26.3.0 and the Real-ESRGAN anime 6B weights
are downloaded from their GitHub releases into `.scratch/tools/` and hash-checked.

## Stages

1. **Extract**: FFDec exports shapes and sprite frames as SVG, bitmaps as PNG and
   the symbol-class table into `.scratch/swf-export/`, once per SWF hash. If Java
   cannot run, `swf_fallback.py` exports shapes (solid, gradient and bitmap
   fills) and bitmaps; sprite timelines (all characters and animations), morph
   shapes and exact gradient strokes are then missed and listed in `summary.json`.
2. **Manifest** (`manifest.csv`): one row per kept asset with its slot guess.
   Tiny fragments, empty symbols and content-hash duplicates are skipped (slot
   sources are always kept). Slot sources come from `config.json`, grounded in the
   AS3 (`_propNum` pickup frames, `_bombMc` clips, `Art_Portal_<id>`, `_brick5`
   frames) and the evidence records. Assets nothing references are `unmapped`.
3. **Palette**: `palette.json` is the 64-colour master palette clustered from every
   vector fill, stroke and gradient stop. Per-asset palettes are in
   `.scratch/art_pipeline/palettes/` and copied into each candidate.
4. **Render**: vectors render at 4x with resvg, cropped to their content.
5. **Modify** (CPU, deterministic, per slot in `config.json`): `hue_shift_deg`,
   `saturation_scale`, `value_scale`, `outline_scale` (SVG stroke widths; dark
   linework for bitmaps), `remap_strength` with the editable
   `target_palette.json` (change a `to` colour to recolour everything nearest its
   `from`), and an img2img hook (below). `modify_by_prefix` and a slot's own
   `modify` entry override the defaults.
6. **Upscale**: bitmaps only, 4x with Real-ESRGAN x4plus anime 6B through
   spandrel on CPU. Bitmaps embedded inside vector art are rendered, not upscaled.
7. **Cleanup**: pixels snap to the job's target palette (its own area-weighted
   colours, remapped and shifted; alpha kept), are re-traced with vtracer in
   colour mode and render at the slot size. Colour comes from the trace; alpha
   (glows, shadows, edges) from the snapped raster. Sheets follow the workbench:
   a strip, or four rows facing Down, Right, Up, Left.
8. **Review**: `candidates/` holds, per slot (`slots/<slot>/`) and per asset
   (`assets/<key>/`): `candidate.png` (import this), `before.png`, `after.png`,
   `diff.png`, traced `vectors/`, `palette.json` and `meta.json` (change %, frames
   across/rows for the workbench). `candidates/review.html` shows original,
   candidate and difference with slot/type filters and the over-15% flag.
   `candidates.zip` packs the folder; `candidates-slots.zip` holds only the slot
   candidates and their review page, a much smaller download.

Change % is the mean premultiplied RGB-or-alpha difference over visible pixels of
the preview. Defaults (hue 12°, saturation ×1.15, outline ×1.2) put characters
near 10%; greys and glassy pickups change less because a hue shift barely moves them.

### img2img hook

Set `img2img.export_inputs` to write the 4x working frames to
`.scratch/art_pipeline/img2img_inputs/<job folder>/<asset>__f<frame>.png`. Run them
through ComfyUI, Krita or another tool, save results with the same relative names
under the folder named by `img2img.dir`, and run again. Results are resized onto
the frame, blended by `img2img.strength`, keep the original alpha and still pass
through palette snapping and vectorisation.

## Character model sheet

```
python tools/art_pipeline/character_sheet.py --robot 0
```

Writes two images per robot (0 is the blue default human) into the ignored
`candidates/character_sheets/r<N>/` folder. It needs the export from a previous
`run.py`.

- `sheet.png`: character-select key art, front/right/back/left turnaround, HUD
  portrait, in-game faces, every outfit (`bodyMc` frame) and every hat or
  accessory (`hatMc` frame), walk and defeat keyframes, the four rides, colour
  swatches and an in-game size reference.
- `wardrobe.png`: one row per outfit and per hat, each worn in all four facings
  and on all four rides at one scale.

The robots have no expression clips; faces change only within animations (the
walk blink, the select clip, the charred defeat), so the faces panel shows those.
`roleHead` has no head for some robots; the portrait then crops the front pose.
The blue robot's front sprite has no hat clip, so its hats show only on the other
facings and rides, as in the game.

Outfits: `RobotView.as` stops the innermost `bodyMc` on clothID + 1 and `hatMc` on
hatID + 1, but FFDec lets them advance with the parent timeline, so raw exported
walk frames change clothes every few frames. `clips.py` pins both to frame 1 (the
default outfit) for the sheet and for every pipeline render. Pipeline version 2
includes the pin, so `--resume` regenerates candidates made before it.

## Notes

- Character slots use robots by colour (human `_r0`, ruby `_r1`, mint `_r6`, gold
  `_r3`). The recorded Cinema roster is `_r0` with AI `_r5`, `_r3`, `_r4`; edit the
  slot sources to switch. Every robot also has asset candidates.
- `Art_Portal_2` is blue in the SWF, though the slot is named purple.
- 18 slots have no SWF source: action poses, protection blink and portal transit
  overlays, the five touch controls, and the screen frame, HUD panels and menu
  buttons. The end cartoons are full-screen clips squeezed into 64x64 outcome slots.
- Never commit the SWF, `.scratch/`, `candidates/` or the zips.
