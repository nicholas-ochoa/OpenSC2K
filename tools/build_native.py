#!/usr/bin/env python3
"""Build the native simulation library and copy it into the Godot project."""
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


def build(profile='release', quiet=False):
    """Build the host library. Cargo skips the work when the sources are unchanged."""
    if shutil.which('cargo') is None:
        raise OSError('cargo is required to build the native simulation (https://rustup.rs)')
    command = ['cargo', 'build', '--manifest-path', str(CRATE / 'Cargo.toml')]
    if profile == 'release':
        command.append('--release')
    if quiet:
        command.append('--quiet')
    subprocess.run(command, cwd=CRATE, check=True)
    built = CRATE / 'target' / profile / library_name()
    target = OUTPUT / host_folder() / library_name()
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists() or target.read_bytes() != built.read_bytes():
        # Replace the file instead of writing over it. macOS stops new processes
        # that load a signed library whose file changed while it was mapped.
        staged = target.with_name(target.name + '.new')
        shutil.copy2(built, staged)
        os.replace(staged, target)
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--debug', action='store_true', help='Build without optimizations')
    args = parser.parse_args()
    target = build('debug' if args.debug else 'release')
    print(f'Native simulation: {target.relative_to(ROOT)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
