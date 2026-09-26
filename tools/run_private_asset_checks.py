#!/usr/bin/env python3
"""Run trusted asset checks with the normal validation output."""
import subprocess
import sys

import validate_project as runner


def private_entries():
    entries = runner.registry()
    public = {entry['id'] for entry in runner.select(entries, ['ci'], [])}
    return [entry for entry in runner.select(entries, ['full'], []) if entry['id'] not in public]


def main():
    ids = [entry['id'] for entry in private_entries()]
    if not ids:
        raise ValueError('No private asset checks selected')
    command = [sys.executable, str(runner.ROOT / 'tools/validate_project.py'),
               '--strict', '--keep-going']
    for name in ids:
        command.extend(['--test', name])
    return subprocess.run(command, cwd=runner.ROOT).returncode


if __name__ == '__main__':
    sys.exit(main())
