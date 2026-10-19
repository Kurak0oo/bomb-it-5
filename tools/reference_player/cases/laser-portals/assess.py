"""Check the recorded original portal-ray observations and their artifact identities."""
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[4]
EVIDENCE = ROOT / 'docs/evidence/reference-2026-10-19/laser-portals'
checks = []


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def check(condition, label):
    if not condition:
        raise AssertionError(label)
    checks.append(label)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def cell(boundary, y):
    return next(item for item in boundary['cells'] if item['y'] == y)


def assess():
    event_count = frames = 0
    for number, condition in [('01', 'empty'), ('02', 'occupied'), ('03', 'shielded')]:
        root = EVIDENCE / condition
        summary, manifest = read(root / 'summary.json'), read(root / 'manifest.json')
        case = Path(__file__).with_name(f'{number}-{condition}-portal.json')
        check(case.read_bytes() == (root / 'case.json').read_bytes(), condition + ': exact executed case')
        check(digest(case) == summary['case_sha256'] == manifest['case_sha256'], condition + ': case hash')
        check(digest(root / 'commands.jsonl') == manifest['command_log_sha256'], condition + ': protocol hash')
        check(digest(root / 'player-stderr.log') == manifest['stderr_sha256'], condition + ': stderr hash')
        check(summary['swf_sha256'] == '718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2', condition + ': source SWF')
        check(summary['player_sha256'] == '33d2791282aa7d93d5b9bfe7a1ce166a31e155355e02c8bd584b08a60354ffe8', condition + ': v6 player')
        check(all(summary['events'][key] == 0 for key in ['dropped', 'overflow_files', 'errors', 'stack_overflows']), condition + ': complete nonerroring stream')
        for fixture in manifest['fixture_results']:
            check(digest(root / (fixture['name'] + '-result.json')) == fixture['sha256'], condition + ': ' + fixture['name'] + ' hash')
        for picture in summary['screenshots']:
            path = root / picture['name']
            original = next(item for item in manifest['captures'] if item['name'] + '.png' == path.name)
            check(digest(path) == picture['sha256'] == original['sha256'], condition + ': ' + path.name + ' hash')
            check(struct.unpack('>II', path.read_bytes()[16:24]) == (700, 510), condition + ': ' + path.name + ' dimensions')
        queries = summary['direct_ray_queries']
        blocks = [call for call in queries if call['method'].endswith('/isBlock()')]
        check([(call['arguments'], call['result']) for call in blocks] == [([13, 11], False), ([13, 12], False), ([13, 13], True)], condition + ': actual nonblock portal and first blocker')
        conditional = [call for call in queries if call['method'].endswith('/getRobot()')]
        check(len(conditional) == 1 and conditional[0]['arguments'] == [13, 13]
              and conditional[0]['result']['array_length'] == 0, condition + ': actor-present OR query skipped on nonblocked portal')
        check(summary['actor_hit_cells'] == [[13, 11, False], [13, 12, False]], condition + ': one actor pass through owner/portal cells')
        check(summary['item_hit_cells'] == [[13, 11], [13, 12], [13, 13]], condition + ': first blocker receives item hit only')
        shoot = summary['shoot']['enter_frame']
        check(summary['laser_end_frames'] == list(range(shoot + 1, shoot + 12)), condition + ': exactly eleven cleanup callbacks after single pass')
        boundary = {item['name']: item for item in read(root / 'boundaries.json')}
        before, beam, after = (boundary[name] for name in ['pre-shot', 'beam-creation', 'beam-cleaned'])
        check(before['uses'] == 0 and beam['uses'] == after['uses'] == 1 and after['total_uses'] == 2, condition + ': one use consumed')
        check(boundary['charge-first']['charge_play']['display']['current_frame'] == 1
              and beam['charge_play']['display']['current_frame'] == 11, condition + ': actual charge frames')
        check(bool(cell(before, 13)['box']) and cell(beam, 13)['box'] is None, condition + ': first soft blocker destroyed without extending this ray')
        check(not cell(beam, 12)['fire'], condition + ': laser pass not persistent portal map fire')
        laser_container = beam['laser']['container']['$ref']
        removals = [call for call in read(root / 'selected-events.json') if 'DisplayObjectContainer/removeChild' in call['method']
                    and call['arguments'] and isinstance(call['arguments'][0], dict)
                    and call['arguments'][0].get('$ref') == laser_container]
        check(len(removals) == 1 and removals[0]['enter_frame'] == shoot + 11, condition + ': same beam display removed at cleanup')
        check(beam['busy'] is not None and after['busy'] is None and after['laser']['owner'] is None, condition + ': source cleanup restores control')
        check(boundary['fresh-movement']['actors'][0]['position'] == [390, 337.25], condition + ': fresh legal movement after recovery')
        ray = read(root / 'ray-call-tree.json')
        target_hits = [call for call in ray if call['method'].endswith('/hitRobot()')]
        if condition == 'empty':
            check(not target_hits and not cell(before, 12)['_robot']['elements'], 'empty portal: no invented target hit')
        else:
            target = before['actors'][1]
            check(target['cell'] == [13, 12] and target['position'] == [390, 360] and target['damage_eligible'], condition + ': eligible target truly occupies portal before charge')
            check(len(target_hits) == 1 and target_hits[0]['arguments'][0]['$ref'] == target['id'], condition + ': exact target hit once by this ray')
            if condition == 'occupied':
                check(beam['actors'][1]['state'] == 'dead' and beam['actors'][1]['cell'] == [13, 12], 'occupied portal: target dies on portal')
            else:
                check(target['shield'] is not None and beam['actors'][1]['shield'] is None
                      and beam['actors'][1]['state'] == 'normal' and not beam['actors'][1]['damage_eligible'], 'shielded portal: shield consumed, target survives protected')
        event_count += summary['events']['events']
        frames += summary['trace_frames']
    result = {'checks_passed': len(checks), 'trace_frames': frames, 'events': event_count,
              'checks': checks, 'scope': 'Recorded original-Ruffle observations; bare portal does not force actor-present blocker exception.'}
    (EVIDENCE / 'assessment.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: result[key] for key in ['checks_passed', 'trace_frames', 'events']}))


if __name__ == '__main__':
    assess()
