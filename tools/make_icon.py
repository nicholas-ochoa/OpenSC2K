#!/usr/bin/env python3
"""Draw the OpenSC2K app icon and write assets/icons/OpenSC2K.png, .icns and .ico.

The icon is pixel art on a 2:1 isometric grid, in the style of the game: a
city block on a slab of land at the edge of a bay, drawn at a small logical
size and scaled up with nearest sampling, on a rounded square of night sky.

  python3 tools/make_icon.py            # write the icon files
  python3 tools/make_icon.py --preview out.png
"""
import argparse
from pathlib import Path
import random
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ICONS = ROOT / 'assets/icons'
SIZE = 1024
# the macOS icon grid: the rounded square and its corner radius
PLATE = 824
PLATE_RADIUS = 186
# the pixel art: its logical size and the scale of one logical pixel
ART = 80
PIXEL = 10
# one tile of the isometric grid: half its width and half its height
HALF_W, HALF_H = 8, 4

SKY_TOP, SKY_BOTTOM = (18, 28, 61), (52, 92, 140)
GRASS, GRASS_DARK = (88, 152, 64), (64, 120, 48)
DIRT_LEFT, DIRT_RIGHT = (122, 84, 52), (92, 62, 40)
WATER, WATER_LIGHT, WATER_SIDE = (40, 92, 196), (88, 140, 228), (28, 64, 140)
ROAD, ROAD_LINE = (78, 78, 84), (232, 200, 72)
TREE, TREE_DARK, TRUNK = (46, 112, 46), (30, 82, 34), (96, 66, 40)
LIT, DARK = (255, 214, 102), (34, 40, 58)


def shade(color, factor):
    return tuple(max(0, min(255, round(channel * factor))) for channel in color)


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


def plate_mask(size, inset, radius):
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([inset, inset, size - inset - 1, size - inset - 1], radius=radius, fill=255)
    return mask


def draw_icon():
    scale = 4  # draw the smooth parts larger, then reduce them for soft edges
    big = SIZE * scale
    inset = (SIZE - PLATE) // 2 * scale
    sky = Image.new('RGBA', (big, big))
    pixels = sky.load()

    for y in range(big):
        t = y / big
        color = tuple(round(a + (b - a) * t) for a, b in zip(SKY_TOP, SKY_BOTTOM))
        for x in range(big):
            pixels[x, y] = (*color, 255)

    mask = plate_mask(big, inset, PLATE_RADIUS * scale)
    plate = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    plate.paste(sky, (0, 0), mask)

    # stars in the night sky
    rng = random.Random(7)
    stars = ImageDraw.Draw(plate)
    for _ in range(40):
        x, y = rng.randrange(inset + 120, big - inset - 120), rng.randrange(inset + 120, big // 2)
        radius = rng.choice([6, 8, 10])
        stars.ellipse([x - radius, y - radius, x + radius, y + radius], fill=(255, 255, 240, rng.randrange(90, 200)))

    plate = plate.resize((SIZE, SIZE), Image.LANCZOS)

    # a soft shadow under the plate, as macOS icons have
    shadow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 110), (0, 12), plate_mask(SIZE, (SIZE - PLATE) // 2, PLATE_RADIUS))
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    icon = Image.alpha_composite(shadow, plate)

    # the pixel art, scaled up with nearest sampling and centered on the plate
    art = draw_art().resize((ART * PIXEL, ART * PIXEL), Image.NEAREST)
    offset = ((SIZE - art.width) // 2, (SIZE - art.height) // 2 + 30)
    layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    layer.paste(art, offset, art)
    clipped = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    clipped.paste(layer, (0, 0), plate_mask(SIZE, (SIZE - PLATE) // 2, PLATE_RADIUS))

    # a thin light edge at the top of the plate
    edge = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle(
        [(SIZE - PLATE) // 2, (SIZE - PLATE) // 2, (SIZE + PLATE) // 2 - 1, (SIZE + PLATE) // 2 - 1],
        radius=PLATE_RADIUS, outline=(255, 255, 255, 40), width=3)

    return Image.alpha_composite(Image.alpha_composite(icon, clipped), edge)


def write_icons(icon):
    icon.save(ICONS / 'OpenSC2K.png')
    icon.save(ICONS / 'OpenSC2K.ico', sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])

    if shutil.which('iconutil'):
        with tempfile.TemporaryDirectory() as work:
            iconset = Path(work) / 'OpenSC2K.iconset'
            iconset.mkdir()
            for size in (16, 32, 128, 256, 512):
                icon.resize((size, size), Image.LANCZOS).save(iconset / f'icon_{size}x{size}.png')
                icon.resize((size * 2, size * 2), Image.LANCZOS).save(iconset / f'icon_{size}x{size}@2x.png')
            subprocess.run(['iconutil', '-c', 'icns', str(iconset), '-o', str(ICONS / 'OpenSC2K.icns')], check=True)
    else:
        print('iconutil is missing: OpenSC2K.icns stays as it is.', file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--preview', type=Path, help='Write only a preview PNG to this path')
    args = parser.parse_args()
    icon = draw_icon()

    if args.preview:
        icon.save(args.preview)
    else:
        write_icons(icon)

    return 0


if __name__ == '__main__':
    sys.exit(main())
