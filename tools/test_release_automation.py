#!/usr/bin/env python3
"""Protect stable releases and the last good nightly during publication failures."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import publish_nightly as nightly


class NightlyTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.commit = 'a' * 40
        hashes = {}
        for platform in ('windows-x64.zip', 'linux-x64.tar.gz', 'macos-universal.dmg'):
            name = f'OpenSC2K-nightly-aaaaaaaa-{platform}'
            (self.folder / name).write_bytes(platform.encode())
            hashes[name] = hashlib.sha256(platform.encode()).hexdigest()
        (self.folder / 'build-info.json').write_text(json.dumps(dict(commit=self.commit, label='nightly-aaaaaaaa', sha256=hashes)))
        (self.folder / 'SHA256SUMS.txt').write_text(''.join(f'{value}  {name}\n' for name, value in sorted(hashes.items())))
        self.assets = [dict(name=p.name, size=p.stat().st_size, state='uploaded',
                            digest='sha256:' + hashlib.sha256(p.read_bytes()).hexdigest()) for p in self.folder.iterdir()]
        self.old = dict(tag_name='nightly-20260101-10-1', prerelease=True, draft=False, body=nightly.MARKER)
        self.stable = dict(tag_name='v0.1.0', prerelease=False, draft=False, body='Stable release')
        self.calls = []

    def respond(self, *args):
        self.calls.append(args)
        if args[0] == 'api':
            return json.dumps([[self.stable, self.old]])
        if args[:2] == ('release', 'view'):
            if args[-1] == 'assets':
                return json.dumps(dict(assets=self.assets))
            return json.dumps(dict(isDraft=False, url='https://example.test/nightly'))
        return ''

    def publish(self):
        nightly.publish(self.folder, 'owner/repo', self.commit, 20, 1)

    def test_publish_verifies_upload_before_deleting_only_older_nightly(self):
        with patch.object(nightly, 'gh', side_effect=self.respond):
            self.publish()
        deletes = [c for c in self.calls if c[:2] == ('release', 'delete')]
        self.assertEqual(len(deletes), 1)
        self.assertEqual(deletes[0][2], self.old['tag_name'])
        self.assertIn('--cleanup-tag', deletes[0])
        publish_index = next(i for i, c in enumerate(self.calls) if c[:2] == ('release', 'edit'))
        self.assertGreater(self.calls.index(deletes[0]), publish_index)

    def test_upload_or_publish_failure_preserves_previous_release(self):
        for operation in ('create', 'edit'):
            with self.subTest(operation=operation):
                self.calls.clear()

                def fail(*args):
                    if args[:2] == ('release', operation):
                        raise RuntimeError('GitHub failure')
                    return self.respond(*args)

                with patch.object(nightly, 'gh', side_effect=fail), self.assertRaises(RuntimeError):
                    self.publish()
                self.assertFalse(any(c[:2] == ('release', 'delete') for c in self.calls))

    def test_remote_hash_mismatch_prevents_publish_and_cleanup(self):
        self.assets[0]['digest'] = 'sha256:bad'
        with patch.object(nightly, 'gh', side_effect=self.respond), self.assertRaises(ValueError):
            self.publish()
        self.assertFalse(any(c[:2] in [('release', 'edit'), ('release', 'delete')] for c in self.calls))

    def test_invalid_package_or_commit_never_contacts_github(self):
        with patch.object(nightly, 'gh') as gh:
            with self.assertRaises(ValueError):
                nightly.package_files(self.folder, 'b' * 40)
            next(self.folder.glob('*.zip')).write_bytes(b'changed')
            with self.assertRaises(ValueError):
                self.publish()
            gh.assert_not_called()

    def test_cleanup_requires_reserved_tag_prerelease_and_workflow_marker(self):
        for changes in [dict(tag_name='v0.1.0'), dict(tag_name='nightly'), dict(prerelease=False), dict(body='')]:
            self.assertIsNone(nightly.nightly_order(dict(self.old, **changes)))
        self.assertEqual(nightly.nightly_order(self.old), (10, 1))

    def test_out_of_order_run_does_not_replace_newer_nightly(self):
        self.old['tag_name'] = 'nightly-20260101-30-1'
        with patch.object(nightly, 'gh', side_effect=self.respond):
            self.publish()
        self.assertEqual(len(self.calls), 1)


if __name__ == '__main__':
    unittest.main()
