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
                 'button_state', 'text', 'color_transform', 'blend_mode', 'filters')


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
    nodes = []
    for node in dump['nodes']:
        nodes.append({k: _round(node[k]) for k in GOLDEN_FIELDS if node.get(k) is not None})
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


def diff(golden, godot, tolerances=None):
    """Return a report: matched/missing/extra paths and every out-of-tolerance field."""
    tol = dict(DEFAULT_TOLERANCES, **(tolerances or {}))
    reference = {n['path']: n for n in golden['nodes']}
    actual = {}
    for node in godot['nodes']:
        if node['path'] in actual:
            raise ValueError(f'duplicate swf_path in Godot scene: {node["path"]}')
        actual[node['path']] = node
    baked = [p for p, n in actual.items() if n.get('baked')]

    def covered(path):
        return any(path.startswith(b + '/') for b in baked)

    required = [p for p, n in reference.items() if n.get('kind') != 'stage' and not covered(p)]
    # Hidden reference nodes only need checking when Godot builds them too.
    missing = [p for p in required if p not in actual and reference[p].get('effective_visible')]
    extra = [p for p in actual if p not in reference]
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
