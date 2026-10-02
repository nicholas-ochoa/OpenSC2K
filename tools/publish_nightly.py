#!/usr/bin/env python3
"""Replace the single nightly release and tag with verified packages from this workflow."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

TAG = 'nightly'
MARKER = '<!-- opensc2k-nightly -->'
RUN = re.compile(r'<!-- opensc2k-nightly run=(\d+) attempt=(\d+) -->')
# Earlier workflows used one dated tag per run. Remove those as well.
LEGACY_TAG = re.compile(r'nightly-\d{8}-(\d+)-(\d+)')
DRAFT_TAG = re.compile(r'nightly-draft-\d+-\d+')


def gh(*arguments):
    return subprocess.check_output(['gh', *arguments], text=True)


def nightly_order(release):
    if not release.get('prerelease'):
        return None
    body = release.get('body') or ''
    tag = release['tag_name']
    match = RUN.match(body)
    if match and (tag == TAG or DRAFT_TAG.fullmatch(tag)):
        return tuple(map(int, match.groups()))
    match = LEGACY_TAG.fullmatch(tag)
    if match and body.startswith(MARKER):
        return tuple(map(int, match.groups()))
    return None


# the desktop packages, and the corresponding source of their LGPL FluidSynth library
PACKAGE_SUFFIXES = ('windows-x64.zip', 'windows-x64-portable.zip', 'windows-arm64.zip', 'windows-arm64-portable.zip',
                    'linux-x64.tar.gz', 'linux-arm64.tar.gz', 'macos-universal.dmg', 'fluidsynth-source.zip')


def package_files(folder, commit):
    info = json.loads((folder / 'build-info.json').read_text())
    if info['commit'] != commit:
        raise ValueError('Packages do not match the tested commit')
    hashes = info['sha256']
    label = info['label']
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.+-]{0,79}', label):
        raise ValueError('Invalid package label')
    expected = {f'OpenSC2K-{label}-{suffix}' for suffix in PACKAGE_SUFFIXES}
    if set(hashes) != expected:
        raise ValueError('Expected the seven desktop packages and the FluidSynth source')
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
    today = datetime.now(timezone.utc).strftime('%Y-%m-%d')
    pages = json.loads(gh('api', '--paginate', '--slurp', f'repos/{repository}/releases?per_page=100'))
    releases = [release for page in pages for release in page]
    order = (run_id, attempt)
    if any(not r['draft'] and nightly_order(r) is not None and nightly_order(r) >= order for r in releases):
        print('A newer or identical nightly is already published; keep it.')
        return
    notes = (f'<!-- opensc2k-nightly run={run_id} attempt={attempt} -->\n'
             f'Automated nightly from `{commit}`, built {today}. This is a development build.\n\n'
             'Includes Windows x64 and arm64 (standard and portable), Linux x64 and arm64, and universal macOS packages, '
             'and the source of the LGPL FluidSynth library that they include. '
             'Your own SimCity 2000 Special Edition for Windows 95 (1996) files are required.\n\n'
             'CI passed the generated-data suite, editor parsing, and startup checks with Dummy audio. '
             'The full local release suite and cross-platform gameplay checks are not run here.\n\n'
             'Windows packages are unsigned. The macOS app is ad-hoc signed and is not notarized. '
             'Linux x64 needs GTK 3 and WebKitGTK 4.1. The arm64 packages cannot show the newspaper.\n\n'
             f'[Install instructions](https://github.com/{repository}/blob/{commit}/docs/install.md) · '
             f'[Build run](https://github.com/{repository}/actions/runs/{run_id})\n\n'
             'Each nightly replaces the previous one. Stable releases are kept.\n')
    # A draft does not create its tag, so the upload can finish before the old nightly is removed.
    draft = f'nightly-draft-{run_id}-{attempt}'
    gh('release', 'create', draft, *map(str, files.values()), '--repo', repository, '--target', commit,
       '--draft', '--prerelease', '--latest=false', '--title', f'Nightly {today} ({commit[:8]})', '--notes', notes)
    remote = json.loads(gh('release', 'view', draft, '--repo', repository, '--json', 'assets'))['assets']
    if {asset['name'] for asset in remote} != set(files):
        raise ValueError('Uploaded asset list does not match the packages')
    for asset in remote:
        local = files[asset['name']]
        if (asset['state'] != 'uploaded' or asset['size'] != local.stat().st_size
                or asset['digest'] != 'sha256:' + hashlib.sha256(local.read_bytes()).hexdigest()):
            raise ValueError(f'Uploaded asset verification failed: {asset["name"]}')
    for release in releases:
        previous = nightly_order(release)
        if previous is not None and previous < order:
            # GitHub creates the tag on publication, not when the draft is created.
            cleanup = [] if release['draft'] else ['--cleanup-tag']
            gh('release', 'delete', release['tag_name'], '--repo', repository, '--yes', *cleanup)
    # Publication must create the tag at this commit, so remove a tag that has no release.
    refs = json.loads(gh('api', f'repos/{repository}/git/matching-refs/tags/{TAG}'))
    if any(ref['ref'] == f'refs/tags/{TAG}' for ref in refs):
        gh('api', '--method', 'DELETE', f'repos/{repository}/git/refs/tags/{TAG}')
    gh('release', 'edit', draft, '--repo', repository, '--tag', TAG, '--draft=false', '--latest=false')
    published = json.loads(gh('release', 'view', TAG, '--repo', repository, '--json', 'isDraft,url'))
    if published['isDraft']:
        raise ValueError('Nightly is still a draft')
    print(published['url'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--packages', type=Path, required=True)
    args = parser.parse_args()
    publish(args.packages, os.environ['GITHUB_REPOSITORY'], os.environ['GITHUB_SHA'],
            int(os.environ['GITHUB_RUN_ID']), int(os.environ['GITHUB_RUN_ATTEMPT']))


if __name__ == '__main__':
    main()
