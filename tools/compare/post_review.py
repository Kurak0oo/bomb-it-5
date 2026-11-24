"""Post comparison results to an issue and mark it ready for the owner's review.

    python3 tools/compare/post_review.py ISSUE CASE [CASE ...]            print the comment
    python3 tools/compare/post_review.py ISSUE CASE [CASE ...] --post     post it with `gh`

Reads each case's last report (.scratch/compare/<case>/report.json, from `compare.py check`)
and writes one comment: pass or fail per case, the first divergence, node counts per
capture and trace, and SSIM / ΔE where pixels were scored. With `--post` it comments on the
issue and adds the `ready-for-owner-review` label when every case passes.

No images are posted: captures and heatmaps show the original art, which never leaves the
local pack (AGENTS.md). The comment names the local files the owner opens instead.
A passing comparison only says a screen is ready to look at; the owner closes UI and art
issues (docs/development.md, rule 2; .github/workflows/owner-gate.yml).
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
WORK = ROOT / '.scratch' / 'compare'
LABEL = 'ready-for-owner-review'


def case_section(name):
    path = WORK / name / 'report.json'
    if not path.is_file():
        return False, [f'### {name}: no report', f'Run `tools/compare.sh check {name}` first.']
    report = json.loads(path.read_text(encoding='utf-8'))
    lines = [f'### {name}: {"PASS" if report["passed"] else "FAIL"}']
    first = report.get('first_divergence')
    if first:
        where = first['at'] + (f' tick {first["tick"]}' if first.get('tick') is not None else '')
        lines.append(f'First divergence: **{where}**')
        lines += [f'- `{p}`' for p in first['problems']]
    lines += ['', '| Capture | Nodes | Pixels |', '| --- | --- | --- |']
    for capture, entry in report['captures'].items():
        n, p = entry['node'], entry['pixel']
        nodes = (f'{n["matched"]}/{n["reference_nodes"]} matched, {len(n["missing"])} missing, '
                 f'{len(n["extra"])} extra, {len(n["mismatches"])} off')
        if p.get('skipped'):
            pixels = f'skipped: {p["skipped"]}'
        elif 'error' in p:
            pixels = f'error: {p["error"]}'
        else:
            pixels = (f'SSIM {p["ssim"]} (need {p["thresholds"]["ssim"]:.4g}), ΔE {p["max_region_delta_e"]} '
                      f'(need ≤ {p["thresholds"]["delta_e"]:.4g}); heatmap `.scratch/compare/{name}/{capture}-heatmap.png`')
        lines.append(f'| {capture} | {nodes} | {pixels} |')
    for trace_name, entry in report.get('traces', {}).items():
        state = 'every tick matches' if entry['passed'] else (
            f'{len(entry["failed_ticks"])} tick(s) differ, first at tick {entry["failed_ticks"][0]}')
        lines.append(f'| {trace_name} (trace, {entry["ticks"]} ticks) | {state} | state only |')
    lines.append('')
    lines.append(f'Local captures to look at: `.scratch/compare/{name}/godot/*.png` beside '
                 f'`.scratch/compare/{name}/reference/*.png`.')
    return report['passed'], lines


def comment(cases):
    passed, body = True, ['Comparison loop results (tools/compare/post_review.py).', '']
    for name in cases:
        ok, lines = case_section(name)
        passed &= ok
        body += lines + ['']
    body.append('Every case passes: ready for the owner to look at. Only the owner closes this issue.'
                if passed else 'Not ready for review: a case above fails or has no report.')
    return passed, '\n'.join(body) + '\n'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('issue', type=int)
    parser.add_argument('cases', nargs='+')
    parser.add_argument('--post', action='store_true', help='comment on the issue with gh and label it when it passes')
    args = parser.parse_args(argv)
    passed, body = comment(args.cases)
    if not args.post:
        sys.stdout.write(body)
        return 0
    if not shutil.which('gh'):
        raise SystemExit('--post needs the gh CLI; print the comment without --post and paste it instead')
    with tempfile.NamedTemporaryFile('w', suffix='.md', delete=False, encoding='utf-8') as handle:
        handle.write(body)
    subprocess.run(['gh', 'issue', 'comment', str(args.issue), '--body-file', handle.name], check=True, cwd=ROOT)
    Path(handle.name).unlink()
    if passed:
        subprocess.run(['gh', 'label', 'create', LABEL, '--color', 'fbca04', '--force', '--description',
                        'Passes the comparison loop; waiting for the owner to look'], check=False, cwd=ROOT)
        subprocess.run(['gh', 'issue', 'edit', str(args.issue), '--add-label', LABEL], check=True, cwd=ROOT)
    print(f'posted to #{args.issue}' + (f' and labelled {LABEL}' if passed else ' (not labelled: a case fails)'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
