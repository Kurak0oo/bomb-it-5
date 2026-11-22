"""Unit tests for record_screen.py's 3× manifest and FFDec effect fallback (no SWF or player)."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

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


if __name__ == '__main__':
    unittest.main()
