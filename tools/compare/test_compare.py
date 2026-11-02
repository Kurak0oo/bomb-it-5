"""Unit checks for the comparison loop's diff logic (no SWF or Godot needed).

    python3 -m unittest discover -s tools/compare
"""
import math
from pathlib import Path
import tempfile
import unittest

import numpy as np
from PIL import Image

import nodes
import pixels


def ref_node(path, x=0.0, y=0.0, scale=1.0, visible=True, **extra):
    node = {'path': path, 'kind': 'movie_clip', 'effective_visible': visible, 'alpha': 1.0,
            'stage_matrix': [scale, 0.0, 0.0, scale, x, y]}
    node.update(extra)
    return node


def golden(*items):
    return {'schema': 'bombit5-golden-nodes-v1', 'nodes': [{'path': '', 'kind': 'stage'}] + list(items)}


def godot(*items):
    return {'schema': 'bombit5-godot-nodes-v1', 'nodes': list(items)}


class NodeDiff(unittest.TestCase):
    def test_exact_match_passes(self):
        g = golden(ref_node('/root1/menu', 10, 20, frame=3))
        report = nodes.diff(g, godot(ref_node('/root1/menu', 10, 20, frame=3)))
        self.assertTrue(report['passed'], report)
        self.assertEqual(report['matched'], 1)

    def test_position_tolerance_is_half_a_stage_unit(self):
        g = golden(ref_node('/a', 100, 100))
        self.assertTrue(nodes.diff(g, godot(ref_node('/a', 100.4, 100)))['passed'])
        report = nodes.diff(g, godot(ref_node('/a', 100.6, 100)))
        self.assertFalse(report['passed'])
        self.assertIn('position', report['mismatches'][0]['problems'][0])

    def test_scale_tolerance_is_relative(self):
        g = golden(ref_node('/a', scale=2.0))
        self.assertTrue(nodes.diff(g, godot(ref_node('/a', scale=2.0015)))['passed'])
        self.assertFalse(nodes.diff(g, godot(ref_node('/a', scale=2.01)))['passed'])

    def test_missing_visible_node_fails_hidden_one_does_not(self):
        g = golden(ref_node('/shown'), ref_node('/hidden', visible=False))
        report = nodes.diff(g, godot(ref_node('/shown')))
        self.assertTrue(report['passed'], report)
        report = nodes.diff(g, godot(ref_node('/hidden', visible=False)))
        self.assertEqual(report['missing'], ['/shown'])

    def test_visibility_mismatch_fails(self):
        g = golden(ref_node('/a', visible=False))
        report = nodes.diff(g, godot(ref_node('/a', visible=True)))
        self.assertFalse(report['passed'])

    def test_extra_godot_node_fails(self):
        report = nodes.diff(golden(ref_node('/a')), godot(ref_node('/a'), ref_node('/invented')))
        self.assertEqual(report['extra'], ['/invented'])
        self.assertFalse(report['passed'])

    def test_baked_node_covers_its_subtree(self):
        g = golden(ref_node('/btn'), ref_node('/btn/@1'), ref_node('/btn/@2/label'))
        report = nodes.diff(g, godot(ref_node('/btn', baked=True)))
        self.assertTrue(report['passed'], report)

    def test_frame_and_button_state_must_match(self):
        g = golden(ref_node('/b', frame=2, button_state='over'))
        self.assertFalse(nodes.diff(g, godot(ref_node('/b', frame=1, button_state='over')))['passed'])
        self.assertFalse(nodes.diff(g, godot(ref_node('/b', frame=2, button_state='up')))['passed'])
        self.assertFalse(nodes.diff(g, godot(ref_node('/b', frame=2)))['passed'])

    def test_decompose_reads_flash_matrix(self):
        angle = math.radians(30)
        m = [2 * math.cos(angle), 2 * math.sin(angle), -3 * math.sin(angle), 3 * math.cos(angle), 5, 6]
        d = nodes.decompose(m)
        self.assertAlmostEqual(d['sx'], 2)
        self.assertAlmostEqual(d['sy'], 3)
        self.assertAlmostEqual(d['rotation'], 30)
        self.assertEqual((d['x'], d['y']), (5, 6))

    def test_normalize_rejects_truncated_dump(self):
        with self.assertRaises(ValueError):
            nodes.normalize_reference({'schema': 'bombit5-display-list-v1', 'truncated': True, 'nodes': [], 'stage': {}})

    def test_duplicate_godot_paths_are_an_error(self):
        with self.assertRaises(ValueError):
            nodes.diff(golden(ref_node('/a')), godot(ref_node('/a'), ref_node('/a')))


class PixelDiff(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        rng = np.random.default_rng(1)
        base = np.zeros((510, 700, 3), np.uint8)
        base[:, :] = (40, 60, 80)
        base[100:300, 200:500] = rng.integers(0, 255, (200, 300, 3), dtype=np.uint8)
        self.base = base

    def tearDown(self):
        self.dir.cleanup()

    def save(self, name, array):
        path = Path(self.dir.name) / name
        Image.fromarray(array).save(path)
        return path

    def test_identical_images_pass(self):
        a = self.save('a.png', self.base)
        result = pixels.compare(a, a, Path(self.dir.name) / 'h.png')
        self.assertTrue(result['passed'])
        self.assertAlmostEqual(result['ssim'], 1.0, places=5)
        self.assertEqual(result['max_region_delta_e'], 0.0)

    def test_tinted_region_fails_on_colour(self):
        tinted = self.base.copy()
        tinted[0:64, 0:64] = (60, 60, 80)
        result = pixels.compare(self.save('a.png', self.base), self.save('b.png', tinted), Path(self.dir.name) / 'h.png')
        self.assertFalse(result['passed'])
        self.assertGreater(result['max_region_delta_e'], 2.0)
        self.assertEqual((result['worst_region']['x'], result['worst_region']['y']), (0, 0))

    def test_shifted_content_lowers_ssim(self):
        shifted = np.roll(self.base, 3, axis=1)
        result = pixels.compare(self.save('a.png', self.base), self.save('b.png', shifted), Path(self.dir.name) / 'h.png')
        self.assertLess(result['ssim'], 0.98)
        self.assertFalse(result['passed'])

    def test_size_mismatch_is_reported(self):
        small = self.base[:500]
        result = pixels.compare(self.save('a.png', self.base), self.save('b.png', small), Path(self.dir.name) / 'h.png')
        self.assertFalse(result['passed'])
        self.assertIn('size', result['error'])


if __name__ == '__main__':
    unittest.main()
