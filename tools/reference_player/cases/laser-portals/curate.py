"""Preserve the original laser's call tree, queried cells and state around portal shots."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import shutil
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from inspect_reference_focus import FocusGraph


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot(path, frame):
    graph = FocusGraph.read(path)
    human = graph.human()
    gun = graph.node(graph.field(human['view'], '_weaponObj'))
    if not gun['class'].endswith('::LaserGunProp'):
        raise ValueError('Expected original equipped laser')
    laser_ref = graph.field(gun, 'laser')
    laser = graph.node(laser_ref) if laser_ref else None
    play = graph.field(gun, 'weaponPlay')
    actors = []
    for actor in graph.state['robots']:
        player = graph.node(graph.field(actor['robot'], 'player'))
        physical = graph.physical(actor['view'])
        actors.append({'ui': graph.field(player, '_uiId'), 'id': actor['robot']['id'],
                       'position': [physical['x'] - 183, physical['y'] - 40],
                       'cell': [graph.field(actor['model'], 'currentX'), graph.field(actor['model'], 'currentY')],
                       'state': graph.field(actor['model'], 'state'),
                       'damage_eligible': graph.field(actor['robot'], 'isExist'),
                       'shield': graph.field(actor['model'], 'shieldObj')})
    actors.sort(key=lambda actor: actor['ui'])
    cells = [{'x': cell['x'], 'y': cell['y'], **{name: graph.field(cell['grid'], name)
              for name in ['box', 'platForm', 'fire', '_robot', '_bombArr']}}
             for cell in graph.state['cells'] if cell['x'] == 13 and cell['y'] in [10, 11, 12, 13, 14]]
    return {'frame': frame, 'actors': actors, 'cells': cells,
            'human_direction': graph.field(human['model'], 'robotDirect'),
            'busy': graph.field(human['controller'], '_stageFunc'), 'gun_id': gun['id'],
            'uses': graph.field(gun, 'currentUseNum'), 'total_uses': graph.field(gun, 'totalUseNum'),
            'charge_play': play,
            'laser': None if laser is None else {'id': laser['id'],
                'owner': graph.field(laser, '_robot'), 'game': graph.field(laser, 'game'),
                'container': graph.field(laser, '_container')}}


def curate(root, output):
    output.mkdir(parents=True, exist_ok=True)
    (output / '.gdignore').touch()
    calls = {}
    health = {'events': 0, 'dropped': 0, 'overflow_files': 0, 'errors': 0, 'stack_overflows': 0}
    for path in sorted((root / 'laser-events').glob('*.json')):
        data = json.loads(path.read_text(encoding='utf-8-sig'))
        health['events'] += len(data['events'])
        health['dropped'] += data['dropped']
        health['overflow_files'] += int(data['overflow'])
        health['stack_overflows'] = max(health['stack_overflows'], data['selected_stack_overflows_total'])
        for event in data['events']:
            if event['kind'] == 'enter':
                calls[event['call']] = {'call': event['call'], 'parent': event['parent'],
                    'enter_frame': event['frame_label'], 'enter_sequence': event['sequence'],
                    'method': event['method'], 'receiver': event['receiver'], 'arguments': event['arguments']}
            elif event['kind'] in ('return', 'error'):
                calls[event['call']].update(kind=event['kind'], result=event['result'],
                    exit_frame=event['frame_label'], exit_sequence=event['sequence'])
                health['errors'] += int(event['kind'] == 'error')
    if any(health[key] for key in ['dropped', 'overflow_files', 'errors', 'stack_overflows']):
        raise ValueError(f'Incomplete/erroring original observation: {health}')
    if any('result' not in call for call in calls.values()):
        raise ValueError('Unbalanced original call stream')
    shoots = [call for call in calls.values() if call['method'] == 'ShootLaserCommand/execute()']
    if len(shoots) != 1:
        raise ValueError(f'Expected one original ray pass, got {len(shoots)}')
    shoot = shoots[0]
    ray = [call for call in calls.values() if shoot['enter_sequence'] <= call['enter_sequence'] <= shoot['exit_sequence']]
    direct = [call for call in ray if call['parent'] == shoot['call']]
    queries = [call for call in direct if any(call['method'].endswith('/' + name + '()')
                                             for name in ['isBlock', 'getRobot', 'isEmpty'])]
    hits = [call for call in direct if call['method'].endswith('/hitRobotUnderPoint()')]
    items = [call for call in direct if call['method'].endswith('/hitItem()')]
    end = [call for call in calls.values() if call['method'] == 'LaserEndCommand/execute()']
    cleanup = [call for call in calls.values() if any(call['method'].endswith('/' + name + '()')
                for name in ['renewRobot', 'resetPlayMc', 'deleFire', 'countWeapon'])]
    selected = [call for call in calls.values() if call in ray or call in end or call in cleanup
                or 'LaserGunPlayCommand/' in call['method'] or 'LaserGunProp/bombDown' in call['method']
                or '::Laser/' in call['method'] or '::LaserPlayCommandChain/' in call['method']
                or 'DisplayObjectContainer/removeChild' in call['method']]
    (output / 'selected-events.json').write_text(json.dumps(selected, indent=2) + '\n', encoding='utf-8')
    (output / 'ray-call-tree.json').write_text(json.dumps(ray, indent=2) + '\n', encoding='utf-8')
    manifest = json.loads((root / 'manifest.json').read_text(encoding='utf-8-sig'))
    boundaries = [{'name': item['name'], **snapshot(root / (item['name'] + '.json'), item['frame'])}
                  for item in manifest['states'] if item['name'] in ['laser-equipped', 'traveler-arrived',
                    'pre-shot', 'laser-input', 'charge-first', 'beam-creation', 'beam-end-first',
                    'beam-visible', 'beam-cleaned', 'fresh-movement']]
    (output / 'boundaries.json').write_text(json.dumps(boundaries, indent=2) + '\n', encoding='utf-8')
    paths = sorted((root / 'laser-trace').glob('f*.json'))
    rows = [snapshot(path, int(path.stem[1:])) for path in paths]
    with (output / 'frames.csv').open('w', newline='', encoding='utf-8') as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows({key: json.dumps(value, separators=(',', ':')) if isinstance(value, (dict, list))
                         else value for key, value in row.items()} for row in rows)
    for name in ['case.json', 'manifest.json', 'commands.jsonl', 'player-stderr.log']:
        shutil.copyfile(root / name, output / name)
    for path in root.glob('fixture-*-result.json'):
        shutil.copyfile(path, output / path.name)
    pictures = []
    for name in ['pre-shot', 'beam-creation', 'beam-cleaned', 'fresh-movement']:
        target = output / (name + '.png')
        shutil.copyfile(root / target.name, target)
        pictures.append({'name': target.name, 'sha256': digest(target), 'bytes': target.stat().st_size})
    summary = {'raw_run': str(root), 'case_sha256': manifest['case_sha256'],
               'swf_sha256': manifest['swf_sha256'], 'player_sha256': manifest['player_sha256'],
               'trace_frames': len(rows), 'events': health, 'shoot': shoot,
               'direct_ray_queries': queries, 'actor_hit_cells': [call['arguments'] for call in hits],
               'item_hit_cells': [call['arguments'] for call in items],
               'laser_end_frames': [call['enter_frame'] for call in end],
               'cleanup': cleanup, 'screenshots': pictures,
               'limits': ['Actual original SWF in pinned Ruffle; native Flash equivalence not established.',
                          'A bare portal is nonblocking for this source query; occupied-blocked exception is not presumed.']}
    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    return summary


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = curate(args.run, args.output)
    print(json.dumps({key: result[key] for key in ['trace_frames', 'events', 'actor_hit_cells', 'laser_end_frames']}, indent=2))
