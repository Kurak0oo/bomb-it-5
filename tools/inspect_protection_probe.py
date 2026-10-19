"""Extract bounded original protection/vehicle observations from recorded Focus files.

This reads existing evidence only. Missing slots remain explicit; references do not
imply their target's unprojected state. Raw Focus files stay in investigation storage.
"""
import argparse
import hashlib
import json
from pathlib import Path

from inspect_reference_focus import FocusGraph


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def protection_state(path, frame):
    raw = json.loads(path.read_text(encoding='utf-8'))
    result = {'frame': frame, 'source_file': path.name, 'source_sha256': sha256(path),
              'available': raw.get('available', True)}
    if not result['available']:
        result['reason'] = raw.get('reason')
        result['actors'] = []
        return result
    graph = FocusGraph(raw)  # Reject truncated records and ambiguous physical slots.
    result['game'] = graph.fields(raw['game'], ['gamePaused', 'gameOver', 'gameStarted', 'pastTime'])
    result['registered_robots'] = len(graph.array(graph.field(raw['game'], 'robots')))
    result['players'] = [{'index': index, 'id': player['id'],
                          **graph.fields(player, ['_life', '_modePoint', '_boxPoint', '_itemPoint'])}
                         for index, player in enumerate(raw['players'])]
    result['bombs'] = [{'id': bomb['id'], **graph.fields(bomb, ['_bombAdder', '_xN', '_yN',
                       '_time', '_isBlast', '_bombPow', '_continueTime'])}
                       for bomb in raw['bombs'].values()
                       if bomb['class'] == 'zlong.bombit5.bombs::Bomb']
    actors = []
    for index, player in enumerate(raw['players']):
        reference = graph.field(player, '_robot')
        actor = next((actor for actor in raw['robots'] if isinstance(reference, dict)
                      and actor['robot']['id'] == reference.get('$ref')), None)
        if actor is None:
            actors.append({'player_index': index, 'robot': reference})
            continue
        commands = []

        def inspect(value):
            if isinstance(value, list):
                for item in value:
                    inspect(item)
            elif isinstance(value, dict):
                if all(key in value for key in ('id', 'class', 'values')) and any(
                        name in value['class'] for name in ('InvincibilityCommand', 'CountMcPlayCommand')):
                    commands.append({'class': value['class'], 'id': value['id'], **{
                        name: graph.field(value, name)
                        for name in ('_nvincibilityTimeCount', '_totalFrames', '_time', '_totalTime')
                        if graph.slot_ids(value, name)}})
                for item in value.values():
                    inspect(item)

        inspect(actor['chains'])
        actors.append({'player_index': index, 'robot': actor['robot']['id'],
                       'isExist': graph.field(actor['robot'], 'isExist'),
                       **graph.fields(actor['model'], ['state', 'currentX', 'currentY', 'vehicle',
                                                      'weapon', 'velocity', 'robotVelocity', '_moveSpeed',
                                                      'shieldObj', 'bombNum', 'speed']),
                       'physical': graph.physical(actor['view']),
                       'stage': graph.field(actor['controller'], '_stageFunc'),
                       'bomb_handler': graph.field(actor['controller'], '_bombHandler'),
                       'commands': commands})
    result['actors'] = actors
    return result


def inspect_run(run, output):
    manifest = json.loads((run / 'manifest.json').read_text(encoding='utf-8-sig'))
    checkpoints = [{'name': item['name'], **protection_state(run / f'{item["name"]}.json', item['frame'])}
                   for item in manifest['states']]
    timelines = {}
    for directory in ('lifecycle', 'invincibility', 'pause', 'damage'):
        if (run / directory).is_dir():
            timelines[directory] = [timeline_state(protection_state(path, int(path.stem[1:])))
                                    for path in sorted((run / directory).glob('f*.json'))]
    output.mkdir(parents=True, exist_ok=True)
    (output / 'checkpoints.json').write_text(json.dumps(checkpoints, indent=2) + '\n')
    for name, rows in timelines.items():
        (output / f'{name}-timeline.json').write_text(json.dumps(rows, separators=(',', ':')) + '\n')
    index = {'schema': 'bombit5-protection-extract-v1', 'raw_run': str(run),
             'raw_manifest_sha256': sha256(run / 'manifest.json'),
             'player_sha256': manifest['player_sha256'], 'swf_sha256': manifest['swf_sha256'],
             'case_sha256': manifest['case_sha256'], 'checkpoints': len(checkpoints),
             'timeline_frames': {name: len(rows) for name, rows in timelines.items()},
             'limits': ['Focus omissions remain in force; absent records are not zero state.',
                        'Per-frame timeline retains players 0/1 only; checkpoints retain all projected actors.',
                        'No pending timer/Tween queue or native display children were observed.',
                        'Frame counters and host wall time are different clocks.']}
    (output / 'extract.json').write_text(json.dumps(index, indent=2) + '\n')
    print(json.dumps(index))


def timeline_state(state):
    """Keep the measured human/target fields and raw-file hash without duplicating layouts."""
    result = {key: value for key, value in state.items() if key != 'actors'}
    result['actors'] = []
    for actor in state['actors'][:2]:
        item = {key: actor[key] for key in ('player_index', 'robot', 'isExist', 'state',
                'currentX', 'currentY', 'vehicle', 'weapon', 'velocity', 'shieldObj') if key in actor}
        if 'physical' in actor:
            item['physical'] = {key: actor['physical'][key] for key in ('x', 'y')}
        if 'stage' in actor:
            item['stage_function'] = actor['stage'].get('function') if actor['stage'] else None
        if 'commands' in actor:
            item['commands'] = [{key: value for key, value in command.items() if key != 'id'}
                                for command in actor['commands']]
        result['actors'].append(item)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    arguments = parser.parse_args()
    inspect_run(arguments.run, arguments.output)
