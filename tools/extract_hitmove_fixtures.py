"""Turn the recorded movement probes into replay fixtures for `HitMove` checks (#82).

    python tools/extract_hitmove_fixtures.py

Reads docs/evidence/reference-2026-10-19/movement/ (seed-42 Cinema board, key log, per-frame
human state) and writes tests/fixtures/hitmove-probes.json: board boxes, start position,
key events by frame counter and the recorded human x/y/velocity after each frame. Only
numbers derived from the evidence records; no SWF bytes.
"""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOVEMENT = ROOT / 'docs/evidence/reference-2026-10-19/movement'
CASES = {'motion': (MOVEMENT / 'motion-commands.jsonl', MOVEMENT / 'motion-frames.csv')}
for name in ['corridor-right', 'corridor-left', 'corridor-up', 'corridor-down',
             'cardinal-down', 'cardinal-left', 'cardinal-up']:
    CASES[name] = (MOVEMENT / 'supplement' / name / 'commands.jsonl', MOVEMENT / 'supplement' / name / 'frames.csv')


def board():
    boxes = []
    for row in csv.DictReader(open(MOVEMENT / 'opening-board.csv')):
        if row['box_present'] == 'True':
            boxes.append([int(row['x']), int(row['y'])])
    return boxes


def case(commands, frames):
    keys = []
    for line in open(commands):
        entry = json.loads(line)
        parts = entry['command'].split()
        if parts[0] in ('kd', 'ku'):
            keys.append([entry['frame'], parts[0], parts[1]])
    expected = []
    for row in csv.DictReader(open(frames)):
        if 'actors' in row:
            human = [a for a in json.loads(row['actors']) if a['ui'] == 0][0]
            expected.append([int(row['frame']), human['x'], human['y'], human['velocity'][0], human['velocity'][1], human['cell']])
        else:  # The first motion probe records the human's columns directly.
            expected.append([int(row['frame']), float(row['x']), float(row['y']), float(row['vx']), float(row['vy']),
                             [int(row['cell_x']), int(row['cell_y'])]])
    first = expected[0]
    start = [first[1] - first[3], first[2] - first[4]]
    return {'keys': keys, 'start': start, 'expected': expected}


def main():
    out = {'source': 'docs/evidence/reference-2026-10-19/movement (seed 42, recorded authority SWF)',
           'boxes': board(), 'cases': {name: case(*paths) for name, paths in CASES.items()}}
    path = ROOT / 'tests/fixtures/hitmove-probes.json'
    path.write_text(json.dumps(out, separators=(',', ':')) + '\n')
    print(path, {name: len(c['expected']) for name, c in out['cases'].items()})


if __name__ == '__main__':
    main()
