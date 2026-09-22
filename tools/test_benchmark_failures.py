#!/usr/bin/env python3
"""Exercise benchmark success and injected workload failures."""
import os
import tempfile

from validate_project import Project, ROOT, execute


def main():
    cases = [
        ('growth_partition_benchmark.gd', 'GrowthScan.run(city, random, step, substep, lfsr, game)',
         'GrowthScan._failed("injected growth failure")', 'injected growth failure'),
        ('determinism_probe.gd', 'engine.advance_day()',
         'SimulationDayResult.failure("injected day failure")', 'injected day failure'),
    ]
    with tempfile.TemporaryDirectory(prefix='city-benchmark-failures-') as temporary:
        project = Project(temporary)
        try:
            project.configure('benchmark-failures')
            command = [os.environ.get('GODOT', 'godot'), '--headless', '--audio-driver', 'Dummy',
                       '--path', str(project.path), '--script']
            if not (project.path / '.godot/global_script_class_cache.cfg').is_file():
                result, _, _ = execute([*command[:-1], '--editor', '--quit'], timeout=30)
                if result != 'PASS':
                    raise ValueError('Cannot import the benchmark test project')

            for name, original, replacement, message in cases:
                source = (ROOT / 'game/tools/benchmarks' / name).read_text()
                if source.count(original) != 1:
                    raise ValueError(f'Cannot locate the workload call in {name}')
                script = project.path / ('failure_' + name)
                script.write_text(source.replace(original, replacement))
                result, _, output = execute([*command, 'res://' + script.name], timeout=20)
                if result != 'FAIL' or message not in output or 'SCRIPT ERROR:' in output:
                    raise ValueError(f'{name} did not reject the injected workload failure')
                print(f'PASS {name} rejects failed work')

            source = (ROOT / 'game/tools/benchmarks/growth_partition_benchmark.gd').read_text()
            script = project.path / 'successful_growth.gd'
            script.write_text(source.replace('const ROUNDS := 5', 'const ROUNDS := 1'))
            result, _, _ = execute([*command, 'res://' + script.name], timeout=20)
            if result != 'PASS':
                raise ValueError('The valid growth workload failed')
            print('PASS valid growth workload')
        finally:
            project.close()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
