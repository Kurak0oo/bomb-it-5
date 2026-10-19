"""Project stored original-SWF observations; this is not a gameplay implementation."""
import argparse
import json
from pathlib import Path


class ReferenceGraph:
    def __init__(self, state):
        if state.get('schema') not in ('bombit5-reference-graph-v1', 'bombit5-reference-compact-graph-v1'):
            raise ValueError('Unrecognized reference graph')
        self.state = state
        self.objects = state['objects']

    def node(self, value):
        if not isinstance(value, dict) or '$ref' not in value or value.get('$truncated'):
            raise ValueError(f'Expected an observed object reference, got {value}')
        return self.objects[value['$ref']]

    def field(self, node, name):
        values = [slot['value'] for slot in node['slots'] if slot['name'] == name]
        if not values:
            raise KeyError(f'{node["class"]}.{name} not observed')
        # Inherited protected aliases can name the same slot repeatedly. Distinct
        # namespace values are ambiguous; never silently select one of those.
        if any(value != values[0] for value in values):
            raise ValueError(f'Ambiguous namespaces for {node["class"]}.{name}')
        return values[0]

    def array(self, value):
        node = self.node(value)
        if node['class'] != 'Array' or node.get('elements_truncated'):
            raise ValueError('Expected a complete observed Array')
        return node['elements']

    def fields(self, node, names):
        return {name: self.field(node, name) for name in names}

    def physical(self, node):
        container = self.node(self.field(node, '_container'))
        return {key: container['display'][key] for key in ['x', 'y']}

    def summary(self):
        games = [node for node in self.objects.values() if node['class'] == 'zlong.bombit5.gameengine::Game']
        if len(games) != 1:
            raise ValueError(f'Expected one observed Game, found {len(games)}')
        game = games[0]
        engine = self.node(self.field(game, 'gameEngine'))
        result = {'truncated': self.state['truncated'],
                  'game': self.fields(game, ['gameMode', 'gameDiff', 'playerCount', 'gameStarted',
                                            'gamePaused', 'gameOver', 'gameTime', 'pastTime', 'currentLevel']),
                  'actors': [], 'bombs': [], 'grid': [], 'callbacks': {}}
        for reference in self.array(self.field(game, 'players')):
            player = self.node(reference)
            robot = self.node(self.field(player, '_robot'))
            model = self.node(self.field(robot, 'model'))
            view = self.node(self.field(robot, 'view'))
            actor = {'name': self.field(robot, 'name'), 'player_class': player['class'],
                     'life': self.field(player, '_life'), 'physical': self.physical(view),
                     'model': self.fields(model, ['robotID', 'currentX', 'currentY', 'state',
                                                 'currentState', 'vehicle', 'currentVehicle',
                                                 'robotDirect', 'velocity', 'robotVelocity',
                                                 'bombNum', 'allowBomb', 'bombPow'])}
            result['actors'].append(actor)
        bomb_refs = {}
        for name in ['_bombArr', '_blastArr', '_sequenceArr', '_aiSequenceArr', '_engineArr',
                     '_moveArr', '_tweenArr', '_brickExpArr', '_deadArr']:
            callbacks = self.array(self.field(engine, name))
            result['callbacks'][name] = []
            for reference in callbacks:
                callback = self.node(reference)
                result['callbacks'][name].append(callback.get('function', callback['class']))
                receiver = callback.get('receiver')
                if receiver and self.node(receiver)['class'] == 'zlong.bombit5.bombs::Bomb':
                    bomb_refs[receiver['$ref']] = receiver
        map_node = self.node(self.field(game, 'map'))
        for x, column in enumerate(self.array(self.field(map_node, 'mapArr'))):
            for y, reference in enumerate(self.array(column)):
                cell = self.node(reference)
                item = self.fields(cell, ['fire', 'fixedBox', 'fixedBoxMc', 'unfixedBox',
                                         '_midBox', '_null', '_other', 'box', 'prop', 'platForm'])
                for key in ['box', 'prop', 'platForm']:
                    item[key] = self.node(item[key])['class'] if item[key] else None
                item.update(x=x, y=y)
                result['grid'].append(item)
                for reference in self.array(self.field(cell, '_bombArr')):
                    if self.node(reference)['class'] == 'zlong.bombit5.bombs::Bomb':
                        bomb_refs[reference['$ref']] = reference
        for identity, reference in bomb_refs.items():
            bomb = self.node(reference)
            owner = self.field(bomb, '_bombAdder')
            entry = {'identity': identity, 'physical': self.physical(bomb),
                     'owner': self.field(self.node(owner), 'name') if owner else None,
                     **self.fields(bomb, ['_time', '_blastTime', '_isBlast', '_continueTime',
                                         '_bombPow', '_xN', '_yN'])}
            entry['owner_robot_id'] = self.field(self.node(self.field(self.node(owner), 'model')), 'robotID') if owner else None
            entry['blast_cells'] = [self.array(cell) for cell in self.array(self.field(bomb, '_blastArr'))]
            result['bombs'].append(entry)
        result['bombs'].sort(key=lambda bomb: (bomb['_xN'], bomb['_yN'], bomb['owner'] or ''))
        return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('state', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    summary = ReferenceGraph(json.loads(args.state.read_text(encoding='utf-8'))).summary()
    args.output.write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
