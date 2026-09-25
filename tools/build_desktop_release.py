#!/usr/bin/env python3
"""Build desktop packages from the committed tree on macOS."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checked_godot(godot, project, *arguments):
    subprocess.run([sys.executable, str(ROOT / 'tools/run_godot_check.py'), godot,
                    '--headless', '--audio-driver', 'Dummy', '--path', str(project),
                    *arguments], check=True)


def build(output, label, godot):
    if sys.platform != 'darwin':
        raise ValueError('Desktop packaging requires macOS to create and sign the app and DMG')
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.+-]{0,79}', label):
        raise ValueError('Invalid package label')
    output.mkdir(parents=True, exist_ok=False)
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    engine = subprocess.check_output([godot, '--version'], text=True).strip()
    with tempfile.TemporaryDirectory(prefix='opensc2k-export-') as temporary:
        work = Path(temporary)
        source = work / 'source'
        source.mkdir()
        archive = work / 'source.tar'
        with archive.open('wb') as stream:
            subprocess.run(['git', 'archive', commit, 'game', 'LICENSE', 'docs/install.md'],
                           cwd=ROOT, stdout=stream, check=True)
        with tarfile.open(archive) as stream:
            stream.extractall(source, filter='data')
        project = source / 'game'
        version = re.search(r'^config/version="([^"]+)"',
                            (project / 'project.godot').read_text(), re.M).group(1)
        checked_godot(godot, project, '--editor', '--import')
        packages = []
        for platform, preset, binary in [('windows-x64', 'Windows Desktop', 'OpenSC2K.exe'),
                                        ('linux-x64', 'Linux', 'OpenSC2K.x86_64'),
                                        ('macos-universal', 'macOS', 'OpenSC2K.app')]:
            name = f'OpenSC2K-{label}-{platform}'
            folder = work / name
            folder.mkdir()
            checked_godot(godot, project, '--export-release', preset, str(folder / binary))
            shutil.copy2(source / 'LICENSE', folder / 'LICENSE.txt')
            shutil.copy2(source / 'docs/install.md', folder / 'INSTALL.md')
            (folder / 'VERSION.txt').write_text(f'OpenSC2K {version}\nBuild: {label}\nCommit: {commit}\nGodot: {engine}\n')
            if platform == 'windows-x64':
                assert (folder / 'godot_wry.dll').is_file()
                package = output / (name + '.zip')
                with zipfile.ZipFile(package, 'w', zipfile.ZIP_DEFLATED) as stream:
                    for path in sorted(folder.rglob('*')):
                        stream.write(path, Path(name) / path.relative_to(folder))
                with zipfile.ZipFile(package) as stream:
                    assert stream.testzip() is None
            elif platform == 'linux-x64':
                assert (folder / 'libgodot_wry.so').is_file()
                (folder / binary).chmod(0o755)
                package = output / (name + '.tar.gz')
                with tarfile.open(package, 'w:gz') as stream:
                    stream.add(folder, arcname=name)
                with tarfile.open(package) as stream:
                    assert stream.getmember(f'{name}/{binary}').mode & 0o111
            else:
                subprocess.run(['codesign', '--verify', '--deep', '--strict', str(folder / binary)], check=True)
                (folder / 'Applications').symlink_to('/Applications')
                package = output / (name + '.dmg')
                subprocess.run(['hdiutil', 'create', '-volname', f'OpenSC2K {label}',
                                '-srcfolder', str(folder), '-format', 'UDZO', str(package)], check=True)
                subprocess.run(['hdiutil', 'verify', str(package)], check=True)
            packages.append(package)
    hashes = {path.name: sha256(path) for path in packages}
    (output / 'SHA256SUMS.txt').write_text(''.join(f'{value}  {name}\n' for name, value in sorted(hashes.items())))
    (output / 'build-info.json').write_text(json.dumps(dict(version=version, label=label, commit=commit,
                                                          engine=engine, sha256=hashes), indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--label', required=True)
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    args = parser.parse_args()
    build(args.output.resolve(), args.label, args.godot)


if __name__ == '__main__':
    main()
