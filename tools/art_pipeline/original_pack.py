"""Build the original replica's ignored art pack from the user's own SWF (ADR 0008).

    python tools/art_pipeline/original_pack.py [--swf PATH] [--resume] [--jobs N]

Runs the art pipeline's extraction and slot layout without any modification, writes
each slot sheet to original/art/slots/<slot>/candidate.png and the pack manifest to
original/active.json. The game reads that pack under the original fidelity profile;
the folder is ignored by git and must never be committed.
"""
import argparse
import json
import os
import sys

os.environ['ART_PIPELINE_ORIGINAL'] = '1'  # Before the pipeline modules read it.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import run
from common import CANDIDATES, ROOT, log, write_json

PACK = ROOT / 'original' / 'active.json'


def manifest():
    """Skin manifest records (scripts/art/skin.gd) for every slot sheet that was built."""
    records = {}
    for path in sorted((CANDIDATES / 'slots').glob('*/meta.json')):
        meta = json.loads(path.read_text(encoding='utf-8'))
        sheet = path.parent / 'candidate.png'
        if meta.get('kind') != 'slot' or not sheet.is_file():
            continue
        records[meta['id']] = {'path': 'res://' + sheet.relative_to(ROOT).as_posix(), 'label': 'original SWF',
                               'columns': meta['columns'], 'rows': meta['rows'], 'fps': 8.0, 'scale': 1.0,
                               'x': 0.0, 'y': 0.0, 'tint': 'ffffffff'}
    return records


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--swf', help='SWF to use; copied to the canonical .scratch path')
    parser.add_argument('--resume', action='store_true', help='skip slots whose sheet is already up to date')
    parser.add_argument('--jobs', type=int, default=os.cpu_count() or 1, help='worker processes')
    args = parser.parse_args(argv)
    forwarded = ['--only', 'slots', '--no-zip', '--jobs', str(args.jobs)]
    if args.swf:
        forwarded += ['--swf', args.swf]
    if args.resume:
        forwarded.append('--resume')
    code = run.main(forwarded)
    if code:
        return code
    records = manifest()
    write_json(PACK, {'version': 1, 'overrides': records})
    log.info('Original pack: %d slot sheets in %s', len(records), os.path.relpath(PACK, ROOT))
    return 0


if __name__ == '__main__':
    sys.exit(main())
