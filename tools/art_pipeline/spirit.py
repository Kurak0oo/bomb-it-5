"""Soft 'emotion spirit' redesign: one parametric 3D rig rendered with Blender Cycles.

    python tools/art_pipeline/spirit.py [--robot 0] [--samples 48]

Reads tools/art_pipeline/spirit_specs/r<N>.json. Every frame comes from the same rig
(subsurface skin, glowing antenna orbs, big eyes), so facings and animation stay
consistent. Writes the ignored candidates/spirit/r<N>/ folder: sheet.png beside the
original, workbench sheets walk.png / idle.png / death.png and the raw frames.
"""
import argparse
import json
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy
import numpy as np
from mathutils import Vector
from PIL import Image, ImageFilter

from character_sheet import DIRECTIONS, MUTED, RULE, Sheet, find, font, palette
from common import CANDIDATES, HERE, hex_to_rgb, rgb_to_hex, save_png

SPECS = HERE / 'spirit_specs'
FACING_YAW = {'Down': 0, 'Right': 90, 'Up': 180, 'Left': -90}
SLOT_CELL = (40, 44)


def linear(hex_colour, alpha=1.0):
    """sRGB hex to Blender's linear RGBA."""
    c = [v / 255 for v in hex_to_rgb(hex_colour)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c) + (alpha,)


class Rig:
    def __init__(self, spec, samples):
        self.spec = spec
        bpy.ops.wm.read_factory_settings(use_empty=True)
        scene = bpy.context.scene
        scene.render.engine = 'CYCLES'
        scene.cycles.device = 'CPU'
        scene.cycles.samples = samples
        scene.cycles.use_denoising = True
        scene.render.film_transparent = True
        try:
            scene.view_settings.view_transform = 'Khronos PBR Neutral'  # Keeps the primary colour saturated.
        except TypeError:
            scene.view_settings.view_transform = 'Standard'
        world = bpy.data.worlds.new('world')
        scene.world = world
        world.use_nodes = True
        world.node_tree.nodes['Background'].inputs['Color'].default_value = linear('#eaf4ff')
        world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.3
        self.materials = {}
        self.objects = {}
        self.root = self._empty('root', (0, 0, 0))
        self._build()
        self._lights()
        self._camera()

    # ---------------------------------------------------------------- materials
    def material(self, name, colour, subsurface=0.5, emission=0.0, roughness=0.45, sheen=0.3, glow=None):
        mat = bpy.data.materials.new(name)
        bsdf = mat.node_tree.nodes['Principled BSDF']
        bsdf.inputs['Base Color'].default_value = linear(colour)
        bsdf.inputs['Roughness'].default_value = roughness
        bsdf.inputs['Subsurface Weight'].default_value = subsurface
        bsdf.inputs['Subsurface Radius'].default_value = (0.6, 0.8, 1.0)
        bsdf.inputs['Subsurface Scale'].default_value = 0.08
        bsdf.inputs['Sheen Weight'].default_value = sheen
        bsdf.inputs['Sheen Tint'].default_value = linear(glow or '#ffffff')
        bsdf.inputs['Coat Weight'].default_value = 0.15
        bsdf.inputs['Emission Color'].default_value = linear(glow or colour)
        bsdf.inputs['Emission Strength'].default_value = emission
        self.materials[name] = (mat, colour, emission)
        return mat

    # ---------------------------------------------------------------- shapes
    def _empty(self, name, location, parent=None):
        empty = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(empty)
        empty.location = location
        if parent:
            empty.parent = parent
        return empty

    def blob(self, name, location, scale, material, parent, segments=48):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2, radius=1, location=(0, 0, 0))
        obj = bpy.context.active_object
        obj.name = name
        obj.scale = scale
        obj.location = location
        obj.parent = parent
        bpy.ops.object.shade_smooth()
        obj.data.materials.append(material)
        self.objects[name] = obj
        return obj

    def tuft(self, name, points, radius, material, parent):
        """A soft tapered strand (hair tuft / antenna) along bezier points."""
        curve = bpy.data.curves.new(name, 'CURVE')
        curve.dimensions = '3D'
        curve.bevel_depth = radius
        curve.bevel_resolution = 6
        curve.use_fill_caps = True
        spline = curve.splines.new('BEZIER')
        spline.bezier_points.add(len(points) - 1)
        for point, (x, y, z, r) in zip(spline.bezier_points, points):
            point.co = (x, y, z)
            point.handle_left_type = point.handle_right_type = 'AUTO'
            point.radius = r
        obj = bpy.data.objects.new(name, curve)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = parent
        obj.data.materials.append(material)
        self.objects[name] = obj
        return obj

    def _build(self):
        s = self.spec
        skin = self.material('skin', s['body'], subsurface=0.6, emission=s.get('inner_glow', 0.12),
                             glow=s['glow'], sheen=0.6)
        lower = self.material('lower', s.get('lower', s['body']), subsurface=0.6, emission=0.08, glow=s['glow'])
        accent = self.material('accent', s['accent'], subsurface=0.5, emission=0.1, glow=s['glow'])
        white = self.material('eye_white', '#ffffff', subsurface=0.1, roughness=0.15, sheen=0)
        iris = self.material('iris', s['iris'], subsurface=0, roughness=0.2, sheen=0, emission=0.25, glow=s['iris'])
        pupil = self.material('pupil', s['pupil'], subsurface=0, roughness=0.1, sheen=0)
        spark = self.material('spark', '#ffffff', subsurface=0, emission=6.0, sheen=0, glow='#ffffff')
        mouth = self.material('mouth', s['mouth'], subsurface=0.2, roughness=0.4, sheen=0)
        orb = self.material('orb', s['orb'], subsurface=0.2, emission=s.get('orb_glow', 4.0), glow=s['orb'], sheen=0)
        self.body = self._empty('body', (0, 0, 0), self.root)
        # Teardrop body: wide soft base tapering up into the head.
        self.blob('torso', (0, 0, 0.6), (0.33, 0.3, 0.4), skin, self.body)
        self.blob('hips', (0, 0, 0.36), (0.31, 0.28, 0.22), lower, self.body)
        self.head_pivot = self._empty('head_pivot', (0, 0, 0.88), self.body)
        self.blob('head', (0, 0, 0.42), (0.58, 0.52, 0.52), skin, self.head_pivot)
        # Eyes: big glossy ovals on the head's front (-y), iris and pupil layered forward.
        for side in (-1, 1):
            x = side * s.get('eye_spread', 0.22)
            eye = self._empty(f'eye_{side}', (x, -0.425, 0.46), self.head_pivot)
            self.blob(f'white_{side}', (0, 0.01, 0), (0.16, 0.05, 0.2), white, eye)
            self.blob(f'iris_{side}', (0, -0.035, -0.015), (0.135, 0.05, 0.165), iris, eye)
            self.blob(f'pupil_{side}', (0, -0.065, -0.02), (0.075, 0.03, 0.095), pupil, eye)
            self.blob(f'spark_{side}', (side * -0.04, -0.095, 0.06), (0.035, 0.015, 0.04), spark, eye, segments=16)
            self.blob(f'spark2_{side}', (side * 0.045, -0.095, -0.06), (0.016, 0.01, 0.018), spark, eye, segments=12)
            self.objects[f'eye_{side}'] = eye
        self.tuft('mouth', [(-0.075, -0.49, 0.23, 0.8), (0, -0.515, 0.185, 1.0), (0.075, -0.49, 0.23, 0.8)],
                  0.016, mouth, self.head_pivot)
        # Earmuff pieces become soft side puffs.
        for side in (-1, 1):
            self.blob(f'puff_{side}', (side * 0.56, 0.02, 0.42), (0.11, 0.17, 0.17), accent, self.head_pivot)
        # Antennae become curling soft tufts with glowing orbs (count and spread from the spec).
        self.tufts = []
        for i, (x, lean) in enumerate(s['antennae']):
            pivot = self._empty(f'tuft_pivot_{i}', (x, 0, 0.86), self.head_pivot)
            self.tuft(f'tuft_{i}', [(0, 0, -0.04, 1.4), (lean * 0.06, 0.0, 0.14, 1.0), (lean * 0.18, 0.0, 0.26, 0.7),
                                    (lean * 0.26, 0.0, 0.33, 0.55)], 0.05, skin, pivot)
            self.blob(f'orb_{i}', (lean * 0.28, 0, 0.38), (0.085, 0.085, 0.085), orb, pivot, segments=24)
            self.tufts.append(pivot)
        # Stubby arms and feet hang from pivots so the float cycle can swing them.
        self.arms, self.feet = [], []
        for side in (-1, 1):
            arm = self._empty(f'arm_{side}', (side * 0.27, 0, 0.76), self.body)
            self.blob(f'arm_mesh_{side}', (side * 0.05, 0, -0.13), (0.085, 0.085, 0.17), skin, arm)
            self.arms.append(arm)
            foot = self._empty(f'foot_{side}', (side * 0.13, 0, 0.22), self.body)
            self.blob(f'foot_mesh_{side}', (0, -0.02, -0.12), (0.1, 0.12, 0.09), lower, foot)
            self.feet.append(foot)

    def _lights(self):
        for name, location, energy, size, colour in (
                ('key', (-2.2, -3.0, 3.2), 520, 3.0, '#fff4e6'),
                ('fill', (2.6, -2.2, 1.4), 160, 3.5, '#e6f2ff'),
                ('rim', (0.5, 3.0, 2.6), 380, 2.0, self.spec['glow'])):
            light = bpy.data.lights.new(name, 'AREA')
            light.energy, light.size = energy, size
            light.color = linear(colour)[:3]
            obj = bpy.data.objects.new(name, light)
            bpy.context.scene.collection.objects.link(obj)
            obj.location = location
            direction = Vector((0, 0, 0.9)) - obj.location
            obj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()

    def _camera(self, pitch=10):
        camera = bpy.data.cameras.new('camera')
        camera.type = 'ORTHO'
        camera.ortho_scale = 2.45
        obj = bpy.data.objects.new('camera', camera)
        bpy.context.scene.collection.objects.link(obj)
        target = Vector((0, 0, 1.16))
        a = math.radians(pitch)
        obj.location = target + Vector((0, -10 * math.cos(a), 10 * math.sin(a)))
        obj.rotation_euler = (target - obj.location).to_track_quat('-Z', 'Y').to_euler()
        bpy.context.scene.camera = obj
        self.camera = obj

    # ---------------------------------------------------------------- posing
    def pose(self, facing='Down', yaw=None, phase=None, defeat=0.0):
        self.root.rotation_euler = (0, 0, math.radians(FACING_YAW[facing] if yaw is None else yaw))
        swing = math.sin(2 * math.pi * phase) if phase is not None else 0.0
        bob = 0.05 * math.sin(4 * math.pi * phase) if phase is not None else 0.0
        self.body.location = (0, 0, 0.06 + bob)
        self.body.rotation_euler = (math.radians(4 * swing), 0, 0)
        for side, arm in zip((-1, 1), self.arms):
            arm.rotation_euler = (math.radians(28 * swing * side), math.radians(-side * 12), 0)
        for side, foot in zip((-1, 1), self.feet):
            foot.rotation_euler = (math.radians(-22 * swing * side), 0, 0)
        for i, tuft in enumerate(self.tufts):
            tuft.rotation_euler = (math.radians(-8 * swing), math.radians(6 * swing * (1 if i % 2 else -1)), 0)
        # Defeat: eyes close, colour drains toward grey, glow fades; the fade-out is applied after render.
        for side in (-1, 1):
            self.objects[f'eye_{side}'].scale = (1, 1, max(0.12, 1 - defeat * 1.6))
        grey = np.array(hex_to_rgb(self.spec.get('drained', '#9aa7b4')), dtype=float)
        for name, (mat, colour, emission) in self.materials.items():
            if name in ('eye_white', 'pupil', 'spark'):
                continue
            mixed = np.array(hex_to_rgb(colour), dtype=float) * (1 - defeat * 0.8) + grey * defeat * 0.8
            bsdf = mat.node_tree.nodes['Principled BSDF']
            bsdf.inputs['Base Color'].default_value = linear(rgb_to_hex(mixed.round()))
            bsdf.inputs['Emission Strength'].default_value = emission * (1 - defeat)

    def render(self, size, path):
        scene = bpy.context.scene
        scene.render.resolution_x, scene.render.resolution_y = size
        scene.render.resolution_percentage = 100
        aspect = size[0] / size[1]
        self.camera.data.ortho_scale = 2.45 * max(1.0, aspect)
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        return np.array(Image.open(path).convert('RGBA'))


def aura(rgba, colour, radius, strength):
    """Soft halo: the silhouette blurred, tinted with the glow colour, placed underneath."""
    image = Image.fromarray(rgba)
    alpha = image.getchannel('A').filter(ImageFilter.GaussianBlur(radius))
    halo = Image.new('RGBA', image.size, hex_to_rgb(colour) + (0,))
    halo.putalpha(alpha.point(lambda a: int(a * strength)))
    return np.array(Image.alpha_composite(halo, image))


def gradient(size, top, bottom):
    t = np.linspace(0, 1, size[1])[:, None, None]
    colours = np.array(hex_to_rgb(top)) * (1 - t) + np.array(hex_to_rgb(bottom)) * t
    return np.dstack([np.repeat(colours, size[0], 1).astype(np.uint8), np.full((size[1], size[0]), 255, np.uint8)])


def build(robot, samples):
    spec = json.loads((SPECS / f'r{robot}.json').read_text(encoding='utf-8'))
    folder = CANDIDATES / 'spirit' / f'r{robot}'
    raw = folder / 'frames'
    raw.mkdir(parents=True, exist_ok=True)
    rig = Rig(spec, samples)
    glow = spec['glow']
    cell = (SLOT_CELL[0] * 4, SLOT_CELL[1] * 4)

    def shot(name, size, **pose):
        rig.pose(**pose)
        return aura(rig.render(size, raw / f'{name}.png'), glow, max(2, size[0] // 40), 0.45)

    count = spec.get('walk_frames', 8)
    walk = {d: [shot(f'walk_{d}_{i + 1}', cell, facing=d, phase=i / count) for i in range(count)] for d, _ in DIRECTIONS}
    idle = {d: shot(f'idle_{d}', cell, facing=d) for d, _ in DIRECTIONS}
    death = []
    for i, k in enumerate((0, 0.25, 0.5, 0.75, 1.0, 1.0, 1.0)):
        frame = shot(f'defeat_{i + 1}', cell, facing='Down', defeat=k)
        fade = max(0.0, 1 - max(0, i - 3) * 0.33)  # The last frames fade the spirit away.
        frame[..., 3] = (frame[..., 3] * fade).astype(np.uint8)
        death.append(frame)
    hero = shot('hero', (900, 1000), yaw=-25, phase=0.12)
    turnaround = [shot(f'turn_{d}', (500, 560), facing=d) for d, _ in DIRECTIONS]

    def sheet_of(rows):
        out = np.zeros((len(rows) * cell[1], max(len(r) for r in rows) * cell[0], 4), np.uint8)
        for r, row in enumerate(rows):
            for c, image in enumerate(row):
                out[r * cell[1]:(r + 1) * cell[1], c * cell[0]:(c + 1) * cell[0]] = image
        return out

    save_png(folder / 'walk.png', sheet_of([walk[d] for d, _ in DIRECTIONS]))
    save_png(folder / 'idle.png', sheet_of([[idle[d]] for d, _ in DIRECTIONS]))
    save_png(folder / 'death.png', sheet_of([death]))

    # Review sheet.
    prefix = f'_r{robot}'
    sheet = Sheet(2600, 1900)
    sheet.label((48, 34), f'ROBOT {prefix}  ·  EMOTION SPIRIT REDESIGN', 40, True)
    sheet.label((50, 88), f'One 3D rig (spirit_specs/r{robot}.json) rendered in Blender Cycles: subsurface skin, glowing '
                          'antenna orbs, soft aura. Every frame uses the same rig. Candidate art for review only.',
                19, fill=MUTED)
    area = sheet.panel(40, 130, 560, 1000, 'Original', 'select art and front idle')
    special = find(rf'robot{robot + 1}_+special_\d+_', pinned=False)
    front = find(rf'_{re.escape(prefix)}_Down_')
    if special:
        box = special.box([1])
        zoom = min(area[2] / (box[2] - box[0]), 560 / (box[3] - box[1]))
        image = special.draw(1, box, zoom)
        sheet.paste(image, area[0] + (area[2] - image.shape[1]) / 2, area[1])
    if front:
        box = front.box([1])
        image = front.draw(1, box, 280 / (box[3] - box[1]))
        sheet.paste(image, area[0] + (area[2] - image.shape[1]) / 2, area[1] + 610)
    area = sheet.panel(620, 130, 900, 1000, 'Spirit', 'three-quarter view')
    backdrop = gradient((hero.shape[1], hero.shape[0]), spec.get('backdrop_top', '#f3f8ff'),
                        spec.get('backdrop_bottom', '#d6ecfb'))
    framed = Image.alpha_composite(Image.fromarray(backdrop), Image.fromarray(hero))
    framed = np.array(framed.resize((area[2], round(area[2] * hero.shape[0] / hero.shape[1])), Image.LANCZOS))
    sheet.paste(framed[:area[3]], area[0], area[1])
    area = sheet.panel(1540, 130, 1020, 1000, 'Turnaround', 'game camera')
    width = area[2] / 4
    for i, ((_, caption), image) in enumerate(zip(DIRECTIONS, turnaround)):
        small = np.array(Image.fromarray(image).resize((round(width), round(width * 560 / 500)), Image.LANCZOS))
        sheet.paste(small, area[0] + i * width, area[1] + 140)
        tw = sheet.pen.textlength(caption, font=font(20, True))
        sheet.label((area[0] + i * width + (width - tw) / 2, area[1] + 140 + small.shape[0] + 10), caption, 20, True,
                    fill=MUTED)
    for row, (d, caption) in enumerate((('Down', 'front'), ('Right', 'right'))):
        area = sheet.panel(40 + row * 1270, 1150, 1250, 300, 'Float cycle', f'{caption}, {count} frames')
        step = area[2] / count
        for i, image in enumerate(walk[d]):
            small = np.array(Image.fromarray(image).resize((round(step), round(step * cell[1] / cell[0])), Image.LANCZOS))
            sheet.paste(small, area[0] + i * step, area[1])
            sheet.label((area[0] + i * step + step / 2 - 4, area[1] + small.shape[0] + 4), str(i + 1), 15, fill=MUTED)
    area = sheet.panel(40, 1470, 1500, 390, 'Defeat', 'eyes close, colour drains, the spirit fades')
    step = area[2] / len(death)
    for i, image in enumerate(death):
        small = np.array(Image.fromarray(image).resize((round(step), round(step * cell[1] / cell[0])), Image.LANCZOS))
        sheet.paste(small, area[0] + i * step, area[1])
    area = sheet.panel(1560, 1470, 1000, 390, 'Colours and scale', 'rendered colours; in-game 1x versus the original')
    for i, colour in enumerate(palette([hero])[:12]):
        cx, cy = area[0] + (i % 6) * 78, area[1] + (i // 6) * 110
        sheet.pen.rounded_rectangle((cx, cy, cx + 66, cy + 66), 8, fill=colour + (255,), outline=RULE)
        sheet.label((cx, cy + 70), rgb_to_hex(colour), 13, fill=MUTED)
    gx, gy = area[0] + 500, area[1]
    sheet.label((gx, gy), 'In game, 1x (40x44 slot)', 15, fill=MUTED)
    sheet.paste(np.array(Image.fromarray(idle['Down']).resize(SLOT_CELL, Image.LANCZOS)), gx, gy + 30)
    if front:
        box = front.box([1])
        orig = front.draw(1, box, min(SLOT_CELL[0] / (box[2] - box[0]), SLOT_CELL[1] / (box[3] - box[1])))
        sheet.paste(orig, gx + 70, gy + 30 + SLOT_CELL[1] - orig.shape[0])
    sheet.label((gx, gy + 84), 'spirit    original', 13, fill=MUTED)
    sheet.paste(np.array(Image.fromarray(idle['Down']).resize((SLOT_CELL[0] * 3, SLOT_CELL[1] * 3), Image.LANCZOS)),
                gx, gy + 120)
    sheet.label((gx + 130, gy + 250), '3x', 14, fill=MUTED)
    save_png(folder / 'sheet.png', np.array(sheet.image))
    return folder


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--robot', type=int, default=0)
    parser.add_argument('--samples', type=int, default=48)
    args = parser.parse_args()
    print(build(args.robot, args.samples))


if __name__ == '__main__':
    main()
