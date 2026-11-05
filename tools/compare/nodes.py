"""Node half of the comparison loop: normalize the reference display list, diff Godot nodes.

Nodes match by display-list path (instance name, or `@depth` for unnamed children),
never by runtime object id. A Godot node marked `baked` draws its whole SWF subtree,
so reference descendants of its path are not expected as separate Godot nodes.
"""
import math

DEFAULT_TOLERANCES = {
    'position': 0.5,     # stage units
    'scale': 0.001,      # relative
    'rotation': 0.1,     # degrees
    'alpha': 1 / 255,
}

GOLDEN_FIELDS = ('path', 'kind', 'class', 'character_id', 'depth', 'name', 'effective_visible',
                 'alpha', 'stage_matrix', 'stage_bounds', 'frame', 'total_frames', 'label',
                 'button_state', 'text', 'color_transform', 'blend_mode', 'filters',
                 'clip_depth', 'mask', 'scroll_rect', 'render_bounds', 'text_format',
                 'filter_list')
# Mask relationships must match exactly: which node is a timeline mask (clip_depth),
# which sibling mask clips a node (clip_mask), and which node an AS3 `mask` names.
MASK_FIELDS = ('clip_depth', 'clip_mask', 'mask')


def _round(value, places=4):
    if isinstance(value, float):
        return round(value, places)
    if isinstance(value, list):
        return [_round(v, places) for v in value]
    if isinstance(value, dict):
        return {k: _round(v, places) for k, v in value.items()}
    return value


def normalize_reference(dump):
    """Reduce a `bombit5-display-list-v1` dump to the committed golden form."""
    if dump.get('schema') != 'bombit5-display-list-v1':
        raise ValueError('not a reference display-list dump')
    if dump.get('truncated'):
        raise ValueError('reference display list is truncated; raise the player limits')
    paths = [n['path'] for n in dump['nodes']]
    if len(paths) != len(set(paths)):
        duplicate = next(p for p in paths if paths.count(p) > 1)
        raise ValueError(f'duplicate display-list path {duplicate}; rebuild the reference player')
    nodes = []
    for node in dump['nodes']:
        nodes.append({k: _round(node[k]) for k in GOLDEN_FIELDS if node.get(k) is not None})
    # A timeline mask (clip_depth N at depth d) clips its siblings at depths d+1..N.
    by_parent = {}
    for node in nodes:
        by_parent.setdefault(node['path'].rsplit('/', 1)[0], []).append(node)
    for siblings in by_parent.values():
        masks = [n for n in siblings if n.get('clip_depth')]
        for node in siblings:
            for mask in masks:
                if mask['depth'] < node.get('depth', 0) <= mask['clip_depth']:
                    node['clip_mask'] = mask['path']
    return {'schema': 'bombit5-golden-nodes-v1', 'stage': dump['stage'], 'nodes': nodes}


def decompose(matrix):
    """Flash matrix [a, b, c, d, tx, ty] -> position, scale, rotation (degrees)."""
    a, b, c, d, tx, ty = matrix
    sx = math.hypot(a, b)
    sy = math.copysign(math.hypot(c, d), a * d - b * c)
    return {'x': tx, 'y': ty, 'sx': sx, 'sy': sy, 'rotation': math.degrees(math.atan2(b, a))}


def _rel(a, b):
    return abs(a - b) / max(abs(a), 1e-9)


def _angle(a, b):
    return abs((a - b + 180) % 360 - 180)


def apply_owner_edits(golden, edits):
    """The golden as the owner wants it: removed subtrees dropped, moved ones shifted."""
    removed, moved = edits.get('removed', {}), edits.get('moved', {})
    nodes = []
    for node in golden['nodes']:
        path = node['path']
        if any(path == r or path.startswith(r + '/') for r in removed):
            continue
        for m, info in moved.items():
            if path == m or path.startswith(m + '/'):
                node = dict(node)
                dx, dy = info['by']
                matrix = list(node['stage_matrix'])
                matrix[4] += dx
                matrix[5] += dy
                node['stage_matrix'] = matrix
        nodes.append(node)
    return dict(golden, nodes=nodes)


# Rules of the run-time effects a screen's port makes at random, which cannot match the
# original one to one (its Math.random state at the screen is not reproducible).
# FallSnow (zlong.bombit5.ui.FallSnow, scripts/ui/fall_snow.gd): `creatSnow` gives each
# Bitmap a colour from `_colorArr` (ColorTransform.color: multipliers 0, offsets the
# colour), x int(random * 710), y int(random * 20), rotation random * 180 and one random
# scale; `enterFrameHandle` adds 1 to y each frame and removes it past y 500 or x 710.
EFFECT_RULES = {
    'FallSnow': {'colours': (10089983, 16777113, 16711782, 6736998, 26367, 11796326),
                 'max_x': 710, 'max_y': 500},
}


def split_effects(golden, godot, effects):
    """Take the nodes of a screen's random effects out of both sides, and check each side's
    against the effect's rules (from the AS3) and the two counts against each other.
    `effects` is the layout's: {effect: {'nodes': {golden path: ...}}}; Godot marks its
    effect nodes with `effect`."""
    report = {}
    paths = {p for how in effects.values() for p in how.get('nodes', {})}
    ref_nodes = [n for n in golden['nodes'] if n['path'] in paths]
    got_nodes = [n for n in godot['nodes'] if n.get('effect')]
    for effect in effects:
        rules = EFFECT_RULES[effect]
        ref = [n for n in ref_nodes if n['path'] in effects[effect].get('nodes', {})]
        got = [n for n in got_nodes if n['effect'] == effect and n.get('effective_visible')]
        problems = [f'{side} {n["path"]}: {p}' for side, group in (('original', ref), ('godot', got))
                    for n in group for p in _effect_problems(n, rules)]
        if len(ref) != len(got):
            problems.append(f'{len(got)} shown in Godot, {len(ref)} in the original')
        report[effect] = {'original': len(ref), 'godot': len(got), 'problems': problems, 'passed': not problems,
                          'bounds': [n['render_bounds'] for n in ref + got if n.get('render_bounds')]}
    golden = dict(golden, nodes=[n for n in golden['nodes'] if n['path'] not in paths])
    godot = dict(godot, nodes=[n for n in godot['nodes'] if not n.get('effect')])
    return golden, godot, report


def _effect_problems(node, rules):
    problems = []
    m = decompose(node['stage_matrix'])
    ct = node.get('color_transform') or {}
    add, mult = ct.get('add', [0, 0, 0, 0]), ct.get('mult', [1, 1, 1, 1])
    colour = (int(add[0]) << 16) | (int(add[1]) << 8) | int(add[2])
    if any(abs(v) > 1e-6 for v in mult[:3]) or colour not in rules['colours']:
        problems.append(f'colour transform {ct} is not one of _colorArr')
    if not (0.0 <= m['sx'] < 1.0) or abs(m['sx'] - abs(m['sy'])) > 1e-3:
        problems.append(f'scale {m["sx"]:.4g} x {m["sy"]:.4g} is not one random scale in [0, 1)')
    if m['sx'] > 1e-3 and not (-1e-3 <= m['rotation'] % 360 < 180 + 1e-3):
        problems.append(f'rotation {m["rotation"]:.4g} is not in [0, 180)')
    if not (0 <= m['y'] <= rules['max_y']) or m['x'] > rules['max_x']:
        problems.append(f'at ({m["x"]:.4g}, {m["y"]:.4g}), where it would have been removed')
    return problems


def diff(golden, godot, tolerances=None):
    """Return a report: matched/missing/extra paths and every out-of-tolerance field."""
    tol = dict(DEFAULT_TOLERANCES, **(tolerances or {}))
    reference = {n['path']: n for n in golden['nodes']}
    actual = {}
    for node in godot['nodes']:
        if node['path'] in actual:
            # Alternatives that share an original path (each robot's panel at the same depth)
            # are fine while at most one shows; that one is compared.
            if actual[node['path']].get('effective_visible') and node.get('effective_visible'):
                raise ValueError(f'duplicate swf_path in Godot scene: {node["path"]}')
            if not node.get('effective_visible'):
                continue
        actual[node['path']] = node
    baked = [p for p, n in actual.items() if n.get('baked')]
    # Parts a group widget draws in its frame art (robotStage1's highlight shapes).
    drawn = [c for n in actual.values() for c in n.get('covers', ())]

    def covered(path):
        return any(path.startswith(b + '/') for b in baked) or any(path == c or path.startswith(c + '/') for c in drawn)

    required = [p for p, n in reference.items() if n.get('kind') != 'stage' and not covered(p)]
    # Hidden reference nodes only need checking when Godot builds them too.
    missing = [p for p in required if p not in actual and reference[p].get('effective_visible')]
    # A Godot node the original does not have counts only if it shows (a closed dropdown
    # that the original keeps off its display list is fine while hidden).
    extra = [p for p in actual if p not in reference and actual[p].get('effective_visible')]
    mismatches = []
    worst = {'position': 0.0, 'scale': 0.0, 'rotation': 0.0, 'alpha': 0.0}
    for path in required:
        if path not in actual:
            continue
        ref, got = reference[path], actual[path]
        problems = []
        if bool(ref.get('effective_visible')) != bool(got.get('effective_visible')):
            problems.append(f'visible {got.get("effective_visible")} != {ref.get("effective_visible")}')
        if ref.get('effective_visible'):
            r, g = decompose(ref['stage_matrix']), decompose(got['stage_matrix'])
            position = math.hypot(r['x'] - g['x'], r['y'] - g['y'])
            scale = max(_rel(r['sx'], g['sx']), _rel(r['sy'], g['sy']))
            rotation = _angle(r['rotation'], g['rotation'])
            alpha = abs(ref.get('alpha', 1.0) - got.get('alpha', 1.0))
            for key, value in (('position', position), ('scale', scale), ('rotation', rotation), ('alpha', alpha)):
                worst[key] = max(worst[key], value)
                if value > tol[key] + 1e-12:
                    problems.append(f'{key} off by {value:.4g} (tolerance {tol[key]:.4g})')
            for key in MASK_FIELDS:
                if ref.get(key) != got.get(key):
                    problems.append(f'{key} {got.get(key)!r} != {ref.get(key)!r}')
            for key in ('frame', 'button_state', 'text'):
                if key in ref and key in got and ref[key] != got[key]:
                    problems.append(f'{key} {got[key]!r} != {ref[key]!r}')
                elif key in ref and key not in got and key != 'text':
                    problems.append(f'{key} not reported by Godot (reference {ref[key]!r})')
        if problems:
            mismatches.append({'path': path, 'problems': problems})
    checked = len([p for p in required if p in actual])
    passed = not missing and not extra and not mismatches
    return {'passed': passed, 'reference_nodes': len(required), 'matched': checked,
            'missing': missing, 'extra': extra, 'mismatches': mismatches, 'worst': worst,
            'tolerances': tol, 'godot_unmapped_visible': godot.get('unmapped_visible', 0)}
