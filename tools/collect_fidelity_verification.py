"""Collect this port's public comparisons, provenance and original desktop captures."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'docs/verification/fidelity-2026-10-20'


def identity(path):
    return {'path': path.relative_to(ROOT).as_posix(),
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    report = json.loads((ROOT / '.scratch/fidelity-port/comparisons.json').read_text())
    assert report['failures'] == 0, 'Do not curate failed comparisons as acceptance'
    shutil.copyfile(ROOT / '.scratch/fidelity-port/comparisons.json', OUTPUT / 'comparisons.json')
    records = []
    for directory in [ROOT / '.scratch/game-captures', ROOT / '.scratch/fidelity-port/captures']:
        destination = OUTPUT / ('desktop' if directory.name == 'game-captures' else 'actions')
        destination.mkdir(exist_ok=True)
        for source in sorted(directory.glob('*.png')):
            shutil.copyfile(source, destination / source.name)
            records.append(identity(destination / source.name))
    source_cases = [identity(path) for path in sorted((ROOT / 'tools/reference_player/cases').rglob('*.json'))]
    production = [identity(path) for path in sorted((ROOT / 'scripts').rglob('*.gd'))]
    evidence = ROOT / 'docs/evidence/reference-2026-10-19'
    manifests = [identity(path) for path in sorted(evidence.rglob('*manifest*.json'))]
    result = {
        'authority_swf_sha256': '718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2',
        'ruffle_revision': '45366370ed7d1a59c89aa3cf7b765c7a274407cd',
        'baseline_commit': '74ab044', 'godot': '4.5.stable.official.876b29033',
        'checks': report['checks'], 'failed_comparisons': report['failures'],
        'comparison_fixtures': len(report['fixtures']),
        'comparison_artifact': identity(OUTPUT / 'comparisons.json'),
        'production_scripts': production, 'captures': records,
        'recovery_case_inventory': source_cases, 'preserved_reference_manifest_inventory': manifests,
        'limits': [
            'Inventory presence is not a claim that every reference case was replayed or paired by this port.',
            '88 flamer endpoints compare actual recorded original getters; other checks are focused source-derived public regressions.',
            'Declared open/route fixtures preserve selected conditions; they are not complete SWF session replays.',
            'RNG draws and clock categories are explicit; seed equality does not imply engine equivalence.',
            'Numeric bounds metadata is used without source sprites, textures, music or artwork.',
        ],
    }
    playthroughs = ROOT / '.scratch/game-captures/playthroughs.json'
    if playthroughs.exists():
        result['desktop_playthroughs'] = json.loads(playthroughs.read_text())
    (OUTPUT / 'verification.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f"Curated {report['checks']} public checks, {len(report['fixtures'])} fixtures, {len(records)} captures")


if __name__ == '__main__':
    main()
