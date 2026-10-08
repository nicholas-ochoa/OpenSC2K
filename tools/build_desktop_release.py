#!/usr/bin/env python3
"""Build desktop packages from the committed tree on macOS.

--platform builds only the named platforms, such as `--platform macos`; it can repeat.

The macOS app is signed with MACOS_SIGNING_IDENTITY, a Developer ID Application
identity of the keychain, or ad hoc without it. The disk image is then notarized
and stapled with a notarytool keychain profile (APPLE_NOTARY_PROFILE) or an App
Store Connect API key (APPLE_API_KEY_PATH, APPLE_API_KEY_ID, APPLE_API_ISSUER_ID).
--require-notarization fails the build without them. See docs/ci.md.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
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


def selected_packages(platforms):
    """The PACKAGES entries of `platforms`, in PACKAGES order. None or empty selects all.
    A name can be a package platform, such as macos-universal, or a native folder, such as macos."""
    if not platforms:
        return list(PACKAGES)
    names = set()
    for name in platforms:
        match = [platform for platform, (folder, _, _) in NATIVE_PLATFORMS.items() if name in (platform, folder)]
        if not match:
            known = ', '.join(NATIVE_PLATFORMS)
            raise ValueError(f'Unknown platform {name}. Use one of: {known}')
        names.update(match)
    return [package for package in PACKAGES if package[0] in names]


def install_native(native, project, platforms=tuple(NATIVE_PLATFORMS)):
    """Copy each prebuilt extension of `platforms`, and FluidSynth beside the audio extension, into the exported project."""
    for module in NATIVE_MODULES:
        for folder, template, _ in (NATIVE_PLATFORMS[platform] for platform in platforms):
            library = template.format(module)
            source = native / f'opensc2k_{module}' / folder / library
            if not source.is_file():
                raise ValueError(f'Missing native {module} library: {source}')
            target = project / 'bin' / f'opensc2k_{module}' / folder / library
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    for platform in platforms:
        library = FLUIDSYNTH[platform][0]
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


# The compiled Icon Composer icon (tools/make_icon.py) and its name in it
APP_ICON = ROOT / 'game/assets/icons/Assets.car'
APP_ICON_NAME = 'OpenSC2K'


# The identity of an ad hoc signature, and the certificate kind that notarization accepts
AD_HOC = '-'
DEVELOPER_ID = 'Developer ID Application'
NOTARY_KEY_VARIABLES = ('APPLE_API_KEY_PATH', 'APPLE_API_KEY_ID', 'APPLE_API_ISSUER_ID')


def signing_identity():
    """MACOS_SIGNING_IDENTITY, a name or SHA-1 hash of a keychain identity, or ad hoc."""
    return os.environ.get('MACOS_SIGNING_IDENTITY', '').strip() or AD_HOC


def notary_arguments():
    """The notarytool credentials of the environment, or None."""
    profile = os.environ.get('APPLE_NOTARY_PROFILE', '').strip()
    if profile:
        return ['--keychain-profile', profile]
    path, key_id, issuer = (os.environ.get(name, '').strip() for name in NOTARY_KEY_VARIABLES)
    if path and key_id and issuer:
        return ['--key', path, '--key-id', key_id, '--issuer', issuer]
    if path or key_id or issuer:
        raise ValueError(f'Set all of {", ".join(NOTARY_KEY_VARIABLES)}, or none')
    return None


def identity_name(identity, listing):
    """The name of `identity`, a name or SHA-1 hash, in `security find-identity` output, or None."""
    for line in listing.splitlines():
        match = re.match(r'\s*\d+\) ([0-9A-F]{40}) "(.+)"$', line)
        if match and identity in match.groups():
            return match.group(2)
    return None


def check_signing(identity, notary, required):
    """Fail before the export when the signing settings cannot give a notarized app."""
    if required and (identity == AD_HOC or notary is None):
        raise ValueError('--require-notarization needs MACOS_SIGNING_IDENTITY and notary credentials')
    if identity == AD_HOC:
        if notary is not None:
            raise ValueError('Notarization needs MACOS_SIGNING_IDENTITY')
        return
    listing = subprocess.check_output(['security', 'find-identity', '-v', '-p', 'codesigning'], text=True)
    name = identity_name(identity, listing)
    if name is None:
        names = re.findall(r'^\s*\d+\) [0-9A-F]{40} "(.+)"$', listing, re.M)
        found = ''.join(f'\n  {name}' for name in names) or ' none'
        raise ValueError(f'No valid code signing identity {identity} in the keychain search list. '
                         f'The name must match exactly. Valid identities:{found}')
    if notary is not None and not name.startswith(DEVELOPER_ID):
        raise ValueError(f'Notarization needs a {DEVELOPER_ID} identity, not {name}')


def sign_app(app, identity=AD_HOC):
    """Sign the libraries of `app`, then the app. An ad hoc app keeps the
    entitlements and options of the export. With an identity, each binary gets
    the hardened runtime and a secure timestamp, and the app has no
    entitlements: its libraries have the same team, so library validation passes."""
    if identity == AD_HOC:
        subprocess.run(['codesign', '--force', '--sign', AD_HOC,
                        '--preserve-metadata=entitlements,requirements,flags,runtime', str(app)], check=True)
    else:
        options = ['--force', '--timestamp', '--options', 'runtime', '--sign', identity]
        for library in sorted((app / 'Contents/Frameworks').glob('*.dylib')):
            subprocess.run(['codesign', *options, str(library)], check=True)
        subprocess.run(['codesign', *options, str(app)], check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)


def submit_for_notarization(path, notary):
    """Submit `path` to the Apple notary service and wait for the result."""
    result = subprocess.run(['xcrun', 'notarytool', 'submit', str(path), *notary, '--wait', '--output-format', 'json'],
                            capture_output=True, text=True)
    try:
        submission = json.loads(result.stdout)
    except json.JSONDecodeError:
        raise ValueError(f'notarytool failed for {path.name}: {result.stderr.strip()}') from None
    if submission.get('status') != 'Accepted':
        log = subprocess.run(['xcrun', 'notarytool', 'log', submission.get('id', ''), *notary],
                             capture_output=True, text=True)
        raise ValueError(f'Notarization of {path.name} ended with {submission.get("status")}:\n{log.stdout}{log.stderr}')


def notarize(item, notary):
    """Notarize an app or a disk image, staple the ticket to it, and check it as
    Gatekeeper does. An app goes to the notary service in a zip archive. Its own
    ticket lets it open offline after it leaves the disk image."""
    if item.suffix == '.app':
        with tempfile.TemporaryDirectory(prefix='opensc2k-notary-') as work:
            archive = Path(work) / f'{item.stem}.zip'
            subprocess.run(['ditto', '-c', '-k', '--keepParent', str(item), str(archive)], check=True)
            submit_for_notarization(archive, notary)
        assessment = ['--type', 'execute']
    else:
        submit_for_notarization(item, notary)
        assessment = ['--type', 'open', '--context', 'context:primary-signature']
    subprocess.run(['xcrun', 'stapler', 'staple', str(item)], check=True)
    subprocess.run(['xcrun', 'stapler', 'validate', str(item)], check=True)
    subprocess.run(['spctl', '--assess', *assessment, '--verbose', str(item)], check=True)


def add_app_icon(app, icon=APP_ICON, identity=AD_HOC):
    """Give an exported app the compiled Icon Composer icon, so macOS 26 and
    later show the icon in its own shape and not in a grey frame. Earlier
    versions keep the .icns of the export. The app is then signed again."""
    contents = app / 'Contents'
    shutil.copy2(icon, contents / 'Resources' / 'Assets.car')
    info_path = contents / 'Info.plist'
    info = plistlib.loads(info_path.read_bytes())
    info['CFBundleIconName'] = APP_ICON_NAME
    info_path.write_bytes(plistlib.dumps(info))
    sign_app(app, identity)


def has_diskutil_image():
    """True where `diskutil image create from` takes a volume name and can replace `hdiutil create`.
    macOS 15 has the command, but without --volumeName."""
    probe = subprocess.run(['diskutil', 'image', 'create', 'from', '--help'], capture_output=True, text=True)
    return probe.returncode == 0 and '--volumeName' in probe.stdout + probe.stderr


# GitHub macOS runners sometimes fail to create an image with "Resource busy"
# (actions/runner-images#7522). A later attempt usually succeeds
DISK_IMAGE_ATTEMPTS = 5
DISK_IMAGE_RETRY_SECONDS = 10


def make_disk_image(folder, volume, image):
    """A compressed read-only disk image of `folder`. Older macOS versions use hdiutil."""
    if has_diskutil_image():
        command = ['diskutil', 'image', 'create', 'from', '--format', 'UDZO', '--volumeName', volume,
                   str(folder), str(image)]
    else:
        command = ['hdiutil', 'create', '-volname', volume, '-srcfolder', str(folder),
                   '-format', 'UDZO', str(image)]

    for attempt in range(1, DISK_IMAGE_ATTEMPTS + 1):
        # a failed attempt can leave a partial image, and hdiutil does not replace a file
        image.unlink(missing_ok=True)
        result = subprocess.run(command)
        if result.returncode == 0:
            break
        if attempt == DISK_IMAGE_ATTEMPTS:
            result.check_returncode()
        print(f'Disk image attempt {attempt} failed. Retry in {DISK_IMAGE_RETRY_SECONDS} seconds.')
        time.sleep(DISK_IMAGE_RETRY_SECONDS)

    subprocess.run(['hdiutil', 'verify', str(image)], check=True)


def build(output, label, godot, native, platforms=None, require_notarization=False):
    if sys.platform != 'darwin':
        raise ValueError('Desktop packaging requires macOS to create and sign the app and DMG')
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.+-]{0,79}', label):
        raise ValueError('Invalid package label')
    selected = selected_packages(platforms)
    macos = any(platform.startswith('macos') for platform, _, _ in selected)
    identity, notary = signing_identity(), notary_arguments()
    if macos:
        check_signing(identity, notary, require_notarization)
    output.mkdir(parents=True, exist_ok=False)
    linux = any(platform.startswith('linux') for platform, _, _ in selected)
    soundfont = build_fluidsynth.download(*SOUNDFONT) if linux else None
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
        install_native(native, project, [platform for platform, _, _ in selected])
        settings = (project / 'project.godot').read_text()
        version = re.search(r'^config/version="([^"]+)"', settings, re.M).group(1)
        # the headless renderer stores textures without a lock, so parallel
        # importers can lose a texture and fail the import with an engine error
        if '[editor]' in settings:
            raise ValueError('project.godot has an [editor] section; merge the import thread setting into it')
        (project / 'project.godot').write_text(settings + '\n[editor]\n\nimport/use_multiple_threads=false\n')
        checked_godot(godot, project, '--editor', '--import')
        packages = []
        for platform, preset, binary in selected:
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
                add_app_icon(folder / binary, identity=identity)
                if notary is not None:
                    notarize(folder / binary, notary)
                (folder / 'Applications').symlink_to('/Applications')
                package = output / (name + '.dmg')
                make_disk_image(folder, f'OpenSC2K {label}', package)
                if identity != AD_HOC:
                    subprocess.run(['codesign', '--force', '--timestamp', '--sign', identity, str(package)], check=True)
                if notary is not None:
                    notarize(package, notary)
            packages.append(package)
        packages.append(write_fluidsynth_source(output / f'OpenSC2K-{label}-fluidsynth-source.zip', work))
    hashes = {path.name: sha256(path) for path in packages}
    (output / 'SHA256SUMS.txt').write_text(''.join(f'{value}  {name}\n' for name, value in sorted(hashes.items())))
    signing = None
    if macos:
        signing = dict(identity=identity, notarized=notary is not None)
    (output / 'build-info.json').write_text(json.dumps(dict(version=version, label=label, commit=commit,
                                                          engine=engine, macos_signing=signing, sha256=hashes),
                                                     indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--label', required=True)
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--native', type=Path, default=ROOT / 'game/bin',
                        help='Folder with each native extension and platform, as tools/build_native.py --package writes it')
    parser.add_argument('--platform', action='append', default=[],
                        help='Build only this platform, such as macos or windows-x64. Repeat for more')
    parser.add_argument('--require-notarization', action='store_true',
                        help='Fail unless the macOS app can be signed with a Developer ID and notarized')
    args = parser.parse_args()
    build(args.output.resolve(), args.label, args.godot, args.native.resolve(), args.platform,
          args.require_notarization)


if __name__ == '__main__':
    main()
