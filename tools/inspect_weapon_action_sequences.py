"""Index observed original weapon callback sequences and lifecycle boundaries."""
import argparse
import hashlib
import json
from pathlib import Path

from inspect_reference_focus import FocusGraph
from inspect_weapon_trace import action_row


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def interesting(method):
    if any(part in method for part in ('/get ', '/set ', '$cinit', '/updateWeaponDisplay', '/updateWeaponTimes')):
        return False
    return ('commands.weapon::' in method or 'items.weapons::' in method or 'bombs::' in method or
            any(part in method for part in ('/robotPause', '/robotResume', '/initWeapon', '/initBombHandle')))


def inspect(run):
    manifest = json.loads((run / 'manifest.json').read_text(encoding='utf-8-sig'))
    kind = run.name.split('-')[2] if run.name.startswith('weapon-survey-') else run.name.split('-')[1]
    logs = [json.loads(line) for line in (run / 'commands.jsonl').read_text(encoding='utf-8-sig').splitlines()]
    down = next(item['frame'] for item in logs if item.get('command') == 'kd space')
    groups, active, errors, files = {}, {}, [], []
    for path in sorted((run / 'events').glob('*.json')):
        packet = json.loads(path.read_text(encoding='utf-8-sig'))
        if packet['dropped'] or packet['overflow'] or packet['selected_stack_overflows_total']:
            raise ValueError(f'Incomplete events: {path}')
        files.append({'file': path.name, 'sha256': sha(path), 'events': len(packet['events'])})
        for event in packet['events']:
            if event['kind'] == 'enter':
                active[event['call']] = event
                if interesting(event['method']):
                    key = (event['method'], event['receiver'].get('$ref'))
                    if key not in groups:
                        groups[key] = {'method': event['method'], 'abc_method_index': event['abc_method_index'],
                            'receiver': event['receiver'], 'count': 0, 'frames': [], 'argument_samples': [],
                            'first_sequence': event['sequence'], 'last_sequence': event['sequence']}
                    group = groups[key]
                    group['count'] += 1
                    group['last_sequence'] = event['sequence']
                    if event['frame_label'] not in group['frames']:
                        group['frames'].append(event['frame_label'])
                    arguments = event['arguments']
                    if arguments and arguments not in group['argument_samples'] and len(group['argument_samples']) < 16:
                        group['argument_samples'].append(arguments)
            elif event['kind'] in ('return', 'error'):
                entry = active.pop(event['call'])
                if event['kind'] == 'error':
                    errors.append({'entry': entry, 'error': event})
    if active:
        raise ValueError(f'Unbalanced events: {run}')
    rows = []
    for path in sorted((run / 'trace').glob('f*.json')):
        frame = int(path.stem[1:])
        if frame < down:
            continue
        raw = json.loads(path.read_text(encoding='utf-8-sig'))
        if raw.get('available', True):
            graph = FocusGraph(raw)
            row = action_row(path, kind, frame)
            row['game_paused'] = graph.field(raw['game'], 'gamePaused')
            row['current_equipped_model'] = graph.field(graph.human()['model'], 'weapon')
            row['source_sha256'] = sha(path)
            rows.append(row)
    input_path = run / 'input.json'
    identity = None
    if input_path.exists():
        original = FocusGraph.read(input_path).human()
        identity = {name: original[name]['id'] for name in ('robot', 'model', 'view', 'controller')}
        row = action_row(input_path, kind, down)
        row.update({'game_paused': False, 'source_sha256': sha(input_path)})
        rows.insert(0, row)
    recoveries = [row['frame'] for row in rows if not row['movement_interrupted']]
    paused = [row['frame'] for row in rows if row['game_paused']]
    return {'run': run.name, 'raw_run': str(run), 'case_sha256': manifest['case_sha256'],
        'player_sha256': manifest['player_sha256'], 'swf_sha256': manifest['swf_sha256'],
        'manifest_sha256': sha(run / 'manifest.json'), 'kind': kind, 'input_counter': down, 'human': identity,
        'first_uninterrupted': recoveries[0] if recoveries else None,
        'paused_frames': paused, 'input_and_pacing_commands': [item for item in logs if item.get('command') in
            ('kd space', 'ku space', 'kd p', 'ku p', 'realtime 1')],
        'step_host_intervals': [item for item in logs if item.get('command', '').startswith('step ')
                                and item['frame'] >= down],
        'rows': rows, 'method_receiver_groups': list(groups.values()),
        'errors': errors, 'event_files': files, 'event_pairs_balanced': True,
        'limits': ['Every stored event packet checked for zero loss/overflow; selected calls balanced.',
            'Method/receiver grouping preserves frame sets and sequence bounds, not a full call tree.',
            'Argument samples stop at16 unique tuples; raw event files remain authoritative.',
            'Survey prefixes omit file-local global ShootLaserCommand/LaserEndCommand; chain probe includes them.',
            'A command spanning many steps has one host interval; no per-callback wall timestamp.',
            'Recovery means first observed post-step cleared interruption, not a claim about every intermediate phase.']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runs', type=Path, default=Path('.scratch/edition-5-research/reference-runs'))
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    lifecycles = {}
    for run in sorted(args.runs.glob('lifecycle-*')):
        if (run / 'manifest.json').exists():
            stem, revision = run.name.rsplit('-', 1)
            if stem not in lifecycles or int(revision) > int(lifecycles[stem].name.rsplit('-', 1)[1]):
                lifecycles[stem] = run
    runs = sorted(args.runs.glob('weapon-survey-*-01')) + sorted(lifecycles.values())
    result = {'schema': 'bombit5-weapon-action-sequences-v1', 'runs': [inspect(run) for run in runs]}
    args.output.write_text(json.dumps(result, separators=(',', ':')) + '\n')
    print(f"Indexed {len(result['runs'])} original action/lifecycle runs")
