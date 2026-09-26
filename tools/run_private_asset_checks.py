#!/usr/bin/env python3
"""Run trusted asset checks without publishing raw logs or generated files."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

import validate_project as runner


def private_entries():
    entries = runner.registry()
    public = {entry['id'] for entry in runner.select(entries, ['ci'], [])}
    return [entry for entry in runner.select(entries, ['full'], []) if entry['id'] not in public]


def safe_report(summary, ids, returncode=0):
    """Copy only known check names and fixed status values into public output."""
    expected = ['parse', 'startup', 'generated-city-fixtures', *ids, 'diff-check']
    statuses = {}
    valid = True
    for result in summary['results']:
        name, status = result['id'], result['status']
        if name not in expected or name in statuses or status not in ('PASS', 'FAIL', 'SKIP'):
            valid = False
            continue
        statuses[name] = status
    lines = [f'{statuses.get(name, "NOT RUN")}: {name}' for name in expected]
    passed = returncode == 0 and valid and all(statuses.get(name) == 'PASS' for name in expected)
    lines.append('PASS: private asset checks' if passed else 'FAIL: private asset checks')
    return '\n'.join(lines) + '\n', passed


def main():
    try:
        ids = [entry['id'] for entry in private_entries()]
        if not ids:
            raise ValueError('Empty selection')
        with tempfile.TemporaryDirectory(prefix='opensc2k-private-checks-') as folder:
            output = Path(folder) / 'results'
            command = [sys.executable, str(runner.ROOT / 'tools/validate_project.py'),
                       '--strict', '--keep-going', '--output', str(output)]
            for name in ids:
                command.extend(['--test', name])
            print(f'Running {len(ids)} private asset checks. Raw output stays on the runner.', flush=True)
            with (Path(folder) / 'runner.log').open('wb') as log:
                result = subprocess.run(command, cwd=runner.ROOT, stdout=log, stderr=subprocess.STDOUT)
            report, passed = safe_report(json.loads((output / 'summary.json').read_text()), ids,
                                         result.returncode)
        # The temporary directory, including all raw logs, has already been removed.
        print(report, end='')
        if os.environ.get('GITHUB_STEP_SUMMARY'):
            with Path(os.environ['GITHUB_STEP_SUMMARY']).open('a') as summary:
                summary.write(report)
        return int(not passed)
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        # Exception messages can include asset-derived text. Do not print them.
        print('FAIL: private asset checks could not produce a complete safe report.')
        return 1


if __name__ == '__main__':
    sys.exit(main())
