#!/usr/bin/env python3
"""Run project checks and report results and timings."""
import argparse
from contextlib import nullcontext
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
DOMAINS = ('formats', 'simulation', 'tools', 'rendering', 'scurk', 'ui', 'audio')
SUITES = ('routine', 'full', 'release', 'audit', 'native', 'slow', 'integration', *DOMAINS)
CONSOLE_LOCK = threading.Lock()


def report(message):
    with CONSOLE_LOCK:
        print(message, flush=True)


def registry():
    entries = json.loads((ROOT / 'tools/validation_tests.json').read_text())
    ids = [e['id'] for e in entries]
    if len(set(ids)) != len(ids):
        raise ValueError('Duplicate test IDs')
    registered = set()
    members = set()
    for entry in entries:
        path = ROOT / 'game' / entry['script'] if 'script' in entry else ROOT / entry['python']
        if not path.is_file():
            raise ValueError(f'Required registered file is missing: {path}')
        if 'script' in entry:
            registered.add(entry['script'])
        for member in entry.get('members', []):
            members.add(member)
            if not (ROOT / 'game' / member).is_file():
                raise ValueError(f'Required suite member is missing: {member}')
    discovered = {str(p.relative_to(ROOT / 'game')) for p in (ROOT / 'game/tests').glob('*.gd')}
    discovered_members = {str(p.relative_to(ROOT / 'game')) for p in (ROOT / 'game/tests/suites/scenes').glob('*.gd')}
    missing = (discovered - registered) | (discovered_members - members)
    if missing:
        raise ValueError('Unregistered tests: ' + ', '.join(sorted(missing)))
    return entries


def select(entries, suites, ids):
    unknown = set(ids) - {e['id'] for e in entries}
    if unknown:
        raise ValueError('Unknown test IDs: ' + ', '.join(sorted(unknown)))
    result = []
    for original in entries:
        e = dict(original)
        include = e['id'] in ids
        for suite in suites:
            include |= (suite == 'release')
            include |= (suite == 'full' and e['lane'] in ('product', 'audit', 'slow', 'integration'))
            include |= (suite == 'routine' and e['lane'] == 'product')
            include |= (suite == e['lane'] and suite != 'product')
            include |= (suite == e['domain'] and e['lane'] == 'product')
        if e['id'] == 'test_runner' and set(suites) & set(DOMAINS):
            include = True
            if not (set(suites) & {'routine', 'full', 'release'}) and e['id'] not in ids:
                e['args'] = ['{references}', *[d for d in DOMAINS if d in suites]]
        if include:
            result.append(e)
    if any(e['id'] == 'runtime_ui_integration' for e in result):
        # The full script covers the short workflow too; do not launch both.
        result = [e for e in result if e['id'] != 'runtime_ui_smoke']
    # Run the history writer before the reader, including with --test ..._read.
    history = [e for e in entries if e.get('state') == 'file-history']
    if any(e.get('state') == 'file-history' for e in result):
        position = next(i for i, e in enumerate(result) if e.get('state') == 'file-history')
        result = [e for e in result if e.get('state') != 'file-history']
        result[position:position] = history
    return result


def missing_requirements(entry):
    missing = []
    for requirement in entry.get('requires', []):
        if requirement == 'ffmpeg':
            present = shutil.which(os.environ.get('OPENSC2K_FFMPEG', 'ffmpeg'))
        elif requirement == 'pillow':
            present = importlib.util.find_spec('PIL')
        else:
            present = (ROOT / requirement).exists()
        if not present:
            missing.append(requirement)
    return missing


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fixture_identity(godot):
    # Rebuild fixtures after any runtime source change.
    paths = [ROOT / 'game/tools/build_large_city_fixtures.gd', ROOT / 'game/project.godot']
    paths += sorted((ROOT / 'game/src').rglob('*.gd'))
    paths += sorted((ROOT / 'references/SIMCITY2000/CITIES').glob('*.SC2'))
    return {'engine': subprocess.check_output([godot, '--version'], text=True).strip(),
            'inputs': {str(p.relative_to(ROOT)): digest(p) for p in paths}}


def fixtures_current(identity):
    folder = ROOT / 'local/large-cities'
    stamp = folder / 'validation-build.json'
    if not stamp.is_file() or json.loads(stamp.read_text()) != identity:
        return False
    for edge in (256, 384, 512):
        path = folder / f'stitched-{edge}.sc2x'
        report = path.with_suffix('.sc2x.json')
        if not path.is_file() or not report.is_file():
            return False
        if json.loads(report.read_text()).get('output_sha256') != digest(path):
            raise ValueError(f'Refuse to reuse an edited fixture: {path}')
    return True


class Project:
    """Temporary project with isolated user data."""
    def __init__(self, temporary):
        self.base = Path(temporary)
        self.path = self.base / 'game'
        self.path.mkdir()
        for path in ROOT.iterdir():
            if path.name not in ('game', '.git'):
                (self.base / path.name).symlink_to(path, target_is_directory=path.is_dir())
        for path in (ROOT / 'game').iterdir():
            if path.name not in ('project.godot', 'override.cfg'):
                (self.path / path.name).symlink_to(path, target_is_directory=path.is_dir())
        self.name = 'OpenSC2K-validation-' + uuid.uuid4().hex
        if sys.platform == 'darwin':
            data = Path.home() / 'Library/Application Support'
        elif sys.platform == 'win32':
            data = Path(os.environ['APPDATA'])
        else:
            data = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
        self.user = data / self.name
        self.user.mkdir(parents=True)

    def configure(self, entry_id):
        text = (ROOT / 'game/project.godot').read_text()
        # An absolute custom directory is sanitized by Godot; use a unique relative name.
        text = re.sub(r'^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n', '', text, flags=re.M)
        text = text.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\n'
                            f'config/custom_user_dir_name="{self.name}/{entry_id}"')
        (self.path / 'project.godot').write_text(text)

    def close(self):
        shutil.rmtree(self.user)


def execute(command, log=None, timeout=900, name=''):
    environment = dict(os.environ, GODOT_AUDIO_DRIVER='Dummy', GODOT_TEST_TIMEOUT_SECONDS=str(timeout))
    start = time.monotonic()
    lines = []
    with log.open('w') if log else nullcontext() as output:
        # The wrapper handles script errors even when Godot would exit successfully or hang.
        with subprocess.Popen([sys.executable, str(ROOT / 'tools/run_godot_check.py'), *command],
                              cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              env=environment, text=True, errors='replace') as process:
            for line in process.stdout:
                lines.append(line)
                report((f'[{name}] ' if name else '') + line.rstrip('\n'))
                if output:
                    output.write(line)
                    output.flush()
            status = process.wait()
    content = ''.join(lines)
    result = 'FAIL' if status else ('SKIP' if re.search(r'^SKIP:', content, re.M) else 'PASS')
    return result, round(time.monotonic() - start, 3), content


def execution_groups(entries, parallel=True):
    """Keep native windows serial and persistence pairs ordered in one private project."""
    groups = []
    shared = {}
    for entry in entries:
        key = ('state', entry['state']) if entry.get('state') else (
            ('native',) if parallel and entry['lane'] == 'native' else None)
        if key is not None and key in shared:
            shared[key].append(entry)
        else:
            group = [entry]
            groups.append(group)
            if key is not None:
                shared[key] = group
    if parallel:
        # Start broad checks early so they do not form a long serial tail.
        groups.sort(key=lambda group: not (group[0]['lane'] in ('native', 'slow', 'integration')
                                          or group[0]['id'] == 'test_runner'))
    return groups


def run_parallel(entries, jobs, execute_entry, completed, keep_going):
    """Bound in-flight work and report on the caller thread. Drain after failure."""
    pending = {}
    remaining = iter(entries)
    stopped = False
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        while True:
            while not stopped and len(pending) < jobs:
                entry = next(remaining, None)
                if entry is None:
                    break
                pending[pool.submit(execute_entry, entry)] = entry
            if not pending:
                return not stopped
            done, _ = wait(pending, return_when=FIRST_COMPLETED)
            for future in done:
                entry = pending.pop(future)
                if not completed(entry, future.result()) and not keep_going:
                    stopped = True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite', action='append', choices=SUITES, default=[])
    parser.add_argument('--test', action='append', default=[], help='Exact registry ID; repeat to combine')
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--keep-going', action='store_true')
    parser.add_argument('--jobs', type=int, default=min(8, max(1, (os.cpu_count() or 1) // 2)),
                        help='Concurrent isolated groups (default: half the CPUs, up to 8; use 1 for timings)')
    parser.add_argument('--strict', action='store_true', help='Treat missing prerequisites and skips as failures')
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--output', type=Path, help='Also save logs and summary.json in this directory')
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error('--jobs must be at least 1')
    started = time.monotonic()
    suites = args.suite or ([] if args.test else ['routine'])
    entries = select(registry(), suites, args.test)
    if args.list:
        for e in entries:
            print(f"{e['id']:50} {e['domain']:12} {e['lane']:12}" + (' fixtures=' + ','.join(e['fixtures']) if e.get('fixtures') else ''))
        print(f'{len(entries)} entries; editor parse and startup also run')
        return 0
    strict = args.strict or 'release' in suites
    output = args.output.resolve() if args.output else None
    if output:
        output.mkdir(parents=True, exist_ok=False)
        report(f'Logs: {output}')
    results = []

    def record(name, status, duration=0, reason=''):
        results.append(dict(id=name, status=status, seconds=duration, reason=reason))
        report(f'{status:4} {name} ({duration:.2f}s)' + (f': {reason}' if reason else ''))
        if output:
            (output / 'summary.json').write_text(json.dumps({'suites': suites, 'selected_tests': [e['id'] for e in entries], 'results': results,
                'jobs': args.jobs, 'elapsed_seconds': round(time.monotonic() - started, 3)}, indent=2) + '\n')

    with tempfile.TemporaryDirectory(prefix='city-validation-') as temporary:
        project = Project(temporary)
        try:
            def godot_command(script=None, native=False, extra=(), target=None):
                cmd = [args.godot, '--audio-driver', 'Dummy', '--path', str((target or project).path)]
                if not native:
                    cmd += ['--headless']
                if script:
                    cmd += ['--script', 'res://' + script]
                return cmd + list(extra)

            def run(name, command, timeout=900):
                report(f'RUN  {name}')
                status, duration, content = execute(command, output / (name + '.log') if output else None, timeout, name)
                return finish(name, (status, duration, content))

            def finish(name, result):
                status, duration, content = result
                if status == 'SKIP' and strict:
                    status = 'FAIL'
                record(name, status, duration)
                return status != 'FAIL'

            project.configure('startup')
            if not run('parse', godot_command(extra=['--editor', '--quit'])):
                return 1
            if not run('startup', godot_command(extra=['--quit-after', '2'])):
                return 1
            prepared = []
            blocked = False
            for entry in entries:
                missing = missing_requirements(entry)
                if missing:
                    record(entry['id'], 'FAIL' if strict else 'SKIP', reason='Missing: ' + ', '.join(missing))
                    if strict and not args.keep_going:
                        blocked = True
                        break
                else:
                    prepared.append(entry)

            # Shared fixture writes finish before any consumer starts.
            if not blocked and any(entry.get('fixtures') for entry in prepared):
                try:
                    identity = fixture_identity(args.godot)
                    current = fixtures_current(identity)
                    if current:
                        record('large-city-fixtures', 'PASS', reason='Verified source, build, and output hashes; reused')
                    else:
                        project.configure('fixtures')
                        if run('large-city-fixtures', godot_command('tools/build_large_city_fixtures.gd')):
                            (ROOT / 'local/large-cities/validation-build.json').write_text(json.dumps(identity, indent=2) + '\n')
                        else:
                            blocked = True
                except (ValueError, OSError, subprocess.SubprocessError) as error:
                    record('large-city-fixtures', 'FAIL', reason=str(error))
                    blocked = True

            def isolated(group):
                results = []
                with tempfile.TemporaryDirectory(prefix='city-check-') as folder:
                    isolated_project = Project(folder)
                    try:
                        for entry in group:
                            name = entry['id']
                            isolated_project.configure(entry.get('state', name))
                            extra = [a.replace('{references}', str(ROOT / 'references/SIMCITY2000')) for a in entry.get('args', [])]
                            if 'python' in entry:
                                command = [sys.executable, str(ROOT / entry['python']), *extra]
                            elif entry.get('driver') == 'gif':
                                command = [sys.executable, str(ROOT / 'tools/test_gif_decode.py'), '--godot', args.godot, '--project', str(isolated_project.path)]
                            else:
                                command = godot_command(entry['script'], entry['lane'] == 'native',
                                                        ['--', *extra] if extra else [], target=isolated_project)
                            report(f'RUN  {name}')
                            result = execute(command, output / (name + '.log') if output else None,
                                             entry.get('timeout', float(os.environ.get('GODOT_TEST_TIMEOUT_SECONDS', '900'))), name)
                            results.append((name, result))
                            if (result[0] == 'FAIL' or (strict and result[0] == 'SKIP')) and not args.keep_going:
                                break
                    finally:
                        isolated_project.close()
                return results

            def finish_group(_group, results):
                passed = True
                for name, result in results:
                    passed = finish(name, result) and passed
                return passed

            if not blocked:
                run_parallel(execution_groups(prepared, args.jobs > 1), args.jobs,
                             isolated, finish_group, args.keep_going)
            run('diff-check', ['git', 'diff', '--check', '--', '.'])
        finally:
            project.close()
    totals = {status: sum(r['status'] == status for r in results) for status in ('PASS', 'FAIL', 'SKIP')}
    print(' '.join(f'{status}={count}' for status, count in totals.items()), flush=True)
    print(f'Elapsed: {time.monotonic() - started:.2f}s; summed check time: '
          f'{sum(r["seconds"] for r in results):.2f}s; jobs: {args.jobs}', flush=True)
    return int(totals['FAIL'] > 0)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(f'FAIL: {error}', file=sys.stderr)
        sys.exit(1)
