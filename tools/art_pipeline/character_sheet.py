"""Compose one robot's SWF art into an all-in-one character model sheet.

    python tools/art_pipeline/character_sheet.py [--robot 0] [--out FOLDER]

Writes sheet.png (model sheet) and wardrobe.png (every outfit and hat, worn).

Needs a completed run.py export (.scratch/swf-export). Writes to the ignored
candidates/character_sheets/ folder; the sheet is review material, not game art.
"""
import argparse
import glob
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import clips
import render
from common import CANDIDATES, EXPORT, rgb_to_hex, rgb_to_lab, save_png

DIRECTIONS = [('Down', 'Front'), ('Right', 'Right'), ('Up', 'Back'), ('Left', 'Left')]
RIDES = [('Car', 'Car'), ('Skateboard', 'Moto (skateboard)'), ('Elephant', 'Elephant'), ('forg', 'Frog')]
PAPER, INK, MUTED, RULE = (246, 244, 239, 255), (34, 38, 43), (110, 116, 122), (214, 210, 202)
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'


def font(size, bold=False):
    try:
        return ImageFont.truetype(BOLD if bold else FONT, size)
    except OSError:
        return ImageFont.load_default()


class Sprite:
    def __init__(self, folder, pinned=True):
        self.folder, self.pinned = folder, pinned
        self.frames = sorted(glob.glob(os.path.join(folder, '*.svg')), key=lambda p: int(os.path.basename(p)[:-4]))
        text = open(self.frames[0], encoding='utf-8').read()
        size = re.search(r'height="([\d.]+)px" width="([\d.]+)px"', text)
        self.size = (float(size.group(2)), float(size.group(1)))

    def raw(self, number):
        return open(self.frames[number - 1], encoding='utf-8').read()

    def text(self, number, pins=None):
        return clips.pin(self.raw(number), pins) if self.pinned else self.raw(number)

    def box(self, numbers, pins=None):
        boxes = [b for b in (render.content_box(self.text(n, pins), self.size) for n in numbers) if b]
        return (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))

    def draw(self, number, box, zoom, pins=None):
        return render.render_box(self.text(number, pins), (box[0], box[1], box[2] - box[0], box[3] - box[1]), zoom)


def find(name_pattern, pinned=True):
    matches = [d for d in glob.glob(str(EXPORT / 'sprites' / 'DefineSprite_*')) if re.search(name_pattern, os.path.basename(d))]
    return Sprite(sorted(matches, key=len)[0], pinned) if matches else None


def keyframes(count, wanted):
    return sorted({round(v) for v in np.linspace(1, count, min(wanted, count))})


def variant_row(sheet, sprite, variants, area):
    """One pose drawn once per (pins, caption) variant, on a shared baseline and scale."""
    x, y, w, h = area
    boxes = [sprite.box([1], pins) for pins, _ in variants]
    box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
    bw, bh = box[2] - box[0], box[3] - box[1]
    cell = w / len(variants)
    zoom = min((cell - 16) / bw, (h - 30) / bh)
    for i, (pins, caption) in enumerate(variants):
        image = sprite.draw(1, box, zoom, pins)
        sheet.paste(image, x + i * cell + (cell - image.shape[1]) / 2, y)
        tw = sheet.pen.textlength(caption, font=font(16))
        sheet.label((x + i * cell + (cell - tw) / 2, y + bh * zoom + 6), caption, 16, fill=MUTED)
    sheet.ground(x, y + bh * zoom, w)


def head_box(sprite, number):
    """Top of the solid figure; glows and shadows (semi-transparent) are ignored."""
    box = sprite.box([number])
    zoom = 256 / max(box[2] - box[0], box[3] - box[1])
    rows, columns = np.nonzero(sprite.draw(number, box, zoom)[..., 3] > 200)
    if rows.size == 0:
        raise ValueError('no solid pixels')
    x0, x1 = box[0] + columns.min() / zoom, box[0] + (columns.max() + 1) / zoom
    y0, y1 = box[1] + rows.min() / zoom, box[1] + (rows.max() + 1) / zoom
    return (x0, y0, x1, y0 + (y1 - y0) * 0.6)


def expressions(sources, limit=8, threshold=0.08):
    """Distinct faces: compare the eye band of each head crop so hats and outfits do not count."""
    chosen = []
    for sprite, number, label in sources:
        try:
            box = head_box(sprite, number)
        except ValueError:
            continue
        band = (box[0], box[1] + (box[3] - box[1]) * 0.45, box[2], box[1] + (box[3] - box[1]) * 0.9)
        zoom = 48 / max(band[2] - band[0], 1e-6)
        thumb = np.array(Image.fromarray(sprite.draw(number, band, zoom)).convert('RGBA').resize((48, 24)),
                         dtype=np.float64) / 255
        if all(np.abs(thumb - other).mean() > threshold for *_, other in chosen):
            chosen.append((sprite, number, label, box, thumb))
        if len(chosen) == limit:
            break
    return [(sprite, number, label, box) for sprite, number, label, box, _ in chosen]


def same_drawing(sprite, a, b):
    box = sprite.box([a, b])
    zoom = 64 / max(box[2] - box[0], box[3] - box[1])
    return np.abs(sprite.draw(a, box, zoom).astype(float) - sprite.draw(b, box, zoom)).mean() < 2


def key_frame(sprite):
    """The select-illustration frame with the most solid area (skips entrance effects)."""
    numbers = range(1, len(sprite.frames) + 1)
    box = sprite.box(list(numbers)[::max(1, len(sprite.frames) // 12)])
    zoom = 96 / max(box[2] - box[0], box[3] - box[1])
    solid = {n: int((sprite.draw(n, box, zoom)[..., 3] > 230).sum()) for n in numbers}
    best = max(numbers, key=lambda n: (solid[n], -n))
    return 1 if solid[1] >= 0.25 * solid[best] else best  # Frame 1 is the default outfit unless empty.


def palette(images, count=14):
    pixels = np.concatenate([i.reshape(-1, 4) for i in images])
    opaque = pixels[pixels[:, 3] > 200][:, :3]
    strip = Image.fromarray(opaque.reshape(1, -1, 3).astype(np.uint8), 'RGB').quantize(count, Image.Quantize.MEDIANCUT)
    counts = np.bincount(np.array(strip).ravel(), minlength=count)
    values = strip.getpalette()[:count * 3]
    colours = [(counts[i], tuple(values[i * 3:i * 3 + 3])) for i in range(count) if counts[i]]
    colours.sort(key=lambda c: -c[0])
    # Order by lightness so the swatch strip reads as a ramp.
    return sorted([c for _, c in colours], key=lambda c: -rgb_to_lab(c)[0])


class Sheet:
    def __init__(self, width, height):
        self.image = Image.new('RGBA', (width, height), PAPER)
        self.pen = ImageDraw.Draw(self.image)

    def label(self, xy, text, size=22, bold=False, fill=INK):
        self.pen.text(xy, text, font=font(size, bold), fill=fill)

    def panel(self, x, y, w, h, title, note=''):
        self.pen.rounded_rectangle((x, y, x + w, y + h), 14, outline=RULE, width=2, fill=(252, 251, 248, 255))
        self.label((x + 18, y + 12), title, 24, True)
        if note:
            self.label((x + 20 + self.pen.textlength(title, font=font(24, True)) + 14, y + 17), note, 17, fill=MUTED)
        return x + 18, y + 52, w - 36, h - 70

    def paste(self, pixels, x, y):
        self.image.alpha_composite(Image.fromarray(pixels), (int(x), int(y)))

    def ground(self, x, y, w):
        self.pen.line((x, y, x + w, y), fill=RULE, width=2)


def row_of(sheet, sprite, numbers, area, captions=None, zoom=None, box=None):
    """Lay frames left to right on a shared baseline and scale; returns the zoom used."""
    x, y, w, h = area
    box = box or sprite.box(numbers)
    bw, bh = box[2] - box[0], box[3] - box[1]
    gap = 14
    zoom = zoom or min((w - gap * (len(numbers) - 1)) / (bw * len(numbers)), (h - (28 if captions else 0)) / bh)
    cell = bw * zoom + gap
    start = x + (w - cell * len(numbers) + gap) / 2
    for i, number in enumerate(numbers):
        sheet.paste(sprite.draw(number, box, zoom), start + i * cell, y)
        if captions:
            text = captions[i]
            tw = sheet.pen.textlength(text, font=font(16))
            sheet.label((start + i * cell + (bw * zoom - tw) / 2, y + bh * zoom + 6), text, 16, fill=MUTED)
    sheet.ground(x, y + bh * zoom, w)
    return zoom


def build(robot, out):
    prefix = f'_r{robot}'
    walk = {d: find(rf'_{re.escape(prefix)}_{d}_') for d, _ in DIRECTIONS}
    missing = [d for d, s in walk.items() if s is None]
    if missing:
        raise SystemExit(f'No {prefix} sprites for {missing}; run run.py first')
    dead = find(rf'_{re.escape(prefix)}_Dead_')
    # The select illustration cycles outfits on purpose; leave it unpinned.
    special = find(rf'robot{robot + 1}_+special_\d+_', pinned=False)
    head = find(r'roleHead_\d+_')
    sheet = Sheet(2600, 2740)
    sheet.label((48, 34), f'ROBOT {prefix}  ·  CHARACTER MODEL SHEET', 40, True)
    sheet.label((50, 88), 'Edition 5 SWF source art, rendered from vectors. Poses wear the default outfit and hat '
                          '(bodyMc/hatMc frame 1, as RobotView.as sets them). Reference for redesign; not approved '
                          'game art.', 19, fill=MUTED)
    # Key art.
    area = sheet.panel(40, 130, 820, 1010, 'Key art', 'character-select illustration')
    hero_images = []
    if special:
        key = key_frame(special)
        sheet.label((area[0] + area[2] - 90, area[1] - 34), f'frame {key}', 16, fill=MUTED)
        box = special.box([key])
        zoom = min(area[2] / (box[2] - box[0]), (area[3] - 10) / (box[3] - box[1]))
        hero = special.draw(key, box, zoom)
        hero_images.append(hero)
        sheet.paste(hero, area[0] + (area[2] - hero.shape[1]) / 2, area[1])
    # Turnaround: each facing is its own sprite; frames stand on a shared baseline.
    area = sheet.panel(880, 130, 1680, 560, 'Turnaround', 'idle, frame 1 of each facing')
    boxes = {d: walk[d].box([1]) for d, _ in DIRECTIONS}
    tallest = max(b[3] - b[1] for b in boxes.values())
    widest = max(b[2] - b[0] for b in boxes.values())
    zoom = min((area[3] - 40) / tallest, (area[2] - 60) / (4 * widest))
    cell = area[2] / 4
    turnaround = []
    for i, (d, caption) in enumerate(DIRECTIONS):
        image = walk[d].draw(1, boxes[d], zoom)
        turnaround.append(image)
        bottom = area[1] + tallest * zoom
        sheet.paste(image, area[0] + i * cell + (cell - image.shape[1]) / 2, bottom - image.shape[0])
        tw = sheet.pen.textlength(caption, font=font(20, True))
        sheet.label((area[0] + i * cell + (cell - tw) / 2, bottom + 10), caption, 20, True, fill=MUTED)
    sheet.ground(area[0], area[1] + tallest * zoom, area[2])
    # Portrait: roleHead frame robot + 1, unless the SWF reuses another robot's head there.
    own_head = head and robot < len(head.frames) and not any(
        same_drawing(head, robot + 1, n) for n in range(1, robot + 1))
    area = sheet.panel(880, 710, 400, 430, 'Portrait',
                       f'HUD head, frame {robot + 1}' if own_head else 'cropped from front idle')
    if own_head:
        source, number, box = head, robot + 1, head.box([robot + 1])
    else:
        source, number, box = walk['Down'], 1, head_box(walk['Down'], 1)
        sheet.label((area[0], area[1] + area[3] - 20), 'roleHead has no head for this robot', 15, fill=MUTED)
    pz = min(area[2] / (box[2] - box[0]), (area[3] - 26) / (box[3] - box[1]))
    portrait = source.draw(number, box, pz)
    sheet.paste(portrait, area[0] + (area[2] - portrait.shape[1]) / 2, area[1])
    # Expressions: the SWF has no expression clips; faces change inside the animations.
    area = sheet.panel(1300, 710, 1260, 430, 'In-game faces', 'the SWF has no expression clips; distinct faces '
                                                                'of the front walk, then defeat')
    faces = expressions([(walk['Down'], n, f'walk {n}') for n in range(1, len(walk['Down'].frames) + 1)], limit=5, threshold=0.025)
    if dead:
        faces += [(dead, 1, 'defeat', head_box(dead, 1))]
    if faces:
        cell = area[2] / len(faces)
        for i, (sprite, number, label, box) in enumerate(faces):
            fz = min((cell - 12) / (box[2] - box[0]), (area[3] - 30) / (box[3] - box[1]))
            image = sprite.draw(number, box, fz)
            sheet.paste(image, area[0] + i * cell + (cell - image.shape[1]) / 2, area[1])
            tw = sheet.pen.textlength(label, font=font(15))
            sheet.label((area[0] + i * cell + (cell - tw) / 2, area[1] + area[3] - 22), label, 15, fill=MUTED)
    # Wardrobe: every outfit (bodyMc) and hat/accessory (hatMc) frame.
    outfits = clips.frame_count(walk['Down'].raw(1), 'bodyMc')
    area = sheet.panel(40, 1160, 2520, 400, 'Outfits', f'all {outfits} bodyMc frames on the front idle pose, '
                                                       'default hat; frame 1 is the default')
    if outfits:
        variant_row(sheet, walk['Down'], [({'bodyMc': n, 'hatMc': 1}, 'default' if n == 1 else f'outfit {n - 1}')
                                          for n in range(1, outfits + 1)], area)
    facing = next(((d, c) for d, c in DIRECTIONS if clips.frame_count(walk[d].raw(1), 'hatMc')), None)
    hats = clips.frame_count(walk[facing[0]].raw(1), 'hatMc') if facing else 0
    note = (f'all {hats} hatMc frames on the {facing[1].lower()} idle pose, default outfit' if facing
            else 'no hatMc clip in any facing')
    if facing and facing[0] != 'Down':
        note += '; the front sprite has no hat clip'
    area = sheet.panel(40, 1580, 2520, 400, 'Hats and accessories', note)
    if hats:
        variant_row(sheet, walk[facing[0]], [({'bodyMc': 1, 'hatMc': n}, 'default' if n == 1 else f'hat {n - 1}')
                                             for n in range(1, hats + 1)], area)
    # Walk cycle.
    area = sheet.panel(40, 2000, 1250, 330, 'Walk cycle', f'front, 8 of {len(walk["Down"].frames)} frames')
    frames = keyframes(len(walk['Down'].frames), 8)
    row_of(sheet, walk['Down'], frames, area, [f'{n}' for n in frames])
    # Death.
    area = sheet.panel(1310, 2000, 1250, 330, 'Defeat', f'8 of {len(dead.frames) if dead else 0} frames')
    if dead:
        frames = keyframes(len(dead.frames), 8)
        row_of(sheet, dead, frames, area, [f'{n}' for n in frames])
    # Rides.
    area = sheet.panel(40, 2350, 1500, 350, 'Rides', 'front, frame 1')
    cell = area[2] / len(RIDES)
    rides = [(find(rf'_{re.escape(prefix)}_{key}_Down_'), caption) for key, caption in RIDES]
    ride_boxes = [(s, s.box([1]), c) for s, c in rides if s]
    tallest = max(b[3] - b[1] for _, b, _ in ride_boxes)
    rz = min((area[3] - 40) / tallest, (cell - 30) / max(b[2] - b[0] for _, b, _ in ride_boxes))
    for i, (sprite, box, caption) in enumerate(ride_boxes):
        image = sprite.draw(1, box, rz)
        bottom = area[1] + tallest * rz
        sheet.paste(image, area[0] + i * cell + (cell - image.shape[1]) / 2, bottom - image.shape[0])
        tw = sheet.pen.textlength(caption, font=font(18))
        sheet.label((area[0] + i * cell + (cell - tw) / 2, bottom + 8), caption, 18, fill=MUTED)
    sheet.ground(area[0], area[1] + tallest * rz, area[2])
    # Palette and scale.
    area = sheet.panel(1560, 2350, 1000, 350, 'Colours and scale', 'area-weighted, from the turnaround')
    colours = palette(turnaround + hero_images)
    sw = min(68, (area[2] - 260) / 7)
    for i, colour in enumerate(colours[:14]):
        cx, cy = area[0] + (i % 7) * (sw + 10), area[1] + (i // 7) * (sw + 42)
        sheet.pen.rounded_rectangle((cx, cy, cx + sw, cy + sw), 8, fill=colour + (255,), outline=RULE)
        sheet.label((cx, cy + sw + 4), rgb_to_hex(colour), 13, fill=MUTED)
    gx = area[0] + area[2] - 220
    idle = walk['Down'].draw(1, boxes['Down'], 1.0)
    big = walk['Down'].draw(1, boxes['Down'], 3.0)
    sheet.label((gx, area[1]), 'In game (1x, 40x44 slot)', 15, fill=MUTED)
    sheet.paste(idle, gx, area[1] + 28)
    sheet.label((gx + 70, area[1] + 28), '3x', 15, fill=MUTED)
    sheet.paste(big, gx + 95, area[1] + 28)
    save_png(out, np.array(sheet.image))
    return out


def build_wardrobe(robot, out):
    """One row per outfit and per hat, each worn in all four facings and on every ride."""
    prefix = f'_r{robot}'
    columns = [(find(rf'_{re.escape(prefix)}_{d}_'), caption) for d, caption in DIRECTIONS]
    columns += [(find(rf'_{re.escape(prefix)}_{key}_Down_'), caption.split(' ')[0]) for key, caption in RIDES]
    columns = [(sprite, caption) for sprite, caption in columns if sprite]
    front = columns[0][0]
    outfits = clips.frame_count(front.raw(1), 'bodyMc')
    hats = max(clips.frame_count(sprite.raw(1), 'hatMc') for sprite, _ in columns)
    rows = [({'bodyMc': n, 'hatMc': 1}, 'Default outfit' if n == 1 else f'Outfit {n - 1}') for n in range(1, outfits + 1)]
    rows += [({'bodyMc': 1, 'hatMc': n}, f'Hat {n - 1}') for n in range(2, hats + 1)]
    # One box per column covering every row, so all rows share a scale and baseline.
    boxes = []
    for sprite, _ in columns:
        found = [sprite.box([1], pins) for pins, _ in rows]
        boxes.append((min(b[0] for b in found), min(b[1] for b in found), max(b[2] for b in found), max(b[3] for b in found)))
    label_width, cell, gap = 230, 260, 10
    zoom = min((cell - 20) / max(b[2] - b[0] for b in boxes), (cell - 30) / max(b[3] - b[1] for b in boxes))
    width = 80 + label_width + cell * len(columns)
    sheet = Sheet(width, 210 + (cell + gap) * len(rows))
    sheet.label((48, 34), f'ROBOT {prefix}  ·  WARDROBE', 40, True)
    sheet.label((50, 88), f'{outfits} outfits (bodyMc) and {hats} hats (hatMc), each worn in every facing and ride. '
                          'Hat rows wear the default outfit. Blank hat cells: that sprite has no hat clip.', 19, fill=MUTED)
    for i, (_, caption) in enumerate(columns):
        tw = sheet.pen.textlength(caption, font=font(20, True))
        sheet.label((40 + label_width + i * cell + (cell - tw) / 2, 140), caption, 20, True, fill=MUTED)
    for r, (pins, title) in enumerate(rows):
        y = 180 + r * (cell + gap)
        sheet.pen.rounded_rectangle((40, y, width - 40, y + cell), 14, outline=RULE, width=2, fill=(252, 251, 248, 255))
        sheet.label((60, y + cell / 2 - 14), title, 24, True)
        for i, ((sprite, _), box) in enumerate(zip(columns, boxes)):
            image = sprite.draw(1, box, zoom, pins)
            x = 40 + label_width + i * cell + (cell - image.shape[1]) / 2
            sheet.paste(image, x, y + cell - 12 - image.shape[0])
    save_png(out, np.array(sheet.image))
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--robot', type=int, default=0, help='robot index 0-7 (0 is the blue human default)')
    parser.add_argument('--out', help='output folder (default candidates/character_sheets/r<N>/)')
    args = parser.parse_args()
    folder = Path(args.out) if args.out else CANDIDATES / 'character_sheets' / f'r{args.robot}'
    print(build(args.robot, folder / 'sheet.png'))
    print(build_wardrobe(args.robot, folder / 'wardrobe.png'))


if __name__ == '__main__':
    main()
