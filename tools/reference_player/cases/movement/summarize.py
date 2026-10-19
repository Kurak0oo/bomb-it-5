"""Curate the recorded movement/portal cases; never advances or mutates a game."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import shutil
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from inspect_reference_focus import FocusGraph
from inspect_reference_trace import ReferenceGraph


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_csv(path, rows):
    with path.open('w', newline='', encoding='utf-8') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def human_row(frame, graph):
    human = graph.human()
    model = graph.fields(human['model'], ['currentX', 'currentY', 'robotDirect', 'speed',
                                           'state', 'bombNum'])
    physical = graph.physical(human['view'])
    occupancy = []
    fire = []
    for cell in graph.state['cells']:
        if any(value.get('$ref') == human['robot']['id']
               for value in graph.array(graph.field(cell['grid'], '_robot'))):
            occupancy.append([cell['x'], cell['y']])
            fire.append(graph.field(cell['grid'], 'fire'))
    command_ids = {}
    send = None
    invincibility = None
    for record in graph.records.values():
        if record['class'] not in ('zlong.bombit5.commands.robot::SendRobotCommand',
                                    'zlong.bombit5.commands.robot::InvincibilityCommand',
                                    'zlong.bombit5.commands.robot::GetFireCommand'):
            continue
        if graph.field(record, 'robot').get('$ref') != human['robot']['id']:
            continue
        command_ids[record['id']] = record['class']
        if record['class'].endswith('::SendRobotCommand'):
            send = {'id': record['id'], **graph.fields(record, ['_frameCount', '_totalFrame',
                                                              '_targetXGrid', '_targetYGrid'])}
        elif record['class'].endswith('::InvincibilityCommand'):
            invincibility = {'id': record['id'], **graph.fields(
                record, ['_nvincibilityTimeCount', '_totalFrames'])}
    busy = graph.field(human['controller'], '_stageFunc')
    organ = graph.field(human['robot'], 'curOrgan')
    return {'frame': frame, 'x': physical['x'] - 183, 'y': physical['y'] - 40,
            'cell_x': model['currentX'], 'cell_y': model['currentY'],
            'direction': model['robotDirect'],
            'vx': model['speed']['point']['x'], 'vy': model['speed']['point']['y'],
            'state': model['state'], 'bomb_num': model['bombNum'],
            'damage_eligible': graph.field(human['robot'], 'isExist'),
            'busy_function': busy.get('function') if busy else None,
            'cur_organ': organ.get('$ref') if organ else None,
            'occupancy': occupancy, 'occupied_cell_fire': fire,
            'send': send, 'blink': invincibility, 'command_ids': command_ids}


def trace_rows(root, name):
    return [human_row(int(path.stem[1:]), FocusGraph.read(path))
            for path in sorted((root / name).glob('f*.json'))]


def csv_rows(rows):
    return [{key: json.dumps(value, separators=(',', ':')) if isinstance(value, (dict, list))
             else value for key, value in row.items() if key != 'command_ids'} for row in rows]


def curate(motion, portals, output):
    output.mkdir(parents=True, exist_ok=True)
    # Source imagery is investigation evidence, never a Godot resource.
    (output / '.gdignore').write_text('', encoding='utf-8')
    movement_rows = trace_rows(motion, 'motion-trace')
    portal_rows = trace_rows(portals, 'portal-trace')
    write_csv(output / 'motion-frames.csv', csv_rows(movement_rows))
    write_csv(output / 'portal-frames.csv', csv_rows(portal_rows))
    full = ReferenceGraph(json.loads((portals / 'opening-full.json').read_text(encoding='utf-8-sig')))
    pairs = {}
    for identity, node in full.objects.items():
        if node['class'] == 'zlong.bombit5.maps.platform::Portal':
            target = full.node(full.field(node, '_associatedPortal'))
            pairs[identity] = {'x': full.field(node, '_xN'), 'y': full.field(node, '_yN'),
                               'color': full.field(node, '_colorId'),
                               'destination': [full.field(target, '_xN'), full.field(target, '_yN')]}
    opening = FocusGraph.read(portals / 'opening-board.json')
    board = []
    for cell in opening.state['cells']:
        grid = cell['grid']
        platform = opening.field(grid, 'platForm')
        pair = pairs.get(platform['$ref']) if platform else None
        board.append({'x': cell['x'], 'y': cell['y'],
                      'fixed_box_probability': opening.field(grid, 'fixedBox'),
                      'unfixed_box_probability': opening.field(grid, 'unfixedBox'),
                      'box_present': bool(opening.field(grid, 'box')),
                      'pickup_present': bool(opening.field(grid, 'prop')),
                      'platform_class': platform['class'] if platform else '',
                      'portal_color': pair['color'] if pair else '',
                      'portal_destination': json.dumps(pair['destination']) if pair else '',
                      'fire': opening.field(grid, 'fire')})
    write_csv(output / 'opening-board.csv', board)
    transfers = []
    command_ids = {}
    by_frame = {row['frame']: row for row in portal_rows}
    for row in portal_rows:
        command_ids.update(row['command_ids'])
    sends = sorted({row['send']['id'] for row in portal_rows if row['send']},
                   key=lambda identity: next(row['frame'] for row in portal_rows
                                             if row['send'] and row['send']['id'] == identity))
    for identity in sends:
        rows = [row for row in portal_rows if row['send'] and row['send']['id'] == identity]
        arrival = by_frame[rows[-1]['frame'] + 1]
        following = by_frame[arrival['frame'] + 1]
        blink_id = rows[0]['blink']['id']
        removed = next((row['frame'] for row in portal_rows if row['frame'] > arrival['frame']
                        and (row['blink'] is None or row['blink']['id'] != blink_id)), None)
        transfers.append({'command_id': identity,
                          'source_cell': [rows[0]['cell_x'], rows[0]['cell_y']],
                          'target': [rows[0]['send']['_targetXGrid'], rows[0]['send']['_targetYGrid']],
                          'first_frame': rows[0]['frame'], 'first_count': rows[0]['send']['_frameCount'],
                          'last_projected_frame': rows[-1]['frame'],
                          'last_projected_count': rows[-1]['send']['_frameCount'],
                          'physical_arrival_frame': arrival['frame'], 'arrival_xy': [arrival['x'], arrival['y']],
                          'transit_positions': sorted({(row['x'], row['y']) for row in rows}),
                          'eligible_during_projected_transit': sorted({row['damage_eligible'] for row in rows}),
                          'occupancy_at_arrival': arrival['occupancy'],
                          'occupancy_next_frame': following['occupancy'],
                          'eligibility_at_arrival': arrival['damage_eligible'],
                          'blink_at_arrival': arrival['blink'], 'blink_removed_frame': removed})
    events_summary = {}
    curated_events = []
    for label, root, directory in [('movement', motion, 'motion-events'),
                                    ('portal', portals, 'portal-events'),
                                    ('template', portals, 'template-events')]:
        count = dropped = overflow = 0
        selected_methods = {}
        fire_checks = []
        alpha_values = []
        owners = command_ids if label == 'portal' else {
            key: value for row in movement_rows for key, value in row['command_ids'].items()}
        for path in sorted((root / directory).glob('*.json')):
            data = json.loads(path.read_text(encoding='utf-8-sig'))
            dropped += data['dropped']
            overflow += int(data['overflow']) + data.get('selected_stack_overflows_total', 0)
            for event in data['events']:
                count += 1
                if event['kind'] != 'enter':
                    continue
                name = event.get('method', '')
                if (event.get('receiver', {}).get('$ref') in owners and
                        name.endswith('GetFireCommand/execute()')):
                    fire_checks.append(event['frame_label'])
                    curated_events.append({'channel': label, 'event': event})
                if label == 'template' and 'CinemaMapData/' in name:
                    selected_methods[name] = selected_methods.get(name, 0) + 1
                if label == 'portal' and event.get('receiver', {}).get('$ref') in command_ids:
                    if any(word in name for word in ('SendRobotCommand/', 'InvincibilityCommand/')):
                        curated_events.append({'channel': label, 'event': event})
                if label == 'portal' and event.get('command_label') in ('kd space', 'kd right'):
                    if 'PersonInteractiveController/' in name:
                        curated_events.append({'channel': label, 'event': event})
                if label == 'portal' and name == 'flash.display::DisplayObject/set alpha()':
                    alpha_values.append({'frame': event['frame_label'], 'value': event['arguments'][0]})
                    curated_events.append({'channel': label, 'event': event})
        if dropped or overflow:
            raise ValueError(f'{label} event stream overflowed')
        events_summary[label] = {'event_records': count, 'dropped': dropped,
                                 'overflow': overflow, 'template_calls': selected_methods,
                                 'human_fire_checks': fire_checks, 'portal_alpha': alpha_values}
    with (output / 'selected-events.jsonl').open('w', encoding='utf-8') as stream:
        for event in curated_events:
            stream.write(json.dumps(event, separators=(',', ':')) + '\n')
    for label, root in [('motion', motion), ('portals', portals)]:
        for name in ['manifest.json', 'commands.jsonl', 'case.json']:
            shutil.copyfile(root / name, output / f'{label}-{name}')
        for path in root.glob('fixture-*-result.json'):
            shutil.copyfile(path, output / f'{label}-{path.name}')
    pictures = {'motion': ['opening-board', 'corridor-aligned', 'bomb-departed', 'bomb-reentry-blocked'],
                'portals': ['pair1-neighbor', 'pair1-transit-frame1', 'pair1-controls-blocked',
                            'pair1-physical-arrival', 'pair1-latch-idle', 'pair1-exited',
                            'pair2-neighbor', 'pair2-physical-arrival', 'pair2-return-arrived']}
    inventory = []
    for label, names in pictures.items():
        root = motion if label == 'motion' else portals
        for name in names:
            source = root / f'{name}.png'
            target = output / f'{label}-{name}.png'
            shutil.copyfile(source, target)
            inventory.append({'file': target.name, 'bytes': target.stat().st_size, 'sha256': digest(target)})
    summary = {'source_swf_sha256': json.loads((motion / 'manifest.json').read_text(encoding='utf-8-sig'))['swf_sha256'],
               'player_sha256': json.loads((motion / 'manifest.json').read_text(encoding='utf-8-sig'))['player_sha256'],
               'seed': 42, 'portal_pairs': list(pairs.values()), 'transfers': transfers,
               'events': events_summary, 'screenshots': inventory,
               'motion_frames': len(movement_rows), 'portal_frames': len(portal_rows),
               'limits': ['Original Ruffle observations; native Flash comparison not established.',
                          'Seed, AI stop and relocation are explicit research fixtures.',
                          'No injected portal fire or damaging weapon contact in transit.',
                          'Raw graphs remain in ignored run directories.']}
    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    return summary


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--motion', type=Path, required=True)
    parser.add_argument('--portals', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = curate(args.motion, args.portals, args.output)
    print(json.dumps({key: result[key] for key in ['motion_frames', 'portal_frames', 'transfers', 'events']}, indent=2))
