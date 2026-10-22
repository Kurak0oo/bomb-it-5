"""Render a blocky redesign beside the original and export workbench sprite sheets.

    python tools/art_pipeline/blocky_sheet.py [--robot 0]

Reads tools/art_pipeline/blocky_specs/r<N>.json. Writes the ignored
candidates/blocky/r<N>/ folder: sheet.png (review), walk.png / idle.png / death.png
(workbench sheets for the actor slots) and SVG frames. Nothing is applied to the game.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np
from PIL import Image

import blocky
import render
from character_sheet import DIRECTIONS, MUTED, RULE, Sheet, find, font, palette
from common import CANDIDATES, rgb_to_hex, save_png, write_text

SLOT_CELL = (40, 44)  # actor idle/walk slot size in the catalogue


def draw(spec, polys, box, zoom):
    return render.render_box(blocky.svg(spec, polys, box), box, zoom)


def strip(sheet, spec, frames, box, area, captions):
    x, y, w, h = area
    cell = w / len(frames)
    zoom = min((cell - 10) / box[2], (h - 30) / box[3])
    for i, polys in enumerate(frames):
        image = draw(spec, polys, box, zoom)
        sheet.paste(image, x + i * cell + (cell - image.shape[1]) / 2, y)
        tw = sheet.pen.textlength(captions[i], font=font(15))
        sheet.label((x + i * cell + (cell - tw) / 2, y + box[3] * zoom + 6), captions[i], 15, fill=MUTED)
    sheet.ground(x, y + box[3] * zoom, w)


def export(spec, robot, folder, scale=4):
    """Workbench sheets: walk 8 across x 4 rows (Down, Right, Up, Left), idle 1 x 4, death strip."""
    sets = blocky.frames(spec)
    box = blocky.union([blocky.bounds(p) for name, frames in sets.items() for p in frames])
    # Fit the shared box into the slot cell keeping aspect; every frame uses the same zoom.
    cell = (SLOT_CELL[0] * scale, SLOT_CELL[1] * scale)
    zoom = min(cell[0] / box[2], cell[1] / box[3])

    def sheet_of(rows):
        canvas = np.zeros((len(rows) * cell[1], max(len(r) for r in rows) * cell[0], 4), np.uint8)
        for r, row in enumerate(rows):
            for c, polys in enumerate(row):
                image = draw(spec, polys, box, zoom)
                h, w = image.shape[:2]
                y, x = r * cell[1] + (cell[1] - h), c * cell[0] + (cell[0] - w) // 2  # Feet on the cell floor.
                canvas[max(0, y):y + h, x:x + w] = image[max(0, -y):, :]
        return canvas

    walk = [sets[f'walk_{d}'] for d, _ in DIRECTIONS]
    save_png(folder / 'walk.png', sheet_of(walk))
    save_png(folder / 'idle.png', sheet_of([sets[f'idle_{d}'] for d, _ in DIRECTIONS]))
    save_png(folder / 'death.png', sheet_of([sets['defeat']]))
    for d, _ in DIRECTIONS:
        for i, polys in enumerate(sets[f'walk_{d}'], 1):
            write_text(folder / 'frames' / f'walk_{d}_{i}.svg', blocky.svg(spec, polys, box))
    return {'walk': f'{len(walk[0])} across x 4 rows (Down, Right, Up, Left)', 'idle': '1 across x 4 rows',
            'death': f'{len(sets["defeat"])} across x 1 row', 'cell': f'{cell[0]}x{cell[1]} ({scale}x the slot)'}


def build(robot):
    spec = blocky.load(robot)
    folder = CANDIDATES / 'blocky' / f'r{robot}'
    prefix = f'_r{robot}'
    sets = blocky.frames(spec)
    parts = blocky.boxes(spec)
    sheet = Sheet(2600, 2420)
    sheet.label((48, 34), f'ROBOT {prefix}  ·  BLOCKY REDESIGN', 40, True)
    sheet.label((50, 88), 'Deterministic box model (blocky_specs/r%d.json) rendered as flat vectors: one model for every '
                          'pose, so proportions and colours never drift. Candidate art for review only.' % robot,
                19, fill=MUTED)
    # Original for comparison.
    area = sheet.panel(40, 130, 560, 900, 'Original', 'select art and front idle')
    special = find(rf'robot{robot + 1}_+special_\d+_', pinned=False)
    front = find(rf'_{re.escape(prefix)}_Down_')
    if special:
        box = special.box([1])
        zoom = min(area[2] / (box[2] - box[0]), 520 / (box[3] - box[1]))
        image = special.draw(1, box, zoom)
        sheet.paste(image, area[0] + (area[2] - image.shape[1]) / 2, area[1])
    if front:
        box = front.box([1])
        zoom = 260 / (box[3] - box[1])
        image = front.draw(1, box, zoom)
        sheet.paste(image, area[0] + (area[2] - image.shape[1]) / 2, area[1] + 560)
    # Blocky hero, three-quarter view.
    area = sheet.panel(620, 130, 700, 900, 'Blocky', 'three-quarter view')
    hero = blocky.polygons(spec, parts, -30, 18)
    box = blocky.bounds(hero)
    zoom = min(area[2] / box[2], (area[3] - 10) / box[3])
    hero_image = draw(spec, hero, box, zoom)
    sheet.paste(hero_image, area[0] + (area[2] - hero_image.shape[1]) / 2, area[1])
    # Turnaround.
    area = sheet.panel(1340, 130, 1220, 900, 'Turnaround', 'idle, game camera')
    idles = [sets[f'idle_{d}'][0] for d, _ in DIRECTIONS]
    box = blocky.union([blocky.bounds(p) for p in idles])
    strip(sheet, spec, idles, box, area, [caption for _, caption in DIRECTIONS])
    # Walk cycles.
    walk_box = blocky.union([blocky.bounds(p) for d, _ in DIRECTIONS for p in sets[f'walk_{d}']])
    count = len(sets['walk_Down'])
    area = sheet.panel(40, 1050, 1250, 380, 'Walk cycle', f'front, {count} frames')
    strip(sheet, spec, sets['walk_Down'], walk_box, area, [str(i + 1) for i in range(count)])
    area = sheet.panel(1310, 1050, 1250, 380, 'Walk cycle', f'right, {count} frames')
    strip(sheet, spec, sets['walk_Right'], walk_box, area, [str(i + 1) for i in range(count)])
    # Wardrobe.
    looks = [(None, None, 'default')] + [(name, None, name.replace('_', ' ')) for name in spec.get('outfits', {})]
    looks += [(None, name, name.replace('_', ' ')) for name in spec.get('hats', {})]
    area = sheet.panel(40, 1450, 2520, 420, 'Wardrobe', 'outfits and hats as blocks, three-quarter view')
    dressed = [blocky.polygons(spec, blocky.boxes(spec, o, h), -30, 18) for o, h, _ in looks]
    strip(sheet, spec, dressed, blocky.union([blocky.bounds(p) for p in dressed]), area, [c for *_, c in looks])
    # Defeat.
    area = sheet.panel(40, 1890, 1500, 480, 'Defeat', 'charred, then the blocks scatter')
    strip(sheet, spec, sets['defeat'], blocky.union([blocky.bounds(p) for p in sets['defeat']]), area,
          [str(i + 1) for i in range(len(sets['defeat']))])
    # Colours and in-game size.
    area = sheet.panel(1560, 1890, 1000, 480, 'Colours and scale', 'spec colours; in-game 1x versus the original')
    colours = palette([hero_image])
    for i, colour in enumerate(colours[:12]):
        cx, cy = area[0] + (i % 6) * 78, area[1] + (i // 6) * 110
        sheet.pen.rounded_rectangle((cx, cy, cx + 66, cy + 66), 8, fill=colour + (255,), outline=RULE)
        sheet.label((cx, cy + 70), rgb_to_hex(colour), 13, fill=MUTED)
    info = export(spec, robot, folder)
    small = np.array(Image.open(folder / 'idle.png').convert('RGBA'))
    one = small[:SLOT_CELL[1] * 4, :SLOT_CELL[0] * 4]
    gx, gy = area[0] + 500, area[1]
    sheet.label((gx, gy), 'In game, 1x (40x44 slot)', 15, fill=MUTED)
    sheet.paste(np.array(Image.fromarray(one).resize(SLOT_CELL, Image.LANCZOS)), gx, gy + 30)
    if front:
        box = front.box([1])
        orig = front.draw(1, box, min(SLOT_CELL[0] / (box[2] - box[0]), SLOT_CELL[1] / (box[3] - box[1])))
        sheet.paste(orig, gx + 70, gy + 30 + SLOT_CELL[1] - orig.shape[0])
    sheet.label((gx, gy + 84), 'blocky   original', 13, fill=MUTED)
    sheet.paste(np.array(Image.fromarray(one).resize((SLOT_CELL[0] * 3, SLOT_CELL[1] * 3), Image.LANCZOS)), gx, gy + 120)
    sheet.label((gx + 140, gy + 230), '3x', 14, fill=MUTED)
    save_png(folder / 'sheet.png', np.array(sheet.image))
    return folder, info


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--robot', type=int, default=0)
    args = parser.parse_args()
    folder, info = build(args.robot)
    print(folder)
    for name, layout in info.items():
        print(f'  {name}: {layout}')


if __name__ == '__main__':
    main()
