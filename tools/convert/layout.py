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
    # CharacterSelectUI + ClothesPanel (scripts/ui/character_select_ui.gd, clothes_panel.gd).
    # Each robot's display (robotStage1/robotMc/robot<N>) and clothes panel
    # (Art_clothPanel<N>, made from the library when the robot is chosen) come from the
    # capture with that robot selected.
    'character': {'golden': ('character-select', 'char0'), 'root_class': 'UI_SELECTCHARACTER',
                  'controller': 'character_select_ui',
                  'class_segments': ('Art_clothPanel',),
                  'interactive': {n: n for n in (
                      [f'robotIcon{i}' for i in range(8)] + ['startBtn', 'backBtn', 'setAvatarBt', 'robotStage1',
                      'robotStage2'] + [f'icon{i}' for i in range(1, 7)] + [f'hat{i}' for i in range(1, 7)])},
                  'optional_interactive': tuple([f'icon{i}' for i in range(1, 7)] + [f'hat{i}' for i in range(1, 7)]),
                  'widgets': tuple([f'robotIcon{i}' for i in range(8)] + ['startBtn', 'backBtn', 'setAvatarBt',
                      'robotStage1', 'robotStage2', 'bodyMc', 'hatMc'] + [f'icon{i}' for i in range(1, 7)]
                      + [f'hat{i}' for i in range(1, 7)]),
                  'extra': {f'char{n}': [f'robotStage1/robotMc/robot{n}', f'class:Art_clothPanel{n}'] for n in range(1, 8)},
                  'states': False},
    # HowToPlayUI (scripts/ui/how_to_play_ui.gd): buttons, the message clip's frames and the
    # 1P key caps, live TextFields that are clicked to rebind.
    'controls': {'golden': ('how-to-play', 'controls'), 'root_class': 'UI_CONTROLS',
                 'controller': 'how_to_play_ui',
                 'interactive': {n: n for n in ('back', 'powerUps', 'defaule', 'save', 'onePOneUp', 'onePOneLeft',
                                                'onePOneDown', 'onePOneRight', 'onePOneBomb')},
                 'widgets': ('back', 'powerUps', 'defaule', 'save', 'messenge'),
                 'live_text': ('onePOneUp', 'onePOneLeft', 'onePOneDown', 'onePOneRight', 'onePOneBomb'),
                 'states': False},
    # PowerUpsUI (scripts/ui/power_ups_ui.gd).
    'powerups': {'golden': ('how-to-play', 'powerups'), 'root_class': 'UI_POWER_UPS',
                 'controller': 'power_ups_ui',
                 'interactive': {n: n for n in ('back', 'controls')},
                 'widgets': ('back', 'controls'),
                 'states': False},
    # OnePScoreUI on PlayerScoreUI (scripts/ui/one_p_score_ui.gd, player_score_ui.gd): the
    # one-player score screen. win-score (level complete, NEXT) is the main capture. The
    # failed title (levelTitle frame 2 shows title4) comes from loss-score; RESTART is hidden
    # at win-score, so its frames are drawn at loss-score, where it shows (art_from). The
    # unlock tip (UnlockTipScreen, class UI_UNLOCK_TIP) is a clip the controller adds to this
    # screen's own clip (`__pmc.addChild`), so it is a part of this screen from the unlock-tip
    # capture, with the tip's clothes panel and unlock bursts (Art_clothPanel0,
    # Art_unlockAnimas, made from the library) addressed by class. Only robot 0's looks are
    # recorded on the tip (the case plays robot 0). MORE GAMES and the publisher logos
    # (__id12_) are original parts of this screen; no owner edit covers them yet.
    'score': {'golden': ('results', 'win-score'), 'root_class': 'UI_LEVEL_COMPLETED_ONEP',
              'controller': 'one_p_score_ui',
              'class_segments': ('UI_UNLOCK_TIP', 'Art_clothPanel', 'Art_unlockAnimas'),
              'interactive': {n: n for n in (
                  ['nextLevel', 'restartBtn', 'dressUpBtn', 'moregames', 'okBt', 'robotBtn1']
                  + [f'icon{i}' for i in range(1, 7)] + [f'hat{i}' for i in range(1, 7)])},
              'optional_interactive': tuple([f'icon{i}' for i in range(1, 7)] + [f'hat{i}' for i in range(1, 7)]),
              'widgets': tuple(['nextLevel', 'restartBtn', 'dressUpBtn', 'moregames', 'bonus_txt', 'modePic',
                                'text_mode', 'okBt', 'robotBtn1', 'bodyMc', 'hatMc']
                               + [f'icon{i}' for i in range(1, 7)] + [f'hat{i}' for i in range(1, 7)]),
              'live_text': ('kill', 'time', 'difficulity', 'levelScore', 'total', 'LevelOver_1', 'LevelOver_2',
                            'scoreText'),
              'extra': {'unlock-tip': ['class:UI_UNLOCK_TIP'], 'loss-score': ['title/title4']},
              'art_from': {'loss-score': ['restartBtn']},
              # Godot opens this screen itself (a dev launch with the recorded points), at
              # the timeline index each capture was taken at.
              'capture_phase': ('unlock-tip', 'win-score', 'loss-score'),
              'states': False},
    # OnePGameOverUI on PlayerGameOver (scripts/ui/one_p_game_over_ui.gd,
    # player_game_over.gd): the end screen after the last heart (UI_GAMEOVERONEP, game-over
    # case) and after the last level (UI_CONGRATULATIONSONEP, game-win case). TRY AGAIN
    # (`back`) returns to Game Settings; `score` is the final total, `p1head` the robot (only
    # robot 0's head is recorded: the cases play robot 0). MORE GAMES and the publisher logos
    # (`Logos`) are portal parts, removed by owner edits.
    'game_over': {'golden': ('game-over', 'game-over'), 'root_class': 'UI_GAMEOVERONEP',
                  'controller': 'one_p_game_over_ui',
                  'interactive': {n: n for n in ('back', 'moregames')},
                  'widgets': ('back', 'moregames'),
                  'live_text': ('score',),
                  # Opened by the round's end on the wall clock (realtime), as the score
                  # screen: Godot opens it itself at the recorded capture's timeline index.
                  'capture_phase': ('game-over',),
                  'states': False},
    'game_win': {'golden': ('game-win', 'congratulations'), 'root_class': 'UI_CONGRATULATIONSONEP',
                 'controller': 'one_p_game_over_ui',
                 'interactive': {n: n for n in ('back', 'moregames')},
                 'widgets': ('back', 'moregames'),
                 'live_text': ('score',),
                 # FallSnow (PlayerGameOver.initView, GAME_WIN; scripts/ui/fall_snow.gd): the
                 # confetti Bitmaps it adds to the stage at random (`creatSnow`) are made by
                 # the port at run time, not laid out. Their art is every frame of the
                 # library clip `fallSnow` drawn into a 25x25 BitmapData (`FallSnow.init`).
                 'effects': {'FallSnow': {'class': 'flash.display::Bitmap', 'art_class': 'fallSnow',
                                          'bitmap_size': [25, 25]}},
                 'states': False},
    # The gameplay screen (checkpoint 4): the Game's two containers under GameMc
    # (`Game.displayReInit`, `UIManager.mainMC`). The UI container holds GameInterFace's
    # UI_interface (scripts/ui/game_inter_face.gd): the frame bitmap, the level and time
    # fields, one panel `robotUI<N>` per robot (frames: 1 enemy, 2 P1, 3 P2, 4 no robot) with
    # its live counters, and PAUSE (a zlong Button). The board container (gameMainContainer,
    # scaled 32/30) holds the BackGround bitmap and one row sprite per map row, each with
    # five layers; `board` below splits those out (`_split_board`): the box layer and the
    # platforms on layer 0 become tiles the board view lays out from the round
    # (scripts/ui/game_board.gd), everything else in the row layers is a moving actor
    # (robots, bombs, items, flames: slice b) and is left out of this layout.
    'game': {'golden': ('gameplay-cinema-start', 'cinema-start'), 'root_path': '/root1/__mainMc/GameMc',
             'controller': 'game_inter_face',
             'board': {
                 # gameMainContainer: GameMc's first child (`stageContainer.addChildAt(..., 0)`).
                 'container': '@0#0',
                 # bgContainer at 0, an empty Sprite at 1, then one row Sprite per map row
                 # (`addChildAt(row, y + 2)`), each with its layers in child order:
                 # 0 platforms and flames (AbstractPlatForm, Bomb.blast), 1 boxes (Box.init),
                 # 2 bombs and pickups (Bomb), 3 robots, 4 effects.
                 'first_row': 2,
                 'layers': ('platform', 'box', 'bomb', 'robot', 'effect'),
                 # Classes on the platform layer that are part of the board (Portal.setMc
                 # `Art_Portal_<colorId>`); anything else there (a blast's flames) moves.
                 'features': ('Art_Portal_',),
                 # CinemaMapData: `beginNum` 49; MapMaster.createRow draws every Cinema box
                 # from `_brick5` frames beginNum .. beginNum + 23 (the wall and centre at +23).
                 'begin_num': 49},
             'interactive': {'pause': 'pause'},
             'widgets': tuple(f'robotUI{i}' for i in range(8)) + ('faceMc', 'pause'),
             'live_text': ('currentLevel', 'totalLevel', 'time', 'lifeTf', 'bombTf', 'powerTf', 'speedTf',
                           'scoreTf'),
             'timeline': False,
             'states': False},
}

EDITS = Path(__file__).resolve().parent / 'owner_edits.json'
# Flash blend modes the screen reproduces (scripts/ui/swf_blend.gdshader).
BLENDS = ('Multiply', 'Screen', 'Lighten', 'Darken', 'Difference', 'Add', 'Subtract', 'Overlay', 'HardLight')

CARRIED = ('golden_path', 'kind', 'name', 'class', 'depth', 'character_id', 'effective_visible', 'alpha',
           'stage_matrix', 'stage_bounds', 'render_bounds', 'frame', 'total_frames', 'label',
           'button_state', 'text', 'text_format', 'clip_depth', 'clip_mask', 'mask', 'blend_mode', 'filters',
           'filter_list')


def parent_of(path):
    return path.rsplit('/', 1)[0]


def _names_path(relative):
    """`robotStage1/robotMc@3/robot3` -> `robotStage1/robotMc/robot3` (names, depths kept for @)."""
    return '/'.join(p if p.startswith('@') else p.split('@')[0] for p in relative.split('/'))


def _matches(node, relative, selector):
    """An extra-part selector: `class:<Class>`, a relative path of names, or a bare name."""
    if selector.startswith('class:'):
        return node.get('class') == selector[6:]
    if '/' in selector:
        return _names_path(relative) == selector
    return relative.rsplit('/', 1)[-1].split('@')[0] == selector


def _class_segments(nodes, prefixes):
    if not prefixes:
        return nodes
    # Original path of each such clip -> its class, which replaces its `@depth` segment
    # (also inside another renamed clip: the unlock tip's own clothes panel).
    renamed = {}
    for node in nodes:
        last = node['path'].rsplit('/', 1)[-1]
        if last.startswith('@') and (node.get('class') or '').startswith(prefixes):
            renamed[node['path']] = node['class']
    if not renamed:
        return nodes
    out = []
    for node in nodes:
        parts = node['path'].split('/')
        new = [renamed.get('/'.join(parts[:k + 1]), parts[k]) for k in range(len(parts))]
        if new != parts:
            node = dict(node, path='/'.join(new), golden_path=node.get('golden_path', node['path']))
        out.append(node)
    return out


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
    the original's own quantities: a fraction of the way from the node (or from another
    node, `from`, so that a row moves by one step) to another node's position."""
    spec = json.loads(EDITS.read_text(encoding='utf-8')).get(name, {})
    removed, moved = {}, {}
    for rel, why in spec.get('remove', {}).items():
        path = screen_root + rel
        if path not in by_path:
            raise SystemExit(f'{name}: owner edit removes {rel}, which is not in the golden')
        removed[path] = {'why': why, 'render_bounds': by_path[path].get('render_bounds') or by_path[path].get('stage_bounds')}
    for rel, how in spec.get('move', {}).items():
        path, target = screen_root + rel, screen_root + how['toward']
        origin = screen_root + how.get('from', rel)
        if path not in by_path or target not in by_path or origin not in by_path:
            raise SystemExit(f'{name}: owner edit moves {rel} toward {how["toward"]}, not all in the golden')
        a, b = by_path[origin]['stage_matrix'], by_path[target]['stage_matrix']
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
    # Unnamed clips made from the library at run time (`Attach.getSprite("Art_clothPanel3")`)
    # all sit at the same depth; such a clip takes its class as its segment, so each is
    # addressable. The original path stays as `golden_path` for the comparison.
    prefixes = tuple(spec.get('class_segments', ()))
    nodes = _class_segments(nodes, prefixes)
    board = None
    if spec.get('board'):
        nodes, board = _split_board(name, spec, case, capture, nodes, screen_root)
    by_path = {n['path']: n for n in nodes}

    # Parts that are off the display list at the capture (a dropdown added on demand, the
    # other robots' panels) come from other captures of the same case; they start hidden.
    extra_paths = set()
    for extra_capture, selectors in spec.get('extra', {}).items():
        extra = _unique_paths([n for n in json.loads((GOLDENS / case / f'{extra_capture}.json').read_text(encoding='utf-8'))['nodes']
                               if n.get('kind') != 'stage'])
        extra = _class_segments(extra, prefixes)
        extra_by_path = {n['path']: n for n in extra}
        for selector in selectors:
            tops = [n['path'] for n in extra if n['path'].startswith(screen_root + '/')
                    and _matches(n, n['path'][len(screen_root) + 1:], selector)]
            if len(tops) != 1:
                raise SystemExit(f'{name}: {selector} not found once in the {extra_capture} capture ({len(tops)})')
            if tops[0] in by_path:
                continue  # already on the main capture
            for n in extra:
                if (n['path'] == tops[0] or n['path'].startswith(tops[0] + '/')) and n['path'] not in by_path:
                    # Only the part itself starts hidden; its children show with it.
                    n = dict(n, initially_hidden=n['path'] == tops[0], from_capture=extra_capture,
                             parent_frame_there=extra_by_path.get(parent_of(n['path']), {}).get('frame'))
                    nodes.append(n)
                    by_path[n['path']] = n
                    extra_paths.add(n['path'])

    def segment_name(path):
        last = path.rsplit('/', 1)[-1]
        return last.split('@')[0] if not last.startswith('@') else None

    interactive = {p: spec['interactive'][segment_name(p)] for p in by_path
                   if p.startswith(screen_root + '/') and segment_name(p) in spec['interactive']}
    missing = set(spec['interactive']) - set(spec.get('optional_interactive', ())) - {segment_name(p) for p in interactive}
    if missing:
        raise SystemExit(f'{name}: interactive instances not in the golden: {sorted(missing)}')

    expanded = set()
    path = screen_root
    while path:
        expanded.add(path)
        path = parent_of(path)
    if board:
        # The board's containers stay groups: the board view adds its tiles to the layers.
        expanded |= set(board['groups'])
    # Interactive instances, widgets and parts from other captures each stay their own
    # node, so every group above them is split.
    keep = set(interactive) | {p for p in by_path if p.startswith(screen_root + '/')
                               and segment_name(p) in tuple(spec.get('widgets', ())) + tuple(spec.get('live_text', ()))}
    keep |= {p for p in extra_paths if by_path[p].get('initially_hidden')}
    for p in keep:
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
    # Parts from other captures loop on their own timeline (record_screen.py timeline).
    extra_timelines = {c: Timeline.load(GOLDENS / case / f'{c}.timeline.json') for c in spec.get('extra', {})}

    def tl(path):
        node = by_path.get(path, {})
        return extra_timelines.get(node['from_capture']) if node.get('from_capture') else timeline

    def key(path):
        return by_path.get(path, {}).get('golden_path', path)

    # Parts of a split group that are on its timeline but off the display list at the
    # capture (robot 7's first arms, swapped for others during its entrance) are added
    # from their tracks, so the whole entrance plays.
    _add_absent_at_capture(nodes, by_path, expanded, screen_root, tl, key)
    if timeline is not None or any(extra_timelines.values()):
        # Animation decides how far groups are split: a part whose inside changes is split
        # into its children while they stay the same; otherwise it is a frame sequence.
        queue = [n['path'] for n in nodes if parent_of(n['path']) in expanded and n['path'] not in expanded]
        while queue:
            path = queue.pop(0)
            node = by_path.get(path, {})
            if node.get('clip_depth') or tl(path) is None:
                continue
            looks = tl(path).look_changes(key(path))
            if not looks:
                continue
            if path in interactive:
                # A widget animating inside (turning gears on the selected card): a sequence
                # at its recorded frame; its other frames are single images.
                sequences[path] = looks
                continue
            kids = [p for p in by_path if parent_of(p) == path]
            # A group Flash composites on its own (filters or a blend: p2head's outline)
            # cannot be split without losing that pass; it plays as a sequence.
            composites = node.get('filters') or node.get('blend_mode', 'Normal') != 'Normal'
            composites = composites or tl(path).has_filters(key(path))
            # Its own colour tween is baked into its art (pieces render with their
            # ancestors' colour), so it plays as rendered frames too.
            composites = composites or tl(path).colour_changes(key(path))
            # Likewise its own fade: Flash fades each shape inside, so overlaps compound.
            composites = composites or tl(path).alpha_changes(key(path))
            if kids and not composites and tl(path).children_stable(key(path)):
                expanded.add(path)
                queue += kids
            else:
                sequences[path] = looks

    # A widget that is also a group (robotStage1: highlight frames behind a robot) draws its
    # frames as art without the parts laid out inside it; its other children are that art.
    group_widgets = {p for p in expanded if p.startswith(screen_root + '/') and segment_name(p) in spec.get('widgets', ())
                     and (by_path[p].get('total_frames') or 1) > 1}
    # A widget hidden at the main capture (RESTART after a win) cannot be rendered there:
    # its frames are rendered at another capture of the case where it shows.
    art_from = {}
    for other, names in spec.get('art_from', {}).items():
        shown = {n['path'] for n in _class_segments(_unique_paths(json.loads(
            (GOLDENS / case / f'{other}.json').read_text(encoding='utf-8'))['nodes']), prefixes) if n.get('effective_visible')}
        for p in by_path:
            if p.startswith(screen_root + '/') and segment_name(p) in names and not by_path[p].get('from_capture'):
                if p not in shown:
                    raise SystemExit(f'{name}: {p} does not show at the {other} capture either')
                art_from[p] = other
    # A widget frame shown animated in another capture (robotIcon3 selected, eyes blinking,
    # at char3) plays that capture's sequence there, on that capture's clock; its other
    # frames stay single images (widget_frames). Each frame takes the first capture, in
    # the spec's order, where it shows and animates.
    frame_sequences = {}
    for path in by_path:
        node = by_path[path]
        if (path in expanded or node.get('from_capture') or not path.startswith(screen_root + '/')
                or segment_name(path) not in spec.get('widgets', ()) or (node.get('total_frames') or 1) <= 1):
            continue
        for c, x in extra_timelines.items():
            if x is None or key(path) not in x.tracks:
                continue
            looks = set(x.look_changes(key(path)))
            shown = {}
            for i in range(x.frames):
                s = x.state(key(path), i)
                if s and s[6] and (s[7] or 0) != (node.get('frame') or 0):
                    shown.setdefault(int(s[7]), []).append(i)
            for f, present in shown.items():
                if str(f) in frame_sequences.get(path, {}) or not looks & set(present):
                    continue
                points = (looks | {present[0], x.data['capture_index']}) & set(present)
                frame_sequences.setdefault(path, {})[str(f)] = {'capture': c, 'art_frames': sorted(points)}
    layout_nodes, warnings, covered = [], [], {}
    effects = {e: dict(how, nodes={}) for e, how in spec.get('effects', {}).items()}
    for node in nodes:
        path = node['path']
        parent = parent_of(path)
        effect = next((e for e, how in spec.get('effects', {}).items()
                       if parent == '' and node.get('class') == how['class']), None)
        if effect:
            # Made at random by a ported effect: the comparison checks them by its rules.
            effects[effect]['nodes'][node.get('golden_path', path)] = {
                k: node[k] for k in ('stage_matrix', 'render_bounds', 'color_transform', 'effective_visible') if k in node}
            continue
        if path not in expanded and parent not in expanded and parent != '':
            continue  # inside a piece
        if parent in group_widgets and path not in expanded:
            covered.setdefault(parent, []).append(node.get('golden_path', path))
            continue  # drawn by its group's frame art
        entry = {'path': path, 'parent': parent}
        entry.update({k: node[k] for k in CARRIED if k in node})
        own = tl(path)
        if own is not None and own.changes(key(path)):
            entry['track'] = own.tracks[key(path)]
        if own is not None and node.get('from_capture'):
            entry['timeline_of'] = node['from_capture']
        if path in expanded:
            entry['role'] = 'group'
        elif node.get('clip_depth'):
            entry['role'] = 'mask'
        elif path in sequences:
            entry['role'] = 'sequence'
            entry['baked'] = True
            present = [i for i in range(own.frames) if (own.state(key(path), i) or [0] * 9)[6]]
            # Art where the look changes, plus where it first shows and at the capture.
            points = set(sequences[path]) | {own.data['capture_index']} | ({present[0]} if present else set())
            entry['art_frames'] = sorted(i for i in points if i in set(present))
        else:
            entry['role'] = 'piece'
            entry['baked'] = True
            if node.get('blend_mode', 'Normal') not in ('Normal', 'Layer', 'Multiply', 'Screen', 'Lighten', 'Darken',
                                                        'Difference', 'Add', 'Subtract', 'Overlay', 'HardLight'):
                warnings.append(f'{path}: piece blends ({node["blend_mode"]}) with what lies below, in a mode '
                                'the screen cannot reproduce; rendered alone it will look different')
        if node.get('parent_frame_there'):
            entry['parent_frame'] = node['parent_frame_there']
        elif parent in by_path and by_path[parent].get('frame'):
            # The parent's frame when this node was recorded: a clip's timeline shows
            # different children per frame (robotMc shows robot<N> on frame N+1).
            entry['parent_frame'] = by_path[parent]['frame']
        if node.get('from_capture'):
            entry['from_capture'] = node['from_capture']
            if node.get('initially_hidden'):
                entry['initially_hidden'] = True
        if path in group_widgets:
            entry['frames_hide'] = [by_path[p].get('golden_path', p) for p in expanded if parent_of(p) == path]
        if segment_name(path) in spec.get('widgets', ()) and (node.get('total_frames') or 1) > 1:
            # Every frame of a widget clip is rendered (selected, disabled, …): its screen
            # controller shows them with set_frame, as the AS3 does with gotoAndStop.
            entry['widget_frames'] = list(range(1, int(node['total_frames']) + 1))
        if path in frame_sequences:
            entry['frame_sequences'] = frame_sequences[path]
        if path in art_from:
            entry['art_from'] = art_from[path]
        if path in interactive:
            entry['action'] = interactive[path]
            if path in states:
                entry['states'] = dict(states[path])
                # A button whose screen is gone right after the press acts on press, as the
                # original's MOUSE_DOWN handlers do (no press frame could be recorded).
                if states[path].get('kind') == 'button':
                    entry['states']['acts_on'] = 'press' if states[path].get('press') is None else 'release'
        if own is not None and entry.get('role') == 'piece':
            index = _art_index(own, path, screen_root, by_path, tl, key)
            if index is not None:
                entry['art_index'] = index
        if own is not None and entry.get('role') == 'piece' and not node.get('effective_visible'):
            first = own.first_visible(key(path))
            if first is not None:
                entry['first_visible'] = first
        layout_nodes.append(entry)
    for e in layout_nodes:
        if e['path'] in covered:
            e['covers'] = covered[e['path']]
    # A parent frame matters only where the children of one clip were recorded on different
    # frames of it (robotMc's robots): those follow the parent's frame instead of starting
    # hidden. Elsewhere the parent frame is dropped.
    by_parent = {}
    for e in layout_nodes:
        if 'parent_frame' in e:
            by_parent.setdefault(e['parent'], set()).add(e['parent_frame'])
    for e in layout_nodes:
        if 'parent_frame' in e:
            if len(by_parent.get(e['parent'], ())) > 1:
                e.pop('initially_hidden', None)
            else:
                del e['parent_frame']
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
    phases = _capture_phases(spec, case, timeline, screen_root) if timeline is not None else None
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
        'extra_timelines': _extra_shown_before(spec, case, extra_timelines, phases),
        'timeline': None if timeline is None else dict(
            {k: timeline.data[k] for k in ('opened_frame', 'opened_after_input', 'capture_index', 'period', 'period_capped')},
            **({'capture_index_of': phases} if phases else {})),
        'nodes': layout_nodes,
        **({'effects': effects} if effects else {}),
        **({'board': {k: v for k, v in board.items() if k != 'groups'}} if board else {}),
    }


def _segment_index(path):
    """`@0#5` -> 5: the order of an unnamed child among its same-depth siblings (0 if alone)."""
    last = path.rsplit('/', 1)[-1]
    return int(last.split('#')[1]) if '#' in last else 0


def _local_point(matrix, x, y):
    """Stage point -> the local space of a node with stage matrix `matrix`."""
    a, b, c, d, tx, ty = matrix
    det = a * d - b * c
    x, y = x - tx, y - ty
    return ((d * x - c * y) / det, (-b * x + a * y) / det)


def _union(bounds):
    bounds = [b for b in bounds if b]
    if not bounds:
        return None
    return [min(b[0] for b in bounds), min(b[1] for b in bounds), max(b[2] for b in bounds), max(b[3] for b in bounds)]


def _split_board(name, spec, case, capture, nodes, screen_root):
    """Take the map out of the gameplay screen's golden (`board` in the spec).

    The board container and its row and layer Sprites stay in the layout as groups. Their
    contents are not laid out: the board view makes them from the round (scripts/ui/
    game_board.gd), so the layout describes them instead:

    - `boxes`: every Box (`Box.init`: a Sprite per box on its row's box layer, created in
      column order by `MapMaster.createRow`) with its cell, `_brick5` frame, whether its clip
      shows (`setBoxVisible`: the centre's hold cells keep an empty Sprite) and whether it is
      a breakable box (`isExist`: `Box.setItem` shrinks its clip to 0.9 and centres it);
    - `features`: the platforms on layer 0 that belong to the map (Portal), by class;
    - `dynamic`: everything else in the row layers (robots, bombs, pickups, flames), with its
      render bounds, which the comparison leaves out of the node diff and the pixel score;
    - `excursion` and `grid`: where cell (x, y) lies in the board container, fitted to the
      recorded boxes (the AS3 sets `x = xN * GRID_WIDTH + EXCURSION_X`, `AbstractObject`);
    - `robots` and `robot_ui_slots`: the recorded round's robots in seat order and the HUD
      panel positions (`GameInterFace.initView` moves robotUI<robot> to slot k), read from the
      panels that show;
    - `template`: the stage-set layout (assets/maps/layouts.json) this round was rolled from,
      the one whose fixed cells, centre and portals the recorded boxes match;
    - `round_start_after_input`: frames from the last input (START) to the capture, which the
      case takes on the round's first frame (no map-loading screen, UI_reading, left).
    """
    how = spec['board']
    container = f'{screen_root}/{how["container"]}'
    by_path = {n['path']: n for n in nodes}
    if container not in by_path:
        raise SystemExit(f'{name}: board container {container} not in the golden')
    if any(n.get('class') == 'UI_reading' for n in nodes):
        raise SystemExit(f'{name}: the map-loading screen still shows at the capture; capture the round\'s first frame')
    kids = sorted((p for p in by_path if parent_of(p) == container), key=_segment_index)
    rows = [p for p in kids if _segment_index(p) >= how['first_row']]
    layers = {}
    for y, row in enumerate(rows):
        own = sorted((p for p in by_path if parent_of(p) == row), key=_segment_index)
        if len(own) != len(how['layers']):
            raise SystemExit(f'{name}: row {row} has {len(own)} layers, expected {len(how["layers"])}')
        for k, layer in enumerate(own):
            layers[layer] = (y, how['layers'][k])
    cm = by_path[container]['stage_matrix']

    def subtree(path):
        return [n for n in nodes if n['path'] == path or n['path'].startswith(path + '/')]

    boxes, features, dynamic, robots = [], [], {}, []
    for layer, (y, role) in layers.items():
        for child in sorted((p for p in by_path if parent_of(p) == layer), key=_segment_index):
            tree = subtree(child)
            classes = [n.get('class') or '' for n in tree]
            node = by_path[child]
            local = _local_point(cm, node['stage_matrix'][4], node['stage_matrix'][5])
            if role == 'box':
                brick = next((n for n in tree if n.get('class') == '_brick5'), None)
                mc = by_path.get(child + '/@0')
                exist = bool(mc) and abs(mc['stage_matrix'][0] / node['stage_matrix'][0] - 0.9) < 1e-3
                boxes.append({'path': child, 'row': y, 'local': [round(local[0], 3), round(local[1], 3)],
                              'frame': brick['frame'] if brick else None, 'shown': brick is not None,
                              'exist': exist, 'brick': brick['path'] if brick else None})
            elif role == 'platform' and any(c.startswith(tuple(how['features'])) for c in classes):
                features.append({'path': child, 'row': y, 'local': [round(local[0], 3), round(local[1], 3)],
                                 'class': next(c for c in classes if c.startswith(tuple(how['features'])))})
            else:
                dynamic[child] = {'role': role, 'render_bounds': _union([n.get('render_bounds') for n in tree]),
                                  'class': next((c for c in classes if c and not c.startswith('flash.')), None)}
                robot = next((c for c in classes if c.startswith('_r') and c[2:].split('_')[0].isdigit()), None)
                if role == 'robot' and robot:
                    robots.append(int(robot[2:].split('_')[0]))
    # The cell grid: rows from the row Sprites, columns from the outer ring's left column.
    grid = 30
    # (Golden matrices carry 4 decimals, so local positions agree to about 0.01.)
    origin_x = [b['local'][0] - grid * round((b['local'][0] - min(c['local'][0] for c in boxes)) / grid) for b in boxes]
    origin_y = [b['local'][1] - grid * b['row'] for b in boxes]
    if max(origin_x) - min(origin_x) > 0.05 or max(origin_y) - min(origin_y) > 0.05:
        raise SystemExit(f'{name}: boxes do not sit on one grid')
    excursion = [round(sum(origin_x) / len(origin_x), 1), round(sum(origin_y) / len(origin_y), 1)]
    for item in boxes + features:
        cx = (item['local'][0] - excursion[0]) / grid
        cy = (item['local'][1] - excursion[1]) / grid
        if abs(cx - round(cx)) > 0.01 or abs(cy - round(cy)) > 0.01 or round(cy) != item['row']:
            raise SystemExit(f'{name}: {item["path"]} is off the cell grid ({cx}, {cy})')
        item['cell'] = [int(round(cx)), int(round(cy))]
        del item['local'], item['row']
    # HUD: the panels that show, in seat order (GameConfig.ROBOT_UI_Y_k grows with k).
    panels = sorted((n for n in nodes if n['path'].startswith(screen_root + '/')
                     and (n.get('name') or '').startswith('robotUI') and n.get('effective_visible')),
                    key=lambda n: n['stage_matrix'][5])
    seats = [int(n['name'][len('robotUI'):]) for n in panels]
    if sorted(seats) != sorted(robots):
        raise SystemExit(f'{name}: HUD panels {seats} do not match the robots on the board {robots}')
    begin = how['begin_num']
    template = _match_template(name, boxes, features, begin)
    groups = [container] + [p for p in kids if _segment_index(p) < how['first_row'] and not subtree(p)[1:]]
    groups += rows + list(layers)
    keep = [n for n in nodes if not any(n['path'].startswith(layer + '/') for layer in layers)]
    board = {
        'container': container, 'container_matrix': cm, 'grid': grid, 'excursion': excursion,
        'size': [17, len(rows)], 'rows': rows,
        'layers': {role: [p for p, (y, r) in sorted(layers.items(), key=lambda kv: kv[1][0]) if r == role]
                   for role in how['layers']},
        'begin_num': begin, 'template': template,
        'boxes': [{k: b[k] for k in ('cell', 'path', 'frame', 'shown', 'exist', 'brick')} for b in boxes],
        'features': [{k: f[k] for k in ('cell', 'path', 'class')} for f in features],
        'dynamic': dynamic, 'robots': seats,
        'robot_ui_slots': [n['stage_matrix'][4:6] for n in panels],
        'round_start_after_input': _frames_after_input(case, capture),
        'groups': groups,
    }
    return keep, board


def _frames_after_input(case, capture):
    """Frames the case steps between its last input and the capture."""
    actions = json.loads((ROOT / 'tools' / 'compare' / 'cases' / f'{case}.json').read_text(encoding='utf-8'))['actions']
    frames = 0
    for action in actions:
        if action.get('capture') == capture:
            return frames
        words = action.get('command', '').split()
        if words and words[0] == 'step':
            frames += int(words[1])
        elif words or 'fixture' in action:
            frames = 0
    raise SystemExit(f'{case}: no capture {capture}')


def _match_template(name, boxes, features, begin):
    """The layout (assets/maps/layouts.json) whose fixed cells, centre, hold cells and portals
    are exactly where the recorded round has its fixed boxes and portals."""
    layouts = json.loads((ROOT / 'assets' / 'maps' / 'layouts.json').read_text(encoding='utf-8'))['layouts']
    fixed = {tuple(b['cell']) for b in boxes if not b['exist']}
    soft = {tuple(b['cell']) for b in boxes if b['exist']}
    portals = {tuple(f['cell']) for f in features}
    found = []
    for layout_name, layout in sorted(layouts.items()):
        want_fixed, want_soft, want_portals = set(), set(), set()
        for y, row in enumerate(layout['rows']):
            for x, cell in enumerate(row):
                if cell.startswith('fixedProp') or cell in ('centerProp', 'holdProp'):
                    want_fixed.add((x, y))
                elif cell == 'unfixedProp_r':
                    want_soft.add((x, y))
                elif cell.startswith('portal_'):
                    want_portals.add((x, y))
        if fixed == want_fixed and soft <= want_soft and portals == want_portals:
            found.append(layout_name)
    if len(found) != 1:
        raise SystemExit(f'{name}: the recorded board matches {len(found)} layouts ({found})')
    return found[0]


def _add_absent_at_capture(nodes, by_path, expanded, screen_root, tl, key):
    """Children of a split group that its timeline shows at some frame but that are off the
    display list at the capture, so the golden has no node for them. Each becomes a node
    from its track (its first shown state), in painter's order among its siblings by depth;
    it plays as a sequence whose art is rendered while it shows."""
    by_key = {key(p): p for p in by_path}
    for group in sorted(expanded):
        if group != screen_root and not group.startswith(screen_root + '/'):
            continue
        own = tl(group)
        if own is None or group not in by_path:
            continue
        for child in own.children(key(group)):
            if child in by_key:
                continue
            shown = [(i, st) for i, st in own.tracks[child] if st is not None and st[6]]
            if not shown:
                continue  # never on screen (robotStage2's robots)
            if own.state(child, own.data['capture_index']) is not None:
                # The golden has no such node at the capture, but the track says it is
                # there: a part timeline recorded before removals were marked (record_screen.py
                # extra timelines) keeps a removed node's last state. Re-record it to add them.
                print(f'  note: {child} is absent at the capture but its track does not say so; '
                      're-record that timeline to play it')
                continue
            segment = child.rsplit('/', 1)[1]
            try:
                depth = int(segment.rsplit('@', 1)[1])
            except (IndexError, ValueError):
                print(f'  warning: {child} is absent at the capture and has no depth; left out')
                continue
            first = shown[0][1]
            parent = by_path[group]
            node = {'path': group + '/' + segment, 'kind': 'movie_clip' if first[7] else 'graphic', 'depth': depth,
                    'character_id': first[8], 'effective_visible': False, 'alpha': first[9] if len(first) > 9 else 1.0,
                    'stage_matrix': list(first[:6]), 'absent_at_capture': True}
            if first[7]:
                node['frame'] = first[7]
            if child != node['path']:
                node['golden_path'] = child
            if parent.get('from_capture'):
                node.update(from_capture=parent['from_capture'], parent_frame_there=parent.get('frame'))
            # After the last sibling (and its subtree) drawn below it.
            at = nodes.index(parent) + 1
            for k in range(at, len(nodes)):
                q = nodes[k]['path']
                if not q.startswith(group + '/'):
                    break
                if parent_of(q) == group and nodes[k].get('depth', 0) > depth:
                    break
                at = k + 1
            nodes.insert(at, node)
            by_path[node['path']] = node
            by_key[child] = node['path']


def _art_index(own, path, screen_root, by_path, tl, key):
    """Where a still piece is rendered, when not at the capture: pieces render with their
    ancestors' alpha and filters, so one whose group is faded out or blurred at the capture
    (robot 5's head, mid entrance) would render empty or smeared. It renders at the first
    frame from the capture on where the alpha along its chain (on its own timeline) is
    highest and the chain's filters are as they settle (at the last recorded frame); None
    if that is the capture."""
    chain, q = [], path
    while q.startswith(screen_root + '/') and q in by_path:
        if tl(q) is own:
            chain.append(key(q))
        q = parent_of(q)

    def filters(i):
        return [(own.state(k, i) or [])[11:12] for k in chain]

    settled = filters(own.frames - 1)

    def look(i):
        out = 1.0
        for k in chain:
            st = own.state(k, i)
            if st is None or not st[6]:
                return (-1.0, False)
            out *= st[9] if len(st) > 9 else 1.0
        return (round(out, 4), filters(i) == settled)

    capture = own.data['capture_index']
    best = max(range(capture, own.frames), key=lambda i: (look(i), -i))
    return best if look(best) > look(capture) else None


def _capture_phases(spec, case, timeline, screen_root):
    """For a screen the comparison opens itself (`capture_phase` in the spec: the score
    screen, which Godot cannot reach by playing a round), the timeline index at which each
    of the case's captures of it was taken: the index whose recorded clip frames,
    visibility and positions agree best with that capture's golden. A wall-time screen
    (the original's tweens run on the clock) opens at a slightly different frame in every
    recording, so the index is read from the golden itself rather than from the run."""
    captures = spec.get('capture_phase')
    if not captures:
        return None
    phases = {}
    for capture in captures:
        index, off, moving = _best_index(timeline, _golden_under(case, capture, screen_root))
        phases[capture] = index
        if off:
            print(f'  note: {capture} matches timeline index {index} but for {off}/{moving} moving nodes')
    return phases


def _golden_under(case, capture, prefix):
    return {n['path']: n for n in json.loads((GOLDENS / case / f'{capture}.json').read_text(encoding='utf-8'))['nodes']
            if n['path'].startswith(prefix)}


def _best_index(timeline, golden):
    """The timeline index whose moving nodes agree best with a golden: (index, nodes off, moving)."""
    moving = [p for p in timeline.tracks if timeline.changes(p) and p in golden]
    best = (0, len(moving))
    for i in range(timeline.frames):
        off = 0
        for p in moving:
            state, ref = timeline.state(p, i), golden[p]
            m = ref.get('stage_matrix') or [1, 0, 0, 1, 0, 0]
            if (not state or bool(state[6]) != bool(ref.get('effective_visible')) or (state[7] or 0) != (ref.get('frame') or 0)
                    or abs(state[4] - m[4]) > 0.5 or abs(state[5] - m[5]) > 0.5):
                off += 1
        if off < best[1]:
            best = (i, off)
    return best[0], best[1], len(moving)


def _extra_shown_before(spec, case, extra_timelines, phases):
    """A part from another capture plays on its own timeline, from that capture's run
    (`from_shown`: index 0 is the frame it shows; older recordings start at the capture).
    With capture phases, the part's run is matched to the golden too (its index L at the
    capture); the part shows with the screen (the unlock tip and the failed title are made
    in the score screen's initData), so its timeline runs `shown_offset` = L - phase frames
    ahead of the frames it has shown in Godot."""
    out = {}
    for c, x in extra_timelines.items():
        if x is None:
            continue
        entry = {k: x.data[k] for k in ('period', 'shown_before_capture')}
        if x.data.get('from_shown'):
            entry.update(from_shown=True, capture_index=x.data['capture_index'])
        if phases and c in phases:
            tops = tuple(x.data.get('tops', ()))
            golden = {p: n for p, n in _golden_under(case, c, '/').items() if p.startswith(tops)}
            local, off, moving = _best_index(x, golden)
            if not moving:
                pass  # a part that does not change has no phase to match
            elif x.data.get('from_shown'):
                entry['shown_offset'] = local - phases[c]
            else:
                entry['shown_before_capture'] = phases[c] - local
            if off:
                print(f'  note: the {c} part matches its timeline at {local} but for {off}/{moving} moving nodes')
        out[c] = entry
    return out


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
