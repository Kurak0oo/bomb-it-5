"""Summarizes the #84 mode x difficulty AI traces (make_cases.py). Per run: each AI's live
profile from the opening focus snapshot (answer time, find range, ordered state classes and
their StateSettings) and, from the AI-package call events, the decision cadence, the
transition checks made and passed per state, the states entered, and path searches.
Usage: summarize.py RUN_DIR [RUN_DIR...] (prints JSON)."""
import collections
import importlib.util
import json
import sys
from pathlib import Path

_spec = importlib.util.spec_from_file_location('mode_summary', Path(__file__).resolve().parents[1] / 'modes' / 'summarize.py')
_modes = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_modes)
named = _modes.named


def short(name):
    return (name or '').split('::')[-1]


def profile(run):
    focus = json.loads((run / 'opening-board.json').read_text())
    layouts = focus['layouts']
    result, owners = [], {}
    for index, ai in enumerate(focus['ai']):
        control = named(layouts, ai['control'])
        machine = named(layouts, ai['machine'])
        states = []
        for ref in machine['states']['elements']:
            record = ai['states'][ref['$ref']]
            settings = named(layouts, record['settings']) if record.get('settings') else {}
            states.append({'class': short(ref['class']), **{k: v for k, v in settings.items() if not isinstance(v, dict)}})
            owners[ref['$ref']] = index
        owners[control['defaultStats']['$ref']] = index
        result.append({'robot': control.get('robotNum'), 'answer_time': control.get('aiAnswerTime'),
                       'find_range': control.get('findRange'), 'default': short(control['defaultStats']['class']),
                       'states': states})
    return result, owners


def events(run, owners):
    calls, counts, passed, entered, frames = {}, collections.Counter(), collections.Counter(), [], set()
    updates, perceptions, searches = collections.Counter(), 0, collections.Counter()
    for path in sorted((run / 'events').glob('f*.json')):
        data = json.loads(path.read_text())
        if data.get('dropped') or data.get('overflow'):
            raise ValueError(f'{path}: event loss')
        for event in data['events']:
            frame = event.get('frame_label')
            if event['kind'] == 'enter':
                method = event['method']
                calls[event['call']] = method
                if method.endswith('AIControl/update()'):
                    updates[frame] += 1
                    frames.add(frame)
                elif method.endswith('AIControl/updatePerceptions()'):
                    perceptions += 1
                elif method.endswith('/checkTransitions()'):
                    counts[short(method.split('/')[0])] += 1
                elif method.endswith('AbstractState/enter()') or method.endswith('AbstractAttackState/enter()'):
                    receiver = event['receiver']
                    entered.append([frame, owners.get(receiver['$ref']), short(receiver['class'])])
                elif method.endswith('RoadSearch/findPath()'):
                    searches['calls'] += 1
            elif event['kind'] == 'return' and calls.get(event['call'], '').endswith('/checkTransitions()'):
                # A passing check returns its state; a failing one returns null.
                if isinstance(event.get('result'), dict):
                    passed[short(calls[event['call']].split('/')[0])] += 1
    span = (min(frames), max(frames)) if frames else None
    return {'frames': span, 'updates_per_frame': dict(collections.Counter(updates.values())),
            'perception_updates': perceptions, 'checks': dict(counts), 'passed': dict(passed),
            'entered': entered, 'path_searches': searches['calls']}


def summarize(run):
    run = Path(run)
    ais, owners = profile(run)
    return {'run': run.name, 'ai': ais, 'trace': events(run, owners)}


if __name__ == '__main__':
    print(json.dumps([summarize(run) for run in sys.argv[1:]], indent=1))
