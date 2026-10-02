#!/usr/bin/env python3
"""Build the native libraries and copy them into the Godot project.

With no options, build the library for this computer. Use --package to build
the library that a desktop package needs on this platform: a universal library
on macOS, and the x86_64 library on Windows and Linux.

The audio library loads FluidSynth at run time. This also builds the FluidSynth
shared library (tools/build_fluidsynth.py, which needs CMake) and downloads the
bundled SoundFonts (tools/fetch_soundfonts.py). Without them, music plays with
the built-in synthesizer.
"""
import argparse
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

import build_fluidsynth
import fetch_soundfonts

ROOT = Path(__file__).resolve().parents[1]
MODULES = ('simulation', 'rendering', 'formats', 'audio')
MACOS_TARGETS = ('aarch64-apple-darwin', 'x86_64-apple-darwin')


def host_folder():
    machine = platform.machine().lower()
    arch = 'arm64' if machine in ('arm64', 'aarch64') else 'x86_64'
    if sys.platform == 'darwin':
        return 'macos'
    if sys.platform == 'win32':
        return f'windows-{arch}'
    return f'linux-{arch}'


def library_name(module):
    name = f'opensc2k_{module}'
    if sys.platform == 'darwin':
        return f'lib{name}.dylib'
    if sys.platform == 'win32':
        return f'{name}.dll'
    return f'lib{name}.so'


def _cargo(module, arguments, quiet):
    crate = ROOT / 'native' / module
    if shutil.which('cargo') is None:
        raise OSError('cargo is required to build the native libraries (https://rustup.rs)')
    command = ['cargo', *arguments, '--manifest-path', str(crate / 'Cargo.toml')]
    if quiet:
        command.append('--quiet')
    subprocess.run(command, cwd=crate, check=True)


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
    """Build the host libraries. Cargo skips unchanged sources."""
    targets = []
    for module in MODULES:
        _cargo(module, ['build', *(['--release'] if profile == 'release' else [])], quiet)
        built = ROOT / 'native' / module / 'target' / profile / library_name(module)
        target = ROOT / 'game/bin' / f'opensc2k_{module}' / host_folder() / library_name(module)
        targets.append(_install(built, target))
    return targets + build_music_dependencies(quiet)


def build_music_dependencies(quiet=False):
    """Build FluidSynth and fetch the SoundFonts. Each step skips current output."""
    return build_fluidsynth.build(quiet=quiet) + fetch_soundfonts.fetch(quiet=quiet)


def build_package(quiet=False):
    """Build the release libraries of a desktop package for this platform."""
    if sys.platform == 'darwin':
        targets = []
        for module in MODULES:
            crate = ROOT / 'native' / module
            slices = []
            for triple in MACOS_TARGETS:
                subprocess.run(['rustup', 'target', 'add', triple], cwd=crate, check=True)
                _cargo(module, ['build', '--release', '--target', triple], quiet)
                slices.append(str(crate / 'target' / triple / 'release' / library_name(module)))
            universal = crate / 'target' / 'universal' / library_name(module)
            universal.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(['lipo', '-create', *slices, '-output', str(universal)], check=True)
            targets.append(_install(universal, ROOT / 'game/bin' / f'opensc2k_{module}' / 'macos' / library_name(module)))
        # the packaging job downloads the SoundFonts once for every platform
        return targets + build_fluidsynth.build(quiet=quiet)
    if host_folder() not in ('linux-x86_64', 'windows-x86_64'):
        raise OSError(f'desktop packages do not include {host_folder()}')
    targets = []
    for module in MODULES:
        _cargo(module, ['build', '--release'], quiet)
        built = ROOT / 'native' / module / 'target' / 'release' / library_name(module)
        targets.append(_install(built, ROOT / 'game/bin' / f'opensc2k_{module}' / host_folder() / library_name(module)))
    return targets + build_fluidsynth.build(quiet=quiet)


def test(quiet=False):
    """Run unit tests for each native library. The audio tests use the built FluidSynth."""
    environment = dict(os.environ)
    fluidsynth = build_fluidsynth.output_folder(host_folder()) / build_fluidsynth.LIBRARY_NAMES[host_folder()][0]
    if fluidsynth.is_file():
        environment.setdefault('OPENSC2K_FLUIDSYNTH', str(fluidsynth))
        environment.setdefault('OPENSC2K_REQUIRE_FLUIDSYNTH', '1')
    for module in MODULES:
        crate = ROOT / 'native' / module
        command = ['cargo', 'test', '--release', '--manifest-path', str(crate / 'Cargo.toml')]
        if quiet:
            command.append('--quiet')
        subprocess.run(command, cwd=crate, check=True, capture_output=quiet, env=environment)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--debug', action='store_true', help='Build without optimizations')
    parser.add_argument('--package', action='store_true', help='Build the library of a desktop package')
    args = parser.parse_args()
    targets = build_package() if args.package else build('debug' if args.debug else 'release')
    for target in targets:
        print(f'Native library: {target.relative_to(ROOT)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
