"""Project recorded original weapon interactions without supplying expected outcomes."""
import argparse
import json
from pathlib import Path

from inspect_reference_focus import FocusGraph


def actor(graph, identity):
    roster = graph.array(graph.field(graph.state['game'], 'robots'))
    registered = any(value.get('$ref') == identity for value in roster)
    matches = [row for row in graph.state['robots'] if row['robot']['id'] == identity]
    if not matches:
        return {'projected': False, 'registered': registered}
    row = matches[0]
    equipment = []
    for weapon in row['equipment'].values():
        if graph.slot_ids(weapon, 'currentUseNum'):
            equipment.append({'class': weapon['class'], **graph.fields(weapon, ['currentUseNum', 'totalUseNum'])})
    return {'projected': True, 'registered': registered, 'state': graph.field(row['model'], 'state'),
            'damage_eligible': graph.field(row['robot'], 'isExist'),
            'physical': {key: value for key, value in graph.physical(row['view']).items() if key in ('x', 'y')},
            'weapon': graph.field(row['model'], 'weapon'),
            'vehicle': graph.field(row['model'], 'vehicle'),
            'shield': graph.field(row['model'], 'shieldObj') is not None,
            'interrupted': graph.field(row['controller'], '_stageFunc') is not None,
            'equipment': equipment}


def inspect(run):
    initial = FocusGraph.read(run / 'equipped.json')
    identities = [initial.field(player, '_robot')['$ref'] for player in initial.state['players']]
    rows = []
    transitions = []
    previous = None
    for path in sorted((run / 'trace').glob('f*.json')):
        graph = FocusGraph.read(path)
        row = {'frame': int(path.stem[1:]), 'actors': [actor(graph, identity) for identity in identities],
               'target': next({'box': graph.field(cell['grid'], 'box'),
                               'prop': graph.field(cell['grid'], 'prop'),
                               'fire': graph.field(cell['grid'], 'fire'),
                               'bombs': graph.field(cell['grid'], '_bombArr')}
                              for cell in graph.state['cells'] if (cell['x'], cell['y']) == (2, 1))}
        rows.append(row)
        signature = {'actors': [{key: value for key, value in state.items() if key != 'physical'}
                                for state in row['actors']], 'target': row['target']}
        if signature != previous:
            transitions.append(row)
            previous = signature
    selected = []
    errors = []
    packets = 0
    for path in sorted((run / 'events').glob('*.json')):
        packet = json.loads(path.read_text(encoding='utf-8'))
        if packet['overflow'] or packet['selected_stack_overflows_total']:
            raise ValueError(f'Incomplete event capture: {path}')
        packets += 1
        calls = {event['call']: event for event in packet['events'] if event['kind'] == 'enter'}
        keep = {call for call, event in calls.items()
                if ('commands.weapon' in event['method'] or
                    'items.weapons' in event['method'] or
                    ('bombs::' in event['method'] and not any(part in event['method']
                         for part in ('/get ', '/set ', '/bombEngine(', '/ended(', '/takeCount(', '/updateBombPos('))))}
        for event in packet['events']:
            if event['kind'] == 'error':
                errors.append({'entry': calls.get(event['call']), 'error': event})
            if event.get('call') in keep:
                selected.append(event)
    commands = [json.loads(line) for line in (run / 'commands.jsonl').read_text(encoding='utf-8').splitlines()]
    return {'case': json.loads((run / 'case.json').read_text(encoding='utf-8'))['name'],
            'inputs': [row for row in commands if row.get('command') in ('kd space', 'ku space')],
            'rows': rows, 'transitions': transitions, 'selected_events': selected,
            'event_packets': packets, 'errors': errors,
            'limits': ['Projection includes player-owned death-animation actors; registration is read separately from Game.robots.',
                       'Target projection is cell (2,1); solid-up cases target (1,0).',
                       'Post-step snapshots can hide intermediate synchronous callback mutations.']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = inspect(args.run)
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(f"{len(result['rows'])} observations, {len(result['errors'])} errors")
