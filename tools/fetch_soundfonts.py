#!/usr/bin/env python3
"""Download the bundled General MIDI SoundFonts into game/bin/soundfonts.

Each file comes from its canonical upstream location at a pinned version and
must match its SHA-256. The license file of each SoundFont goes beside it.
Packages copy this folder; see docs/fluidsynth.md for the license review.
"""
import argparse
import hashlib
import os
import shutil
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / 'game' / 'bin' / 'soundfonts'

# MuseScore 2.3.2 is the last release that ships FluidR3Mono 2.312 as a file of its own
MUSESCORE_2_3_2 = 'https://raw.githubusercontent.com/musescore/MuseScore/45924076871483cb96b859cc374c5fbdbf76ba53'
MUSESCORE_GENERAL = 'https://ftp.osuosl.org/pub/musescore/soundfont/MuseScore_General'

# file name: (url, sha256). Keep in sync with game/src/audio/sound_font_catalog.gd
FILES = {
    'FluidR3Mono_GM.sf3': (f'{MUSESCORE_2_3_2}/share/sound/FluidR3Mono_GM.sf3',
                           'cfcd66d89e8386823400eca64934b14fbea7bf48ba1f00d21189af1262794ec2'),
    'FluidR3Mono_License.md': (f'{MUSESCORE_2_3_2}/share/sound/FluidR3Mono_License.md',
                               '09926f9451f751408abd65162c99343f840234d2a708584808fd46427633063f'),
    'MuseScore_General.sf3': (f'{MUSESCORE_GENERAL}/MuseScore_General.sf3',
                              '5b85b6c2c61d10b2b91cddd41efcce7b25cd31c8271d511c73afafbef20b6fa3'),
    'MuseScore_General_License.md': (f'{MUSESCORE_GENERAL}/MuseScore_General_License.md',
                                     '5ad8d737e13c7f01f5b9674872a82a92b4ba253603e8ed14b9db12293550b4b9'),
    'MuseScore_General_Sample_Sources.csv': (f'{MUSESCORE_GENERAL}/MuseScore_General_Sample_Sources.csv',
                                             'cbec757614fa47d2ba71a2f1276bf010918261d94987cfb678352e9755e9bdd4'),
}


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


def fetch(destination=DESTINATION, quiet=False):
    """Download each missing or changed file. Returns the paths."""
    destination.mkdir(parents=True, exist_ok=True)
    # Godot must not import the license text and the CSV file as project resources
    (destination / '.gdignore').touch()
    paths = []
    for name, (url, expected) in FILES.items():
        target = destination / name
        if not target.is_file() or sha256(target) != expected:
            if not quiet:
                print(f'Downloading {url}')
            staged = target.with_name(name + '.part')
            with urllib.request.urlopen(url) as response, staged.open('wb') as stream:
                shutil.copyfileobj(response, stream)
            actual = sha256(staged)
            if actual != expected:
                staged.unlink()
                raise ValueError(f'{name}: SHA-256 is {actual}, expected {expected}')
            os.replace(staged, target)
        paths.append(target)
    return paths


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--destination', type=Path, default=DESTINATION)
    args = parser.parse_args()
    for path in fetch(args.destination.resolve()):
        print(f'SoundFont file: {path}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
