#!/usr/bin/env python3
"""Build OpenSC2K for this Mac and install it as /Applications/OpenSC2K.app.

One step: build the native libraries and FluidSynth for this Mac's
architecture only (tools/build_native.py), export a copy of the Godot project
with the macOS preset, add the Icon Composer icon, sign the app ad hoc, and
replace the app in the target folder. The old app stays until the new one is
complete. The export uses the working tree, with its changes.

The Godot export templates have only a universal macOS executable, so the app
runs Godot's universal executable with native libraries of this Mac's
architecture. Use tools/build_desktop_release.py for a universal package.

  python3 tools/install_macos_app.py               # build, export and install
  python3 tools/install_macos_app.py --no-build    # export the last native build again
  python3 tools/install_macos_app.py --destination ~/Applications

Set GODOT to the Godot editor when `godot` is not on the PATH.
"""
import argparse
import functools
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile

import build_desktop_release as release
import build_native

ROOT = Path(__file__).resolve().parents[1]
APP_NAME = 'OpenSC2K.app'
MACOS_PRESET = 'macOS'
LSREGISTER = ('/System/Library/Frameworks/CoreServices.framework/Frameworks/'
              'LaunchServices.framework/Support/lsregister')
# the messages of this script keep their order among the build output
print = functools.partial(print, flush=True)


def architecture():
    """The Godot export architecture of this Mac."""
    return 'arm64' if platform.machine().lower() in ('arm64', 'aarch64') else 'x86_64'


def prepare_project(project):
    """Import the textures of the project copy on one thread, as the release build does."""
    settings_path = project / 'project.godot'
    settings = settings_path.read_text()

    if '[editor]' not in settings:
        settings_path.write_text(settings + '\n[editor]\n\nimport/use_multiple_threads=false\n')


def running_from(app):
    """True when a process runs the executable of `app`."""
    probe = subprocess.run(['pgrep', '-f', str(app / 'Contents/MacOS/')], capture_output=True)
    return probe.returncode == 0


def install(app, destination):
    """Copy `app` beside `destination`, then swap it in, so a failed copy keeps the old app."""
    staged = destination.with_name(destination.name + '.new')
    old = destination.with_name(destination.name + '.old')

    for path in (staged, old):
        if path.exists():
            shutil.rmtree(path)

    # ditto keeps the code signature and the extended attributes of the bundle
    subprocess.run(['ditto', str(app), str(staged)], check=True)

    if destination.exists():
        destination.rename(old)

    staged.rename(destination)

    if old.exists():
        shutil.rmtree(old)

    if Path(LSREGISTER).exists():
        subprocess.run([LSREGISTER, '-f', str(destination)], check=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--no-build', action='store_true', help='Export the native libraries of the last build')
    parser.add_argument('--destination', type=Path, default=Path('/Applications'),
                        help='The folder of the app (default: /Applications)')
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'), help='The Godot editor')
    args = parser.parse_args()

    if sys.platform != 'darwin':
        print('This script builds the macOS app; run it on macOS.', file=sys.stderr)
        return 1

    if shutil.which(args.godot) is None and not Path(args.godot).is_file():
        print(f'Cannot find Godot ({args.godot}). Set GODOT or use --godot.', file=sys.stderr)
        return 1

    destination = args.destination.expanduser().resolve() / APP_NAME

    if running_from(destination):
        print(f'{destination} is running. Quit OpenSC2K, then run this script again.', file=sys.stderr)
        return 1

    arch = architecture()

    if not args.no_build:
        print(f'Building the native libraries and FluidSynth for {arch}...')
        build_native.build('release')

    with tempfile.TemporaryDirectory(prefix='opensc2k-app-') as work:
        work = Path(work)
        project = work / 'game'
        shutil.copytree(ROOT / 'game', project, symlinks=True, ignore=shutil.ignore_patterns('.DS_Store'))
        prepare_project(project)

        print('Importing the Godot project...')
        release.checked_godot(args.godot, project, '--editor', '--import')
        print(f'Exporting {APP_NAME}...')
        app = work / 'export' / APP_NAME
        app.parent.mkdir()
        release.checked_godot(args.godot, project, '--export-release', MACOS_PRESET, str(app))

        release.add_app_icon(app)
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)

        try:
            install(app, destination)
        except PermissionError:
            print(f'Cannot write {destination.parent}. Run with sudo, or use --destination ~/Applications.',
                  file=sys.stderr)
            return 1

    print(f'Installed {destination}')
    return 0


if __name__ == '__main__':
    os.chdir(ROOT)
    sys.exit(main())
