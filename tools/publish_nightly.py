#!/usr/bin/env python3
"""Publish verified packages, then remove older nightlies from this workflow."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

MARKER = '<!-- opensc2k-nightly -->'
TAG = re.compile(r'nightly-\d{8}-(\d+)-(\d+)')


def gh(*arguments):
    return subprocess.check_output(['gh', *arguments], text=True)


def nightly_order(release):
    match = TAG.fullmatch(release['tag_name'])
    if match and release.get('prerelease') and MARKER in (release.get('body') or ''):
        return tuple(map(int, match.groups()))
    return None


def package_files(folder, commit):
    info = json.loads((folder / 'build-info.json').read_text())
    if info['commit'] != commit:
        raise ValueError('Packages do not match the tested commit')
    hashes = info['sha256']
    label = info['label']
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.+-]{0,79}', label):
        raise ValueError('Invalid package label')
    expected = {f'OpenSC2K-{label}-{platform}' for platform in
                ('windows-x64.zip', 'linux-x64.tar.gz', 'macos-universal.dmg')}
    if set(hashes) != expected:
        raise ValueError('Expected exactly three platform packages')
    files = {path.name: path for path in folder.iterdir() if path.is_file()}
    if set(files) != expected | {'SHA256SUMS.txt', 'build-info.json'}:
        raise ValueError('Unexpected or missing release files')
    for name, digest in hashes.items():
        if hashlib.sha256(files[name].read_bytes()).hexdigest() != digest:
            raise ValueError(f'Package checksum mismatch: {name}')
    sums = ''.join(f'{digest}  {name}\n' for name, digest in sorted(hashes.items()))
    if files['SHA256SUMS.txt'].read_text() != sums:
        raise ValueError('Checksum manifest mismatch')
    return files


def publish(folder, repository, commit, run_id, attempt):
    files = package_files(folder, commit)
    today = datetime.now(timezone.utc).strftime('%Y%m%d')
    tag = f'nightly-{today}-{run_id}-{attempt}'
    pages = json.loads(gh('api', '--paginate', '--slurp', f'repos/{repository}/releases?per_page=100'))
    releases = [release for page in pages for release in page]
    order = (run_id, attempt)
    if any(not r['draft'] and nightly_order(r) is not None and nightly_order(r) >= order for r in releases):
        print('A newer or identical nightly is already published; keep it.')
        return
    notes = (f'{MARKER}\nAutomated nightly from `{commit}`. This is a development build.\n\n'
             'Includes Windows x64, Linux x64, and universal macOS packages. '
             'Your own SimCity 2000 Special Edition for Windows 95 (1996) files are required.\n\n'
             'CI passed the generated-data suite, editor parsing, and startup checks with Dummy audio. '
             'The full local release suite and cross-platform gameplay checks are not run here.\n\n'
             'Windows packages are unsigned. The macOS app is ad-hoc signed and is not notarized. '
             'Linux needs GTK 3 and WebKitGTK 4.1.\n\n'
             f'[Install instructions](https://github.com/{repository}/blob/{commit}/docs/install.md) · '
             f'[Build run](https://github.com/{repository}/actions/runs/{run_id})\n\n'
             'Only the newest successful nightly is retained. Stable releases are kept.\n')
    gh('release', 'create', tag, *map(str, files.values()), '--repo', repository, '--target', commit,
       '--draft', '--prerelease', '--latest=false', '--title', f'Nightly {today} ({commit[:8]})', '--notes', notes)
    remote = json.loads(gh('release', 'view', tag, '--repo', repository, '--json', 'assets'))['assets']
    if {asset['name'] for asset in remote} != set(files):
        raise ValueError('Uploaded asset list does not match the packages')
    for asset in remote:
        local = files[asset['name']]
        if (asset['state'] != 'uploaded' or asset['size'] != local.stat().st_size
                or asset['digest'] != 'sha256:' + hashlib.sha256(local.read_bytes()).hexdigest()):
            raise ValueError(f'Uploaded asset verification failed: {asset["name"]}')
    gh('release', 'edit', tag, '--repo', repository, '--draft=false', '--latest=false')
    # Do not delete the previous successful nightly until the new one is public.
    published = json.loads(gh('release', 'view', tag, '--repo', repository, '--json', 'isDraft,url'))
    if published['isDraft']:
        raise ValueError('Nightly is still a draft; retain previous nightlies')
    print(published['url'])
    for release in releases:
        previous = nightly_order(release)
        if previous is not None and previous < order:
            gh('release', 'delete', release['tag_name'], '--repo', repository, '--yes', '--cleanup-tag')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--packages', type=Path, required=True)
    args = parser.parse_args()
    publish(args.packages, os.environ['GITHUB_REPOSITORY'], os.environ['GITHUB_SHA'],
            int(os.environ['GITHUB_RUN_ID']), int(os.environ['GITHUB_RUN_ATTEMPT']))


if __name__ == '__main__':
    main()
