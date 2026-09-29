#!/usr/bin/env python3
"""Build the native simulation library and copy it into the Godot project.

With no options, build the library for this computer. Use --package to build
the library that a desktop package needs on this platform: a universal library
on macOS, and the x86_64 library on Windows and Linux.
"""
import argparse
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CRATE = ROOT / 'native/simulation'
OUTPUT = ROOT / 'game/bin/opensc2k_simulation'
NAME = 'opensc2k_simulation'
# the library of each package platform, as the .gdextension file names it
PACKAGE_LIBRARIES = {
    'macos': f'lib{NAME}.dylib',
    'linux-x86_64': f'lib{NAME}.so',
    'windows-x86_64': f'{NAME}.dll',
}
MACOS_TARGETS = ('aarch64-apple-darwin', 'x86_64-apple-darwin')


def host_folder():
    machine = platform.machine().lower()
    arch = 'arm64' if machine in ('arm64', 'aarch64') else 'x86_64'
    if sys.platform == 'darwin':
        return 'macos'
    if sys.platform == 'win32':
        return f'windows-{arch}'
    return f'linux-{arch}'


def library_name():
    if sys.platform == 'darwin':
        return f'lib{NAME}.dylib'
    if sys.platform == 'win32':
        return f'{NAME}.dll'
    return f'lib{NAME}.so'


def _cargo(arguments, quiet):
    if shutil.which('cargo') is None:
        raise OSError('cargo is required to build the native simulation (https://rustup.rs)')
    command = ['cargo', *arguments, '--manifest-path', str(CRATE / 'Cargo.toml')]
    if quiet:
        command.append('--quiet')
    subprocess.run(command, cwd=CRATE, check=True)


def _install(built, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists() or target.read_bytes() != built.read_bytes():
        # Replace the file instead of writing over it. macOS stops new processes
        # that load a signed library whose file changed while it was mapped.
        staged = target.with_name(target.name + '.new')
        shutil.copy2(built, staged)
        os.replace(staged, target)
    return target


def build(profile='release', quiet=False):
    """Build the host library. Cargo skips the work when the sources are unchanged."""
    _cargo(['build', *(['--release'] if profile == 'release' else [])], quiet)
    built = CRATE / 'target' / profile / library_name()
    return _install(built, OUTPUT / host_folder() / library_name())


def build_package(quiet=False):
    """Build the release library of a desktop package for this platform."""
    if sys.platform == 'darwin':
        slices = []
        for triple in MACOS_TARGETS:
            subprocess.run(['rustup', 'target', 'add', triple], cwd=CRATE, check=True)
            _cargo(['build', '--release', '--target', triple], quiet)
            slices.append(str(CRATE / 'target' / triple / 'release' / library_name()))
        universal = CRATE / 'target' / 'universal' / library_name()
        universal.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['lipo', '-create', *slices, '-output', str(universal)], check=True)
        return _install(universal, OUTPUT / 'macos' / library_name())
    if host_folder() not in PACKAGE_LIBRARIES:
        raise OSError(f'desktop packages do not include {host_folder()}')
    return build('release', quiet)


def test(quiet=False):
    """Run the native simulation unit tests."""
    command = ['cargo', 'test', '--release', '--manifest-path', str(CRATE / 'Cargo.toml')]
    if quiet:
        command.append('--quiet')
    subprocess.run(command, cwd=CRATE, check=True, capture_output=quiet)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--debug', action='store_true', help='Build without optimizations')
    parser.add_argument('--package', action='store_true', help='Build the library of a desktop package')
    args = parser.parse_args()
    target = build_package() if args.package else build('debug' if args.debug else 'release')
    print(f'Native simulation: {target.relative_to(ROOT)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
