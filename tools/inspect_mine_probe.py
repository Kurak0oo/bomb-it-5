"""Extract stored original landmine state; never execute ActionScript getters."""
import argparse
import json
from pathlib import Path

from inspect_chain_probe import inspect, selected, state as chain_state
from inspect_reference_focus import FocusGraph


def mine_state(path, frame):
    result = chain_state(path, frame)
    if not result['available']:
        return result
    raw = json.loads(path.read_text(encoding='utf-8'))
    graph = FocusGraph(raw)
    result['bombs'] = []
    for bomb in raw['bombs'].values():
        result['bombs'].append({'id': bomb['id'], 'class': bomb['class'], **graph.fields(bomb,
            ['_bombAdder', '_xN', '_yN', '_time', '_blastTime', '_isBlast', '_bombPow',
             '_continueTime', '_engineArr', '_mc', '_container']), **{
                name: graph.field(bomb, name) for name in ('_hasOutLandBomb', '_robot')
                if graph.slot_ids(bomb, name)}})
    for actor in result['actors']:
        reference = actor['robot']
        original = next((item for item in raw['robots'] if item['robot']['id'] == reference), None)
        if original:
            actor.update(graph.fields(original['model'], ['allowBomb', 'bombArr', 'bombPow', 'robotDirect']))
    result['equipment'] = []
    for index, item in enumerate(raw['robots']):
        for equipment in item['equipment'].values():
            result['equipment'].append({'projected_actor_index': index, 'id': equipment['id'],
                'class': equipment['class'], **{name: graph.field(equipment, name)
                    for name in ('_weaponName', 'currentUseNum', 'totalUseNum', 'weaponPlay', 'bomb', 'robot')
                    if graph.slot_ids(equipment, name)}})
    return result


def mine_selected(event):
    method = event.get('method', '')
    return selected(event) or 'Landmine' in method or 'items.weapons::' in method or (
        '::RobotController/' in method and any(word in method for word in
            ('/addBomb', '/deleteBomb', '/initWeapon', '/initBombHandle', '/robot_addBoomHandler')))


def extract(run, output):
    # Shared event extraction verifies original enter/return balance and zero loss.
    inspect(run, output, event_filter=mine_selected)
    manifest = json.loads((run / 'manifest.json').read_text(encoding='utf-8-sig'))
    names = [item['name'] for item in manifest['states']]
    if len(names) != len(set(names)):
        raise ValueError('Duplicate checkpoint names would overwrite original evidence')
    checkpoints = []
    for item in manifest['states']:
        path = run / (item['name'] + '.json')
        state = mine_state(path, item['frame'])
        if state['source_sha256'] != item['sha256']:
            raise ValueError('Checkpoint hash mismatch')
        checkpoints.append({'name': item['name'], **state})
    frames = [mine_state(path, int(path.stem[1:])) for path in sorted((run / 'frames').glob('f*.json'))]
    for name, rows in [('checkpoints.json', checkpoints), ('timeline.json', frames)]:
        (output / name).write_text(json.dumps(rows, separators=(',', ':')) + '\n')
    index_path = output / 'extract.json'
    index = json.loads(index_path.read_text(encoding='utf-8-sig'))
    index['schema'] = 'bombit5-mine-extract-v1'
    index['limits'].append('Only projected equipment slots are extracted; exhausted detached weapons need event evidence.')
    index_path.write_text(json.dumps(index, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    extract(args.run, args.output)
