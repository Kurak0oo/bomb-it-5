"""Inventory the export, skip tiny fragments and duplicates, and guess workbench slots."""
import csv
import io
import re

import numpy as np
from PIL import Image

import slots
from common import EXPORT, MANIFEST, WORK, log, safe_name, sha256_bytes, write_json, write_text

SIZE = re.compile(r'<svg[^>]*?height="([\d.]+)px"[^>]*?width="([\d.]+)px"|<svg[^>]*?width="([\d.]+)px"[^>]*?height="([\d.]+)px"')
ORIGIN = re.compile(r'<g transform="matrix\(1\.0, 0\.0, 0\.0, 1\.0, (-?[\d.]+), (-?[\d.]+)\)">')
VOLATILE = re.compile(r'\s(?:ffdec:characterId|id)="[^"]*"')
CONTENT = re.compile(r'<(?:path|image|use|text)\b')
COLUMNS = ['key', 'type', 'source_id', 'name', 'width', 'height', 'frames', 'content_hash', 'slot', 'slot_basis',
           'duplicate_ids']


def svg_geometry(text):
    match = SIZE.search(text)
    if not match:
        return 0.0, 0.0, (0.0, 0.0)
    height, width = (match.group(1), match.group(2)) if match.group(1) else (match.group(4), match.group(3))
    origin = ORIGIN.search(text)
    return float(width), float(height), (float(origin.group(1)), float(origin.group(2))) if origin else (0.0, 0.0)


def read_symbols():
    names = {}
    path = EXPORT / 'symbolClass' / 'symbols.csv'
    if path.is_file():
        for line in path.read_text(encoding='utf-8').splitlines():
            ident, _, name = line.partition(';')
            if ident.strip().isdigit():
                names.setdefault(int(ident), name.strip().strip('"'))
    return names


def inventory():
    names = read_symbols()
    assets = []
    for path in sorted((EXPORT / 'shapes').glob('*.svg'), key=lambda p: int(p.stem)):
        text = path.read_text(encoding='utf-8')
        width, height, origin = svg_geometry(text)
        ident = int(path.stem)
        assets.append({'type': 'vector shape', 'id': ident, 'name': names.get(ident, ''), 'width': width,
                       'height': height, 'origin': origin, 'frames': [str(path)], 'empty': not CONTENT.search(text),
                       'hash': sha256_bytes(VOLATILE.sub('', text).encode())})
    for folder in sorted((EXPORT / 'sprites').glob('DefineSprite_*'), key=lambda p: int(p.name.split('_')[1])):
        frames = sorted(folder.glob('*.svg'), key=lambda p: int(p.stem))
        if not frames:
            continue
        ident = int(folder.name.split('_')[1])
        texts = [f.read_text(encoding='utf-8') for f in frames]
        width, height, origin = svg_geometry(texts[0])
        assets.append({'type': 'sprite', 'id': ident, 'name': names.get(ident, ''), 'width': width,
                       'height': height, 'origin': origin, 'frames': [str(f) for f in frames],
                       'empty': not any(CONTENT.search(t) for t in texts),
                       'hash': sha256_bytes('\n'.join(VOLATILE.sub('', t) for t in texts).encode())})
    for path in sorted((EXPORT / 'images').glob('*.*'), key=lambda p: int(p.stem)):
        image = Image.open(path).convert('RGBA')
        pixels = np.array(image)
        ident = int(path.stem)
        assets.append({'type': 'bitmap', 'id': ident, 'name': names.get(ident, ''), 'width': float(image.width),
                       'height': float(image.height), 'origin': (0.0, 0.0), 'frames': [str(path)],
                       'empty': not (pixels[..., 3] > 0).any(), 'hash': sha256_bytes(pixels.tobytes())})
    for asset in assets:
        prefix = {'vector shape': 'shape', 'sprite': 'sprite', 'bitmap': 'bitmap'}[asset['type']]
        asset['key'] = f'{prefix}_{asset["id"]}' + (f'_{safe_name(asset["name"])}' if asset['name'] else '')
    return assets


def resolve(reference, by_name, by_id):
    if reference.startswith('#'):
        return by_id.get(int(reference[1:]))
    return by_name.get(reference)


def source_references(source):
    if not source:
        return []
    return list(source.get('rows', [])) + ([source['sprite']] if 'sprite' in source else [])


def build(config):
    assets = inventory()
    skip = config['skip']
    kept, skipped, canonical = [], [], {}
    referenced = {r for slot in config['slots'].values() for r in source_references(slot['source'])}
    # Named assets win duplicate ties so slot sources and names stay readable.
    order = sorted(assets, key=lambda a: (a['name'] == '', a['type'] != 'sprite', a['id']))
    for asset in order:
        tiny = max(asset['width'], asset['height']) < skip['min_side'] or asset['width'] * asset['height'] < skip['min_area']
        if tiny and (asset['name'] in referenced or f'#{asset["id"]}' in referenced):
            tiny = False  # A slot source stays even when it is a small fragment.
        if asset['empty'] or tiny:
            skipped.append({'key': asset['key'], 'reason': 'empty' if asset['empty'] else 'tiny'})
            continue
        if asset['hash'] in canonical:
            canonical[asset['hash']]['duplicate_ids'].append(asset['id'])
            canonical[asset['hash']].setdefault('aliases', []).append(asset)
            skipped.append({'key': asset['key'], 'reason': 'duplicate of ' + canonical[asset['hash']]['key']})
            continue
        asset['duplicate_ids'] = []
        asset['slots'], asset['basis'] = [], []
        canonical[asset['hash']] = asset
        kept.append(asset)
    by_name, by_id = {}, {}
    for asset in kept:
        for alias in [asset] + asset.get('aliases', []):
            if alias['name']:
                by_name.setdefault(alias['name'], asset)
            by_id[alias['id']] = asset
    unresolved = []
    for slot in slots.entries():
        source = config['slots'][slot['id']]['source']
        for reference in source_references(source):
            asset = resolve(reference, by_name, by_id)
            if asset is None:
                unresolved.append(f'{slot["id"]}: {reference}')
                continue
            if slot['id'] not in asset['slots']:
                asset['slots'].append(slot['id'])
                frames = source.get('frames', 'all')
                asset['basis'].append('config ' + ('frame ' + ','.join(map(str, frames)) if isinstance(frames, list) else 'all frames'))
    kept.sort(key=lambda a: ({'sprite': 0, 'vector shape': 1, 'bitmap': 2}[a['type']], a['id']))
    buffer = io.StringIO()
    writer = csv.writer(buffer, lineterminator='\n')
    writer.writerow(COLUMNS)
    for asset in kept:
        writer.writerow([asset['key'], asset['type'], asset['id'], asset['name'], f'{asset["width"]:g}',
                         f'{asset["height"]:g}', len(asset['frames']), asset['hash'][:16],
                         ';'.join(asset['slots']) or 'unmapped', ';'.join(sorted(set(asset['basis']))),
                         ' '.join(map(str, sorted(asset['duplicate_ids'])))])
    write_text(MANIFEST, buffer.getvalue())
    for asset in kept:
        asset['alias_names'] = [a['name'] for a in asset.pop('aliases', []) if a['name']]
    write_json(WORK / 'inventory.json', {'assets': kept, 'skipped': skipped, 'unresolved_sources': unresolved})
    counts = {'kept': len(kept), 'skipped_tiny': sum(s['reason'] == 'tiny' for s in skipped),
              'skipped_empty': sum(s['reason'] == 'empty' for s in skipped),
              'skipped_duplicate': sum(s['reason'].startswith('duplicate') for s in skipped),
              'mapped': sum(bool(a['slots']) for a in kept), 'unresolved_sources': unresolved}
    log.info('Manifest: %s', counts)
    return kept, counts


def load():
    import json
    data = json.loads((WORK / 'inventory.json').read_text())
    for asset in data['assets']:
        asset['origin'] = tuple(asset['origin'])
    return data
