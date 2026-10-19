"""Summarize observed original weapon actions; no Godot timing oracle is used."""
import argparse
import json
from pathlib import Path

from inspect_reference_focus import FocusGraph


WEAPON_CLASSES = {
    'hammer': 'HammerProp', 'flamer': 'FlamerProp', 'laser': 'LaserGunProp',
    'triple': 'TripleShootGunProp', 'fireball': 'ShotGunProp', 'landmine': 'LandmineProp',
}


def action_row(path, kind, frame=None):
    graph = FocusGraph.read(path)
    human = graph.human()
    weapons = [record for record in human['equipment'].values()
               if record['class'] == f'zlong.bombit5.items.weapons::{WEAPON_CLASSES[kind]}']
    if len(weapons) > 1:
        raise ValueError('Multiple matching original equipped weapons')
    weapon = weapons[0] if weapons else None
    row = {'frame': int(path.stem[1:]) if frame is None else frame,
           'physical': {key: value for key, value in graph.physical(human['view']).items() if key in ('x', 'y')},
           'actor_state': graph.field(human['model'], 'state'),
           'facing': graph.field(human['model'], 'robotDirect'),
           'movement_interrupted': graph.field(human['controller'], '_stageFunc') is not None,
           'weapon': None}
    if weapon:
        row['weapon'] = graph.fields(weapon, ['currentUseNum', 'totalUseNum', 'weaponPlay'])
        for name in ['weaponPlay', '_fireMc', '_firePlayMc', '_flamerFire']:
            if graph.slot_ids(weapon, name):
                row['weapon'][name] = graph.field(weapon, name)
    return row


def summarize(run):
    case = json.loads((run / 'case.json').read_text(encoding='utf-8'))
    kind = case['name'].split('-')[0]
    if kind not in WEAPON_CLASSES:
        raise ValueError('Case name must identify the original selected weapon')
    rows = [action_row(path, kind) for path in sorted((run / 'trace').glob('f*.json'))]
    if not rows:
        raise ValueError('No per-frame focused action trace')
    commands = [json.loads(line) for line in (run / 'commands.jsonl').read_text(encoding='utf-8').splitlines()]
    downs = [row['frame'] for row in commands if row.get('command') == 'kd space']
    if len(downs) != 1:
        raise ValueError('Expected exactly one recorded action down event')
    # Mine placement can restore the default handler immediately, before a frame
    # is stepped. Do not turn the first post-step sample into a one-tick lock.
    if (run / 'input.json').is_file():
        rows.insert(0, action_row(run / 'input.json', kind, downs[0]))
    events = []
    for path in sorted((run / 'events').glob('*.json')):
        packet = json.loads(path.read_text(encoding='utf-8'))
        if packet['overflow'] or packet['selected_stack_overflows_total']:
            raise ValueError(f'Incomplete event capture: {path}')
        events.extend(packet['events'])
    exits = [row['frame'] for row in rows if not row['movement_interrupted']]
    return {'case': case['name'], 'input_counter': downs[0],
            'first_observed_uninterrupted_frame': exits[0] if exits else None,
            'interruption_frame_intervals': exits[0] - downs[0] if exits else None,
            'rows': rows, 'events': len(events),
            'errors': [event for event in events if event['kind'] == 'error'],
            'limits': ['Post-step interruption state, not every intermediate callback phase.',
                       'Missing equipment can mean replacement/disposal; inspect source and event history.',
                       'Nominal frame intervals are not measured real-time duration.']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = summarize(args.run)
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
