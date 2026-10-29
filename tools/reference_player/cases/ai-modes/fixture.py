"""Writes tests/fixtures/ai-profiles-traced.json from the #84 runs: each mode and difficulty's
live AI profile as the opening focus snapshot reads it (all AIs in a run must agree).
Usage: fixture.py RUNS_DIR (holding ai-<mode>-<difficulty>-01)."""
import json
import sys
from pathlib import Path

import importlib.util  # noqa: E402

_spec = importlib.util.spec_from_file_location('ai_summary', Path(__file__).resolve().parent / 'summarize.py')
_summary = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_summary)
profile = _summary.profile

FIELDS = ('precentage', 'weaponAttackDelay', 'advanceAttack', 'advanceDodge', 'hasWeapon', 'target',
          'isDanger', 'hasItem', 'hasInvisiblity')


def main(runs):
    result = {}
    for mode in ('arcade', 'kill', 'pac_man', 'green_zone'):
        for difficulty in ('easy', 'normal', 'hard'):
            run = Path(runs) / f'ai-{mode.replace("_", "-")}-{difficulty}-01'
            ais, _ = profile(run)
            keep = [{'answer_time': ai['answer_time'], 'find_range': ai['find_range'], 'default': ai['default'],
                     'states': [{'class': s['class'], **{k: s.get(k) for k in FIELDS}} for s in ai['states']]} for ai in ais]
            if any(entry != keep[0] for entry in keep):
                raise ValueError(f'{run.name}: AIs disagree')
            result[f'{mode}/{difficulty}'] = keep[0]
    out = Path(__file__).resolve().parents[4] / 'tests' / 'fixtures' / 'ai-profiles-traced.json'
    out.write_text(json.dumps(result, indent=1) + '\n')
    print(f'wrote {out} ({len(result)} profiles)')


if __name__ == '__main__':
    main(sys.argv[1])
