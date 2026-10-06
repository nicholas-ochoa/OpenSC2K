#!/usr/bin/env python3
"""Paint the OpenSC2K app icon and write the icon files in assets/icons.

The icon follows the box art of SimCity 2000. tools/icon_art.py paints its
layers as SVG; each layer also has a dusk version for the dark appearance.

macOS 26 and later show an app icon in its own shape only when it comes from
an Icon Composer document. Other icons get a grey frame. So this script writes:

  OpenSC2K.icon  the Icon Composer document: the sky fill and the land and city layers
  Assets.car     the document compiled by actool, for the app bundle
  OpenSC2K.icns  the icon of earlier macOS versions, as ictool renders the document
  OpenSC2K.png   the window icon, the same render
  OpenSC2K.ico   the Windows icon, the same render

It needs Xcode 26 or later, for actool and the ictool of Icon Composer.

  python3 tools/make_icon.py                     # write the icon files
  python3 tools/make_icon.py --preview out.png   # render the icon only
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

from icon_art import PAINTERS, SIZE, SKY_DAY, SKY_DUSK, hex_rgb

ROOT = Path(__file__).resolve().parents[1]
ICONS = ROOT / 'assets/icons'
NAME = 'OpenSC2K'
ICTOOL = Path('/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool')
# the rounded square of a classic macOS icon on the canvas of an Icon Composer document
PLATE = 824

# the layers from the front to the back: (name, Liquid Glass, shadow)
LAYERS = (('city', False, 'neutral'), ('land', False, 'none'))


def icon_color(value):
    r, g, b = hex_rgb(value)
    return f'srgb:{r / 255:.5f},{g / 255:.5f},{b / 255:.5f},1.00000'


def group(name, glass, shadow):
    """A group of one layer, with its dusk image in the dark appearance."""
    images = [{'value': f'{name}.svg'}, {'appearance': 'dark', 'value': f'{name}-dusk.svg'}]
    return {
        'layers': [{'name': name, 'glass': glass, 'image-name-specializations': images}],
        'shadow': {'kind': shadow, 'opacity': 0.5},
        'translucency': {'enabled': False, 'value': 0.5},
        'specular': glass,
    }


def write_document(folder):
    """The Icon Composer document. Its first group is in front."""
    if folder.exists():
        shutil.rmtree(folder)

    (folder / 'Assets').mkdir(parents=True)

    for name, paint in PAINTERS.items():
        (folder / f'Assets/{name}.svg').write_text(paint())
        (folder / f'Assets/{name}-dusk.svg').write_text(paint(dusk=True))

    document = {
        'fill-specializations': [
            {'value': {'linear-gradient': [icon_color(c) for c in SKY_DAY]}},
            {'appearance': 'dark', 'value': {'linear-gradient': [icon_color(c) for c in SKY_DUSK]}},
        ],
        'groups': [group(*layer) for layer in LAYERS],
        'supported-platforms': {'squares': ['macOS']},
    }
    (folder / 'icon.json').write_text(json.dumps(document, indent=2) + '\n')


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
    write_document(document)
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
        with tempfile.TemporaryDirectory() as work:
            document = Path(work) / f'{NAME}.icon'
            write_document(document)
            classic_icon(document).save(args.preview)
    else:
        write_icons()

    return 0


if __name__ == '__main__':
    sys.exit(main())
