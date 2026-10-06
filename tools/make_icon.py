#!/usr/bin/env python3
"""Build the OpenSC2K app icon files from the Icon Composer document in assets/icons.

The art is in OpenSC2K.icon: an aerial view of a city on a bay, after the box
art of SimCity 2000. Its layers are plain SVG files, to edit by hand:

  Assets/land.svg       the sky, mountains, streets, cars, far skyline and bay
  Assets/city.svg       everything that stands, from the back to the front, and the bridge
  Assets/*-dusk.svg     the same layers for the dark appearance, with lit windows

Each object is its own named group, with its gradients inside it. icon.json
holds the sky gradient of each appearance and the order of the layers.

macOS 26 and later show an app icon in its own shape only when it comes from
an Icon Composer document. Other icons get a grey frame. So this script writes:

  Assets.car     the document compiled by actool, for the app bundle
  OpenSC2K.icns  the icon of earlier macOS versions, as ictool renders the document
  OpenSC2K.png   the window icon, the same render
  OpenSC2K.ico   the Windows icon, the same render

It needs Xcode 26 or later, for actool and the ictool of Icon Composer.

  python3 tools/make_icon.py                     # write the icon files
  python3 tools/make_icon.py --preview out.png   # render the icon only
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ICONS = ROOT / 'assets/icons'
NAME = 'OpenSC2K'
ICTOOL = Path('/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool')
# the canvas of an Icon Composer document, and the rounded square of a
# classic macOS icon on the same canvas
SIZE = 1024
PLATE = 824


def render(document, size):
    """The icon as macOS draws it, `size` pixels square, from ictool."""
    with tempfile.TemporaryDirectory() as work:
        output = Path(work) / 'icon.png'
        subprocess.run([str(ICTOOL), str(document), '--export-image', '--output-file', str(output),
                        '--platform', 'macOS', '--rendition', 'Default',
                        '--width', str(size), '--height', str(size), '--scale', '1'],
                       check=True, stdout=subprocess.DEVNULL)
        return Image.open(output).convert('RGBA')


def classic_icon(document):
    """The render on the grid of a classic macOS icon: the rounded square with space around it."""
    icon = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    plate = render(document, PLATE)
    icon.alpha_composite(plate, ((SIZE - PLATE) // 2, (SIZE - PLATE) // 2))
    return icon


def compile_document(document, folder):
    """Assets.car from actool. actool also writes a small .icns, which this script makes itself."""
    with tempfile.TemporaryDirectory() as work:
        work = Path(work)
        subprocess.run(['xcrun', 'actool', str(document), '--compile', str(work),
                        '--output-format', 'human-readable-text', '--errors', '--warnings',
                        '--platform', 'macosx', '--target-device', 'mac', '--minimum-deployment-target', '11.0',
                        '--app-icon', NAME, '--output-partial-info-plist', str(work / 'partial.plist')],
                       check=True, stdout=subprocess.DEVNULL)
        shutil.copy2(work / 'Assets.car', folder / 'Assets.car')


def write_icns(icon, path):
    with tempfile.TemporaryDirectory() as work:
        iconset = Path(work) / f'{NAME}.iconset'
        iconset.mkdir()

        for size in (16, 32, 128, 256, 512):
            icon.resize((size, size), Image.LANCZOS).save(iconset / f'icon_{size}x{size}.png')
            icon.resize((size * 2, size * 2), Image.LANCZOS).save(iconset / f'icon_{size}x{size}@2x.png')

        subprocess.run(['iconutil', '-c', 'icns', str(iconset), '-o', str(path)], check=True)


def write_icons():
    document = ICONS / f'{NAME}.icon'
    compile_document(document, ICONS)
    icon = classic_icon(document)
    icon.save(ICONS / f'{NAME}.png')
    icon.save(ICONS / f'{NAME}.ico', sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    write_icns(icon, ICONS / f'{NAME}.icns')


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--preview', type=Path, help='Write only a render of the icon to this path')
    args = parser.parse_args()

    if sys.platform != 'darwin' or not ICTOOL.exists():
        print(f'This script needs macOS and Xcode 26 or later, for {ICTOOL.name} and actool.', file=sys.stderr)
        return 1

    if args.preview:
        classic_icon(ICONS / f'{NAME}.icon').save(args.preview)
    else:
        write_icons()

    return 0


if __name__ == '__main__':
    sys.exit(main())
