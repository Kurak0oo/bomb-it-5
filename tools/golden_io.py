"""Read and write committed goldens (tests/goldens), which are stored gzip-compressed.

Callers keep using the logical name (`<capture>.json`, `<capture>.timeline.json`); on disk
the large files are `<name>.gz`, written byte-for-byte reproducibly (gzip level 9, mtime 0).
Small bookkeeping files (meta.json, floor.json, math_random.json, *.states.json) stay plain.
Reading accepts either form, so a plain file left by an older tool still loads.

Hashes (`sha256`) are of the decompressed JSON text, so a golden's hash does not change when
it is compressed and provenance recorded against the plain files stays valid.

    python3 tools/golden_io.py pack [DIR]     compress every large plain golden under DIR
    python3 tools/golden_io.py verify [DIR]   check every .gz decompresses to valid JSON
"""
import gzip
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
GOLDENS = ROOT / 'tests' / 'goldens'
PLAIN_NAMES = {'meta.json', 'floor.json', 'math_random.json'}


def is_packed_name(name):
    """Whether a golden with this logical file name is stored compressed."""
    name = Path(name).name
    return name.endswith('.json') and name not in PLAIN_NAMES and not name.endswith('.states.json')


def _gz(path):
    path = Path(path)
    return path.with_name(path.name + '.gz')


def resolve(path):
    """The file on disk for a logical golden path (the .gz when there is no plain file)."""
    path = Path(path)
    if path.is_file():
        return path
    return _gz(path)


def exists(path):
    return Path(path).is_file() or _gz(path).is_file()


def read_bytes(path):
    path = Path(path)
    if path.is_file():
        return path.read_bytes()
    return gzip.decompress(_gz(path).read_bytes())


def read_text(path):
    return read_bytes(path).decode('utf-8')


def load(path):
    return json.loads(read_text(path))


def write_text(path, text):
    """Write a golden under its logical path: compressed when its name says so."""
    path = Path(path)
    data = text.encode('utf-8')
    path.parent.mkdir(parents=True, exist_ok=True)
    if is_packed_name(path.name):
        _gz(path).write_bytes(gzip.compress(data, compresslevel=9, mtime=0))
        if path.is_file():
            path.unlink()
    else:
        path.write_bytes(data)
        if _gz(path).is_file():
            _gz(path).unlink()


def dump(obj, path):
    write_text(path, json.dumps(obj, indent=1, sort_keys=True) + '\n')


def sha256(path):
    return hashlib.sha256(read_bytes(path)).hexdigest()


def pack(directory=GOLDENS):
    """Compress every plain golden that should be stored compressed; returns (count, before, after)."""
    count = before = after = 0
    for plain in sorted(Path(directory).rglob('*.json')):
        if not is_packed_name(plain.name):
            continue
        text = plain.read_text(encoding='utf-8')
        before += len(text.encode('utf-8'))
        write_text(plain, text)
        after += _gz(plain).stat().st_size
        count += 1
    return count, before, after


def verify(directory=GOLDENS):
    problems = []
    for packed in sorted(Path(directory).rglob('*.json.gz')):
        try:
            json.loads(gzip.decompress(packed.read_bytes()).decode('utf-8'))
        except Exception as error:  # noqa: BLE001 - report every broken file
            problems.append(f'{packed}: {error}')
        if packed.with_suffix('').is_file():
            problems.append(f'{packed}: a plain copy exists next to it')
    return problems


def main(argv):
    if len(argv) < 2 or argv[1] not in ('pack', 'verify'):
        raise SystemExit(__doc__)
    directory = Path(argv[2]) if len(argv) > 2 else GOLDENS
    if argv[1] == 'pack':
        count, before, after = pack(directory)
        print(f'packed {count} golden(s): {before / 1e6:.1f} MB -> {after / 1e6:.1f} MB')
        return
    problems = verify(directory)
    for problem in problems:
        print(problem)
    print('OK' if not problems else f'{len(problems)} problem(s)')
    sys.exit(1 if problems else 0)


if __name__ == '__main__':
    main(sys.argv)
