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
        self.cases = self.root / 'cases'
        self.cases.mkdir()
        self.case_path = self.cases / 'main-menu.json'
        self.case_path.write_text(json.dumps({'name': 'main-menu', 'actions': [{'capture': 'menu'}]}),
                                  encoding='utf-8')
        self.swf = self.root / 'game.swf'
        self.swf.write_bytes(b'stub SWF; the replay is patched')
        self.player = self.root / 'probe'
        self.player.write_bytes(b'stub player')
        self.display = {'schema': 'bombit5-display-list-v1', 'truncated': False, 'stage': {},
                        'nodes': [{'path': '/root1/menu', 'kind': 'movie_clip', 'depth': 1,
                                   'effective_visible': True, 'alpha': 1.0,
                                   'stage_matrix': [1.0, 0.0, 0.0, 1.0, 10.0, 20.0]}]}
        self.golden = nodes.normalize_reference(self.display)
        self.golden['frame'] = 541
        self.replay_display = None
        self.replay = {'case_path': self.case_path, 'captures': ['menu'], 'frames': {'menu': 541},
                       'fps': 35.0, 'swf_sha256': compare.sha256(self.swf),
                       'player_sha256': compare.sha256(self.player)}
        self.meta = {'case': 'main-menu', 'case_sha256': compare.reference_sha256(self.case_path),
                     'swf_sha256': self.replay['swf_sha256'],
                     'player_sha256': self.replay['player_sha256'],
                     'fps': 35.0, 'frames': {'menu': 541}}
        for patch in (mock.patch.object(compare, 'ROOT', self.root),
                      mock.patch.object(compare, 'GOLDENS', self.goldens),
                      mock.patch.object(compare, 'WORK', self.work),
                      mock.patch.object(compare, 'CASES', self.cases),
                      mock.patch.object(compare, 'replay_case', side_effect=self.fake_replay)):
            patch.start()
            self.addCleanup(patch.stop)

    def tearDown(self):
        self.dir.cleanup()

    def fake_replay(self, name, player, swf, out=None):
        """A replay that writes only what `record` reads: a PNG and a display list."""
        out = Path(out) if out is not None else compare.WORK / name / 'reference'
        out.mkdir(parents=True, exist_ok=True)
        (out / 'menu.png').write_bytes(b'stub reference PNG')
        display = self.display if self.replay_display is None else self.replay_display
        (out / 'menu.display.json').write_text(json.dumps(display), encoding='utf-8')
        return dict(self.replay, out=out)

    def write_meta(self, **changes):
        target = self.goldens / 'main-menu'
        target.mkdir(parents=True, exist_ok=True)
        (target / 'menu.json').write_text(json.dumps(self.golden, indent=1, sort_keys=True) + '\n',
                                          encoding='utf-8')
        (target / 'meta.json').write_text(json.dumps(dict(self.meta, **changes)), encoding='utf-8')
        return target

    def seed_reference(self):
        out = self.work / 'main-menu' / 'reference'
        out.mkdir(parents=True, exist_ok=True)
        (out / 'menu.png').write_bytes(b'good reference PNG')
        (out / 'reference.json').write_text('{"kept": true}\n', encoding='utf-8')
        return out

    def test_reference_only_writes_nothing_under_goldens(self):
        target = self.write_meta()
        meta = (target / 'meta.json').read_bytes()
        golden = (target / 'menu.json').read_bytes()
        with contextlib.redirect_stdout(io.StringIO()) as printed:
            compare.record('main-menu', self.player, self.swf, reference_only=True)
        self.assertIn('recorded reference for main-menu: 1 capture(s) in', printed.getvalue())
        self.assertEqual(sorted(p.name for p in target.iterdir()), ['menu.json', 'meta.json'])
        self.assertEqual((target / 'meta.json').read_bytes(), meta)
        self.assertEqual((target / 'menu.json').read_bytes(), golden)
        self.assertTrue((self.work / 'main-menu' / 'reference' / 'menu.png').is_file())

    def test_reference_only_writes_provenance(self):
        target = self.write_meta()
        with contextlib.redirect_stdout(io.StringIO()):
            compare.record('main-menu', self.player, self.swf, reference_only=True)
        provenance = json.loads((self.work / 'main-menu' / 'reference' / 'reference.json').read_text(encoding='utf-8'))
        self.assertEqual(provenance['case_sha256'], compare.reference_sha256(self.case_path))
        self.assertEqual(provenance['swf_sha256'], compare.sha256(self.swf))
        self.assertEqual(provenance['player_sha256'], compare.sha256(self.player))
        self.assertEqual(provenance['frames'], {'menu': 541})
        self.assertEqual(provenance['golden_sha256'], {'menu': compare.sha256(target / 'menu.json')})

    def test_frame_mismatch_raises(self):
        self.write_meta(frames={'menu': 540})
        with self.assertRaisesRegex(SystemExit, 'capture menu is at frame 540, replayed 541'):
            compare.record('main-menu', self.player, self.swf, reference_only=True)

    def test_scene_mismatch_raises(self):
        self.write_meta()
        self.display['nodes'][0]['stage_matrix'][4] = 50.0
        with self.assertRaisesRegex(SystemExit, 'capture menu scene differs'):
            compare.record('main-menu', self.player, self.swf, reference_only=True)

    def write_layout(self, **layout):
        target = self.root / 'scenes' / 'swf' / 'screen.json'
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(dict({'screen': 'menu',
                                           'source': {'golden': 'tests/goldens/main-menu/menu.json'}},
                                          **layout)), encoding='utf-8')

    def rewrite_case(self, **changes):
        case = json.loads(self.case_path.read_text(encoding='utf-8'))
        self.case_path.write_text(json.dumps(dict(case, **changes)), encoding='utf-8')
        self.meta['case_sha256'] = compare.reference_sha256(self.case_path)

    def test_wall_clock_text_difference_is_accepted(self):
        self.rewrite_case(wall_clock_text={'/root1/time': 'Game.countTime polls the host clock'})
        self.display['nodes'][0].update(path='/root1/time', text='178')
        self.golden = nodes.normalize_reference(self.display)
        self.golden['frame'] = 541
        self.replay_display = json.loads(json.dumps(self.display))
        self.replay_display['nodes'][0]['text'] = '179'
        self.write_meta()
        with contextlib.redirect_stdout(io.StringIO()):
            compare.record('main-menu', self.player, self.swf, reference_only=True)
        self.assertTrue((self.work / 'main-menu' / 'reference' / 'reference.json').is_file())

    def test_random_effect_difference_is_accepted(self):
        pink = {'add': [255, 0, 102, 0], 'mult': [0.0, 0.0, 0.0, 1.0]}
        snow = ref_node('/@0#4', kind='bitmap', color_transform=pink, render_bounds=[165.3, 19.0, 186.85, 40.5])
        snow['stage_matrix'] = [0.7676, 0.0931, -0.0931, 0.7676, 167.65, 19.0]
        self.display['nodes'].append(snow)
        self.golden = nodes.normalize_reference(self.display)
        self.golden['frame'] = 541
        self.replay_display = json.loads(json.dumps(self.display))
        self.replay_display['nodes'][-1] = dict(
            snow, color_transform={'add': [102, 204, 102, 0], 'mult': [0.0, 0.0, 0.0, 1.0]},
            stage_matrix=[0.433, 0.25, -0.25, 0.433, 300.0, 40.0])
        self.write_layout(effects={'FallSnow': {'nodes': {'/@0#4': {}}}})
        self.write_meta()
        with contextlib.redirect_stdout(io.StringIO()):
            compare.record('main-menu', self.player, self.swf, reference_only=True)
        self.assertTrue((self.work / 'main-menu' / 'reference' / 'reference.json').is_file())

    def test_wrong_class_node_at_effect_path_is_refused(self):
        # The layout's effect is a FallSnow Bitmap; a static movie clip at its path is not
        # the effect, so it is left in the scene (an extra) rather than dropped.
        pink = {'add': [255, 0, 102, 0], 'mult': [0.0, 0.0, 0.0, 1.0]}
        snow = ref_node('/@0#4', kind='bitmap', color_transform=pink, render_bounds=[165.3, 19.0, 186.85, 40.5])
        snow['class'] = 'flash.display::Bitmap'
        snow['stage_matrix'] = [0.7676, 0.0931, -0.0931, 0.7676, 167.65, 19.0]
        self.display['nodes'].append(snow)
        self.golden = nodes.normalize_reference(self.display)
        self.golden['frame'] = 541
        self.replay_display = json.loads(json.dumps(self.display))
        self.replay_display['nodes'][-1] = ref_node('/@0#4', kind='movie_clip', x=300, y=40)
        self.write_layout(effects={'FallSnow': {'class': 'flash.display::Bitmap',
                                                'nodes': {'/@0#4': {}}}})
        self.write_meta()
        with self.assertRaisesRegex(SystemExit, 'scene differs'):
            compare.record('main-menu', self.player, self.swf, reference_only=True)

    def test_effect_node_breaking_its_rules_is_refused(self):
        # A Bitmap at the effect path with a scale the AS3 never makes is tagged and taken
        # out of the node diff; the effect's own rules must still refuse it (check does).
        pink = {'add': [255, 0, 102, 0], 'mult': [0.0, 0.0, 0.0, 1.0]}
        snow = ref_node('/@0#4', kind='bitmap', color_transform=pink, render_bounds=[165.3, 19.0, 186.85, 40.5])
        snow['class'] = 'flash.display::Bitmap'
        snow['stage_matrix'] = [0.7676, 0.0931, -0.0931, 0.7676, 167.65, 19.0]
        self.display['nodes'].append(snow)
        self.golden = nodes.normalize_reference(self.display)
        self.golden['frame'] = 541
        self.replay_display = json.loads(json.dumps(self.display))
        self.replay_display['nodes'][-1]['stage_matrix'] = [1.0, 0.0, 0.0, 1.0, 300.0, 40.0]
        self.write_layout(effects={'FallSnow': {'class': 'flash.display::Bitmap',
                                                'nodes': {'/@0#4': {}}}})
        self.write_meta()
        with self.assertRaisesRegex(SystemExit, 'scale'):
            compare.record('main-menu', self.player, self.swf, reference_only=True)

    def test_owner_edited_node_in_both_is_accepted(self):
        self.display['nodes'].append(ref_node('/root1/removed', 5, 5))
        self.golden = nodes.normalize_reference(self.display)
        self.golden['frame'] = 541
        self.replay_display = json.loads(json.dumps(self.display))
        self.write_layout(owner_edits={'removed': {'/root1/menu': {}}})
        self.write_meta()
        with contextlib.redirect_stdout(io.StringIO()):
            compare.record('main-menu', self.player, self.swf, reference_only=True)
        self.assertTrue((self.work / 'main-menu' / 'reference' / 'reference.json').is_file())

    def test_regular_node_frame_difference_is_refused(self):
        self.display['nodes'][0]['frame'] = 3
        self.golden = nodes.normalize_reference(self.display)
        self.golden['frame'] = 541
        self.replay_display = json.loads(json.dumps(self.display))
        self.replay_display['nodes'][0]['frame'] = 4
        self.write_meta()
        with self.assertRaisesRegex(SystemExit, 'frame 4 != 3'):
            compare.record('main-menu', self.player, self.swf, reference_only=True)

    def test_hidden_reference_node_absent_is_accepted(self):
        # Like check, verification refuses only nodes.diff's missing/extra/off: a hidden
        # golden node the replay does not build is not missing.
        self.display['nodes'].append(ref_node('/root1/hidden', visible=False))
        self.golden = nodes.normalize_reference(self.display)
        self.golden['frame'] = 541
        self.replay_display = {'schema': self.display['schema'], 'truncated': False, 'stage': {},
                               'nodes': [self.display['nodes'][0]]}
        self.write_meta()
        with contextlib.redirect_stdout(io.StringIO()):
            compare.record('main-menu', self.player, self.swf, reference_only=True)
        self.assertTrue((self.work / 'main-menu' / 'reference' / 'reference.json').is_file())

    def test_scene_problems_work_fallback_and_missing_frame(self):
        # No `out` on the replay: the fallback is WORK/<name>/reference (this used to be a
        # NameError), and a capture absent from the replayed frames is a clean error.
        self.write_meta()
        out = self.work / 'main-menu' / 'reference'
        out.mkdir(parents=True)
        (out / 'menu.display.json').write_text(json.dumps(self.display), encoding='utf-8')
        case = json.loads(self.case_path.read_text(encoding='utf-8'))
        golden = self.goldens / 'main-menu' / 'menu.json'
        self.assertEqual(compare._scene_problems(case, 'main-menu', golden, 'menu', {'frames': {'menu': 541}}), [])
        self.assertEqual(compare._scene_problems(case, 'main-menu', golden, 'menu', {'frames': {}}),
                         ['capture menu has no replayed frame'])

    def test_failed_verify_keeps_existing_reference(self):
        self.write_meta(frames={'menu': 540})
        out = self.seed_reference()
        before = (out / 'menu.png').read_bytes()
        with self.assertRaises(SystemExit):
            compare.record('main-menu', self.player, self.swf, reference_only=True)
        self.assertEqual((out / 'menu.png').read_bytes(), before)
        self.assertTrue((out / 'reference.json').is_file())
        self.assertFalse((self.work / 'main-menu' / 'reference.tmp').exists())

    def test_scene_mismatch_keeps_existing_reference(self):
        self.write_meta()
        out = self.seed_reference()
        before = (out / 'menu.png').read_bytes()
        self.display['nodes'][0]['stage_matrix'][5] = 60.0
        with self.assertRaisesRegex(SystemExit, 'scene differs'):
            compare.record('main-menu', self.player, self.swf, reference_only=True)
        self.assertEqual((out / 'menu.png').read_bytes(), before)
        self.assertTrue((out / 'reference.json').is_file())
        self.assertFalse((self.work / 'main-menu' / 'reference.tmp').exists())

    def test_different_player_with_matching_scene_is_accepted(self):
        self.write_meta(player_sha256='0' * 64)
        with contextlib.redirect_stdout(io.StringIO()) as printed:
            compare.record('main-menu', self.player, self.swf, reference_only=True)
        self.assertIn('scene matches, accepting', printed.getvalue())
        self.assertTrue((self.work / 'main-menu' / 'reference' / 'reference.json').is_file())

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
        provenance = json.loads((out / 'reference.json').read_text(encoding='utf-8'))
        self.assertEqual(provenance['golden_sha256'], {'menu': compare.sha256(target / 'menu.json')})


class CheckReferenceProvenance(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.root = Path(self.dir.name)
        self.goldens = self.root / 'goldens'
        self.work = self.root / 'work'
        self.cases = self.root / 'cases'
        self.cases.mkdir()
        self.case_path = self.cases / 'main-menu.json'
        self.case_path.write_text(json.dumps({'name': 'main-menu', 'actions': [{'capture': 'menu'}]}),
                                  encoding='utf-8')
        target = self.goldens / 'main-menu'
        target.mkdir(parents=True)
        self.golden_path = target / 'menu.json'
        self.golden_path.write_text(json.dumps({'schema': 'bombit5-golden-nodes-v1',
                                                'nodes': [ref_node('/root1/menu', 10, 20, frame=541)]},
                                               indent=1) + '\n', encoding='utf-8')
        self.meta = {'case': 'main-menu', 'case_sha256': compare.reference_sha256(self.case_path),
                     'swf_sha256': 'a' * 64, 'player_sha256': '0' * 64, 'fps': 35.0,
                     'frames': {'menu': 541}}
        (target / 'meta.json').write_text(json.dumps(self.meta), encoding='utf-8')
        self.reference = self.work / 'main-menu' / 'reference'
        self.reference.mkdir(parents=True)
        (self.reference / 'menu.png').write_bytes(b'local reference PNG')
        self.provenance = {'case_sha256': self.meta['case_sha256'], 'swf_sha256': self.meta['swf_sha256'],
                           'player_sha256': self.meta['player_sha256'], 'frames': {'menu': 541},
                           'golden_sha256': {'menu': compare.sha256(self.golden_path)}}
        self.godot = self.work / 'main-menu' / 'godot'
        self.godot.mkdir(parents=True)
        (self.godot / 'menu.nodes.json').write_text(json.dumps(
            {'schema': 'bombit5-godot-nodes-v1', 'nodes': [ref_node('/root1/menu', 10, 20, frame=541)]}),
            encoding='utf-8')
        (self.godot / 'menu.png').write_bytes(b'godot PNG')
        for patch in (mock.patch.object(compare, 'ROOT', self.root),
                      mock.patch.object(compare, 'GOLDENS', self.goldens),
                      mock.patch.object(compare, 'WORK', self.work),
                      mock.patch.object(compare, 'CASES', self.cases),
                      mock.patch.object(compare, 'run_godot', return_value=self.godot)):
            patch.start()
            self.addCleanup(patch.stop)

    def tearDown(self):
        self.dir.cleanup()

    def write_provenance(self, **changes):
        (self.reference / 'reference.json').write_text(json.dumps(dict(self.provenance, **changes)),
                                                       encoding='utf-8')

    def assert_pixels_skipped(self):
        with contextlib.redirect_stdout(io.StringIO()):
            report = compare.check('main-menu', 'godot')
        pixel = report['captures']['menu']['pixel']
        self.assertEqual(pixel['skipped'], 'local reference is stale or unverified: re-run record --reference-only')
        self.assertIsNone(pixel['passed'])
        self.assertTrue(report['passed'])
        return report

    def test_missing_provenance_skips_pixels(self):
        self.assert_pixels_skipped()

    def test_missing_provenance_prints_the_reason(self):
        with contextlib.redirect_stdout(io.StringIO()) as printed:
            compare.check('main-menu', 'godot')
        self.assertIn('why: reference.json is missing', printed.getvalue())

    def test_stale_frames_skip_pixels(self):
        self.write_provenance(frames={'menu': 540})
        self.assert_pixels_skipped()

    def test_changed_golden_skips_pixels(self):
        self.write_provenance()
        document = json.loads(self.golden_path.read_text(encoding='utf-8'))
        self.golden_path.write_text(json.dumps(document, indent=2) + '\n', encoding='utf-8')
        self.assert_pixels_skipped()

    def test_valid_provenance_scores_pixels(self):
        self.write_provenance()
        with mock.patch.object(compare.pixels, 'compare',
                               return_value={'passed': True, 'ssim': 1.0, 'max_region_delta_e': 0.0,
                                             'thresholds': dict(pixels.DEFAULT_THRESHOLDS)}), \
                contextlib.redirect_stdout(io.StringIO()):
            report = compare.check('main-menu', 'godot')
        pixel = report['captures']['menu']['pixel']
        self.assertNotIn('skipped', pixel)
        self.assertTrue(pixel['passed'])
        self.assertTrue(report['passed'])


class ResamplingCeilingNote(unittest.TestCase):
    """The 3×→1× ceiling must say when its 3× image came from another player build."""

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.root = Path(self.dir.name)
        self.work = self.root / 'work'
        self.goldens = self.root / 'goldens'
        self.cases = self.root / 'cases'
        self.cases.mkdir()
        screen = self.root / 'original' / 'screens' / 'menu'
        screen.mkdir(parents=True)
        self.big = screen / 'reference-3x-main-menu-menu.png'
        Image.new('RGB', (2100, 1530), (10, 20, 30)).save(self.big)
        self.reference_png = self.work / 'main-menu' / 'reference' / 'menu.png'
        self.reference_png.parent.mkdir(parents=True)
        Image.new('RGB', (700, 510), (10, 20, 30)).save(self.reference_png)
        (self.goldens / 'main-menu').mkdir(parents=True)
        (self.goldens / 'main-menu' / 'menu.json').write_text(
            json.dumps({'schema': 'bombit5-golden-nodes-v1', 'nodes': []}), encoding='utf-8')
        for patch in (mock.patch.object(compare, 'ROOT', self.root),
                      mock.patch.object(compare, 'WORK', self.work),
                      mock.patch.object(compare, 'GOLDENS', self.goldens),
                      mock.patch.object(compare, 'CASES', self.cases)):
            patch.start()
            self.addCleanup(patch.stop)

    def tearDown(self):
        self.dir.cleanup()

    def write_players(self, rendered_by, reference_by):
        (self.work / 'main-menu' / 'reference' / 'reference.json').write_text(
            json.dumps({'player_sha256': reference_by}), encoding='utf-8')
        (self.big.parent / 'reference-3x.json').write_text(json.dumps(
            {'schema': 'bombit5-reference-3x-v1',
             'images': {self.big.name: {'case': 'main-menu', 'capture': 'menu',
                                        'player_sha256': rendered_by}}}), encoding='utf-8')

    def test_note_when_3x_and_reference_players_differ(self):
        self.write_players('b' * 64, 'a' * 64)
        with contextlib.redirect_stdout(io.StringIO()) as printed:
            ceiling = compare.resampling_ceiling('main-menu', 'menu', self.reference_png)
        self.assertIsNotNone(ceiling)
        self.assertIn(self.big.name, printed.getvalue())
        self.assertIn('different player builds', printed.getvalue())

    def test_no_note_when_3x_and_reference_players_match(self):
        self.write_players('a' * 64, 'a' * 64)
        with contextlib.redirect_stdout(io.StringIO()) as printed:
            ceiling = compare.resampling_ceiling('main-menu', 'menu', self.reference_png)
        self.assertIsNotNone(ceiling)
        self.assertNotIn('different player builds', printed.getvalue())

    def test_note_when_3x_image_has_no_recorded_player(self):
        # A 3× image recorded before `reference-3x.json` exists: its player is unknown, so the
        # ceiling may compare builds.
        with contextlib.redirect_stdout(io.StringIO()) as printed:
            ceiling = compare.resampling_ceiling('main-menu', 'menu', self.reference_png)
        self.assertIsNotNone(ceiling)
        self.assertIn(self.big.name, printed.getvalue())
        self.assertIn('3x ceiling image has no recorded player; it may compare builds', printed.getvalue())

    def test_note_when_3x_image_is_missing_from_its_manifest(self):
        self.write_players('b' * 64, 'a' * 64)
        (self.big.parent / 'reference-3x.json').write_text(json.dumps(
            {'schema': 'bombit5-reference-3x-v1', 'images': {}}), encoding='utf-8')
        with contextlib.redirect_stdout(io.StringIO()) as printed:
            ceiling = compare.resampling_ceiling('main-menu', 'menu', self.reference_png)
        self.assertIsNotNone(ceiling)
        self.assertIn('3x ceiling image has no recorded player; it may compare builds', printed.getvalue())


if __name__ == '__main__':
    unittest.main()
