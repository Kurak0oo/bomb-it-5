"""SVG rasterisation (resvg, falling back to cairosvg) with content-box cropping."""
import io
import re

import numpy as np
from PIL import Image

SVG_TAG = re.compile(r'<svg\b[^>]*>', re.S)
SIZE_ATTRIBUTE = re.compile(r'\s(?:width|height|viewBox)="[^"]*"')
PROBE_SIDE = 1024


def _decode(png):
    return np.array(Image.open(io.BytesIO(png)).convert('RGBA'))


def rasterise(svg, zoom):
    try:
        import resvg_py
        return _decode(bytes(resvg_py.svg_to_bytes(svg_string=svg, zoom=zoom)))
    except ImportError:
        import cairosvg
        return _decode(cairosvg.svg2png(bytestring=svg.encode(), scale=zoom))


def crop_svg(svg, box):
    """Re-root the SVG so its viewport is box=(x, y, w, h) in its own pixel units."""
    x, y, w, h = box
    match = SVG_TAG.search(svg)
    tag = SIZE_ATTRIBUTE.sub('', match.group(0))
    tag = tag[:-1].rstrip('/').rstrip() + f' width="{w:.4f}" height="{h:.4f}" viewBox="{x:.4f} {y:.4f} {w:.4f} {h:.4f}">'
    return svg[:match.start()] + tag + svg[match.end():]


def render_box(svg, box, zoom):
    """Render box at zoom; the output is exactly round(w*zoom) x round(h*zoom)."""
    width, height = max(1, round(box[2] * zoom)), max(1, round(box[3] * zoom))
    pixels = rasterise(crop_svg(svg, box), zoom)
    if pixels.shape[:2] != (height, width):
        pixels = np.array(Image.fromarray(pixels).resize((width, height), Image.LANCZOS))
    return pixels


def _bounds(svg, box):
    zoom = min(4.0, PROBE_SIDE / max(box[2], box[3]))
    pixels = render_box(svg, box, zoom)
    alpha = pixels[..., 3].astype(np.float64) * (pixels[..., 3] > 2)
    if not alpha.any():
        return None, zoom
    gap = max(2, round(256 * zoom))
    y0, y1 = _main_run(alpha.sum(1), gap)
    x0, x1 = _main_run(alpha[y0:y1].sum(0), gap)
    return (box[0] + x0 / zoom, box[1] + y0 / zoom, box[0] + x1 / zoom, box[1] + y1 / zoom), zoom


def _main_run(profile, gap):
    """Span of the heaviest group of occupied rows/columns; drops fragments beyond a wide empty gap."""
    occupied = np.nonzero(profile > 0)[0]
    groups, start = [], occupied[0]
    for previous, current in zip(occupied[:-1], occupied[1:]):
        if current - previous > gap:
            groups.append((start, previous + 1))
            start = current
    groups.append((start, occupied[-1] + 1))
    return max(groups, key=lambda g: profile[g[0]:g[1]].sum())


def content_box(svg, size, pad=1.0):
    """Alpha bounds of the drawing in canvas pixels, or None if nothing is visible."""
    width, height = size
    if width <= 0 or height <= 0:
        return None
    bounds, zoom = _bounds(svg, (0, 0, width, height))
    if bounds and zoom < 4.0:  # Large canvases: refine around the coarse bounds.
        slack = 2 / zoom
        coarse = (bounds[0] - slack, bounds[1] - slack, bounds[2] - bounds[0] + 2 * slack, bounds[3] - bounds[1] + 2 * slack)
        bounds = _bounds(svg, coarse)[0] or bounds
    if bounds is None:
        return None
    return (bounds[0] - pad, bounds[1] - pad, bounds[2] + pad, bounds[3] + pad)


def bitmap_box(pixels, box, zoom):
    """Crop/pad a bitmap to box (canvas pixels) and resize by zoom."""
    x, y, w, h = box
    width, height = max(1, round(w * zoom)), max(1, round(h * zoom))
    image = Image.fromarray(pixels)
    # Image.transform maps output pixels back into the source, padding outside with transparency.
    scale = 1.0 / zoom
    result = image.transform((width, height), Image.AFFINE, (scale, 0, x, 0, scale, y), Image.BICUBIC,
                             fillcolor=(0, 0, 0, 0))
    return np.array(result)
