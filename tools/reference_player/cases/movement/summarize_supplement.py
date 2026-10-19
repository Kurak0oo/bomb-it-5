"""Curate supplemental source-original cardinal/portal cases without changing a game."""
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


def optional(graph, record, name):
    return graph.field(record, name) if graph.slot_ids(record, name) else None


def project(path, frame):
    graph = FocusGraph.read(path)
    actors = []
    for actor in graph.state['robots']:
        robot, view, model = (actor[name] for name in ['robot', 'view', 'model'])
        player = graph.node(graph.field(robot, 'player'))
        commands = []
        for record in graph.records.values():
            if 'Command' not in record['class']:
                continue
            owners = [optional(graph, record, name) for name in ['robot', '_robot']]
            if not any(isinstance(owner, dict) and owner.get('$ref') == robot['id'] for owner in owners):
                continue
            commands.append({'id': record['id'], 'class': record['class'], **{
                name: graph.field(record, name) for name in ['_frameCount', '_totalFrame',
                    '_targetXGrid', '_targetYGrid', '_nvincibilityTimeCount', '_totalFrames', '_time', '_totalTime']
                if graph.slot_ids(record, name)}})
        physical = graph.physical(view)
        speed = graph.field(model, 'speed')['point']
        actors.append({'ui': graph.field(player, '_uiId'), 'robot': robot['id'],
                       'x': physical['x'] - 183, 'y': physical['y'] - 40,
                       'cell': [graph.field(model, 'currentX'), graph.field(model, 'currentY')],
                       'velocity': [speed['x'], speed['y']], 'state': graph.field(model, 'state'),
                       'damage_eligible': graph.field(robot, 'isExist'),
                       'vehicle': graph.field(model, 'vehicle'), 'shield': graph.field(model, 'shieldObj'),
                       'bomb_num': graph.field(model, 'bombNum'), 'power': graph.field(model, 'bombPow'),
                       'cur_organ': graph.field(robot, 'curOrgan'),
                       'busy': graph.field(actor['controller'], '_stageFunc'), 'commands': commands})
    actors.sort(key=lambda actor: actor['ui'])
    cells = []
    selected = {(1, 1), (1, 2), (2, 1), (3, 2), (3, 3), (13, 10), (13, 11),
                (13, 12), (13, 13), (14, 13), (15, 12), (15, 13)}
    for cell in graph.state['cells']:
        if (cell['x'], cell['y']) in selected:
            grid = cell['grid']
            cells.append({'x': cell['x'], 'y': cell['y'], **{name: graph.field(grid, name)
                          for name in ['fire', 'box', 'platForm', '_robot', '_bombArr']}})
    bombs = [{'id': record['id'], 'class': record['class'], **{
                name: graph.field(record, name) for name in ['_time', '_isBlast', '_continueTime',
                    '_hasOutLandBomb', '_bombPow', '_bombAdder', '_blastArr', '_xN', '_yN']
                if graph.slot_ids(record, name)}} for record in graph.records.values()
             if record['class'].startswith('zlong.bombit5.bombs::')]
    return {'frame': frame, 'actors': actors, 'cells': cells, 'bombs': bombs,
            'game_paused': graph.field(graph.state['game'], 'gamePaused'),
            'game_over': graph.field(graph.state['game'], 'gameOver')}


def curate(root, output, pictures):
    output.mkdir(parents=True, exist_ok=True)
    (output / '.gdignore').touch()
    manifest = json.loads((root / 'manifest.json').read_text(encoding='utf-8-sig'))
    boundaries = [{'name': item['name'], **project(root / (item['name'] + '.json'), item['frame'])}
                  for item in manifest['states'] if item['available']]
    (output / 'boundaries.json').write_text(json.dumps(boundaries, indent=2) + '\n', encoding='utf-8')
    paths = sorted((root / 'motion-trace').glob('f*.json')) + sorted((root / 'portal-trace').glob('f*.json'))
    with (output / 'frames.csv').open('w', newline='', encoding='utf-8') as stream:
        writer = csv.DictWriter(stream, fieldnames=['frame', 'actors', 'cells', 'bombs', 'game_paused', 'game_over'])
        writer.writeheader()
        for path in paths:
            row = project(path, int(path.stem[1:]))
            writer.writerow({name: json.dumps(value, separators=(',', ':')) if isinstance(value, (list, dict))
                             else value for name, value in row.items()})
    selected = []
    calls = {}
    totals = {'events': 0, 'dropped': 0, 'overflow_files': 0, 'errors': 0}
    for folder in ['movement-events', 'portal-events']:
        for path in sorted((root / folder).glob('*.json')):
            data = json.loads(path.read_text(encoding='utf-8-sig'))
            totals['events'] += len(data['events'])
            totals['dropped'] += data['dropped']
            totals['overflow_files'] += int(data['overflow'])
            for event in data['events']:
                if event['kind'] == 'error':
                    totals['errors'] += 1
                if event['kind'] == 'enter':
                    method = event['method']
                    keep = any(name in method for name in ['::SendRobotCommand/', '::Portal/runEngine()',
                        '::LandmineBomb/', '::LandminePlayCommand/', '::TryToKillCommandChain/',
                        '::GetFireCommand/execute()', '::Bomb/blast()', '::HitMove/',
                        '::Game/gamePause()', '::Game/doGamePause()', '::Game/gameResume()',
                        '::Game/doGameResume()', '::AbstractObject/get xN()', '::AbstractObject/get yN()'])
                    if keep:
                        item = {'call': event['call'], 'frame': event['frame_label'], 'method': method,
                                'receiver': event['receiver'], 'arguments': event['arguments']}
                        selected.append(item)
                        calls[event['call']] = item
                elif event['kind'] in ('return', 'error') and event['call'] in calls:
                    calls[event['call']].update(exit_frame=event['frame_label'], kind=event['kind'], result=event['result'])
    if totals['dropped'] or totals['overflow_files'] or totals['errors']:
        raise ValueError(f'Incomplete/erroring source observation: {totals}')
    (output / 'selected-events.json').write_text(json.dumps(selected, separators=(',', ':')) + '\n', encoding='utf-8')
    for name in ['case.json', 'manifest.json', 'commands.jsonl', 'player-stderr.log']:
        shutil.copyfile(root / name, output / name)
    for path in root.glob('fixture-*-result.json'):
        shutil.copyfile(path, output / path.name)
    inventory = []
    for name in pictures:
        target = output / (name + '.png')
        shutil.copyfile(root / target.name, target)
        inventory.append({'name': target.name, 'sha256': digest(target), 'bytes': target.stat().st_size})
    summary = {'raw_run': str(root), 'case_sha256': manifest['case_sha256'],
               'swf_sha256': manifest['swf_sha256'], 'player_sha256': manifest['player_sha256'],
               'trace_frames': len(paths), 'events': totals, 'screenshots': inventory,
               'limits': ['Selected native/raw source observations; no complete Flash equivalence claim.',
                          'Fixtures invoke original methods and do not implement new gameplay.',
                          'Position/state and original callback timing must be interpreted separately.']}
    (output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    return summary


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--pictures', nargs='*', default=[])
    args = parser.parse_args()
    result = curate(args.run, args.output, args.pictures)
    print(json.dumps({key: result[key] for key in ['trace_frames', 'events']}, indent=2))
