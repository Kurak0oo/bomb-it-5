"""Render a screen's art pieces with the reference player (route A), on the SWF machine.

    python3 tools/convert/render_pieces.py main-menu

For every screen in tools/convert/layout.py whose golden comes from this case, the case
is replayed in the reference player at 3×. At the screen's capture each piece in its
layout (scenes/swf/<screen>.json) is rendered alone with `piece`, with its masks, filters
and blends. Output goes to the ignored local pack, original/screens/<screen>/:
pieces as PNG plus manifest.json, which scripts/ui/swf_screen.gd reads.

Self-check: the pieces are composited back over the stage colour and compared with the
reference player's own 3× frame. A low score means a piece cannot be rendered alone (for
example it blends with what lies below) and is listed in the report.
"""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / 'compare'))
import layout as layouts  # noqa: E402
import pixels  # noqa: E402

PACK = ROOT / 'original' / 'screens'
SCALE = 3


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def default_player():
    base = ROOT / '.scratch' / 'edition-5-research' / 'ruffle-runtime' / 'target' / 'ci' / 'probe'
    return base.with_suffix('.exe') if platform.system() == 'Windows' else base


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('case')
    parser.add_argument('--player', type=Path, default=default_player())
    parser.add_argument('--swf', type=Path, default=ROOT / '.scratch' / 'edition-5-research' / 'agame-bomb-it-5-zh-fix.swf')
    args = parser.parse_args()
    if not args.swf.is_file():
        raise SystemExit(f'needs the SWF at {args.swf}')
    if not args.player.is_file():
        raise SystemExit(f'reference player not built: {args.player} (run tools/reference_player/build.sh)')
    case = json.loads((ROOT / 'tools' / 'compare' / 'cases' / f'{args.case}.json').read_text(encoding='utf-8'))
    screens = {spec['golden'][1]: name for name, spec in layouts.SCREENS.items() if spec['golden'][0] == args.case}
    if not screens:
        raise SystemExit(f'no screen in tools/convert/layout.py comes from case {args.case}')
    work = Path(tempfile.mkdtemp(prefix='bombit5-pieces-'))
    plans, lines = {}, []
    for action in case['actions']:
        if 'command' in action:
            lines.append(action['command'])
        capture = action.get('capture')
        if capture in screens:
            screen = screens[capture]
            layout = json.loads((ROOT / 'scenes' / 'swf' / f'{screen}.json').read_text(encoding='utf-8'))
            folder = work / screen
            folder.mkdir()
            lines.append(f'shot {folder / "full.png"}')
            files = {}
            for i, path in enumerate(layout['pieces']):
                files[path] = f'piece-{i:04d}.png'
                lines.append(f'piece {path} {folder / files[path]}')
            plans[screen] = (layout, files, folder)
    lines.append('quit')
    with tempfile.TemporaryDirectory(prefix='bombit5-swf-') as staging:
        loaded = Path(staging) / 'original.swf'  # Ruffle rejects dot-prefixed SWF paths
        loaded.write_bytes(args.swf.read_bytes())
        result = subprocess.run([str(args.player), str(loaded), '--scale', str(SCALE)], input='\n'.join(lines) + '\n',
                                capture_output=True, text=True, timeout=3600)
    if result.returncode != 0:
        (work / 'player.log').write_text(result.stdout + result.stderr, encoding='utf-8')
        raise SystemExit(f'reference player failed; see {work / "player.log"}')
    for screen, (layout, files, folder) in plans.items():
        target = PACK / screen
        target.mkdir(parents=True, exist_ok=True)
        (PACK / '.gdignore').write_text('')  # Godot reads these directly; no import
        for old in target.glob('piece-*.png'):
            old.unlink()
        pieces = {}
        bg = tuple(layout['stage'].get('background') or [255, 255, 255, 255])
        composite = Image.new('RGBA', (700 * SCALE, 510 * SCALE), tuple(bg[:3]) + (255,))
        for path, name in files.items():
            meta = json.loads((folder / f'{name}.json').read_text(encoding='utf-8'))
            image = Image.open(folder / name).convert('RGBA')
            image.save(target / name)
            pieces[path] = {'file': name, 'pixel_origin': meta['pixel_origin'], 'pixel_size': meta['pixel_size'],
                            'render_bounds': meta['render_bounds'], 'scale': meta['scale'],
                            'clipped_by_viewport': meta['clipped_by_viewport']}
            layer = Image.new('RGBA', composite.size, (0, 0, 0, 0))
            layer.paste(image, tuple(meta['pixel_origin']))
            composite = Image.alpha_composite(composite, layer)
        composite.convert('RGB').save(target / 'composite.png')
        Image.open(folder / 'full.png').convert('RGB').save(target / 'reference-3x.png')
        check = pixels.compare(target / 'reference-3x.png', target / 'composite.png', target / 'composite-heatmap.png')
        manifest = {'schema': 'bombit5-original-screen-v1', 'screen': screen,
                    'golden_sha256': layout['source']['golden_sha256'], 'swf_sha256': sha256(args.swf),
                    'player_sha256': sha256(args.player), 'scale': SCALE, 'pieces': pieces,
                    'self_check': {k: check.get(k) for k in ('ssim', 'max_region_delta_e', 'regions_over', 'worst_region')}}
        (target / 'manifest.json').write_text(json.dumps(manifest, indent=1) + '\n', encoding='utf-8')
        print(f'{screen}: {len(pieces)} pieces in {target.relative_to(ROOT)}; pieces recomposed vs the reference '
              f'frame: SSIM {check.get("ssim")}, max region ΔE {check.get("max_region_delta_e")}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
