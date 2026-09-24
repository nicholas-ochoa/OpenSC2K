#!/usr/bin/env python3
"""Profile a native city workload with disposable preferences and Dummy audio."""
import argparse
from contextlib import nullcontext
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time

from validate_project import Project


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--renderer', choices=('gl_compatibility', 'mobile'), default='gl_compatibility')
    parser.add_argument('--large-artwork', action='store_true', help='Use Large artwork at every zoom.')
    parser.add_argument('--moving-fps', choices=(5, 10, 20, 30, 60), type=int, default=20)
    parser.add_argument('--compare-overview', action='store_true', help='Compare Large and Small artwork at 10%% zoom.')
    parser.add_argument('--output', type=Path, help='Save the console log and macOS memory snapshots here.')
    args = parser.parse_args()
    if args.output:
        args.output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='city-resource-') as temporary:
        project = Project(temporary)
        project.configure('resource-profile')
        try:
            config = project.path / 'project.godot'
            text = config.read_text().replace('renderer/rendering_method.macos="mobile"',
                                            f'renderer/rendering_method.macos="{args.renderer}"')
            config.write_text(text.replace('window/size/mode=2', 'window/size/mode=0'))
            command = [os.environ.get('GODOT', 'godot'), '--path', str(project.path),
                       '--audio-driver', 'Dummy', '--rendering-method', args.renderer,
                       '--script', 'res://tools/benchmarks/resource_profile.gd']
            # Instruments records target environment variables. Inherit only runtime essentials.
            environment = {key: os.environ[key] for key in
                           ('PATH', 'HOME', 'TMPDIR', 'USER', 'LOGNAME', 'DISPLAY', 'WAYLAND_DISPLAY',
                            'XDG_RUNTIME_DIR', 'SystemRoot', 'APPDATA', 'LOCALAPPDATA') if key in os.environ}
            environment['GODOT_AUDIO_DRIVER'] = 'Dummy'
            environment['CITY_BENCH_LARGE_ARTWORK'] = '1' if args.large_artwork or args.compare_overview else '0'
            environment['CITY_BENCH_MOVING_FPS'] = str(args.moving_fps)
            environment['CITY_BENCH_OVERVIEW_COMPARISON'] = '1' if args.compare_overview else '0'
            environment['CITY_BENCH_LOAD_NOTE'] = os.environ.get('CITY_BENCH_LOAD_NOTE', 'not recorded')
            acknowledgement = project.path / 'profile-ack'
            if args.output and sys.platform == 'darwin':
                environment['CITY_BENCH_ACK'] = str(acknowledgement)
            output = (args.output / 'profile.log').open('w') if args.output else nullcontext()
            with output as log, subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                                 text=True, env=environment) as process:
                watchdog = threading.Timer(240, process.terminate)
                watchdog.start()
                failed = False
                stage_start = None

                def emit(line):
                    print(line, flush=True)
                    if log:
                        log.write(line + '\n')
                        log.flush()

                def cpu_seconds():
                    if os.name != 'posix':
                        return None
                    value = subprocess.run(['ps', '-p', str(process.pid), '-o', 'time='],
                                           capture_output=True, text=True, check=False).stdout.strip()
                    if not value or '-' in value:
                        return None
                    return sum(float(part) * 60 ** index for index, part in enumerate(reversed(value.split(':'))))

                emit(f'Profiling PID {process.pid}; backend {args.renderer}')
                try:
                    for line in process.stdout:
                        line = line.rstrip('\n')
                        emit(line)
                        if line.startswith('BEGIN '):
                            stage_start = (cpu_seconds(), time.monotonic())
                        if line.startswith('RESULT '):
                            stage = json.loads(line[7:])['stage']
                            current_cpu = cpu_seconds()
                            if stage_start and current_cpu is not None and stage_start[0] is not None:
                                elapsed = time.monotonic() - stage_start[1]
                                emit('CPU ' + json.dumps({'stage': stage, 'sample_seconds': elapsed,
                                     'one_core_percent': 100 * (current_cpu - stage_start[0]) / elapsed}))
                            if args.output and sys.platform == 'darwin':
                                snapshot = subprocess.run(['vmmap', '-summary', str(process.pid)],
                                                          capture_output=True, text=True, check=False, timeout=20)
                                (args.output / (stage + '-vmmap.txt')).write_text(snapshot.stdout + snapshot.stderr)
                                acknowledgement.write_text(stage)
                        if 'SCRIPT ERROR:' in line or 'ERROR:' in line:
                            failed = True
                            process.terminate()
                    return process.wait() or int(failed)
                finally:
                    watchdog.cancel()
        finally:
            project.close()


if __name__ == '__main__':
    raise SystemExit(main())
