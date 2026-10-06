#!/usr/bin/env python3
"""Paint the OpenSC2K app icon and write the icon files in assets/icons.

The icon follows the box art of SimCity 2000, which every edition from 1993
to 2003 shares: an aerial view of a city on a bay under a bright sky, with
mountains on the horizon, a sandstone tower with two peaked caps and a glass
cross, round glass towers, a red suspension bridge, a stadium and a monorail.
The colors are more saturated than the painting, so the icon is bright at small sizes.

The art is vector: each layer is an SVG. Each layer also has a dusk version for
the dark appearance, with a sunset sky and lit windows.

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
import colorsys
import json
from pathlib import Path
import random
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

# the aerial view: the fall of a horizontal edge across a building face, and the horizon
SLOPE = 0.30
HORIZON = 500
# the scene is drawn larger than the canvas from this point at the bottom, so the city fills the sky
ZOOM, ZOOM_ORIGIN = 1.07, (560, 1024)

# the sky fill from the top to the horizon, by day and at dusk
SKY_DAY = ('#0a4fd8', '#72ccff')
SKY_DUSK = ('#0c1250', '#ff6a4a')
# each color of the art has its saturation multiplied by this
SATURATION = 1.6
# at dusk each color moves toward this blue and toward black; lights keep their color
DUSK, DUSK_BLUE, DUSK_DARK = '#1b2350', 0.55, 0.25
LIT = '#ffd77a'
# the colors that the box art is known for
STONE_TOP, STONE_LEFT, STONE_RIGHT = '#f6d6a6', '#f2c38a', '#bd8452'
TEAL_LIGHT, TEAL_DARK = '#4cc4d2', '#155d7c'
VIOLET_LIGHT, VIOLET_DARK = '#a2a8f0', '#3c3c8e'
BRIDGE_RED, BRIDGE_RED_DARK = '#dc3a2a', '#981f16'

# the layers from the front to the back: (name, Liquid Glass, shadow)
LAYERS = (('city', False, 'neutral'), ('land', False, 'none'))


ZOOM_TRANSFORM = (f'translate({ZOOM_ORIGIN[0]},{ZOOM_ORIGIN[1]}) scale({ZOOM}) '
                  f'translate({-ZOOM_ORIGIN[0]},{-ZOOM_ORIGIN[1]})')


def hex_rgb(value):
    value = value.lstrip('#')
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def rgb_hex(rgb):
    return '#' + ''.join(f'{max(0, min(255, round(c))):02x}' for c in rgb)


def mix(a, b, t):
    a, b = hex_rgb(a), hex_rgb(b)
    return rgb_hex([x + (y - x) * t for x, y in zip(a, b)])


def saturate(value, factor=SATURATION):
    hue, lightness, saturation = colorsys.rgb_to_hls(*(c / 255 for c in hex_rgb(value)))
    return rgb_hex([c * 255 for c in colorsys.hls_to_rgb(hue, lightness, min(1.0, saturation * factor))])


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def points(values):
    return ' '.join(f'{x:.1f},{y:.1f}' for x, y in values)


class Svg:
    """One layer of the icon. At dusk each color is darker and bluer, except
    the colors that are marked as lights."""

    def __init__(self, dusk=False):
        self.defs, self.body, self.dusk, self.ids = [], [], dusk, 0

    def color(self, value, light=False):
        if not self.dusk or light:
            return saturate(value)

        return saturate(mix(mix(value, DUSK, DUSK_BLUE), '#000000', DUSK_DARK))

    def paint(self, value, light=False):
        return value if value.startswith('url(') or value == 'none' else self.color(value, light)

    def gradient(self, stops, x2=0, y2=1, light=False):
        """A linear gradient from the top left of a shape. Each stop is (offset, color[, opacity])."""
        self.ids += 1
        name = f'g{self.ids}'
        parts = ''.join(f'<stop offset="{s[0]}" stop-color="{self.color(s[1], light)}" '
                        f'stop-opacity="{s[2] if len(s) > 2 else 1}"/>' for s in stops)
        self.defs.append(f'<linearGradient id="{name}" x1="0" y1="0" x2="{x2}" y2="{y2}">{parts}</linearGradient>')
        return f'url(#{name})'

    def radial(self, stops):
        self.ids += 1
        name = f'g{self.ids}'
        parts = ''.join(f'<stop offset="{o}" stop-color="{self.color(c)}" stop-opacity="{a}"/>' for o, c, a in stops)
        self.defs.append(f'<radialGradient id="{name}">{parts}</radialGradient>')
        return f'url(#{name})'

    def polygon(self, values, fill, light=False, extra=''):
        self.body.append(f'<polygon points="{points(values)}" fill="{self.paint(fill, light)}"{extra}/>')

    def path(self, d, fill='none', stroke=None, width=None, light=False, extra=''):
        line = f' stroke="{self.paint(stroke, light)}" stroke-width="{width}"' if stroke else ''
        self.body.append(f'<path d="{d}" fill="{self.paint(fill, light)}"{line}{extra}/>')

    def ellipse(self, cx, cy, rx, ry, fill, light=False, extra=''):
        self.body.append(f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" '
                         f'fill="{self.paint(fill, light)}"{extra}/>')

    def text(self):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">'
                f'<defs>{"".join(self.defs)}</defs><g transform="{ZOOM_TRANSFORM}">{"".join(self.body)}</g></svg>\n')


def face_point(face, u, v):
    """A point on a face: `u` across from its left edge, `v` up from its bottom edge."""
    bottom_left, bottom_right, top_right, top_left = face
    return lerp(lerp(bottom_left, bottom_right, u), lerp(top_left, top_right, u), v)


def face_part(face, u0, u1, v0, v1):
    return [face_point(face, u0, v0), face_point(face, u1, v0), face_point(face, u1, v1), face_point(face, u0, v1)]


def ribbons(svg, face, rows, color, size, rng, panes=6):
    """Bands of windows across a face. At dusk about half of their panes are lit."""
    for row in range(rows):
        v0, v1 = (row + 0.5 - size / 2) / rows, (row + 0.5 + size / 2) / rows
        svg.polygon(face_part(face, 0.06, 0.94, v0, v1), color)

        if not svg.dusk:
            continue

        for pane in range(panes):
            if rng.random() < 0.5:
                u0, u1 = 0.06 + 0.88 * (pane + 0.15) / panes, 0.06 + 0.88 * (pane + 0.85) / panes
                svg.polygon(face_part(face, u0, u1, v0, v1), LIT, light=True)


def punched(svg, face, columns, rows, color, rng, u_range, v_range):
    """Small square windows in a stone face."""
    u_span, v_span = u_range[1] - u_range[0], v_range[1] - v_range[0]
    du, dv = u_span / columns * 0.22, v_span / rows * 0.28

    for row in range(rows):
        for column in range(columns):
            u = u_range[0] + u_span * (column + 0.5) / columns
            v = v_range[0] + v_span * (row + 0.5) / rows
            lit = svg.dusk and rng.random() < 0.45
            svg.polygon(face_part(face, u - du, u + du, v - dv, v + dv), LIT if lit else color, light=lit)


def prism(svg, near, left_width, right_width, height, top, left, right):
    """A building seen from above, lit from the left: its near bottom corner,
    the widths of its left and right faces, and its height. Returns the faces."""
    x, y = near
    left_bottom, right_bottom = (x - left_width, y - left_width * SLOPE), (x + right_width, y - right_width * SLOPE)
    left_top, near_top = (left_bottom[0], left_bottom[1] - height), (x, y - height)
    right_top = (right_bottom[0], right_bottom[1] - height)
    far_top = (x - left_width + right_width, y - height - (left_width + right_width) * SLOPE)
    left_face, right_face = [left_bottom, near, near_top, left_top], [near, right_bottom, right_top, near_top]

    svg.polygon(left_face, svg.gradient([(0, mix(left, '#ffffff', 0.12)), (1, mix(left, '#3a3550', 0.18))]))
    svg.polygon(right_face, svg.gradient([(0, right), (1, mix(right, '#2a2540', 0.28))]))
    svg.polygon([near_top, right_top, far_top, left_top], top)
    return left_face, right_face, (left_top, near_top, right_top, far_top)


def capsule(svg, cx, base, radius, top, light, dark, rng, floors):
    """A round tower with a domed top, lit from the left, with floor lines around it."""
    fill = svg.gradient([(0, light), (0.3, mix(light, '#ffffff', 0.45)), (0.5, light), (1, dark)], x2=1, y2=0)
    rise = radius * SLOPE
    svg.path(f'M{cx - radius:.1f},{base:.1f} L{cx - radius:.1f},{top + radius:.1f} '
             f'A{radius:.1f},{radius:.1f} 0 0 1 {cx + radius:.1f},{top + radius:.1f} '
             f'L{cx + radius:.1f},{base:.1f} A{radius:.1f},{rise:.1f} 0 0 1 {cx - radius:.1f},{base:.1f} Z', fill)

    for floor in range(floors):
        y = top + radius + 18 + floor * (base - top - radius - 30) / max(1, floors - 1)
        svg.path(f'M{cx - radius:.1f},{y:.1f} A{radius:.1f},{rise:.1f} 0 0 0 {cx + radius:.1f},{y:.1f}',
                 stroke=mix(dark, '#000000', 0.2), width=3, extra=' opacity="0.35"')

        if svg.dusk and rng.random() < 0.5:
            x = cx + rng.uniform(-0.7, 0.3) * radius
            svg.path(f'M{x:.1f},{y + 6:.1f} l{radius * 0.35:.1f},0', stroke=LIT, width=5, light=True)


def land_layer(dusk=False):
    """The clouds, the mountains, the ground with its streets and parks, the far skyline and the bay."""
    svg = Svg(dusk)
    rng = random.Random(1993)

    # soft cumulus clouds at the left and the right of the sky, as on the box
    cloud = svg.radial([(0, '#ffffff', 0.95), (0.65, '#f4f8fc', 0.85), (1, '#dfeaf4', 0)])
    for cx, cy, r in [(100, 330, 66), (175, 300, 80), (258, 322, 60), (40, 360, 52), (310, 345, 40),
                      (830, 360, 46), (900, 338, 64), (975, 362, 52)]:
        svg.ellipse(cx, cy, r * 1.3, r * 0.82, cloud)

    # the mountains: a lit slope and a shaded slope on each peak, in haze
    haze = svg.gradient([(0, '#c9dbe8', 0.05), (1, '#d3e2ec', 0.95)])
    for left, peak, right in [((-60, HORIZON), (130, 372), (330, HORIZON)), ((180, HORIZON), (390, 402), (590, HORIZON)),
                              ((540, HORIZON), (760, 392), (950, HORIZON)), ((780, HORIZON), (985, 368), (1160, HORIZON))]:
        foot = (peak[0] + 40, HORIZON)
        svg.polygon([left, peak, foot], '#d9a96d')
        svg.polygon([peak, right, foot], '#a0704a')
        svg.polygon([left, peak, right], haze)

    ground = svg.gradient([(0, '#bccaa8'), (0.2, '#cdc292'), (1, '#dcc890')])
    svg.polygon([(0, HORIZON), (SIZE, HORIZON), (SIZE, SIZE), (0, SIZE)], ground)

    # the streets of the grid: the avenues fall to the left, the cross streets
    # rise to the right and stop at the horizon
    for k in range(-4, 10):
        x = 130 * k
        svg.path(f'M{x},{HORIZON + 10} L{x - 300},{SIZE + 40}', stroke='#efe7d0', width=5, extra=' opacity="0.45"')

    rise = 300 / (SIZE + 40)
    for y in range(580, SIZE + 300, 90):
        x_end = min(SIZE + 20, -20 + (y - HORIZON - 10) / rise)
        svg.path(f'M-20,{y} L{x_end:.1f},{y - (x_end + 20) * rise:.1f}', stroke='#efe7d0', width=5, extra=' opacity="0.4"')

    for cx, cy, rx, ry in [(150, 620, 110, 26), (110, 840, 120, 34), (360, 680, 80, 20)]:
        svg.ellipse(cx, cy, rx, ry, '#8ab35e')

        for _ in range(9):
            svg.ellipse(cx + rng.uniform(-0.8, 0.8) * rx, cy + rng.uniform(-0.6, 0.6) * ry, 9, 7, '#5f8f44')

    # the far skyline, faded by distance
    for k in range(15):
        x, height, width = 10 + k * 70 + rng.uniform(-12, 12), rng.uniform(40, 110), rng.uniform(24, 44)
        prism(svg, (x, HORIZON + 30 + rng.uniform(0, 12)), width * 0.6, width * 0.5, height, '#dbe3ea', '#bccbd8', '#98acc0')

    # the bay at the lower right, with a sandy shore and ripples
    shore = f'M{SIZE + 10},640 C910,660 780,690 705,760 C630,830 610,910 575,{SIZE + 10} L{SIZE + 10},{SIZE + 10} Z'
    svg.path(shore, '#ece0bd', extra=' transform="translate(-12,-8)"')
    svg.path(shore, svg.gradient([(0, '#9ad3ee'), (0.5, '#5fa6da'), (1, '#3a7fc4')]))

    for k in range(6):
        svg.path(f'M{770 + k * 34},{760 + k * 48} q30,-8 60,0', stroke='#e2f4fc', width=4, extra=' opacity="0.55"')

    return svg.text()


def sandstone_tower(svg, rng):
    """The tower at the center of the box art: two stone slabs split by a glass
    channel, a glass band across them, and a peaked cap on each slab."""
    left, right, top = prism(svg, (492, 930), 142, 124, 500, STONE_TOP, STONE_LEFT, STONE_RIGHT)
    glass_left = svg.gradient([(0, '#a8daf7'), (1, '#5a98d6')])
    glass_right = svg.gradient([(0, '#6496d0'), (1, '#2c5a98')])

    for face, glass, window in [(left, glass_left, '#9b6a40'), (right, glass_right, '#714728')]:
        for u_range in [(0.07, 0.40), (0.60, 0.93)]:
            punched(svg, face, 3, 9, window, rng, u_range, (0.04, 0.54))
            punched(svg, face, 3, 5, window, rng, u_range, (0.70, 0.97))

        svg.polygon(face_part(face, 0.43, 0.57, 0, 1), glass)
        svg.polygon(face_part(face, 0, 1, 0.58, 0.66), glass)

    left_top, near_top, right_top, far_top = top
    middle_near, middle_far = lerp(left_top, near_top, 0.5), lerp(far_top, right_top, 0.5)

    for west, south, east, north in [(left_top, middle_near, middle_far, far_top), (middle_near, near_top, right_top, middle_far)]:
        apex = ((west[0] + east[0]) / 2, (north[1] + south[1]) / 2 - 92)
        svg.polygon([north, west, apex], '#f8deb4')
        svg.polygon([north, east, apex], '#e2ae78')
        svg.polygon([west, south, apex], '#f6cd94')
        svg.polygon([south, east, apex], '#c08a58')

    svg.polygon([lerp(left_top, near_top, 0.46), lerp(left_top, near_top, 0.54),
                 lerp(far_top, right_top, 0.54), lerp(far_top, right_top, 0.46)], '#7ab4e4')


def monorail(svg):
    """The monorail on its curved guideway across the front, as on the box."""
    pier = svg.gradient([(0, '#e8e4dc'), (1, '#a49e94')], x2=1, y2=0)
    for x, y in [(60, 860), (190, 892), (300, 948)]:
        svg.polygon([(x - 9, y), (x + 9, y), (x + 7, SIZE + 20), (x - 7, SIZE + 20)], pier)

    track = 'M-40,846 C140,868 300,930 420,1060'
    svg.path(track, stroke='#8c8780', width=30, extra=' transform="translate(0,6)"')
    svg.path(track, stroke='#f2eee6', width=24)

    train = 'M-40,822 C60,832 150,852 236,884'
    svg.path(train, stroke='#6b7380', width=46, extra=' stroke-linecap="round" transform="translate(0,4)"')
    svg.path(train, stroke=svg.gradient([(0, '#ffffff'), (0.6, '#d7dce3'), (1, '#9aa3ae')]), width=40,
             extra=' stroke-linecap="round"')
    svg.path(train, stroke=LIT if svg.dusk else '#3a5f9a', width=10, light=svg.dusk,
             extra=' stroke-dasharray="26 8" transform="translate(0,-4)"')


def bridge(svg):
    """The red suspension bridge across the bay."""
    deck_start, deck_end = (612, 1012), (1044, 806)
    svg.path(f'M{deck_start[0]},{deck_start[1]} L{deck_end[0]},{deck_end[1]}', stroke='#6e271e', width=16)
    svg.path(f'M{deck_start[0]},{deck_start[1] - 7} L{deck_end[0]},{deck_end[1] - 7}', stroke='#eadccb', width=6)

    towers = [lerp(deck_start, deck_end, 0.38), lerp(deck_start, deck_end, 0.8)]
    (x0, y0), (x1, y1) = towers
    for cable in [f'M{x0},{y0 - 150} Q{(x0 + x1) / 2},{(y0 + y1) / 2 - 30} {x1},{y1 - 154}',
                  f'M{deck_start[0]},{deck_start[1] - 12} Q{(deck_start[0] + x0) / 2 + 10},{(deck_start[1] + y0) / 2 - 12} {x0},{y0 - 150}',
                  f'M{x1},{y1 - 154} Q{(x1 + deck_end[0]) / 2},{(y1 + deck_end[1]) / 2 - 40} {deck_end[0]},{deck_end[1] - 60}']:
        svg.path(cable, stroke=BRIDGE_RED, width=6)

    for x, y in towers:
        svg.polygon([(x - 13, y + 30), (x - 5, y + 30), (x - 5, y - 150), (x - 11, y - 150)], BRIDGE_RED)
        svg.polygon([(x + 5, y + 26), (x + 13, y + 26), (x + 11, y - 154), (x + 5, y - 154)], BRIDGE_RED_DARK)

        for k in range(3):
            y_beam = y - 140 + k * 55
            svg.polygon([(x - 11, y_beam), (x + 11, y_beam - 4), (x + 11, y_beam + 6), (x - 11, y_beam + 10)], BRIDGE_RED)

    if svg.dusk:
        for k in range(1, 12):
            x, y = lerp(deck_start, deck_end, k / 12)
            svg.ellipse(x, y - 10, 4, 4, LIT, light=True)


def city_layer(dusk=False):
    """The buildings, the monorail and the bridge, from the back to the front."""
    svg = Svg(dusk)
    rng = random.Random(2000)

    # the round stadium with a red rim on the far shore
    svg.ellipse(900, 606, 66, 25, '#8f2c22')
    svg.ellipse(900, 598, 66, 25, '#d24a36')
    svg.ellipse(900, 598, 50, 17, '#efe6d4')
    svg.ellipse(900, 600, 34, 11, '#6fae4c')

    # towers in the middle distance, behind the main group
    for near, left_width, right_width, height, colors in [
            ((120, 650), 48, 42, 220, ('#efe4d2', '#d8c3a5', '#a48e72')),
            ((835, 560), 34, 40, 270, ('#d79f78', '#b8714a', '#874e32')),
            ((548, 600), 36, 38, 300, ('#e2ebf4', '#adc4da', '#7c95b1')),
            ((420, 590), 30, 30, 210, ('#f1e7d8', '#cdbfae', '#9b8d7c'))]:
        left, right, _ = prism(svg, near, left_width, right_width, height, *colors)
        ribbons(svg, left, height // 24, '#7f8ea4', 0.32, rng, 3)
        ribbons(svg, right, height // 24, '#5e6c84', 0.32, rng, 3)

    # the teal glass tower with a round top, with a reflection down its lit side
    capsule(svg, 272, 770, 72, 222, TEAL_LIGHT, TEAL_DARK, rng, 15)
    shine = svg.gradient([(0, '#ffffff', 0), (0.5, '#ffffff', 0.5), (1, '#ffffff', 0)], x2=1, y2=0, light=dusk)
    svg.path('M222,300 L222,756 L240,762 L240,292 Z', shine, extra=' opacity="0.7"')

    for cx, top, base in [(612, 338, 712), (686, 358, 700), (756, 384, 690)]:
        capsule(svg, cx, base, 38, top, VIOLET_LIGHT, VIOLET_DARK, rng, 9)

    left, right, _ = prism(svg, (782, 790), 70, 88, 150, '#e08868', '#c95c3e', '#8e3926')
    ribbons(svg, left, 6, '#5a2418', 0.35, rng, 4)
    ribbons(svg, right, 6, '#4a1c12', 0.35, rng, 4)

    sandstone_tower(svg, rng)
    monorail(svg)

    # the blue-violet glass block in front, at the right of the tower
    left, right, _ = prism(svg, (676, 972), 60, 110, 166, '#d2daf6', '#8a99dc', '#4d5ca8')
    ribbons(svg, left, 8, '#e6ecff', 0.3, rng, 3)
    ribbons(svg, right, 8, '#aab6ec', 0.3, rng, 5)

    bridge(svg)
    return svg.text()


PAINTERS = {'city': city_layer, 'land': land_layer}


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
