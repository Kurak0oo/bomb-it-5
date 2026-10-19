"""Read the purpose-built original-SWF focus schema without guessing missing state."""
import argparse
import json
from pathlib import Path


class FocusGraph:
    def __init__(self, state):
        if state.get('schema') != 'bombit5-reference-focus-v1':
            raise ValueError('Unrecognized focused reference schema')
        if not state.get('available'):
            raise ValueError('No original Game was available in this observation')
        if state.get('truncated'):
            raise ValueError('Focused reference observation is truncated')
        self.state = state
        self.layouts = state['layouts']
        self.records = {}
        self._index(state)

    @classmethod
    def read(cls, path):
        return cls(json.loads(Path(path).read_text(encoding='utf-8-sig')))

    def _index(self, value):
        if isinstance(value, list):
            for item in value:
                self._index(item)
        elif isinstance(value, dict):
            if value.get('$truncated'):
                raise ValueError('A focused reference value is truncated')
            if all(key in value for key in ('id', 'class', 'values')):
                previous = self.records.get(value['id'])
                if previous is not None and previous != value:
                    raise ValueError(f'Conflicting records for {value["id"]}')
                self.records[value['id']] = value
            for item in value.values():
                self._index(item)

    def node(self, value):
        if isinstance(value, str):
            identity = value
        elif isinstance(value, dict):
            if value.get('$truncated'):
                raise ValueError('Truncated reference')
            identity = value.get('id', value.get('$ref'))
        else:
            raise ValueError(f'Expected recorded object/reference, got {value!r}')
        if identity not in self.records:
            raise KeyError(f'{identity} has reference metadata only; its slots were not projected')
        return self.records[identity]

    def slot_ids(self, record, name, namespace=None):
        record = self.node(record)
        return sorted({entry['slot'] for entry in self.layouts[record['class']]['slots']
                       if any(alias == name and (namespace is None or ns == namespace)
                              for alias, ns in entry['aliases'])})

    def field(self, record, name, namespace=None):
        record = self.node(record)
        ids = self.slot_ids(record, name, namespace)
        if not ids:
            raise KeyError(f'{record["class"]}.{name} is not a stored slot')
        if len(ids) != 1:
            raise ValueError(f'Ambiguous physical slots for {record["class"]}.{name}: {ids}')
        key = str(ids[0])
        if key not in record['values']:
            raise KeyError(f'{record["class"]}.{name} was intentionally omitted')
        return record['values'][key]

    def fields(self, record, names):
        return {name: self.field(record, name) for name in names}

    @staticmethod
    def primitive(value):
        if value is None or isinstance(value, (str, int, float, bool)):
            return value
        raise ValueError(f'Expected primitive value, got {value!r}')

    def primitive_field(self, record, name, namespace=None):
        return self.primitive(self.field(record, name, namespace))

    @staticmethod
    def array(value):
        if not isinstance(value, dict) or value.get('class') != 'Array':
            raise ValueError('Expected an inline original Array projection')
        if value.get('$truncated') or 'elements' not in value:
            raise ValueError('Array elements were not completely projected')
        if len(value['elements']) != value['length']:
            raise ValueError('Array storage length does not match projected elements')
        return value['elements']  # Holes remain explicit {$hole:true} values.

    @staticmethod
    def display(value):
        if not isinstance(value, dict) or 'display' not in value:
            raise ValueError('Native display state was not projected')
        return value['display']

    def physical(self, view):
        return self.display(self.field(view, '_container'))

    def by_class(self, class_name):
        return [record for record in self.records.values() if record['class'] == class_name]

    def human(self):
        actors = [actor for actor in self.state['robots']
                  if actor['robot']['class'] == 'zlong.bombit5.gameengine.robot::PersonRobot']
        if len(actors) != 1:
            raise ValueError(f'Expected one projected PersonRobot, found {len(actors)}')
        return actors[0]

    def verify_against_full(self, full):
        """Verify retained data against an actual same-process, same-boundary graph."""
        if full.get('schema') != 'bombit5-reference-graph-v1' or full.get('truncated'):
            raise ValueError('Verification requires a complete full reference graph')
        objects = full['objects']
        counts = dict(records=0, values=0, arrays=0, functions=0, displays=0, nodes=0,
                      display_fields=0, unverified_native_fields={})

        def unverified(name):
            fields = counts['unverified_native_fields']
            fields[name] = fields.get(name, 0) + 1

        def normalize(value):
            counts['values'] += 1
            if not isinstance(value, dict) or '$ref' not in value:
                return value
            identity = value['$ref']
            original = objects[identity]
            if value['class'] != original['class']:
                raise ValueError(f'Class mismatch for {identity}')
            if 'elements' in value:
                counts['arrays'] += 1
                if (value['length'] != original['array_length'] or
                        [normalize(item) for item in self.array(value)] != original['elements']):
                    raise ValueError(f'Array mismatch for {identity}')
            if 'function' in value:
                counts['functions'] += 1
                if value['function'] != original['function']:
                    raise ValueError(f'Function mismatch for {identity}')
                if 'receiver' in value and normalize(value['receiver']) != original['receiver']:
                    raise ValueError(f'Receiver mismatch for {identity}')
            if 'display' in value:
                counts['displays'] += 1
                for key, item in value['display'].items():
                    if key in ('x', 'y', 'current_frame') and key in original.get('display', {}):
                        counts['display_fields'] += 1
                        if original['display'][key] != item:
                            raise ValueError(f'Display mismatch for {identity}.{key}')
                    else:
                        unverified(f'display.{key}')
            # The original full observer has no geometry/bounds oracle. Added
            # native metadata is explicitly outside this comparison's claim.
            for key in set(value) - {'$ref', 'class', 'length', 'elements', 'function',
                                     'receiver', 'display', 'point'}:
                unverified(key)
            if 'point' in value:
                fields = {slot['name']: slot['value'] for slot in original['slots']}
                if any(normalize(item) != fields[key] for key, item in value['point'].items()):
                    raise ValueError(f'Point mismatch for {identity}')
            return {'$ref': identity}

        for identity, record in self.records.items():
            original = objects[identity]
            if original['class'] != record['class']:
                raise ValueError(f'Record class mismatch for {identity}')
            slots = {str(slot['slot']): slot['value'] for slot in original['slots']}
            for slot_id, value in record['values'].items():
                if normalize(value) != slots[slot_id]:
                    raise ValueError(f'Slot mismatch for {record["class"]} slot {slot_id}')
            aliases = {str(row['slot']): set(map(tuple, row['aliases']))
                       for row in self.layouts[record['class']]['slots']}
            expected = {}
            for slot in original['slots']:
                expected.setdefault(str(slot['slot']), set()).add((slot['name'], slot['namespace']))
            if aliases != expected:
                raise ValueError(f'Namespace layout mismatch for {record["class"]}')
            counts['records'] += 1
        for node in self.state['nodes']:
            slots = {slot['name']: slot['value'] for slot in objects[node['id']]['slots']}
            for key, name in [('x', 'xGrid'), ('y', 'yGrid'), ('blocked', 'isBlock'),
                              ('cost', 'costMultiplier')]:
                if normalize(node[key]) != slots[name]:
                    raise ValueError(f'Search-cell flag mismatch for {node["id"]}')
            counts['nodes'] += 1
        return counts


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('state', type=Path)
    parser.add_argument('--verify-full', type=Path)
    args = parser.parse_args()
    graph = FocusGraph.read(args.state)
    result = {'records': len(graph.records), 'cells': len(graph.state['cells']),
              'source': str(args.state)}
    if args.verify_full:
        result['same_boundary_comparison'] = graph.verify_against_full(
            json.loads(args.verify_full.read_text(encoding='utf-8-sig')))
    print(json.dumps(result, indent=2))
