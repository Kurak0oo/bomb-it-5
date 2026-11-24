"""Unit tests for record_screen.py's 3× manifest and FFDec effect fallback (no SWF or player)."""
import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

from PIL import Image

import record_screen

SWF = 'a' * 64
GOLDEN = 'b' * 64


class Reference3xManifest(unittest.TestCase):
    """`record_reference_3x`: keep every image's entry, fail on a corrupt manifest, write atomically."""

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.target = Path(self.dir.name)
        self.player = self.target / 'probe'
        self.player.write_bytes(b'stub player')
        self.addCleanup(self.dir.cleanup)

    def read_manifest(self):
        return json.loads((self.target / record_screen.REFERENCE_3X).read_text(encoding='utf-8'))

    def test_updates_only_its_entry_and_keeps_the_others(self):
        record_screen.record_reference_3x(self.target, 'main-menu', 'menu', self.player, 'menu.png')
        record_screen.record_reference_3x(self.target, 'main-menu', 'settings', self.player, 'settings.png')
        images = self.read_manifest()['images']
        self.assertEqual(set(images), {'menu.png', 'settings.png'})
        self.assertEqual(images['menu.png'],
                         {'case': 'main-menu', 'capture': 'menu',
                          'player_sha256': record_screen.sha256(self.player)})
        self.assertEqual(images['settings.png']['capture'], 'settings')

    def test_corrupt_manifest_fails_without_overwriting_it(self):
        path = self.target / record_screen.REFERENCE_3X
        path.write_text('{not json', encoding='utf-8')
        with self.assertRaises(SystemExit) as raised:
            record_screen.record_reference_3x(self.target, 'main-menu', 'menu', self.player, 'menu.png')
        self.assertIn(record_screen.REFERENCE_3X, str(raised.exception))
        self.assertEqual(path.read_text(encoding='utf-8'), '{not json')

    def test_write_failure_leaves_the_previous_manifest_and_no_temp_file(self):
        record_screen.record_reference_3x(self.target, 'main-menu', 'menu', self.player, 'menu.png')
        before = (self.target / record_screen.REFERENCE_3X).read_text(encoding='utf-8')
        with mock.patch.object(record_screen.os, 'replace', side_effect=OSError('disk full')):
            with self.assertRaises(OSError):
                record_screen.record_reference_3x(self.target, 'main-menu', 'other', self.player, 'other.png')
        self.assertEqual((self.target / record_screen.REFERENCE_3X).read_text(encoding='utf-8'), before)
        self.assertEqual(list(self.target.glob(f'.{record_screen.REFERENCE_3X}.*')), [])


class EffectsFallback(unittest.TestCase):
    """`_record_effects_or_keep`: keep recorded effect art only when it still matches."""

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.target = Path(self.dir.name)
        self.swf = self.target / 'game.swf'
        self.swf.write_bytes(b'stub swf')
        self.frame = self.target / 'effects' / 'fallSnow-1.png'
        self.frame.parent.mkdir()
        self.frame.write_bytes(b'stub frame')
        self.addCleanup(self.dir.cleanup)

    def layout(self, art_class='fallSnow', bitmap_size=(25, 25)):
        return {'screen': 'game-win',
                'effects': {'FallSnow': {'art_class': art_class, 'bitmap_size': list(bitmap_size)}}}

    def manifest(self, swf=SWF, golden=GOLDEN):
        return {'swf_sha256': swf, 'golden_sha256': golden}

    def recorded(self, art_class='fallSnow', bitmap_size=(25, 25), frames=('effects/fallSnow-1.png',)):
        return {'FallSnow': {'art_class': art_class, 'character_id': 7,
                             'bitmap_size': list(bitmap_size), 'frames': list(frames)}}

    def write_old(self, old):
        path = self.target / 'manifest.json'
        if old is None:
            path.unlink(missing_ok=True)
        else:
            path.write_text(json.dumps(old), encoding='utf-8')

    def fallback_fails(self, old, manifest, needle):
        self.write_old(old)
        with mock.patch.object(record_screen, '_ffdec_missing', return_value='FFDec is not cached'):
            with self.assertRaises(SystemExit) as raised:
                record_screen._record_effects_or_keep(self.layout(), self.target, self.swf, manifest)
        self.assertIn(needle, str(raised.exception))

    def test_unavailable_ffdec_keeps_matching_recorded_effects(self):
        self.write_old({'swf_sha256': SWF, 'golden_sha256': GOLDEN, 'effects': self.recorded()})
        with mock.patch.object(record_screen, '_ffdec_missing', return_value='Java is not on PATH'):
            with contextlib.redirect_stdout(io.StringIO()) as printed:
                kept = record_screen._record_effects_or_keep(self.layout(), self.target, self.swf, self.manifest())
        self.assertEqual(kept, self.recorded())
        self.assertIn('keeping the recorded effect art', printed.getvalue())
        self.assertTrue(self.frame.is_file())

    def test_fallback_fails_on_a_different_swf(self):
        self.fallback_fails({'swf_sha256': 'c' * 64, 'golden_sha256': GOLDEN, 'effects': self.recorded()},
                            self.manifest(), 'different SWF')

    def test_fallback_fails_on_a_different_golden(self):
        self.fallback_fails({'swf_sha256': SWF, 'golden_sha256': 'c' * 64, 'effects': self.recorded()},
                            self.manifest(), 'different golden capture')

    def test_fallback_fails_on_a_different_art_class(self):
        self.fallback_fails({'swf_sha256': SWF, 'golden_sha256': GOLDEN,
                             'effects': self.recorded(art_class='otherSnow')},
                            self.manifest(), 'art class')

    def test_fallback_fails_on_a_different_bitmap_size(self):
        self.fallback_fails({'swf_sha256': SWF, 'golden_sha256': GOLDEN,
                             'effects': self.recorded(bitmap_size=(26, 25))},
                            self.manifest(), 'bitmap size')

    def test_fallback_fails_when_a_recorded_frame_is_missing(self):
        self.frame.unlink()
        self.fallback_fails({'swf_sha256': SWF, 'golden_sha256': GOLDEN,
                             'effects': self.recorded(frames=('effects/gone.png',))},
                            self.manifest(), 'missing effects/gone.png')

    def test_fallback_fails_without_an_old_manifest(self):
        self.fallback_fails(None, self.manifest(), 'no recorded effects')

    def test_fallback_fails_on_an_unreadable_old_manifest(self):
        (self.target / 'manifest.json').write_text('{not json', encoding='utf-8')
        with self.assertRaises(SystemExit) as raised:
            record_screen._record_effects_or_keep(self.layout(), self.target, self.swf, self.manifest())
        self.assertIn('unreadable', str(raised.exception))


class FfdecAvailability(unittest.TestCase):
    """The pre-check: a cached jar and Java, or the recorded-art fallback (no download)."""

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.root = Path(self.dir.name)
        self.addCleanup(self.dir.cleanup)

    def test_jar_not_cached(self):
        with mock.patch.object(record_screen, 'ROOT', self.root):
            self.assertIn('not cached', record_screen._ffdec_missing())

    def write_jar(self):
        jar = self.root / '.scratch' / 'tools' / 'ffdec' / 'ffdec.jar'
        jar.parent.mkdir(parents=True)
        jar.write_bytes(b'stub jar')

    def test_java_missing(self):
        self.write_jar()
        with mock.patch.object(record_screen, 'ROOT', self.root), \
                mock.patch.object(record_screen.shutil, 'which', return_value=None):
            self.assertIn('Java is not on PATH', record_screen._ffdec_missing())

    def test_ready_when_jar_and_java_are_present(self):
        self.write_jar()
        with mock.patch.object(record_screen, 'ROOT', self.root), \
                mock.patch.object(record_screen.shutil, 'which', return_value='/usr/bin/java'):
            self.assertIsNone(record_screen._ffdec_missing())

    def test_download_allowed_for_an_uncached_jar_when_java_is_present(self):
        with mock.patch.object(record_screen, 'ROOT', self.root), \
                mock.patch.object(record_screen.shutil, 'which', return_value='/usr/bin/java'):
            self.assertIsNone(record_screen._ffdec_missing(download=True))

    def test_no_download_for_an_uncached_jar_without_java(self):
        with mock.patch.object(record_screen, 'ROOT', self.root), \
                mock.patch.object(record_screen.shutil, 'which', return_value=None):
            self.assertIn('not cached', record_screen._ffdec_missing(download=True))


class EffectsRendering(unittest.TestCase):
    """`_record_effects_or_keep`: only the missing-symbol case falls back, and an uncached
    jar is downloaded when Java is present (a failed download keeps the recorded art)."""

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.target = Path(self.dir.name)
        self.swf = self.target / 'game.swf'
        self.swf.write_bytes(b'stub swf')
        frame = self.target / 'effects' / 'fallSnow-1.png'
        frame.parent.mkdir()
        frame.write_bytes(b'stub frame')
        self.layout = {'screen': 'game-win',
                       'effects': {'FallSnow': {'art_class': 'fallSnow', 'bitmap_size': [25, 25]}}}
        self.manifest = {'swf_sha256': SWF, 'golden_sha256': GOLDEN}
        self.recorded = {'FallSnow': {'art_class': 'fallSnow', 'character_id': 7,
                                      'bitmap_size': [25, 25], 'frames': ['effects/fallSnow-1.png']}}
        (self.target / 'manifest.json').write_text(json.dumps(
            {'swf_sha256': SWF, 'golden_sha256': GOLDEN, 'effects': self.recorded}), encoding='utf-8')
        self.addCleanup(self.dir.cleanup)

    def run_effects(self, render):
        with mock.patch.object(record_screen, '_ffdec_missing', return_value=None), \
                mock.patch.object(record_screen, '_record_screen_effects', side_effect=render):
            with contextlib.redirect_stdout(io.StringIO()) as printed:
                kept = record_screen._record_effects_or_keep(self.layout, self.target, self.swf, self.manifest)
        return kept, printed.getvalue()

    def test_renders_instead_of_keeping_when_ffdec_can_download(self):
        with mock.patch.object(record_screen, '_ffdec_missing', return_value=None) as missing, \
                mock.patch.object(record_screen, '_record_screen_effects', return_value={'FallSnow': 'new'}) as render:
            kept = record_screen._record_effects_or_keep(self.layout, self.target, self.swf, self.manifest)
        self.assertEqual(kept, {'FallSnow': 'new'})
        missing.assert_called_once_with(download=True)
        render.assert_called_once()

    def test_failed_download_keeps_matching_recorded_effects(self):
        kept, printed = self.run_effects(record_screen.EffectsUnavailable('FFDec is unavailable: offline'))
        self.assertEqual(kept, self.recorded)
        self.assertIn('keeping the recorded effect art', printed)

    def test_a_missing_effect_symbol_keeps_matching_recorded_effects(self):
        kept, printed = self.run_effects(record_screen.EffectSymbolMissing('FallSnow is not a symbol'))
        self.assertEqual(kept, self.recorded)
        self.assertIn('keeping the recorded effect art', printed)

    def test_other_lookup_errors_propagate(self):
        with self.assertRaises(LookupError) as raised:
            self.run_effects(LookupError('a localized font is missing'))
        self.assertNotIsInstance(raised.exception, record_screen.EffectSymbolMissing)

    def test_ensure_ffdec_download_failure_is_effects_unavailable(self):
        bakeoff = mock.Mock()
        bakeoff.ensure_ffdec.side_effect = OSError('network is down')
        with mock.patch.dict(sys.modules, {'bakeoff': bakeoff}):
            with self.assertRaises(record_screen.EffectsUnavailable) as raised:
                record_screen._ensure_ffdec()
        self.assertIn('network is down', str(raised.exception))

    def test_a_non_swf_does_not_trigger_a_download(self):
        bakeoff = mock.Mock()
        with mock.patch.object(record_screen, 'ROOT', self.target), \
                mock.patch.dict(sys.modules, {'bakeoff': bakeoff}):
            with self.assertRaises(record_screen.EffectsUnavailable):
                record_screen._ensure_ffdec(self.swf)
        bakeoff.ensure_ffdec.assert_not_called()


class FrontHatMath(unittest.TestCase):
    """`_affine_compose`, `_front_hat_pixels` and `_compose_front_hat` with known matrices."""

    def test_affine_compose_multiplies_in_display_list_order(self):
        # p * q: q's translation goes through p's linear part first.
        self.assertEqual(record_screen._affine_compose([2, 0, 0, 3, 10, 20], [1, 0, 0, 1, 5, 7]),
                         [2, 0, 0, 3, 20, 41])
        self.assertEqual(record_screen._affine_compose([1, 0, 0, 1, 5, 7], [2, 0, 0, 3, 10, 20]),
                         [2, 0, 0, 3, 15, 27])

    def test_front_hat_pixels_converts_origins_and_scale(self):
        identity = [1, 0, 0, 1, 0, 0]
        self.assertEqual(record_screen._front_hat_pixels(identity, identity, [4, 6], [10, 20]),
                         [1, 0, 0, 1, -6, -14])
        # A 2x Down head over an unscaled front head: the hat scales by 2, the stage SCALE
        # (3) enters only in the offsets.
        self.assertEqual(record_screen._front_hat_pixels([2, 0, 0, 2, 0, 0], identity, [4, 6], [10, 20]),
                         [2, 0, 0, 2, -2, -8])

    def test_compose_places_the_hat_and_keeps_alpha(self):
        body = Image.new('RGBA', (4, 4), (255, 0, 0, 255))
        hat = Image.new('RGBA', (2, 2), (0, 0, 255, 255))
        composed, left, top = record_screen._compose_front_hat(body, hat, [1, 0, 0, 1, 0, 0])
        self.assertEqual((left, top), (0, 0))
        self.assertEqual(composed.size, (4, 4))
        self.assertEqual(composed.getpixel((0, 0)), (0, 0, 255, 255))
        self.assertEqual(composed.getpixel((3, 3)), (255, 0, 0, 255))
        faded = Image.new('RGBA', (2, 2), (0, 0, 255, 128))
        blended, _, _ = record_screen._compose_front_hat(body, faded, [1, 0, 0, 1, 0, 0])
        self.assertEqual(blended.getpixel((0, 0))[3], 255)
        self.assertTrue(100 < blended.getpixel((0, 0))[0] < 155)
        self.assertTrue(100 < blended.getpixel((0, 0))[2] < 155)

    def test_compose_grows_the_canvas_for_a_negative_offset(self):
        body = Image.new('RGBA', (4, 4), (255, 0, 0, 255))
        hat = Image.new('RGBA', (2, 2), (0, 0, 255, 255))
        composed, left, top = record_screen._compose_front_hat(body, hat, [1, 0, 0, 1, -2, -1])
        self.assertEqual((left, top), (-2, -1))
        self.assertEqual(composed.size, (6, 5))
        self.assertEqual(composed.getpixel((0, 0)), (0, 0, 255, 255))
        self.assertEqual(composed.getpixel((2, 1)), (255, 0, 0, 255))
        self.assertEqual(composed.getpixel((5, 4)), (255, 0, 0, 255))
        self.assertEqual(composed.getpixel((0, 4))[3], 0)


class FrontHatPlayer:
    """The commands `_record_front_hat_down` sends, with one synthetic hat frame."""

    def __init__(self, tmp, clipped=False):
        self.tmp = tmp
        self.clipped = clipped
        self.commands = []

    def command(self, line):
        self.commands.append(line)

    def display(self):
        identity = [1, 0, 0, 1, 0, 0]
        return {'nodes': [{'path': record_screen.FRONT_HEAD_PATH, 'stage_matrix': identity},
                          {'path': record_screen.FRONT_HAT_PATH, 'stage_matrix': identity},
                          {'path': '/root1/r/@46', 'stage_matrix': identity}]}

    def piece(self, path, target, frame=None):
        hat = Image.new('RGBA', (6, 6), (0, 0, 0, 0))
        hat.paste(Image.new('RGBA', (3, 3), (0, 0, 255, 255)), (0, 0))
        hat.save(target)
        return {'path': path, 'pixel_origin': [12, 12], 'pixel_size': [6, 6], 'scale': 3,
                'render_bounds': [4.0, 4.0, 5.0, 5.0], 'clipped_by_viewport': self.clipped}


class FrontHatDown(unittest.TestCase):
    """Owner edit: the front hat is composed onto the body looks the pass actually recorded."""

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.target = Path(self.dir.name)
        self.tmp = self.target / 'tmp'
        self.tmp.mkdir()
        self.addCleanup(self.dir.cleanup)

    def body_look(self, cloth):
        Image.new('RGBA', (6, 6), (255, 0, 0, 255)).save(self.target / f'body-{cloth}.png')
        return {'file': f'body-{cloth}.png', 'pixel_origin': [0, 0], 'pixel_size': [6, 6],
                'scale': 3, 'render_bounds': [0.0, 0.0, 2.0, 2.0]}

    def sparse_entry(self):
        # Round mode leaves only some body looks (here 0 and 2 of 4) in the clip entry.
        return {'frames': 1, 'body_frames': 4, 'hat_frames': 0,
                'looks': {'0|-1': {'1': self.body_look(0)}, '2|-1': {'1': self.body_look(2)}}}

    def record(self, entry, clipped=False):
        out = {'robots': {'_r0_Down': entry}}
        record_screen._record_front_hat_down(FrontHatPlayer(self.tmp, clipped), self.target, self.tmp, {}, out)
        return out['robots']['_r0_Down']

    def test_composes_only_the_recorded_body_looks(self):
        edited = self.record(self.sparse_entry())
        self.assertTrue(edited['hat'])
        self.assertEqual(edited['hat_frames'], 4)
        self.assertEqual(edited['body_frames'], 4)
        self.assertEqual(set(edited['looks']),
                         {'0|0', '0|1', '0|2', '0|3', '2|0', '2|1', '2|2', '2|3'})

    def test_composed_bounds_are_the_content_union_not_the_crop(self):
        edited = self.record(self.sparse_entry())
        meta = edited['looks']['0|1']['1']
        # Body content [0,0,2,2] plus the hat's content [4,4,5,5]; the crop reaches 6.
        self.assertEqual(meta['render_bounds'], [0.0, 0.0, 5.0, 5.0])
        self.assertEqual(meta['pixel_size'], [18, 18])

    def test_fails_when_the_hat_render_is_clipped(self):
        with self.assertRaises(RuntimeError) as raised:
            self.record(self.sparse_entry(), clipped=True)
        self.assertIn('clipped by the viewport', str(raised.exception))


if __name__ == '__main__':
    unittest.main()


class TipArt(unittest.TestCase):
    """`_tip_piece`: the tip clip's SWF-rendered metadata and stage matrix."""

    def test_piece_carries_its_stage_matrix_and_frame(self):
        meta = {'pixel_origin': [10, 20], 'pixel_size': [30, 40], 'scale': 3.0,
                'render_bounds': [1, 2, 11, 22]}
        piece = record_screen._tip_piece(meta, [0.45, 0, 0, 0.45, 100, 200], 4)
        self.assertEqual(piece['at'], [0.45, 0, 0, 0.45, 100, 200])
        self.assertEqual(piece['frame'], 4)
        self.assertEqual(piece['pixel_origin'], [10, 20])

    def test_head_and_preview_paths_are_the_generated_tip_paths(self):
        self.assertEqual(record_screen.TIP_PREVIEW % 3,
                         '/root1/__mainMc/GameMc/@0/@0/@0/containerMc/robotStage/robotMc/robot3')
        self.assertEqual(record_screen.TIP_HEAD,
                         '/root1/__mainMc/GameMc/@0/@0/@0/containerMc/robotBtn1/robotHeadMc')
        self.assertEqual(record_screen.SCORE_HEAD,
                         '/root1/__mainMc/GameMc/@0/@0/p1head')
