#!/usr/bin/env python3
"""Inspect, prepare, and publish a manually requested stable release."""
import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
from urllib.parse import quote

from publish_nightly import gh, package_files

VERSION = re.compile(r'v?((?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))')
ROOT = Path(__file__).resolve().parents[1]


def normalize(value):
    match = VERSION.fullmatch(value.strip())
    if not match or any(int(part) > 65535 for part in match[1].split('.')):
        raise ValueError('Use a version such as 0.1.1, with each number between 0 and 65535')
    return match[1]


def releases(repository):
    pages = json.loads(gh('api', '--paginate', '--slurp', f'repos/{repository}/releases?per_page=100'))
    return [release for page in pages for release in page]


def stable_releases(published):
    return sorted((r for r in published if not r['draft'] and not r['prerelease']),
                  key=lambda r: r['published_at'] or '', reverse=True)


def commit_notes(repository, commit, previous_tag=None):
    if subprocess.check_output(['git', 'rev-parse', '--is-shallow-repository'],
                               cwd=ROOT, text=True).strip() != 'false':
        raise ValueError('Release notes require full Git history')
    target = subprocess.check_output(['git', 'rev-parse', '--verify', '--end-of-options', f'{commit}^{{commit}}'],
                                     cwd=ROOT, text=True).strip()
    revision = target
    if previous_tag:
        previous = subprocess.check_output(
            ['git', 'rev-parse', '--verify', f'refs/tags/{previous_tag}^{{commit}}'], cwd=ROOT, text=True).strip()
        revision = f'{previous}..{target}'
    history = subprocess.check_output(['git', 'log', '--reverse', '--format=%H%x00%s', revision, '--'],
                                      cwd=ROOT, text=True)
    commits = [line.split('\0', 1) for line in history.splitlines()]
    label = f'Changes since {previous_tag}' if previous_tag else 'Commits in this release'
    notes = f'\n<details>\n<summary>{html.escape(label)} ({len(commits)} commits)</summary>\n\n<ul>\n'
    for sha, subject in commits:
        notes += (f'<li><a href="https://github.com/{repository}/commit/{sha}"><code>{sha[:8]}</code></a> '
                  f'{html.escape(subject)}</li>\n')
    notes += '</ul>\n\n'
    if previous_tag:
        notes += f'[Full comparison](https://github.com/{repository}/compare/{quote(previous_tag, safe="")}...{target})\n\n'
    return notes + '</details>\n'


def output(name, value):
    with Path(os.environ['GITHUB_OUTPUT']).open('a') as stream:
        stream.write(f'{name}={value}\n')


def summary(text):
    print(text)
    with Path(os.environ['GITHUB_STEP_SUMMARY']).open('a') as stream:
        stream.write(text + '\n')


def available(version, published):
    tag = 'v' + version
    if any(r['tag_name'] == tag for r in published):
        raise ValueError(f'{tag} already has a release or draft; it will not be overwritten')
    result = subprocess.run(['git', 'ls-remote', '--exit-code', '--tags', 'origin', f'refs/tags/{tag}'],
                            cwd=ROOT, capture_output=True, text=True)
    if result.returncode == 0:
        raise ValueError(f'{tag} already exists; it will not be moved')
    if result.returncode != 2:
        raise RuntimeError(result.stderr or 'Cannot check existing tags')


def inspect(requested, repository):
    published = releases(repository)
    stable = stable_releases(published)
    latest = f"[{stable[0]['tag_name']}]({stable[0]['html_url']})" if stable else 'None'
    summary(f'## Release\n\nMost recently published stable version: **{latest}**\n')
    version = normalize(requested)
    numbers = tuple(map(int, version.split('.')))
    existing = [normalize(r['tag_name']) for r in stable if VERSION.fullmatch(r['tag_name'])]
    if any(numbers <= tuple(map(int, prior.split('.'))) for prior in existing):
        raise ValueError('The new stable version must be higher than all published stable versions')
    available(version, published)
    summary(f'Requested version: **{version}**\n')
    output('version', version)


def prepare(version):
    path = ROOT / 'game/project.godot'
    text = path.read_text()
    current = re.search(r'^config/version="([^"]+)"$', text, re.M)
    if not current:
        raise ValueError('The project version is missing')
    if tuple(map(int, version.split('.'))) < tuple(map(int, normalize(current[1]).split('.'))):
        raise ValueError('The requested version is older than the project version')
    if current[1] != version:
        path.write_text(text[:current.start(1)] + version + text[current.end(1):])
        subprocess.run(['git', 'config', 'user.name', 'github-actions[bot]'], cwd=ROOT, check=True)
        subprocess.run(['git', 'config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com'],
                       cwd=ROOT, check=True)
        subprocess.run(['git', 'add', 'game/project.godot'], cwd=ROOT, check=True)
        subprocess.run(['git', 'commit', '-m', f'Release version {version}'], cwd=ROOT, check=True)
    # Never force-push over a concurrent change to main.
    subprocess.run(['git', 'push', 'origin', 'HEAD:refs/heads/main'], cwd=ROOT, check=True)
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    output('sha', commit)
    summary(f'Prepared **{version}** at `{commit}`. CI and packaging use this exact commit.')


def publish(version, folder, repository, commit, draft):
    files = package_files(folder, commit)
    info = json.loads(files['build-info.json'].read_text())
    if info['version'] != version or info['label'] != version:
        raise ValueError('Package version does not match the requested release')
    published = releases(repository)
    available(version, published)
    stable = stable_releases(published)
    tag = 'v' + version
    notes = (f'OpenSC2K {version}\n\n'
             'Includes Windows x64, Linux x64, and universal macOS packages, with SHA-256 checksums.\n\n'
             'Your own SimCity 2000 Special Edition for Windows 95 (1996) files are required. '
             'Original game assets are not included.\n\n'
             f'[Installation instructions](https://github.com/{repository}/blob/{commit}/docs/install.md)\n\n'
             'CI passed the generated-data suite, editor parsing, and startup checks with Dummy audio. '
             'The full local release suite and cross-platform gameplay checks are not run by this workflow.\n\n'
             'Windows packages are unsigned. The macOS app is ad-hoc signed and is not notarized. '
             'Linux requires GTK 3 and WebKitGTK 4.1.\n')
    notes += commit_notes(repository, commit, stable[0]['tag_name'] if stable else None)
    with tempfile.TemporaryDirectory(prefix='opensc2k-release-notes-') as temporary:
        notes_path = Path(temporary) / 'notes.md'
        notes_path.write_text(notes, encoding='utf-8')
        gh('release', 'create', tag, *map(str, files.values()), '--repo', repository, '--target', commit,
           '--draft', '--title', f'OpenSC2K {version}', '--notes-file', str(notes_path))
    remote = json.loads(gh('release', 'view', tag, '--repo', repository, '--json', 'assets'))['assets']
    if {asset['name'] for asset in remote} != set(files):
        raise ValueError('Uploaded asset list does not match the packages')
    for asset in remote:
        path = files[asset['name']]
        if (asset['state'] != 'uploaded' or asset['size'] != path.stat().st_size
                or asset['digest'] != 'sha256:' + hashlib.sha256(path.read_bytes()).hexdigest()):
            raise ValueError(f'Uploaded asset verification failed: {asset["name"]}')
    if not draft:
        gh('release', 'edit', tag, '--repo', repository, '--draft=false', '--latest')
    result = json.loads(gh('release', 'view', tag, '--repo', repository, '--json', 'isDraft,url'))
    if result['isDraft'] != draft:
        raise ValueError('Release publication state does not match the request')
    summary(f"{'Draft created' if draft else 'Published'}: [{tag}]({result['url']})")


def sync_hint(repository):
    stable = stable_releases(releases(repository))
    if not stable:
        raise ValueError('No published stable release is available')
    version = normalize(stable[0]['tag_name'])
    path = ROOT / '.github/workflows/release.yml'
    original = path.read_text()
    updated, count = re.subn(
        r"(?m)^        description: 'Version to release \(last published: [^']+\)'$",
        f"        description: 'Version to release (last published: {version})'", original)
    if count != 1:
        raise ValueError('Cannot find the release input version hint')
    if updated != original:
        path.write_text(updated)
        subprocess.run(['git', 'config', 'user.name', 'github-actions[bot]'], cwd=ROOT, check=True)
        subprocess.run(['git', 'config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com'],
                       cwd=ROOT, check=True)
        subprocess.run(['git', 'add', '.github/workflows/release.yml'], cwd=ROOT, check=True)
        subprocess.run(['git', 'commit', '-m', f'Update last published version to {version} [skip ci]'],
                       cwd=ROOT, check=True)
        subprocess.run(['git', 'push', 'origin', 'HEAD:refs/heads/main'], cwd=ROOT, check=True)
    summary(f'The release form now shows **{version}** as the last published version.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['inspect', 'prepare', 'publish', 'sync-hint'])
    parser.add_argument('--packages', type=Path)
    args = parser.parse_args()
    repository = os.environ['GITHUB_REPOSITORY']
    requested = os.environ.get('RELEASE_VERSION', '')
    if args.operation == 'sync-hint':
        sync_hint(repository)
    elif args.operation == 'inspect':
        inspect(requested, repository)
    elif args.operation == 'prepare':
        prepare(normalize(requested))
    else:
        publish(normalize(requested), args.packages, repository, os.environ['RELEASE_SHA'],
                os.environ.get('RELEASE_DRAFT') == 'true')


if __name__ == '__main__':
    main()
