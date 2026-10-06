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

import build_fluidsynth

ROOT = Path(__file__).resolve().parents[1]


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checked_godot(godot, project, *arguments):
    subprocess.run([sys.executable, str(ROOT / 'tools/run_godot_check.py'), godot,
                    '--headless', '--audio-driver', 'Dummy', '--path', str(project),
                    *arguments], check=True)


def write_zip(package, folder, name, *directories):
    with zipfile.ZipFile(package, 'w', zipfile.ZIP_DEFLATED) as stream:
        for path in sorted(folder.rglob('*')):
            stream.write(path, Path(name) / path.relative_to(folder))
        for directory in directories:
            stream.writestr(f'{name}/{directory}', b'')
    with zipfile.ZipFile(package) as stream:
        assert stream.testzip() is None


# Native libraries are independent extensions with the same platform layout.
NATIVE_MODULES = ('simulation', 'rendering', 'formats', 'audio', 'scripting')
NATIVE_PLATFORMS = {
    'windows-x64': ('windows-x86_64', 'opensc2k_{}.dll', 'opensc2k_{}.dll'),
    'windows-arm64': ('windows-arm64', 'opensc2k_{}.dll', 'opensc2k_{}.dll'),
    'linux-x64': ('linux-x86_64', 'libopensc2k_{}.so', 'libopensc2k_{}.so'),
    'linux-arm64': ('linux-arm64', 'libopensc2k_{}.so', 'libopensc2k_{}.so'),
    'macos-universal': ('macos', 'libopensc2k_{}.dylib',
                        'OpenSC2K.app/Contents/Frameworks/libopensc2k_{}.dylib'),
}


# FluidSynth, beside the audio extension. Godot exports it from the [dependencies]
# section of opensc2k_audio.gdextension: (built file, file in the package)
FLUIDSYNTH = {
    'windows-x64': ('libfluidsynth-3.dll', 'libfluidsynth-3.dll'),
    'windows-arm64': ('libfluidsynth-3.dll', 'libfluidsynth-3.dll'),
    'linux-x64': ('libfluidsynth.so.3', 'libfluidsynth.so.3'),
    'linux-arm64': ('libfluidsynth.so.3', 'libfluidsynth.so.3'),
    'macos-universal': ('libfluidsynth.3.dylib', 'OpenSC2K.app/Contents/Frameworks/libfluidsynth.3.dylib'),
}


# The MIT General MIDI SoundFont that only the Linux packages include, beside the
# executable, as MuseScore 2.3.2 shipped it. Keep the file name in sync with
# BUNDLED_SOUND_SET in game/src/audio/sound_font_catalog.gd: (url, sha256, file name)
SOUNDFONT = ('https://raw.githubusercontent.com/musescore/MuseScore/v2.3.2/share/sound/FluidR3Mono_GM.sf3',
             'cfcd66d89e8386823400eca64934b14fbea7bf48ba1f00d21189af1262794ec2', 'FluidR3Mono_GM.sf3')


# (platform, export preset, exported binary)
PACKAGES = (
    ('windows-x64', 'Windows Desktop', 'OpenSC2K.exe'),
    ('windows-arm64', 'Windows Desktop arm64', 'OpenSC2K.exe'),
    ('linux-x64', 'Linux', 'OpenSC2K.x86_64'),
    ('linux-arm64', 'Linux arm64', 'OpenSC2K.arm64'),
    ('macos-universal', 'macOS', 'OpenSC2K.app'),
)


def install_native(native, project):
    """Copy each prebuilt extension, and FluidSynth beside the audio extension, into the exported project."""
    for module in NATIVE_MODULES:
        for folder, template, _ in NATIVE_PLATFORMS.values():
            library = template.format(module)
            source = native / f'opensc2k_{module}' / folder / library
            if not source.is_file():
                raise ValueError(f'Missing native {module} library: {source}')
            target = project / 'bin' / f'opensc2k_{module}' / folder / library
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    for platform, (library, _) in FLUIDSYNTH.items():
        folder = NATIVE_PLATFORMS[platform][0]
        source = native / 'opensc2k_audio' / folder / library
        if not source.is_file():
            raise ValueError(f'Missing FluidSynth library: {source}')
        shutil.copy2(source, project / 'bin' / 'opensc2k_audio' / folder / library)


def install_notices(source, folder, platform):
    """The notices and license texts of the third-party works in a package."""
    shutil.copy2(source / 'THIRD_PARTY_NOTICES.md', folder / 'THIRD_PARTY_NOTICES.md')
    shutil.copytree(source / 'game/assets/licenses/fluidsynth', folder / 'licenses' / 'fluidsynth')
    shutil.copytree(source / 'game/assets/licenses/quickjs', folder / 'licenses' / 'quickjs')
    shutil.copytree(source / 'game/assets/licenses/rust', folder / 'licenses' / 'rust')
    if platform.startswith('linux'):
        shutil.copytree(source / 'game/assets/licenses/fluidr3mono', folder / 'licenses' / 'fluidr3mono')


def install_soundfont(soundfont, folder, platform):
    """The Linux packages include a SoundFont beside the executable; the others use the system sound set."""
    if platform.startswith('linux'):
        shutil.copy2(soundfont, folder / SOUNDFONT[2])


def write_fluidsynth_source(package, work):
    """The corresponding source of the LGPL FluidSynth library in each package."""
    folder = build_fluidsynth.write_source_bundle(work / 'fluidsynth-source')
    write_zip(package, folder, package.stem)
    return package


def has_diskutil_image():
    """True on macOS 26 and later, where `diskutil image` replaces `hdiutil create`."""
    probe = subprocess.run(['diskutil', 'image', 'create', 'from', '--help'], capture_output=True)
    return probe.returncode == 0


def make_disk_image(folder, volume, image):
    """A compressed read-only disk image of `folder`. Older macOS versions use hdiutil."""
    if has_diskutil_image():
        subprocess.run(['diskutil', 'image', 'create', 'from', '--format', 'UDZO', '--volumeName', volume,
                        str(folder), str(image)], check=True)
    else:
        subprocess.run(['hdiutil', 'create', '-volname', volume, '-srcfolder', str(folder),
                        '-format', 'UDZO', str(image)], check=True)
    subprocess.run(['hdiutil', 'verify', str(image)], check=True)


def build(output, label, godot, native):
    if sys.platform != 'darwin':
        raise ValueError('Desktop packaging requires macOS to create and sign the app and DMG')
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.+-]{0,79}', label):
        raise ValueError('Invalid package label')
    output.mkdir(parents=True, exist_ok=False)
    soundfont = build_fluidsynth.download(*SOUNDFONT)
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    engine = subprocess.check_output([godot, '--version'], text=True).strip()
    with tempfile.TemporaryDirectory(prefix='opensc2k-export-') as temporary:
        work = Path(temporary)
        source = work / 'source'
        source.mkdir()
        archive = work / 'source.tar'
        with archive.open('wb') as stream:
            subprocess.run(['git', 'archive', commit, 'game', 'LICENSE', 'THIRD_PARTY_NOTICES.md', 'docs/install.md'],
                           cwd=ROOT, stdout=stream, check=True)
        with tarfile.open(archive) as stream:
            stream.extractall(source, filter='data')
        project = source / 'game'
        install_native(native, project)
        settings = (project / 'project.godot').read_text()
        version = re.search(r'^config/version="([^"]+)"', settings, re.M).group(1)
        # the headless renderer stores textures without a lock, so parallel
        # importers can lose a texture and fail the import with an engine error
        if '[editor]' in settings:
            raise ValueError('project.godot has an [editor] section; merge the import thread setting into it')
        (project / 'project.godot').write_text(settings + '\n[editor]\n\nimport/use_multiple_threads=false\n')
        checked_godot(godot, project, '--editor', '--import')
        packages = []
        for platform, preset, binary in PACKAGES:
            name = f'OpenSC2K-{label}-{platform}'
            folder = work / name
            folder.mkdir()
            checked_godot(godot, project, '--export-release', preset, str(folder / binary))
            shutil.copy2(source / 'LICENSE', folder / 'LICENSE.txt')
            shutil.copy2(source / 'docs/install.md', folder / 'INSTALL.md')
            install_notices(source, folder, platform)
            install_soundfont(soundfont, folder, platform)
            for module in NATIVE_MODULES:
                expected_library = NATIVE_PLATFORMS[platform][2].format(module)
                assert (folder / expected_library).is_file(), f'{platform} lacks native {module}'
            assert (folder / FLUIDSYNTH[platform][1]).is_file(), f'{platform} lacks FluidSynth'
            (folder / 'VERSION.txt').write_text(f'OpenSC2K {version}\nBuild: {label}\nCommit: {commit}\nGodot: {engine}\n')
            if platform.startswith('windows'):
                package = output / (name + '.zip')
                write_zip(package, folder, name)
                # the data folder beside the executable selects portable mode
                portable = output / (name + '-portable.zip')
                write_zip(portable, folder, name + '-portable', 'data/')
                packages.append(portable)
            elif platform.startswith('linux'):
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
                make_disk_image(folder, f'OpenSC2K {label}', package)
            packages.append(package)
        packages.append(write_fluidsynth_source(output / f'OpenSC2K-{label}-fluidsynth-source.zip', work))
    hashes = {path.name: sha256(path) for path in packages}
    (output / 'SHA256SUMS.txt').write_text(''.join(f'{value}  {name}\n' for name, value in sorted(hashes.items())))
    (output / 'build-info.json').write_text(json.dumps(dict(version=version, label=label, commit=commit,
                                                          engine=engine, sha256=hashes), indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--label', required=True)
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--native', type=Path, default=ROOT / 'game/bin',
                        help='Folder with each native extension and platform, as tools/build_native.py --package writes it')
    args = parser.parse_args()
    build(args.output.resolve(), args.label, args.godot, args.native.resolve())


if __name__ == '__main__':
    main()
