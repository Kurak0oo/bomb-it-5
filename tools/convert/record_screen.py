"""Record a screen's behaviour and art from the reference player (converter v2, SWF machine).

    python3 tools/convert/record_screen.py timeline main-menu   # -> tests/goldens/<case>/<capture>.timeline.json
    python3 tools/convert/record_screen.py states main-menu     # -> tests/goldens/<case>/<capture>.states.json
    python3 tools/convert/record_screen.py art main-menu        # -> original/screens/<screen>/ (local pack)

timeline: the case is replayed one frame at a time. From the frame a screen's root clip
first appears until its capture, and then for one full period after it with no input,
every display object under the root is recorded (stage matrix, visibility, clip frame,
presence), stored as changes only. The period is the least common multiple of the clip
lengths under the root (capped). Also recorded: how many frames after the last input the
screen opened, so Godot opens it as late as the original.

states: the case is replayed to the capture; then each interactive instance is hovered,
pressed and released away from it (so nothing navigates), and each switch is clicked
through its frames. The clip frame shown in each state is recorded, and its art rendered.

art (after tools/convert/layout.py): every piece is rendered at 3× with `piece`: static
pieces once, sequence pieces at every recorded frame (identical images stored once).
Everything is self-checked: at the capture frame the pieces, laid back together, must
reproduce the reference player's own frame.
"""
import argparse
from functools import reduce
import hashlib
import json
import math
from pathlib import Path
import platform
import shutil
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE.parent / 'compare'))
import layout as layouts  # noqa: E402
import pixels  # noqa: E402

GOLDENS = ROOT / 'tests' / 'goldens'
PACK = ROOT / 'original' / 'screens'
SCALE = 3
MAX_PERIOD = 600


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def default_player():
    base = ROOT / '.scratch' / 'edition-5-research' / 'ruffle-runtime' / 'target' / 'ci' / 'probe'
    return base.with_suffix('.exe') if platform.system() == 'Windows' else base


class Player:
    """The reference player at SCALE×, one acknowledged command at a time."""

    def __init__(self, player, swf):
        from replay_reference import ReferenceSession
        self.tmp = Path(tempfile.mkdtemp(prefix='bombit5-record-'))
        staged = self.tmp / 'original.swf'  # Ruffle rejects dot-prefixed SWF paths
        staged.write_bytes(Path(swf).read_bytes())
        self.session = ReferenceSession(player, staged, self.tmp / 'session', extra_args=('--scale', str(SCALE)))
        self.dumps = 0

    @property
    def frame(self):
        return self.session.frame

    def command(self, line):
        if line.startswith('fixture {'):
            return self.session.fixture(json.loads(line[len('fixture '):]))
        return self.session.command(line)

    def display(self):
        path = self.tmp / 'display.json'
        self.command(f'display {path}')
        self.dumps += 1
        return json.loads(path.read_text(encoding='utf-8'))

    def piece(self, path, target, frame=None, hide=None):
        self.command(f'piece {path} {target}' + (f' {frame or "-"} {",".join(hide)}' if hide else (f' {frame}' if frame else '')))
        return json.loads(Path(f'{target}.json').read_text(encoding='utf-8'))

    def shot(self, target):
        self.command(f'shot {target}')

    def close(self):
        try:
            self.session.close(check=False)
        finally:
            shutil.rmtree(self.tmp, ignore_errors=True)


def screens_of(case):
    out = {}
    for name, spec in layouts.SCREENS.items():
        if spec['golden'][0] == case:
            out[spec['golden'][1]] = (name, spec)
    if not out:
        raise SystemExit(f'no screen in tools/convert/layout.py comes from case {case}')
    return out


def load_case(case):
    return json.loads((ROOT / 'tools' / 'compare' / 'cases' / f'{case}.json').read_text(encoding='utf-8'))


def single_steps(case, capture):
    """The case's commands up to `capture`, with `step N` split into single frames."""
    for action in case['actions']:
        if action.get('capture') == capture:
            return
        if 'fixture' in action:
            yield 'fixture ' + json.dumps(action['fixture'])
        if 'command' in action:
            words = action['command'].split()
            if words[0] == 'step':
                for _ in range(int(words[1])):
                    yield 'step 1'
            else:
                yield action['command']


def root_path(dump, spec):
    for node in dump['nodes']:
        if spec.get('root_class') and node.get('class') == spec['root_class']:
            return node['path']
        if node['path'] == spec.get('root_path'):
            return node['path']
    return None


def period_of(golden, root):
    lengths = {int(n['total_frames']) for n in golden['nodes']
               if n['path'].startswith(root) and (n.get('total_frames') or 1) > 1}
    period = reduce(lambda a, b: a * b // math.gcd(a, b), lengths, 1)
    return min(period, MAX_PERIOD), period > MAX_PERIOD


def state_of(node):
    m = node.get('stage_matrix') or [1, 0, 0, 1, 0, 0]
    ct = node.get('color_transform') or {}
    # The colour transform's RGB part (a balloon's brightness tween); alpha is index 9.
    colour = [round(v, 4) for v in (ct.get('mult', [1, 1, 1])[:3] + ct.get('add', [0, 0, 0])[:3])]
    return [round(v, 4) for v in m] + [1 if node.get('effective_visible') else 0, node.get('frame') or 0,
                                        node.get('character_id') or 0, round(node.get('alpha', 1.0), 4), colour]


# ------------------------------------------------------------------ timeline

def record_timeline(case_name, player_path, swf):
    case = load_case(case_name)
    for capture, (screen, spec) in screens_of(case_name).items():
        golden = json.loads((GOLDENS / case_name / f'{capture}.json').read_text(encoding='utf-8'))
        p = Player(player_path, swf)
        try:
            opened, last_input, tracks, t = None, 0, {}, 0
            root = None

            def sample(index):
                dump = p.display()
                nodes = {n['path']: n for n in dump['nodes'] if n['path'] == root or n['path'].startswith(root + '/')}
                for path, node in nodes.items():
                    value = state_of(node)
                    track = tracks.setdefault(path, [])
                    if not track or track[-1][1] != value:
                        track.append([index, value])
                for path, track in tracks.items():
                    if path not in nodes and track[-1][1] is not None:
                        track.append([index, None])

            for line in single_steps(case, capture):
                p.command(line)
                if not line.startswith('step'):
                    last_input = p.frame
                    continue
                if root is None:
                    root = root_path(p.display(), spec)
                    if root is None:
                        continue
                    opened = p.frame
                sample(p.frame - opened)
            if root is None:
                raise SystemExit(f'{screen}: its root clip never appeared before the {capture} capture')
            capture_index = p.frame - opened
            period, capped = period_of(golden, root)
            for _ in range(period):
                p.command('step 1')
                sample(p.frame - opened)
        finally:
            p.close()
        out = {'schema': 'bombit5-screen-timeline-v1', 'screen': screen, 'case': case_name, 'capture': capture,
               'root': root, 'opened_frame': opened, 'opened_after_input': opened - last_input,
               'capture_index': capture_index, 'period': period, 'period_capped': capped,
               'state': ['a', 'b', 'c', 'd', 'tx', 'ty', 'visible', 'frame', 'character', 'alpha'],
               'note': 'Changes only: [frame index since the screen opened, state or null when absent].',
               'tracks': tracks}
        target = GOLDENS / case_name / f'{capture}.timeline.json'
        target.write_text(json.dumps(out, separators=(',', ':'), sort_keys=True) + '\n', encoding='utf-8')
        moving = sum(1 for tr in tracks.values() if len(tr) > 1)
        print(f'{screen}: opened {opened - last_input} frames after input, capture at +{capture_index}, '
              f'period {period}{" (capped)" if capped else ""}; {moving}/{len(tracks)} nodes change '
              f'-> {target.relative_to(ROOT)}')
        for extra_capture, selectors in spec.get('extra', {}).items():
            _record_extra_timeline(case_name, case, screen, root, extra_capture, selectors, player_path, swf)


def _record_extra_timeline(case_name, case, screen, root, capture, selectors, player_path, swf):
    """A part from another capture (a robot shown after its icon was clicked, the unlock tip)
    plays on its own timeline: recorded from the frame it shows (index 0), through its
    capture (`capture_index`), and one period after it with no further input, which loops."""
    golden = json.loads((GOLDENS / case_name / f'{capture}.json').read_text(encoding='utf-8'))
    tops = [n['path'] for n in golden['nodes'] if n['path'].startswith(root + '/') and any(
        layouts._matches(n, n['path'][len(root) + 1:], s) for s in selectors)]
    inside = [n for n in golden['nodes'] if any(n['path'] == top or n['path'].startswith(top + '/') for top in tops)]
    lengths = {int(n['total_frames']) for n in inside if (n.get('total_frames') or 1) > 1}
    period = min(reduce(lambda a, b: a * b // math.gcd(a, b), lengths, 1), MAX_PERIOD)
    top_class = {n['path']: n.get('class') for n in golden['nodes'] if n['path'] in tops}
    p = Player(player_path, swf)
    tracks, first_present = {}, None

    def sample(nodes, index):
        for node in nodes:
            if any(node['path'] == top or node['path'].startswith(top + '/') for top in tops):
                value = state_of(node)
                track = tracks.setdefault(node['path'], [])
                if not track or track[-1][1] != value:
                    track.append([index, value])

    try:
        for line in single_steps(case, capture):
            p.command(line)
            if line.startswith('step'):
                nodes = p.display()['nodes']
                # Shown once all its tops are, each with its class: the clothes panel slot
                # (/@0) is on screen from the first robot on (another robot's panel), the
                # robot only after its icon is clicked.
                present = {(n['path'], n.get('class')) for n in nodes}
                if all((top, top_class[top]) in present for top in tops):
                    if first_present is None:
                        first_present, tracks = p.frame, {}  # shown (again): its timeline starts
                    sample(nodes, p.frame - first_present)
                else:
                    first_present = None
        if first_present is None:
            raise SystemExit(f'{screen}: {selectors} not shown at the {capture} capture')
        capture_index = p.frame - first_present
        for _ in range(period):
            p.command('step 1')
            sample(p.display()['nodes'], p.frame - first_present)
    finally:
        p.close()
    out = {'schema': 'bombit5-screen-timeline-v2', 'screen': screen, 'case': case_name, 'capture': capture,
           'root': root, 'extra': True, 'tops': tops, 'from_shown': True, 'capture_index': capture_index,
           'period': period, 'shown_before_capture': capture_index,
           'state': ['a', 'b', 'c', 'd', 'tx', 'ty', 'visible', 'frame', 'character', 'alpha'],
           'note': 'An extra part, from the frame it shows (index 0) through its capture and one period '
                   'after it with no input.',
           'tracks': tracks}
    target = GOLDENS / case_name / f'{capture}.timeline.json'
    target.write_text(json.dumps(out, separators=(',', ':'), sort_keys=True) + '\n', encoding='utf-8')
    print(f'{screen}/{capture}: extra parts shown {capture_index} frames before the capture, then loop over {period}')


# ------------------------------------------------------------------ states

def centre(bounds):
    return (bounds[0] + bounds[2]) / 2, (bounds[1] + bounds[3]) / 2


def record_states(case_name, player_path, swf):
    case = load_case(case_name)
    for capture, (screen, spec) in screens_of(case_name).items():
        if spec.get('states') is False:
            continue  # a ported controller drives this screen's widgets
        golden = json.loads((GOLDENS / case_name / f'{capture}.json').read_text(encoding='utf-8'))
        by_name = {}
        for node in golden['nodes']:
            last = node['path'].rsplit('/', 1)[-1].split('@')[0]
            if last in spec['interactive'] and node.get('stage_bounds'):
                by_name.setdefault(last, node)
        art_dir = PACK / screen / 'states'
        shutil.rmtree(art_dir, ignore_errors=True)
        art_dir.mkdir(parents=True, exist_ok=True)
        states, art = {}, {}
        for name, node in by_name.items():
            p = Player(player_path, swf)  # a fresh run per instance: states never leak
            try:
                for line in single_steps(case, capture):
                    p.command(line)
                path = node['path']
                x, y = centre(node['stage_bounds'])
                away = (2, 2)

                def frame_now():
                    for n in p.display()['nodes']:
                        if n['path'] == path:
                            return n.get('frame') or 1
                    return None

                def render(frame):
                    if frame is None or frame in art.get(path, {}):
                        return
                    target = art_dir / f'{len(art.get(path, {})):02d}-{hashlib.md5(path.encode()).hexdigest()[:8]}.png'
                    meta = p.piece(path, target)
                    art.setdefault(path, {})[frame] = {'file': f'states/{target.name}', **_piece_meta(meta)}

                record = {'rest': frame_now()}
                render(record['rest'])
                kind = spec.get('switches', {}).get(name) and 'switch' or 'button'
                p.command(f'move {x:.2f} {y:.2f}')
                p.command('step 1')
                record['hover'] = frame_now()
                render(record['hover'])
                if kind == 'button':
                    p.command(f'down {x:.2f} {y:.2f}')
                    p.command('step 1')
                    record['press'] = frame_now()
                    render(record['press'])
                    p.command(f'move {away[0]} {away[1]}')
                    p.command('step 1')
                    record['press_out'] = frame_now()
                    p.command(f'up {away[0]} {away[1]}')
                    p.command('step 1')
                    record['released_out'] = frame_now()
                else:
                    cycle = []
                    for _ in range(int(node.get('total_frames') or 1)):
                        p.command(f'click {x:.2f} {y:.2f}')
                        p.command('step 1')
                        cycle.append(frame_now())
                        render(cycle[-1])
                    record['click_cycle'] = cycle
                record['kind'] = kind
                states[path] = record
            finally:
                p.close()
            print(f'{screen}: {name} {record}')
        out = {'schema': 'bombit5-screen-states-v1', 'screen': screen, 'case': case_name, 'capture': capture,
               'note': 'Clip frame shown at rest, hovered, pressed (and dragged off / released off), or after '
                       'each click of a switch, as the reference player showed it.',
               'states': states}
        (GOLDENS / case_name / f'{capture}.states.json').write_text(json.dumps(out, indent=1, sort_keys=True) + '\n',
                                                                     encoding='utf-8')
        (art_dir / 'states.json').write_text(json.dumps(art, indent=1) + '\n', encoding='utf-8')


def _piece_meta(meta):
    return {'pixel_origin': meta['pixel_origin'], 'pixel_size': meta['pixel_size'], 'scale': meta['scale'],
            'render_bounds': meta['render_bounds']}


# ------------------------------------------------------------------ art

def record_art(case_name, player_path, swf):
    case = load_case(case_name)
    for capture, (screen, spec) in screens_of(case_name).items():
        layout = json.loads((ROOT / 'scenes' / 'swf' / f'{screen}.json').read_text(encoding='utf-8'))
        timeline = layout.get('timeline') or {}
        PLAYER_PATHS.update({n['path']: n['golden_path'] for n in layout['nodes'] if n.get('golden_path')})
        target = PACK / screen
        target.mkdir(parents=True, exist_ok=True)
        (PACK / '.gdignore').write_text('')
        for old in target.glob('piece-*.png'):
            old.unlink()
        statics = {n['path']: n for n in layout['nodes'] if n['role'] == 'piece' and n['path'] in layout['pieces']
                   and not n.get('from_capture')}
        sequences = {n['path']: n for n in layout['nodes'] if n['role'] == 'sequence'}
        # A static piece renders at the capture if it is visible there, else at its first visible frame.
        wanted = {}
        for path, node in statics.items():
            index = timeline.get('capture_index', 0) if node.get('effective_visible') else node.get('first_visible', 0)
            wanted.setdefault(index, []).append(path)
        frames = timeline.get('capture_index', 0) + timeline.get('period', 0)
        p = Player(player_path, swf)
        pieces, seen = {}, {}
        tmp = Path(tempfile.mkdtemp(prefix='bombit5-art-'))
        try:
            opened = None
            # A screen that opens on the wall clock (its layout has capture phases: the score
            # screen after the original's tweens) opens at another frame in every run, so
            # its timeline starts where its root clip first shows in this run.
            on_clock = bool(timeline.get('capture_index_of'))
            for line in single_steps(case, capture):
                p.command(line)
                if line.startswith('step') and opened is None:
                    if (root_path(p.display(), spec) == layout['screen_root'] if on_clock
                            else timeline.get('opened_frame') == p.frame):
                        opened = p.frame
                if opened is not None and line.startswith('step'):
                    _render_frame(p, p.frame - opened, wanted, sequences, pieces, seen, target, tmp)
            if opened is None:
                opened = p.frame - timeline.get('capture_index', 0)
                if not timeline:  # no recorded timeline: everything renders at the capture
                    _render_frame(p, p.frame - opened, wanted, sequences, pieces, seen, target, tmp)
            p.shot(tmp / 'full.png')
            full = tmp / 'full.png'
            shutil.copy(full, target / 'reference-3x.png')
            while p.frame - opened < frames:
                p.command('step 1')
                _render_frame(p, p.frame - opened, wanted, sequences, pieces, seen, target, tmp)
        finally:
            p.close()
        frames = _record_frames_and_extras(case, capture, layout, player_path, swf, pieces, seen, target)
        states = target / 'states' / 'states.json'
        manifest = {'schema': 'bombit5-original-screen-v2', 'screen': screen,
                    'golden_sha256': layout['source']['golden_sha256'], 'swf_sha256': sha256(swf),
                    'player_sha256': sha256(player_path), 'scale': SCALE,
                    'pieces': {k: v for k, v in pieces.items() if not isinstance(v, dict) or 'frames' not in v},
                    'sequences': {k: v['frames'] for k, v in pieces.items() if isinstance(v, dict) and 'frames' in v},
                    'states': json.loads(states.read_text(encoding='utf-8')) if states.is_file() else {},
                    'frames': frames}
        check = _self_check(layout, manifest, target)
        manifest['self_check'] = check
        (target / 'manifest.json').write_text(json.dumps(manifest, indent=1) + '\n', encoding='utf-8')
        print(f'{screen}: {len(manifest["pieces"])} static pieces, {len(manifest["sequences"])} sequences '
              f'({len(seen)} distinct images); recomposed at the capture vs the reference frame: '
              f'SSIM {check.get("ssim")}, max region ΔE {check.get("max_region_delta_e")}')
        shutil.rmtree(tmp, ignore_errors=True)


def _record_frames_and_extras(case, capture, layout, player_path, swf, pieces, seen, target):
    """Widget frames and parts from other captures, each in a fresh run up to its capture,
    so going to other frames never disturbs the timeline recording. Parts with their own
    timeline (record_screen.py timeline) render their sequences over its period first;
    widget frames come last, since they go to other frames."""
    by_capture = {}
    for node in layout['nodes']:
        # Parts from another capture, and widgets hidden at this one (art_from), render there.
        where = node.get('from_capture') or node.get('art_from') or capture
        if node.get('widget_frames') or (node.get('from_capture') and node['role'] in ('piece', 'sequence')
                                         and (node['path'] in layout['pieces'] or node['role'] == 'sequence')):
            by_capture.setdefault(where, []).append(node)
    frames = {}
    main_index = (layout.get('timeline') or {}).get('capture_index', 0)
    for where, nodes in by_capture.items():
        p = Player(player_path, swf)
        tmp = Path(tempfile.mkdtemp(prefix='bombit5-frames-'))
        own = (layout.get('extra_timelines') or {}).get(where)
        sequences = [n for n in nodes if n['role'] == 'sequence' and n.get('from_capture')]
        # A part timed from when it shows (from_shown) renders its sequence frames from then:
        # the frames before its capture while the case is replayed, the rest after it.
        from_shown = bool(own and own.get('from_shown')) and where != capture
        tops = {(PLAYER_PATHS.get(n['path'], n['path']), n.get('class')) for n in layout['nodes'] if n.get('from_capture') == where
                and next((m for m in layout['nodes'] if m['path'] == n['parent']), {}).get('from_capture') != where}
        shown_at = None

        def render_sequences(index):
            for node in sequences:
                if index in node.get('art_frames', []):
                    entry = pieces.setdefault(node['path'], {'frames': {}})
                    stored = _store(p, node['path'], target, tmp, seen)
                    if stored:
                        entry['frames'][str(index)] = stored

        try:
            for line in single_steps(case, where):
                p.command(line)
                if from_shown and sequences and line.startswith('step'):
                    if tops <= {(n['path'], n.get('class')) for n in p.display()['nodes']}:
                        shown_at = shown_at or p.frame
                        render_sequences(p.frame - shown_at)
                    else:
                        shown_at = None
            index = p.frame - shown_at if from_shown and shown_at else 0
            base = index if where != capture else main_index
            # The player's own 3× frame at this capture: the comparison's resampling ceiling.
            p.shot(target / f'reference-3x-{case["name"]}-{where}.png')
            present = {n['path'] for n in p.display()['nodes']}
            for node in nodes:
                path = node['path']
                if node.get('from_capture') and node['role'] == 'piece' and PLAYER_PATHS.get(path, path) in present:
                    stored = _store(p, path, target, tmp, seen)
                    if stored:
                        pieces[path] = dict(stored, index=base)
            if sequences and own and from_shown:
                start = index
                for index in range(start, int(own['capture_index']) + int(own['period']) + 1):
                    if index > start:
                        p.command('step 1')
                    render_sequences(index)
            elif sequences and own:
                for index in range(own['period'] + 1):
                    if index:
                        p.command('step 1')
                    render_sequences(index)
            present = {n['path'] for n in p.display()['nodes']}
            for node in nodes:
                path = node['path']
                if not node.get('widget_frames'):
                    continue
                if PLAYER_PATHS.get(path, path) not in present:
                    print(f'  warning: {path} not on the display list at the {where} capture; no art')
                    continue
                for frame in node['widget_frames']:
                    stored = _store(p, path, target, tmp, seen, frame, node.get('frames_hide'))
                    if stored:
                        frames.setdefault(path, {})[str(frame)] = dict(stored, index=(index if from_shown else base + index) if where != capture else main_index)
        finally:
            p.close()
            shutil.rmtree(tmp, ignore_errors=True)
    return frames


def _render_frame(p, index, wanted, sequences, pieces, seen, target, tmp):
    for path in wanted.get(index, []):
        stored = _store(p, path, target, tmp, seen)
        if stored:
            pieces[path] = dict(stored, index=index)
    for path, node in sequences.items():
        if index in node.get('art_frames', []):
            entry = pieces.setdefault(path, {'frames': {}})
            stored = _store(p, path, target, tmp, seen)
            if stored:
                entry['frames'][str(index)] = stored


# Layout paths may rename library clips by class; the player knows their original paths.
PLAYER_PATHS = {}


def _store(p, path, target, tmp, seen, frame=None, hide=None):
    raw = tmp / 'piece.png'
    meta = p.piece(PLAYER_PATHS.get(path, path), raw, frame, hide)
    if meta.get('missing'):
        return None  # not on the display list at this frame
    digest = hashlib.sha256(raw.read_bytes() + json.dumps(meta['pixel_origin']).encode()).hexdigest()
    if digest not in seen:
        name = f'piece-{len(seen):05d}.png'
        Image.open(raw).save(target / name)
        seen[digest] = name
    return {'file': seen[digest], **_piece_meta(meta)}


def _blend(below, layer, mode):
    """Composite `layer` over `below` with a Flash blend mode (as scripts/ui/swf_blend.gdshader)."""
    if mode in ('Normal', 'Layer', None):
        return Image.alpha_composite(below, layer)
    d = np.asarray(below, float)[..., :3] / 255
    s = np.asarray(layer, float) / 255
    a = s[..., 3:4]
    src = s[..., :3]
    formulas = {
        'Multiply': lambda: src * d, 'Screen': lambda: 1 - (1 - src) * (1 - d),
        'Lighten': lambda: np.maximum(src, d), 'Darken': lambda: np.minimum(src, d),
        'Difference': lambda: np.abs(src - d), 'Add': lambda: np.minimum(src + d, 1),
        'Subtract': lambda: np.maximum(d - src, 0),
        'Overlay': lambda: np.where(d < 0.5, 2 * src * d, 1 - 2 * (1 - src) * (1 - d)),
        'HardLight': lambda: np.where(src < 0.5, 2 * src * d, 1 - 2 * (1 - src) * (1 - d)),
    }
    b = formulas.get(mode, lambda: src)()
    out = d * (1 - a) + b * a
    return Image.fromarray(np.dstack([out * 255, np.full(out.shape[:2], 255.0)]).round().astype(np.uint8), 'RGBA')


def _self_check(layout, manifest, target):
    timeline = layout.get('timeline') or {}
    index = str(timeline.get('capture_index', 0))
    bg = tuple(layout['stage'].get('background') or [255, 255, 255, 255])
    composite = Image.new('RGBA', (700 * SCALE, 510 * SCALE), tuple(bg[:3]) + (255,))
    for node in layout['nodes']:
        entry = None
        if node.get('from_capture'):
            continue  # recorded in another capture (e.g. a closed dropdown)
        if node['role'] == 'piece' and node.get('effective_visible'):
            entry = manifest['pieces'].get(node['path'])
        elif node['role'] == 'sequence' and node.get('effective_visible'):
            entry = manifest['sequences'].get(node['path'], {}).get(index)
        elif node['role'] == 'group' and node.get('effective_visible') and node.get('frames_hide') is not None:
            # A group widget draws its frame art (its parts laid out inside come after it).
            entry = manifest.get('frames', {}).get(node['path'], {}).get(str(node.get('frame')))
        if not entry:
            continue
        image = Image.open(target / entry['file']).convert('RGBA')
        layer = Image.new('RGBA', composite.size, (0, 0, 0, 0))
        layer.paste(image, tuple(entry['pixel_origin']))
        composite = _blend(composite, layer, node.get('blend_mode', 'Normal'))
    composite.convert('RGB').save(target / 'composite.png')
    # Owner edits (removed nodes) are absent from the composite on purpose; leave them out.
    masks = [[v * SCALE for v in info['render_bounds']] for info in layout.get('owner_edits', {}).get('removed', {}).values()
             if info.get('render_bounds')]
    result = pixels.compare(target / 'reference-3x.png', target / 'composite.png', target / 'composite-heatmap.png',
                            masks=masks)
    return {k: result.get(k) for k in ('ssim', 'max_region_delta_e', 'regions_over', 'worst_region')}


def record_fonts(_case_name, _player_path, swf):
    """The SWF's embedded fonts as TTF (FFDec), for live text, in the local pack:
    original/fonts/ with fonts.json mapping each family to its files, largest first (the
    SWF embeds several subsets of one family; the others serve as fallbacks)."""
    sys.path.insert(0, str(HERE.parent / 'bakeoff'))
    import bakeoff
    jar = bakeoff.ensure_ffdec()
    out = ROOT / 'original' / 'fonts'
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    (ROOT / 'original' / '.gdignore').write_text('')
    import subprocess
    subprocess.run(['java', '-jar', str(jar), '-format', 'font:ttf', '-export', 'font', str(out), str(swf)],
                   check=True, capture_output=True, timeout=1800)
    families = {}
    for f in sorted(out.glob('*.ttf')):
        family = f.stem.split('_', 1)[1] if '_' in f.stem else f.stem
        family = family.split('_')[0]
        families.setdefault(family, []).append(f.name)
    for family in families:
        families[family].sort(key=lambda n: -(out / n).stat().st_size)
    (out / 'fonts.json').write_text(json.dumps(families, indent=1, sort_keys=True) + '\n', encoding='utf-8')
    print(f'fonts: {sum(len(v) for v in families.values())} files, families {", ".join(sorted(families))}')


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('what', choices=['timeline', 'states', 'art', 'fonts'])
    parser.add_argument('case')
    parser.add_argument('--player', type=Path, default=default_player())
    parser.add_argument('--swf', type=Path, default=ROOT / '.scratch' / 'edition-5-research' / 'agame-bomb-it-5-zh-fix.swf')
    args = parser.parse_args()
    if not args.swf.is_file():
        raise SystemExit(f'needs the SWF at {args.swf}')
    if not args.player.is_file():
        raise SystemExit(f'reference player not built: {args.player} (run tools/reference_player/build.sh)')
    {'timeline': record_timeline, 'states': record_states, 'art': record_art, 'fonts': record_fonts}[args.what](
        args.case, args.player.resolve(), args.swf)
    return 0


if __name__ == '__main__':
    sys.exit(main())
