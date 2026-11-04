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
    # switches (docs/evidence/edition-5-modes-and-flow.md, edition-5-quality.md);
    # MORE GAMES is the portal link, shown but inert.
    'menu': {'golden': ('main-menu', 'menu'), 'root_class': 'UI_MainMenu',
             'interactive': {'startGame': 'start', 'howToPlay': 'how_to_play', 'quality': 'quality',
                             'sound': 'sound', 'music': 'music', 'moregames': 'more_games'}},
}

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

    layout_nodes, warnings = [], []
    for node in nodes:
        path = node['path']
        parent = parent_of(path)
        if path not in expanded and parent not in expanded and parent != '':
            continue  # inside a piece
        entry = {'path': path, 'parent': parent}
        entry.update({k: node[k] for k in CARRIED if k in node})
        if path in expanded:
            entry['role'] = 'group'
        elif node.get('clip_depth'):
            entry['role'] = 'mask'
        else:
            entry['role'] = 'piece'
            entry['baked'] = True
            if node.get('blend_mode', 'Normal') not in ('Normal', 'Layer'):
                warnings.append(f'{path}: piece blends ({node["blend_mode"]}) with what lies below; '
                                'rendered alone it will look different')
        if path in interactive:
            entry['action'] = interactive[path]
        layout_nodes.append(entry)
    # A visible node with no bounds draws nothing (an empty sprite: char 295 in the title
    # screen is one frame with zero placements). Asking the reference player for such a
    # piece makes it crop a zero-size rectangle, so skip it and say so; never drop art
    # silently.
    pieces = []
    for n in layout_nodes:
        if n['role'] != 'piece' or not n.get('effective_visible'):
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
        roles = {r: sum(1 for n in layout['nodes'] if n['role'] == r) for r in ('group', 'piece', 'mask')}
        print(f'{name}: {roles["group"]} groups, {len(layout["pieces"])} visible pieces '
              f'({roles["piece"]} in all), {roles["mask"]} masks -> {target.relative_to(ROOT)}')
        for warning in layout['warnings']:
            print(f'  warning: {warning}')
    if stale:
        print(f'stale layouts: {", ".join(stale)}; run tools/convert/layout.py')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
