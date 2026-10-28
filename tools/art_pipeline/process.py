"""Turn one slot or asset job into a candidate: modify at 4x, snap, vectorise, lay out, diff.

A job is a grid of frame references (rows x columns). Every frame in a job is cropped
to the same union content box in its sprite's local coordinates, so animation and
facing rows keep their registration.
"""
import io
import re
import shutil

import numpy as np
from PIL import Image

import palette
import render
from common import (CANDIDATES, PIPELINE_VERSION, WORK, guard_output, rgb_to_hex, save_png, shift_colours,
                    stable_hash, write_json, write_text)

STROKE = re.compile(r'stroke-width="([\d.]+)"')
MAX_WORK_SIDE = 2048
PREVIEW_MAX = 384


class EmptyJob(Exception):
    pass


# ---------------------------------------------------------------- raster helpers

def resize(rgba, size):
    """Premultiplied resize so transparent edges do not darken."""
    if rgba.shape[1::-1] == tuple(size):
        return rgba
    image = Image.fromarray(rgba, 'RGBA').convert('RGBa').resize(tuple(size), Image.LANCZOS)
    return np.array(image.convert('RGBA'))


def grow(mask, radius):
    for _ in range(radius):
        mask = mask | np.roll(mask, 1, 0) | np.roll(mask, -1, 0) | np.roll(mask, 1, 1) | np.roll(mask, -1, 1)
    return mask


def raster_outline(rgba, scale, zoom):
    """Thicken (scale > 1) or thin (< 1) dark linework in a bitmap at the working resolution."""
    radius = round(abs(scale - 1) * zoom)
    if radius == 0:
        return rgba
    rgba = rgba.copy()
    luma = rgba[..., :3].astype(np.float64) @ np.array([0.299, 0.587, 0.114])
    line = (rgba[..., 3] > 128) & (luma < 70)
    if not line.any():
        return rgba
    if scale > 1:
        colour = np.median(rgba[line][:, :3], 0)
        added = grow(line, radius) & ~line & (rgba[..., 3] > 0)
        rgba[added, :3] = colour
    else:
        kept = ~grow(~line, radius) & line
        removed = line & ~kept
        known = ~removed
        for _ in range(radius + 1):
            for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                source = np.roll(known, (dy, dx), (0, 1)) & ~known
                rgba[source, :3] = np.roll(rgba[..., :3], (dy, dx), (0, 1))[source]
                known = known | source
    return rgba


def change(before, after):
    """Percent change (premultiplied RGB or alpha, whichever moved more) over visible pixels."""
    a, b = before.astype(np.float64), after.astype(np.float64)
    pa, pb = a[..., :3] * a[..., 3:] / 255, b[..., :3] * b[..., 3:] / 255
    delta = np.maximum(np.abs(pa - pb).mean(-1), np.abs(a[..., 3] - b[..., 3])) / 255
    mask = (a[..., 3] > 8) | (b[..., 3] > 8)
    if not mask.any():
        return 0.0, 0.0, delta, mask
    return float(delta[mask].mean() * 100), float((delta[mask] > 0.1).mean() * 100), delta, mask


def diff_image(before, delta, mask):
    luma = before[..., :3].astype(np.float64) @ np.array([0.299, 0.587, 0.114]) * before[..., 3] / 255
    grey = 24 + luma * 0.3
    heat = np.clip(delta * 4, 0, 1)
    out = np.dstack([grey + heat * (255 - grey), grey * (1 - heat) + heat * 40, grey * (1 - heat) + heat * 60,
                     np.full(delta.shape, 255.0)])
    out[~mask, :3] = 16
    return out.clip(0, 255).astype(np.uint8)


def sheet(frames, cell, rows, columns):
    canvas = np.zeros((rows * cell[1], columns * cell[0], 4), np.uint8)
    for r in range(rows):
        for c in range(columns):
            frame = frames[r][c][:cell[1], :cell[0]]
            h, w = frame.shape[:2]
            y, x = r * cell[1] + (cell[1] - h) // 2, c * cell[0] + (cell[0] - w) // 2
            canvas[y:y + h, x:x + w] = frame
    return canvas


# ---------------------------------------------------------------- frames

class Frame:
    """One source frame: an SVG file, or a bitmap with its 4x upscale."""

    def __init__(self, asset, number, upscaled):
        self.asset, self.number = asset, number
        self.vector = asset['type'] != 'bitmap'
        self.path = asset['frames'][number - 1]
        self.origin = asset['origin']
        self._text = self._pixels = None
        self.upscaled = upscaled.get(asset['key']) if not self.vector else None

    @property
    def text(self):
        if self._text is None:
            self._text = open(self.path, encoding='utf-8').read()
        return self._text

    @property
    def pixels(self):
        if self._pixels is None:
            self._pixels = np.array(Image.open(self.path).convert('RGBA'))
        return self._pixels

    def box(self):
        """Content bounds in local (registration) coordinates."""
        if self.vector:
            bounds = render.content_box(self.text, (self.asset['width'], self.asset['height']))
        else:
            rows, columns = np.nonzero(self.pixels[..., 3] > 2)
            bounds = None if rows.size == 0 else (columns.min(), rows.min(), columns.max() + 1, rows.max() + 1)
        if bounds is None:
            return None
        ox, oy = self.origin
        return (bounds[0] - ox, bounds[1] - oy, bounds[2] - ox, bounds[3] - oy)

    def render(self, local, zoom, modified_strokes=1.0):
        ox, oy = self.origin
        box = (local[0] + ox, local[1] + oy, local[2], local[3])
        if self.vector:
            text = self.text
            if modified_strokes != 1.0:
                text = STROKE.sub(lambda m: f'stroke-width="{float(m.group(1)) * modified_strokes:.3f}"', text)
            return render.render_box(text, box, zoom)
        return render.bitmap_box(self.pixels, box, zoom)

    def render_upscaled(self, local, zoom):
        """Bitmap at zoom, sampled from the Real-ESRGAN 4x image when available."""
        if self.upscaled is None or not self.upscaled.is_file():
            return self.render(local, zoom)
        big = np.array(Image.open(self.upscaled).convert('RGBA'))
        factor = big.shape[1] / self.pixels.shape[1]
        ox, oy = self.origin
        box = ((local[0] + ox) * factor, (local[1] + oy) * factor, local[2] * factor, local[3] * factor)
        return render.bitmap_box(big, box, zoom / factor)


def vectorise(rgba, settings):
    import vtracer
    buffer = io.BytesIO()
    Image.fromarray(rgba, 'RGBA').save(buffer, 'PNG')
    return vtracer.convert_raw_image_to_svg(buffer.getvalue(), img_format='png', **settings)


def candidate_frame(frame, local, zooms, params, target, mapping, config, img2img_path):
    """Returns before/after arrays at final and preview zooms plus the traced SVG."""
    work_zoom, final_zoom, preview_zoom = zooms
    sizes = {name: (max(1, round(local[2] * z)), max(1, round(local[3] * z)))
             for name, z in (('work', work_zoom), ('final', final_zoom), ('preview', preview_zoom))}
    # Modify at the working (4x) resolution.
    if frame.vector:
        work = frame.render(local, work_zoom, params.get('outline_scale', 1.0))
    else:
        work = raster_outline(frame.render_upscaled(local, work_zoom), params.get('outline_scale', 1.0), work_zoom)
    work = resize(work, sizes['work'])
    visible = work[..., 3] > 0
    rgb = work[..., :3][visible].astype(np.float64)
    rgb = shift_colours(palette.remap(rgb, params.get('remap_strength', 1.0), mapping), params)
    work[..., :3][visible] = rgb.round().astype(np.uint8)
    if img2img_path is not None and img2img_path.is_file():
        external = resize(np.array(Image.open(img2img_path).convert('RGBA')), sizes['work'])
        strength = float(config['img2img'].get('strength', 1.0))
        blended = work[..., :3] * (1 - strength) + external[..., :3] * strength
        work[..., :3] = blended.round().clip(0, 255).astype(np.uint8)
    if params.get('snap', True) and len(target):
        visible = work[..., 3] > 0
        work[..., :3][visible] = target[palette.nearest_index(work[..., :3][visible], target)].round().astype(np.uint8)
    traced = vectorise(work, config['vtracer']) if params.get('vectorize', True) else None
    result = {'svg': traced, 'work': work}
    for name, zoom in (('final', final_zoom), ('preview', preview_zoom)):
        size = sizes[name]
        before = resize(frame.render(local, zoom), size)
        raster = resize(work, size)
        if traced:
            vector = resize(render.render_box(traced, (0, 0) + sizes['work'], zoom / work_zoom), size)
            cover = vector[..., 3:].astype(np.float64) / 255
            rgb = vector[..., :3] * cover + raster[..., :3] * (1 - cover)
            # Colour from the trace; alpha (glows, shadows, antialiasing) from the snapped raster.
            after = np.dstack([rgb.round().clip(0, 255).astype(np.uint8), raster[..., 3]])
        else:
            after = raster
        result['before_' + name], result['after_' + name] = before, after
    return result


# ---------------------------------------------------------------- jobs

def job_target(params, mapping, frames, frame_box, zoom, limit):
    """Snap palette: area-weighted colours of the job's own rendered frames plus declared SVG colours."""
    colours = []
    for key in dict.fromkeys(f.asset['key'] for f in frames):
        colours += palette.load_asset(key)[:16]
    pixels = np.concatenate([f.render(frame_box[(f.asset['key'], f.number)], zoom).reshape(-1, 4) for f in frames[:8]])
    opaque = pixels[pixels[:, 3] > 32][:, :3]
    if opaque.size:
        strip = Image.fromarray(opaque.reshape(1, -1, 3).astype(np.uint8), 'RGB')
        quantised = strip.quantize(colors=limit, method=Image.Quantize.MEDIANCUT)
        used = np.unique(np.array(quantised))
        values = quantised.getpalette()
        colours += [{'hex': rgb_to_hex(values[i * 3:i * 3 + 3]), 'count': 1} for i in used]
    return palette.asset_target(colours, params, mapping), colours


def run(job, config, mapping, upscaled, resume):
    out = CANDIDATES / job['folder']
    guard_output(out)
    params = job['params']
    img2img_dir = config['img2img'].get('dir') or ''
    stamp = stable_hash([PIPELINE_VERSION, job['stamp_input'], params, config['vtracer'], config['render_scale'],
                         {k: config['img2img'].get(k) for k in ('dir', 'strength')}, mapping[1].tolist(),
                         mapping[0].tolist()])
    meta_path = out / 'meta.json'
    if resume and meta_path.is_file():
        import json
        previous = json.loads(meta_path.read_text())
        if previous.get('stamp') == stamp:
            return previous, True
    grid = [[Frame(ref['asset'], ref['frame'], upscaled) for ref in row] for row in job['rows']]
    unique = list({(f.asset['key'], f.number): f for row in grid for f in row}.values())
    found = {(f.asset['key'], f.number): f.box() for f in unique}
    boxes = [b for b in found.values() if b]
    if not boxes:
        raise EmptyJob('no visible pixels')
    union = (min(b[0] for b in boxes), min(b[1] for b in boxes))
    union = union + (max(b[2] for b in boxes) - union[0], max(b[3] for b in boxes) - union[1])
    own = {k: (b[0], b[1], b[2] - b[0], b[3] - b[1]) if b else union for k, b in found.items()}
    largest = max(w * h for _, _, w, h in own.values())
    # Shared registration keeps animation aligned. An unmapped asset whose frames sit far
    # apart on a huge canvas is cropped per frame instead, at one shared scale.
    separate = job['kind'] == 'asset' and union[2] * union[3] > 4 * largest
    frame_box = own if separate else {k: union for k in own}
    span = (max(b[2] for b in frame_box.values()), max(b[3] for b in frame_box.values()))
    if job['cell'] is None:  # Unmapped asset: natural size, scaled and capped.
        scale = min(config['unmapped']['scale'], config['unmapped']['max_side'] / max(span))
        cell = (max(1, round(span[0] * scale)), max(1, round(span[1] * scale)))
    else:
        cell = tuple(int(v * config['output_scale']) for v in job['cell'])
    final_zoom = min(cell[0] / span[0], cell[1] / span[1])
    preview_long = min(max(max(cell), config['preview_cell']), PREVIEW_MAX)
    preview_cell = tuple(max(1, round(v * preview_long / max(cell))) for v in cell)
    preview_zoom = min(preview_cell[0] / span[0], preview_cell[1] / span[1])
    work_zoom = min(config['render_scale'], MAX_WORK_SIDE / max(span))
    target, colours = job_target(params, mapping, unique, frame_box, preview_zoom, config['palette']['job_colors'])
    results = {}
    for frame in unique:
        img2img = None
        if img2img_dir and not params.get('original'):
            from pathlib import Path
            img2img = Path(img2img_dir) / job['folder'] / f'{frame.asset["key"]}__f{frame.number}.png'
        results[(frame.asset['key'], frame.number)] = candidate_frame(
            frame, frame_box[(frame.asset['key'], frame.number)], (work_zoom, final_zoom, preview_zoom), params,
            target, mapping, config, img2img)
    rows, columns = len(grid), max(len(row) for row in grid)
    pick = lambda name: [[results[(f.asset['key'], f.number)][name] for f in row] for row in grid]
    # The original pack keeps the SWF rendering itself, laid out for the slot.
    candidate = sheet(pick('before_final' if params.get('original') else 'after_final'), cell, rows, columns)
    before = sheet(pick('before_preview'), preview_cell, rows, columns)
    after = sheet(pick('after_preview'), preview_cell, rows, columns)
    percent, pixels_changed, delta, mask = change(before, after)
    final_percent = change(sheet(pick('before_final'), cell, rows, columns), candidate)[0]
    if out.exists():
        shutil.rmtree(out)
    save_png(out / 'candidate.png', candidate)
    save_png(out / 'before.png', before)
    save_png(out / 'after.png', after)
    save_png(out / 'diff.png', diff_image(before, delta, mask))
    for (key, number), result in results.items():
        if result['svg']:
            write_text(out / 'vectors' / f'{key}__f{number}.svg', result['svg'])
        if config['img2img'].get('export_inputs'):
            save_png(WORK / 'img2img_inputs' / job['folder'] / f'{key}__f{number}.png', result['work'])
    write_json(out / 'palette.json', {'source': colours, 'target': [rgb_to_hex(c) for c in target]})
    meta = {'aligned': 'per frame' if separate else 'shared registration', 'id': job['id'], 'kind': job['kind'], 'slots': job['slots'], 'folder': job['folder'],
            'sources': job['sources'], 'type': job['type'], 'rows': rows, 'columns': columns,
            'cell': list(cell), 'change_pct': round(percent, 2), 'change_pct_final': round(final_percent, 2),
            'changed_pixels_pct': round(pixels_changed, 2),
            'flag': percent > config['flag_change_pct'], 'params': params, 'stamp': stamp,
            'workbench': {'frames_across': columns, 'rows': rows,
                          'facing_rows': 'Down, Right, Up, Left' if rows == 4 else None}}
    write_json(meta_path, meta)
    return meta, False
