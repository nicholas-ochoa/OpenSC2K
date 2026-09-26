#!/usr/bin/env python3
"""Protect stable releases and the last good nightly during publication failures."""
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import tempfile
import subprocess
import unittest
from unittest.mock import patch

import publish_nightly as nightly
import manual_release as stable


class CommitList(HTMLParser):
    def __init__(self, notes):
        super().__init__()
        self.links = []
        self.items = []
        self.current = None
        self.feed(notes)

    def handle_starttag(self, tag, attrs):
        if tag == 'li':
            self.current = ''
        elif tag == 'a':
            self.links.append(dict(attrs)['href'])

    def handle_data(self, data):
        if self.current is not None:
            self.current += data

    def handle_endtag(self, tag):
        if tag == 'li':
            self.items.append(self.current)
            self.current = None


class StableReleaseTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.git('init', '-b', 'main')
        self.git('config', 'user.name', 'Release test')
        self.git('config', 'user.email', 'release@example.test')
        self.tree = self.git('mktree', input='').strip()
        self.base = self.commit('Previous release')
        self.subject = 'Preserve <details> & *literal* [text] `code` — café'
        self.change = self.commit(self.subject, self.base)
        self.branch = self.commit('Branch change', self.base)
        self.target = self.commit('Merge branch', self.change, self.branch)
        self.later = self.commit('After this release', self.target)
        self.git('update-ref', 'refs/heads/main', self.later)
        self.git('tag', '-a', 'v0.1.0', self.base, '-m', 'Previous release')
        root = patch.object(stable, 'ROOT', self.folder)
        root.start()
        self.addCleanup(root.stop)

    def git(self, *args, input=None):
        return subprocess.run(['git', *args], cwd=self.folder, input=input, text=True,
                              capture_output=True, check=True).stdout

    def commit(self, subject, *parents):
        args = [value for parent in parents for value in ('-p', parent)]
        return self.git('commit-tree', self.tree, *args, '-m', subject).strip()

    def test_range_includes_branch_and_merge_but_excludes_base_and_later_commits(self):
        notes = stable.commit_notes('owner/repo', self.target, 'v0.1.0')
        parsed = CommitList(notes)
        expected = {self.change, self.branch, self.target}
        self.assertEqual(set(parsed.links), {f'https://github.com/owner/repo/commit/{sha}' for sha in expected})
        self.assertEqual(len(parsed.items), 3)
        self.assertIn(f'{self.change[:8]} {self.subject}', parsed.items)

    def test_first_release_includes_all_ancestors(self):
        parsed = CommitList(stable.commit_notes('owner/repo', self.target))
        self.assertEqual(len(parsed.items), 4)
        self.assertIn(f'https://github.com/owner/repo/commit/{self.base}', parsed.links)
        self.assertNotIn(f'https://github.com/owner/repo/commit/{self.later}', parsed.links)

    def test_no_new_commits_produces_empty_list(self):
        self.assertEqual(CommitList(stable.commit_notes('owner/repo', self.base, 'v0.1.0')).items, [])

    def test_missing_tag_or_shallow_history_fails_instead_of_omitting_commits(self):
        with self.assertRaises(subprocess.CalledProcessError):
            stable.commit_notes('owner/repo', self.target, 'missing')
        clone = self.folder / 'shallow'
        self.git('clone', '--depth=1', self.folder.as_uri(), str(clone))
        with patch.object(stable, 'ROOT', clone), self.assertRaises(ValueError):
            stable.commit_notes('owner/repo', 'HEAD')

    def test_publish_uses_last_published_stable_release_and_exact_build_commit(self):
        info = self.folder / 'build-info.json'
        info.write_text(json.dumps(dict(version='0.1.1', label='0.1.1')))
        published = [
            dict(tag_name='nightly', draft=False, prerelease=True, published_at='2026-09-26'),
            dict(tag_name='v0.2.0', draft=True, prerelease=False, published_at=None),
            dict(tag_name='v0.0.9', draft=False, prerelease=False, published_at='2026-09-24'),
            dict(tag_name='v0.1.0', draft=False, prerelease=False, published_at='2026-09-25'),
        ]
        created = []

        def respond(*args):
            if args[:2] == ('release', 'create'):
                self.assertEqual(args[args.index('--target') + 1], self.target)
                created.append(Path(args[args.index('--notes-file') + 1]).read_text())
            elif args[:2] == ('release', 'view'):
                if args[-1] == 'assets':
                    return json.dumps(dict(assets=[dict(name=info.name, size=info.stat().st_size, state='uploaded',
                        digest='sha256:' + hashlib.sha256(info.read_bytes()).hexdigest())]))
                return json.dumps(dict(isDraft=False, url='https://example.test/release'))
            return ''

        with patch.object(stable, 'releases', return_value=published), patch.object(stable, 'available'), \
                patch.object(stable, 'package_files', return_value={info.name: info}), \
                patch.object(stable, 'summary'), patch.object(stable, 'gh', side_effect=respond):
            stable.publish('0.1.1', self.folder, 'owner/repo', self.target, False)
        self.assertEqual(len(created), 1)
        parsed = CommitList(created[0])
        self.assertEqual(set(parsed.links), {f'https://github.com/owner/repo/commit/{sha}'
                                           for sha in (self.change, self.branch, self.target)})


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

    def test_failed_draft_is_removed_without_deleting_a_missing_tag(self):
        self.old['draft'] = True
        with patch.object(nightly, 'gh', side_effect=self.respond):
            self.publish()
        deletes = [c for c in self.calls if c[:2] == ('release', 'delete')]
        self.assertEqual(len(deletes), 1)
        self.assertNotIn('--cleanup-tag', deletes[0])

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
