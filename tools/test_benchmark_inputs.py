#!/usr/bin/env python3
"""Parse every benchmark and check its default inputs without timed workloads."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(script, *arguments):
    command = [os.environ.get('GODOT', 'godot'), '--headless', '--audio-driver', 'Dummy',
               '--path', str(ROOT / 'game'), '-s', f'tools/benchmarks/{script.name}']
    command += ['--', *arguments]
    return subprocess.run(command, capture_output=True, text=True, timeout=15)


def main():
    result = run(ROOT / 'fixture_paths.gd', '--check-all-inputs')
    output = result.stdout + result.stderr
    print(output, end='')
    if result.returncode or 'SCRIPT ERROR:' in output or 'ERROR:' in output:
        return 1
    missing = run(ROOT / 'dialog_scene_benchmark.gd',
                  'res://__missing_benchmark_input__.tscn', '--check-inputs')
    if missing.returncode != 1 or 'Missing benchmark input:' not in missing.stderr:
        print('Missing input did not exit with code 1:', missing.stdout, missing.stderr)
        return 1
    print('PASS missing-input exit')
    return 0


if __name__ == '__main__':
    sys.exit(main())
