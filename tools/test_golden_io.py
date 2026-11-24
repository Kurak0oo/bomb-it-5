"""Unit checks for tools/golden_io.py: python3 -m unittest tools/test_golden_io.py"""
import gzip
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import golden_io  # noqa: E402


class GoldenIo(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_capture_round_trips_compressed_and_reproducibly(self):
        path = self.dir / 'case' / 'menu.json'
        golden_io.dump({'nodes': [{'path': '/a'}]}, path)
        packed = path.with_name('menu.json.gz')
        self.assertTrue(packed.is_file())
        self.assertFalse(path.exists())
        first = packed.read_bytes()
        golden_io.dump({'nodes': [{'path': '/a'}]}, path)
        self.assertEqual(first, packed.read_bytes(), 'same content must give the same bytes')
        self.assertEqual(golden_io.load(path), {'nodes': [{'path': '/a'}]})

    def test_bookkeeping_files_stay_plain(self):
        for name in ('meta.json', 'floor.json', 'math_random.json', 'menu.states.json'):
            golden_io.dump({'x': 1}, self.dir / name)
            self.assertTrue((self.dir / name).is_file(), name)
            self.assertFalse((self.dir / (name + '.gz')).exists(), name)

    def test_hash_is_of_the_plain_text(self):
        text = json.dumps({'nodes': []}, indent=1) + '\n'
        plain = self.dir / 'a.json'
        plain.write_text(text, encoding='utf-8')
        before = golden_io.sha256(plain)
        golden_io.pack(self.dir)
        self.assertFalse(plain.exists())
        self.assertEqual(before, golden_io.sha256(plain))
        self.assertEqual(gzip.decompress(plain.with_name('a.json.gz').read_bytes()).decode(), text)

    def test_plain_file_still_reads(self):
        plain = self.dir / 'old.json'
        plain.write_text('{"nodes": [1]}', encoding='utf-8')
        self.assertTrue(golden_io.exists(plain))
        self.assertEqual(golden_io.load(plain), {'nodes': [1]})

    def test_verify_flags_a_plain_copy_beside_a_packed_one(self):
        golden_io.dump({'a': 1}, self.dir / 'x.json')
        (self.dir / 'x.json').write_text('{}', encoding='utf-8')
        self.assertTrue(golden_io.verify(self.dir))


if __name__ == '__main__':
    unittest.main()
