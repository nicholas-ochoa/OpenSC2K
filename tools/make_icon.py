#!/usr/bin/env python3
"""Draw the OpenSC2K app icon and write the icon files in assets/icons.

The icon is pixel art on a 2:1 isometric grid, in the style of the game: a
city block on a slab of land at the edge of a bay, drawn at a small logical
size and scaled up with nearest sampling, in front of a night sky.

macOS 26 and later show an app icon in its own shape only when it comes from
an Icon Composer document. Other icons get a grey frame. So this script writes:

  OpenSC2K.icon  the Icon Composer document: the sky fill, the city and the stars
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
import random
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ICONS = ROOT / 'assets/icons'
NAME = 'OpenSC2K'
ICTOOL = Path('/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool')
# the canvas of an Icon Composer document, and the rounded square of a
# classic macOS icon on the same canvas
SIZE = 1024
PLATE = 824
# the pixel art: its logical size and the scale of one logical pixel on the canvas
ART = 80
PIXEL = 11
# one tile of the isometric grid: half its width and half its height
HALF_W, HALF_H = 8, 4
# the stars: how many, their half size, and the part of the sky that has them
STARS, STAR_SIZES = 40, (2, 3, 4)
STAR_AREA = (130, 90, 894, 560)
STAR_CLEARANCE = 12

# the sky, from the top to the bottom, as Icon Composer colors
SKY = ('srgb:0.07059,0.10980,0.23922,1.00000', 'srgb:0.20392,0.36078,0.54902,1.00000')
GRASS, GRASS_DARK = (88, 152, 64), (64, 120, 48)
DIRT_LEFT, DIRT_RIGHT = (122, 84, 52), (92, 62, 40)
WATER, WATER_LIGHT, WATER_SIDE = (40, 92, 196), (88, 140, 228), (28, 64, 140)
ROAD, ROAD_LINE = (78, 78, 84), (232, 200, 72)
TREE, TREE_DARK, TRUNK = (46, 112, 46), (30, 82, 34), (96, 66, 40)
LIT, DARK = (255, 214, 102), (34, 40, 58)
STAR = (255, 255, 240)


class Art:
    """The logical canvas and its isometric grid. Tile (i, j) has its top corner
    at the screen point of `point(i, j)`; `height` raises a point."""

    def __init__(self, center, top):
        self.image = Image.new('RGBA', (ART, ART), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.image)
        self.center, self.top = center, top

    def point(self, i, j, height=0):
        return (self.center + (i - j) * HALF_W, self.top + (i + j) * HALF_H - height)

    def polygon(self, points, color):
        self.draw.polygon([(round(x), round(y)) for x, y in points], fill=color)

    def box(self, i0, j0, i1, j1, height, top, left, right, base=0):
        """A box on the tiles from (i0, j0) to (i1, j1), `height` pixels tall. Returns its faces."""
        p = self.point
        north, east, south, west = (i0, j0), (i1, j0), (i1, j1), (i0, j1)
        left_face = [p(*west, base), p(*south, base), p(*south, base + height), p(*west, base + height)]
        right_face = [p(*south, base), p(*east, base), p(*east, base + height), p(*south, base + height)]
        top_face = [p(*north, base + height), p(*east, base + height), p(*south, base + height), p(*west, base + height)]
        self.polygon(left_face, left)
        self.polygon(right_face, right)
        self.polygon(top_face, top)
        return west, south, east

    def windows(self, start, end, base, height, rng, lit=0.45, columns=2, rows=3, frame=None):
        """Windows on a face from tile point `start` to `end`: one pixel in each
        `columns` across, rows each `rows` pixels, lit at random."""
        (x0, y0), (x1, y1) = self.point(*start, base), self.point(*end, base)
        steps = abs(round(x1 - x0))

        for step in range(1, steps, columns):
            t = step / steps
            x = round(x0 + (x1 - x0) * t)
            y_base = y0 + (y1 - y0) * t

            for row in range(3, height - 1, rows):
                y = round(y_base - row)
                color = LIT if rng.random() < lit else DARK
                self.draw.point((x, y), fill=color)

                if frame:
                    self.draw.point((x, y - 1), fill=frame)


def draw_art():
    rng = random.Random(2000)
    art = Art(center=40, top=34)
    p = art.point

    # the slab: grass on the land tiles, water in the bay, dirt on the sides
    edge, depth = 4, 5
    art.box(0, 0, edge, edge, depth, GRASS, DIRT_LEFT, DIRT_RIGHT, base=-depth)

    # the bay at the front right, below the land, with a lighter shore line
    art.polygon([p(3, 0), p(4, 0), p(4, 4), p(3, 4)], WATER)
    art.polygon([p(4, 0, -1), p(4, 4, -1), p(4, 4, -depth), p(4, 0, -depth)], WATER_SIDE)
    for j in range(4):
        x, y = p(3, j + 0.5)
        art.draw.point((round(x) + 3, round(y) + 1), fill=WATER_LIGHT)

    # grass texture
    for _ in range(26):
        i, j = rng.uniform(0, 3), rng.uniform(0, 4)
        x, y = p(i, j)
        art.draw.point((round(x), round(y)), fill=GRASS_DARK)

    # a road along the front of the block, with its center line
    art.polygon([p(0, 3.4), p(3, 3.4), p(3, 4), p(0, 4)], ROAD)
    for i in range(6):
        x, y = p(0.25 + i * 0.5, 3.7)
        art.draw.point((round(x), round(y)), fill=ROAD_LINE)

    # buildings from the back to the front, so nearer ones cover farther ones
    # the tall glass tower
    art.box(1, 0.75, 2, 1.75, 34, (150, 196, 230), (64, 110, 160), (42, 78, 124))
    art.box(1.25, 1.0, 1.75, 1.5, 4, (120, 168, 210), (60, 100, 150), (40, 70, 116), base=34)
    art.windows((1, 1.75), (2, 1.75), 0, 34, rng, lit=0.5, rows=3)
    art.windows((2, 1.75), (2, 0.75), 0, 34, rng, lit=0.35, rows=3)
    tip = p(1.5, 1.25, 40)
    art.draw.line([(tip[0], tip[1]), (tip[0], tip[1] - 4)], fill=(210, 210, 220))
    art.draw.point((tip[0], tip[1] - 5), fill=(255, 60, 60))

    # the stone office block at the left
    art.box(0, 0.75, 1, 2.25, 20, (214, 200, 168), (176, 156, 120), (138, 120, 92))
    art.windows((0, 2.25), (1, 2.25), 0, 20, rng, lit=0.4)
    art.windows((1, 2.25), (1, 0.75), 0, 20, rng, lit=0.3)

    # the brick building with a red roof at the right
    art.box(2.25, 0.75, 3, 1.75, 14, (196, 72, 56), (164, 92, 72), (128, 68, 54))
    art.windows((2.25, 1.75), (3, 1.75), 0, 14, rng, lit=0.6)
    art.windows((3, 1.75), (3, 0.75), 0, 14, rng, lit=0.4)

    # houses and trees at the front
    art.box(0.25, 2.5, 1, 3.25, 6, (180, 60, 52), (232, 224, 204), (196, 186, 164))
    art.windows((0.25, 3.25), (1, 3.25), 0, 6, rng, lit=0.7, rows=6)
    art.box(1.5, 2.35, 2.75, 3.1, 9, (110, 120, 132), (210, 214, 220), (170, 176, 186))
    art.windows((1.5, 3.1), (2.75, 3.1), 0, 9, rng, lit=0.5, rows=4)
    art.windows((2.75, 3.1), (2.75, 2.35), 0, 9, rng, lit=0.5, rows=4)

    for i, j in [(0.4, 2.3), (2.75, 2.1), (1.25, 2.45), (2.95, 3.25), (0.1, 3.3)]:
        x, y = p(i, j)
        x, y = round(x), round(y)
        art.draw.point((x, y), fill=TRUNK)
        art.draw.rectangle([x - 1, y - 4, x + 1, y - 1], fill=TREE)
        art.draw.point((x, y - 5), fill=TREE)
        art.draw.point((x + 1, y - 1), fill=TREE_DARK)
        art.draw.point((x - 1, y - 4), fill=TREE_DARK)

    return art.image


def city_layer():
    """The pixel art scaled to the canvas, centered on its own bounds."""
    art = draw_art()
    left, top, right, bottom = art.getbbox()
    art = art.resize((ART * PIXEL, ART * PIXEL), Image.NEAREST)
    x = SIZE // 2 - (left + right) * PIXEL // 2
    y = SIZE // 2 - (top + bottom) * PIXEL // 2
    layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    layer.paste(art, (x, y), art)
    return layer


def star_layer(city):
    """Square stars in the sky, clear of the city."""
    rng = random.Random(7)
    layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    alpha = city.getchannel('A')
    placed = 0

    while placed < STARS:
        x, y = rng.randrange(STAR_AREA[0], STAR_AREA[2]), rng.randrange(STAR_AREA[1], STAR_AREA[3])
        reach = (x - STAR_CLEARANCE, y - STAR_CLEARANCE, x + STAR_CLEARANCE, y + STAR_CLEARANCE)

        if alpha.crop(reach).getbbox():
            continue

        size = rng.choice(STAR_SIZES)
        draw.rectangle([x - size, y - size, x + size, y + size], fill=(*STAR, rng.randrange(120, 230)))
        placed += 1

    return layer


def group(image, shadow):
    """A group of one flat layer: pixel art has no glass and no highlights."""
    return {
        'layers': [{'image-name': image, 'name': Path(image).stem, 'glass': False}],
        'shadow': {'kind': shadow, 'opacity': 0.5},
        'translucency': {'enabled': False, 'value': 0.5},
        'specular': False,
    }


def write_document(folder):
    """The Icon Composer document. Its first group is in front."""
    if folder.exists():
        shutil.rmtree(folder)

    (folder / 'Assets').mkdir(parents=True)
    city = city_layer()
    city.save(folder / 'Assets/city.png')
    star_layer(city).save(folder / 'Assets/stars.png')
    document = {
        'fill': {'linear-gradient': list(SKY)},
        'groups': [group('city.png', 'neutral'), group('stars.png', 'none')],
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
