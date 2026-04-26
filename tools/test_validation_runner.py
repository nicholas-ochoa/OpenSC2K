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
import unittest
from unittest.mock import patch

import validate_project as runner


class ValidationRunnerTest(unittest.TestCase):
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
        self.assertIn('stitched_city_test', ids)
        self.assertTrue(any(e['lane'] == 'audit' for e in selected))

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

    def test_skip_is_reported_separately(self):
        with tempfile.TemporaryDirectory() as folder:
            status, _, _ = runner.execute([sys.executable, '-c', "print('SKIP: missing fixture')"],
                                          Path(folder) / 'skip.log')
            self.assertEqual(status, 'SKIP')
        with patch.object(runner.shutil, 'which', return_value=None):
            self.assertEqual(runner.missing_requirements({'requires': ['ffmpeg']}), ['ffmpeg'])

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

    def test_edited_fixture_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            target = root / 'local/large-cities'
            target.mkdir(parents=True)
            (target / 'validation-build.json').write_text('{}')
            (target / 'stitched-256.sc2x').write_bytes(b'edited')
            (target / 'stitched-256.sc2x.json').write_text('{"output_sha256": "old"}')
            with patch.object(runner, 'ROOT', root):
                with self.assertRaises(ValueError):
                    runner.fixtures_current({})

    def test_isolated_user_data_matches_godot(self):
        # Test the actual engine setting: an absolute custom directory is sanitized.
        with tempfile.TemporaryDirectory() as folder:
            project = runner.Project(folder)
            try:
                project.configure('probe')
                (project.path / 'probe.gd').write_text('extends SceneTree\nfunc _init():\n\tprint("USER_PATH=", OS.get_user_data_dir())\n\tquit()\n')
                output = subprocess.check_output(['godot', '--headless', '--audio-driver', 'Dummy',
                                                  '--path', str(project.path), '--script', 'res://probe.gd'], text=True)
                self.assertIn('USER_PATH=' + str(project.user / 'probe'), output)
            finally:
                project.close()
            self.assertFalse(project.user.exists())


if __name__ == '__main__':
    unittest.main()
