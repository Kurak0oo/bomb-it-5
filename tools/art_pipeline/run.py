"""Run the whole SWF-to-candidate art pipeline.

    python tools/art_pipeline/run.py [--swf PATH] [--only TOKENS] [--resume] [--jobs N] [--no-zip]

Outputs go to ignored .scratch/ and candidates/ only. Candidates are never applied to
the game; review candidates/review.html and import chosen ones through the workbench.
"""
import argparse
import json
import multiprocessing
import os
import shutil
import sys
import time
import traceback

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np

import extract
import manifest
import palette
import process
import review
import slots
import upscale
from common import CANDIDATES, ROOT, load_config, log, modify_params, setup_logging, write_json

_STATE = {}


def pick_frames(count, spec, limit):
    if spec == 'all':
        frames = list(range(1, count + 1))
    elif isinstance(spec, int):
        frames = sorted({round(v) for v in np.linspace(1, count, max(1, min(spec, count)))})
    else:
        frames = [min(max(1, int(f)), count) for f in spec]
    if len(frames) > limit:
        frames = [frames[round(i)] for i in np.linspace(0, len(frames) - 1, limit)]
    return frames


def plan(assets, config):
    by_name, by_id = {}, {}
    for asset in assets:
        for name in [asset['name']] + asset['alias_names']:
            if name:
                by_name.setdefault(name, asset)
        for ident in [asset['id']] + asset['duplicate_ids']:
            by_id[ident] = asset
    jobs = []
    for entry in slots.entries():
        source = config['slots'][entry['id']]['source']
        if not source:
            continue
        names = source.get('rows') or [source['sprite']]
        rows = []
        for name in names:
            asset = manifest.resolve(name, by_name, by_id)
            frames = pick_frames(len(asset['frames']), source.get('frames', 'all'), config['max_frames'])
            rows.append([{'asset': asset, 'frame': f} for f in frames])
        columns = max(len(r) for r in rows)
        rows = [[r[int(i * len(r) / columns)] for i in range(columns)] for r in rows]
        jobs.append(job('slot', entry['id'], 'slots/' + entry['id'], rows, entry['size'], [entry['id']],
                        modify_params(config, entry['id']), config))
    for asset in assets:
        frames = pick_frames(len(asset['frames']), 'all', config['unmapped']['max_frames'])
        params = modify_params(config, asset['slots'][0] if asset['slots'] else 'unmapped')
        jobs.append(job('asset', asset['key'], 'assets/' + asset['key'], [[{'asset': asset, 'frame': f} for f in frames]],
                        None, asset['slots'], params, config))
    return jobs


def job(kind, ident, folder, rows, cell, slot_ids, params, config):
    sources = list(dict.fromkeys(ref['asset']['key'] for row in rows for ref in row))
    types = sorted({ref['asset']['type'] for row in rows for ref in row})
    stamp_input = [cell, [[(ref['asset']['hash'], ref['frame']) for ref in row] for row in rows]]
    return {'kind': kind, 'id': ident, 'folder': folder, 'rows': rows, 'cell': cell, 'slots': slot_ids,
            'params': params, 'sources': sources, 'type': ' + '.join(types), 'stamp_input': stamp_input}


def matches(job_entry, tokens):
    if not tokens:
        return True
    for token in tokens:
        lowered = token.lower()
        if token == 'slots' and job_entry['kind'] == 'slot' or token == 'assets' and job_entry['kind'] == 'asset':
            return True
        if token == 'mapped' and job_entry['slots'] or token == 'unmapped' and not job_entry['slots']:
            return True
        if any(s.startswith(token) for s in job_entry['slots']) or job_entry['id'].startswith(token):
            return True
        if lowered in job_entry['id'].lower() or lowered in job_entry['type'].replace('vector ', ''):
            return True
    return False


def _init(config, mapping, upscaled, resume):
    _STATE.update(config=config, mapping=mapping, upscaled=upscaled, resume=resume)
    try:
        import resource
        resource.setrlimit(resource.RLIMIT_AS, (6 << 30, 6 << 30))  # Keep one runaway job from starving others.
    except (ImportError, ValueError, OSError):
        pass


def _work(job_entry):
    started = time.time()
    try:
        meta, reused = process.run(job_entry, _STATE['config'], _STATE['mapping'], _STATE['upscaled'], _STATE['resume'])
        return {'ok': True, 'meta': meta, 'reused': reused, 'seconds': time.time() - started}
    except process.EmptyJob as error:
        return {'ok': False, 'id': job_entry['id'], 'stage': 'process', 'error': str(error), 'empty': True}
    except BaseException as error:  # Log and continue; one asset never stops the batch.
        return {'ok': False, 'id': job_entry['id'], 'stage': 'process', 'error': repr(error),
                'trace': traceback.format_exc(limit=4)}


def collect_metas():
    metas = []
    for path in sorted(CANDIDATES.glob('*/*/meta.json')):
        try:
            metas.append(json.loads(path.read_text()))
        except (OSError, ValueError):
            continue
    return metas


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--swf', help='SWF to use; copied to the canonical .scratch path')
    parser.add_argument('--only', help='comma-separated filters: slots, assets, mapped, unmapped, a slot id or '
                                       'prefix (actor.human, board.), an asset key/name substring, or a type')
    parser.add_argument('--resume', action='store_true', help='skip jobs whose candidate is already up to date')
    parser.add_argument('--jobs', type=int, default=os.cpu_count() or 1, help='worker processes')
    parser.add_argument('--batch', type=int, default=200, help='jobs per batch between progress reports')
    parser.add_argument('--no-zip', action='store_true', help='skip candidates.zip')
    args = parser.parse_args(argv)
    setup_logging()
    started = time.time()
    config = load_config()
    problems = slots.check_against_catalog()
    if problems:
        log.error('Slot mirror is out of date with scripts/art/catalog.gd: %s', problems)
        return 2
    try:
        swf, digest = extract.locate_swf(args.swf)
    except extract.SwfMissing as error:
        log.error('%s', error)
        return 3
    CANDIDATES.mkdir(exist_ok=True)
    (CANDIDATES / '.gdignore').write_text('Candidate art is reviewed outside Godot; import chosen files via the workbench.\n')
    export_summary = extract.export(swf, digest, config)
    assets, counts = manifest.build(config)
    palette.build(assets, config)
    mapping = palette.target_mapping()
    jobs = plan(assets, config)
    tokens = [t.strip() for t in (args.only or '').split(',') if t.strip()]
    selected = [j for j in jobs if matches(j, tokens)]
    bitmaps = [a for a in assets if a['type'] == 'bitmap'
               and any(ref['asset']['key'] == a['key'] for j in selected for row in j['rows'] for ref in row)]
    upscaled, failures = upscale.upscale_all(bitmaps, config, args.jobs)
    log.info('Processing %d of %d jobs with %d workers%s', len(selected), len(jobs), args.jobs,
             ' (resume)' if args.resume else '')
    done = reused = empty = 0
    # Large slot sheets first so a long tail does not wait on them.
    selected.sort(key=lambda j: (j['kind'] != 'slot', -sum(len(r) for r in j['rows'])))
    with multiprocessing.Pool(args.jobs, _init, (config, mapping, upscaled, args.resume), maxtasksperchild=50) as pool:
        for start in range(0, len(selected), args.batch):
            for result in pool.imap_unordered(_work, selected[start:start + args.batch], chunksize=2):
                if result['ok']:
                    done += 1
                    reused += result['reused']
                elif result.get('empty'):
                    empty += 1
                else:
                    failures.append(result)
                    log.error('Failed %s: %s', result['id'], result['error'])
            log.info('Progress %d/%d (failed %d, empty %d, reused %d)', min(start + args.batch, len(selected)),
                     len(selected), len(failures), empty, reused)
    metas = collect_metas()
    page = review.build(metas, config['flag_change_pct'])
    slot_metas = [m for m in metas if m['kind'] == 'slot']
    summary = {
        'swf_sha256': digest, 'export': export_summary, 'manifest': counts,
        'jobs': {'planned': len(jobs), 'selected': len(selected), 'succeeded': done, 'reused': reused,
                 'empty': empty, 'failed': len(failures)},
        'slots': {'catalogue': 89, 'with_source': sum(1 for s in config['slots'].values() if s['source']),
                  'candidates': len(slot_metas),
                  'without_source': sorted(k for k, s in config['slots'].items() if not s['source'])},
        'flagged_over_pct': config['flag_change_pct'],
        'flagged': sorted(m['id'] for m in metas if m['flag']),
        'change_pct_median': {'slots': float(np.median([m['change_pct'] for m in slot_metas])) if slot_metas else None,
                              'assets': float(np.median([m['change_pct'] for m in metas if m['kind'] == 'asset']))
                              if len(metas) > len(slot_metas) else None},
        'unmapped_assets': sum(1 for a in assets if not a['slots']),
        'failures': failures, 'seconds': round(time.time() - started, 1)}
    write_json(CANDIDATES / 'summary.json', summary)
    write_json(CANDIDATES / 'failures.json', failures)
    if not args.no_zip:
        archive = shutil.make_archive(str(ROOT / 'candidates'), 'zip', root_dir=ROOT, base_dir='candidates')
        log.info('Zipped %s (%.1f MB)', os.path.relpath(archive, ROOT), os.path.getsize(archive) / 1e6)
    log.info('Done in %.0fs: %d succeeded (%d reused), %d empty, %d failed. Review: %s', time.time() - started,
             done, reused, empty, len(failures), os.path.relpath(page, ROOT))
    return 0


if __name__ == '__main__':
    sys.exit(main())
