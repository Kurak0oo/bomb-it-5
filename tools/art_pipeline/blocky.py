"""Deterministic blocky-avatar renderer: a per-robot box spec posed and drawn as flat SVG.

Every pose (facing, walk swing, defeat) comes from one model, so proportions, colours
and accessories stay identical across frames. Units are Minecraft-style pixels: head
8x8x8, torso 8x12x4, limbs 4x12x4. y is up, the character faces +z.
"""
import json
import math

from common import HERE, hex_to_rgb, rgb_to_hex

SPECS = HERE / 'blocky_specs'
FACINGS = {'Down': 0, 'Right': 90, 'Up': 180, 'Left': -90}
# Face name -> (outward normal, origin corner, u axis, v axis) in box-local unit cube terms.
FACES = {
    'front': ((0, 0, 1), (0, 1, 1), (1, 0, 0), (0, -1, 0)),
    'back': ((0, 0, -1), (1, 1, 0), (-1, 0, 0), (0, -1, 0)),
    'right': ((1, 0, 0), (1, 1, 1), (0, 0, -1), (0, -1, 0)),
    'left': ((-1, 0, 0), (0, 1, 0), (0, 0, 1), (0, -1, 0)),
    'top': ((0, 1, 0), (0, 1, 0), (1, 0, 0), (0, 0, 1)),
    'bottom': ((0, -1, 0), (0, 0, 1), (1, 0, 0), (0, 0, -1)),
}


def load(robot):
    return json.loads((SPECS / f'r{robot}.json').read_text(encoding='utf-8'))


def _rotate_x(p, degrees, pivot):
    a = math.radians(degrees)
    y, z = p[1] - pivot[1], p[2] - pivot[2]
    return (p[0], pivot[1] + y * math.cos(a) - z * math.sin(a), pivot[2] + y * math.sin(a) + z * math.cos(a))


def _camera(p, yaw, pitch):
    a, b = math.radians(yaw), math.radians(pitch)
    x, z = p[0] * math.cos(a) + p[2] * math.sin(a), -p[0] * math.sin(a) + p[2] * math.cos(a)
    y, z = p[1] * math.cos(b) - z * math.sin(b), p[1] * math.sin(b) + z * math.cos(b)
    return (x, -y, z)  # SVG y grows downward; larger z is nearer the camera.


def _shade(colour, normal, spec):
    """Minimal flat shading from the camera-space normal."""
    light = 1 + spec.get('top_light', 0.1) * max(0.0, -normal[1]) - spec.get('side_dark', 0.12) * abs(normal[0])
    return rgb_to_hex(tuple(max(0, min(255, round(c * light))) for c in hex_to_rgb(colour)))


def boxes(spec, outfit=None, hat=None):
    """The spec's boxes plus the chosen outfit's colour overrides and hat boxes."""
    parts = [dict(b) for b in spec['boxes']]
    if outfit:
        override = spec['outfits'][outfit]
        for part in parts:
            part.update(override.get('parts', {}).get(part['name'], {}))
        parts += override.get('boxes', [])
    if hat:
        parts += spec['hats'][hat]['boxes']
    return parts


def pose(spec, frame=None):
    """Limb swing (degrees about the x axis) and body bob for a walk phase in [0, 1)."""
    if frame is None:
        return {}, 0.0
    swing = spec.get('walk_swing', 32) * math.sin(2 * math.pi * frame)
    bob = spec.get('walk_bob', 0.6) * abs(math.sin(2 * math.pi * frame))
    return {'arm_l': swing, 'arm_r': -swing, 'leg_l': -swing, 'leg_r': swing}, bob


def polygons(spec, parts, yaw, pitch, swings=None, bob=0.0, scatter=0.0, char=False):
    """Visible faces and decals as (depth, points, fill, stroke, opacity), painter-ordered by box."""
    swings = swings or {}
    pivots = spec['pivots']
    outline = spec.get('outline', '#1d2a38')
    drawn = []
    for index, part in enumerate(parts):
        group = part.get('group', 'torso')
        x0, y0, z0 = part['pos']
        w, h, d = part['size']
        size = (w, h, d)

        def world(u, v, t):
            p = (x0 + u * w, y0 + v * h + bob, z0 + t * d)
            if group in swings:
                p = _rotate_x(p, swings[group], pivots[group])
            if scatter:
                # Defeat: each box drifts outward from the body and drops.
                cx, cz = x0 + w / 2, z0 + d / 2
                p = (p[0] + cx * scatter * 0.6, p[1] + (index % 5 - 2) * scatter * 0.8 - scatter * 6,
                     p[2] + cz * scatter * 0.6)
            return _camera(p, yaw, pitch)

        centre = world(0.5, 0.5, 0.5)
        faces = []
        for name, (normal, origin, uaxis, vaxis) in FACES.items():
            n = _camera(normal, yaw, pitch)
            if n[2] <= 1e-6:
                continue
            corners = [origin, tuple(o + a for o, a in zip(origin, uaxis)),
                       tuple(o + a + b for o, a, b in zip(origin, uaxis, vaxis)), tuple(o + b for o, b in zip(origin, vaxis))]
            colour = '#1b1b1b' if char else part.get('faces', {}).get(name, part['color'])
            items = [([world(*c) for c in corners], _shade(colour, n, spec), outline)]
            for decal in part.get('decals', []):
                if decal['face'] != name or char:
                    continue
                # Decal rect is in face pixels: u across, v down from the face's top-left.
                face_w = size[[i for i, a in enumerate(uaxis) if a][0]]
                face_h = size[[i for i, a in enumerate(vaxis) if a][0]]
                u, v, dw, dh = decal['rect']
                quad = []
                for du, dv in ((u, v), (u + dw, v), (u + dw, v + dh), (u, v + dh)):
                    s, t = du / face_w, dv / face_h
                    quad.append(tuple(o + s * a + t * b + 0.002 * nn for o, a, b, nn in zip(origin, uaxis, vaxis, normal)))
                stroke = decal.get('stroke')
                items.append(([world(*c) for c in quad], _shade(decal['color'], n, spec), stroke))
            faces.append(items)
        drawn.append((centre[2], faces))
    drawn.sort(key=lambda item: item[0])
    return [polygon for _, faces in drawn for items in faces for polygon in items]


def svg(spec, polys, box, opacity=1.0, stroke_width=None):
    x, y, w, h = box
    stroke_width = spec.get('stroke_width', 0.35) if stroke_width is None else stroke_width
    body = []
    for points, fill, stroke in polys:
        path = ' '.join(f'{px:.3f},{py:.3f}' for px, py, _ in points)
        line = f' stroke="{stroke}" stroke-width="{stroke_width}" stroke-linejoin="miter"' if stroke else ''
        body.append(f'<polygon points="{path}" fill="{fill}"{line}/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:.3f}px" height="{h:.3f}px" '
            f'viewBox="{x:.3f} {y:.3f} {w:.3f} {h:.3f}"><g opacity="{opacity}">' + ''.join(body) + '</g></svg>')


def bounds(polys, pad=1.0):
    xs = [p[0] for points, *_ in polys for p in points]
    ys = [p[1] for points, *_ in polys for p in points]
    return (min(xs) - pad, min(ys) - pad, max(xs) - min(xs) + 2 * pad, max(ys) - min(ys) + 2 * pad)


def union(boxes_):
    x0 = min(b[0] for b in boxes_)
    y0 = min(b[1] for b in boxes_)
    return (x0, y0, max(b[0] + b[2] for b in boxes_) - x0, max(b[1] + b[3] for b in boxes_) - y0)


def frames(spec, outfit=None, hat=None, pitch=None):
    """Every sprite the workbench needs, as {name: [polygon lists]} sharing one model."""
    pitch = spec.get('pitch', 12) if pitch is None else pitch
    parts = boxes(spec, outfit, hat)
    count = spec.get('walk_frames', 8)
    result = {}
    for facing, yaw in FACINGS.items():
        result[f'idle_{facing}'] = [polygons(spec, parts, yaw, pitch)]
        result[f'walk_{facing}'] = [polygons(spec, parts, yaw, pitch, *pose(spec, i / count)) for i in range(count)]
    result['defeat'] = ([polygons(spec, parts, 0, pitch, char=True)] * 3 +
                        [polygons(spec, parts, 0, pitch, scatter=s, char=True) for s in (0.4, 0.9, 1.5, 2.2)])
    return result
