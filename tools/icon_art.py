"""Paint the layers of the OpenSC2K app icon as SVG, after the SimCity 2000 box art.

The scene is an aerial view of a city on a bay: mountains on the horizon, a
street grid of blocks with houses, shops, offices and parks, the towers of the
box art, a red suspension bridge, a stadium, a monorail and boats on the water.

The view is a parallel projection. The ground axes `u` and `v` run along the
right faces and the left faces of the buildings, so the streets line up with
the buildings. Each layer has a dusk version, with lit windows and lights.
"""
import colorsys
import random

# the canvas of an Icon Composer document
SIZE = 1024

# the aerial view: the fall of a horizontal edge across a building face, and the horizon
SLOPE = 0.30
HORIZON = 500
# the scene is drawn larger than the canvas from this point at the bottom, so the city fills the sky
ZOOM, ZOOM_ORIGIN = 1.07, (560, 1024)

# the street grid: the screen point of ground point (0, 0), the pitch of the
# blocks, and the widths of a road and a sidewalk, in ground units
GRID_ORIGIN = (330, 888.6)
BLOCK, ROAD, SIDEWALK = 160, 14, 5
# the depth of the band in front of the horizon that haze fades, and the
# depth in front of the horizon where houses and trees start
HAZE_DEPTH, STANDING_DEPTH = 170, 110

# the sky fill from the top to the horizon, by day and at dusk
SKY_DAY = ('#0a4fd8', '#72ccff')
SKY_DUSK = ('#0c1250', '#ff6a4a')
# each color of the art has its saturation multiplied by this
SATURATION = 1.6
# at dusk each color moves toward this blue and toward black; lights keep their color
DUSK, DUSK_BLUE, DUSK_DARK = '#1b2350', 0.55, 0.25
LIT = '#ffd77a'
# the seed of the lights, apart from the layout, so day and dusk show the same city
LIGHTS_SEED = 1995

# the colors that the box art is known for
STONE_TOP, STONE_LEFT, STONE_RIGHT = '#f6d6a6', '#f2c38a', '#bd8452'
TEAL_LIGHT, TEAL_DARK = '#4cc4d2', '#155d7c'
VIOLET_LIGHT, VIOLET_DARK = '#a2a8f0', '#3c3c8e'
BRIDGE_RED, BRIDGE_RED_DARK = '#dc3a2a', '#981f16'

# the ground
ASPHALT, ROAD_LINE, CONCRETE = '#6a6d78', '#f4e7a4', '#ddd4c2'
LAWN, PARK, TREE, TREE_LIGHT = '#94c95a', '#78bd48', '#3f8a32', '#6cb846'
HOUSE_WALLS = ('#f4ecd8', '#f2e2b0', '#e8eef2', '#f0d2b8')
HOUSE_ROOFS = ('#c8452f', '#9a5a36', '#4f6fb0', '#3f8a6a', '#b84a5a')
SHOP_COLORS = (('#f0e2c8', '#e2c49a', '#b08e64'), ('#e6eef6', '#b8cce0', '#7f98b4'),
               ('#f6d8c8', '#e2a080', '#b06a4a'), ('#e8f0dc', '#bcd29a', '#86a066'))
CAR_COLORS = ('#e03a2e', '#f2c430', '#ffffff', '#2e7ad8', '#30a060')

# the bay: the shore as two cubic curves from the right edge to the bottom edge
SHORE = (((1034, 640), (920, 660), (840, 700), (820, 780)),
         ((820, 780), (800, 860), (700, 930), (640, 1034)))
SHORE_STEPS = 24

# the screen points where the large buildings of the city layer stand; their
# blocks in the land layer are plazas, so no small building shows through
LANDMARKS = ((478, 860), (272, 770), (612, 712), (686, 700), (756, 690), (750, 750),
             (120, 645), (835, 555), (548, 595), (420, 585), (900, 600))

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


def ground(u, v):
    """The screen point of a ground point."""
    return (GRID_ORIGIN[0] + u + v, GRID_ORIGIN[1] + SLOPE * (v - u))


def ground_area(u0, u1, v0, v1):
    """A rectangle of the ground, from its near corner around."""
    return [ground(u0, v1), ground(u1, v1), ground(u1, v0), ground(u0, v0)]


def clip_below(polygon, y_limit):
    """The part of a polygon at or below a screen line."""
    result = []

    for k, current in enumerate(polygon):
        previous = polygon[k - 1]
        inside, was_inside = current[1] >= y_limit, previous[1] >= y_limit

        if inside != was_inside:
            t = (y_limit - previous[1]) / (current[1] - previous[1])
            result.append(lerp(previous, current, t))

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


def water_area():
    """The bay as a polygon: the shore, then the corner of the canvas."""
    shore = [bezier(*curve, step / SHORE_STEPS) for curve in SHORE for step in range(SHORE_STEPS + 1)]
    return shore + [(SIZE + 10, SIZE + 10)]


class Svg:
    """One layer of the icon. At dusk each color is darker and bluer, except
    the colors that are marked as lights."""

    def __init__(self, dusk=False):
        self.defs, self.body, self.dusk, self.ids = [], [], dusk, 0
        self.lights = random.Random(LIGHTS_SEED)

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
        if len(values) >= 3:
            self.body.append(f'<polygon points="{points(values)}" fill="{self.paint(fill, light)}"{extra}/>')

    def path(self, d, fill='none', stroke=None, width=None, light=False, extra=''):
        line = f' stroke="{self.paint(stroke, light)}" stroke-width="{width}"' if stroke else ''
        self.body.append(f'<path d="{d}" fill="{self.paint(fill, light)}"{line}{extra}/>')

    def line(self, start, end, stroke, width, light=False, extra=''):
        self.path(f'M{start[0]:.1f},{start[1]:.1f} L{end[0]:.1f},{end[1]:.1f}', stroke=stroke, width=width,
                  light=light, extra=extra)

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


def roof_point(top, u, v):
    """A point on a flat roof: `u` toward its right corner, `v` toward its left corner, from its near corner."""
    left_top, near_top, right_top, _ = top
    return (near_top[0] + u * (right_top[0] - near_top[0]) + v * (left_top[0] - near_top[0]),
            near_top[1] + u * (right_top[1] - near_top[1]) + v * (left_top[1] - near_top[1]))


def ribbons(svg, face, rows, color, size, panes=6):
    """Bands of windows across a face. At dusk about half of their panes are lit."""
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
    """Small square windows in a face."""
    u_span, v_span = u_range[1] - u_range[0], v_range[1] - v_range[0]
    du, dv = u_span / columns * 0.22, v_span / rows * 0.28

    for row in range(rows):
        for column in range(columns):
            u = u_range[0] + u_span * (column + 0.5) / columns
            v = v_range[0] + v_span * (row + 0.5) / rows
            lit = svg.dusk and svg.lights.random() < 0.45
            svg.polygon(face_part(face, u - du, u + du, v - dv, v + dv), LIT if lit else color, light=lit)


def prism(svg, near, left_width, right_width, height, top, left, right, shaded=True):
    """A building seen from above, lit from the left: its near bottom corner,
    the widths of its left and right faces, and its height. Returns the faces."""
    x, y = near
    left_bottom, right_bottom = (x - left_width, y - left_width * SLOPE), (x + right_width, y - right_width * SLOPE)
    left_top, near_top = (left_bottom[0], left_bottom[1] - height), (x, y - height)
    right_top = (right_bottom[0], right_bottom[1] - height)
    far_top = (x - left_width + right_width, y - height - (left_width + right_width) * SLOPE)
    left_face, right_face = [left_bottom, near, near_top, left_top], [near, right_bottom, right_top, near_top]

    if shaded:
        left = svg.gradient([(0, mix(left, '#ffffff', 0.12)), (1, mix(left, '#3a3550', 0.18))])
        right = svg.gradient([(0, right), (1, mix(right, '#2a2540', 0.28))])

    svg.polygon(left_face, left)
    svg.polygon(right_face, right)
    svg.polygon([near_top, right_top, far_top, left_top], top)
    return left_face, right_face, (left_top, near_top, right_top, far_top)


def roof_box(svg, top, u, v, size, height, color='#c9cdd4'):
    """A small box on a flat roof, such as an air conditioner or a stair house."""
    prism(svg, roof_point(top, u, v), size, size, height, mix(color, '#ffffff', 0.3), color, mix(color, '#000000', 0.3),
          shaded=False)


def antenna(svg, base, height):
    tip = (base[0], base[1] - height)
    svg.line(base, tip, '#d8dce2', 3)
    svg.ellipse(*tip, 4, 4, '#ff3a30', light=True)


def capsule(svg, cx, base, radius, top, light, dark, floors):
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

        if svg.dusk and svg.lights.random() < 0.5:
            x = cx + svg.lights.uniform(-0.7, 0.3) * radius
            svg.path(f'M{x:.1f},{y + 6:.1f} l{radius * 0.35:.1f},0', stroke=LIT, width=5, light=True)


def tree(svg, base, size):
    """A round tree with its shadow on the ground."""
    x, y = base
    svg.ellipse(x + size * 0.5, y + size * 0.1, size * 0.9, size * 0.35, '#2f5a2a', extra=' opacity="0.35"')
    svg.ellipse(x, y - size * 0.7, size, size * 0.9, TREE)
    svg.ellipse(x - size * 0.3, y - size * 0.95, size * 0.55, size * 0.45, TREE_LIGHT)


def house(svg, near, left_width, right_width, rng):
    """A small house with a pitched roof, its ridge along its right face."""
    wall, roof = rng.choice(HOUSE_WALLS), rng.choice(HOUSE_ROOFS)
    height, pitch = rng.uniform(12, 18), rng.uniform(9, 13)
    left, right, top = prism(svg, near, left_width, right_width, height, wall, wall, mix(wall, '#6a5a50', 0.35),
                             shaded=False)
    left_top, near_top, right_top, far_top = top
    ridge_near, ridge_far = lerp(left_top, near_top, 0.5), lerp(far_top, right_top, 0.5)
    ridge_near, ridge_far = (ridge_near[0], ridge_near[1] - pitch), (ridge_far[0], ridge_far[1] - pitch)

    svg.polygon([left_top, ridge_near, ridge_far, far_top], mix(roof, '#ffffff', 0.15))
    svg.polygon([left_top, near_top, ridge_near], mix(wall, '#ffffff', 0.1))
    svg.polygon([near_top, right_top, ridge_far, ridge_near], roof)

    lit = svg.dusk and svg.lights.random() < 0.6
    svg.polygon(face_part(right, 0.35, 0.6, 0.3, 0.7), LIT if lit else '#5a6a80', light=lit)


def shop(svg, near, left_width, right_width, rng):
    """A low building with a flat roof, bands of windows and boxes on its roof."""
    top, left, right = rng.choice(SHOP_COLORS)
    height = rng.uniform(26, 58)
    left_face, right_face, roof = prism(svg, near, left_width, right_width, height, top, left, right, shaded=False)
    ribbons(svg, left_face, max(2, int(height // 14)), '#5f7088', 0.4, 3)
    ribbons(svg, right_face, max(2, int(height // 14)), '#4a5870', 0.4, 3)
    roof_box(svg, roof, rng.uniform(0.2, 0.5), rng.uniform(0.2, 0.5), 6, 5)


def office(svg, near, left_width, right_width, rng):
    """A taller building with bands of windows and a stair house on its roof."""
    top, left, right = rng.choice(SHOP_COLORS)
    height = rng.uniform(70, 120)
    left_face, right_face, roof = prism(svg, near, left_width, right_width, height, top, left, right)
    ribbons(svg, left_face, int(height // 16), '#6a7d98', 0.35, 3)
    ribbons(svg, right_face, int(height // 16), '#4d5d78', 0.35, 3)
    roof_box(svg, roof, 0.3, 0.3, 9, 8)


def car(svg, u, v, along_u, rng):
    """A car on a road, seen from above, pointed along its road."""
    length, width = 9, 4.5
    du, dv = (length, width) if along_u else (width, length)
    body = ground_area(u - du / 2, u + du / 2, v - dv / 2, v + dv / 2)
    color = rng.choice(CAR_COLORS)
    svg.polygon([(x, y - 3) for x, y in body], color)

    if svg.dusk:
        x, y = ground(u, v)
        svg.ellipse(x, y - 3, 2.5, 2, LIT, light=True)


def lots(block_u, block_v, count):
    """The near corners and sizes of `count` by `count` lots in a block, in ground units."""
    inner = BLOCK - ROAD - 2 * SIDEWALK
    size = inner / count
    start_u, start_v = block_u + ROAD / 2 + SIDEWALK, block_v + ROAD / 2 + SIDEWALK

    for i in range(count):
        for j in range(count):
            yield start_u + i * size, start_v + j * size, size


def block_items(kind, block_u, block_v, rng):
    """The things that stand in a block, as (near point, painter) pairs."""
    items = []

    def standing(u, v, paint):
        items.append((ground(u, v), paint))

    if kind == 'park':
        for _ in range(rng.randint(6, 10)):
            u = block_u + rng.uniform(ROAD, BLOCK - ROAD)
            v = block_v + rng.uniform(ROAD, BLOCK - ROAD)
            size = rng.uniform(8, 12)
            standing(u, v, lambda s, base=ground(u, v), size=size: tree(s, base, size))

    elif kind == 'homes':
        for u, v, size in lots(block_u, block_v, 3):
            if rng.random() < 0.2:
                standing(u + size / 2, v + size / 2,
                         lambda s, base=ground(u + size / 2, v + size / 2), size=rng.uniform(8, 11): tree(s, base, size))
                continue

            margin = size * 0.18
            near = ground(u + margin, v + size - margin)
            standing(u + margin, v + size - margin,
                     lambda s, near=near, width=size - 2 * margin: house(s, near, width * 0.85, width, rng))

    else:
        count, paint = (2, shop) if kind == 'shops' else (1, office)
        for u, v, size in lots(block_u, block_v, count):
            margin = size * (0.12 if count == 2 else 0.18)
            near = ground(u + margin, v + size - margin)
            standing(u + margin, v + size - margin,
                     lambda s, near=near, width=size - 2 * margin, paint=paint: paint(s, near, width, width, rng))

    return items


def block_kind(area, rng):
    if any(contains(area, landmark) for landmark in LANDMARKS):
        return 'plaza'

    return rng.choices(('park', 'homes', 'shops', 'offices'), (0.18, 0.42, 0.26, 0.14))[0]


def street_grid(svg, rng, water):
    """The ground: asphalt, then each block with its sidewalk and its lot, the
    center lines of the roads, cars, and then everything that stands in the blocks."""
    svg.polygon([(-60, HORIZON), (SIZE + 60, HORIZON), (SIZE + 60, SIZE + 60), (-60, SIZE + 60)], ASPHALT)
    lot_colors = {'park': PARK, 'homes': LAWN, 'shops': CONCRETE, 'offices': CONCRETE, 'plaza': '#e8dcc4'}
    items = []

    for i in range(-5, 9):
        for j in range(-7, 6):
            block_u, block_v = i * BLOCK, j * BLOCK
            near = ground(block_u, block_v + BLOCK)
            if near[1] < HORIZON or not -BLOCK * 2 < near[0] < SIZE + BLOCK * 2:
                continue

            curb = ground_area(block_u + ROAD / 2, block_u + BLOCK - ROAD / 2, block_v + ROAD / 2, block_v + BLOCK - ROAD / 2)
            lot = ground_area(block_u + ROAD / 2 + SIDEWALK, block_u + BLOCK - ROAD / 2 - SIDEWALK,
                              block_v + ROAD / 2 + SIDEWALK, block_v + BLOCK - ROAD / 2 - SIDEWALK)
            kind = block_kind(lot, rng)
            svg.polygon(clip_below(curb, HORIZON), '#c8c2b6')
            svg.polygon(clip_below(lot, HORIZON), lot_colors[kind])

            if kind == 'park' and rng.random() < 0.5:
                center = ground(block_u + BLOCK / 2, block_v + BLOCK / 2)
                svg.ellipse(*center, 26, 9, '#4f9ad8')

            if kind != 'plaza':
                items += [item for item in block_items(kind, block_u, block_v, rng)
                          if item[0][1] > HORIZON + STANDING_DEPTH and not contains(water, item[0])]

    # the dashed center line of each road, from the horizon down
    for k in range(-6, 10):
        for start, end in [(ground(k * BLOCK, -8 * BLOCK), ground(k * BLOCK, 8 * BLOCK)),
                           (ground(-8 * BLOCK, k * BLOCK), ground(8 * BLOCK, k * BLOCK))]:
            line = clip_below([start, end, end], HORIZON + 4)
            if len(line) >= 2:
                svg.line(line[0], line[1], ROAD_LINE, 2.2, extra=' stroke-dasharray="9 9" opacity="0.85"')

    for _ in range(70):
        along_u = rng.random() < 0.5
        lane = rng.randint(-6, 9) * BLOCK + rng.choice((-ROAD / 4, ROAD / 4))
        travel = rng.uniform(-8 * BLOCK, 8 * BLOCK)
        u, v = (travel, lane) if along_u else (lane, travel)
        x, y = ground(u, v)
        if HORIZON + 60 < y < SIZE + 20 and -20 < x < SIZE + 20 and not contains(water, (x, y)):
            car(svg, u, v, along_u, rng)

    # from the back to the front: the lower the near point, the nearer the thing
    for _, paint in sorted(items, key=lambda item: item[0][1]):
        paint(svg)


def mountains(svg):
    """The mountains on the horizon: a lit slope and a shaded slope on each peak,
    with a crease down each slope, in haze."""
    haze = svg.gradient([(0, '#c9dbe8', 0.05), (1, '#d3e2ec', 0.95)])
    for left, peak, right in [((-60, HORIZON), (130, 372), (330, HORIZON)), ((180, HORIZON), (390, 402), (590, HORIZON)),
                              ((540, HORIZON), (760, 392), (950, HORIZON)), ((780, HORIZON), (985, 368), (1160, HORIZON))]:
        foot = (peak[0] + 40, HORIZON)
        svg.polygon([left, peak, foot], '#d9a96d')
        svg.polygon([peak, right, foot], '#a0704a')
        svg.polygon([lerp(peak, left, 0.25), lerp(peak, foot, 0.3), lerp(left, foot, 0.55)], '#c08a58')
        svg.polygon([lerp(peak, right, 0.4), lerp(peak, foot, 0.55), lerp(right, foot, 0.4)], '#8a5c3c')
        svg.polygon([left, peak, right], haze)


def boat(svg, center, length, wake=True):
    """A white boat on the water heading toward the upper right, with its wake."""
    cx, cy = center
    unit = (1, -SLOPE)
    bow = (cx + unit[0] * length, cy + unit[1] * length)
    stern = (cx - unit[0] * length, cy - unit[1] * length)
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
    """The clouds, the mountains, the street grid, the far skyline and the bay."""
    svg = Svg(dusk)
    rng = random.Random(1993)
    water = water_area()

    # soft cumulus clouds as on the box, and thin high clouds above them
    cloud = svg.radial([(0, '#ffffff', 0.95), (0.65, '#f4f8fc', 0.85), (1, '#dfeaf4', 0)])
    for cx, cy, r in [(100, 330, 66), (175, 300, 80), (258, 322, 60), (40, 360, 52), (310, 345, 40),
                      (830, 360, 46), (900, 338, 64), (975, 362, 52), (560, 380, 40), (620, 368, 48)]:
        svg.ellipse(cx, cy, r * 1.3, r * 0.82, cloud)

    for cx, cy, rx in [(420, 150, 120), (860, 190, 140), (150, 200, 90)]:
        for dx, dy, scale in [(-0.35, 4, 0.55), (0, 0, 0.8), (0.4, 6, 0.5)]:
            svg.ellipse(cx + dx * rx, cy + dy, rx * scale, 9, cloud, extra=' opacity="0.55"')

    mountains(svg)
    street_grid(svg, rng, water)

    # haze over the ground in front of the horizon, then the far skyline
    haze = svg.gradient([(0, '#cfe0ec', 0.95), (1, '#cfe0ec', 0)])
    svg.polygon([(-60, HORIZON), (SIZE + 60, HORIZON), (SIZE + 60, HORIZON + HAZE_DEPTH), (-60, HORIZON + HAZE_DEPTH)], haze)

    for k in range(18):
        x, height, width = -10 + k * 62 + rng.uniform(-12, 12), rng.uniform(40, 110), rng.uniform(24, 44)
        left, right, _ = prism(svg, (x, HORIZON + 30 + rng.uniform(0, 12)), width * 0.6, width * 0.5, height,
                               '#dbe3ea', '#bccbd8', '#98acc0')
        ribbons(svg, left, int(height // 12), '#a8b8ca', 0.3, 2)

    # the bay, with a sandy shore, glints on the water, and boats
    svg.polygon([(x - 12, y - 8) for x, y in water], '#ece0bd')
    svg.polygon(water, svg.gradient([(0, '#9ad3ee'), (0.5, '#5fa6da'), (1, '#3a7fc4')]))

    for k in range(9):
        x, y = 820 + k * 26 + rng.uniform(-20, 20), 740 + k * 34 + rng.uniform(-10, 10)
        if contains(water, (x, y)) and contains(water, (x + 40, y)):
            svg.path(f'M{x:.1f},{y:.1f} q20,-6 40,0', stroke='#e2f4fc', width=3.5, extra=' opacity="0.6"')

    boat(svg, (905, 790), 22)
    boat(svg, (940, 960), 16)
    boat(svg, (790, 960), 12, wake=False)
    return svg.text()


def sandstone_tower(svg, rng):
    """The tower at the center of the box art: two stone slabs split by a glass
    channel, a glass band across them, and a peaked cap on each slab."""
    left, right, top = prism(svg, (492, 930), 142, 124, 500, STONE_TOP, STONE_LEFT, STONE_RIGHT)
    glass_left = svg.gradient([(0, '#a8daf7'), (1, '#5a98d6')])
    glass_right = svg.gradient([(0, '#6496d0'), (1, '#2c5a98')])

    for face, glass, window in [(left, glass_left, '#9b6a40'), (right, glass_right, '#714728')]:
        for u_range in [(0.07, 0.40), (0.60, 0.93)]:
            punched(svg, face, 3, 9, window, u_range, (0.04, 0.54))
            punched(svg, face, 3, 5, window, u_range, (0.70, 0.97))

        svg.polygon(face_part(face, 0.43, 0.57, 0, 1), glass)
        svg.polygon(face_part(face, 0, 1, 0.58, 0.66), glass)

        # the entrance at the foot of the glass channel
        svg.polygon(face_part(face, 0.40, 0.60, 0, 0.05), '#3a4a66')

    left_top, near_top, right_top, far_top = top
    middle_near, middle_far = lerp(left_top, near_top, 0.5), lerp(far_top, right_top, 0.5)

    for west, south, east, north in [(left_top, middle_near, middle_far, far_top), (middle_near, near_top, right_top, middle_far)]:
        apex = ((west[0] + east[0]) / 2, (north[1] + south[1]) / 2 - 92)
        svg.polygon([north, west, apex], '#f8deb4')
        svg.polygon([north, east, apex], '#e2ae78')
        svg.polygon([west, south, apex], '#f6cd94')
        svg.polygon([south, east, apex], '#c08a58')

        # a small window in the lit slope of each cap
        svg.polygon([lerp(lerp(west, south, 0.5), apex, 0.25), lerp(lerp(west, south, 0.62), apex, 0.25),
                     lerp(lerp(west, south, 0.62), apex, 0.45), lerp(lerp(west, south, 0.5), apex, 0.45)], '#7ab4e4')

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
    svg.path(train, stroke='#e03a2e', width=3, extra=' transform="translate(0,9)"')


def bridge(svg):
    """The red suspension bridge from the near shore across the bay."""
    deck_start, deck_end = (600, 1062), (1050, 830)
    svg.line(deck_start, deck_end, '#6e271e', 16)
    svg.line((deck_start[0], deck_start[1] - 7), (deck_end[0], deck_end[1] - 7), '#eadccb', 6)

    towers = [lerp(deck_start, deck_end, 0.38), lerp(deck_start, deck_end, 0.8)]
    (x0, y0), (x1, y1) = towers
    main = f'M{x0},{y0 - 140} Q{(x0 + x1) / 2},{(y0 + y1) / 2 - 20} {x1},{y1 - 144}'
    for cable in [main,
                  f'M{deck_start[0]},{deck_start[1] - 12} Q{(deck_start[0] + x0) / 2 + 10},{(deck_start[1] + y0) / 2 - 12} {x0},{y0 - 140}',
                  f'M{x1},{y1 - 144} Q{(x1 + deck_end[0]) / 2},{(y1 + deck_end[1]) / 2 - 40} {deck_end[0]},{deck_end[1] - 60}']:
        svg.path(cable, stroke=BRIDGE_RED, width=6)

    # the hangers from the main cable down to the deck
    for k in range(1, 8):
        t = k / 8
        top = bezier((x0, y0 - 140), ((x0 + x1) / 2, (y0 + y1) / 2 - 20), ((x0 + x1) / 2, (y0 + y1) / 2 - 20), (x1, y1 - 144), t)
        bottom = lerp((x0, y0 - 7), (x1, y1 - 7), t)
        svg.line(top, bottom, BRIDGE_RED, 1.6)

    for x, y in towers:
        svg.polygon([(x - 13, y + 30), (x - 5, y + 30), (x - 5, y - 140), (x - 11, y - 140)], BRIDGE_RED)
        svg.polygon([(x + 5, y + 26), (x + 13, y + 26), (x + 11, y - 144), (x + 5, y - 144)], BRIDGE_RED_DARK)

        for k in range(3):
            y_beam = y - 130 + k * 52
            svg.polygon([(x - 11, y_beam), (x + 11, y_beam - 4), (x + 11, y_beam + 6), (x - 11, y_beam + 10)], BRIDGE_RED)

    if svg.dusk:
        for k in range(1, 12):
            x, y = lerp(deck_start, deck_end, k / 12)
            svg.ellipse(x, y - 10, 4, 4, LIT, light=True)


def stadium(svg, center):
    """The round stadium with a red rim, its stands and its field."""
    x, y = center
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


def city_layer(dusk=False):
    """The buildings, the monorail and the bridge, from the back to the front."""
    svg = Svg(dusk)
    rng = random.Random(2000)

    stadium(svg, (900, 598))

    # towers in the middle distance, behind the main group
    for near, left_width, right_width, height, colors in [
            ((120, 650), 48, 42, 220, ('#efe4d2', '#d8c3a5', '#a48e72')),
            ((835, 560), 34, 40, 270, ('#d79f78', '#b8714a', '#874e32')),
            ((548, 600), 36, 38, 300, ('#e2ebf4', '#adc4da', '#7c95b1')),
            ((420, 590), 30, 30, 210, ('#f1e7d8', '#cdbfae', '#9b8d7c'))]:
        left, right, roof = prism(svg, near, left_width, right_width, height, *colors)
        ribbons(svg, left, height // 24, '#7f8ea4', 0.32, 3)
        ribbons(svg, right, height // 24, '#5e6c84', 0.32, 3)
        roof_box(svg, roof, 0.25, 0.3, 10, 9)
        antenna(svg, roof_point(roof, 0.7, 0.6), 34)

    # the teal glass tower with a round top, a reflection down its lit side and a spire
    capsule(svg, 272, 770, 72, 222, TEAL_LIGHT, TEAL_DARK, 15)
    shine = svg.gradient([(0, '#ffffff', 0), (0.5, '#ffffff', 0.5), (1, '#ffffff', 0)], x2=1, y2=0, light=dusk)
    svg.path('M222,300 L222,756 L240,762 L240,292 Z', shine, extra=' opacity="0.7"')
    antenna(svg, (272, 224), 60)

    for cx, top, base in [(612, 338, 712), (686, 358, 700), (756, 384, 690)]:
        capsule(svg, cx, base, 38, top, VIOLET_LIGHT, VIOLET_DARK, 9)

    # the red brick block on the near shore, with a helipad and boxes on its roof
    left, right, roof = prism(svg, (740, 772), 56, 74, 150, '#e08868', '#c95c3e', '#8e3926')
    ribbons(svg, left, 6, '#5a2418', 0.35, 4)
    ribbons(svg, right, 6, '#4a1c12', 0.35, 4)
    pad = roof_point(roof, 0.55, 0.5)
    svg.ellipse(*pad, 22, 8, '#5a5e66')
    svg.ellipse(*pad, 15, 5, 'none', extra=f' stroke="{svg.color("#f4f4f4")}" stroke-width="2"')
    roof_box(svg, roof, 0.12, 0.15, 9, 7)

    sandstone_tower(svg, rng)
    monorail(svg)

    bridge(svg)
    return svg.text()


# the layers by name
PAINTERS = {'city': city_layer, 'land': land_layer}
