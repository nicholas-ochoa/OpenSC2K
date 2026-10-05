//! Thin tile grid lines on HD ground art, an optional HD effect.
//!
//! Each ground draw paints the two back edges of its tile, and the front edges
//! at the map border, so each shared edge paints one time. The lines follow the
//! raised corners of the tile and draw in painter order, so later art covers
//! them. Shore tiles draw lines only over their land pixels.

use super::region::Region;
use super::sprites::Sprite;
use super::{Draw, Rect};

type Point = [f32; 2];

/// The vertex color tag of grid line geometry. Its UVs hold the distance from
/// the line, in view pixels, not atlas coordinates.
pub const TAG: u8 = 48;

/// Line width at the large view, in view pixels.
const WIDTH: f32 = 0.45;
const COLOR: [f32; 3] = [0.22, 0.19, 0.10];
const OPACITY: f32 = 0.36;

/// `Draw::surface_grid` bits: the raised corners (0-3), the painted edges
/// (4-7), a marked draw, and a shore draw.
const CORNERS: u16 = 0xf;
const EDGE_SHIFT: u16 = 4;
const MARKED: u16 = 0x100;
const SHORE: u16 = 0x200;

/// The edges from the top corner and from the left corner: the back edges.
const BACK_EDGES: u16 = 0b1001;
const RIGHT_EDGE: u16 = 0b0010;
const BOTTOM_EDGE: u16 = 0b0100;

/// Raised corners by terrain shape, in top, right, bottom, left order.
const CORNER_MASKS: [u8; 15] = [0x0, 0x9, 0x3, 0x6, 0xc, 0xb, 0x7, 0xe, 0xd, 0x1, 0x2, 0x4, 0x8, 0xf, 0x0];

/// The fixed blue colors of shore art, and the animated water colors.
const WATER_INDICES: [std::ops::RangeInclusive<u8>; 3] = [95..=95, 146..=146, 200..=211];

#[derive(Clone, Copy)]
struct Segment {
    a: Point,
    b: Point,
    normal: Point,
    width: f32,
}

/// Marks the ground draw of the tile at `x`, `y` with terrain shape `shape`.
pub fn mark(draw: &mut Draw, shape: u8, x: i32, y: i32, edge: i32) {
    if ![8, 16, 32].contains(&draw.rect.w) || draw.rect.h < draw.rect.w / 2 + 1 || usize::from(shape) >= CORNER_MASKS.len() {
        return;
    }

    let edges = BACK_EDGES | if x == edge - 1 { RIGHT_EDGE } else { 0 } | if y == edge - 1 { BOTTOM_EDGE } else { 0 };
    draw.surface_grid = MARKED | (edges << EDGE_SHIFT) | u16::from(CORNER_MASKS[usize::from(shape)]);
}

/// Marks a flat shore draw. Its lines show only on land pixels.
pub fn mark_shore(draw: &mut Draw, x: i32, y: i32, edge: i32) {
    mark(draw, 0, x, y, edge);

    if draw.surface_grid != 0 {
        draw.surface_grid |= SHORE;
    }
}

/// Whether the indexed pixel at `x`, `y` is land, or None when it is transparent.
fn land_label(source: &Sprite, x: i32, y: i32) -> Option<bool> {
    if !(0..source.w).contains(&x) || !(0..source.h).contains(&y) {
        return None;
    }

    let at = ((y * source.w + x) * 2) as usize;

    (source.la[at + 1] != 0).then(|| !WATER_INDICES.iter().any(|range| range.contains(&source.la[at])))
}

/// Whether the pixel is land. A transparent pixel at the stepped edge of the
/// indexed diamond takes the material of its neighbors; water wins.
fn land_pixel(source: &Sprite, x: i32, y: i32) -> bool {
    if let Some(land) = land_label(source, x, y) {
        return land;
    }

    for neighbors in [
        [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]],
        [[x - 1, y - 1], [x + 1, y - 1], [x - 1, y + 1], [x + 1, y + 1]],
    ] {
        let mut has_land = false;

        for [nx, ny] in neighbors {
            match land_label(source, nx, ny) {
                Some(false) => return false,
                Some(true) => has_land = true,
                None => {}
            }
        }

        if has_land {
            return true;
        }
    }

    false
}

fn dot(a: Point, b: Point) -> f32 {
    a[0] * b[0] + a[1] * b[1]
}

fn add(a: Point, b: Point) -> Point {
    [a[0] + b[0], a[1] + b[1]]
}

fn sub(a: Point, b: Point) -> Point {
    [a[0] - b[0], a[1] - b[1]]
}

fn mul(a: Point, scale: f32) -> Point {
    [a[0] * scale, a[1] * scale]
}

/// The two triangles of the top face. A tile with one raised or lowered corner
/// keeps the opposite half flat.
fn triangles(mask: u8) -> [[usize; 3]; 2] {
    if [1, 4, 11, 14].contains(&mask) {
        [[0, 1, 3], [1, 2, 3]]
    } else {
        [[0, 1, 2], [0, 2, 3]]
    }
}

/// The line segments of a marked draw.
fn segments(draw: &Draw) -> Vec<Segment> {
    if draw.surface_grid & MARKED == 0 {
        return Vec::new();
    }

    let w = draw.rect.w as f32;
    let y = (draw.rect.y + draw.rect.h - draw.rect.w / 2 - 1) as f32;
    let x = draw.rect.x as f32;
    let mut corners = [[x + w / 2.0, y], [x + w, y + w / 4.0], [x + w / 2.0, y + w / 2.0], [x, y + w / 4.0]];
    let mask = (draw.surface_grid & CORNERS) as u8;

    // A raised corner is one altitude step (3/8 of the tile width) higher.
    for (corner, point) in corners.iter_mut().enumerate() {
        if mask & (1 << corner) != 0 {
            point[1] -= w * 3.0 / 8.0;
        }
    }

    let faces = triangles(mask);
    let mut output = Vec::with_capacity(4);

    for edge in 0..4 {
        if draw.surface_grid & (1 << (edge as u16 + EDGE_SHIFT)) == 0 {
            continue;
        }

        let next = (edge + 1) % 4;
        let (a, b) = (corners[edge], corners[next]);
        let vector = sub(b, a);
        let length = vector[0].hypot(vector[1]);

        if length < 0.001 {
            continue;
        }

        let normal = [-vector[1] / length, vector[0] / length];
        let third = faces
            .iter()
            .find(|ids| ids.contains(&edge) && ids.contains(&next))
            .and_then(|ids| ids.iter().find(|&&id| id != edge && id != next))
            .copied()
            .unwrap_or((edge + 2) % 4);
        let inward = dot(sub(corners[third], a), normal);

        // A face turned away from the camera, or a steep rear ramp compressed
        // to a quarter of a flat face, hides its edge.
        if inward <= 0.0 || inward * length <= w * w / 16.0 + 0.001 {
            continue;
        }

        output.push(Segment {
            a,
            b,
            normal,
            width: WIDTH * w / 32.0,
        });
    }

    output
}

/// `polygon` clipped to `bounds`.
fn clip(mut polygon: Vec<Point>, bounds: Rect) -> Vec<Point> {
    for (axis, limit, sign) in [
        (0, bounds.x as f32, 1.0),
        (0, (bounds.x + bounds.w) as f32, -1.0),
        (1, bounds.y as f32, 1.0),
        (1, (bounds.y + bounds.h) as f32, -1.0),
    ] {
        let source = std::mem::take(&mut polygon);

        if source.is_empty() {
            break;
        }

        let mut previous = source[source.len() - 1];

        for point in source {
            let a = (previous[axis] - limit) * sign;
            let b = (point[axis] - limit) * sign;

            if (a >= 0.0) != (b >= 0.0) {
                polygon.push(add(previous, mul(sub(point, previous), a / (a - b))));
            }

            if b >= 0.0 {
                polygon.push(point);
            }

            previous = point;
        }
    }

    polygon
}

/// Adds the line geometry of `draw` to a GPU region. The shader draws each
/// line with antialiased edges at every zoom.
pub fn append(region: &mut Region, draw: &Draw, bounds: Rect, original: &Sprite) {
    let view = match draw.rect.w {
        8 => 0.0,
        16 => 1.0,
        _ => 2.0,
    };

    for segment in segments(draw) {
        // One extra view pixel on each side leaves room for the antialiased edge.
        let outer = mul(segment.normal, -1.0);
        let inner = mul(segment.normal, segment.width + 1.0);
        let polygon = clip(
            vec![
                add(segment.a, outer),
                add(segment.b, outer),
                add(segment.b, inner),
                add(segment.a, inner),
            ],
            bounds,
        );
        let mut polygons = Vec::new();

        if draw.surface_grid & SHORE != 0 {
            // Horizontal runs of land pixels.
            for y in 0..original.h {
                let mut x = 0;

                while x < original.w {
                    if !land_pixel(original, x, y) {
                        x += 1;
                        continue;
                    }

                    let start = x;

                    while x < original.w && land_pixel(original, x, y) {
                        x += 1;
                    }

                    let part = clip(polygon.clone(), Rect::new(draw.rect.x + start, draw.rect.y + y, x - start, 1));

                    if part.len() >= 3 {
                        polygons.push(part);
                    }
                }
            }
        } else if polygon.len() >= 3 {
            polygons.push(polygon);
        }

        for polygon in polygons {
            let first = region.vertices.len() as i32;

            for point in &polygon {
                region.vertices.push([point[0] - bounds.x as f32, point[1] - bounds.y as f32]);
                region.uvs.push([0.0, dot(sub(*point, segment.a), segment.normal)]);
                region.colors.push([f32::from(TAG) / 255.0, view / 255.0, 0.0, 1.0]);
            }

            for corner in 1..polygon.len() - 1 {
                region.indices.extend([first, first + corner as i32, first + corner as i32 + 1]);
            }
        }
    }
}

/// Whether a vertex color is the grid line tag. Its UVs are not atlas UVs.
pub fn is_grid_color(color: &[f32; 4]) -> bool {
    (color[0] * 255.0).round() == f32::from(TAG)
}

/// Paints the lines of `draw` into CPU pixels of `bounds` at `factor` pixels for
/// each view pixel, only over the pixels that `owner` painted.
#[allow(clippy::too_many_arguments)]
pub fn raster(draw: &Draw, bounds: Rect, factor: i32, pixels: &mut [u8], owners: &[i64], owner: i64, original: &Sprite) {
    let width = bounds.w * factor;
    let height = bounds.h * factor;

    for segment in segments(draw) {
        let vector = sub(segment.b, segment.a);
        let length_squared = dot(vector, vector);
        let feather = (segment.normal[0].abs() + segment.normal[1].abs()) / factor as f32;
        let span = |a: f32, b: f32, origin: i32, limit: i32| {
            let first = ((a.min(b) - 1.0 - origin as f32) * factor as f32).floor().max(0.0) as i32;
            let last = ((a.max(b) + 1.0 - origin as f32) * factor as f32).ceil().min(limit as f32) as i32;
            first..last
        };

        for py in span(segment.a[1], segment.b[1], bounds.y, height) {
            for px in span(segment.a[0], segment.b[0], bounds.x, width) {
                let at = (py * width + px) as usize;

                if owners[at] != owner {
                    continue;
                }

                let point = [
                    bounds.x as f32 + (px as f32 + 0.5) / factor as f32,
                    bounds.y as f32 + (py as f32 + 0.5) / factor as f32,
                ];

                if draw.surface_grid & SHORE != 0
                    && !land_pixel(
                        original,
                        (point[0] - draw.rect.x as f32).floor() as i32,
                        (point[1] - draw.rect.y as f32).floor() as i32,
                    )
                {
                    continue;
                }

                let local = sub(point, segment.a);
                let along = dot(local, vector) / length_squared;

                if !(0.0..=1.0).contains(&along) {
                    continue;
                }

                let distance = dot(local, segment.normal);
                let coverage = (segment.width / 2.0 + feather / 2.0 - (distance - segment.width / 2.0).abs()) / feather;
                let opacity = coverage.clamp(0.0, 1.0) * OPACITY;

                for (channel, color) in COLOR.iter().enumerate() {
                    let old = f32::from(pixels[at * 4 + channel]);
                    pixels[at * 4 + channel] = (old * (1.0 - opacity) + color * 255.0 * opacity).round() as u8;
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ground(w: i32, h: i32) -> Draw {
        Draw::new(0, Rect::new(0, 0, w, h))
    }

    #[test]
    fn flat_tiles_paint_their_back_edges_and_the_map_border() {
        let mut draw = ground(32, 17);
        mark(&mut draw, 0, 1, 1, 4);
        assert_eq!(segments(&draw).len(), 2);

        mark(&mut draw, 0, 3, 3, 4);
        assert_eq!(segments(&draw).len(), 4);

        // a tile smaller than a diamond is not marked
        let mut small = ground(32, 10);
        mark(&mut small, 0, 1, 1, 4);
        assert_eq!(small.surface_grid, 0);
    }

    #[test]
    fn raised_corners_lift_the_line_ends() {
        let mut flat = ground(32, 17);
        let mut raised = ground(32, 29);
        mark(&mut flat, 0, 0, 0, 4);
        mark(&mut raised, 13, 0, 0, 4);
        let (flat, raised) = (segments(&flat), segments(&raised));

        // a fully raised tile is one step higher in a taller sprite: the same place
        assert_eq!(flat.len(), raised.len());
        assert!((flat[0].a[1] - raised[0].a[1]).abs() < 0.01);
    }

    #[test]
    fn region_geometry_has_one_tagged_color_for_each_vertex() {
        let mut draw = ground(32, 17);
        mark(&mut draw, 0, 0, 0, 4);
        let original = Sprite {
            w: 32,
            h: 17,
            rgba: vec![],
            la: [10, 255].repeat(32 * 17),
        };
        let mut region = Region::default();
        append(&mut region, &draw, Rect::new(0, 0, 64, 64), &original);

        assert!(!region.vertices.is_empty());
        assert_eq!(region.vertices.len(), region.colors.len());
        assert!(region.colors.iter().all(is_grid_color));

        // a shore of only water draws no line
        let mut shore = ground(32, 17);
        mark_shore(&mut shore, 0, 0, 4);
        let water = Sprite {
            la: [200, 255].repeat(32 * 17),
            ..original
        };
        let mut empty = Region::default();
        append(&mut empty, &shore, Rect::new(0, 0, 64, 64), &water);
        assert!(empty.vertices.is_empty());
    }

    #[test]
    fn cpu_lines_darken_only_the_owner_pixels() {
        let mut draw = ground(32, 17);
        mark(&mut draw, 0, 0, 0, 4);
        let original = Sprite {
            w: 32,
            h: 17,
            rgba: vec![],
            la: [10, 255].repeat(32 * 17),
        };
        let bounds = Rect::new(0, 0, 32, 17);
        let mut pixels = [200, 200, 200, 255].repeat(32 * 17);
        let mut owners = vec![5_i64; 32 * 17];
        owners[0] = 6;
        raster(&draw, bounds, 1, &mut pixels, &owners, 5, &original);

        assert!(pixels.chunks_exact(4).any(|p| p[0] < 200));
        assert_eq!(pixels[..4], [200, 200, 200, 255]);
    }
}
