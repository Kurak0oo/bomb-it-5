"""Curate the current painted presentation without overwriting earlier evidence."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'docs/verification/presentation-2026-10-20'


def identity(path):
    return {'path': path.relative_to(ROOT).as_posix(),
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    records = []
    for source, name in [('.scratch/game-captures', 'desktop'),
                         ('.scratch/fidelity-port/captures', 'actions'),
                         ('.scratch/presentation-captures', 'states'),
                         ('.scratch/presentation-layout', 'layouts')]:
        destination = OUTPUT / name
        destination.mkdir(exist_ok=True)
        for path in sorted((ROOT / source).glob('*.png')):
            target = destination / path.name
            shutil.copyfile(path, target)
            records.append(identity(target))
    result = {
        'baseline_commit': 'ca86801', 'ticket': 20,
        'godot': '4.5.stable.official.876b29033', 'renderer': 'Compatibility',
        'assets': [identity(path) for path in sorted((ROOT / 'assets/art').glob('*.png'))],
        'scripts': [identity(ROOT / 'scripts' / name) for name in
                    ['game_art.gd', 'game_view.gd', 'game.gd', 'touch_controls.gd']],
        'captures': records,
        'render_checks': json.loads((ROOT / '.scratch/presentation-captures/checks.json').read_text()),
        'layout_checks': json.loads((ROOT / '.scratch/presentation-layout/checks.json').read_text()),
        'limits': ['Desktop rendering and synthetic input only; no physical-device cutout validation.',
                   'Original generated illustration, not SWF pixels, frame artwork or audio.',
                   'Functional checks do not constitute human art/play-quality acceptance (#21).'],
    }
    (OUTPUT / 'verification.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f'Curated {len(records)} painted presentation captures')


if __name__ == '__main__':
    main()
