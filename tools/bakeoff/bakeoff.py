"""Render bake-off (checkpoint 2): three ways to get the original's art at N×, side by side.

    python3 tools/bakeoff/bakeoff.py                  # main-menu case, `menu` capture, 3×
    python3 tools/bakeoff/bakeoff.py --capture title

A. Ruffle at N×: the reference player renders the stage at N× (`--scale`). Same renderer
   as the reference, so filters, colour transforms and blends are included.
B. FFDec → SVG → resvg: every visible shape/text from the golden display list, exported
   by FFDec as SVG, placed by its stage matrix in one SVG document, rasterised once at N×.
C. FFDec PNG: the same pieces exported by FFDec as PNG at N×, pasted by stage matrix
   (an exact paste when the piece is unscaled and unrotated, otherwise resampled again).

B and C rebuild the frame from separate pieces, which is also how a Godot scene would be
built. What they cannot rebuild is listed under `not_rebuilt` in scores.json (filters,
masks, blend modes, morph shapes, missing exports): those need baking or shaders.

Outputs go to .scratch/bakeoff/<case>-<capture>/ (original art: never commit them):
A-ruffle.png, B-ffdec-resvg.png, C-ffdec-png.png at N×, scores.json, and sheet.png.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE.parent / 'compare'))
sys.path.insert(0, str(HERE.parent))
import pixels  # noqa: E402

FFDEC_VERSION = '26.3.0'
FFDEC_URL = f'https://github.com/jindrapetrik/jpexs-decompiler/releases/download/version{FFDEC_VERSION}/ffdec_{FFDEC_VERSION}.zip'
FFDEC_SHA256 = '35f4930eb7c380afe66f2117f90b006deac0631473ad7500bb39c78f68645ecd'
STAGE = (700, 510)
PIECE_KINDS = ('graphic', 'text', 'bitmap', 'morph_shape')


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


# ---------------------------------------------------------------- FFDec

def ensure_ffdec():
    folder = ROOT / '.scratch' / 'tools' / 'ffdec'
    jar = folder / 'ffdec.jar'
    if jar.is_file():
        return jar
    if not shutil.which('java'):
        raise SystemExit('FFDec needs Java: on macOS run `brew install openjdk` and follow its PATH note')
    import urllib.request
    import zipfile
    folder.mkdir(parents=True, exist_ok=True)
    archive = folder.parent / f'ffdec_{FFDEC_VERSION}.zip'
    if not archive.is_file():
        print(f'downloading FFDec {FFDEC_VERSION}')
        urllib.request.urlretrieve(FFDEC_URL, archive)
    if sha256(archive) != FFDEC_SHA256:
        archive.unlink()
        raise SystemExit('FFDec download has the wrong checksum')
    with zipfile.ZipFile(archive) as z:
        z.extractall(folder)
    return jar


def ffdec_export(swf, scale, out):
    """Shapes and texts as SVG (1×) and PNG (N×), images as PNG; cached per SWF and scale."""
    stamp = out / 'stamp.json'
    want = {'swf': sha256(swf), 'scale': scale, 'ffdec': FFDEC_VERSION}
    if stamp.is_file() and json.loads(stamp.read_text()) == want:
        return
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    jar = ensure_ffdec()
    runs = [('shape:svg,text:svg,morphshape:svg', '1', 'svg', 'shape,text,morphshape'),
            ('shape:png,text:png,morphshape:png', str(scale), 'png', 'shape,text,morphshape'),
            ('image:png_gif_jpeg', '1', 'image', 'image')]
    for formats, zoom, folder, items in runs:
        print(f'FFDec export: {items} as {folder} (zoom {zoom})')
        subprocess.run(['java', '-Xmx4g', '-jar', str(jar), '-format', formats, '-zoom', zoom,
                        '-export', items, str(out / folder), str(swf)],
                       check=True, capture_output=True, timeout=3600)
    stamp.write_text(json.dumps(want))


def exported(out, folder, character_id, suffix):
    """FFDec names files `<id>.<ext>` or `<id>_<name>.<ext>`, possibly under a type folder."""
    base = out / folder
    for pattern in (f'{character_id}.{suffix}', f'{character_id}_*.{suffix}'):
        hits = sorted(base.rglob(pattern))
        if hits:
            return hits[0]
    frames = sorted(base.rglob(f'{character_id}/*.{suffix}'))  # morph shapes: one file per ratio
    return frames[0] if frames else None


SVG_OFFSET = re.compile(r'<g transform="matrix\(1\.0, 0\.0, 0\.0, 1\.0, (-?[\d.]+), (-?[\d.]+)\)">')


def svg_offset(svg_text):
    """FFDec wraps a piece in translate(-x_min, -y_min) of its bounds; return (x_min, y_min)."""
    match = SVG_OFFSET.search(svg_text)
    return (-float(match.group(1)), -float(match.group(2))) if match else (0.0, 0.0)


def swf_header(swf):
    """Movie size (header RECT, twips) and stage colour (SetBackgroundColor, tag 9)."""
    import lzma
    import zlib
    data = Path(swf).read_bytes()
    signature, body = data[:3], data[8:]
    if signature == b'CWS':
        body = zlib.decompress(body)
    elif signature == b'ZWS':  # LZMA: 5 property bytes at offset 12, raw stream from 17
        props = lzma._decode_filter_properties(lzma.FILTER_LZMA1, data[12:17])
        body = lzma.LZMADecompressor(lzma.FORMAT_RAW, filters=[dict(props, id=lzma.FILTER_LZMA1)]).decompress(data[17:])
    bits = body[0] >> 3
    value = int.from_bytes(body[:(5 + 4 * bits + 7) // 8], 'big')
    total = ((5 + 4 * bits + 7) // 8) * 8
    fields = [(value >> (total - 5 - bits * (i + 1))) & ((1 << bits) - 1) for i in range(4)]
    fields = [f - (1 << bits) if f >> (bits - 1) else f for f in fields]
    size = ((fields[1] - fields[0]) / 20, (fields[3] - fields[2]) / 20)
    pos = (5 + 4 * bits + 7) // 8 + 4  # RECT, then frame rate and frame count
    while pos + 2 <= len(body):
        header = int.from_bytes(body[pos:pos + 2], 'little')
        code, length = header >> 6, header & 0x3F
        pos += 2
        if length == 0x3F:
            length = int.from_bytes(body[pos:pos + 4], 'little')
            pos += 4
        if code == 9:
            return size, tuple(body[pos:pos + 3]) + (255,)
        if code == 0:
            break
        pos += length
    return size, (255, 255, 255, 255)


def view_matrix(movie_size):
    """Stage → 700×510 viewport under the default showAll/centre fit (identity for 700×510)."""
    w, h = movie_size
    s = min(STAGE[0] / w, STAGE[1] / h)
    return s, (STAGE[0] - w * s) / 2, (STAGE[1] - h * s) / 2


def to_view(matrix, view):
    s, ox, oy = view
    a, b, c, d, tx, ty = matrix
    return [a * s, b * s, c * s, d * s, tx * s + ox, ty * s + oy]


EMPTY_SVG = re.compile(r'<(path|use|image|rect|circle|ellipse|polygon|polyline|line|text)\b')


# ---------------------------------------------------------------- display list

def parent_path(path):
    return path.rsplit('/', 1)[0]


def concatenated_colour(node, by_path):
    """Product of colour transforms from the node up to the stage."""
    mult, add = np.ones(4), np.zeros(4)
    chain = []
    path = node['path']
    while path:
        if path in by_path:
            chain.append(by_path[path])
        path = parent_path(path)
    for item in chain:  # child first: c' = c*m + a applied innermost first
        ct = item.get('color_transform', {'mult': [1, 1, 1, 1], 'add': [0, 0, 0, 0]})
        m, a = np.array(ct['mult'], float), np.array(ct['add'], float)
        mult, add = mult * m, add * m + a
    return mult, add


def ancestors_with(node, by_path, test):
    hits, path = [], parent_path(node['path'])
    while path:
        if path in by_path and test(by_path[path]):
            hits.append(path)
        path = parent_path(path)
    return hits


def pieces(golden):
    by_path = {n['path']: n for n in golden['nodes']}
    result, not_rebuilt = [], {}
    for node in golden['nodes']:
        if node.get('filters') or node.get('blend_mode', 'Normal') != 'Normal':
            if node.get('effective_visible'):
                not_rebuilt.setdefault('filter_or_blend', []).append(node['path'])
        if node.get('kind') not in PIECE_KINDS or not node.get('effective_visible'):
            continue
        if node['kind'] == 'morph_shape':
            not_rebuilt.setdefault('morph_shape (first ratio used)', []).append(node['path'])
        mult, add = concatenated_colour(node, by_path)
        result.append({'node': node, 'mult': mult, 'add': add})
    return result, not_rebuilt


# ---------------------------------------------------------------- route B

def _prefix_ids(svg_body, prefix):
    body = re.sub(r'\bid="([^"]+)"', lambda m: f'id="{prefix}{m.group(1)}"', svg_body)
    body = re.sub(r'url\(#([^)]+)\)', lambda m: f'url(#{prefix}{m.group(1)})', body)
    return re.sub(r'href="#([^"]+)"', lambda m: f'href="#{prefix}{m.group(1)}"', body)


def _inner(svg_text):
    start = svg_text.index('>', svg_text.index('<svg')) + 1
    return svg_text[start:svg_text.rindex('</svg>')]


def route_b(items, export, scale, missing, background, view):
    w, h = STAGE[0] * scale, STAGE[1] * scale
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
             f'width="{w}" height="{h}" viewBox="0 0 {w} {h}">',
             f'<rect width="{w}" height="{h}" fill="rgb{background[:3]}"/>']
    filters = []
    for i, item in enumerate(items):
        node = item['node']
        source = exported(export, 'svg', node['character_id'], 'svg')
        if source is None:
            missing.append(node['path'])
            continue
        text = source.read_text(encoding='utf-8')
        if not EMPTY_SVG.search(_inner(text)):
            missing.append(node['path'])
            continue
        x0, y0 = svg_offset(text)
        a, b, c, d, tx, ty = to_view(node['stage_matrix'], view)
        transform = f'matrix({a * scale},{b * scale},{c * scale},{d * scale},{tx * scale},{ty * scale}) translate({x0},{y0})'
        filter_attr = ''
        mult, add = item['mult'], item['add']
        if not (np.allclose(mult, 1) and np.allclose(add, 0)):
            fid = f'ct{i}'
            r, g, bl, al = mult
            ar, ag, ab, aa = add / 255.0
            filters.append(f'<filter id="{fid}" color-interpolation-filters="sRGB"><feColorMatrix type="matrix" '
                           f'values="{r} 0 0 0 {ar} 0 {g} 0 0 {ag} 0 0 {bl} 0 {ab} 0 0 0 {al} {aa}"/></filter>')
            filter_attr = f' filter="url(#{fid})"'
        parts.append(f'<g transform="{transform}"{filter_attr}>{_prefix_ids(_inner(text), f"p{i}_")}</g>')
    parts.insert(1, '<defs>' + ''.join(filters) + '</defs>')
    parts.append('</svg>')
    import resvg_py
    png = bytes(resvg_py.svg_to_bytes(svg_string=''.join(parts)))
    import io
    return Image.open(io.BytesIO(png)).convert('RGBA')


# ---------------------------------------------------------------- route C

def route_c(items, export, scale, missing, background, view):
    canvas = Image.new('RGBA', (STAGE[0] * scale, STAGE[1] * scale), background)
    resampled, from_svg = [], []
    for item in items:
        node = item['node']
        png = exported(export, 'png', node['character_id'], 'png')
        svg = exported(export, 'svg', node['character_id'], 'svg')
        if svg is None:
            missing.append(node['path'])
            continue
        svg_text = svg.read_text(encoding='utf-8')
        if not EMPTY_SVG.search(_inner(svg_text)):
            missing.append(node['path'])
            continue
        x0, y0 = svg_offset(svg_text)
        if png is not None:
            piece = Image.open(png).convert('RGBA')
        else:  # FFDec has no PNG export for text: rasterise its SVG at N× instead
            import io
            import resvg_py
            from_svg.append(node['path'])
            piece = Image.open(io.BytesIO(bytes(resvg_py.svg_to_bytes(
                svg_string=svg.read_text(encoding='utf-8'), zoom=scale)))).convert('RGBA')
        mult, add = item['mult'], item['add']
        if not (np.allclose(mult, 1) and np.allclose(add, 0)):
            arr = np.asarray(piece, float)
            arr = np.clip(arr * mult + add, 0, 255)
            piece = Image.fromarray(arr.astype(np.uint8), 'RGBA')
        a, b, c, d, tx, ty = to_view(node['stage_matrix'], view)
        ox, oy = (a * x0 + c * y0 + tx) * scale, (b * x0 + d * y0 + ty) * scale
        if abs(a - 1) < 1e-6 and abs(d - 1) < 1e-6 and abs(b) < 1e-6 and abs(c) < 1e-6 \
                and abs(ox - round(ox)) < 1e-3 and abs(oy - round(oy)) < 1e-3:
            layer = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
            layer.paste(piece, (round(ox), round(oy)))
        else:
            resampled.append(node['path'])
            # Map canvas -> piece pixels: inverse of (scale·M·translate(x0,y0)·scale⁻¹).
            det = a * d - b * c
            ia, ib, ic, id_ = d / det, -b / det, -c / det, a / det
            # piece = (inv(M) · (canvas/scale - t) - (x0, y0)) · scale
            coeffs = (ia, ic, (-(ia * tx + ic * ty) - x0) * scale,
                      ib, id_, (-(ib * tx + id_ * ty) - y0) * scale)
            layer = piece.transform(canvas.size, Image.AFFINE, coeffs, resample=Image.BICUBIC)
        canvas = Image.alpha_composite(canvas, layer)
    return canvas, resampled, from_svg


# ---------------------------------------------------------------- route A

def route_a(player, swf, case, capture, scale, out):
    import tempfile
    lines = []
    for action in case['actions']:
        if 'command' in action:
            lines.append(action['command'])
        if action.get('capture') == capture:
            lines.append(f'shot {out / "A-ruffle.png"}')
            break
    lines.append('quit')
    with tempfile.TemporaryDirectory(prefix='bombit5-bakeoff-') as staging:
        loaded = Path(staging) / 'original.swf'
        loaded.write_bytes(Path(swf).read_bytes())
        result = subprocess.run([str(player), str(loaded), '--scale', str(scale)], input='\n'.join(lines) + '\n',
                                capture_output=True, text=True, timeout=900)
    (out / 'A-ruffle.log').write_text(result.stdout + result.stderr, encoding='utf-8')
    if result.returncode != 0 or not (out / 'A-ruffle.png').is_file():
        raise SystemExit(f'reference player failed; see {out / "A-ruffle.log"}')
    return Image.open(out / 'A-ruffle.png').convert('RGBA')


# ---------------------------------------------------------------- scoring and sheet

def on_black(image):
    background = Image.new('RGBA', image.size, (0, 0, 0, 255))
    return Image.alpha_composite(background, image.convert('RGBA')).convert('RGB')


def score(candidate, reference_png, out, name):
    small = on_black(candidate).resize(STAGE, Image.LANCZOS)
    path = out / f'{name}-1x.png'
    small.save(path)
    if reference_png is None:
        return {'skipped': 'no 1× reference capture'}
    result = pixels.compare(reference_png, path, out / f'{name}-1x-heatmap.png')
    return {k: result[k] for k in ('ssim', 'max_region_delta_e', 'regions_over') if k in result}


def crops_from(golden, count=3):
    """Detail regions generated from the display list: the largest named visible clips."""
    named = [n for n in golden['nodes'] if n.get('name') and n.get('effective_visible') and n.get('stage_bounds')
             and n.get('kind') in ('movie_clip', 'button', 'text')]
    def area(n):
        x0, y0, x1, y1 = n['stage_bounds']
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, STAGE[0]), min(y1, STAGE[1])
        return max(0, x1 - x0) * max(0, y1 - y0)
    named = [n for n in named if 400 < area(n) < STAGE[0] * STAGE[1] * 0.25]
    named.sort(key=area, reverse=True)
    picked = []
    for n in named:
        if all(not n['path'].startswith(p['path'] + '/') and not p['path'].startswith(n['path'] + '/') for p in picked):
            picked.append(n)
        if len(picked) == count:
            break
    return [(n['path'], n['stage_bounds']) for n in picked]


def sheet(images, labels, crops, scale, out):
    thumb_w = 700
    rows = [[on_black(im).resize((thumb_w, round(thumb_w * im.height / im.width)), Image.LANCZOS) for im in images]]
    for _, (x0, y0, x1, y1) in crops:
        pad = 6
        box = [max(0, x0 - pad), max(0, y0 - pad), min(STAGE[0], x1 + pad), min(STAGE[1], y1 + pad)]
        box = [round(v * scale) for v in box]
        row = []
        for im in images:
            crop = on_black(im).crop(box) if im.width > STAGE[0] else on_black(im).resize(
                (STAGE[0] * scale, STAGE[1] * scale), Image.NEAREST).crop(box)
            k = min(thumb_w / crop.width, 420 / crop.height)
            row.append(crop.resize((max(1, round(crop.width * k)), max(1, round(crop.height * k))), Image.NEAREST))
        rows.append(row)
    label_h, gap = 28, 10
    width = len(images) * (thumb_w + gap) + gap
    height = sum(max(im.height for im in row) + gap for row in rows) + label_h + gap
    canvas = Image.new('RGB', (width, height), (32, 32, 32))
    draw = ImageDraw.Draw(canvas)
    for i, label in enumerate(labels):
        draw.text((gap + i * (thumb_w + gap), 8), label, fill=(240, 240, 240))
    y = label_h
    for r, row in enumerate(rows):
        for i, im in enumerate(row):
            canvas.paste(im, (gap + i * (thumb_w + gap), y))
        if r > 0:
            draw.text((gap, y + 2), crops[r - 1][0], fill=(255, 220, 120))
        y += max(im.height for im in row) + gap
    canvas.save(out / 'sheet.png')


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--case', default='main-menu')
    parser.add_argument('--capture', default='menu')
    parser.add_argument('--scale', type=int, default=3)
    parser.add_argument('--swf', type=Path, default=ROOT / '.scratch' / 'edition-5-research' / 'agame-bomb-it-5-zh-fix.swf')
    parser.add_argument('--player', type=Path, default=ROOT / '.scratch' / 'edition-5-research' / 'ruffle-runtime' / 'target' / 'ci' / 'probe')
    parser.add_argument('--golden', type=Path, help='display-list golden (default tests/goldens/<case>/<capture>.json)')
    parser.add_argument('--reference', type=Path, help='1× reference capture (default from compare.py record)')
    parser.add_argument('--case-file', type=Path, help='case JSON (default tools/compare/cases/<case>.json)')
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    if not args.swf.is_file():
        raise SystemExit(f'needs the SWF at {args.swf}')
    golden_path = args.golden or ROOT / 'tests' / 'goldens' / args.case / f'{args.capture}.json'
    golden = json.loads(golden_path.read_text(encoding='utf-8'))
    case = json.loads((args.case_file or ROOT / 'tools' / 'compare' / 'cases' / f'{args.case}.json').read_text(encoding='utf-8'))
    reference = args.reference or ROOT / '.scratch' / 'compare' / args.case / 'reference' / f'{args.capture}.png'
    reference = reference if reference.is_file() else None
    out = (args.out or ROOT / '.scratch' / 'bakeoff' / f'{args.case}-{args.capture}').resolve()
    out.mkdir(parents=True, exist_ok=True)
    export = ROOT / '.scratch' / 'bakeoff' / 'ffdec-export'

    a = route_a(args.player.resolve(), args.swf, case, args.capture, args.scale, out)
    ffdec_export(args.swf.resolve(), args.scale, export)
    items, not_rebuilt = pieces(golden)
    missing_b, missing_c = [], []
    movie_size, background = swf_header(args.swf)
    view = view_matrix(movie_size)
    if movie_size != STAGE:
        print(f'note: the SWF stage is {movie_size[0]:g}x{movie_size[1]:g}; pieces are fitted to 700x510 as Ruffle shows it')
    b = route_b(items, export, args.scale, missing_b, background, view)
    b.save(out / 'B-ffdec-resvg.png')
    c, resampled, c_from_svg = route_c(items, export, args.scale, missing_c, background, view)
    c.save(out / 'C-ffdec-png.png')
    if missing_b:
        not_rebuilt['no FFDec export, or empty (device-font text)'] = missing_b
    scores = {'case': args.case, 'capture': args.capture, 'scale': args.scale, 'pieces': len(items),
              'A-ruffle': score(a, reference, out, 'A-ruffle'),
              'B-ffdec-resvg': score(b, reference, out, 'B-ffdec-resvg'),
              'C-ffdec-png': score(c, reference, out, 'C-ffdec-png'),
              'C_resampled_twice': resampled,
              'C_text_from_svg': c_from_svg,
              'background': list(background), 'movie_size': list(movie_size),
              'not_rebuilt': {k: {'count': len(v), 'paths': v[:20]} for k, v in not_rebuilt.items()},
              'note': 'Scores compare each route, scaled back to 1×, with the 1× reference capture.'}
    (out / 'scores.json').write_text(json.dumps(scores, indent=1) + '\n', encoding='utf-8')
    images, labels = [a, b, c], [f'A  Ruffle {args.scale}x', f'B  FFDec SVG -> resvg {args.scale}x', f'C  FFDec PNG {args.scale}x']
    sheet(images, labels, crops_from(golden), args.scale, out)
    for name in ('A-ruffle', 'B-ffdec-resvg', 'C-ffdec-png'):
        s = scores[name]
        detail = s.get('skipped') or f'SSIM {s["ssim"]}, max region ΔE {s["max_region_delta_e"]}'
        print(f'{name:15} {detail}')
    print(f'not rebuilt by B/C: ' + (', '.join(f'{k} ({v["count"]})' for k, v in scores['not_rebuilt'].items()) or 'nothing'))
    print(f'outputs: {out}  (open sheet.png first)')


if __name__ == '__main__':
    main()
