"""Pixel half of the comparison loop: SSIM, regional colour difference and a heatmap.

"Highly alike", not identical: Ruffle and Godot antialias differently, so the score is a
structural similarity over the whole frame plus a check that no region's average colour
is visibly off. Colour difference is CIE76 ΔE on CIELAB (about 2.3 is a just-noticeable
difference).
"""
import numpy as np
from PIL import Image

DEFAULT_THRESHOLDS = {'ssim': 0.98, 'delta_e': 2.0, 'region': 16}


def load(path):
    image = Image.open(path).convert('RGBA')
    background = Image.new('RGBA', image.size, (0, 0, 0, 255))
    return np.asarray(Image.alpha_composite(background, image).convert('RGB'), dtype=np.float64) / 255.0


def _gaussian_kernel(size=11, sigma=1.5):
    x = np.arange(size) - size // 2
    k = np.exp(-(x ** 2) / (2 * sigma ** 2))
    return k / k.sum()


def _blur(channel, kernel):
    pad = len(kernel) // 2
    padded = np.pad(channel, pad, mode='reflect')
    rows = np.apply_along_axis(lambda r: np.convolve(r, kernel, mode='valid'), 1, padded)
    return np.apply_along_axis(lambda c: np.convolve(c, kernel, mode='valid'), 0, rows)


def ssim(a, b):
    """Mean SSIM (Wang et al. 2004, Gaussian 11×11, σ 1.5) on Rec. 601 luma."""
    weights = np.array([0.299, 0.587, 0.114])
    x, y = a @ weights, b @ weights
    kernel = _gaussian_kernel()
    c1, c2 = 0.01 ** 2, 0.03 ** 2
    mx, my = _blur(x, kernel), _blur(y, kernel)
    sxx = _blur(x * x, kernel) - mx * mx
    syy = _blur(y * y, kernel) - my * my
    sxy = _blur(x * y, kernel) - mx * my
    value = ((2 * mx * my + c1) * (2 * sxy + c2)) / ((mx * mx + my * my + c1) * (sxx + syy + c2))
    return float(value.mean())


def to_lab(rgb):
    linear = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124564, 0.3575761, 0.1804375],
                  [0.2126729, 0.7151522, 0.0721750],
                  [0.0193339, 0.1191920, 0.9503041]])
    xyz = linear @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > (6 / 29) ** 3, np.cbrt(xyz), xyz / (3 * (6 / 29) ** 2) + 4 / 29)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], axis=-1)


def region_delta_e(a, b, region):
    """ΔE between the mean colours of each region×region block; returns the block grid."""
    lab_a, lab_b = to_lab(a), to_lab(b)
    h, w = a.shape[:2]
    rows, cols = -(-h // region), -(-w // region)
    grid = np.zeros((rows, cols))
    for r in range(rows):
        for c in range(cols):
            ys, xs = slice(r * region, (r + 1) * region), slice(c * region, (c + 1) * region)
            grid[r, c] = np.linalg.norm(lab_a[ys, xs].reshape(-1, 3).mean(0) - lab_b[ys, xs].reshape(-1, 3).mean(0))
    return grid


def heatmap(a, b, path):
    """Grey reference with per-pixel ΔE in red (full red at ΔE ≥ 10)."""
    per_pixel = np.linalg.norm(to_lab(a) - to_lab(b), axis=-1)
    grey = (a @ np.array([0.299, 0.587, 0.114]))[..., None].repeat(3, -1) * 0.5
    heat = np.clip(per_pixel / 10.0, 0, 1)[..., None]
    out = grey * (1 - heat) + np.array([1.0, 0.0, 0.0]) * heat
    Image.fromarray((out * 255).round().astype(np.uint8)).save(path)


def compare(reference_path, godot_path, heatmap_path, thresholds=None):
    t = dict(DEFAULT_THRESHOLDS, **(thresholds or {}))
    a, b = load(reference_path), load(godot_path)
    if a.shape != b.shape:
        return {'passed': False, 'error': f'size {b.shape[1]}x{b.shape[0]} != {a.shape[1]}x{a.shape[0]}'}
    score = ssim(a, b)
    grid = region_delta_e(a, b, t['region'])
    heatmap(a, b, heatmap_path)
    worst = np.unravel_index(int(grid.argmax()), grid.shape)
    return {'passed': score >= t['ssim'] and float(grid.max()) <= t['delta_e'],
            'ssim': round(score, 5), 'max_region_delta_e': round(float(grid.max()), 3),
            'worst_region': {'x': int(worst[1] * t['region']), 'y': int(worst[0] * t['region']),
                             'size': t['region']},
            'regions_over': int((grid > t['delta_e']).sum()), 'thresholds': t}
