"""4x upscale of SWF bitmaps with Real-ESRGAN x4plus anime 6B on CPU, loaded by spandrel."""
import shutil
import urllib.request

import numpy as np
from PIL import Image

from common import TOOLS, WORK, log, save_png, sha256_file

WEIGHTS = TOOLS / 'weights' / 'RealESRGAN_x4plus_anime_6B.pth'


def ensure_weights(config):
    settings = config['realesrgan']
    if not WEIGHTS.is_file() or sha256_file(WEIGHTS) != settings['sha256']:
        WEIGHTS.parent.mkdir(parents=True, exist_ok=True)
        log.info('Downloading %s', settings['url'])
        with urllib.request.urlopen(settings['url'], timeout=300) as response, open(WEIGHTS, 'wb') as handle:
            shutil.copyfileobj(response, handle)
        if sha256_file(WEIGHTS) != settings['sha256']:
            raise RuntimeError('Real-ESRGAN weights hash mismatch')
    return WEIGHTS


def bleed(rgba):
    """Spread opaque colours into transparent pixels so upscaling does not pull in black edges."""
    rgb = rgba[..., :3].astype(np.float64)
    known = rgba[..., 3] > 0
    if known.all() or not known.any():
        return rgba[..., :3]
    for _ in range(16):
        if known.all():
            break
        total = np.zeros_like(rgb)
        weight = np.zeros(known.shape)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            shifted_known = np.roll(known, (dy, dx), (0, 1))
            total += np.roll(rgb, (dy, dx), (0, 1)) * shifted_known[..., None]
            weight += shifted_known
        grow = ~known & (weight > 0)
        rgb[grow] = total[grow] / weight[grow][:, None]
        known = known | grow
    return np.clip(rgb, 0, 255).astype(np.uint8)


def _run(model, rgb, tile, overlap):
    import torch
    height, width = rgb.shape[:2]
    scale = model.scale
    source = torch.from_numpy(rgb.astype(np.float32) / 255.0).permute(2, 0, 1)[None]
    output = torch.zeros(1, 3, height * scale, width * scale)
    step = tile - 2 * overlap
    with torch.inference_mode():
        for y in range(0, height, step):
            for x in range(0, width, step):
                y0, x0 = max(0, y - overlap), max(0, x - overlap)
                y1, x1 = min(height, y + step + overlap), min(width, x + step + overlap)
                result = model.model(source[:, :, y0:y1, x0:x1])
                # Keep only the tile's own region, dropping the overlap margin.
                ty, tx = (y - y0) * scale, (x - x0) * scale
                th, tw = (min(height, y + step) - y) * scale, (min(width, x + step) - x) * scale
                output[:, :, y * scale:y * scale + th, x * scale:x * scale + tw] = result[:, :, ty:ty + th, tx:tx + tw]
    return (output[0].permute(1, 2, 0).clamp(0, 1).numpy() * 255).round().astype(np.uint8)


def upscale_all(bitmaps, config, jobs):
    """Upscale each bitmap once; cached by asset hash. Returns {key: path}."""
    folder = WORK / 'upscaled'
    results, pending = {}, []
    for asset in bitmaps:
        target = folder / f'{asset["hash"][:16]}.png'
        results[asset['key']] = target
        if not target.is_file():
            pending.append((asset, target))
    if not pending:
        return results, []
    import spandrel
    import torch
    torch.set_num_threads(max(1, jobs))
    model = spandrel.ModelLoader().load_from_file(str(ensure_weights(config))).eval()
    tile, overlap = config['realesrgan']['tile'], config['realesrgan']['overlap']
    failures = []
    for number, (asset, target) in enumerate(pending, 1):
        try:
            rgba = np.array(Image.open(asset['frames'][0]).convert('RGBA'))
            rgb = _run(model, bleed(rgba), tile, overlap)
            alpha = rgba[..., 3]
            if (alpha < 255).any():
                alpha = _run(model, np.repeat(alpha[..., None], 3, -1), tile, overlap).mean(-1).round().astype(np.uint8)
            else:
                alpha = np.full(rgb.shape[:2], 255, np.uint8)
            save_png(target, np.dstack([rgb, alpha]))
            log.info('Upscaled %d/%d %s %s -> %s', number, len(pending), asset['key'], rgba.shape[1::-1], rgb.shape[1::-1])
        except Exception as error:
            failures.append({'id': asset['key'], 'stage': 'upscale', 'error': repr(error)})
            log.error('Upscale failed for %s: %r', asset['key'], error)
            results.pop(asset['key'], None)
    return results, failures
