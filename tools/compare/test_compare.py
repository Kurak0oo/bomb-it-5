"""Unit checks for the comparison loop's diff logic (no SWF or Godot needed).

    python3 -m unittest discover -s tools/compare
"""
import contextlib
import io
import json
import math
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import numpy as np
from PIL import Image

import compare
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

    def test_mask_relationships_must_match(self):
        g = golden(ref_node('/m', clip_depth=3), ref_node('/a', clip_mask='/m'))
        self.assertTrue(nodes.diff(g, godot(ref_node('/m', clip_depth=3), ref_node('/a', clip_mask='/m')))['passed'])
        report = nodes.diff(g, godot(ref_node('/m', clip_depth=3), ref_node('/a')))
        self.assertFalse(report['passed'])
        self.assertIn('clip_mask', report['mismatches'][0]['problems'][0])
        self.assertFalse(nodes.diff(g, godot(ref_node('/m'), ref_node('/a', clip_mask='/m')))['passed'])

    def test_normalize_links_timeline_masks_to_the_depths_they_clip(self):
        def raw(path, depth, **extra):
            node = {'path': path, 'kind': 'graphic', 'depth': depth, 'effective_visible': True,
                    'stage_matrix': [1, 0, 0, 1, 0, 0]}
            node.update(extra)
            return node
        dump = {'schema': 'bombit5-display-list-v1', 'truncated': False, 'stage': {},
                'nodes': [raw('/c', 0), raw('/c/@1', 1, clip_depth=3), raw('/c/@2', 2), raw('/c/@3', 3), raw('/c/@4', 4)]}
        out = {n['path']: n for n in nodes.normalize_reference(dump)['nodes']}
        self.assertEqual(out['/c/@2'].get('clip_mask'), '/c/@1')
        self.assertEqual(out['/c/@3'].get('clip_mask'), '/c/@1')
        self.assertNotIn('clip_mask', out['/c/@4'])
        self.assertNotIn('clip_mask', out['/c/@1'])

    def test_owner_edits_remove_subtrees_and_shift_moved_nodes(self):
        g = golden(ref_node('/a', 10, 10), ref_node('/a/b', 12, 12), ref_node('/m', 5, 5), ref_node('/m/c', 6, 6))
        edits = {'removed': {'/a': {}}, 'moved': {'/m': {'by': [0, 30]}}}
        edited = {n['path']: n for n in nodes.apply_owner_edits(g, edits)['nodes']}
        self.assertNotIn('/a', edited)
        self.assertNotIn('/a/b', edited)
        self.assertEqual(edited['/m']['stage_matrix'][4:], [5, 35])
        self.assertEqual(edited['/m/c']['stage_matrix'][4:], [6, 36])
        report = nodes.diff(nodes.apply_owner_edits(g, edits), godot(ref_node('/m', 5, 35), ref_node('/m/c', 6, 36)))
        self.assertTrue(report['passed'], report)

    def test_effects_are_checked_by_their_rules_not_one_to_one(self):
        # /@0#4 of the game-win golden: a FallSnow confetti Bitmap.
        pink = {'add': [255, 0, 102, 0], 'mult': [0.0, 0.0, 0.0, 1.0]}
        snow = ref_node('/@0#4', kind='bitmap', color_transform=pink, render_bounds=[165.3, 19.0, 186.85, 40.5])
        snow['stage_matrix'] = [0.7676, 0.0931, -0.0931, 0.7676, 167.65, 19.0]
        g = golden(ref_node('/root1'), snow)
        effects = {'FallSnow': {'nodes': {'/@0#4': {}}}}
        mine = dict(snow, path='/FallSnow#1', effect='FallSnow', stage_matrix=[0.5, 0.0, 0.0, 0.5, 300.0, 40.0])
        g2, got, report = nodes.split_effects(g, godot(ref_node('/root1'), mine), effects)
        self.assertTrue(report['FallSnow']['passed'], report)
        self.assertTrue(nodes.diff(g2, got)['passed'])
        self.assertEqual(len(report['FallSnow']['bounds']), 2)
        off = dict(mine, color_transform={'add': [1, 2, 3, 0], 'mult': [0.0, 0.0, 0.0, 1.0]})
        _, _, report = nodes.split_effects(g, godot(ref_node('/root1'), off, mine), effects)
        self.assertFalse(report['FallSnow']['passed'])  # a colour not in _colorArr, and one too many

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
        tinted[0:64, 0:64] = (110, 60, 80)
        result = pixels.compare(self.save('a.png', self.base), self.save('b.png', tinted), Path(self.dir.name) / 'h.png')
        self.assertFalse(result['passed'])
        self.assertGreater(result['max_region_delta_e'], pixels.DEFAULT_THRESHOLDS['delta_e'])
        self.assertEqual((result['worst_region']['x'], result['worst_region']['y']), (0, 0))

    def test_shifted_content_lowers_ssim(self):
        shifted = np.roll(self.base, 3, axis=1)
        result = pixels.compare(self.save('a.png', self.base), self.save('b.png', shifted), Path(self.dir.name) / 'h.png')
        self.assertLess(result['ssim'], 0.98)
        self.assertFalse(result['passed'])

    def test_masked_region_is_not_scored(self):
        changed = self.base.copy()
        changed[100:200, 200:300] = (255, 0, 0)
        a, b = self.save('a.png', self.base), self.save('b.png', changed)
        self.assertFalse(pixels.compare(a, b, Path(self.dir.name) / 'h.png')['passed'])
        self.assertTrue(pixels.compare(a, b, Path(self.dir.name) / 'h.png', masks=[(190, 90, 310, 210)])['passed'])

    def test_size_mismatch_is_reported(self):
        small = self.base[:500]
        result = pixels.compare(self.save('a.png', self.base), self.save('b.png', small), Path(self.dir.name) / 'h.png')
        self.assertFalse(result['passed'])
        self.assertIn('size', result['error'])


class ReferenceOnlyRecord(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.root = Path(self.dir.name)
        self.goldens = self.root / 'goldens'
        self.work = self.root / 'work'
        self.case_path = self.root / 'main-menu.json'
        self.case_path.write_text(json.dumps({'name': 'main-menu', 'actions': [{'capture': 'menu'}]}),
                                  encoding='utf-8')
        self.swf = self.root / 'game.swf'
        self.swf.write_bytes(b'stub SWF; the replay is patched')
        self.player = self.root / 'probe'
        self.player.write_bytes(b'stub player')
        self.replay = {'case_path': self.case_path, 'captures': ['menu'], 'frames': {'menu': 541},
                       'fps': 35.0, 'swf_sha256': compare.sha256(self.swf)}
        self.meta = {'case': 'main-menu', 'case_sha256': compare.reference_sha256(self.case_path),
                     'swf_sha256': self.replay['swf_sha256'], 'fps': 35.0, 'frames': {'menu': 541}}
        for patch in (mock.patch.object(compare, 'ROOT', self.root),
                      mock.patch.object(compare, 'GOLDENS', self.goldens),
                      mock.patch.object(compare, 'WORK', self.work),
                      mock.patch.object(compare, 'replay_case', return_value=self.replay)):
            patch.start()
            self.addCleanup(patch.stop)

    def tearDown(self):
        self.dir.cleanup()

    def write_meta(self, **changes):
        target = self.goldens / 'main-menu'
        target.mkdir(parents=True, exist_ok=True)
        (target / 'meta.json').write_text(json.dumps(dict(self.meta, **changes)), encoding='utf-8')
        return target

    def test_reference_only_writes_nothing_under_goldens(self):
        target = self.write_meta()
        meta = (target / 'meta.json').read_bytes()
        with contextlib.redirect_stdout(io.StringIO()) as printed:
            compare.record('main-menu', self.player, self.swf, reference_only=True)
        self.assertIn('recorded reference for main-menu: 1 capture(s) in', printed.getvalue())
        self.assertEqual(sorted(p.name for p in target.iterdir()), ['meta.json'])
        self.assertEqual((target / 'meta.json').read_bytes(), meta)
        self.assertFalse((self.work / 'main-menu').exists())

    def test_frame_mismatch_raises(self):
        self.write_meta(frames={'menu': 540})
        with self.assertRaisesRegex(SystemExit, 'capture menu is at frame 540, replayed 541'):
            compare.record('main-menu', self.player, self.swf, reference_only=True)

    def test_case_hash_mismatch_raises(self):
        self.write_meta(case_sha256='0' * 64)
        with self.assertRaisesRegex(SystemExit, 'case_sha256'):
            compare.record('main-menu', self.player, self.swf, reference_only=True)

    def test_swf_hash_mismatch_raises(self):
        self.write_meta(swf_sha256='0' * 64)
        with self.assertRaisesRegex(SystemExit, 'swf_sha256'):
            compare.record('main-menu', self.player, self.swf, reference_only=True)

    def test_missing_goldens_raises(self):
        with self.assertRaisesRegex(SystemExit, 'no committed goldens'):
            compare.record('main-menu', self.player, self.swf, reference_only=True)

    def test_normal_record_still_writes_goldens_and_meta(self):
        out = self.work / 'main-menu' / 'reference'
        out.mkdir(parents=True)
        (out / 'menu.display.json').write_text(json.dumps(
            {'schema': 'bombit5-display-list-v1', 'truncated': False, 'stage': {}, 'nodes': []}),
            encoding='utf-8')
        with contextlib.redirect_stdout(io.StringIO()):
            compare.record('main-menu', self.player, self.swf)
        target = self.goldens / 'main-menu'
        self.assertTrue((target / 'menu.json').is_file())
        meta = json.loads((target / 'meta.json').read_text(encoding='utf-8'))
        self.assertEqual(meta['frames'], {'menu': 541})
        self.assertEqual(meta['case_sha256'], compare.reference_sha256(self.case_path))


if __name__ == '__main__':
    unittest.main()
