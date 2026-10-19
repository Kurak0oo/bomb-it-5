"""Curate recorded original death/results observations; never infer missing source state."""
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


def events(root):
    calls = {}
    all_entries = {}
    selected = []
    totals = {'events': 0, 'dropped': 0, 'overflow_files': 0, 'errors': 0}
    score_fields = ['life', 'lifeData', 'boxPoint', 'itemPoint', 'modePoint', 'timePoint',
                    'diffiPoint', 'levelPoint', 'totalPoint', 'scoreData', 'killNum']
    phases = ['/win()', '/lose()', '/winHandler()', '/loseHandler()', '/countScore()',
              '/onePScore()', '/gameOver()', '/gameReStart()', '/gameReInit()', '/overInit()',
              '/animationComplete()', '/deleRobot()', '/robotDead()', '/kill()',
              '/nextLevelFunc()', '/backHandle()', '/stopPause()', '/afterStopPause()',
              '/robotStop()', '/unRegistRobot()', '/disablePauseButton()', '/end()']
    for path in sorted((root / 'result-events').glob('*.json')):
        data = json.loads(path.read_text(encoding='utf-8'))
        totals['events'] += len(data['events'])
        totals['dropped'] += data['dropped']
        totals['overflow_files'] += int(data['overflow'])
        for event in data['events']:
            frame = event['frame_label']
            if event['kind'] == 'error':
                totals['errors'] += 1
            if event['kind'] == 'enter':
                method = event['method']
                all_entries[event['call']] = {'call': event['call'], 'enter_frame': frame, 'method': method,
                                               'receiver': event['receiver'], 'arguments': event['arguments']}
                keep = any(name in method for name in phases) or '::RobotDeadCommand/' in method or (
                    '::AbstractPlayer/' in method and any(
                        method.endswith(f'/{access} {name}()')
                        for name in score_fields for access in ['get', 'set']))
                if keep:
                    item = {'call': event['call'], 'enter_frame': frame, 'method': method,
                            'receiver': event['receiver'], 'arguments': event['arguments']}
                    selected.append(item)
                    calls[event['call']] = item
            elif event['kind'] in ('return', 'error') and event['call'] in calls:
                calls[event['call']].update(exit_frame=frame, kind=event['kind'], result=event['result'])
            elif event['kind'] == 'error':
                item = all_entries[event['call']]
                item.update(exit_frame=frame, kind='error', result=event['result'])
                selected.append(item)
    if totals['dropped'] or totals['overflow_files']:
        raise ValueError(f'Incomplete/erroring original event observation: {totals}')
    return selected, totals


def boundary(path, frame):
    data = json.loads(path.read_text(encoding='utf-8'))
    if not data.get('available'):
        return {'frame': frame, 'available': False}
    graph = FocusGraph(data)
    game = data['game']
    field = graph.field
    registered = [value['$ref'] for value in graph.array(field(game, 'robots'))]
    human = next(player for player in data['players'] if player['class'].endswith('::PersonPlayer'))
    actor_rows = []
    for player in data['players']:
        ref = field(player, '_robot')
        row = {'player': player['id'], 'class': player['class'], 'life': field(player, '_life'),
               'robot': ref.get('$ref') if isinstance(ref, dict) else None}
        if row['robot']:
            robot = graph.node(ref)
            view = graph.node(field(robot, 'view'))
            model = graph.node(field(robot, 'model'))
            row.update(state=field(model, 'state'), is_exist=field(robot, 'isExist'),
                       registered=row['robot'] in registered, position=graph.physical(view),
                       movie=field(view, '_mc'))
        actor_rows.append(row)
    ending = data['ending']
    cartoon = None if ending is None else {
        'id': ending['id'], 'name': field(ending, '_cartoonName'), 'movie': field(ending, '_mc')}
    # Keep only shared native position/frame summaries in this small artifact.
    for actor in actor_rows:
        if 'position' in actor:
            actor['position'] = {key: actor['position'][key] for key in ('x', 'y')}
            movie = actor['movie']
            actor['movie'] = {'id': movie['$ref'], **{key: value for key, value in movie.get('display', {}).items()
                                                    if key in ('current_frame', 'x', 'y')}}
    if cartoon:
        movie = cartoon['movie']
        cartoon['movie'] = {'id': movie['$ref'], **{key: value for key, value in movie.get('display', {}).items()
                                                  if key in ('current_frame', 'x', 'y')}}
    return {'frame': frame, 'available': True, 'game': game['id'], 'level': field(game, 'currentLevel'),
            'game_over': field(game, 'gameOver'), 'past_time': field(game, 'pastTime'),
            'game_time': field(game, 'gameTime'), 'hearts': field(human, '_life'),
            'registered': registered, 'actors': actor_rows, 'ending': cartoon,
            'engine_present': data['engine'] is not None}


def curate(root, output, pictures):
    output.mkdir(parents=True, exist_ok=True)
    (output / '.gdignore').touch()
    manifest = json.loads((root / 'manifest.json').read_text(encoding='utf-8-sig'))
    selected, event_totals = events(root)
    (output / 'selected-events.json').write_text(json.dumps(selected, indent=2) + '\n', encoding='utf-8')
    snapshots = [dict(name=state['name'], **boundary(root / (state['name'] + '.json'), state['frame']))
                 for state in manifest['states']]
    (output / 'boundaries.json').write_text(json.dumps(snapshots, indent=2) + '\n', encoding='utf-8')
    rows = []
    for directory in ['death-trace', 'simultaneous-trace', 'kill-trace']:
        for path in sorted((root / directory).glob('f*.json')):
            rows.append(boundary(path, int(path.stem[1:])))
    if rows:
        with (output / 'frames.csv').open('w', newline='', encoding='utf-8') as file:
            names = list(next(row for row in rows if row.get('available')))
            writer = csv.DictWriter(file, fieldnames=names)
            writer.writeheader()
            for row in rows:
                writer.writerow({key: json.dumps(value, separators=(',', ':')) if isinstance(value, (list, dict))
                                 else value for key, value in row.items()})
    for name in ['manifest.json', 'commands.jsonl', 'case.json', 'player-stderr.log']:
        shutil.copyfile(root / name, output / name)
    for path in root.glob('fixture-*-result.json'):
        shutil.copyfile(path, output / path.name)
    inventory = []
    for name in pictures:
        source = root / (name + '.png')
        target = output / source.name
        shutil.copyfile(source, target)
        inventory.append({'name': target.name, 'sha256': digest(target), 'bytes': target.stat().st_size})
    summary = {'raw_run': str(root), 'swf_sha256': manifest['swf_sha256'],
               'player_sha256': manifest['player_sha256'], 'case_sha256': manifest['case_sha256'],
               'trace_frames': len(rows), 'events': event_totals, 'screenshots': inventory,
               'settlements': [event for event in selected if '/countScore()' in event['method']],
               'limits': ['Controlled original-method setup; no raw health/score/outcome writes.',
                          'Date/Tween wall time and explicit logical steps are distinct.',
                          'Encrypted score getters/setters are observed original calls; stale private slots are not their oracle.']}
    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    return summary


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--pictures', nargs='*', default=[])
    arguments = parser.parse_args()
    result = curate(arguments.run, arguments.output, arguments.pictures)
    print(json.dumps({key: result[key] for key in ['trace_frames', 'events', 'settlements']}, indent=2))
