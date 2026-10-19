"""Recover flamer/held-weapon/hand timeline metadata, without exporting artwork."""
import argparse
import hashlib
import json
import re
import struct
import zlib
import xml.etree.ElementTree as ET
from pathlib import Path

from inspect_source_data import SWF_SHA256, tags
from inspect_swf_structure import Bits, shape_bounds, timeline, verify_xml


def rectangle(data, offset):
    bits = Bits(data, offset)
    width = bits.unsigned(5)
    return [bits.signed(width) / 20 for _ in range(4)], bits.next_byte()


def inspect(path):
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != SWF_SHA256:
        raise ValueError('Not the recorded publisher SWF')
    data = zlib.decompress(raw[8:]) if raw[:3] == b'CWS' else raw[8:]
    offset = (5 + 4 * (data[0] >> 3) + 7) // 8 + 4
    definitions, symbols = {}, {}
    for code, payload in tags(data, offset):
        if code in (2, 22, 32, 83, 39, 46, 84):
            definitions[struct.unpack_from('<H', payload)[0]] = (code, payload)
        if code == 76:
            cursor = 2
            for _ in range(struct.unpack_from('<H', payload)[0]):
                identity = struct.unpack_from('<H', payload, cursor)[0]
                cursor += 2
                end = payload.index(0, cursor)
                symbols[payload[cursor:end].decode('utf-8')] = identity
                cursor = end + 1
    roots = {name: identity for name, identity in symbols.items()
             if re.fullmatch(r'(thrower_(Up|Down|Left|Right)(_Play)?|_r0_(Up|Down|Left|Right))', name)}
    if len(roots) != 12:
        raise ValueError(f'Expected 12 selected named roots, found {len(roots)}')
    pending = list(roots.values())
    result = {}
    while pending:
        identity = pending.pop()
        if str(identity) in result:
            continue
        if identity not in definitions:
            result[str(identity)] = {'definition_not_decoded': True}
            continue
        code, payload = definitions[identity]
        item = {'tag': code, 'payload_sha256': hashlib.sha256(payload).hexdigest()}
        if code == 39:
            item.update(timeline(payload))
            display_list = {}
            inherited = []
            for frame in item['frame_events']:
                for event in frame:
                    if 'remove_depth' in event:
                        display_list.pop(event['remove_depth'], None)
                    if 'place' in event:
                        place = event['place']
                        state = dict(display_list.get(place['depth'], {})) if place['move'] else {}
                        state.update(place)
                        display_list[place['depth']] = state
                        if 'character_id' in place:
                            pending.append(place['character_id'])
                inherited.append([dict(display_list[depth]) for depth in sorted(display_list)])
            item['inherited_display_lists'] = inherited
        elif code in (46, 84):
            item['start_bounds'], cursor = rectangle(payload, 2)
            item['end_bounds'], cursor = rectangle(payload, cursor)
            if code == 84:
                item['start_edge_bounds'], cursor = rectangle(payload, cursor)
                item['end_edge_bounds'], cursor = rectangle(payload, cursor)
        else:
            item['shape_bounds'] = shape_bounds(payload)
        result[str(identity)] = item
    return {'swf_sha256': SWF_SHA256, 'roots': roots, 'definitions': result,
            'bounds_order': ['x_min', 'x_max', 'y_min', 'y_max'], 'units': 'source pixels',
            'limits': ['Metadata only; no shape paths, textures or artwork are exported.',
                       'Morph start/end RECTs are stored envelopes, not an evaluated intermediate outline.',
                       'Inherited source placements do not execute frame scripts or infer nested playback phase.',
                       'Unsupported tag/placement tails remain explicit; filters are not evaluated.',
                       'Actual per-frame Script bounds and endpoint getters are measured separately.']}


def verify(result, xml):
    definitions = result['definitions']
    sprites = {identity: {'character_id': int(identity), **item}
               for identity, item in definitions.items() if item.get('tag') == 39}
    clips, placements = verify_xml({'selected_timelines': sprites}, xml)
    checked = set()
    retained = False
    for event, element in ET.iterparse(xml, events=('start', 'end')):
        kind = element.get('type', '')
        identity = element.get('characterId', element.get('shapeId'))
        selected = identity in definitions and (kind.startswith('DefineShape') or kind.startswith('DefineMorphShape'))
        if event == 'start' and selected:
            retained = True
        if event == 'end' and selected:
            item = definitions[identity]
            for key, name in [('shape_bounds', 'shapeBounds'), ('start_bounds', 'startBounds'),
                              ('end_bounds', 'endBounds'), ('start_edge_bounds', 'startEdgeBounds'),
                              ('end_edge_bounds', 'endEdgeBounds')]:
                if key in item:
                    rect = element.find(name)
                    actual = [int(rect.get(axis)) / 20 for axis in ('Xmin', 'Xmax', 'Ymin', 'Ymax')]
                    if actual != item[key]:
                        raise ValueError(f'XML bounds mismatch for {identity}.{key}')
            checked.add(identity)
            retained = False
        if event == 'end' and not retained:
            element.clear()
    expected = {identity for identity, item in definitions.items() if item.get('tag') in (2, 22, 32, 83, 46, 84)}
    if checked != expected:
        raise ValueError('XML did not independently verify every selected shape/morph envelope')
    return {'sprite_timelines': clips, 'placement_records': placements,
            'shape_and_morph_definitions': len(checked),
            'xml_sha256': hashlib.sha256(xml.read_bytes()).hexdigest()}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--swf', type=Path, default=Path('.scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf'))
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--verify-xml', type=Path)
    args = parser.parse_args()
    result = inspect(args.swf)
    if args.verify_xml:
        result['independent_xml_comparison'] = verify(result, args.verify_xml)
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
