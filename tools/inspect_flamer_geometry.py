"""Compare recorded native animated bounds with original FlamerFire getter returns."""
import argparse
import json
import math
from pathlib import Path

from inspect_reference_focus import FocusGraph


def inspect(run):
    case = json.loads((run / 'case.json').read_text(encoding='utf-8'))
    direction = case['name'].split('-')[1]
    dx, dy = {'up': (0, -1), 'down': (0, 1), 'left': (-1, 0), 'right': (1, 0)}[direction]
    rows = []
    for path in sorted((run / 'trace').glob('f*.json')):
        graph = FocusGraph.read(path)
        human = graph.human()
        weapons = [weapon for weapon in human['equipment'].values()
                   if weapon['class'] == 'zlong.bombit5.items.weapons::FlamerProp']
        if not weapons:
            continue
        fire = graph.field(weapons[0], '_fireMc')
        play = graph.field(weapons[0], 'weaponPlay')
        if fire is None or play is None:
            continue
        geometry = fire['display']['geometry']
        matrix = play['display']['geometry']['matrix']
        if geometry['truncated'] or any(abs(matrix[key]) > 1e-9 for key in ('b', 'c')):
            raise ValueError('Expected complete, axis-aligned reference action geometry')
        if matrix['a'] < 0 or matrix['d'] < 0:
            raise ValueError('Signed scale decomposition needs a separate oracle')
        physical = graph.physical(human['view'])
        # Authority: GameConfig EXCURSION_X/Y=183/40, GRID_WIDTH=30;
        # AbstractObject.xN/yN floor((native position-offset+item dimension/2)/30).
        cell = [math.floor((physical['x'] - 183 + graph.field(human['view'], 'itemWid') / 2) / 30),
                math.floor((physical['y'] - 40 + graph.field(human['view'], 'itemHei') / 2) / 30)]
        calculated = [math.trunc(cell[0] + dx * geometry['script_width'] * matrix['a'] / 30),
                      math.trunc(cell[1] + dy * geometry['script_height'] * matrix['d'] / 30)]
        packet = json.loads((run / 'events' / path.name).read_text(encoding='utf-8'))
        if packet['overflow'] or packet['selected_stack_overflows_total']:
            raise ValueError('Incomplete event oracle')
        calls = {event['call']: event for event in packet['events'] if event['kind'] == 'enter'}
        actual = {}
        for event in packet['events']:
            if event['kind'] != 'return' or event['call'] not in calls:
                continue
            for coordinate in ('xN', 'yN'):
                if f'FlamerFire/get {coordinate}()' in calls[event['call']]['method']:
                    actual[coordinate] = event['result']
        if set(actual) != {'xN', 'yN'}:
            raise ValueError(f'No actual endpoint getter oracle at {path.name}')
        rows.append({'frame': int(path.stem[1:]), 'fire_frame': fire['display']['current_frame'],
                     'width': geometry['script_width'], 'height': geometry['script_height'],
                     'matrix': matrix, 'actor_cell': cell, 'calculated': calculated, 'actual': actual,
                     'matches': calculated == [actual['xN'], actual['yN']]})
    if not rows:
        raise ValueError('No animated reference geometry')
    return {'case': case['name'], 'rows': rows, 'matched': sum(row['matches'] for row in rows),
            'limits': ['Last actual endpoint getter in each frame is compared with post-step bounds.',
                       'Native Script bounds are Ruffle results, not native Flash rendering certification.',
                       'This verifies the sampled scenario; it does not certify arbitrary obstructions.']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = inspect(args.run)
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(f"Matched {result['matched']}/{len(result['rows'])} recorded endpoints")
