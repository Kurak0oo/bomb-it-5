"""Python mirror of scripts/art/catalog.gd: the 89 named slots the workbench edits."""
import re

from common import ROOT

CATALOG_GD = ROOT / 'scripts' / 'art' / 'catalog.gd'
ACTORS = ['human', 'ruby', 'mint', 'gold']
DIRECTIONS = ['Down', 'Right', 'Up', 'Left']  # Workbench row order for four-row sheets.


def entries():
    result = []

    def add(ident, category, size):
        result.append({'id': ident, 'category': category, 'size': size})

    for item in ['floor_even', 'floor_odd', 'wall', 'seat', 'spotlight', 'clapper', 'popcorn', 'portal_green',
                 'portal_purple', 'marquee']:
        add('board.' + item, 'Board', (108, 108) if item == 'marquee' else (36, 36))
    for actor in ACTORS:
        for pose in ['idle', 'walk', 'action', 'portrait', 'death']:
            add(f'actor.{actor}.{pose}', 'Characters',
                (38, 38) if pose == 'portrait' else (40, 40) if pose == 'death' else (40, 44))
    for item in ['capacity', 'power', 'speed', 'life', 'shield', 'invincible', 'car', 'moto', 'landmine', 'hammer',
                 'flamer', 'laser', 'triple', 'shotgun']:
        add('item.' + item, 'Pickups', (28, 28))
    for kind in ['landmine', 'hammer', 'flamer', 'laser', 'triple', 'shotgun']:
        add('held.' + kind, 'Weapons', (24, 24))
    for kind in ['hammer', 'flamer', 'laser', 'triple', 'shotgun']:
        add('attack.' + kind, 'Weapons', (48, 48))
    for kind in ['triple', 'shotgun']:
        add('projectile.' + kind, 'Weapons', (28, 24))
    for item in ['bomb', 'mine', 'flame', 'shield', 'invincible', 'invincible_intro', 'blink', 'transit', 'car', 'moto',
                 'car_recovery', 'moto_recovery']:
        size = ((36, 36) if item in ('bomb', 'mine', 'flame') else (48, 48) if item.startswith('invincible')
                else (44, 35) if item in ('car', 'moto', 'car_recovery', 'moto_recovery') else (44, 44))
        add('effect.' + item, 'Effects', size)
    for item, side in [('stick_base', 168), ('stick_thumb', 54), ('action_normal', 128), ('action_pressed', 128),
                       ('action_disabled', 128)]:
        add('control.' + item, 'Controls', (side, side))
    for item, size in [('background', (1280, 720)), ('frame', (1260, 700)), ('board_frame', (626, 554)),
                       ('roster', (251, 76)), ('timer', (141, 42)), ('results', (444, 228)),
                       ('button_normal', (210, 40)), ('button_hover', (210, 40)), ('button_pressed', (210, 40)),
                       ('button_disabled', (210, 40))]:
        add('ui.' + item, 'Interface', size)
    for outcome in ['won', 'lost', 'timeout', 'game_over', 'paused']:
        add('outcome.' + outcome, 'Outcomes', (64, 64))
    return result


def check_against_catalog():
    """Fail loudly if catalog.gd gained, lost or resized a slot this mirror does not know."""
    text = CATALOG_GD.read_text(encoding='utf-8').split('static func find')[0]
    problems = []
    listed = entries()
    if len(listed) != 89:
        problems.append(f'mirror has {len(listed)} slots, expected 89')
    for entry in listed:
        suffix = entry['id'].split('.')[-1]
        if f'"{suffix}"' not in text:
            problems.append(f'{entry["id"]} not found in catalog.gd')
    for number in re.findall(r'Vector2\((\d+), (\d+)\)', text):
        if not any(tuple(map(int, number)) == e['size'] for e in listed):
            problems.append(f'catalog.gd size {number} unknown to the mirror')
    return problems


def find(slot):
    return next((e for e in entries() if e['id'] == slot), None)
