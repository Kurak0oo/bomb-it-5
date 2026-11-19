"""Explosion lab: cut a `--sheet` capture into one animation profile sheet per robot.

    xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 \
      --fixed-fps 60 res://experiments/explosion_lab/lab.tscn -- --capture=DIR --sheet --off=shake
    python3 experiments/explosion_lab/make_sheets.py DIR experiments/explosion_lab/media/bombs

Each sheet is one strip: the bomb idle, its warning, then its blast at fixed times after
it shows. The lab writes every bomb's screen position and blast time to DIR/layout.json,
so crops and frames are picked from data, never measured by hand.
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

NAMES = ["blue", "ruby", "lime", "gold", "violet", "slate", "mint", "snow"]
# Crop around the bomb's cell centre, in cells: wide enough for a power-1 cross and the
# signature burst, tall enough for the bomb that overlaps the row above.
LEFT, RIGHT, UP, DOWN = 1.75, 1.75, 2.0, 1.6
FRAME = 220
LABEL = 26
# Seconds after the bomb's own blast shows; "idle" is the first frame captured.
AFTER = [0.02, 0.06, 0.12, 0.2, 0.28, 0.36, 0.44, 0.7]
WARNING = -0.1


def font(size):
    for name in ("DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main(capture_dir, out_dir):
    capture = Path(capture_dir)
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    layout = json.loads((capture / "layout.json").read_text())
    times = layout["times"]
    labels = ["idle", "warning"] + ["+%d ms" % round(t * 1000) for t in AFTER]
    text = font(15)
    cache = {}

    def frame(index):
        if index not in cache:
            cache[index] = Image.open(capture / ("sheet_%03d.png" % index)).convert("RGB")
        return cache[index]

    def nearest(moment):
        return min(range(len(times)), key=lambda index: abs(times[index] - moment))

    for bomb in layout["bombs"]:
        cell = bomb["cell"]
        x, y = bomb["x"], bomb["y"]
        box = (round(x - LEFT * cell), round(y - UP * cell), round(x + RIGHT * cell), round(y + DOWN * cell))
        picks = [0, nearest(bomb["blast"] + WARNING)] + [nearest(bomb["blast"] + t) for t in AFTER]
        width = FRAME
        height = round(FRAME * (box[3] - box[1]) / (box[2] - box[0]))
        sheet = Image.new("RGB", (width * len(picks), height + LABEL), "#0d86c4")
        draw = ImageDraw.Draw(sheet)
        for column, index in enumerate(picks):
            sheet.paste(frame(index).crop(box).resize((width, height), Image.LANCZOS), (column * width, LABEL))
            draw.text((column * width + 8, 5), labels[column], fill="white", font=text)
        sheet.save(out / ("%s.png" % NAMES[bomb["robot"]]))
    print("wrote %d sheets to %s" % (len(layout["bombs"]), out))


if __name__ == "__main__":
    main(*sys.argv[1:3])
