"""Inventory recovered edition 5 source and selected SWF timelines; no artwork export."""
from collections import Counter
from pathlib import Path
import argparse
import hashlib
import json
import re
import struct
import xml.etree.ElementTree as ET
import zlib

from inspect_source_data import SWF_SHA256, tags


class Bits:
    def __init__(self, data, offset=0):
        self.data = data
        self.position = offset * 8

    def unsigned(self, width):
        value = 0
        for _ in range(width):
            byte, bit = divmod(self.position, 8)
            value = (value << 1) | ((self.data[byte] >> (7 - bit)) & 1)
            self.position += 1
        return value

    def signed(self, width):
        value = self.unsigned(width)
        return value - (1 << width) if width and value & (1 << (width - 1)) else value

    def next_byte(self):
        return (self.position + 7) // 8


def matrix(data, offset):
    bits = Bits(data, offset)
    scale = [1.0, 1.0]
    skew = [0.0, 0.0]
    if bits.unsigned(1):
        width = bits.unsigned(5)
        scale = [bits.signed(width) / 65536 for _ in range(2)]
    if bits.unsigned(1):
        width = bits.unsigned(5)
        skew = [bits.signed(width) / 65536 for _ in range(2)]
    width = bits.unsigned(5)
    translation = [bits.signed(width) / 20 for _ in range(2)]
    return {"scale": scale, "skew": skew, "translation_pixels": translation}, bits.next_byte()


def shape_bounds(data):
    bits = Bits(data, 2)
    width = bits.unsigned(5)
    return [bits.signed(width) / 20 for _ in range(4)]


def place_object(data, version):
    flag_bytes = 2 if version == 3 else 1
    flags = int.from_bytes(data[:flag_bytes], 'little')
    result = {"version": version, "depth": struct.unpack_from('<H', data, flag_bytes)[0], "move": bool(flags & 1)}
    cursor = flag_bytes + 2
    if flags & 2048 or (flags & 4096 and not flags & 2):
        end = data.index(0, cursor)
        result['class_name'] = data[cursor:end].decode('utf-8')
        cursor = end + 1
    if flags & 2:
        result['character_id'] = struct.unpack_from('<H', data, cursor)[0]
        cursor += 2
    if flags & 4:
        result['matrix'], cursor = matrix(data, cursor)
    if flags & 8:
        bits = Bits(data, cursor)
        has_add, has_mult, width = bits.unsigned(1), bits.unsigned(1), bits.unsigned(4)
        if has_mult:
            result['color_multiply'] = [bits.signed(width) for _ in range(4)]
        if has_add:
            result['color_add'] = [bits.signed(width) for _ in range(4)]
        cursor = bits.next_byte()
    if flags & 16:
        result['ratio'] = struct.unpack_from('<H', data, cursor)[0]
        cursor += 2
    if flags & 32:
        end = data.index(0, cursor)
        result['instance_name'] = data[cursor:end].decode('utf-8')
        cursor = end + 1
    if flags & 64:
        result['clip_depth'] = struct.unpack_from('<H', data, cursor)[0]
        cursor += 2
    optional = flags & (128 | 256 | 512 | 1024 | 8192 | 16384)
    if optional:
        result['unparsed_optional_flags'] = optional
        result['unparsed_tail_sha256'] = hashlib.sha256(data[cursor:]).hexdigest()
    return result


def timeline(payload):
    declared = struct.unpack_from('<H', payload, 2)[0]
    frames, events = [], []
    unparsed = Counter()
    for code, data in tags(payload, 4):
        if code == 1:
            frames.append(events)
            events = []
        elif code in (26, 70):
            events.append({"place": place_object(data, 2 if code == 26 else 3)})
        elif code == 28:
            events.append({"remove_depth": struct.unpack_from('<H', data)[0]})
        elif code == 43:
            events.append({"label": data.split(b'\0', 1)[0].decode('utf-8')})
        elif code not in (0,):
            # Preserve the existence of unsupported tags; never imply a complete timeline decoder.
            unparsed[code] += 1
            events.append({"unparsed_tag": code, "bytes": len(data),
                           "sha256": hashlib.sha256(data).hexdigest()})
    if len(frames) != declared:
        raise ValueError(f'Sprite declares {declared} frames, contains {len(frames)} ShowFrame tags')
    return {"frames": declared, "frame_events": frames, "unparsed_tags": dict(unparsed)}


def source_inventory(source):
    records = []
    for path in sorted((source / 'zlong/bombit5').rglob('*.as')):
        raw = path.read_bytes()
        text = raw.decode('utf-8-sig')
        classes = re.findall(r'\bclass\s+(\w+)(?:\s+extends\s+([\w.]+))?', text)
        methods = re.findall(r'\bfunction\s+(?:(get|set)\s+)?(\w+)\s*\(', text)
        records.append({"file": path.relative_to(source).as_posix(),
                        "sha256": hashlib.sha256(raw).hexdigest(),
                        "classes": [{"name": name, "extends": base or None} for name, base in classes],
                        "method_declarations": len(methods)})
    groups = Counter(Path(record['file']).parts[2] if len(Path(record['file']).parts) > 3
                     else '(package root)' for record in records)
    return records, dict(sorted(groups.items()))


def inspect(swf, source):
    original = swf.read_bytes()
    if hashlib.sha256(original).hexdigest() != SWF_SHA256:
        raise ValueError('Not the recorded publisher SWF')
    data = zlib.decompress(original[8:]) if original[:3] == b'CWS' else original[8:]
    offset = (5 + 4 * (data[0] >> 3) + 7) // 8 + 4
    sprites, symbols, bounds, counts, abc = {}, {}, {}, Counter(), []
    for code, payload in tags(data, offset):
        counts[code] += 1
        if code == 39:
            sprites[struct.unpack_from('<H', payload)[0]] = payload
        elif code in (2, 22, 32, 83):
            bounds[struct.unpack_from('<H', payload)[0]] = shape_bounds(payload)
        elif code == 76:
            cursor = 2
            for _ in range(struct.unpack_from('<H', payload)[0]):
                character = struct.unpack_from('<H', payload, cursor)[0]
                cursor += 2
                end = payload.index(0, cursor)
                symbols[payload[cursor:end].decode('utf-8')] = character
                cursor = end + 1
        elif code == 82:
            end = payload.index(0, 4)
            abc.append({"name": payload[4:end].decode('utf-8'),
                        "sha256": hashlib.sha256(payload[end + 1:]).hexdigest(),
                        "bytes": len(payload) - end - 1})
    pattern = r'(exp0|bomb0|(?:sinker|lasergun|thrower|fireball)(?:_(?:Right|Left|Up|Down))?_Play|invincibityPlay|brickExp)'
    selected = {name: ident for name, ident in symbols.items() if re.fullmatch(pattern, name)}
    selected['flamer_inner'] = 2212
    clips = {name: {"character_id": ident, **timeline(sprites[ident])} for name, ident in selected.items()}
    for name, clip in clips.items():
        script = source / f'{name}.as'
        if script.exists():
            raw = script.read_bytes()
            clip['class_source'] = {"file": script.relative_to(source).as_posix(),
                                    "sha256": hashlib.sha256(raw).hexdigest()}
    references = {event['place']['character_id'] for clip in clips.values()
                  for frame in clip['frame_events'] for event in frame
                  if 'place' in event and 'character_id' in event['place']}
    children = {}
    for ident in sorted(references):
        item = {}
        if ident in sprites:
            item['sprite_frames'] = struct.unpack_from('<H', sprites[ident], 2)[0]
        if ident in bounds:
            item['shape_bounds_pixels_xmin_xmax_ymin_ymax'] = bounds[ident]
        children[str(ident)] = item or {"definition_not_decoded": True}
    records, groups = source_inventory(source)
    return {"status": "static_metadata_only_not_runtime_or_fidelity_verification",
            "swf": {"sha256": SWF_SHA256, "bytes": len(original), "abc_blocks": abc,
                    "named_symbols": len(symbols), "sprites": len(sprites), "root_tag_counts": dict(counts)},
            "source": {"files": len(records), "groups": groups, "records": records,
                       "parser_limit": "Class/method counts are lexical declarations, not a resolved call graph; decompiled output is not original author source."},
            "selected_timelines": clips, "direct_child_metadata": children,
            "timeline_limits": ["Placement matrices are source pixels; this is not a rendering or bounds evaluator.",
                                "PlaceObject2/3 placement fields, RemoveObject2, frame labels and ShowFrame are decoded; other tags remain explicitly unparsed.",
                                "Filters, blend/cache/visibility fields and clip actions remain explicitly unparsed tails; they are not evaluated.",
                                "Inherited display-list state, nested playback, morph geometry, frame scripts and runtime transforms need further reconstruction."]}


def verify_xml(result, path):
    """Compare decoded placement geometry with an independent FFDec SWF-to-XML export."""
    wanted = {clip['character_id']: clip for clip in result['selected_timelines'].values()}
    retained = False
    checked, placements = set(), 0
    for event, element in ET.iterparse(path, events=('start', 'end')):
        kind = element.get('type')
        if event == 'start' and kind == 'DefineSpriteTag' and int(element.get('spriteId')) in wanted:
            retained = True
        if retained and event == 'end' and kind == 'DefineSpriteTag':
            ident = int(element.get('spriteId'))
            clip = wanted[ident]
            if int(element.get('frameCount')) != clip['frames']:
                raise ValueError(f'Frame-count mismatch for sprite {ident}')
            expected = [(index, entry['place']) for index, frame in enumerate(clip['frame_events'], 1)
                        for entry in frame if 'place' in entry]
            actual, frame_index = [], 1
            for entry in element.find('subTags'):
                if entry.get('type') == 'ShowFrameTag':
                    frame_index += 1
                elif entry.get('type') in ('PlaceObject2Tag', 'PlaceObject3Tag'):
                    actual.append((frame_index, entry))
            if len(expected) != len(actual):
                raise ValueError(f'Placement-count mismatch for sprite {ident}')
            for (parsed_frame, parsed), (exported_frame, exported) in zip(expected, actual):
                if parsed_frame != exported_frame:
                    raise ValueError(f'Placement-frame mismatch for sprite {ident}')
                for key, attribute in [('depth', 'depth'), ('character_id', 'characterId'), ('ratio', 'ratio')]:
                    if key in parsed and parsed[key] != int(exported.get(attribute)):
                        raise ValueError(f'{key} mismatch for sprite {ident}')
                if parsed['move'] != (exported.get('placeFlagMove') == 'true'):
                    raise ValueError(f'Move mismatch for sprite {ident}')
                if parsed.get('instance_name') != exported.get('name'):
                    raise ValueError(f'Name mismatch for sprite {ident}')
                if 'matrix' in parsed:
                    matrix_xml = exported.find('matrix')
                    fields = [('scale', ['scaleX', 'scaleY'], 1, 1),
                              ('skew', ['rotateSkew0', 'rotateSkew1'], 0, 1),
                              ('translation_pixels', ['translateX', 'translateY'], 0, 20)]
                    for key, attributes, default, divisor in fields:
                        values = [float(matrix_xml.get(attribute, default)) / divisor for attribute in attributes]
                        if any(abs(left - right) > 0.00001 for left, right in zip(parsed['matrix'][key], values)):
                            raise ValueError(f'Matrix {key} mismatch for sprite {ident}')
                placements += 1
            checked.add(ident)
            retained = False
        if event == 'end' and not retained:
            element.clear()
    if checked != set(wanted):
        raise ValueError('XML did not verify every selected sprite')
    return len(checked), placements


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--swf', type=Path, default=Path('.scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf'))
    parser.add_argument('--source', type=Path, default=Path('.scratch/edition-5-research/publisher-scripts/scripts'))
    parser.add_argument('--output', type=Path, default=Path('docs/evidence/edition-5-structure-inventory.json'))
    parser.add_argument('--verify-xml', type=Path, help='Optional independent JPEXS -swf2xml export')
    args = parser.parse_args()
    result = inspect(args.swf, args.source)
    if args.verify_xml:
        clips, placements = verify_xml(result, args.verify_xml)
        print(f'PASS: {clips} timelines and {placements} placement records agree with FFDec XML for compared fields')
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(f'Inspected {result["source"]["files"]} game source files and {len(result["selected_timelines"])} timelines: {args.output}')
