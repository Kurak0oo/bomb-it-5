"""Summarize a pause/resume reference trace (#81): per frame, the human's position and speed,
the game's pause flags, the round clock and the commands log around it.

    python tools/inspect_pause_trace.py RUN_DIR
"""
import argparse
import csv
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inspect_reference_focus import FocusGraph  # noqa: E402


def frame_rows(run, trace='pause-trace'):
    rows = []
    for path in sorted((run / trace).glob('f*.json'), key=lambda p: int(re.findall(r'\d+', p.name)[-1])):
        graph = FocusGraph.read(path)
        human = graph.human()
        view = graph.node(human['view'])
        game = graph.node(graph.state['game'])
        row = {'frame': int(re.findall(r'\d+', path.name)[-1])}
        physical = graph.physical(view)
        row['x'] = round(physical['x'] - 183, 3)
        row['y'] = round(physical['y'] - 40, 3)
        for name in ('gamePaused', 'pastTime', 'pastSecond', '_gameDeactive', '_pauseHelp'):
            try:
                value = graph.field(game, name)
                row[name] = value if not isinstance(value, dict) else value.get('class')
            except (KeyError, ValueError):
                row[name] = None
        rows.append(row)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    parser.add_argument('--trace', default='pause-trace', help='focus-trace folder inside RUN')
    args = parser.parse_args()
    rows = frame_rows(args.run, args.trace)
    out = args.run / (args.trace.replace('-trace', '') + '-frames.csv')
    with open(out, 'w', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    print(out, len(rows))


if __name__ == '__main__':
    main()
