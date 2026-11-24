"""Per-tick traces: the scene at every tick of a window, stored as per-node changes.

A case action `{"trace": NAME, "ticks": N}` steps N frames one at a time and dumps the
scene after each, on both sides (reference player and Godot). The golden
`tests/goldens/<case>/<NAME>.trace.json` (compressed, tools/golden_io.py) holds:

    {"schema": "bombit5-golden-trace-v1", "frames": [frame of tick 0, ...],
     "stage": {...}, "first": [nodes of tick 0],
     "changes": [{"set": [changed or new nodes], "gone": [paths]} for ticks 1..N-1]}

Only nodes whose fields changed since the previous tick are stored, so a long window of a
mostly still screen costs little. `decode` rebuilds the full scene of every tick.
"""

SCHEMA = 'bombit5-golden-trace-v1'


def _by_path(scene):
    return {n['path']: n for n in scene['nodes']}


def encode(scenes):
    """Scenes (golden form, each with 'frame') -> one delta-encoded trace."""
    if not scenes:
        raise ValueError('a trace needs at least one tick')
    changes = []
    previous = _by_path(scenes[0])
    for scene in scenes[1:]:
        current = _by_path(scene)
        changed = [n for path, n in current.items() if previous.get(path) != n]
        gone = sorted(path for path in previous if path not in current)
        changes.append({'set': changed, 'gone': gone})
        previous = current
    return {'schema': SCHEMA, 'frames': [s.get('frame') for s in scenes], 'stage': scenes[0].get('stage', {}),
            'first': scenes[0]['nodes'], 'changes': changes}


def decode(trace):
    """One delta-encoded trace -> the full golden scene of every tick, in order."""
    if trace.get('schema') != SCHEMA:
        raise ValueError('not a golden trace')
    current = {n['path']: n for n in trace['first']}
    order = [n['path'] for n in trace['first']]
    scenes = [{'schema': 'bombit5-golden-nodes-v1', 'stage': trace['stage'], 'frame': trace['frames'][0],
               'nodes': [current[p] for p in order]}]
    for tick, change in enumerate(trace['changes'], start=1):
        for path in change['gone']:
            current.pop(path, None)
        for node in change['set']:
            if node['path'] not in current:
                order.append(node['path'])
            current[node['path']] = node
        order = [p for p in order if p in current]
        scenes.append({'schema': 'bombit5-golden-nodes-v1', 'stage': trace['stage'], 'frame': trace['frames'][tick],
                       'nodes': [current[p] for p in order]})
    return scenes


def first_divergence(results):
    """The first failing entry of (label, tick, node_diff) results in order, or None.

    The report names where the replays part: fix that tick first, since later differences
    usually follow from it."""
    for label, tick, diff in results:
        if diff['passed']:
            continue
        problems = [f'{m["path"]}: {"; ".join(m["problems"])}' for m in diff.get('mismatches', [])[:5]]
        problems += [f'missing {p}' for p in diff.get('missing', [])[:3]]
        problems += [f'extra {p}' for p in diff.get('extra', [])[:3]]
        return {'at': label, 'tick': tick, 'problems': problems}
    return None
