#!/usr/bin/env python3
"""Run project checks and report results and timings."""
import argparse
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
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
DOMAINS = ('formats', 'simulation', 'tools', 'rendering', 'scurk', 'ui', 'audio')
SUITES = ('routine', 'full', 'release', 'audit', 'native', 'slow', 'architecture', 'integration', *DOMAINS)


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
            include |= (suite == 'release' and e['lane'] != 'architecture')
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
            present = (ROOT / requirement).is_file()
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


def execute(command, log, timeout=900):
    environment = dict(os.environ, GODOT_AUDIO_DRIVER='Dummy', GODOT_TEST_TIMEOUT_SECONDS=str(timeout))
    start = time.monotonic()
    with log.open('w') as output:
        # The wrapper handles script errors even when Godot would exit successfully or hang.
        status = subprocess.call([sys.executable, str(ROOT / 'tools/run_godot_check.py'), *command],
                                 cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, env=environment)
    content = log.read_text(errors='replace')
    result = 'FAIL' if status else ('SKIP' if re.search(r'^SKIP:', content, re.M) else 'PASS')
    return result, round(time.monotonic() - start, 3), content


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite', action='append', choices=SUITES, default=[])
    parser.add_argument('--test', action='append', default=[], help='Exact registry ID; repeat to combine')
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--keep-going', action='store_true')
    parser.add_argument('--strict', action='store_true', help='Treat missing prerequisites and skips as failures')
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--output', type=Path, help='Log directory (default: unique local/validation run)')
    args = parser.parse_args()
    suites = args.suite or ([] if args.test else ['routine'])
    entries = select(registry(), suites, args.test)
    if args.list:
        for e in entries:
            print(f"{e['id']:50} {e['domain']:12} {e['lane']:12}" + (' fixtures=' + ','.join(e['fixtures']) if e.get('fixtures') else ''))
        print(f'{len(entries)} entries; editor parse and startup also run')
        return 0
    strict = args.strict or 'release' in suites
    output = (args.output or ROOT / 'local/validation' / (time.strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:6])).resolve()
    output.mkdir(parents=True, exist_ok=False)
    results = []
    print(f'Logs: {output}', flush=True)

    def record(name, status, duration=0, reason=''):
        results.append(dict(id=name, status=status, seconds=duration, reason=reason))
        print(f'{status:4} {name} ({duration:.2f}s)' + (f': {reason}' if reason else ''), flush=True)
        (output / 'summary.json').write_text(json.dumps({'suites': suites, 'selected_tests': [e['id'] for e in entries], 'results': results}, indent=2) + '\n')

    with tempfile.TemporaryDirectory(prefix='city-validation-') as temporary:
        project = Project(temporary)
        try:
            def godot_command(script=None, native=False, extra=()):
                cmd = [args.godot, '--audio-driver', 'Dummy', '--path', str(project.path)]
                if not native:
                    cmd += ['--headless']
                if script:
                    cmd += ['--script', 'res://' + script]
                return cmd + list(extra)

            def run(name, command, timeout=900):
                print(f'RUN  {name}', flush=True)
                status, duration, content = execute(command, output / (name + '.log'), timeout)
                if status == 'SKIP' and strict:
                    status = 'FAIL'
                record(name, status, duration)
                if status != 'PASS':
                    print(content[-6000:], flush=True)
                return status != 'FAIL'

            project.configure('startup')
            if not run('parse', godot_command(extra=['--editor', '--quit'])):
                return 1
            if not run('startup', godot_command(extra=['--quit-after', '2'])):
                return 1
            ready = False
            for entry in entries:
                name = entry['id']
                missing = missing_requirements(entry)
                if missing:
                    record(name, 'FAIL' if strict else 'SKIP', reason='Missing: ' + ', '.join(missing))
                    if strict and not args.keep_going:
                        break
                    continue
                if entry.get('fixtures') and not ready:
                    try:
                        identity = fixture_identity(args.godot)
                        current = fixtures_current(identity)
                    except (ValueError, OSError, subprocess.SubprocessError) as error:
                        record('large-city-fixtures', 'FAIL', reason=str(error))
                        break
                    if current:
                        record('large-city-fixtures', 'PASS', reason='Verified source, build, and output hashes; reused')
                    else:
                        project.configure('fixtures')
                        if not run('large-city-fixtures', godot_command('tools/build_large_city_fixtures.gd')):
                            break
                        (ROOT / 'local/large-cities/validation-build.json').write_text(json.dumps(identity, indent=2) + '\n')
                    ready = True
                project.configure(entry.get('state', name))
                extra = [a.replace('{references}', str(ROOT / 'references/SIMCITY2000')) for a in entry.get('args', [])]
                if 'python' in entry:
                    command = [sys.executable, str(ROOT / entry['python']), *extra]
                elif entry.get('driver') == 'gif':
                    command = [sys.executable, str(ROOT / 'tools/test_gif_decode.py'), '--godot', args.godot, '--project', str(project.path)]
                else:
                    command = godot_command(entry['script'], entry['lane'] == 'native', ['--', *extra] if extra else [])
                if not run(name, command, entry.get('timeout', float(os.environ.get('GODOT_TEST_TIMEOUT_SECONDS', '900')))) and not args.keep_going:
                    break
            run('diff-check', ['git', 'diff', '--check'])
        finally:
            project.close()
    totals = {status: sum(r['status'] == status for r in results) for status in ('PASS', 'FAIL', 'SKIP')}
    print(' '.join(f'{status}={count}' for status, count in totals.items()), flush=True)
    return int(totals['FAIL'] > 0)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(f'FAIL: {error}', file=sys.stderr)
        sys.exit(1)
