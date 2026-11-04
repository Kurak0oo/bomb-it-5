"""Comparison loop: the same case in the reference player and in Godot, diffed.

    compare.py record CASE   reference player -> committed golden node dumps (+ local PNGs)
    compare.py check CASE    Godot -> node diff against goldens, pixel diff where PNGs exist
    compare.py run CASE      record (when the SWF and player are present), then check
    compare.py all           check every case
    compare.py accept CASE   after the owner accepts a screen: its scores become the floor

`record` needs the SWF and a reference player built with `-Display`/`build.sh`. `check`
needs only Godot 4.5, so agents without the SWF can still run the node diff. Captures
with original art stay in .scratch/compare and are never committed.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE.parent))  # tools/, for replay_reference
import nodes  # noqa: E402
import pixels  # noqa: E402

CASES = HERE / 'cases'
GOLDENS = ROOT / 'tests' / 'goldens'
WORK = ROOT / '.scratch' / 'compare'
DEFAULT_SWF = ROOT / '.scratch' / 'edition-5-research' / 'agame-bomb-it-5-zh-fix.swf'
FLOOR_SLACK = {'ssim': 0.001, 'delta_e': 0.25}


def load_case(name):
    path = CASES / f'{name}.json'
    if not path.is_file():
        raise SystemExit(f'No case {name!r}; cases: {", ".join(sorted(p.stem for p in CASES.glob("*.json")))}')
    case = json.loads(path.read_text(encoding='utf-8'))
    captures = [a['capture'] for a in case['actions'] if 'capture' in a]
    if not captures or len(set(captures)) != len(captures):
        raise SystemExit(f'{name}: a case needs at least one capture, each with a unique name')
    return path, case, captures


def default_player():
    base = ROOT / '.scratch' / 'edition-5-research' / 'ruffle-runtime' / 'target' / 'ci' / 'probe'
    return base.with_suffix('.exe') if platform.system() == 'Windows' else base


def default_godot():
    if os.environ.get('GODOT'):
        return os.environ['GODOT']
    mac = Path('/Applications/Godot.app/Contents/MacOS/Godot')
    if mac.exists():
        return str(mac)
    return shutil.which('godot') or shutil.which('godot4') or 'godot'


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def record(name, player, swf):
    from replay_reference import ReferenceSession, SWF_SHA256
    case_path, case, captures = load_case(name)
    if not swf.is_file():
        raise SystemExit(f'record needs the SWF at {swf} (pass --swf)')
    if sha256(swf) != SWF_SHA256:
        raise SystemExit('Not the recorded publisher SWF')
    if not player.is_file():
        raise SystemExit(f'Reference player not built: {player} (run tools/reference_player/build.sh)')
    import tempfile
    out = WORK / name / 'reference'
    shutil.rmtree(out, ignore_errors=True)
    out.parent.mkdir(parents=True, exist_ok=True)
    # Same reason as replay_reference: Ruffle rejects dot-prefixed SWF paths.
    with tempfile.TemporaryDirectory(prefix='bombit5-compare-') as staging:
        loaded = Path(staging) / 'original.swf'
        loaded.write_bytes(swf.read_bytes())
        session = ReferenceSession(player, loaded, out)
        frames, fps = {}, None
        ok = False
        try:
            for action in case['actions']:
                if 'command' in action:
                    fps = session.command(action['command'])['fps_setting']
                if 'capture' in action:
                    capture = action['capture']
                    fps = session.command(f'display {capture}.display.json')['fps_setting']
                    session.capture(capture)
                    frames[capture] = session.frame
            ok = True
        finally:
            session.close(check=ok)
    target = GOLDENS / name
    target.mkdir(parents=True, exist_ok=True)
    for capture in captures:
        dump = json.loads((out / f'{capture}.display.json').read_text(encoding='utf-8'))
        golden = nodes.normalize_reference(dump)
        golden['frame'] = frames[capture]
        (target / f'{capture}.json').write_text(json.dumps(golden, indent=1, sort_keys=True) + '\n', encoding='utf-8')
    meta = {'case': name, 'case_sha256': sha256(case_path), 'swf_sha256': sha256(swf),
            'player_sha256': sha256(player), 'fps': fps, 'frames': frames,
            'note': 'Recorded by tools/compare/compare.py record; regenerate rather than edit.'}
    (target / 'meta.json').write_text(json.dumps(meta, indent=1, sort_keys=True) + '\n', encoding='utf-8')
    print(f'recorded {name}: {len(captures)} capture(s), goldens in {target.relative_to(ROOT)}')


def run_godot(name, case_path, godot, fps):
    out = WORK / name / 'godot'
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    command = [godot, '--path', str(ROOT), '--fixed-fps', str(int(round(fps))), '--resolution', '700x510',
               '--script', 'res://tools/compare/godot_capture.gd', '--', '--case', str(case_path), '--out', str(out)]
    command += json.loads(Path(case_path).read_text(encoding='utf-8')).get('godot_args', [])
    if platform.system() == 'Linux' and not os.environ.get('DISPLAY') and shutil.which('xvfb-run'):
        command = ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24'] + command
    result = subprocess.run(command, capture_output=True, text=True, timeout=600)
    (out / 'godot-stdout.log').write_text(result.stdout + result.stderr, encoding='utf-8')
    if result.returncode != 0:
        raise SystemExit(f'Godot failed ({result.returncode}); see {out / "godot-stdout.log"}')
    return out


def owner_edits(case, capture):
    """Owner edits of the screen recorded by this capture (from its generated layout), and
    the stage rectangles they change: original and new places, excluded from pixels."""
    for layout_path in sorted((ROOT / 'scenes' / 'swf').glob('*.json')):
        layout = json.loads(layout_path.read_text(encoding='utf-8'))
        if layout.get('source', {}).get('golden') == f'tests/goldens/{case}/{capture}.json':
            edits = layout.get('owner_edits', {})
            masks = []
            for info in edits.get('removed', {}).values():
                if info.get('render_bounds'):
                    masks.append(info['render_bounds'])
            for info in edits.get('moved', {}).values():
                if info.get('render_bounds'):
                    b, (dx, dy) = info['render_bounds'], info['by']
                    masks += [b, [b[0] + dx, b[1] + dy, b[2] + dx, b[3] + dy]]
            return edits, masks
    return {}, []


def check(name, godot):
    case_path, case, captures = load_case(name)
    golden_dir = GOLDENS / name
    meta_path = golden_dir / 'meta.json'
    if not meta_path.is_file():
        raise SystemExit(f'No goldens for {name}; run `compare.py record {name}` on a machine with the SWF')
    meta = json.loads(meta_path.read_text(encoding='utf-8'))
    if meta['case_sha256'] != sha256(case_path):
        raise SystemExit(f'{name}: the case changed since its goldens were recorded; record again')
    floor_path = golden_dir / 'floor.json'
    floor = json.loads(floor_path.read_text(encoding='utf-8')) if floor_path.is_file() else {}
    out = run_godot(name, case_path, godot, meta['fps'])
    report = {'case': name, 'captures': {}, 'passed': True}
    for capture in captures:
        golden = json.loads((golden_dir / f'{capture}.json').read_text(encoding='utf-8'))
        actual = json.loads((out / f'{capture}.nodes.json').read_text(encoding='utf-8'))
        edits, masks = owner_edits(name, capture)
        golden = nodes.apply_owner_edits(golden, edits)
        entry = {'node': nodes.diff(golden, actual, case.get('tolerances'))}
        if edits.get('removed') or edits.get('moved'):
            entry['owner_edits'] = {'removed': sorted(edits.get('removed', {})), 'moved': sorted(edits.get('moved', {}))}
        reference_png = WORK / name / 'reference' / f'{capture}.png'
        if reference_png.is_file():
            thresholds = dict(case.get('thresholds', {}))
            if capture in floor:
                base = dict(pixels.DEFAULT_THRESHOLDS, **thresholds)
                thresholds['ssim'] = max(base['ssim'], floor[capture]['ssim'] - FLOOR_SLACK['ssim'])
                thresholds['delta_e'] = min(base['delta_e'], floor[capture]['max_region_delta_e'] + FLOOR_SLACK['delta_e'])
            entry['pixel'] = pixels.compare(reference_png, out / f'{capture}.png',
                                            WORK / name / f'{capture}-heatmap.png', thresholds, masks)
        else:
            entry['pixel'] = {'passed': None, 'skipped': 'no local reference capture (record on the SWF machine)'}
        report['captures'][capture] = entry
        report['passed'] &= entry['node']['passed'] and entry['pixel']['passed'] is not False
    (WORK / name / 'report.json').write_text(json.dumps(report, indent=1) + '\n', encoding='utf-8')
    print_report(report)
    return report


def print_report(report):
    print(f'{"PASS" if report["passed"] else "FAIL"}: {report["case"]}')
    for capture, entry in report['captures'].items():
        n, p = entry['node'], entry['pixel']
        if entry.get('owner_edits'):
            e = entry['owner_edits']
            print(f'  {capture}: owner edits expected: {len(e["removed"])} removed, {len(e["moved"])} moved '
                  '(excluded from the pixel score)')
        print(f'  {capture}: nodes {n["matched"]}/{n["reference_nodes"]} matched, {len(n["missing"])} missing, '
              f'{len(n["extra"])} extra, {len(n["mismatches"])} off'
              + (f'; Godot has {n["godot_unmapped_visible"]} unmapped visible nodes' if n['godot_unmapped_visible'] else ''))
        for item in n['mismatches'][:10]:
            print(f'    {item["path"]}: {"; ".join(item["problems"])}')
        for path in n['missing'][:5]:
            print(f'    missing {path}')
        if p.get('skipped'):
            print(f'    pixels skipped: {p["skipped"]}')
        elif 'error' in p:
            print(f'    pixels: {p["error"]}')
        else:
            print(f'    pixels: SSIM {p["ssim"]} (need {p["thresholds"]["ssim"]:.4g}), max region ΔE '
                  f'{p["max_region_delta_e"]} (need ≤ {p["thresholds"]["delta_e"]:.4g}), heatmap {capture}-heatmap.png')


def accept(name):
    report_path = WORK / name / 'report.json'
    if not report_path.is_file():
        raise SystemExit(f'Run `compare.py check {name}` first')
    report = json.loads(report_path.read_text(encoding='utf-8'))
    floor = {}
    for capture, entry in report['captures'].items():
        if not entry['node']['passed'] or not entry['pixel'].get('passed'):
            raise SystemExit(f'{capture} does not pass with pixels; only an accepted, passing screen sets a floor')
        floor[capture] = {k: entry['pixel'][k] for k in ('ssim', 'max_region_delta_e')}
    path = GOLDENS / name / 'floor.json'
    path.write_text(json.dumps(floor, indent=1, sort_keys=True) + '\n', encoding='utf-8')
    print(f'floor recorded in {path.relative_to(ROOT)}')


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('action', choices=['record', 'check', 'run', 'all', 'accept'])
    parser.add_argument('case', nargs='?')
    parser.add_argument('--player', type=Path, default=default_player())
    parser.add_argument('--swf', type=Path, default=DEFAULT_SWF)
    parser.add_argument('--godot', default=default_godot())
    args = parser.parse_args()
    if args.action != 'all' and not args.case:
        parser.error('this action needs a case')
    if args.action == 'record':
        record(args.case, args.player, args.swf)
        return 0
    if args.action == 'accept':
        accept(args.case)
        return 0
    if args.action == 'run':
        if args.swf.is_file() and args.player.is_file():
            record(args.case, args.player, args.swf)
        else:
            print('reference player or SWF missing: checking against the committed goldens')
        return 0 if check(args.case, args.godot)['passed'] else 1
    names = [args.case] if args.action == 'check' else sorted(p.stem for p in CASES.glob('*.json'))
    results = [check(name, args.godot)['passed'] for name in names]
    return 0 if all(results) else 1


if __name__ == '__main__':
    sys.exit(main())
