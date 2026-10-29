"""Build the original replica's ignored audio pack from the user's own SWF (#75).

    python tools/art_pipeline/original_audio.py [--swf PATH]

Exports every DefineSound with FFDec and copies the class-linked ones, unmodified, to
original/audio/<Class>.mp3, with original/audio/index.json listing them. The game plays
them by class name (scripts/original_audio.gd); without the pack it stays silent. The
folder is ignored by git and must never be committed. Sounds placed only on timelines
(the publisher intro `Art_A10`) have no class and are not copied.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from common import ROOT, SCRATCH, load_config, log, setup_logging, write_json
from extract import ensure_ffdec, ensure_java, locate_swf

PACK = ROOT / 'original' / 'audio'
EXPORT = SCRATCH / 'sound-export'
# FFDec names class-linked sounds `<character>_<export>_<class>.mp3`; here both names agree.
LINKED = re.compile(r'^(\d+)_(\w+)_\2\.(mp3|wav)$')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--swf', help='SWF to use; copied to the canonical .scratch path')
    args = parser.parse_args(argv)
    setup_logging()
    swf, digest = locate_swf(args.swf)
    java = ensure_java()
    if not java:
        log.error('Java is required to export sounds')
        return 1
    jar = ensure_ffdec(load_config())
    shutil.rmtree(EXPORT, ignore_errors=True)
    EXPORT.mkdir(parents=True)
    result = subprocess.run([java, '-jar', str(jar), '-format', 'sound:mp3_wav', '-export', 'sound', str(EXPORT), str(swf)],
                            capture_output=True, text=True)
    if result.returncode != 0:
        log.error('FFDec sound export failed: %s', result.stdout[-2000:] + result.stderr[-2000:])
        return 1
    shutil.rmtree(PACK, ignore_errors=True)
    PACK.mkdir(parents=True)
    sounds = {}
    for path in sorted(EXPORT.iterdir()):
        match = LINKED.match(path.name)
        if not match:
            continue
        name = match.group(2)
        target = PACK / f'{name}.{match.group(3)}'
        shutil.copyfile(path, target)
        sounds[name] = {'file': target.name, 'character': int(match.group(1))}
    write_json(PACK / 'index.json', {'swf_sha256': digest, 'sounds': sounds})
    log.info('Original audio: %d sounds in %s', len(sounds), PACK.relative_to(ROOT))
    return 0


if __name__ == '__main__':
    sys.exit(main())
