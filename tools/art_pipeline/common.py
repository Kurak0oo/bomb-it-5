"""Shared paths, configuration, logging and colour helpers for the art pipeline."""
from pathlib import Path
import hashlib
import json
import logging
import os
import re

import numpy as np

PIPELINE_VERSION = 2  # 2: outfit/hat clips pinned to the default frame
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SCRATCH = ROOT / '.scratch'
CANONICAL_SWF = SCRATCH / 'edition-5-research' / 'agame-bomb-it-5-zh-fix.swf'
RECORDED_SWF_SHA256 = '718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2'
EXPORT = SCRATCH / 'swf-export'
TOOLS = SCRATCH / 'tools'
WORK = SCRATCH / 'art_pipeline'
CANDIDATES = ROOT / 'candidates'
CONFIG = HERE / 'config.json'
MANIFEST = HERE / 'manifest.csv'
PALETTE = HERE / 'palette.json'
TARGET_PALETTE = HERE / 'target_palette.json'
# The pipeline must never write the game's applied art.
FORBIDDEN = [ROOT / 'assets' / 'skins' / 'active.json', ROOT / 'assets' / 'skins' / 'imports']

log = logging.getLogger('art_pipeline')


def setup_logging():
    WORK.mkdir(parents=True, exist_ok=True)
    if log.handlers:
        return
    log.setLevel(logging.INFO)
    form = logging.Formatter('%(asctime)s %(levelname)s %(message)s', '%H:%M:%S')
    for handler in (logging.StreamHandler(), logging.FileHandler(WORK / 'run.log', encoding='utf-8')):
        handler.setFormatter(form)
        log.addHandler(handler)


def load_config():
    return json.loads(CONFIG.read_text(encoding='utf-8'))


def modify_params(config, slot):
    """Defaults, then every matching slot-prefix override, then the slot's own entry."""
    params = dict(config['modify'])
    for prefix, values in sorted(config.get('modify_by_prefix', {}).items(), key=lambda item: len(item[0])):
        if slot and slot.startswith(prefix):
            params.update(values)
    if slot in config.get('slots', {}):
        params.update(config['slots'][slot].get('modify', {}))
    return params


def guard_output(path):
    resolved = Path(path).resolve()
    for forbidden in FORBIDDEN:
        if resolved == forbidden.resolve() or forbidden.resolve() in resolved.parents:
            raise RuntimeError(f'Refusing to write applied game art: {resolved}')
    return resolved


def write_text(path, text):
    path = guard_output(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(text, encoding='utf-8')
    os.replace(temporary, path)


def write_json(path, value):
    write_text(path, json.dumps(value, indent=1, sort_keys=True) + '\n')


def save_png(path, array):
    from PIL import Image
    path = guard_output(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.tmp.png')
    Image.fromarray(np.ascontiguousarray(array), 'RGBA').save(temporary, optimize=False)
    os.replace(temporary, path)


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as handle:
        for block in iter(lambda: handle.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


def stable_hash(value):
    return sha256_bytes(json.dumps(value, sort_keys=True).encode())[:16]


def safe_name(text):
    return re.sub(r'[^A-Za-z0-9_.-]+', '_', text).strip('_')[:80] or 'unnamed'


def hex_to_rgb(text):
    text = text.lstrip('#')
    if len(text) == 3:
        text = ''.join(c * 2 for c in text)
    return tuple(int(text[i:i + 2], 16) for i in (0, 2, 4))


def rgb_to_hex(rgb):
    return '#%02x%02x%02x' % tuple(int(v) for v in rgb)


def rgb_to_lab(rgb):
    """sRGB (0-255, ...x3) to CIE Lab (D65)."""
    c = np.asarray(rgb, dtype=np.float64) / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    xyz = c @ np.array([[0.4124, 0.2126, 0.0193], [0.3576, 0.7152, 0.1192], [0.1805, 0.0722, 0.9505]])
    xyz /= np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def rgb_to_hsv(rgb):
    rgb = np.asarray(rgb, dtype=np.float64) / 255.0
    high, low = rgb.max(-1), rgb.min(-1)
    delta = high - low
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    safe = np.where(delta == 0, 1, delta)
    hue = np.where(high == r, ((g - b) / safe) % 6, np.where(high == g, (b - r) / safe + 2, (r - g) / safe + 4))
    hue = np.where(delta == 0, 0, hue) / 6.0
    saturation = np.where(high == 0, 0, delta / np.where(high == 0, 1, high))
    return np.stack([hue, saturation, high], -1)


def hsv_to_rgb(hsv):
    h, s, v = hsv[..., 0] % 1.0, np.clip(hsv[..., 1], 0, 1), np.clip(hsv[..., 2], 0, 1)
    i = np.floor(h * 6).astype(int) % 6
    f = h * 6 - np.floor(h * 6)
    p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    choices = [np.stack(x, -1) for x in ((v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q))]
    out = np.zeros(h.shape + (3,))
    for k in range(6):
        out = np.where((i == k)[..., None], choices[k], out)
    return np.clip(np.round(out * 255), 0, 255)


def shift_colours(rgb, params):
    """The deterministic hue/saturation/value change shared by palettes and pixels."""
    hue, sat, val = params.get('hue_shift_deg', 0), params.get('saturation_scale', 1), params.get('value_scale', 1)
    if hue == 0 and sat == 1 and val == 1:
        return np.asarray(rgb, dtype=np.float64)
    hsv = rgb_to_hsv(rgb)
    hsv[..., 0] += hue / 360.0
    hsv[..., 1] *= sat
    hsv[..., 2] *= val
    return hsv_to_rgb(hsv)
