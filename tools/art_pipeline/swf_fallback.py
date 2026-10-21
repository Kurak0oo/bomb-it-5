"""Pure-Python SWF export used only when Java/FFDec cannot run.

Covers bitmaps (DefineBits*, lossless) and DefineShape 1-4 with solid, gradient and
bitmap fills. Sprite timelines (so all multi-part characters and animation frames),
morph shapes, fonts and text are not reconstructed; they are reported as missed. Output mirrors FFDec's folder layout.
"""
from collections import defaultdict
from pathlib import Path
import base64
import io
import lzma
import struct
import zlib

import numpy as np
from PIL import Image


class Bits:
    def __init__(self, data, offset=0):
        self.data, self.pos = data, offset * 8

    def ub(self, n):
        value = 0
        for _ in range(n):
            byte, bit = divmod(self.pos, 8)
            value = (value << 1) | ((self.data[byte] >> (7 - bit)) & 1)
            self.pos += 1
        return value

    def sb(self, n):
        value = self.ub(n)
        return value - (1 << n) if n and value & (1 << (n - 1)) else value

    def align(self):
        self.pos = (self.pos + 7) // 8 * 8

    def byte(self):
        self.align()
        return self.pos // 8

    def ui8(self):
        self.align()
        value = self.data[self.pos // 8]
        self.pos += 8
        return value

    def ui16(self):
        self.align()
        value = struct.unpack_from('<H', self.data, self.pos // 8)[0]
        self.pos += 16
        return value


def decompress(raw):
    signature, length = raw[:3], struct.unpack_from('<I', raw, 4)[0]
    if signature == b'FWS':
        return raw[8:]
    if signature == b'CWS':
        return zlib.decompress(raw[8:])
    if signature == b'ZWS':
        header = raw[12:17] + struct.pack('<Q', length - 8)
        return lzma.LZMADecompressor(lzma.FORMAT_ALONE).decompress(header + raw[17:])
    raise ValueError('Not a SWF file')


def tags(data, offset):
    while offset + 2 <= len(data):
        header = struct.unpack_from('<H', data, offset)[0]
        offset += 2
        code, length = header >> 6, header & 63
        if length == 63:
            length = struct.unpack_from('<I', data, offset)[0]
            offset += 4
        yield code, data[offset:offset + length]
        offset += length
        if code == 0:
            return


def read_rect(bits):
    bits.align()
    n = bits.ub(5)
    return [bits.sb(n) for _ in range(4)]


def read_matrix(bits):
    bits.align()
    a = d = 1.0
    b = c = 0.0
    if bits.ub(1):
        n = bits.ub(5)
        a, d = bits.sb(n) / 65536, bits.sb(n) / 65536
    if bits.ub(1):
        n = bits.ub(5)
        b, c = bits.sb(n) / 65536, bits.sb(n) / 65536
    n = bits.ub(5)
    tx, ty = bits.sb(n), bits.sb(n)
    return (a, b, c, d, tx / 20, ty / 20)


def read_color(bits, alpha):
    values = [bits.ui8() for _ in range(4 if alpha else 3)]
    return tuple(values) + (() if alpha else (255,))


def read_fill(bits, version, missed):
    kind = bits.ui8()
    if kind == 0x00:
        return {'type': 'solid', 'color': read_color(bits, version >= 3)}
    if kind in (0x10, 0x12, 0x13):
        matrix = read_matrix(bits)
        bits.align()
        bits.ub(2), bits.ub(2)
        count = bits.ub(4)
        stops = [(bits.ui8(), read_color(bits, version >= 3)) for _ in range(count)]
        focal = struct.unpack('<h', bytes([bits.ui8(), bits.ui8()]))[0] / 256 if kind == 0x13 else 0
        return {'type': 'linear' if kind == 0x10 else 'radial', 'matrix': matrix, 'stops': stops, 'focal': focal}
    if kind in (0x40, 0x41, 0x42, 0x43):
        bitmap = bits.ui16()
        return {'type': 'bitmap', 'bitmap': bitmap, 'matrix': read_matrix(bits)}
    raise ValueError(f'Unknown fill style {kind:#x}')


def read_styles(bits, version, missed):
    count = bits.ui8()
    if count == 0xFF and version >= 2:
        count = bits.ui16()
    fills = [read_fill(bits, version, missed) for _ in range(count)]
    count = bits.ui8()
    if count == 0xFF and version >= 2:
        count = bits.ui16()
    lines = []
    for _ in range(count):
        width = bits.ui16() / 20
        if version == 4:
            bits.ub(2)
            join = bits.ub(2)
            has_fill = bits.ub(1)
            bits.ub(3), bits.ub(5), bits.ub(1), bits.ub(2)
            if join == 2:
                bits.ui16()
            fill = read_fill(bits, version, missed) if has_fill else {'type': 'solid', 'color': read_color(bits, True)}
            if fill['type'] != 'solid':
                missed['gradient strokes (drawn with first stop)'] += 1
                fill = {'type': 'solid', 'color': fill['stops'][0][1]} if fill.get('stops') else fill
        else:
            fill = {'type': 'solid', 'color': read_color(bits, version >= 3)}
        lines.append({'width': width, 'fill': fill})
    bits.align()
    return fills, lines, bits.ub(4), bits.ub(4)


def chain(edges):
    """Join directed edges into subpaths, preferring closed loops."""
    starts = defaultdict(list)
    for index, edge in enumerate(edges):
        starts[edge[0]].append(index)
    used, paths = set(), []
    for index in range(len(edges)):
        if index in used:
            continue
        path, current = [], index
        while current is not None:
            used.add(current)
            path.append(edges[current])
            end = edges[current][-1]
            current = next((i for i in starts[end] if i not in used), None)
            if end == path[0][0]:
                break
        paths.append(path)
    return paths


def path_data(paths, close):
    parts = []
    for path in paths:
        parts.append('M%g %g' % (path[0][0][0] / 20, path[0][0][1] / 20))
        for edge in path:
            if len(edge) == 2:
                parts.append('L%g %g' % (edge[1][0] / 20, edge[1][1] / 20))
            else:
                parts.append('Q%g %g %g %g' % (edge[1][0] / 20, edge[1][1] / 20, edge[2][0] / 20, edge[2][1] / 20))
        if close:
            parts.append('Z')
    return ' '.join(parts)


def paint(fill, defs, key, bitmaps=None, missed=None):
    if fill['type'] == 'solid':
        r, g, b, a = fill['color']
        return '#%02x%02x%02x' % (r, g, b), a / 255
    if fill['type'] in ('linear', 'radial'):
        stops = ''.join('<stop offset="%g" stop-color="#%02x%02x%02x" stop-opacity="%g"/>'
                        % (ratio / 255, c[0], c[1], c[2], c[3] / 255) for ratio, c in fill['stops'])
        transform = 'matrix(%g %g %g %g %g %g)' % fill['matrix']
        if fill['type'] == 'linear':
            defs.append(f'<linearGradient id="{key}" gradientUnits="userSpaceOnUse" x1="-819.2" x2="819.2" '
                        f'y1="0" y2="0" gradientTransform="{transform}">{stops}</linearGradient>')
        else:
            defs.append(f'<radialGradient id="{key}" gradientUnits="userSpaceOnUse" cx="0" cy="0" r="819.2" '
                        f'fx="{fill["focal"] * 819.2:g}" fy="0" gradientTransform="{transform}">{stops}</radialGradient>')
        return f'url(#{key})', 1.0
    if fill['type'] == 'bitmap' and bitmaps is not None and fill['bitmap'] in bitmaps:
        pixels = bitmaps[fill['bitmap']]
        buffer = io.BytesIO()
        Image.fromarray(pixels, 'RGBA').save(buffer, 'PNG')
        height, width = pixels.shape[:2]
        a, b, c, d, tx, ty = fill['matrix']
        defs.append(f'<pattern id="{key}" patternUnits="userSpaceOnUse" width="{width}" height="{height}" '
                    f'patternTransform="matrix({a / 20:g} {b / 20:g} {c / 20:g} {d / 20:g} {tx:g} {ty:g})">'
                    f'<image width="{width}" height="{height}" xlink:href="data:image/png;base64,'
                    f'{base64.b64encode(buffer.getvalue()).decode()}"/></pattern>')
        return f'url(#{key})', 1.0
    if fill['type'] == 'bitmap' and missed is not None:
        missed['bitmap fills without a decoded bitmap'] += 1
    return None, 0


def shape_svg(payload, version, ident, missed, bitmaps=None):
    bits = Bits(payload, 2)
    bounds = read_rect(bits)
    if version == 4:
        read_rect(bits)
        bits.ui8()
    fills, lines, fill_bits, line_bits = read_styles(bits, version, missed)
    groups, x = [], 0
    y = 0
    fill0 = fill1 = line = 0
    current = {'fills': fills, 'lines': lines, 'fill_edges': defaultdict(list), 'line_edges': defaultdict(list)}
    groups.append(current)
    while True:
        if bits.ub(1) == 0:
            flags = bits.ub(5)
            if flags == 0:
                break
            if flags & 1:
                n = bits.ub(5)
                x, y = bits.sb(n), bits.sb(n)
            if flags & 2:
                fill0 = bits.ub(fill_bits)
            if flags & 4:
                fill1 = bits.ub(fill_bits)
            if flags & 8:
                line = bits.ub(line_bits)
            if flags & 16:
                new_fills, new_lines, fill_bits, line_bits = read_styles(bits, version, missed)
                current = {'fills': new_fills, 'lines': new_lines, 'fill_edges': defaultdict(list),
                           'line_edges': defaultdict(list)}
                groups.append(current)
            continue
        straight = bits.ub(1)
        n = bits.ub(4) + 2
        start = (x, y)
        if straight:
            if bits.ub(1):
                x, y = x + bits.sb(n), y + bits.sb(n)
            elif bits.ub(1):
                y += bits.sb(n)
            else:
                x += bits.sb(n)
            edge = (start, (x, y))
        else:
            cx, cy = x + bits.sb(n), y + bits.sb(n)
            x, y = cx + bits.sb(n), cy + bits.sb(n)
            edge = (start, (cx, cy), (x, y))
        if fill1:
            current['fill_edges'][fill1].append(edge)
        if fill0:
            current['fill_edges'][fill0].append(tuple(reversed(edge)))
        if line:
            current['line_edges'][line].append(edge)
    defs, body = [], []
    for g, group in enumerate(groups):
        for index, edges in sorted(group['fill_edges'].items()):
            colour, opacity = paint(group['fills'][index - 1], defs, f'g{ident}_{g}_{index}', bitmaps, missed)
            if colour:
                body.append(f'<path fill="{colour}" fill-opacity="{opacity:g}" fill-rule="evenodd" '
                            f'd="{path_data(chain(edges), True)}"/>')
        for index, edges in sorted(group['line_edges'].items()):
            style = group['lines'][index - 1]
            colour, opacity = paint(style['fill'], defs, f'l{ident}_{g}_{index}')
            if colour:
                body.append(f'<path fill="none" stroke="{colour}" stroke-opacity="{opacity:g}" '
                            f'stroke-width="{max(style["width"], 1.0):g}" stroke-linecap="round" '
                            f'stroke-linejoin="round" d="{path_data(chain(edges), False)}"/>')
    x0, x1, y0, y1 = (v / 20 for v in bounds)
    return (f'<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
            f'width="{x1 - x0:g}px" height="{y1 - y0:g}px">\n<defs>{"".join(defs)}</defs>\n'
            f'<g transform="matrix(1.0, 0.0, 0.0, 1.0, {-x0:g}, {-y0:g})">\n' + '\n'.join(body) + '\n</g>\n</svg>\n')


def lossless(payload, alpha):
    ident, kind, width, height = struct.unpack_from('<HBHH', payload)
    if kind == 3:
        table = payload[7] + 1
        raw = zlib.decompress(payload[8:])
        entry = 4 if alpha else 3
        palette = np.frombuffer(raw[:table * entry], np.uint8).reshape(-1, entry)
        stride = (width + 3) // 4 * 4
        indices = np.frombuffer(raw[table * entry:], np.uint8)[:stride * height].reshape(height, stride)[:, :width]
        pixels = palette[indices]
        if not alpha:
            pixels = np.dstack([pixels, np.full(pixels.shape[:2], 255, np.uint8)])
        return ident, pixels
    raw = zlib.decompress(payload[7:])
    if kind == 4:
        stride = (width * 2 + 3) // 4 * 4
        words = np.frombuffer(raw, '>u2')[:stride // 2 * height].reshape(height, -1)[:, :width].astype(np.uint16)
        rgb = np.dstack([(words >> 10) & 31, (words >> 5) & 31, words & 31]).astype(np.uint16) * 255 // 31
        return ident, np.dstack([rgb.astype(np.uint8), np.full((height, width), 255, np.uint8)])
    argb = np.frombuffer(raw, np.uint8)[:width * height * 4].reshape(height, width, 4).astype(np.float64)
    a = argb[..., 0] if alpha else np.full((height, width), 255.0)
    rgb = argb[..., 1:] * (255.0 / np.where(a == 0, 255, a))[..., None] if alpha else argb[..., 1:]
    return ident, np.dstack([np.clip(rgb, 0, 255), a]).astype(np.uint8)


def jpeg(payload, tables, version):
    ident = struct.unpack_from('<H', payload)[0]
    offset = 2
    alpha_offset = None
    if version in (3, 4):
        alpha_offset = struct.unpack_from('<I', payload, offset)[0]
        offset += 4 + (2 if version == 4 else 0)
    data = payload[offset:offset + alpha_offset] if alpha_offset is not None else payload[offset:]
    if data[:4] == b'\xff\xd9\xff\xd8':
        data = data[4:]
    if version == 1 and tables:
        data = tables[:-2] + data[2:]
    image = np.array(Image.open(io.BytesIO(data)).convert('RGBA'))
    if alpha_offset is not None and data[:4] != b'\x89PNG' and len(payload) > offset + alpha_offset:
        mask = zlib.decompress(payload[offset + alpha_offset:])
        image[..., 3] = np.frombuffer(mask, np.uint8)[:image.shape[0] * image.shape[1]].reshape(image.shape[:2])
        # JPEG colour in alpha-carrying bitmap tags is premultiplied.
        alpha = image[..., 3:].astype(np.float64)
        image[..., :3] = np.clip(image[..., :3] * 255.0 / np.where(alpha == 0, 255, alpha), 0, 255).astype(np.uint8)
    return ident, image


def export(swf, target):
    target = Path(target)
    for folder in ('shapes', 'images', 'symbolClass'):
        (target / folder).mkdir(parents=True, exist_ok=True)
    data = decompress(Path(swf).read_bytes())
    offset = (5 + 4 * (data[0] >> 3) + 7) // 8 + 4
    missed, counts, tables, symbols, errors = defaultdict(int), defaultdict(int), None, [], []
    bitmaps = {}
    shape_versions = {2: 1, 22: 2, 32: 3, 83: 4}
    for code, payload in tags(data, offset):
        try:
            if code in shape_versions:
                ident = struct.unpack_from('<H', payload)[0]
                svg = shape_svg(payload, shape_versions[code], ident, missed, bitmaps)
                (target / 'shapes' / f'{ident}.svg').write_text(svg, encoding='utf-8')
                counts['shapes'] += 1
            elif code in (20, 36):
                ident, pixels = lossless(payload, code == 36)
                bitmaps[ident] = pixels
                Image.fromarray(pixels, 'RGBA').save(target / 'images' / f'{ident}.png')
                counts['images'] += 1
            elif code == 8:
                tables = payload
            elif code in (6, 21, 35, 90):
                ident, pixels = jpeg(payload, tables, {6: 1, 21: 2, 35: 3, 90: 4}[code])
                bitmaps[ident] = pixels
                Image.fromarray(pixels, 'RGBA').save(target / 'images' / f'{ident}.png')
                counts['images'] += 1
            elif code == 76:
                count, cursor = struct.unpack_from('<H', payload)[0], 2
                for _ in range(count):
                    ident = struct.unpack_from('<H', payload, cursor)[0]
                    end = payload.index(0, cursor + 2)
                    symbols.append(f'{ident};"{payload[cursor + 2:end].decode("utf-8", "replace")}"')
                    cursor = end + 1
            elif code == 39:
                missed['sprite timelines (not composed)'] += 1
            elif code in (46, 84):
                missed['morph shapes'] += 1
        except Exception as error:
            errors.append(f'tag {code}: {error}')
    (target / 'symbolClass' / 'symbols.csv').write_text('\n'.join(symbols) + '\n', encoding='utf-8')
    if errors:
        missed['tags that failed to parse'] = len(errors)
    return {'counts': dict(counts), 'missed': [f'{k}: {v}' for k, v in sorted(missed.items())], 'errors': errors[:50]}
