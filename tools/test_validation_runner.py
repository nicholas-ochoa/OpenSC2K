#!/usr/bin/env python3
"""Check selection, prerequisite failures, isolation, and false-positive protection."""
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import Mock, patch

import run_godot_check as godot_check
import validate_project as runner


class ValidationRunnerTest(unittest.TestCase):
    def test_fresh_projects_share_the_import_cache(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / 'checkout'
            (root / 'game').mkdir(parents=True)
            projects = []
            try:
                with patch.object(runner, 'ROOT', root):
                    for name in ('parse', 'worker'):
                        (Path(folder) / name).mkdir()
                        projects.append(runner.Project(Path(folder) / name))
                cache_file = projects[0].path / '.godot/imported-marker'
                cache_file.write_text('imported')
                self.assertEqual((projects[1].path / '.godot/imported-marker').read_text(), 'imported')
                self.assertEqual((root / 'game/.godot/imported-marker').read_text(), 'imported')
            finally:
                for project in projects:
                    project.close()

    def test_ci_selects_generated_data_tests_and_required_tools(self):
        entries = runner.registry()
        selected = runner.select(entries, ['ci'], [])
        self.assertTrue(selected)
        for entry in selected:
            self.assertEqual(entry['lane'], 'product')
            self.assertFalse(entry.get('fixtures'))
            self.assertLessEqual(set(entry.get('requires', [])), {'ffmpeg', 'pillow'})
        ids = {entry['id'] for entry in selected}
        self.assertTrue({'recorded_soundtrack_test', 'scurk_gif_export_test',
                         'no_assets_startup_test', 'binary_data_test'} <= ids)
        synthetic = [dict(id='fixture', lane='product', domain='formats', fixtures=['private'])]
        self.assertEqual(runner.select(synthetic, ['ci'], []), [])

    def test_parallel_bound_and_failure_drain(self):
        entered = threading.Barrier(2)
        release = threading.Event()
        active = set()
        lock = threading.Lock()
        completed = []

        def execute(entry):
            with lock:
                active.add(entry)
            entered.wait(timeout=5)
            if entry == 'slow':
                assert release.wait(timeout=5)
            with lock:
                active.remove(entry)
            return entry != 'fail'

        def finish(entry, result):
            completed.append(entry)
            if entry == 'fail':
                release.set()
            return result

        self.assertFalse(runner.run_parallel(['fail', 'slow', 'must-not-start'],
                                             2, execute, finish, False))
        self.assertCountEqual(completed, ['fail', 'slow'])
        self.assertFalse(active)
        completed.clear()
        self.assertTrue(runner.run_parallel(['fail', 'next'], 1,
                                            lambda entry: entry != 'fail', finish, True))
        self.assertEqual(completed, ['fail', 'next'])

    def test_groups_preserve_native_and_persistence_order_without_losing_checks(self):
        entries = runner.select(runner.registry(), ['release'], [])
        groups = runner.execution_groups(entries)
        self.assertCountEqual([entry['id'] for group in groups for entry in group],
                              [entry['id'] for entry in entries])
        native = [entry['id'] for entry in entries if entry['lane'] == 'native']
        native_groups = [group for group in groups if any(e['lane'] == 'native' for e in group)]
        self.assertEqual([[e['id'] for e in group] for group in native_groups], [native])
        history = [group for group in groups if group[0].get('state') == 'file-history']
        self.assertEqual([[e['args'] for e in group] for group in history], [[['write'], ['read']]])
        serial = runner.execution_groups(entries, parallel=False)
        self.assertEqual([e['id'] for group in serial for e in group], [e['id'] for e in entries])

    def test_registry_covers_every_script(self):
        entries = runner.registry()
        self.assertEqual(len({e['id'] for e in entries}), len(entries))

    def test_domains_keep_core_cases_and_history_dependency(self):
        entries = runner.registry()
        selected = runner.select(entries, ['formats', 'ui'], [])
        core = next(e for e in selected if e['id'] == 'test_runner')
        self.assertEqual(core['args'], ['{references}', 'formats', 'ui'])
        history = runner.select(entries, [], ['file_dialog_history_test_read'])
        self.assertEqual([e['args'] for e in history], [['write'], ['read']])
        with self.assertRaises(ValueError):
            runner.select(entries, [], ['missing-test'])

    def test_full_selects_full_workflow_once(self):
        selected = runner.select(runner.registry(), ['full', 'integration'], [])
        ids = [e['id'] for e in selected]
        self.assertNotIn('runtime_ui_smoke', ids)
        self.assertEqual(ids.count('runtime_ui_integration'), 1)
        self.assertIn('generated_city_simulation_test', ids)

    def test_routine_excludes_audits_and_native_only_checks(self):
        entries = runner.registry()
        selected = runner.select(entries, ['routine'], [])
        self.assertTrue(all(e['lane'] == 'product' for e in selected))
        native = runner.select(entries, ['native'], [])
        self.assertTrue(native)
        self.assertTrue(all(e['lane'] == 'native' for e in native))
        self.assertIn('city_gpu_geometry_test', {e['id'] for e in selected})

    def test_missing_and_unregistered_files_fail(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'tools').mkdir()
            (root / 'game/tests').mkdir(parents=True)
            manifest = root / 'tools/validation_tests.json'
            manifest.write_text(json.dumps([dict(id='gone', script='tests/gone.gd')]))
            with patch.object(runner, 'ROOT', root):
                with self.assertRaises(ValueError):
                    runner.registry()
                manifest.write_text('[]')
                (root / 'game/tests/new.gd').touch()
                with self.assertRaises(ValueError):
                    runner.registry()

    def test_script_error_and_timeout_cannot_pass(self):
        wrapper = runner.ROOT / 'tools/run_godot_check.py'
        for code, timeout in [("print('SCRIPT ERROR: fixture'); print('PASS');", '10'),
                              ('import time; time.sleep(10)', '0.1')]:
            result = subprocess.run([sys.executable, str(wrapper), sys.executable, '-c', code],
                                    env=dict(os.environ, GODOT_TEST_TIMEOUT_SECONDS=timeout),
                                    capture_output=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)

    def test_interleaved_engine_error_cannot_pass(self):
        code = ("import sys; print('Leaked instance: RefCounted - Reference ', end='', flush=True); "
                "print('ERROR: 45 resources still in use at exit.', file=sys.stderr)")
        with contextlib.redirect_stdout(io.StringIO()):
            status, _, content = runner.execute([sys.executable, '-c', code])
        self.assertEqual(status, 'FAIL')
        self.assertIn('Reference ERROR:', content)
        with contextlib.redirect_stdout(io.StringIO()):
            status, _, content = runner.execute([sys.executable, '-c', "print('PASS: no errors')"])
        self.assertEqual(status, 'PASS')
        self.assertEqual(content, 'PASS: no errors\n')

    def test_split_error_is_detected_during_read_and_exit_drain(self):
        marker = b'ERROR:'
        for exited in (False, True):
            for split in range(1, len(marker)):
                with self.subTest(exited=exited, split=split):
                    prefix = b'Leaked instance: RefCounted - Reference ' + marker[:split]
                    suffix = marker[split:] + b' resources still in use at exit.\n'
                    process = Mock()
                    pending = True

                    def spawn(*args, stdout, **kwargs):
                        stdout.write(prefix)
                        stdout.flush()

                        def poll():
                            nonlocal pending
                            if pending:
                                pending = False
                                stdout.write(suffix)
                                stdout.flush()
                                return 0 if exited else None
                            return 0

                        process.poll.side_effect = poll
                        return process

                    with io.TextIOWrapper(io.BytesIO(), write_through=True) as console, \
                            contextlib.redirect_stdout(console), \
                            patch.object(sys, 'argv', ['run', 'fixture']), \
                            patch.object(godot_check.subprocess, 'Popen', side_effect=spawn), \
                            patch.object(godot_check.time, 'sleep'):
                        self.assertEqual(godot_check.main(), 1)
                        self.assertEqual(console.buffer.getvalue(), prefix + suffix)
                    self.assertEqual(process.terminate.call_count, 0 if exited else 1)

    def test_skip_is_reported_separately(self):
        with contextlib.redirect_stdout(io.StringIO()) as console:
            status, _, _ = runner.execute([sys.executable, '-c', "print('SKIP: missing fixture')"],
                                          name='skip')
            self.assertEqual(status, 'SKIP')
        self.assertIn('[skip] SKIP: missing fixture', console.getvalue())
        with patch.object(runner.shutil, 'which', return_value=None):
            self.assertEqual(runner.missing_requirements({'requires': ['ffmpeg']}), ['ffmpeg'])

    def test_console_streams_before_exit_and_can_also_save_logs(self):
        with tempfile.TemporaryDirectory() as folder:
            marker = Path(folder) / 'received'
            log = Path(folder) / 'check.log'
            code = ('import pathlib, sys, time\n'
                    'print("ready", flush=True)\n'
                    'deadline = time.monotonic() + 3\n'
                    'marker = pathlib.Path(sys.argv[1])\n'
                    'while not marker.exists() and time.monotonic() < deadline: time.sleep(0.01)\n'
                    'assert marker.exists(), "Output was not streamed before exit"\n'
                    'print("done", file=sys.stderr)\n')
            report = runner.report

            def receive(message):
                report(message)
                if message == '[stream] ready':
                    marker.touch()

            with contextlib.redirect_stdout(io.StringIO()) as console, \
                    patch.object(runner, 'report', side_effect=receive):
                status, _, content = runner.execute([sys.executable, '-c', code, str(marker)],
                                                     log, name='stream')
            self.assertEqual(status, 'PASS')
            self.assertEqual(content, 'ready\ndone\n')
            self.assertEqual(log.read_text(), content)
            self.assertEqual(console.getvalue(), '[stream] ready\n[stream] done\n')

    def test_default_run_does_not_create_log_directory(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            with patch.object(sys, 'argv', ['validate']), \
                    patch.object(runner, 'ROOT', root), \
                    patch.object(runner, 'registry', return_value=[]), \
                    patch.object(runner, 'verify_city_fixtures'), \
                    patch.object(runner, 'Project'), \
                    patch.object(runner, 'execute', return_value=('PASS', 0, '')) as execute, \
                    contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(runner.main(), 0)
            self.assertEqual(len(execute.call_args_list), 3)
            self.assertTrue(all(call.args[1] is None for call in execute.call_args_list))
            self.assertEqual(list(root.iterdir()), [])

    def test_release_rejects_missing_prerequisite(self):
        entry = next(e for e in runner.registry() if e['id'] == 'recorded_soundtrack_test')
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / 'results'
            with patch.object(sys, 'argv', ['validate', '--suite', 'release', '--output', str(output)]), \
                    patch.object(runner, 'select', return_value=[entry]), \
                    patch.object(runner, 'missing_requirements', return_value=['ffmpeg']), \
                    patch.object(runner, 'execute', return_value=('PASS', 0, '')), \
                    contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(runner.main(), 1)
            results = json.loads((output / 'summary.json').read_text())['results']
            self.assertEqual(next(r['status'] for r in results if r['id'] == entry['id']), 'FAIL')

    def test_ci_rejects_missing_tools_and_runtime_skips(self):
        entry = next(e for e in runner.registry() if e['id'] == 'recorded_soundtrack_test')
        for missing in ([], ['ffmpeg']):
            with self.subTest(missing=missing), \
                    patch.object(sys, 'argv', ['validate', '--suite', 'ci']), \
                    patch.object(runner, 'select', return_value=[entry]), \
                    patch.object(runner, 'missing_requirements', return_value=missing), \
                    patch.object(runner, 'execute', return_value=('SKIP', 0, '')), \
                    contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(runner.main(), 1)

    def test_committed_city_fixture_hashes(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            target = root / 'game/tests/fixtures/cities'
            target.mkdir(parents=True)
            with patch.object(runner, 'ROOT', root):
                with self.assertRaisesRegex(ValueError, 'Missing committed'):
                    runner.verify_city_fixtures()
                for edge in (128, 256, 384, 512):
                    extension = 'SC2' if edge == 128 else 'sc2x'
                    path = target / f'generated-{edge}.{extension}'
                    path.write_bytes(str(edge).encode())
                    path.with_name(path.name + '.json').write_text(json.dumps(
                        {'output_sha256': runner.digest(path)}))
                runner.verify_city_fixtures()
                path.write_bytes(b'edited')
                with self.assertRaisesRegex(ValueError, 'hash mismatch'):
                    runner.verify_city_fixtures()
                self.assertEqual(path.read_bytes(), b'edited')

    def test_isolated_user_data_matches_godot(self):
        # Give concurrent engine processes separate settings and project files.
        user_paths = []
        def probe(marker):
            with tempfile.TemporaryDirectory() as folder:
                project = runner.Project(folder)
                try:
                    project.configure('probe')
                    (project.path / 'probe.gd').write_text(
                        'extends SceneTree\nfunc _init():\n'
                        '\tvar file = FileAccess.open("user://same-name.cfg", FileAccess.WRITE)\n'
                        f'\tfile.store_string("{marker}")\n\tfile.close()\n'
                        '\tprint("USER_PATH=", OS.get_user_data_dir())\n'
                        '\tprint("MARKER=", FileAccess.get_file_as_string("user://same-name.cfg"))\n\tquit()\n')
                    output = subprocess.check_output(['godot', '--headless', '--audio-driver', 'Dummy',
                                                      '--path', str(project.path), '--script', 'res://probe.gd'], text=True)
                    return project.user, output
                finally:
                    project.close()

        def check(marker, result):
            user, output = result
            self.assertIn('USER_PATH=' + str(user / 'probe'), output)
            self.assertIn('MARKER=' + marker, output)
            self.assertFalse(user.exists())
            user_paths.append(user)
            return True

        self.assertTrue(runner.run_parallel(['first', 'second'], 2, probe, check, False))
        self.assertEqual(len(set(user_paths)), 2)


if __name__ == '__main__':
    unittest.main()
