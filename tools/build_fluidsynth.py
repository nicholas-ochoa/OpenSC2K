#!/usr/bin/env python3
"""Build the FluidSynth shared library and copy it beside the native audio library.

FluidSynth is LGPL-2.1-or-later. OpenSC2K loads it at run time from a separate,
replaceable shared library and never links it statically. See docs/fluidsynth.md.

Every platform builds the pinned, unchanged upstream sources with CMake, so the
corresponding source of each package is exactly the archives listed here. The
build has no audio or MIDI drivers, because Godot plays the audio. libsndfile,
Ogg, Vorbis, FLAC and Opus are built into the FluidSynth library so that it can
read SF3 (compressed) SoundFonts. The result needs only operating system libraries.

With --source-bundle, also write the unchanged upstream source archives and this
script to a folder. Releases publish that folder as the corresponding source.
"""
import argparse
import hashlib
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'native' / 'audio' / 'target' / 'fluidsynth'
DOWNLOADS = WORK / 'downloads'
FLUIDSYNTH_VERSION = '2.6.1'
MACOS_ARCHITECTURES = ('arm64', 'x86_64')
MACOS_DEPLOYMENT_TARGET = '11.0'

# name: (url, sha256, archive file name)
SOURCES = {
    'ogg': ('https://github.com/xiph/ogg/releases/download/v1.3.6/libogg-1.3.6.tar.xz',
            '5c8253428e181840cd20d41f3ca16557a9cc04bad4a3d04cce84808677fa1061', 'libogg-1.3.6.tar.xz'),
    'vorbis': ('https://github.com/xiph/vorbis/releases/download/v1.3.7/libvorbis-1.3.7.tar.xz',
               'b33cc4934322bcbf6efcbacf49e3ca01aadbea4114ec9589d1b1e9d20f72954b', 'libvorbis-1.3.7.tar.xz'),
    'flac': ('https://github.com/xiph/flac/releases/download/1.5.0/flac-1.5.0.tar.xz',
             'f2c1c76592a82ffff8413ba3c4a1299b6c7ab06c734dee03fd88630485c2b920', 'flac-1.5.0.tar.xz'),
    'opus': ('https://github.com/xiph/opus/releases/download/v1.5.2/opus-1.5.2.tar.gz',
             '65c1d2f78b9f2fb20082c38cbe47c951ad5839345876e46941612ee87f9a7ce1', 'opus-1.5.2.tar.gz'),
    'sndfile': ('https://github.com/libsndfile/libsndfile/releases/download/1.2.2/libsndfile-1.2.2.tar.xz',
                '3799ca9924d3125038880367bf1468e53a1b7e3686a934f098b7e1d286cdb80e', 'libsndfile-1.2.2.tar.xz'),
    'fluidsynth': (f'https://github.com/FluidSynth/fluidsynth/archive/refs/tags/v{FLUIDSYNTH_VERSION}.tar.gz',
                   '3d258a3bf97cc20c59eeebfe62c2432fae88adda74d3ad098681c76e0ebf446b',
                   f'fluidsynth-{FLUIDSYNTH_VERSION}.tar.gz'),
    # git submodules of FluidSynth v2.6.1, at the commits that the tag records
    'gcem': ('https://github.com/kthohr/gcem/archive/012ae73c6d0a2cb09ffe86475f5c6fba3926e200.tar.gz',
             '34ab0ee87a9eb26d3087fa9b49c2572ea8ee03db0c9705b83648301a3a3fc172', 'gcem-012ae73c.tar.gz'),
    'signalsmith': ('https://github.com/Signalsmith-Audio/basics/archive/012d2be17b0eb6839628f8c73687c4ccccc1bb01.tar.gz',
                    '27af16f00c47abb498eb54bcbe52f6701bf970331f7d2e65731cf5264b202441',
                    'signalsmith-audio-basics-012d2be1.tar.gz'),
    # Signalsmith basics fetches these at configure time; the build uses these copies instead
    'signalsmith-linear': ('https://github.com/Signalsmith-Audio/linear/archive/refs/tags/0.3.1.tar.gz',
                           'b294471f1306baa4d968b230a8836924680e9ca068a667f4659259d66edbe9bc',
                           'signalsmith-linear-0.3.1.tar.gz'),
    'signalsmith-dsp': ('https://github.com/Signalsmith-Audio/dsp/archive/refs/tags/v1.7.1.tar.gz',
                        '7f679d0751f61079edeaefc6c68b27f5f70a2bc9a4b97b2b02ebf59b7573b359',
                        'signalsmith-dsp-1.7.1.tar.gz'),
    'signalsmith-hilbert': ('https://github.com/Signalsmith-Audio/hilbert-iir/archive/refs/tags/1.0.0.tar.gz',
                            '01f811fb0945edd5f146e493251672ab2bff03902a88e8c0574dc6c441e3d0b5',
                            'signalsmith-hilbert-iir-1.0.0.tar.gz'),
}

# the shared library that each platform loads. keep in sync with the
# candidate names in native/audio/src/fluidsynth/library.rs
LIBRARY_NAMES = {
    'macos': ('libfluidsynth.3.dylib',),
    'linux-x86_64': ('libfluidsynth.so.3',),
    'linux-arm64': ('libfluidsynth.so.3',),
    'windows-x86_64': ('libfluidsynth-3.dll',),
}

# the static codec libraries inside libsndfile, in link order
LINUX_CODEC_LIBRARIES = ('libFLAC.a', 'libopus.a', 'libvorbisenc.a', 'libvorbis.a', 'libogg.a')

COMMON_OPTIONS = ['-DCMAKE_BUILD_TYPE=Release', '-DBUILD_SHARED_LIBS=OFF',
                  '-DCMAKE_POSITION_INDEPENDENT_CODE=ON', '-DCMAKE_INSTALL_LIBDIR=lib',
                  '-DCMAKE_INSTALL_BINDIR=bin', '-DBUILD_TESTING=OFF', '-DCMAKE_POLICY_VERSION_MINIMUM=3.5',
                  # Windows: the static C runtime, so the DLL needs no Visual C++ redistributable
                  '-DCMAKE_POLICY_DEFAULT_CMP0091=NEW', '-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded']
DEPENDENCY_OPTIONS = {
    'ogg': ['-DINSTALL_DOCS=OFF'],
    'vorbis': [],
    'flac': ['-DBUILD_CXXLIBS=OFF', '-DBUILD_PROGRAMS=OFF', '-DBUILD_EXAMPLES=OFF', '-DBUILD_DOCS=OFF',
             '-DINSTALL_MANPAGES=OFF', '-DWITH_OGG=ON'],
    'opus': ['-DOPUS_BUILD_PROGRAMS=OFF', '-DOPUS_BUILD_TESTING=OFF'],
    'sndfile': ['-DBUILD_PROGRAMS=OFF', '-DBUILD_EXAMPLES=OFF', '-DBUILD_REGTEST=OFF', '-DENABLE_CPACK=OFF',
                '-DINSTALL_MANPAGES=OFF', '-DENABLE_EXTERNAL_LIBS=ON', '-DENABLE_MPEG=OFF',
                '-DCMAKE_DISABLE_FIND_PACKAGE_ALSA=ON', '-DCMAKE_DISABLE_FIND_PACKAGE_Sndio=ON',
                '-DCMAKE_DISABLE_FIND_PACKAGE_Speex=ON', '-DCMAKE_DISABLE_FIND_PACKAGE_SQLite3=ON'],
}
# FluidSynth renders samples for Godot. It opens no audio device, MIDI port, shell
# or network socket, so every driver and optional system library is off
FLUIDSYNTH_OPTIONS = [
    '-DBUILD_SHARED_LIBS=ON', '-Dosal=cpp11', '-Denable-libsndfile=ON', '-Denable-threads=ON',
    '-Denable-openmp=OFF', '-Denable-network=OFF', '-Denable-ipv6=OFF', '-Denable-aufile=OFF',
    '-Denable-alsa=OFF', '-Denable-dbus=OFF', '-Denable-jack=OFF', '-Denable-ladspa=OFF',
    '-Denable-midishare=OFF', '-Denable-oss=OFF', '-Denable-sdl3=OFF', '-Denable-pulseaudio=OFF',
    '-Denable-pipewire=OFF', '-Denable-readline=OFF', '-Denable-portaudio=OFF', '-Denable-systemd=OFF',
    '-Denable-coreaudio=OFF', '-Denable-coremidi=OFF', '-Denable-framework=OFF',
    '-Denable-dsound=OFF', '-Denable-wasapi=OFF', '-Denable-waveout=OFF', '-Denable-winmidi=OFF',
]


def host_folder():
    machine = platform.machine().lower()
    arch = 'arm64' if machine in ('arm64', 'aarch64') else 'x86_64'
    if sys.platform == 'darwin':
        return 'macos'
    if sys.platform == 'win32':
        return f'windows-{arch}'
    return f'linux-{arch}'


def output_folder(folder):
    return ROOT / 'game' / 'bin' / 'opensc2k_audio' / folder


def recipe_hash():
    """A hash of every input of the build. A change rebuilds the library."""
    digest = hashlib.sha256()
    digest.update(Path(__file__).read_bytes())
    return digest.hexdigest()


def download(url, sha256, name):
    DOWNLOADS.mkdir(parents=True, exist_ok=True)
    target = DOWNLOADS / name
    if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest() != sha256:
        staged = target.with_name(name + '.part')
        with urllib.request.urlopen(url) as response, staged.open('wb') as stream:
            shutil.copyfileobj(response, stream)
        actual = hashlib.sha256(staged.read_bytes()).hexdigest()
        if actual != sha256:
            staged.unlink()
            raise ValueError(f'{name}: SHA-256 is {actual}, expected {sha256}')
        os.replace(staged, target)
    return target


def extract(archive, destination):
    """Extract an archive that holds one top-level folder, and return that folder."""
    shutil.rmtree(destination, ignore_errors=True)
    destination.mkdir(parents=True)
    with tarfile.open(archive) as stream:
        stream.extractall(destination, filter='data')
    (folder,) = destination.iterdir()
    return folder


def cmake(source, build, prefix, options, architecture, quiet):
    # Visual Studio finds its compiler without a developer prompt; Ninja does not
    generator = ['-G', 'Ninja'] if shutil.which('ninja') and sys.platform != 'win32' else []
    platform_options = []
    if sys.platform == 'darwin':
        platform_options = [f'-DCMAKE_OSX_ARCHITECTURES={architecture}',
                            f'-DCMAKE_OSX_DEPLOYMENT_TARGET={MACOS_DEPLOYMENT_TARGET}']
    run(['cmake', '-S', str(source), '-B', str(build), *generator, *COMMON_OPTIONS, *platform_options,
         f'-DCMAKE_INSTALL_PREFIX={prefix}', f'-DCMAKE_PREFIX_PATH={prefix}', *options], quiet)
    run(['cmake', '--build', str(build), '--config', 'Release', '--parallel'], quiet)
    run(['cmake', '--install', str(build), '--config', 'Release'], quiet)


def run(command, quiet):
    """Run a build step. A quiet step shows its output only when it fails."""
    result = subprocess.run(command, capture_output=quiet, text=True)
    if result.returncode != 0:
        if quiet:
            print(result.stdout + result.stderr, file=sys.stderr)
        raise subprocess.CalledProcessError(result.returncode, command)


def build_from_source(architecture, quiet):
    """Build FluidSynth for one architecture, and return the shared library."""
    if shutil.which('cmake') is None:
        raise OSError('cmake is required to build FluidSynth (https://cmake.org)')
    work = WORK / f'{host_folder()}-{architecture}'
    prefix = work / 'prefix'
    # a clean build: an old CMake cache could keep settings from another recipe
    shutil.rmtree(prefix, ignore_errors=True)
    shutil.rmtree(work / 'build', ignore_errors=True)
    for name in ('ogg', 'vorbis', 'flac', 'opus', 'sndfile'):
        source = extract(download(*SOURCES[name]), work / 'source' / name)
        cmake(source, work / 'build' / name, prefix, DEPENDENCY_OPTIONS[name], architecture, quiet)

    source = extract(download(*SOURCES['fluidsynth']), work / 'source' / 'fluidsynth')
    for name, folder in (('gcem', 'gcem'), ('signalsmith', 'signalsmith-audio-basics')):
        submodule = extract(download(*SOURCES[name]), work / 'source' / name)
        shutil.rmtree(source / folder, ignore_errors=True)
        shutil.copytree(submodule, source / folder)

    # CMake must not download anything: every source is pinned above
    options = [*FLUIDSYNTH_OPTIONS, '-DFETCHCONTENT_FULLY_DISCONNECTED=ON']
    for name in ('signalsmith-linear', 'signalsmith-dsp', 'signalsmith-hilbert'):
        fetched = extract(download(*SOURCES[name]), work / 'source' / name)
        options.append(f'-DFETCHCONTENT_SOURCE_DIR_{name.upper()}={fetched}')
    if sys.platform.startswith('linux'):
        # the package must not need the C++ runtime of the build machine
        options.append('-DCMAKE_SHARED_LINKER_FLAGS=-static-libstdc++ -static-libgcc')
        # GNU ld resolves static libraries in order, so the codecs of libsndfile go last
        codecs = ' '.join(str(prefix / 'lib' / name) for name in LINUX_CODEC_LIBRARIES) + ' -lm'
        options += [f'-DCMAKE_C_STANDARD_LIBRARIES={codecs}', f'-DCMAKE_CXX_STANDARD_LIBRARIES={codecs}']
    cmake(source, work / 'build' / 'fluidsynth', prefix, options, architecture, quiet)
    library = LIBRARY_NAMES[host_folder()][0]
    folder = 'bin' if sys.platform == 'win32' else 'lib'
    return (prefix / folder / library).resolve()


def check_dependencies(library):
    """Reject a library that needs a shared library outside the operating system."""
    if sys.platform == 'win32':
        names = pe_imports(library)
        allowed = WINDOWS_SYSTEM_LIBRARIES
        for name in names:
            if name.lower() not in allowed and not name.lower().startswith('api-ms-win-'):
                raise ValueError(f'{library.name} needs {name}, which a package does not include')
        return
    if sys.platform == 'darwin':
        # a universal library lists each architecture under a line that ends with a colon
        listing = subprocess.check_output(['otool', '-L', str(library)], text=True).splitlines()
        allowed = ('/usr/lib/', '/System/Library/', '@rpath/libfluidsynth')
        names = [line.strip().split(' ')[0] for line in listing if not line.endswith(':')]
    else:
        listing = subprocess.check_output(['readelf', '-d', str(library)], text=True).splitlines()
        names = [line.split('[')[1].split(']')[0] for line in listing if '(NEEDED)' in line]
        allowed = ('libc.so', 'libm.so', 'libpthread.so', 'libdl.so', 'ld-linux', 'libgcc_s.so', 'librt.so')
    for name in names:
        if not any(part in name for part in allowed):
            raise ValueError(f'{library.name} needs {name}, which a package does not include')


# Windows system DLLs that FluidSynth may import with every driver off
WINDOWS_SYSTEM_LIBRARIES = {'kernel32.dll', 'user32.dll', 'advapi32.dll', 'ole32.dll', 'oleaut32.dll',
                            'ws2_32.dll', 'winmm.dll', 'dsound.dll', 'shell32.dll', 'shlwapi.dll', 'bcrypt.dll'}


def pe_imports(path):
    """The DLL names in the import table of a 64-bit Windows library."""
    data = path.read_bytes()
    header = int.from_bytes(data[0x3c:0x40], 'little')
    sections = int.from_bytes(data[header + 6:header + 8], 'little')
    optional_size = int.from_bytes(data[header + 20:header + 22], 'little')
    optional = header + 24
    import_rva = int.from_bytes(data[optional + 120:optional + 124], 'little')
    table = optional + optional_size

    def offset(rva):
        for index in range(sections):
            entry = table + index * 40
            virtual_size, virtual_address, _, raw = (int.from_bytes(data[entry + at:entry + at + 4], 'little')
                                                    for at in (8, 12, 16, 20))
            if virtual_address <= rva < virtual_address + virtual_size:
                return rva - virtual_address + raw
        raise ValueError(f'{path.name}: RVA {rva:#x} is outside every section')

    names = []
    descriptor = offset(import_rva)
    while int.from_bytes(data[descriptor + 12:descriptor + 16], 'little'):
        start = offset(int.from_bytes(data[descriptor + 12:descriptor + 16], 'little'))
        names.append(data[start:data.index(b'\0', start)].decode('ascii'))
        descriptor += 20
    return names


def install_built(quiet):
    folder = host_folder()
    target = output_folder(folder) / LIBRARY_NAMES[folder][0]
    if sys.platform == 'darwin':
        slices = [str(build_from_source(architecture, quiet)) for architecture in MACOS_ARCHITECTURES]
        universal = WORK / 'macos-universal' / target.name
        universal.parent.mkdir(parents=True, exist_ok=True)
        run(['lipo', '-create', *slices, '-output', str(universal)], quiet)
        run(['install_name_tool', '-id', f'@rpath/{target.name}', str(universal)], quiet)
        # install_name_tool removes the signature; Apple silicon needs one
        run(['codesign', '--force', '--sign', '-', str(universal)], quiet)
        built = universal
    else:
        machine = 'x86_64' if folder.endswith('x86_64') else 'aarch64'
        built = build_from_source(machine, quiet)
    check_dependencies(built)
    return [install(built, target)]


def install(built, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists() or target.read_bytes() != built.read_bytes():
        # replace the file; macOS stops processes that map a changed signed library
        staged = target.with_name(target.name + '.new')
        shutil.copy2(built, staged)
        os.replace(staged, target)
    return target


def write_source_bundle(destination):
    """Write the corresponding source of every LGPL library that a package includes."""
    destination.mkdir(parents=True, exist_ok=True)
    lines = [f'FluidSynth {FLUIDSYNTH_VERSION} and the libraries built into it, as OpenSC2K packages use them.',
             'Every archive is the unchanged upstream release. build_fluidsynth.py is the build script.', '']
    for name, (url, sha256, file_name) in sorted(SOURCES.items()):
        shutil.copy2(download(url, sha256, file_name), destination / file_name)
        lines.append(f'{file_name}\n  {url}\n  sha256 {sha256}')
    shutil.copy2(__file__, destination / 'build_fluidsynth.py')
    (destination / 'SOURCES.txt').write_text('\n'.join(lines) + '\n')
    return destination


def build(force=False, quiet=False):
    folder = host_folder()
    if folder not in LIBRARY_NAMES:
        raise OSError(f'FluidSynth is not packaged for {folder}')
    stamp = output_folder(folder) / 'fluidsynth.recipe'
    targets = [output_folder(folder) / name for name in LIBRARY_NAMES[folder]]
    if not force and stamp.is_file() and stamp.read_text() == recipe_hash() and all(t.is_file() for t in targets):
        return targets
    targets = install_built(quiet)
    stamp.write_text(recipe_hash())
    return targets


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--force', action='store_true', help='Build again even when the library is current')
    parser.add_argument('--source-bundle', type=Path, help='Also write the corresponding source to this folder')
    args = parser.parse_args()
    for target in build(args.force):
        print(f'FluidSynth library: {target.relative_to(ROOT)}')
    if args.source_bundle:
        print(f'FluidSynth source: {write_source_bundle(args.source_bundle.resolve())}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
