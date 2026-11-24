"""Where the original's `Math.random` stands when a recorded round starts (SWF machine).

    python3 tools/compare/round_draws.py gameplay-cinema-start   # -> tests/goldens/<case>/math_random.json

Godot does not reproduce the original's draws before the round (menus, the board, the AI
players' looks): the comparison loop's round takes its board from a golden instead
(`App.round_as_recorded`). The draws the round itself makes (a box's drop roll,
`Box.createProp`) can still follow the original's generator if the round's draws continue
from the same place. This replays the case with the reference player's event collector
(`events`: every `Math.random` call, its ordinal and the original methods it was made from)
up to the case's last capture, the round's first frame, and records:

- `pool_draws`: the ordinals drawn inside `AbstractGameMode.initMap` (one per Vehicle entry
  of the drop pool, `game.mapPropArr`), which Godot's round builds at its start;
- `draws_before_round`: every draw made through the capture's frame; the round's own
  draws continue from the next ordinal;
- `callers`: the innermost original method of each draw, run-length grouped (evidence).

The seed is the case's `seed N`. Same-seed draws come from scripts/simulation/avm_random.gd.
"""
import json
from pathlib import Path
import shutil
import sys
import tempfile

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import compare  # noqa: E402
from replay_reference import ReferenceSession, SWF_SHA256  # noqa: E402


def main():
    name = sys.argv[1]
    _, case, captures = compare.load_case(name)
    capture = captures[-1]
    swf = compare.DEFAULT_SWF
    if compare.sha256(swf) != SWF_SHA256:
        raise SystemExit('Not the recorded publisher SWF')
    seed = next(int(a['command'].split()[1]) for a in case['actions'] if a.get('command', '').startswith('seed '))
    work = Path(tempfile.mkdtemp(prefix='bombit5-draws-'))
    staged = work / 'original.swf'
    staged.write_bytes(swf.read_bytes())
    session = ReferenceSession(compare.default_player(), staged, work / 'session')
    frame = None
    try:
        enabled = False
        for action in case['actions']:
            if 'fixture' in action:
                session.fixture(action['fixture'])
            if 'command' in action:
                session.command(action['command'])
                if not enabled:
                    # After `seed N` (it must come before any frame), every original method.
                    session.command('events ev 200000 zlong.bombit5')
                    enabled = True
            if action.get('capture') == capture:
                frame = session.frame
                break
        session.command('events off')
    finally:
        session.close(check=False)
    draws = []
    for path in sorted((work / 'session' / 'ev').glob('*.json')):
        dump = json.loads(path.read_text(encoding='utf-8'))
        if dump.get('overflow'):
            raise SystemExit(f'{path.name}: event buffer overflow; the draw order is incomplete')
        for event in dump['events']:
            if event['kind'] == 'math_random':
                chain = event.get('selected_call_chain') or []
                method = chain[-1][1] if chain else ''
                draws.append({'draw': event['draw'], 'frame': event['frame_label'], 'raw': event['raw'], 'method': method})
    shutil.rmtree(work, ignore_errors=True)
    if [d['draw'] for d in draws] != list(range(1, len(draws) + 1)):
        raise SystemExit('draw ordinals are not consecutive from 1')
    callers = []
    for d in draws:
        if callers and callers[-1]['method'] == d['method'] and callers[-1]['frame'] == d['frame']:
            callers[-1]['last'] = d['draw']
        else:
            callers.append({'first': d['draw'], 'last': d['draw'], 'frame': d['frame'], 'method': d['method']})
    out = {'schema': 'bombit5-round-draws-v1', 'case': name, 'capture': capture, 'frame': frame, 'seed': seed,
           'pool_draws': [d['draw'] for d in draws if d['method'].endswith('AbstractGameMode/initMap()')],
           'draws_before_round': len(draws),
           'raw': [d['raw'] for d in draws],
           'callers': callers,
           'note': 'Recorded by tools/compare/round_draws.py; regenerate rather than edit.'}
    target = compare.GOLDENS / name / 'math_random.json'
    target.write_text(json.dumps(out, indent=1) + '\n', encoding='utf-8')
    print(f'{name}: {len(draws)} draws before the round, pool draws {out["pool_draws"]} -> {target}')


if __name__ == '__main__':
    main()
