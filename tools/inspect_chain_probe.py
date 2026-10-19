"""Extract original chain/overlap observations without executing ActionScript."""
import argparse
import hashlib
import json
from pathlib import Path

from inspect_reference_focus import FocusGraph
from inspect_protection_probe import protection_state


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def state(path, frame):
    result = protection_state(path, frame)
    raw = json.loads(path.read_text(encoding='utf-8'))
    if not result['available']:
        return result
    graph = FocusGraph(raw)
    result['cells'] = []
    for cell in raw['cells']:
        grid = cell['grid']
        fire = graph.field(grid, 'fire')
        bombs = graph.array(graph.field(grid, '_bombArr'))
        robots = graph.array(graph.field(grid, '_robot'))
        if fire or bombs or robots or (cell['x'], cell['y']) == (2, 1):
            result['cells'].append({'x': cell['x'], 'y': cell['y'], 'fire': fire,
                                    'bombs': bombs, 'robots': robots})
    result['callbacks'] = graph.fields(raw['engine'], ['_bombArr', '_blastArr', '_engineArr'])
    return result


def selected(event):
    method = event.get('method', '')
    if 'GameEngine/' in method:
        return any(word in method for word in ('/add', '/remove', '/clear', '/dispose'))
    if '::Map/' in method:
        return any(word in method for word in ('/setFire', '/addBomb', '/deleBomb', '/deleRobot'))
    if '::CommandChain/' in method:
        return any(word in method for word in ('/addCommand', '/removeCommand', '/clear', '/dispose'))
    if '::Bomb/' in method:
        return any(word in method for word in ('/blast(', '/blastHandle', '/ended', '/deleFire',
                                             '/hitItem', '/hitRobot', '/disappear', '/dispose'))
    return any(word in method for word in ('ShootLaserCommand', 'LaserEndCommand',
               'InvincibilityCommand/', 'SendRobotCommand/', 'RobotDeadCommand'))


def inspect(run, output, event_filter=None):
    event_filter = event_filter or selected
    manifest = json.loads((run / 'manifest.json').read_text(encoding='utf-8-sig'))
    output.mkdir(parents=True, exist_ok=True)
    checkpoints = [{'name': item['name'], **state(run / (item['name'] + '.json'), item['frame'])}
                   for item in manifest['states']]
    frames = [state(path, int(path.stem[1:])) for path in sorted((run / 'frames').glob('f*.json'))]
    events, files = [], []
    active, unmatched = {}, []
    for path in sorted((run / 'events').glob('*.json')):
        raw = json.loads(path.read_text(encoding='utf-8-sig'))
        files.append({'name': path.name, 'sha256': sha(path), 'events': len(raw['events']),
                      **{key: raw[key] for key in ('dropped', 'overflow', 'selected_stack_overflows_total')}})
        for event in raw['events']:
            kind, call = event['kind'], event.get('call')
            if kind == 'enter':
                active[call] = event_filter(event)
                if active[call]:
                    events.append(event)
            elif kind in ('return', 'error'):
                keep = active.pop(call, None)
                if keep is None:
                    unmatched.append(call)
                if keep:
                    events.append(event)
    if active or unmatched or any(f['dropped'] or f['overflow'] or f['selected_stack_overflows_total'] for f in files):
        raise ValueError('Incomplete or unbalanced event collection')
    for name, data in [('checkpoints.json', checkpoints), ('timeline.json', frames), ('mutation-events.json', events)]:
        (output / name).write_text(json.dumps(data, separators=(',', ':')) + '\n')
    index = {'schema': 'bombit5-chain-extract-v1', 'run': str(run), 'manifest_sha256': sha(run / 'manifest.json'),
             'player_sha256': manifest['player_sha256'], 'swf_sha256': manifest['swf_sha256'],
             'case_sha256': manifest['case_sha256'], 'frames': len(frames), 'event_files': files,
             'balanced_original_event_pairs': True, 'mutation_event_records': len(events),
             'limits': ['Only stored slots are read; Focus omissions apply.',
                        'Mutation excerpt preserves original sequence/call/depth; omitted ancestors may be referenced.',
                        'Process-local addresses are correlation identifiers, not stable cross-run IDs.',
                        'Host and frame clocks differ. No global deterministic replay claim.']}
    (output / 'extract.json').write_text(json.dumps(index, indent=2) + '\n')
    print(json.dumps({key: index[key] for key in ('run', 'frames', 'mutation_event_records')}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    inspect(args.run, args.output)
