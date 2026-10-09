#!/usr/bin/env python3
"""Paint the layers of the OpenSC2K app icon as SVG, after the SimCity 2000 box art.

The scene is an aerial view of a city on a bay: mountains on the horizon, a
street grid of blocks with houses, shops, offices and parks, contemporary glass
towers around the sandstone tower of the box art, a stadium, a monorail, a
suspension bridge, boats, and the red helicopter of the game.

The view is a parallel projection. The ground axes `u` and `v` run along the
right faces and the left faces of the buildings, so the streets line up with
the buildings. Everything that stands is drawn from the back to the front by
its footprint on the ground.

This script writes the SVG layers and icon.json of game/assets/icons/OpenSC2K.icon,
for day and for dusk. Each object is its own named group. It replaces hand
edits of the SVG files, so carry those edits into this script first. Then run
tools/make_icon.py to build the icon files.

  python3 tools/paint_icon.py              # write game/assets/icons/OpenSC2K.icon
  python3 tools/paint_icon.py out.icon     # write another document
"""
from contextlib import contextmanager
import colorsys
import json
import math
from pathlib import Path
import random
import sys

SIZE = 1024
SLOPE = 0.30
HORIZON = 500
ZOOM, ZOOM_ORIGIN = 1.07, (560, 1024)
VIEW = SIZE / ZOOM
VIEW_X, VIEW_Y = ZOOM_ORIGIN[0] - ZOOM_ORIGIN[0] / ZOOM, ZOOM_ORIGIN[1] - ZOOM_ORIGIN[1] / ZOOM

GRID_ORIGIN = (330, 888.6)
BLOCK, ROAD, SIDEWALK = 160, 14, 5
HAZE_DEPTH, STANDING_DEPTH = 170, 110

SKY_DAY = ('#0a4fd8', '#72ccff')
SKY_DUSK = ('#0c1250', '#ff6a4a')
SATURATION = 1.6
DUSK, DUSK_BLUE, DUSK_DARK = '#1b2350', 0.55, 0.25
LIT = '#ffd77a'
LIGHTS_SEED = 1995

STONE_TOP, STONE_LEFT, STONE_RIGHT = '#f6d6a6', '#f2c38a', '#bd8452'
BRIDGE_RED, BRIDGE_RED_DARK = '#dc3a2a', '#981f16'
ASPHALT, ROAD_LINE, CONCRETE = '#6a6d78', '#f4e7a4', '#ddd4c2'
LAWN, PARK, TREE, TREE_LIGHT = '#94c95a', '#78bd48', '#3f8a32', '#6cb846'
HOUSE_WALLS = ('#f4ecd8', '#f2e2b0', '#e8eef2', '#f0d2b8')
HOUSE_ROOFS = ('#c8452f', '#9a5a36', '#4f6fb0', '#3f8a6a', '#b84a5a')
SHOP_COLORS = (('#f0e2c8', '#e2c49a', '#b08e64'), ('#e6eef6', '#b8cce0', '#7f98b4'),
               ('#f6d8c8', '#e2a080', '#b06a4a'), ('#e8f0dc', '#bcd29a', '#86a066'))
CAR_COLORS = ('#e03a2e', '#f2c430', '#ffffff', '#2e7ad8', '#30a060')

# glass: roof, left face top and bottom, right face top and bottom, mullions
TEAL_GLASS = ('#c8f4fa', '#8ae4f2', '#2a9cc0', '#2f8cb4', '#124a68', '#e8fbff')
VIOLET_GLASS = ('#dcdcff', '#b4baf6', '#6a70d0', '#5a5fc0', '#2c2c78', '#eef0ff')
SILVER_GLASS = ('#eef4fa', '#d4e2f0', '#8aa2bc', '#8ea4be', '#46586e', '#ffffff')
GREEN_GLASS = ('#d8f4ea', '#a8e0cc', '#4a9a86', '#4a8a7a', '#1e4a42', '#f0fff8')

SHORE = (((1034, 640), (920, 660), (840, 700), (820, 780)),
         ((820, 780), (800, 860), (700, 930), (640, 1034)))
SHORE_STEPS = 24

HERO = ((492, 930), 142, 124, 500)
GLASS_TOWERS = (('tower-teal-glass', (272, 800), 70, 74, 560, TEAL_GLASS, 'slant'),
                ('tower-violet-glass', (630, 712), 48, 58, 380, VIOLET_GLASS, 'setback'),
                ('tower-silver-glass', (735, 690), 50, 50, 300, SILVER_GLASS, 'flat'),
                ('tower-far-green-glass', (835, 560), 34, 40, 270, GREEN_GLASS, 'flat'),
                ('tower-far-silver-glass', (548, 600), 36, 38, 300, SILVER_GLASS, 'setback'))
RIBBON_TOWERS = (('tower-far-cream', (120, 650), 48, 42, 220, ('#efe4d2', '#d8c3a5', '#a48e72')),
                 ('tower-far-stone', (420, 590), 30, 30, 210, ('#f1e7d8', '#cdbfae', '#9b8d7c')))
BRICK = ((740, 772), 56, 74, 150)
# the stadium, and the plaza where it stood first, which now has a copy of a shop
STADIUM_CENTER, STADIUM_RADIUS = (968.54, 558.12), 66
STADIUM_PLAZA = (900, 598)
# copies of small buildings: name, the near corner of the original, and the move of the copy
COPIES = (('shop-near-stadium', (-58.0, 760.1), (930.45269, -136.95891)),)
# the helicopter: its center, its tilt, and its scale
HELICOPTER = ((440, 214), -8, 1.25)

BRIDGE_V, BRIDGE_U = 330, (-90, 560)
BRIDGE_TOWERS_U = (95, 285)
DECK_WIDTH, DECK_HEIGHT, DECK_DEPTH = 24, 20, 6
TOWER_HEIGHT, CABLE_LOW = 150, 32

RAIL_TRACK = ((-40, 846), (140, 868), (300, 930), (420, 1060))
RAIL_TRAIN = ((-40, 822), (60, 832), (150, 852), (236, 884))
RAIL_PIERS, RAIL_HEIGHT = (60, 190, 300), 64


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


def ground(u, v, height=0):
    return (GRID_ORIGIN[0] + u + v, GRID_ORIGIN[1] + SLOPE * (v - u) - height)


def ground_point(x, y):
    dx, dy = x - GRID_ORIGIN[0], (y - GRID_ORIGIN[1]) / SLOPE
    return ((dx - dy) / 2, (dx + dy) / 2)


def ground_area(u0, u1, v0, v1, height=0):
    return [ground(u0, v1, height), ground(u1, v1, height), ground(u1, v0, height), ground(u0, v0, height)]


def box_footprint(near, left_width, right_width):
    u, v = ground_point(*near)
    return (u, u + right_width, v - left_width, v)


def round_footprint(center, radius):
    u, v = ground_point(*center)
    r = radius / math.sqrt(2)
    return (u - r, u + r, v - r, v + r)


def overlap_area(a, b):
    return max(0, min(a[1], b[1]) - max(a[0], b[0])) * max(0, min(a[3], b[3]) - max(a[2], b[2]))


def grown(footprint, margin):
    u0, u1, v0, v1 = footprint
    return (u0 - margin, u1 + margin, v0 - margin, v1 + margin)


def overlaps(a, b):
    return a[0] < b[1] and b[0] < a[1] and a[2] < b[3] and b[2] < a[3]


def clip_below(polygon, y_limit):
    result = []
    for k, current in enumerate(polygon):
        previous = polygon[k - 1]
        inside, was_inside = current[1] >= y_limit, previous[1] >= y_limit
        if inside != was_inside:
            result.append(lerp(previous, current, (y_limit - previous[1]) / (current[1] - previous[1])))
        if inside:
            result.append(current)
    return result


def contains(polygon, point):
    x, y = point
    inside = False
    for k, (x1, y1) in enumerate(polygon):
        x0, y0 = polygon[k - 1]
        if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
            inside = not inside
    return inside


def bezier(p0, p1, p2, p3, t):
    s = 1 - t
    return tuple(s ** 3 * a + 3 * s * s * t * b + 3 * s * t * t * c + t ** 3 * d for a, b, c, d in zip(p0, p1, p2, p3))


def curve_path(curve):
    (x0, y0), (x1, y1), (x2, y2), (x3, y3) = curve
    return f'M{x0},{y0} C{x1},{y1} {x2},{y2} {x3},{y3}'


def water_area():
    shore = [bezier(*curve, step / SHORE_STEPS) for curve in SHORE for step in range(SHORE_STEPS + 1)]
    return shore + [(SIZE + 10, SIZE + 10)]


class Svg:
    def __init__(self, dusk=False):
        self.body, self.dusk, self.ids = [], dusk, 0
        self.lights = random.Random(LIGHTS_SEED)
        self.names = ['art']

    @contextmanager
    def group(self, name, transform=None):
        moved = f' transform="{transform}"' if transform else ''
        self.body.append(f'<g id="{name}"{moved}>')
        self.names.append(name)
        yield
        self.names.pop()
        self.body.append('</g>')

    def color(self, value, light=False):
        if not self.dusk or light:
            return saturate(value)
        return saturate(mix(mix(value, DUSK, DUSK_BLUE), '#000000', DUSK_DARK))

    def paint(self, value, light=False):
        return value if value.startswith('url(') or value == 'none' else self.color(value, light)

    def _name(self):
        self.ids += 1
        return f'{self.names[-1]}-paint{self.ids}'

    def gradient(self, stops, x2=0, y2=1, light=False):
        name = self._name()
        parts = ''.join(f'<stop offset="{s[0]}" stop-color="{self.color(s[1], light)}" '
                        f'stop-opacity="{s[2] if len(s) > 2 else 1}"/>' for s in stops)
        self.body.append(f'<defs><linearGradient id="{name}" x1="0" y1="0" x2="{x2}" y2="{y2}">{parts}</linearGradient></defs>')
        return f'url(#{name})'

    def radial(self, stops):
        name = self._name()
        parts = ''.join(f'<stop offset="{o}" stop-color="{self.color(c)}" stop-opacity="{a}"/>' for o, c, a in stops)
        self.body.append(f'<defs><radialGradient id="{name}">{parts}</radialGradient></defs>')
        return f'url(#{name})'

    def polygon(self, values, fill, light=False, extra=''):
        if len(values) >= 3:
            self.body.append(f'<polygon points="{points(values)}" fill="{self.paint(fill, light)}"{extra}/>')

    def path(self, d, fill='none', stroke=None, width=None, light=False, extra=''):
        line = f' stroke="{self.paint(stroke, light)}" stroke-width="{width}"' if stroke else ''
        self.body.append(f'<path d="{d}" fill="{self.paint(fill, light)}"{line}{extra}/>')

    def line(self, start, end, stroke, width, light=False, extra=''):
        self.path(f'M{start[0]:.1f},{start[1]:.1f} L{end[0]:.1f},{end[1]:.1f}', stroke=stroke, width=width,
                  light=light, extra=extra)

    def polyline(self, values, stroke, width, light=False, extra=''):
        self.body.append(f'<polyline points="{points(values)}" fill="none" stroke="{self.paint(stroke, light)}" '
                         f'stroke-width="{width}"{extra}/>')

    def ellipse(self, cx, cy, rx, ry, fill, light=False, extra=''):
        self.body.append(f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" '
                         f'fill="{self.paint(fill, light)}"{extra}/>')

    def text(self):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" '
                f'viewBox="{VIEW_X:.2f} {VIEW_Y:.2f} {VIEW:.2f} {VIEW:.2f}">\n'
                + '\n'.join(self.body).replace('\n<g id', '\n<g id') + '\n</svg>\n')


def face_point(face, u, v):
    bottom_left, bottom_right, top_right, top_left = face
    return lerp(lerp(bottom_left, bottom_right, u), lerp(top_left, top_right, u), v)


def face_part(face, u0, u1, v0, v1):
    return [face_point(face, u0, v0), face_point(face, u1, v0), face_point(face, u1, v1), face_point(face, u0, v1)]


def roof_point(top, u, v):
    left_top, near_top, right_top, _ = top
    return (near_top[0] + u * (right_top[0] - near_top[0]) + v * (left_top[0] - near_top[0]),
            near_top[1] + u * (right_top[1] - near_top[1]) + v * (left_top[1] - near_top[1]))


def ribbons(svg, face, rows, color, size, panes=6):
    for row in range(rows):
        v0, v1 = (row + 0.5 - size / 2) / rows, (row + 0.5 + size / 2) / rows
        svg.polygon(face_part(face, 0.06, 0.94, v0, v1), color)
        if not svg.dusk:
            continue
        for pane in range(panes):
            if svg.lights.random() < 0.5:
                u0, u1 = 0.06 + 0.88 * (pane + 0.15) / panes, 0.06 + 0.88 * (pane + 0.85) / panes
                svg.polygon(face_part(face, u0, u1, v0, v1), LIT, light=True)


def punched(svg, face, columns, rows, color, u_range=(0.08, 0.92), v_range=(0.04, 0.96)):
    u_span, v_span = u_range[1] - u_range[0], v_range[1] - v_range[0]
    du, dv = u_span / columns * 0.22, v_span / rows * 0.28
    for row in range(rows):
        for column in range(columns):
            u = u_range[0] + u_span * (column + 0.5) / columns
            v = v_range[0] + v_span * (row + 0.5) / rows
            lit = svg.dusk and svg.lights.random() < 0.45
            svg.polygon(face_part(face, u - du, u + du, v - dv, v + dv), LIT if lit else color, light=lit)


def box_corners(near, left_width, right_width, height, raise_back=0):
    x, y = near
    left_bottom, right_bottom = (x - left_width, y - left_width * SLOPE), (x + right_width, y - right_width * SLOPE)
    left_top, near_top = (left_bottom[0], left_bottom[1] - height - raise_back), (x, y - height)
    right_top = (right_bottom[0], right_bottom[1] - height)
    far_top = (x - left_width + right_width, y - height - (left_width + right_width) * SLOPE - raise_back)
    return [left_bottom, near, near_top, left_top], [near, right_bottom, right_top, near_top], (left_top, near_top, right_top, far_top)


def prism(svg, near, left_width, right_width, height, top, left, right, shaded=True):
    left_face, right_face, roof = box_corners(near, left_width, right_width, height)
    if shaded:
        left = svg.gradient([(0, mix(left, '#ffffff', 0.12)), (1, mix(left, '#3a3550', 0.18))])
        right = svg.gradient([(0, right), (1, mix(right, '#2a2540', 0.28))])
    svg.polygon(left_face, left)
    svg.polygon(right_face, right)
    svg.polygon([roof[1], roof[2], roof[3], roof[0]], top)
    return left_face, right_face, roof


def roof_box(svg, top, u, v, size, height, color='#c9cdd4'):
    prism(svg, roof_point(top, u, v), size, size, height, mix(color, '#ffffff', 0.3), color, mix(color, '#000000', 0.3),
          shaded=False)


def antenna(svg, base, height):
    tip = (base[0], base[1] - height)
    svg.line(base, tip, '#d8dce2', 3)
    svg.ellipse(*tip, 4, 4, '#ff3a30', light=True)


def curtain_wall(svg, face, floors, columns, mullion):
    """The mullions and floor lines of a glass face, and lit panes at dusk."""
    bottom_left, bottom_right, _, top_left = face

    for column in range(1, columns):
        u = column / columns
        svg.line(face_point(face, u, 0), face_point(face, u, 1), mullion, 1.2, extra=' opacity="0.55"')

    for floor in range(1, floors):
        start = (bottom_left[0], bottom_left[1] + (top_left[1] - bottom_left[1]) * floor / floors)
        end = (bottom_right[0], start[1] + bottom_right[1] - bottom_left[1])
        svg.line(start, end, mullion, 1.4, extra=' opacity="0.6"')

    if not svg.dusk:
        return

    for floor in range(floors):
        for column in range(columns):
            if svg.lights.random() < 0.22:
                v0, v1 = (floor + 0.2) / floors, (floor + 0.8) / floors
                u0, u1 = (column + 0.15) / columns, (column + 0.85) / columns
                svg.polygon(face_part(face, u0, u1, v0, v1), LIT, light=True)


def glass_tower(svg, near, left_width, right_width, height, glass, crown):
    """A contemporary tower with a glass curtain wall and a flat, set-back or slanted crown."""
    roof_color, left_hi, left_lo, right_hi, right_lo, mullion = glass
    slant = height * 0.12 if crown == 'slant' else 0
    left_face, right_face, roof = box_corners(near, left_width, right_width, height, slant)

    svg.polygon(left_face, svg.gradient([(0, left_hi), (1, left_lo)]))
    svg.polygon(right_face, svg.gradient([(0, right_hi), (1, right_lo)]))

    # a band of sky reflected across each face
    for face, opacity in ((left_face, 0.22), (right_face, 0.12)):
        svg.polygon([face_point(face, 0.5, 1), face_point(face, 0.72, 1), face_point(face, 0.3, 0), face_point(face, 0.08, 0)],
                    '#ffffff', extra=f' opacity="{opacity}"')

    floors = int((height + slant) // 13)
    if slant:
        # the left face rises to the back: keep its floor lines level
        for floor in range(1, floors):
            z = floor * 13
            start = (left_face[0][0], left_face[0][1] - z)
            end_t = 1.0 if z <= height else max(0.0, 1 - (z - height) / slant)
            end = (lerp(left_face[0], left_face[1], end_t)[0], lerp(left_face[0], left_face[1], end_t)[1] - z)
            svg.line(start, end, mullion, 1.4, extra=' opacity="0.6"')
        for column in range(1, 6):
            svg.line(face_point(left_face, column / 6, 0), face_point(left_face, column / 6, 1), mullion, 1.2,
                     extra=' opacity="0.55"')
        curtain_wall(svg, right_face, int(height // 13), 6, mullion)
        if svg.dusk:
            for _ in range(int(height // 13) * 2):
                z = svg.lights.uniform(10, height - 10)
                u = svg.lights.uniform(0.05, 0.8)
                a = lerp(left_face[0], left_face[1], u)
                b = lerp(left_face[0], left_face[1], u + 0.12)
                svg.polygon([(a[0], a[1] - z), (b[0], b[1] - z), (b[0], b[1] - z - 7), (a[0], a[1] - z - 7)], LIT, light=True)
    else:
        curtain_wall(svg, left_face, floors, 5, mullion)
        curtain_wall(svg, right_face, floors, 6, mullion)

    svg.polygon([roof[1], roof[2], roof[3], roof[0]], roof_color)

    # the lobby at the foot of each face
    for face in (left_face, right_face):
        svg.polygon(face_part(face, 0, 1, 0, 0.025), '#2a3448')

    if crown == 'setback':
        upper_near = roof_point(roof, 0.18, 0.18)
        glass_tower(svg, upper_near, left_width * 0.64, right_width * 0.64, height * 0.14, glass, 'flat')
    elif crown == 'flat':
        roof_box(svg, roof, 0.3, 0.3, min(left_width, right_width) * 0.3, 10)
        antenna(svg, roof_point(roof, 0.7, 0.7), 30)
    else:
        svg.line(roof[1], roof[0], '#ffffff', 2, extra=' opacity="0.7"')


def ribbon_tower(svg, near, left_width, right_width, height, colors):
    left, right, roof = prism(svg, near, left_width, right_width, height, *colors)
    ribbons(svg, left, height // 20, '#7f8ea4', 0.4, 3)
    ribbons(svg, right, height // 20, '#5e6c84', 0.4, 3)
    roof_box(svg, roof, 0.25, 0.3, 10, 9)
    antenna(svg, roof_point(roof, 0.7, 0.6), 34)


def tree(svg, base, size):
    x, y = base
    svg.ellipse(x + size * 0.5, y + size * 0.1, size * 0.9, size * 0.35, '#2f5a2a', extra=' opacity="0.35"')
    svg.ellipse(x, y - size * 0.7, size, size * 0.9, TREE)
    svg.ellipse(x - size * 0.3, y - size * 0.95, size * 0.55, size * 0.45, TREE_LIGHT)


def house(svg, near, left_width, right_width, rng):
    wall, roof = rng.choice(HOUSE_WALLS), rng.choice(HOUSE_ROOFS)
    height, pitch = rng.uniform(12, 18), rng.uniform(9, 13)
    left, right, top = prism(svg, near, left_width, right_width, height, wall, wall, mix(wall, '#6a5a50', 0.35), shaded=False)
    left_top, near_top, right_top, far_top = top
    ridge_near, ridge_far = lerp(left_top, near_top, 0.5), lerp(far_top, right_top, 0.5)
    ridge_near, ridge_far = (ridge_near[0], ridge_near[1] - pitch), (ridge_far[0], ridge_far[1] - pitch)
    svg.polygon([left_top, ridge_near, ridge_far, far_top], mix(roof, '#ffffff', 0.15))
    svg.polygon([left_top, near_top, ridge_near], mix(wall, '#ffffff', 0.1))
    svg.polygon([near_top, right_top, ridge_far, ridge_near], roof)
    lit = svg.dusk and svg.lights.random() < 0.6
    svg.polygon(face_part(right, 0.35, 0.6, 0.3, 0.7), LIT if lit else '#5a6a80', light=lit)


def shop(svg, near, left_width, right_width, rng):
    top, left, right = rng.choice(SHOP_COLORS)
    height = rng.uniform(26, 58)
    left_face, right_face, roof = prism(svg, near, left_width, right_width, height, top, left, right, shaded=False)
    ribbons(svg, left_face, max(2, int(height // 14)), '#5f7088', 0.4, 3)
    ribbons(svg, right_face, max(2, int(height // 14)), '#4a5870', 0.4, 3)
    roof_box(svg, roof, rng.uniform(0.2, 0.5), rng.uniform(0.2, 0.5), 6, 5)


def office(svg, near, left_width, right_width, rng):
    top, left, right = rng.choice(SHOP_COLORS)
    height = rng.uniform(70, 120)
    left_face, right_face, roof = prism(svg, near, left_width, right_width, height, top, left, right)
    ribbons(svg, left_face, int(height // 16), '#6a7d98', 0.35, 3)
    ribbons(svg, right_face, int(height // 16), '#4d5d78', 0.35, 3)
    roof_box(svg, roof, 0.3, 0.3, 9, 8)


def car(svg, u, v, along_u, color):
    length, width = 9, 4.5
    du, dv = (length, width) if along_u else (width, length)
    svg.polygon(ground_area(u - du / 2, u + du / 2, v - dv / 2, v + dv / 2, 3), color)
    if svg.dusk:
        x, y = ground(u, v, 3)
        svg.ellipse(x, y, 2.5, 2, LIT, light=True)


def lots(block_u, block_v, count):
    inner = BLOCK - ROAD - 2 * SIDEWALK
    size = inner / count
    start_u, start_v = block_u + ROAD / 2 + SIDEWALK, block_v + ROAD / 2 + SIDEWALK
    for i in range(count):
        for j in range(count):
            yield start_u + i * size, start_v + j * size, size


def obstacles():
    """The footprints of the large buildings and the bridge approach, where nothing small stands."""
    result = [box_footprint(HERO[0], HERO[1], HERO[2]), box_footprint(*BRICK[:3]),
              round_footprint(STADIUM_PLAZA, STADIUM_RADIUS),
              (BRIDGE_U[0], BRIDGE_U[1], BRIDGE_V - DECK_WIDTH, BRIDGE_V + DECK_WIDTH)]
    result += [box_footprint(near, wl, wr) for _, near, wl, wr, *_ in GLASS_TOWERS]
    result += [box_footprint(near, wl, wr) for _, near, wl, wr, *_ in RIBBON_TOWERS]
    return result


def block_items(kind, block_u, block_v, rng):
    """(footprint, kind, painter) for each thing that stands in a block."""
    items = []

    if kind == 'park':
        for _ in range(rng.randint(6, 10)):
            u = block_u + rng.uniform(ROAD, BLOCK - ROAD)
            v = block_v + rng.uniform(ROAD, BLOCK - ROAD)
            size = rng.uniform(8, 12)
            r = size * 0.5
            items.append(((u - r, u + r, v - r, v + r), 'tree', lambda s, base=ground(u, v), size=size: tree(s, base, size)))

    elif kind == 'homes':
        for u, v, size in lots(block_u, block_v, 3):
            if rng.random() < 0.2:
                cu, cv, tree_size = u + size / 2, v + size / 2, rng.uniform(8, 11)
                r = tree_size * 0.5
                items.append(((cu - r, cu + r, cv - r, cv + r), 'tree',
                              lambda s, base=ground(cu, cv), size=tree_size: tree(s, base, size)))
                continue
            margin = size * 0.18
            width = size - 2 * margin
            u0, v1 = u + margin, v + size - margin
            seed = rng.random()
            items.append(((u0, u0 + width, v1 - width * 0.85, v1), 'house',
                          lambda s, near=ground(u0, v1), width=width, seed=seed:
                          house(s, near, width * 0.85, width, random.Random(seed))))

    else:
        count, paint = (2, shop) if kind == 'shops' else (1, office)
        for u, v, size in lots(block_u, block_v, count):
            margin = size * (0.12 if count == 2 else 0.18)
            width = size - 2 * margin
            u0, v1 = u + margin, v + size - margin
            seed = rng.random()
            items.append(((u0, u0 + width, v1 - width, v1), kind[:-1],
                          lambda s, near=ground(u0, v1), width=width, seed=seed, paint=paint:
                          paint(s, near, width, width, random.Random(seed))))

    return items


def plan():
    """The blocks, cars and small buildings of the city. Both layers call it and get the same city."""
    rng = random.Random(1993)
    water = water_area()
    blocked = obstacles()
    blocks, items, cars = [], [], []

    for i in range(-5, 9):
        for j in range(-7, 6):
            block_u, block_v = i * BLOCK, j * BLOCK
            near = ground(block_u, block_v + BLOCK)
            if near[1] < HORIZON or not -BLOCK * 2 < near[0] < SIZE + BLOCK * 2:
                continue
            lot = (block_u + ROAD / 2, block_u + BLOCK - ROAD / 2, block_v + ROAD / 2, block_v + BLOCK - ROAD / 2)
            covered = [footprint for footprint in blocked if overlaps(lot, footprint)]
            if any(overlap_area(lot, footprint) > 0.5 * BLOCK * BLOCK for footprint in covered):
                kind = 'plaza'
            else:
                kind = rng.choices(('park', 'homes', 'shops', 'offices'), (0.18, 0.42, 0.26, 0.14))[0]
            pond = kind == 'park' and rng.random() < 0.5
            blocks.append((i, j, kind, pond))

            if kind == 'plaza':
                continue

            for footprint, name, paint in block_items(kind, block_u, block_v, rng):
                u0, u1, v0, v1 = footprint
                near_point = ground(u0, v1)
                corners = [ground(u0, v0), ground(u1, v0), ground(u0, v1), ground(u1, v1)]
                if near_point[1] <= HORIZON + STANDING_DEPTH or any(contains(water, c) for c in corners):
                    continue
                if near_point[1] > SIZE + 80 or not -80 < near_point[0] < SIZE + 80:
                    continue
                if any(overlaps(grown(footprint, 6), obstacle) for obstacle in blocked):
                    continue
                if pond and name == 'tree':
                    center = (block_u + BLOCK / 2, block_v + BLOCK / 2)
                    if overlaps(footprint, (center[0] - 40, center[0] + 40, center[1] - 40, center[1] + 40)):
                        continue
                items.append((footprint, name, paint))

    for _ in range(70):
        along_u = rng.random() < 0.5
        lane = rng.randint(-6, 9) * BLOCK + rng.choice((-ROAD / 4, ROAD / 4))
        travel = rng.uniform(-8 * BLOCK, 8 * BLOCK)
        color = rng.choice(CAR_COLORS)
        u, v = (travel, lane) if along_u else (lane, travel)
        x, y = ground(u, v)
        if HORIZON + 60 < y < SIZE + 20 and -20 < x < SIZE + 20 and not contains(water, (x, y)):
            if not any(overlaps((u - 6, u + 6, v - 6, v + 6), footprint) for footprint in blocked[3:4]):
                cars.append((u, v, along_u, color))

    return blocks, items, cars


def precedes(a, b):
    """Footprint `a` is behind `b` where they cover the same columns of the screen."""
    if not (a[0] + a[2] < b[1] + b[3] and b[0] + b[2] < a[1] + a[3]):
        return False
    return a[0] >= b[1] - 0.01 or a[3] <= b[2] + 0.01


def depth_order(items):
    """Painter's order of footprints: each thing after everything behind it."""
    count = len(items)
    after = [[] for _ in range(count)]
    waiting = [0] * count
    for i in range(count):
        for j in range(count):
            if i != j and precedes(items[i][0], items[j][0]):
                after[i].append(j)
                waiting[j] += 1

    def near_y(k):
        u0, _, _, v1 = items[k][0]
        return ground(u0, v1)[1]

    done, ordered = [False] * count, []
    while len(ordered) < count:
        ready = [k for k in range(count) if not done[k] and waiting[k] == 0]
        if not ready:
            ready = [k for k in range(count) if not done[k]]
        k = min(ready, key=near_y)
        done[k] = True
        ordered.append(items[k])
        for j in after[k]:
            waiting[j] -= 1
    return ordered


def mountains(svg):
    peaks = [((-60, HORIZON), (130, 372), (330, HORIZON)), ((180, HORIZON), (390, 402), (590, HORIZON)),
             ((540, HORIZON), (760, 392), (950, HORIZON)), ((780, HORIZON), (985, 368), (1160, HORIZON))]
    for number, (left, peak, right) in enumerate(peaks, 1):
        with svg.group(f'mountain-{number}'):
            foot = (peak[0] + 40, HORIZON)
            svg.polygon([left, peak, foot], '#d9a96d')
            svg.polygon([peak, right, foot], '#a0704a')
            svg.polygon([lerp(peak, left, 0.25), lerp(peak, foot, 0.3), lerp(left, foot, 0.55)], '#c08a58')
            svg.polygon([lerp(peak, right, 0.4), lerp(peak, foot, 0.55), lerp(right, foot, 0.4)], '#8a5c3c')
            svg.polygon([left, peak, right], svg.gradient([(0, '#c9dbe8', 0.05), (1, '#d3e2ec', 0.95)]))


def boat(svg, center, length, wake=True):
    cx, cy = center
    bow = (cx + length, cy - SLOPE * length)
    stern = (cx - length, cy + SLOPE * length)
    side = (length * 0.12, length * 0.22)
    if wake:
        for spread in (-1, 1):
            end = (stern[0] - length * 1.6, stern[1] + length * (0.48 + 0.22 * spread))
            svg.line(stern, end, '#e8f7ff', 3, extra=' opacity="0.7"')
    hull = [bow, (stern[0] + side[0], stern[1] + side[1]), (stern[0] - side[0] * 0.2, stern[1] - side[1] * 0.2),
            (bow[0] - length * 0.3, bow[1] - length * 0.15)]
    svg.polygon(hull, '#ffffff')
    svg.polygon([(x, y + 3) for x, y in hull[:2]] + [hull[1], hull[0]], '#c8452f')
    prism(svg, (cx - length * 0.1, cy + 2), length * 0.25, length * 0.5, length * 0.25, '#f4f4f4', '#e2e6ea', '#aab4be',
          shaded=False)
    if svg.dusk:
        svg.ellipse(cx, cy - length * 0.15, 3, 3, LIT, light=True)


def land_layer(dusk=False):
    """Flat things and far things: sky, mountains, streets, cars, the far skyline and the bay."""
    svg = Svg(dusk)
    rng = random.Random(7)
    water = water_area()
    blocks, _, cars = plan()

    with svg.group('clouds'):
        cumulus = [(100, 330, 66), (175, 300, 80), (258, 322, 60), (40, 360, 52), (310, 345, 40),
                   (830, 360, 46), (900, 338, 64), (975, 362, 52), (560, 380, 40), (620, 368, 48)]
        for number, (cx, cy, r) in enumerate(cumulus, 1):
            with svg.group(f'cloud-{number}'):
                cloud = svg.radial([(0, '#ffffff', 0.95), (0.65, '#f4f8fc', 0.85), (1, '#dfeaf4', 0)])
                svg.ellipse(cx, cy, r * 1.3, r * 0.82, cloud)
        for number, (cx, cy, rx) in enumerate([(420, 150, 120), (860, 190, 140), (150, 200, 90)], 1):
            with svg.group(f'high-cloud-{number}'):
                cloud = svg.radial([(0, '#ffffff', 0.95), (0.65, '#f4f8fc', 0.85), (1, '#dfeaf4', 0)])
                for dx, dy, scale in [(-0.35, 4, 0.55), (0, 0, 0.8), (0.4, 6, 0.5)]:
                    svg.ellipse(cx + dx * rx, cy + dy, rx * scale, 9, cloud, extra=' opacity="0.55"')

    with svg.group('mountains'):
        mountains(svg)

    with svg.group('ground'):
        svg.polygon([(-60, HORIZON), (SIZE + 60, HORIZON), (SIZE + 60, SIZE + 60), (-60, SIZE + 60)], ASPHALT)

    lot_colors = {'park': PARK, 'homes': LAWN, 'shops': CONCRETE, 'offices': CONCRETE, 'plaza': '#e8dcc4'}
    with svg.group('blocks'):
        for i, j, kind, pond in blocks:
            block_u, block_v = i * BLOCK, j * BLOCK
            with svg.group(f'block-{kind}-{i}-{j}'.replace('--', '-m')):
                curb = ground_area(block_u + ROAD / 2, block_u + BLOCK - ROAD / 2, block_v + ROAD / 2, block_v + BLOCK - ROAD / 2)
                lot = ground_area(block_u + ROAD / 2 + SIDEWALK, block_u + BLOCK - ROAD / 2 - SIDEWALK,
                                  block_v + ROAD / 2 + SIDEWALK, block_v + BLOCK - ROAD / 2 - SIDEWALK)
                svg.polygon(clip_below(curb, HORIZON), '#c8c2b6')
                svg.polygon(clip_below(lot, HORIZON), lot_colors[kind])
                if pond:
                    svg.ellipse(*ground(block_u + BLOCK / 2, block_v + BLOCK / 2), 26, 9, '#4f9ad8')

    with svg.group('road-lines'):
        for k in range(-6, 10):
            for start, end in [(ground(k * BLOCK, -8 * BLOCK), ground(k * BLOCK, 8 * BLOCK)),
                               (ground(-8 * BLOCK, k * BLOCK), ground(8 * BLOCK, k * BLOCK))]:
                line = clip_below([start, end, end], HORIZON + 4)
                if len(line) >= 2:
                    svg.line(line[0], line[1], ROAD_LINE, 2.2, extra=' stroke-dasharray="9 9" opacity="0.85"')

    with svg.group('cars'):
        for number, (u, v, along_u, color) in enumerate(cars, 1):
            with svg.group(f'car-{number}'):
                car(svg, u, v, along_u, color)

    with svg.group('haze'):
        haze = svg.gradient([(0, '#cfe0ec', 0.95), (1, '#cfe0ec', 0)])
        svg.polygon([(-60, HORIZON), (SIZE + 60, HORIZON), (SIZE + 60, HORIZON + HAZE_DEPTH), (-60, HORIZON + HAZE_DEPTH)], haze)

    with svg.group('far-skyline'):
        for k in range(18):
            x, height, width = -10 + k * 62 + rng.uniform(-12, 12), rng.uniform(40, 110), rng.uniform(24, 44)
            with svg.group(f'far-building-{k + 1}'):
                left, _, _ = prism(svg, (x, HORIZON + 30 + rng.uniform(0, 12)), width * 0.6, width * 0.5, height,
                                   '#dbe3ea', '#bccbd8', '#98acc0')
                ribbons(svg, left, int(height // 12), '#a8b8ca', 0.3, 2)

    with svg.group('bay'):
        with svg.group('beach'):
            svg.polygon([(x - 12, y - 8) for x, y in water], '#ece0bd')
        with svg.group('water'):
            svg.polygon(water, svg.gradient([(0, '#9ad3ee'), (0.5, '#5fa6da'), (1, '#3a7fc4')]))
        with svg.group('ripples'):
            for k in range(14):
                x, y = 760 + k * 22 + rng.uniform(-20, 20), 720 + k * 22 + rng.uniform(-10, 10)
                if contains(water, (x, y)) and contains(water, (x + 40, y)):
                    svg.path(f'M{x:.1f},{y:.1f} q20,-6 40,0', stroke='#e2f4fc', width=3.5, extra=' opacity="0.6"')
        for number, (center, length, wake) in enumerate([((905, 790), 22, True), ((990, 900), 14, True),
                                                         ((800, 1010), 12, False)], 1):
            with svg.group(f'boat-{number}'):
                boat(svg, center, length, wake)

    return svg.text()


def sandstone_tower(svg):
    left, right, top = prism(svg, HERO[0], HERO[1], HERO[2], HERO[3], STONE_TOP, STONE_LEFT, STONE_RIGHT)
    glass_left = svg.gradient([(0, '#a8daf7'), (1, '#5a98d6')])
    glass_right = svg.gradient([(0, '#6496d0'), (1, '#2c5a98')])
    for face, glass, window in [(left, glass_left, '#9b6a40'), (right, glass_right, '#714728')]:
        for u_range in [(0.07, 0.40), (0.60, 0.93)]:
            punched(svg, face, 3, 9, window, u_range, (0.04, 0.54))
            punched(svg, face, 3, 5, window, u_range, (0.70, 0.97))
        svg.polygon(face_part(face, 0.43, 0.57, 0, 1), glass)
        svg.polygon(face_part(face, 0, 1, 0.58, 0.66), glass)
        svg.polygon(face_part(face, 0.40, 0.60, 0, 0.05), '#3a4a66')

    left_top, near_top, right_top, far_top = top
    middle_near, middle_far = lerp(left_top, near_top, 0.5), lerp(far_top, right_top, 0.5)
    for west, south, east, north in [(left_top, middle_near, middle_far, far_top), (middle_near, near_top, right_top, middle_far)]:
        apex = ((west[0] + east[0]) / 2, (north[1] + south[1]) / 2 - 92)
        svg.polygon([north, west, apex], '#f8deb4')
        svg.polygon([north, east, apex], '#e2ae78')
        svg.polygon([west, south, apex], '#f6cd94')
        svg.polygon([south, east, apex], '#c08a58')


def brick_block(svg):
    left, right, roof = prism(svg, BRICK[0], BRICK[1], BRICK[2], BRICK[3], '#e08868', '#c95c3e', '#8e3926')
    ribbons(svg, left, 6, '#5a2418', 0.35, 4)
    ribbons(svg, right, 6, '#4a1c12', 0.35, 4)
    pad = roof_point(roof, 0.55, 0.5)
    svg.ellipse(*pad, 22, 8, '#5a5e66')
    svg.ellipse(*pad, 15, 5, 'none', extra=f' stroke="{svg.color("#f4f4f4")}" stroke-width="2"')
    roof_box(svg, roof, 0.12, 0.15, 9, 7)


def stadium(svg):
    x, y = STADIUM_CENTER
    svg.ellipse(x, y + 8, 66, 25, '#8f2c22')
    svg.ellipse(x, y, 66, 25, '#d24a36')
    svg.ellipse(x, y, 54, 19, '#efe6d4')
    svg.ellipse(x, y + 1, 44, 15, '#b8b0a4')
    svg.ellipse(x, y + 2, 34, 11, '#6fae4c')
    svg.polygon([(x - 18, y + 2), (x, y - 4), (x + 18, y + 2), (x, y + 8)], '#8ccc66')
    for k in range(4):
        pole = (x - 56 + k * 37, y - 6 + (k % 3 == 0) * 10)
        svg.line(pole, (pole[0], pole[1] - 24), '#d8dce2', 2.5)
        svg.ellipse(pole[0], pole[1] - 25, 5, 3, '#ffffff' if not svg.dusk else LIT, light=svg.dusk)


def landmarks():
    """(footprint, name, painter) for the large buildings."""
    result = [(box_footprint(HERO[0], HERO[1], HERO[2]), 'tower-sandstone', sandstone_tower),
              (box_footprint(*BRICK[:3]), 'office-brick', brick_block),
              (round_footprint(STADIUM_CENTER, STADIUM_RADIUS), 'stadium', stadium)]
    for name, near, wl, wr, height, glass, crown in GLASS_TOWERS:
        result.append((box_footprint(near, wl, wr), name,
                       lambda s, a=(near, wl, wr, height, glass, crown): glass_tower(s, *a)))
    for name, near, wl, wr, height, colors in RIBBON_TOWERS:
        result.append((box_footprint(near, wl, wr), name,
                       lambda s, a=(near, wl, wr, height, colors): ribbon_tower(s, *a)))
    return result


def monorail(svg):
    """The monorail: piers down to the ground, the guideway and the train."""
    pier = svg.gradient([(0, '#e8e4dc'), (1, '#a49e94')], x2=1, y2=0)
    for x in RAIL_PIERS:
        t = min((abs(bezier(*RAIL_TRACK, s / 100)[0] - x), s / 100) for s in range(101))[1]
        _, y = bezier(*RAIL_TRACK, t)
        svg.polygon([(x - 9, y), (x + 9, y), (x + 7, y + RAIL_HEIGHT), (x - 7, y + RAIL_HEIGHT)], pier)
        svg.ellipse(x, y + RAIL_HEIGHT, 10, 4, '#8c8780')

    track = curve_path(RAIL_TRACK)
    svg.path(track, stroke='#8c8780', width=30, extra=' transform="translate(0,6)"')
    svg.path(track, stroke='#f2eee6', width=24)
    train = curve_path(RAIL_TRAIN)
    svg.path(train, stroke='#6b7380', width=46, extra=' stroke-linecap="round" transform="translate(0,4)"')
    svg.path(train, stroke=svg.gradient([(0, '#ffffff'), (0.6, '#d7dce3'), (1, '#9aa3ae')]), width=40,
             extra=' stroke-linecap="round"')
    svg.path(train, stroke=LIT if svg.dusk else '#3a5f9a', width=10, light=svg.dusk,
             extra=' stroke-dasharray="26 8" transform="translate(0,-4)"')
    svg.path(train, stroke='#e03a2e', width=3, extra=' transform="translate(0,9)"')


def in_front_of_rail(footprint):
    """The near corner of a footprint lies below the guideway, so it stands in front of it."""
    x, y = ground(footprint[0], footprint[3])
    samples = [bezier(*RAIL_TRACK, s / 60) for s in range(61)]
    if not samples[0][0] <= x <= samples[-1][0]:
        return False
    rail_y = min(samples, key=lambda p: abs(p[0] - x))[1]
    return y > rail_y + RAIL_HEIGHT


def cable_height(u):
    """The height of a main cable of the bridge above the water at `u`."""
    start, end = BRIDGE_U
    first, second = BRIDGE_TOWERS_U
    if u <= first:
        t = (u - start) / (first - start)
        return DECK_HEIGHT + (TOWER_HEIGHT - DECK_HEIGHT) * t ** 1.8
    if u >= second:
        t = (end - u) / (end - second)
        return DECK_HEIGHT + (TOWER_HEIGHT - DECK_HEIGHT) * t ** 1.8
    t = (u - first) / (second - first) * 2 - 1
    return CABLE_LOW + (TOWER_HEIGHT - CABLE_LOW) * t * t


def bridge_side(svg, v):
    """One main cable with its hangers down to the deck edge."""
    start, end = BRIDGE_U
    steps = [start + (end - start) * k / 80 for k in range(81)]
    svg.polyline([ground(u, v, cable_height(u)) for u in steps], BRIDGE_RED, 4)
    for k in range(1, 40):
        u = start + (end - start) * k / 40
        if cable_height(u) > DECK_HEIGHT + 3:
            svg.line(ground(u, v, cable_height(u)), ground(u, v, DECK_HEIGHT), BRIDGE_RED, 1.3, extra=' opacity="0.9"')


def bridge_legs(svg, v):
    for u in BRIDGE_TOWERS_U:
        prism(svg, ground(u - 4, v + 4), 8, 8, TOWER_HEIGHT + 6, BRIDGE_RED, BRIDGE_RED, BRIDGE_RED_DARK, shaded=False)


def bridge(svg):
    """The suspension bridge along the grid: back cable and legs, deck, beams, front legs and cable."""
    back, front = BRIDGE_V - DECK_WIDTH / 2 - 4, BRIDGE_V + DECK_WIDTH / 2 + 4
    start, end = BRIDGE_U
    with svg.group('bridge-back-cable'):
        bridge_side(svg, back)
    with svg.group('bridge-back-legs'):
        bridge_legs(svg, back)
    with svg.group('bridge-deck'):
        side = [ground(start, front - 4, DECK_HEIGHT), ground(end, front - 4, DECK_HEIGHT),
                ground(end, front - 4, DECK_HEIGHT - DECK_DEPTH), ground(start, front - 4, DECK_HEIGHT - DECK_DEPTH)]
        svg.polygon(ground_area(start, end, back + 4, front - 4, DECK_HEIGHT), '#7a7e88')
        svg.polygon(side, BRIDGE_RED_DARK)
        svg.line(ground(start, BRIDGE_V, DECK_HEIGHT), ground(end, BRIDGE_V, DECK_HEIGHT), ROAD_LINE, 1.5,
                 extra=' stroke-dasharray="8 8"')
        for k, (u, color) in enumerate([(120, '#e03a2e'), (300, '#f2c430'), (420, '#ffffff')]):
            lane = BRIDGE_V + (4 if k % 2 else -4)
            svg.polygon(ground_area(u - 5, u + 5, lane - 2.5, lane + 2.5, DECK_HEIGHT + 2), color)
        if svg.dusk:
            for k in range(1, 24):
                x, y = ground(start + (end - start) * k / 24, front - 4, DECK_HEIGHT)
                svg.ellipse(x, y - 2, 3, 3, LIT, light=True)
    with svg.group('bridge-beams'):
        for u in BRIDGE_TOWERS_U:
            for height in (TOWER_HEIGHT - 4, TOWER_HEIGHT * 0.62, DECK_HEIGHT - 2):
                svg.polygon([ground(u, back, height), ground(u, front, height), ground(u, front, height - 8),
                             ground(u, back, height - 8)], BRIDGE_RED)
    with svg.group('bridge-front-legs'):
        bridge_legs(svg, front)
    with svg.group('bridge-front-cable'):
        bridge_side(svg, front)


def copies(items):
    """(footprint, name, painter) for each copy of a small building: the painter
    of the original inside a group that moves it."""
    result = []
    for name, near, (dx, dy) in COPIES:
        footprint, _, paint = min(items, key=lambda item: math.dist(ground(item[0][0], item[0][3]), near))
        du, dv = (dx - dy / SLOPE) / 2, (dx + dy / SLOPE) / 2
        moved = (footprint[0] + du, footprint[1] + du, footprint[2] + dv, footprint[3] + dv)

        def paint_copy(svg, paint=paint, dx=dx, dy=dy):
            with svg.group(f'{name}-moved', f'translate({dx},{dy})'):
                paint(svg)

        result.append((moved, name, paint_copy))
    return result


def helicopter(svg):
    """The red helicopter of SimCity 2000 with a black outline, a blue blur of
    a main rotor and a grey tail rotor, nose to the left, around (0, 0)."""
    outline = f' stroke="{svg.color("#141414")}" stroke-width="2.5" stroke-linejoin="round"'

    # the tail boom, its fin and the tail rotor
    svg.polygon([(10, -9), (72, -27), (74, -21), (12, 1)], '#ff2a1a', extra=outline)
    svg.polygon([(64, -25), (80, -46), (86, -45), (76, -22)], '#c40e0e', extra=outline)
    svg.ellipse(78, -26, 13, 13, svg.radial([(0, '#e8e8e8', 0.5), (0.8, '#bbbbbb', 0.45), (1, '#888888', 0.2)]),
                extra=f' stroke="{svg.color("#9a9a9a")}" stroke-width="1.5"')

    # the skids under the body
    for x0, y0 in ((-30, 22), (-22, 27)):
        svg.line((x0, y0), (x0 + 50, y0 - 6), '#3b3b3b', 3.5, extra=' stroke-linecap="round"')
        svg.line((x0 + 12, y0 - 2), (x0 + 14, y0 - 14), '#3b3b3b', 2.5)
        svg.line((x0 + 36, y0 - 5), (x0 + 36, y0 - 16), '#3b3b3b', 2.5)

    # the body: lit red above, deep red below, and a white stripe
    body = 'M-38,6 C-38,-12 -22,-20 0,-20 C16,-20 22,-10 22,0 C22,10 12,16 -6,16 C-26,16 -38,14 -38,6 Z'
    svg.path(body, svg.gradient([(0, '#ff5a40'), (0.55, '#ff1e10'), (1, '#930000')]), extra=outline)
    svg.path('M-30,6 C-14,8 4,6 21,1', stroke='#ffffff', width=3, extra=' opacity="0.85"')

    # the cockpit glass with a glint
    svg.path('M-37,4 C-37,-10 -26,-17 -12,-18 L-10,2 Z', svg.gradient([(0, '#c9ecff'), (1, '#5c8fe0')]),
             extra=f' stroke="{svg.color("#141414")}" stroke-width="2"')
    svg.path('M-31,-6 C-29,-11 -24,-14 -18,-15', stroke='#ffffff', width=2.5, extra=' opacity="0.9" stroke-linecap="round"')

    # the mast, the blue blur of the main rotor, its blade streaks and the hub
    svg.line((-6, -20), (-6, -30), '#3b3b3b', 4)
    svg.ellipse(-6, -32, 70, 15, svg.radial([(0, '#c4d2ff', 0.9), (0.6, '#7d95ff', 0.7), (1, '#4945ff', 0.45)]),
                extra=f' stroke="{svg.color("#2720ff")}" stroke-width="1.2" stroke-opacity="0.6"')
    for angle in (-12, 10, 40, 75):
        a = math.radians(angle)
        svg.line((-6 - 66 * math.cos(a), -32 - 14 * math.sin(a)), (-6 + 66 * math.cos(a), -32 + 14 * math.sin(a)),
                 '#3a44ff', 1.5, extra=' opacity="0.45"')
    svg.ellipse(-6, -32, 6, 3, '#141414')

    # the beacon under the body and the light on the tail
    svg.ellipse(-4, 17, 3, 2, '#ff0000', light=True)
    svg.ellipse(84, -46, 2.5, 2.5, '#ffffff' if not svg.dusk else LIT, light=True)
    if svg.dusk:
        svg.polygon([(-36, 8), (-150, 140), (-60, 160)], LIT, light=True, extra=' opacity="0.18"')


def city_layer(dusk=False):
    """Everything that stands, from the back to the front, then the bridge."""
    svg = Svg(dusk)
    _, items, _ = plan()
    named = landmarks() + copies(items)
    ordered = depth_order(items + named)
    unique = {name for _, name, _ in named}
    counts = {}

    def draw(group):
        for footprint, name, paint in group:
            counts[name] = counts.get(name, 0) + 1
            label = name if name in unique else f'{name}-{counts[name]}'
            with svg.group(label):
                paint(svg)

    draw([item for item in ordered if not in_front_of_rail(item[0])])
    with svg.group('monorail'):
        monorail(svg)
    draw([item for item in ordered if in_front_of_rail(item[0])])
    with svg.group('bridge'):
        bridge(svg)
    (x, y), tilt, scale = HELICOPTER
    with svg.group('helicopter', f'translate({x},{y}) rotate({tilt}) scale({scale})'):
        helicopter(svg)
    return svg.text()


def srgb(value):
    r, g, b = hex_rgb(value)
    return f'srgb:{r / 255:.5f},{g / 255:.5f},{b / 255:.5f},1.00000'


def main(folder):
    folder = Path(folder)
    (folder / 'Assets').mkdir(parents=True, exist_ok=True)
    for old in (folder / 'Assets').glob('*'):
        old.unlink()
    for name, paint in (('city', city_layer), ('land', land_layer)):
        (folder / f'Assets/{name}.svg').write_text(paint())
        (folder / f'Assets/{name}-dusk.svg').write_text(paint(dusk=True))

    # the city layer takes the Liquid Glass highlight of Icon Composer; the land stays flat
    def group(name, shadow, glass):
        images = [{'value': f'{name}.svg'}, {'appearance': 'dark', 'value': f'{name}-dusk.svg'}]
        return {'layers': [{'name': name, 'glass': glass, 'image-name-specializations': images}],
                'shadow': {'kind': shadow, 'opacity': 0.5}, 'translucency': {'enabled': False, 'value': 0.5},
                'specular': False}

    document = {
        'fill-specializations': [{'value': {'linear-gradient': [srgb(c) for c in SKY_DAY]}},
                                 {'appearance': 'dark', 'value': {'linear-gradient': [srgb(c) for c in SKY_DUSK]}}],
        'groups': [group('city', 'neutral', True), group('land', 'none', False)],
        'supported-platforms': {'squares': ['macOS']},
    }
    (folder / 'icon.json').write_text(json.dumps(document, indent=2) + '\n')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / 'game/assets/icons/OpenSC2K.icon')
