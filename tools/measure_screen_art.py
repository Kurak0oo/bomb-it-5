"""Measure the original screens' named instances from the FFDec SVG export (#76).

    python tools/measure_screen_art.py [--sprite UI_MainMenu ...]

Every UI page is a 700x510 stage (`UIManager` sets `scrollRect = (0, 0, 700, 510)`), shown on
the 1280x720 page at 720/510 and centred: `PAGE_STAGE`. For each top-level named instance (and
each text field) of the page's sprite this prints its rectangle in stage and page coordinates,
and the crop of the art-pipeline sheet (`original/art/slots/screen.<page>/candidate.png`,
the frame fitted into 1280x720) that holds exactly the stage. Reads the ignored export in
`.scratch/swf-export/sprites`; prints numbers only.
"""
import argparse
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / '.scratch' / 'swf-export' / 'sprites'
NS = '{http://www.w3.org/2000/svg}'
FFDEC = '{https://www.free-decompiler.com/flash}'
STAGE = (700.0, 510.0)
SCALE = 720.0 / STAGE[1]
PAGE_STAGE = ((1280.0 - STAGE[0] * SCALE) / 2, 0.0, STAGE[0] * SCALE, 720.0)
PAGES = {'UI_MainMenu': 'menu', 'UI_SETTING': 'settings', 'UI_SELECTCHARACTER': 'character',
         'UI_CONTROLS': 'how_to_play', 'UI_POWER_UPS': 'power_ups', 'UI_LEVEL_COMPLETED_ONEP': 'score',
         'UI_Dress Up': 'dress_up', 'UI_GAMEOVERONEP': 'game_over', 'UI_CONGRATULATIONSONEP': 'game_win',
         'UI_pause': 'pause'}


def matrix(text):
    values = [float(v) for v in re.findall(r'-?[\d.]+(?:[eE]-?\d+)?', text or '')] or [1, 0, 0, 1, 0, 0]
    return values


def sprite_dir(name_or_id):
    for path in SPRITES.iterdir():
        parts = path.name.split('_')
        if str(name_or_id) == parts[1] or path.name.endswith('_' + str(name_or_id)):
            return path
    return None


def origin(svg_path):
    """Size and the root translate (= -bounds min) of a sprite's first frame."""
    root = ET.parse(svg_path).getroot()
    group = root.find(NS + 'g')
    m = matrix(group.get('transform')) if group is not None else [1, 0, 0, 1, 0, 0]
    return float(root.get('width').rstrip('px')), float(root.get('height').rstrip('px')), m[4], m[5]


def bounds(character):
    """Local bounds of a character: from its own sprite export, else None."""
    folder = sprite_dir(character)
    if folder is None or not (folder / '1.svg').is_file():
        return None
    width, height, tx, ty = origin(folder / '1.svg')
    return -tx, -ty, width, height


def _compose(outer, inner):
    a, b, c, d, e, f = outer
    a2, b2, c2, d2, e2, f2 = inner
    return [a * a2 + c * b2, b * a2 + d * b2, a * c2 + c * d2, b * c2 + d * d2, a * e2 + c * f2 + e, b * e2 + d * f2 + f]


def _uses(group, outer):
    """Instances under the page's root group, through nested (clipping) groups."""
    for element in group:
        if element.tag == NS + 'use':
            yield element, outer
        elif element.tag == NS + 'g':
            yield from _uses(element, _compose(outer, matrix(element.get('transform'))))


def page_rect(x, y, w, h):
    return [round(PAGE_STAGE[0] + x * SCALE, 1), round(y * SCALE, 1), round(w * SCALE, 1), round(h * SCALE, 1)]


def measure(sprite):
    folder = next((p for p in SPRITES.iterdir() if p.name.endswith('_' + sprite.replace(' ', '_')) or p.name.endswith('_' + sprite)), None)
    if folder is None:
        return {'sprite': sprite, 'error': 'not exported'}
    width, height, tx, ty = origin(folder / '1.svg')
    fit = min(1280 / width, 720 / height)
    left = (1280 - width * fit) / 2
    top = (720 - height * fit) / 2
    crop = [round(left + tx * fit, 2), round(top + ty * fit, 2), round(STAGE[0] * fit, 2), round(STAGE[1] * fit, 2)]
    group = ET.parse(folder / '1.svg').getroot().find(NS + 'g')
    items = {}
    for element, outer in _uses(group, [1, 0, 0, 1, 0, 0]):
        name = element.get('id')
        if not name or name.startswith('__id'):
            continue
        a, b, c, d, ex, ey = _compose(outer, matrix(element.get('transform')))
        local = bounds(element.get(FFDEC + 'characterId'))
        if local is None:
            local = (0.0, 0.0, float(element.get('width', 0)), float(element.get('height', 0)))
        x0, y0, w, h = local
        corners = [(a * x + c * y + ex, b * x + d * y + ey) for x, y in ((x0, y0), (x0 + w, y0), (x0, y0 + h), (x0 + w, y0 + h))]
        xs, ys = [p[0] for p in corners], [p[1] for p in corners]
        stage = [round(min(xs), 2), round(min(ys), 2), round(max(xs) - min(xs), 2), round(max(ys) - min(ys), 2)]
        items[name] = {'stage': stage, 'page': page_rect(*stage)}
    return {'sprite': sprite, 'page': PAGES.get(sprite), 'svg': [width, height], 'stage_origin': [tx, ty],
            'sheet_crop': crop, 'page_frame': [round(v, 1) for v in PAGE_STAGE], 'items': items}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--sprite', action='append', help='sprite class name; default every page')
    args = parser.parse_args()
    for sprite in args.sprite or PAGES:
        print(json.dumps(measure(sprite)))


if __name__ == '__main__':
    main()
