"""Run a recorded input case against the actual original-SWF reference player."""
import argparse
import hashlib
import json
from pathlib import Path
import queue
import re
import subprocess
import tempfile
import threading
import time

from inspect_source_data import SWF_SHA256


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class ReferenceSession:
    def __init__(self, executable, swf, output, compact=False, focus=False):
        self.output = output.resolve()
        self.compact = compact
        self.focus = focus
        self.output.mkdir(parents=True, exist_ok=False)
        self.stderr = (self.output / 'player-stderr.log').open('w', encoding='utf-8')
        self.log = (self.output / 'commands.jsonl').open('w', encoding='utf-8')
        self.process = subprocess.Popen([str(executable.resolve()), str(swf.resolve())],
                                        cwd=self.output, stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=self.stderr,
                                        text=True, encoding='utf-8', bufsize=1)
        self.lines = queue.Queue()
        self.frame = 0
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        for line in self.process.stdout:
            self.lines.put(line.rstrip('\n'))
        self.lines.put(None)

    def command(self, command):
        if '\n' in command or '\r' in command:
            raise ValueError('One command per protocol line')
        before = time.monotonic_ns()
        self.process.stdin.write(command + '\n')
        self.process.stdin.flush()
        while True:
            line = self.lines.get(timeout=120)
            if line is None:
                raise RuntimeError(f'Player exited during {command}; see player-stderr.log')
            match = re.fullmatch(r'OK frame=(\d+) wall_ms=(\d+) fps_setting=(\S+) cmd=(.*)', line)
            if match:
                if match[4] != command:
                    raise RuntimeError(f'Unexpected command acknowledgement: {line}')
                current = int(match[1])
                expected = self.frame + int(command.split()[1]) if command.startswith('step ') else self.frame
                if current != expected:
                    raise RuntimeError(f'Frame accounting mismatch: expected {expected}, got {current}')
                self.frame = current
                item = {'command': command, 'frame': current, 'player_wall_ms': int(match[2]),
                        'fps_setting': float(match[3]), 'host_before_ns': before,
                        'host_after_ns': time.monotonic_ns()}
                self.log.write(json.dumps(item) + '\n')
                self.log.flush()
                return item
            self.log.write(json.dumps({'player_stdout': line}) + '\n')

    def capture(self, name):
        if not re.fullmatch(r'[A-Za-z0-9_-]+', name):
            raise ValueError('Capture names contain only letters, digits, underscore and hyphen')
        self.command(f'shot {name}.png')
        path = self.output / f'{name}.png'
        raw = path.read_bytes()
        if raw[:8] != b'\x89PNG\r\n\x1a\n' or raw[16:24] != (700).to_bytes(4, 'big') + (510).to_bytes(4, 'big'):
            raise RuntimeError('Reference capture is not a 700x510 PNG')
        return {'name': name, 'frame': self.frame, 'sha256': sha256(path), 'bytes': len(raw)}

    def snapshot(self, name):
        if not re.fullmatch(r'[A-Za-z0-9_-]+', name):
            raise ValueError('State names contain only letters, digits, underscore and hyphen')
        self.command(f'{"focus" if self.focus else "compact" if self.compact else "state"} {name}.json')
        path = self.output / f'{name}.json'
        state = json.loads(path.read_text(encoding='utf-8'))
        if state.get('schema') not in ('bombit5-reference-graph-v1', 'bombit5-reference-compact-graph-v1', 'bombit5-reference-focus-v1'):
            raise RuntimeError('Unrecognized reference state schema')
        return {'name': name, 'frame': self.frame, 'sha256': sha256(path),
                'objects': len(state.get('objects', {})) if not self.focus else state.get('record_count', 0),
                'available': state.get('available', True), 'truncated': state['truncated']}

    def close(self, check=True):
        try:
            if self.process.poll() is None:
                # The supplied protocol exits before printing an OK line for quit.
                try:
                    self.process.stdin.write('quit\n')
                    self.process.stdin.flush()
                    self.process.stdin.close()
                except OSError:
                    # A protocol failure may already have closed the child's pipe.
                    pass
                try:
                    self.process.wait(timeout=20)
                except subprocess.TimeoutExpired:
                    if check:
                        raise
            if check and self.process.returncode:
                raise RuntimeError(f'Reference player failed with {self.process.returncode}')
        finally:
            if self.process.poll() is None:
                self.process.kill()
                self.process.wait(timeout=10)
            self.log.close()
            self.stderr.close()


def replay(executable, swf, case_path, output, observe=False, fixtures=False, compact=False, focus=False):
    if sha256(swf) != SWF_SHA256:
        raise ValueError('Not the recorded publisher SWF')
    if not executable.is_file():
        raise FileNotFoundError(f'Reference executable not built: {executable}')
    case_bytes = case_path.read_bytes()
    case = json.loads(case_bytes.decode('utf-8'))
    if any('fixture' in action for action in case['actions']) and not fixtures:
        raise ValueError('This case requires --fixtures and a fixture-enabled player')
    if (compact or focus) and not observe:
        raise ValueError('--compact/--focus require --observe')
    if compact and focus:
        raise ValueError('Choose either compact or focused observation')
    # Ruffle's SharedObject.getLocal rejects dot-prefixed URL path components.
    # Loading directly from .scratch makes the original controls setup throw.
    staging = tempfile.TemporaryDirectory(prefix='bombit5-reference-')
    loaded_swf = Path(staging.name) / 'original.swf'
    loaded_swf.write_bytes(swf.read_bytes())
    if any(part.startswith('.') for part in loaded_swf.resolve().parts):
        staging.cleanup()
        raise ValueError('TEMP must not contain dot-prefixed path components')
    session = ReferenceSession(executable, loaded_swf, output, compact, focus)
    (session.output / 'case.json').write_bytes(case_bytes)
    captures = []
    states = []
    fixture_results = []
    completed = False
    try:
        for action in case['actions']:
            if 'fixture' in action:
                name = f'fixture-{len(fixture_results):04d}'
                (session.output / f'{name}.json').write_text(json.dumps(action['fixture']), encoding='utf-8')
                session.command(f'fixture {name}.json')
                result_path = session.output / f'{name}-result.json'
                result = json.loads(result_path.read_text(encoding='utf-8'))
                if result.get('schema') != 'bombit5-reference-fixture-v1' or result.get('command') != action['fixture']:
                    raise RuntimeError('Fixture result does not match the requested original-method operation')
                fixture_results.append({'name': name, 'frame': session.frame, 'sha256': sha256(result_path)})
            if 'command' in action:
                session.command(action['command'])
            if observe and 'observe_command' in action:
                session.command(action['observe_command'])
            if 'capture' in action:
                captures.append(session.capture(action['capture']))
                if observe:
                    states.append(session.snapshot(action['capture']))
            if observe and 'state' in action:
                states.append(session.snapshot(action['state']))
        manifest = {'status': 'executed_reference_case_not_yet_behavior_verified',
                    'case': case['name'], 'case_sha256': hashlib.sha256(case_bytes).hexdigest(),
                    'fixtures': fixtures, 'fixture_results': fixture_results,
                    'observation_mode': 'focus' if focus else 'compact' if compact else 'full' if observe else 'none',
                    'swf_sha256': sha256(swf), 'player_sha256': sha256(executable),
                    'load_path': str(loaded_swf.resolve()),
                    'load_path_reason': 'Byte-identical temporary copy avoids SharedObject dot-path rejection.',
                    'last_frame': session.frame, 'captures': captures, 'states': states,
                    'limits': ['No RNG determinism implied.',
                               'Frame stepping and host wall clock are different clocks.',
                               'Visual content and game state require separate assessment.']}
        completed = True
    finally:
        try:
            session.close(check=completed)
        finally:
            staging.cleanup()
    manifest['exit_code'] = session.process.returncode
    manifest['command_log_sha256'] = sha256(session.output / 'commands.jsonl')
    manifest['stderr_sha256'] = sha256(session.output / 'player-stderr.log')
    (session.output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(f'Replayed {case["name"]}: frame {session.frame}, {len(captures)} captures at {session.output}')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    default_player = Path('.scratch/edition-5-research/ruffle-runtime/target/ci/probe.exe')
    if not default_player.exists():
        default_player = default_player.with_suffix('')  # Linux build (build.sh)
    parser.add_argument('--player', type=Path, default=default_player)
    parser.add_argument('--swf', type=Path, default=Path('.scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf'))
    parser.add_argument('--case', type=Path, default=Path('tools/reference_player/cases/normal-arcade.json'))
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--observe', action='store_true', help='Capture read-only state beside each screenshot (patched player only)')
    parser.add_argument('--fixtures', action='store_true', help='Allow explicitly recorded original-method fixture calls')
    parser.add_argument('--compact', action='store_true', help='Omit native painting trees from --observe snapshots')
    parser.add_argument('--focus', action='store_true', help='Capture explicit gameplay projection with --observe')
    args = parser.parse_args()
    replay(args.player, args.swf, args.case, args.output, args.observe, args.fixtures, args.compact, args.focus)
