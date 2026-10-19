"""Read edition 5 embedded rule data and sprite frame counts without exporting artwork."""
from pathlib import Path
import argparse
import hashlib
import json
import math
import struct
import xml.etree.ElementTree as ET
import zlib

SWF_SHA256 = '718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2'


def tags(data, offset=0):
    while offset < len(data):
        header = struct.unpack_from('<H', data, offset)[0]
        offset += 2
        code, length = header >> 6, header & 63
        if length == 63:
            length = struct.unpack_from('<I', data, offset)[0]
            offset += 4
        yield code, data[offset:offset + length]
        offset += length


def inspect(path):
    original = path.read_bytes()
    assert hashlib.sha256(original).hexdigest() == SWF_SHA256, 'Not the recorded publisher SWF'
    data = zlib.decompress(original[8:]) if original[:3] == b'CWS' else original[8:]
    offset = (5 + 4 * (data[0] >> 3) + 7) // 8 + 4
    sprites, symbols, xml = {}, {}, None
    for code, payload in tags(data, offset):
        if code == 39:
            ident, frames = struct.unpack_from('<HH', payload)
            sprites[ident] = frames
        elif code == 87 and struct.unpack_from('<H', payload)[0] == 6787:
            xml = payload[6:]
        elif code == 76:
            cursor = 2
            for _ in range(struct.unpack_from('<H', payload)[0]):
                ident = struct.unpack_from('<H', payload, cursor)[0]
                cursor += 2
                end = payload.index(0, cursor)
                symbols[payload[cursor:end].decode('utf-8')] = ident
                cursor = end + 1
    root = ET.fromstring(xml)
    normal_ai = root.find("./GameAI/ai[@id='010201']")
    actions = normal_ai.find('actions').get('name').split('|')
    names = ['sinker_Right_Play', 'lasergun_Play', 'fireball_Right_Play',
             'thrower_Right_Play', 'invincibityPlay', 'brickExp']
    return {
        'swf_sha256': SWF_SHA256,
        'embedded_xml_id': 6787,
        'embedded_xml_sha256': hashlib.sha256(xml).hexdigest(),
        'normal_ai_control': normal_ai.find('control').attrib,
        'normal_ai_actions': [root.find(f"./GameAI/action[@id='{action}']").attrib for action in actions],
        'arcade_integer_drop_weights': {item.tag: math.floor(float(item.get('value')) * 100 + 0.5)
                                        for item in root.find('./ArcadeMode/prop')},
        'animations': {name: {'symbol': symbols[name], 'frames': sprites[symbols[name]]} for name in names},
        'flamer_inner_animation': {'symbol': 2212, 'frames': sprites[2212]},
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--swf', type=Path, default=Path('.scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf'))
    parser.add_argument('--output', type=Path, default=Path('docs/evidence/edition-5-runtime-data.json'))
    args = parser.parse_args()
    result = inspect(args.swf)
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(f'Inspected publisher rule data: {args.output}')
