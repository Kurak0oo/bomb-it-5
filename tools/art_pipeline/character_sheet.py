"""Compose one robot's SWF art into an all-in-one character model sheet.

    python tools/art_pipeline/character_sheet.py [--robot 0] [--out PATH]

Needs a completed run.py export (.scratch/swf-export). Writes to the ignored
candidates/character_sheets/ folder; the sheet is review material, not game art.
"""
import argparse
import glob
import os
import re
import sys

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

    def text(self, number):
        text = open(self.frames[number - 1], encoding='utf-8').read()
        return clips.pin(text) if self.pinned else text

    def box(self, numbers):
        boxes = [b for b in (render.content_box(self.text(n), self.size) for n in numbers) if b]
        return (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))

    def draw(self, number, box, zoom):
        return render.render_box(self.text(number), (box[0], box[1], box[2] - box[0], box[3] - box[1]), zoom)


def find(name_pattern, pinned=True):
    matches = [d for d in glob.glob(str(EXPORT / 'sprites' / 'DefineSprite_*')) if re.search(name_pattern, os.path.basename(d))]
    return Sprite(sorted(matches, key=len)[0], pinned) if matches else None


def keyframes(count, wanted):
    return sorted({round(v) for v in np.linspace(1, count, min(wanted, count))})


def distinct_frames(sprite, limit, threshold=0.08):
    """Frames that look different from each other (outfits/poses), in timeline order."""
    box = sprite.box(range(1, len(sprite.frames) + 1, max(1, len(sprite.frames) // 12)))
    zoom = 48 / max(box[2] - box[0], box[3] - box[1])
    thumbs = [(n, sprite.draw(n, box, zoom).astype(np.float64) / 255) for n in range(1, len(sprite.frames) + 1)]
    chosen = []
    for number, thumb in thumbs:
        if all(np.abs(thumb - other).mean() > threshold for _, other in chosen):
            chosen.append((number, thumb))
    return [n for n, _ in chosen][:limit]


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
    sheet = Sheet(2600, 1900)
    sheet.label((48, 34), f'ROBOT {prefix}  ·  CHARACTER MODEL SHEET', 40, True)
    sheet.label((50, 88), 'Edition 5 SWF source art, rendered from vectors in the default outfit (bodyMc/hatMc frame 1, '
                          'as RobotView.as sets them). Reference for redesign; not approved game art.', 19, fill=MUTED)
    # Key art and outfits.
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
    # Turnaround.
    area = sheet.panel(880, 130, 1680, 560, 'Turnaround', 'idle, frame 1 of each facing')
    # Each facing is its own sprite; frames stand on a shared baseline.
    boxes = {d: walk[d].box([1]) for d, _ in DIRECTIONS}
    tallest = max(b[3] - b[1] for b in boxes.values())
    widest = max(b[2] - b[0] for b in boxes.values())
    zoom = min((area[3] - 40) / tallest, (area[2] - 60) / (4 * widest))
    cell = area[2] / 4
    turnaround = []
    for i, (d, caption) in enumerate(DIRECTIONS):
        b = boxes[d]
        image = walk[d].draw(1, b, zoom)
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
        # No head of its own in roleHead: take the top of the front idle pose.
        source, number, box = walk['Down'], 1, boxes['Down']
        box = (box[0], box[1], box[2], box[1] + (box[3] - box[1]) * 0.56)
        sheet.label((area[0], area[1] + area[3] - 20), 'roleHead has no head for this robot', 15, fill=MUTED)
    pz = min(area[2] / (box[2] - box[0]), (area[3] - 26) / (box[3] - box[1]))
    portrait = source.draw(number, box, pz)
    sheet.paste(portrait, area[0] + (area[2] - portrait.shape[1]) / 2, area[1])
    # Outfits.
    area = sheet.panel(1300, 710, 1260, 430, 'Outfits and poses', 'distinct frames of the select illustration')
    if special:
        frames = distinct_frames(special, 6)[1:] or [1]
        row_of(sheet, special, frames, (area[0], area[1], area[2], area[3] - 6), [f'frame {n}' for n in frames])
    # Walk cycle.
    area = sheet.panel(40, 1160, 1250, 330, 'Walk cycle', 'front, 8 of 24 frames')
    frames = keyframes(len(walk['Down'].frames), 8)
    row_of(sheet, walk['Down'], frames, area, [f'{n}' for n in frames])
    # Death.
    area = sheet.panel(1310, 1160, 1250, 330, 'Defeat', f'8 of {len(dead.frames) if dead else 0} frames')
    if dead:
        frames = keyframes(len(dead.frames), 8)
        row_of(sheet, dead, frames, area, [f'{n}' for n in frames])
    # Rides.
    area = sheet.panel(40, 1510, 1500, 350, 'Rides', 'front, frame 1')
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
    area = sheet.panel(1560, 1510, 1000, 350, 'Colours and scale', 'area-weighted, from the turnaround')
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


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--robot', type=int, default=0, help='robot index 0-7 (0 is the blue human default)')
    parser.add_argument('--out', help='output PNG (default candidates/character_sheets/r<N>/sheet.png)')
    args = parser.parse_args()
    out = args.out or CANDIDATES / 'character_sheets' / f'r{args.robot}' / 'sheet.png'
    print(build(args.robot, out))


if __name__ == '__main__':
    main()
