"""Display-list golden -> Godot screen layout (checkpoint 2 converter, no art involved).

    python3 tools/convert/layout.py            # regenerate every screen in SCREENS
    python3 tools/convert/layout.py --check    # fail if a committed layout is stale

A screen layout lists the display objects the Godot screen builds
(scripts/ui/swf_screen.gd), each with its stage matrix and mask relationships:

- Expanded nodes keep their children in the layout: the ancestors of the screen's root
  clip, the root clip itself, and any clip that contains an interactive instance.
- Every other node directly under an expanded node is a *piece*: the reference player
  renders it alone, with its own masks, filters and blends (`piece` command, route A),
  and Godot draws that image. Pieces are marked `baked`, so the node diff does not expect
  their descendants as separate Godot nodes.
- Timeline masks (`clip_depth`) stay as nodes but are never drawn: the pieces they clip
  are rendered already clipped.

Which instances are interactive, and what they do, is the port of each screen's AS3
handlers; the table below cites its sources. Everything else comes from the golden.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from timeline import Timeline  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
GOLDENS = ROOT / 'tests' / 'goldens'
OUT = ROOT / 'scenes' / 'swf'

# Screen -> golden capture, the class of its root clip, and its interactive instances.
SCREENS = {
    # UILoading: the portal preloader; PLAY opens the main menu
    # (docs/evidence/edition-5-screens.md, "Title and publisher screens").
    'title': {'golden': ('main-menu', 'title'), 'root_class': 'UI_loading',
              'interactive': {'btn_play': 'play'}},
    # MainMenuUI: START -> Game Settings, HOW TO PLAY -> controls, quality/sound/music
    # switches (docs/evidence/edition-5-modes-and-flow.md, edition-5-quality.md).
    # MORE GAMES is the portal link; the owner removed it (owner_edits.json).
    'menu': {'golden': ('main-menu', 'menu'), 'root_class': 'UI_MainMenu',
             'interactive': {'startGame': 'start', 'howToPlay': 'how_to_play', 'quality': 'quality',
                             'sound': 'sound', 'music': 'music', 'moregames': 'more_games'},
             # Clips whose frame is a setting, cycled by clicks (`qualityCtlHandle`, the
             # sound and music handlers); the others are buttons with hover/press frames.
             'switches': {'quality': True, 'sound': True, 'music': True}},
    # GameSettingsUI: every widget is driven by the ported controller
    # (scripts/ui/game_settings_ui.gd), so each instance's action is its own name and every
    # frame of it is rendered. The stage dropdown `showMenu` is off the display list until
    # mapMenu or choose is pressed, so it comes from the `dropdown` capture.
    'settings': {'golden': ('game-settings', 'settings'), 'root_class': 'UI_SETTING',
                 'controller': 'game_settings_ui',
                 'interactive': {n: n for n in (
                     'arcadeMode', 'killMode', 'collectMode', 'paintingMode', 'playersOne', 'playersTwo',
                     'enemiesOne', 'enemiesTwo', 'enemiesThree', 'enemiesZero', 'levelsFive', 'levelsTen',
                     'levelsFifteen', 'levelsTwenty', 'mapMenu', 'choose', 'easy', 'normal', 'hard', 'confirm',
                     'back', 'randomStages', 'restaurantStages', 'basketballStages', 'cinemaStages',
                     'weddingStages', 'mysteriousStages', 'caveStages')},
                 'widgets': ('arcadeMode', 'killMode', 'collectMode', 'paintingMode', 'playersOne', 'playersTwo',
                             'enemiesOne', 'enemiesTwo', 'enemiesThree', 'enemiesZero', 'levelsFive', 'levelsTen',
                             'levelsFifteen', 'levelsTwenty', 'mapMenu', 'choose', 'easy', 'normal', 'hard',
                             'confirm', 'back', 'randomStages', 'restaurantStages', 'basketballStages',
                             'cinemaStages', 'weddingStages', 'mysteriousStages', 'caveStages'),
                 'extra': {'dropdown': ['showMenu']},
                 'states': False},
}

EDITS = Path(__file__).resolve().parent / 'owner_edits.json'
# Flash blend modes the screen reproduces (scripts/ui/swf_blend.gdshader).
BLENDS = ('Multiply', 'Screen', 'Lighten', 'Darken', 'Difference', 'Add', 'Subtract', 'Overlay', 'HardLight')

CARRIED = ('kind', 'name', 'class', 'depth', 'character_id', 'effective_visible', 'alpha',
           'stage_matrix', 'stage_bounds', 'render_bounds', 'frame', 'total_frames', 'label',
           'button_state', 'text', 'clip_depth', 'clip_mask', 'mask', 'blend_mode', 'filters')


def parent_of(path):
    return path.rsplit('/', 1)[0]


def _unique_paths(nodes):
    """Goldens recorded before the player made shared sibling names unique (`name@depth`)
    can repeat a path; apply the player's rule so layouts match what it resolves now."""
    seen = {}
    for node in nodes:
        seen.setdefault(node['path'], []).append(node)
    renamed = {}
    for path, group in seen.items():
        if len(group) > 1:
            for node in group:
                renamed[id(node)] = f'{path}@{node["depth"]}'
    if not renamed:
        return nodes
    # Rewrite each renamed node and its descendants (which follow it in document order).
    result, current = [], []
    for original in nodes:
        node = dict(original)
        path = node['path']
        while current and not (path == current[-1][0] or path.startswith(current[-1][0] + '/')):
            current.pop()
        new = renamed.get(id(original))
        if new:
            current.append((path, new))
            node['path'] = new
        elif current:
            old_prefix, new_prefix = current[-1]
            node['path'] = new_prefix + path[len(old_prefix):]
        result.append(node)
    return result


def _shift(bounds, dx, dy):
    return [bounds[0] + dx, bounds[1] + dy, bounds[2] + dx, bounds[3] + dy] if bounds else bounds


def _apply_owner_edits(name, screen_root, layout_nodes, by_path):
    """Remove and move nodes as tools/convert/owner_edits.json says. A move is expressed in
    the original's own quantities (a fraction of the way to another node's position)."""
    spec = json.loads(EDITS.read_text(encoding='utf-8')).get(name, {})
    removed, moved = {}, {}
    for rel, why in spec.get('remove', {}).items():
        path = screen_root + rel
        if path not in by_path:
            raise SystemExit(f'{name}: owner edit removes {rel}, which is not in the golden')
        removed[path] = {'why': why, 'render_bounds': by_path[path].get('render_bounds') or by_path[path].get('stage_bounds')}
    for rel, how in spec.get('move', {}).items():
        path, target = screen_root + rel, screen_root + how['toward']
        if path not in by_path or target not in by_path:
            raise SystemExit(f'{name}: owner edit moves {rel} toward {how["toward"]}, not both in the golden')
        a, b = by_path[path]['stage_matrix'], by_path[target]['stage_matrix']
        axis = how.get('axis', 'xy')
        delta = [round((b[4] - a[4]) * how['fraction'], 4) if 'x' in axis else 0.0,
                 round((b[5] - a[5]) * how['fraction'], 4) if 'y' in axis else 0.0]
        moved[path] = {'by': delta, 'why': how.get('why', ''),
                       'render_bounds': by_path[path].get('render_bounds') or by_path[path].get('stage_bounds')}
    kept = []
    for node in layout_nodes:
        path = node['path']
        if any(path == r or path.startswith(r + '/') for r in removed):
            continue
        for m, info in moved.items():
            if path == m or path.startswith(m + '/'):
                dx, dy = info['by']
                node = dict(node)
                sm = list(node['stage_matrix'])
                sm[4] += dx
                sm[5] += dy
                node['stage_matrix'] = sm
                for key in ('stage_bounds', 'render_bounds'):
                    if node.get(key):
                        node[key] = _shift(node[key], dx, dy)
                node['moved_by'] = [dx, dy]
        kept.append(node)
    edits = {'removed': removed, 'moved': moved}
    if 'open_delay' in spec:
        edits['open_delay'] = spec['open_delay']
    return kept, edits


def build(name, spec):
    case, capture = spec['golden']
    golden_path = GOLDENS / case / f'{capture}.json'
    golden_bytes = golden_path.read_bytes()
    golden = json.loads(golden_bytes)
    nodes = _unique_paths([n for n in golden['nodes'] if n.get('kind') != 'stage'])
    by_path = {n['path']: n for n in nodes}
    roots = [n['path'] for n in nodes if (spec.get('root_class') and n.get('class') == spec['root_class'])
             or n['path'] == spec.get('root_path')]
    if len(roots) != 1:
        raise SystemExit(f'{name}: expected one root clip ({spec.get("root_class") or spec.get("root_path")}), found {len(roots)}')
    screen_root = roots[0]
    # Parts that are off the display list at the capture (a dropdown added on demand) come
    # from another capture of the same case; they start hidden.
    extra_paths = set()
    for extra_capture, names in spec.get('extra', {}).items():
        extra = _unique_paths([n for n in json.loads((GOLDENS / case / f'{extra_capture}.json').read_text(encoding='utf-8'))['nodes']
                               if n.get('kind') != 'stage'])
        for instance in names:
            tops = [n['path'] for n in extra if n['path'].startswith(screen_root + '/')
                    and n['path'].rsplit('/', 1)[-1] == instance]
            if len(tops) != 1:
                raise SystemExit(f'{name}: {instance} not found once in the {extra_capture} capture')
            for n in extra:
                if (n['path'] == tops[0] or n['path'].startswith(tops[0] + '/')) and n['path'] not in by_path:
                    # Only the part itself starts hidden; its children show with it.
                    n = dict(n, initially_hidden=n['path'] == tops[0], from_capture=extra_capture)
                    nodes.append(n)
                    by_path[n['path']] = n
                    extra_paths.add(n['path'])

    def segment_name(path):
        last = path.rsplit('/', 1)[-1]
        return last.split('@')[0] if not last.startswith('@') else None

    interactive = {p: spec['interactive'][segment_name(p)] for p in by_path
                   if p.startswith(screen_root + '/') and segment_name(p) in spec['interactive']}
    missing = set(spec['interactive']) - {segment_name(p) for p in interactive}
    if missing:
        raise SystemExit(f'{name}: interactive instances not in the golden: {sorted(missing)}')

    expanded = set()
    path = screen_root
    while path:
        expanded.add(path)
        path = parent_of(path)
    for p in interactive:
        q = parent_of(p)
        while q.startswith(screen_root):
            expanded.add(q)
            q = parent_of(q)

    # A node that blends with what lies below must be its own piece, so the screen can
    # blend it against the real backdrop: split every group above it.
    # A group that Flash composites on its own (any blend mode, Layer included, or filters,
    # which cache it as a bitmap) contains the blends inside it: the split stops there and
    # that group is the piece.
    for path, node in by_path.items():
        if path.startswith(screen_root + '/') and node.get('blend_mode', 'Normal') in BLENDS:
            chain, q = [], parent_of(path)
            while q.startswith(screen_root):
                group = by_path.get(q, {})
                if q != screen_root and (group.get('blend_mode', 'Normal') != 'Normal' or group.get('filters')):
                    chain = []  # blends inside this group: split only above it
                else:
                    chain.append(q)
                q = parent_of(q)
            expanded.update(chain)
    timeline = Timeline.load(GOLDENS / case / f'{capture}.timeline.json')
    states_path = GOLDENS / case / f'{capture}.states.json'
    states = json.loads(states_path.read_text(encoding='utf-8'))['states'] if states_path.is_file() else {}
    sequences = {}
    if timeline is not None:
        # Animation decides how far groups are split: a part whose inside changes is split
        # into its children while they stay the same; otherwise it is a frame sequence.
        queue = [n['path'] for n in nodes if parent_of(n['path']) in expanded and n['path'] not in expanded]
        while queue:
            path = queue.pop(0)
            node = by_path.get(path, {})
            if node.get('clip_depth'):
                continue
            looks = timeline.look_changes(path)
            if not looks:
                continue
            if path in interactive:
                # A widget animating inside (turning gears on the selected card): a sequence
                # at its recorded frame; its other frames are single images.
                sequences[path] = looks
                continue
            kids = [p for p in by_path if parent_of(p) == path]
            if kids and timeline.children_stable(path):
                expanded.add(path)
                queue += kids
            else:
                sequences[path] = looks

    layout_nodes, warnings = [], []
    for node in nodes:
        path = node['path']
        parent = parent_of(path)
        if path not in expanded and parent not in expanded and parent != '':
            continue  # inside a piece
        entry = {'path': path, 'parent': parent}
        entry.update({k: node[k] for k in CARRIED if k in node})
        if timeline is not None and timeline.changes(path):
            entry['track'] = timeline.tracks[path]
        if path in expanded:
            entry['role'] = 'group'
        elif node.get('clip_depth'):
            entry['role'] = 'mask'
        elif path in sequences:
            entry['role'] = 'sequence'
            entry['baked'] = True
            present = [i for i in range(timeline.frames) if (timeline.state(path, i) or [0] * 9)[6]]
            # Art where the look changes, plus where it first shows and at the capture.
            points = set(sequences[path]) | {timeline.data['capture_index']} | ({present[0]} if present else set())
            entry['art_frames'] = sorted(i for i in points if i in set(present))
        else:
            entry['role'] = 'piece'
            entry['baked'] = True
            if node.get('blend_mode', 'Normal') not in ('Normal', 'Layer', 'Multiply', 'Screen', 'Lighten', 'Darken',
                                                        'Difference', 'Add', 'Subtract', 'Overlay', 'HardLight'):
                warnings.append(f'{path}: piece blends ({node["blend_mode"]}) with what lies below, in a mode '
                                'the screen cannot reproduce; rendered alone it will look different')
        if node.get('from_capture'):
            entry['from_capture'] = node['from_capture']
            if node.get('initially_hidden'):
                entry['initially_hidden'] = True
        if segment_name(path) in spec.get('widgets', ()) and (node.get('total_frames') or 1) > 1:
            # Every frame of a widget clip is rendered (selected, disabled, …): its screen
            # controller shows them with set_frame, as the AS3 does with gotoAndStop.
            entry['widget_frames'] = list(range(1, int(node['total_frames']) + 1))
        if path in interactive:
            entry['action'] = interactive[path]
            if path in states:
                entry['states'] = dict(states[path])
                # A button whose screen is gone right after the press acts on press, as the
                # original's MOUSE_DOWN handlers do (no press frame could be recorded).
                if states[path].get('kind') == 'button':
                    entry['states']['acts_on'] = 'press' if states[path].get('press') is None else 'release'
        if timeline is not None and entry.get('role') == 'piece' and not node.get('effective_visible'):
            first = timeline.first_visible(path)
            if first is not None:
                entry['first_visible'] = first
        layout_nodes.append(entry)
    layout_nodes, edits = _apply_owner_edits(name, screen_root, layout_nodes, by_path)
    # A visible node with no bounds draws nothing (an empty sprite: char 295 in the title
    # screen is one frame with zero placements). Asking the reference player for such a
    # piece makes it crop a zero-size rectangle, so skip it and say so; never drop art
    # silently.
    pieces = []
    for n in layout_nodes:
        if n['role'] != 'piece' or not (n.get('effective_visible') or 'first_visible' in n):
            continue
        if n.get('render_bounds') or n.get('stage_bounds'):
            pieces.append(n['path'])
        else:
            warnings.append(f'{n["path"]}: no bounds at this frame (empty clip); not rendered as a piece')
    return {
        'schema': 'bombit5-swf-layout-v1',
        'screen': name,
        'note': 'Generated by tools/convert/layout.py from the golden; do not edit.',
        'source': {'golden': str(golden_path.relative_to(ROOT)),
                   'golden_sha256': hashlib.sha256(golden_bytes).hexdigest(),
                   'frame': golden.get('frame')},
        'stage': golden['stage'],
        'screen_root': screen_root,
        'pieces': pieces,
        'warnings': warnings,
        'owner_edits': edits,
        'controller': spec.get('controller'),
        'timeline': None if timeline is None else {
            k: timeline.data[k] for k in ('opened_frame', 'opened_after_input', 'capture_index', 'period', 'period_capped')},
        'nodes': layout_nodes,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    stale = []
    for name, spec in SCREENS.items():
        layout = build(name, spec)
        text = json.dumps(layout, indent=1, sort_keys=True) + '\n'
        target = OUT / f'{name}.json'
        if args.check:
            if not target.is_file() or target.read_text(encoding='utf-8') != text:
                stale.append(name)
            continue
        target.write_text(text, encoding='utf-8')
        roles = {r: sum(1 for n in layout['nodes'] if n['role'] == r) for r in ('group', 'piece', 'mask', 'sequence')}
        tracked = sum(1 for n in layout['nodes'] if 'track' in n)
        print(f'{name}: {roles["group"]} groups, {len(layout["pieces"])} visible pieces '
              f'({roles["piece"]} in all), {roles["sequence"]} sequences, {roles["mask"]} masks, '
              f'{tracked} animated nodes -> {target.relative_to(ROOT)}')
        for warning in layout['warnings']:
            print(f'  warning: {warning}')
    if stale:
        print(f'stale layouts: {", ".join(stale)}; run tools/convert/layout.py')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
