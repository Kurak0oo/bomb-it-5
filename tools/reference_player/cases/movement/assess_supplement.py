"""Check artifact integrity and recorded original observations, not Godot behavior."""
import csv
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[4]
EVIDENCE = ROOT / 'docs/evidence/reference-2026-10-19/movement/supplement'
CASES = Path(__file__).resolve().parent
CASE_FILES = {'cardinal-down': '03-cardinal-down.json', 'cardinal-left': '04-cardinal-left.json',
              'cardinal-up': '05-cardinal-up.json', 'protected-portal': '06-protected-portal.json',
              'portal-bomb': '07-portal-ordinary-bomb.json', 'portal-pause': '08-portal-pause.json',
              'mine-hazard': '09-portal-mine-hazard.json', 'ordinary-overlap': '10-ordinary-overlap.json',
              'stationary-expiry': '11-stationary-fire-expiry.json', **{
                  'corridor-' + direction: f'{number}-corridor-{direction}.json'
                  for number, direction in zip(range(12, 16), ['right', 'left', 'up', 'down'])}}
checks = []


def check(condition, label):
    if not condition:
        raise AssertionError(label)
    checks.append(label)


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def frames(name):
    result = {}
    for row in csv.DictReader((EVIDENCE / name / 'frames.csv').open(newline='', encoding='utf-8')):
        result[int(row['frame'])] = {key: json.loads(row[key]) for key in ['actors', 'cells', 'bombs']}
        result[int(row['frame'])]['paused'] = row['game_paused'] == 'True'
    return result


def actor(row, ui=0):
    return next(value for value in row['actors'] if value['ui'] == ui)


def cell(row, x, y):
    return next(value for value in row['cells'] if (value['x'], value['y']) == (x, y))


def command(owner, suffix):
    return next((value for value in owner['commands'] if value['class'].endswith(suffix)), None)


def assess():
    total_frames = total_events = pictures = 0
    for name, filename in CASE_FILES.items():
        root = EVIDENCE / name
        summary, manifest = read(root / 'summary.json'), read(root / 'manifest.json')
        check((root / 'case.json').read_bytes() == (CASES / filename).read_bytes(), f'{name}: exact case bytes')
        check(digest(root / 'case.json') == summary['case_sha256'] == manifest['case_sha256'], f'{name}: case hash')
        check(digest(root / 'commands.jsonl') == manifest['command_log_sha256'], f'{name}: command hash')
        check(digest(root / 'player-stderr.log') == manifest['stderr_sha256'], f'{name}: stderr hash')
        check(summary['swf_sha256'] == '718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2', f'{name}: authority hash')
        check(summary['player_sha256'] == '9c1dcc316e1344e5061194ba5062abc01396145d89318ea27582058a6bb1ea3c', f'{name}: player hash')
        check(all(summary['events'][key] == 0 for key in ['dropped', 'overflow_files', 'errors']), f'{name}: complete/error-free event buffers')
        check(len(frames(name)) == summary['trace_frames'], f'{name}: frame count')
        for fixture in manifest['fixture_results']:
            check(digest(root / (fixture['name'] + '-result.json')) == fixture['sha256'], f'{name}: {fixture["name"]} result hash')
        for picture in summary['screenshots']:
            path = root / picture['name']
            original = next(item for item in manifest['captures'] if item['name'] + '.png' == path.name)
            check(digest(path) == picture['sha256'] == original['sha256'], f'{name}: {path.name} hash')
            check(struct.unpack('>II', path.read_bytes()[16:24]) == (700, 510), f'{name}: {path.name} dimensions')
            pictures += 1
        total_frames += summary['trace_frames']
        total_events += summary['events']['events']
    for direction, axis, blocked in [('down', 1, 60), ('left', 0, 420), ('up', 1, 360)]:
        rows = frames('cardinal-' + direction)
        for frame, expected in zip(range(722, 725), [1.6, 2.56, 3.136]):
            check(abs(abs(actor(rows[frame])['velocity'][axis]) - expected) < 1e-10, f'{direction}: original acceleration at {frame}')
        check(all((actor(rows[frame])['x'], actor(rows[frame])['y']) == (actor(rows[736])['x'], actor(rows[736])['y'])
                  for frame in range(737, 741)), f'{direction}: release stops displacement')
        last = actor(rows[799])
        check(last[['x', 'y'][axis]] == blocked and last['bomb_num'] == 1, f'{direction}: live-bomb reentry blocked')
    rows = frames('stationary-expiry')
    check(all(actor(rows[f])['state'] == 'normal' and actor(rows[f])['damage_eligible'] and cell(rows[f], 1, 1)['fire']
              and (actor(rows[f])['x'], actor(rows[f])['y']) == (30, 30) for f in range(876, 883)), 'stationary eligible human survives existing fire at expiry')
    human_fire = command(actor(rows[876]), '::GetFireCommand')['id']
    check(not any(e['receiver'].get('$ref') == human_fire and 876 <= e['frame'] <= 882
                  for e in read(EVIDENCE / 'stationary-expiry/selected-events.json')), 'no human fire-contact command at eligibility-only expiry')
    check(not cell(rows[883], 1, 1)['fire'] and actor(rows[883])['state'] == 'normal', 'stationary survivor after fire cleanup')
    overlap = frames('ordinary-overlap')[799]
    check(all(actor(overlap, ui)['state'] == 'normal' and actor(overlap, ui)['damage_eligible']
              and actor(overlap, ui)['cell'] == [1, 2] for ui in [0, 3]), 'ordinary eligible actors overlap without damage')
    portal = frames('portal-bomb')[798]
    check(cell(portal, 13, 11)['fire'] and not cell(portal, 13, 12)['fire'] and bool(cell(portal, 13, 13)['box']), 'ordinary power-two ray excludes portal and stops before box beyond')
    check(actor(frames('portal-bomb')[799])['bomb_num'] == 0, 'ordinary bomb rejected on portal')
    protected = frames('protected-portal')
    check(actor(protected[730])['state'] == 'Invincible' and command(actor(protected[730]), '::SendRobotCommand') is not None, 'protected actor accepted by portal')
    check(actor(protected[759])['state'] == 'Invincible' and actor(protected[759])['damage_eligible'], 'Send arrival overrides damage eligibility before item state expires')
    paused = frames('portal-pause')
    identity = command(actor(paused[733]), '::SendRobotCommand')['id']
    check(all(paused[f]['paused'] and command(actor(paused[f]), '::SendRobotCommand')['_frameCount'] == 5
              and command(actor(paused[f]), '::InvincibilityCommand')['_nvincibilityTimeCount'] == 5
              for f in range(733, 780)), 'Send/blink paused without countdown progress')
    check(command(actor(paused[780]), '::SendRobotCommand')['id'] == identity
          and command(actor(paused[780]), '::SendRobotCommand')['_frameCount'] == 6, 'same Send resumes')
    mine = frames('mine-hazard')
    check(bool(cell(mine[760], 13, 12)['_bombArr']['elements']), 'equipped action places mine on portal')
    check(any(b.get('_hasOutLandBomb') for b in mine[767]['bombs']), 'portal mine arms after owner exit')
    check(actor(mine[810], 1)['damage_eligible'] and actor(mine[810], 1)['cell'] == [3, 2], 'physical mine-destination arrival precedes occupancy')
    check(actor(mine[811], 1)['cell'] == [13, 12] and actor(mine[811], 1)['state'] == 'normal', 'live destination occupancy before mine contact')
    victim = actor(mine[812], 1)
    check(victim['state'] == 'dead' and cell(mine[812], 13, 12)['fire']
          and command(victim, '::InvincibilityCommand')['_nvincibilityTimeCount'] == 31, 'mine kills arriving actor while portal blink persists')
    check(all(not any(item.get('$ref') == victim['robot'] for item in cell(mine[f], 13, 12)['_robot']['elements']) for f in range(812, 822)), 'dead traveler removed from portal occupancy')
    result = {'checks_passed': len(checks), 'trace_frames': total_frames, 'events': total_events,
              'screenshots': pictures, 'checks': checks,
              'scope': 'Artifact integrity and observed original-Ruffle outcomes; not simulation tests or complete Flash parity.'}
    (EVIDENCE / 'assessment.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: result[key] for key in ['checks_passed', 'trace_frames', 'events', 'screenshots']}))


if __name__ == '__main__':
    assess()
