"""Keep the reviewed workbench evidence separate from rejected art artifacts."""
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/verification/art-workbench-2026-10-20'


def identity(path):
    return {'path': path.relative_to(ROOT).as_posix(),
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def main():
    result = json.loads((ROOT / '.scratch/art-workbench-check/result.json').read_text())
    assert result['failures'] == 0 and result['profiles_restored']
    OUT.mkdir(parents=True, exist_ok=True)
    captures = []
    for name in ['overview', 'bomb-inspector', 'replacement-draft', 'real-game-preview']:
        target = OUT / (name + '.png')
        shutil.copyfile(ROOT / '.scratch/art-workbench-check' / target.name, target)
        captures.append(identity(target))
    defaults = {}
    for name in ['match', 'pause', 'death', 'ending', 'results']:
        old = ROOT / 'docs/verification/fidelity-2026-10-20/desktop' / (name + '.png')
        new = ROOT / '.scratch/game-captures' / old.name
        defaults[name] = ImageChops.difference(Image.open(old).convert('RGB'),
                                             Image.open(new).convert('RGB')).getbbox() is None
    assert all(defaults.values()), defaults
    result.update({'baseline': 'ca86801', 'reverts': ['0f41b43', '8211c82'],
                   'godot': '4.5.stable.official.876b29033', 'default_rgb_comparisons': defaults,
                   'captures': captures,
                   'active_manifest': identity(ROOT / 'assets/skins/active.json'),
                   'scripts': [identity(p) for p in sorted((ROOT / 'scripts').rglob('*.gd'))],
                   'limits': ['Native picker completion is exercised at its public signal, not internal mouse controls.',
                              'Two-colour verification fixture is not a proposed art direction.',
                              'References are preserved context screenshots, not a complete exported source sprite atlas.',
                              'Desktop authoring only; no phone/iOS testing or export.']})
    (OUT / 'verification.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f"Curated four workbench captures, {result['checks']} UI/rendering checks and five default RGB comparisons")


if __name__ == '__main__':
    main()
