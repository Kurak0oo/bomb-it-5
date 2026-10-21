"""Master and per-asset palettes, the editable target palette and palette mapping."""
from collections import Counter
import json
import re

import numpy as np
from PIL import Image

from common import (EXPORT, PALETTE, TARGET_PALETTE, WORK, hex_to_rgb, log, rgb_to_hex, rgb_to_lab, shift_colours,
                    write_json)

COLOUR = re.compile(r'(?:fill|stroke|stop-color)="(#[0-9a-fA-F]{6}|#[0-9a-fA-F]{3})"')


def svg_colours(texts):
    counts = Counter()
    for text in texts:
        counts.update(c.lower() for c in COLOUR.findall(text))
    return counts


def merge(counts, delta_e, limit):
    """Greedy clustering in Lab: frequent colours absorb near neighbours."""
    clusters = []
    for colour, count in counts.most_common():
        lab = rgb_to_lab(hex_to_rgb(colour))
        for cluster in clusters:
            if np.linalg.norm(cluster['lab'] - lab) < delta_e:
                cluster['count'] += count
                break
        else:
            clusters.append({'hex': colour, 'count': count, 'lab': lab})
    clusters.sort(key=lambda c: -c['count'])
    return [{'hex': c['hex'], 'count': int(c['count'])} for c in clusters[:limit]]


def bitmap_colours(path, limit):
    pixels = np.array(Image.open(path).convert('RGBA'))
    opaque = pixels[pixels[..., 3] > 32][:, :3]
    if opaque.size == 0:
        return []
    strip = Image.fromarray(opaque.reshape(1, -1, 3).astype(np.uint8), 'RGB')
    quantised = strip.quantize(colors=limit, method=Image.Quantize.MEDIANCUT)
    palette = quantised.getpalette()[:limit * 3]
    counts = Counter(np.array(quantised).ravel().tolist())
    return [{'hex': rgb_to_hex(palette[i * 3:i * 3 + 3]), 'count': int(n)} for i, n in counts.most_common()]


def build(assets, config):
    settings = config['palette']
    shapes = [p.read_text(encoding='utf-8') for p in sorted((EXPORT / 'shapes').glob('*.svg'))]
    counts = svg_colours(shapes)
    master = merge(counts, settings['merge_delta_e'], settings['master_size'])
    write_json(PALETTE, {'source': 'fill, stroke and gradient stop colours of every exported vector shape',
                         'unique_colours': len(counts), 'merge_delta_e': settings['merge_delta_e'], 'master': master})
    if not TARGET_PALETTE.is_file():
        write_json(TARGET_PALETTE, {
            'note': 'Edit "to" to remap every pixel nearest a master colour. Identical from/to means no remap.',
            'colors': [{'from': c['hex'], 'to': c['hex']} for c in master]})
    folder = WORK / 'palettes'
    for asset in assets:
        if asset['type'] == 'bitmap':
            colours = bitmap_colours(asset['frames'][0], settings['bitmap_colors'])
        else:
            texts = [open(f, encoding='utf-8').read() for f in asset['frames'][:24]]
            colours = merge(svg_colours(texts), settings['asset_merge_delta_e'], settings['asset_max'])
        write_json(folder / f'{asset["key"]}.json', {'key': asset['key'], 'colors': colours})
    log.info('Palette: %d unique vector colours -> %d master; %d asset palettes', len(counts), len(master), len(assets))
    return master


def load_asset(key):
    return json.loads((WORK / 'palettes' / f'{key}.json').read_text())['colors']


def target_mapping():
    data = json.loads(TARGET_PALETTE.read_text())
    sources = np.array([hex_to_rgb(c['from']) for c in data['colors']], dtype=np.float64)
    targets = np.array([hex_to_rgb(c['to']) for c in data['colors']], dtype=np.float64)
    return sources, targets


def remap(rgb, strength, mapping):
    """Move each colour by its nearest master colour's edit (to - from)."""
    sources, targets = mapping
    delta = targets - sources
    if strength == 0 or not delta.any():
        return np.asarray(rgb, dtype=np.float64)
    nearest = nearest_index(rgb, sources)
    return np.clip(np.asarray(rgb, dtype=np.float64) + strength * delta[nearest], 0, 255)


_CUBE_LAB = None
_TABLES = {}


def _table(palette):
    global _CUBE_LAB
    key = np.asarray(palette, dtype=np.float64).tobytes()
    if key not in _TABLES:
        if _CUBE_LAB is None:
            grid = (np.arange(32) * 8 + 4).astype(np.float64)
            _CUBE_LAB = rgb_to_lab(np.stack(np.meshgrid(grid, grid, grid, indexing='ij'), -1).reshape(-1, 3))
        palette_lab = rgb_to_lab(palette)
        table = np.empty(len(_CUBE_LAB), dtype=np.int32)
        for start in range(0, len(_CUBE_LAB), 4096):
            block = _CUBE_LAB[start:start + 4096]
            table[start:start + 4096] = ((block[:, None, :] - palette_lab[None]) ** 2).sum(-1).argmin(1)
        if len(_TABLES) > 64:
            _TABLES.clear()
        _TABLES[key] = table
    return _TABLES[key]


def nearest_index(rgb, palette):
    """Nearest palette entry in Lab via a 32^3 lookup table; works for any (..., 3) array."""
    table = _table(palette)
    index = np.clip(np.asarray(rgb), 0, 255).astype(np.int32) >> 3
    return table[(index[..., 0] << 10) | (index[..., 1] << 5) | index[..., 2]]


def asset_target(colours, params, mapping):
    """The palette a candidate snaps to: the asset's own colours, remapped and shifted."""
    rgb = np.array([hex_to_rgb(c['hex']) for c in colours], dtype=np.float64)
    if rgb.size == 0:
        return rgb.reshape(0, 3)
    rgb = remap(rgb, params.get('remap_strength', 1.0), mapping)
    return shift_colours(rgb, params)
