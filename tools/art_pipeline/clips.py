"""Pin script-controlled nested clips (outfit, hat) to one frame in exported SVGs.

RobotView.as stops the innermost `bodyMc` on clothID + 1 and `hatMc` on hatID + 1.
FFDec instead lets those clips advance with the parent timeline, so exported walk,
ride and death frames cycle through every outfit. This replaces each pinned clip's
content with its standalone export at the chosen frame.
"""
import glob
import os
import re

from common import EXPORT

DEFAULT_PINS = {'bodyMc': 1, 'hatMc': 1}
USE = re.compile(r'<use\b[^>]*>')
_CACHE = {}


def _standalone(character, frame):
    key = (character, frame)
    if key not in _CACHE:
        folders = glob.glob(str(EXPORT / 'sprites' / f'DefineSprite_{character}')) + \
            glob.glob(str(EXPORT / 'sprites' / f'DefineSprite_{character}_*'))
        path = os.path.join(folders[0], f'{frame}.svg') if folders else None
        if path is None or not os.path.isfile(path):
            frames = sorted(glob.glob(os.path.join(folders[0], '*.svg'))) if folders else []
            path = frames[0] if frames else None
        _CACHE[key] = open(path, encoding='utf-8').read() if path else None
    return _CACHE[key]


def _inner(svg):
    """Children of the root registration <g>, and the <defs> body, of a standalone export."""
    root = re.search(r'<svg\b[^>]*>\s*<g transform="matrix\(1\.0, 0\.0, 0\.0, 1\.0, (-?[\d.]+), (-?[\d.]+)\)">', svg)
    if not root:
        return None, ''
    start = root.end()
    defs_at = svg.find('<defs>', start)
    # The registration <g> closes just before <defs> (or before </svg> if there are none).
    body_end = svg.rfind('</g>', start, defs_at if defs_at != -1 else svg.rfind('</svg>'))
    body = svg[start:body_end]
    defs = svg[defs_at + 6:svg.find('</defs>', defs_at)] if defs_at != -1 else ''
    return body, defs


def _prefix_ids(text, prefix):
    text = re.sub(r'\bid="([^"]+)"', lambda m: f'id="{prefix}{m.group(1)}"', text)
    return re.sub(r'href="#([^"]+)"', lambda m: f'href="#{prefix}{m.group(1)}"', text)


def _group_span(svg, ident):
    """Start/end of <g id="ident">...</g>, matching nested groups."""
    start = svg.find(f'<g id="{ident}">')
    if start == -1:
        return None
    depth = 0
    for match in re.finditer(r'<g\b[^>]*?(/?)>|</g>', svg[start:]):
        if match.group(0) == '</g>':
            depth -= 1
            if depth == 0:
                return start, start + match.end()
        elif not match.group(1):
            depth += 1
    return None


def pin(svg, pins=None, depth=0):
    pins = DEFAULT_PINS if pins is None else pins
    if depth > 4 or not any(f'id="{name}"' in svg for name in pins):
        return svg
    extra_defs = []
    for number, use in enumerate(USE.findall(svg)):
        name = re.search(r'\bid="([^"]+)"', use)
        if not name or name.group(1) not in pins:
            continue
        character = re.search(r'ffdec:characterId="(\d+)"', use)
        target = re.search(r'href="#([^"]+)"', use)
        standalone = _standalone(character.group(1), pins[name.group(1)]) if character else None
        span = _group_span(svg, target.group(1)) if target else None
        if not standalone or not span:
            continue
        body, defs = _inner(pin(standalone, pins, depth + 1))
        if body is None:
            continue
        prefix = f'pin{depth}_{number}_'
        replacement = f'<g id="{target.group(1)}">{_prefix_ids(body, prefix)}</g>'
        svg = svg[:span[0]] + replacement + svg[span[1]:]
        extra_defs.append(_prefix_ids(defs, prefix))
    if extra_defs:
        at = svg.rfind('</defs>')
        addition = ''.join(extra_defs)
        svg = svg[:at] + addition + svg[at:] if at != -1 else svg.replace('</svg>', f'<defs>{addition}</defs></svg>')
    return svg
