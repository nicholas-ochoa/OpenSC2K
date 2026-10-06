//! The tile under a source point. A tile can sit at any altitude, so each
//! altitude gives candidate tiles; the front-most tile whose visible surface
//! holds the point wins. This is IsometricGeometry.screen_to_tile.

use super::geometry::{ALTITUDE_STEP, HALF_HEIGHT, HALF_WIDTH, SIDE_MARGIN, TILE_HEIGHT, TILE_WIDTH, TOP_MARGIN};
use sc2k_render::City;
use std::collections::BTreeSet;

const DEEP_WATER_FIRST: u8 = 0x10;
const SHAPE_MASK: u8 = 0x0f;
/// Each bit raises one dry-terrain corner in top, right, bottom, left order.
const CORNER_MASKS: [u8; 15] = [0x0, 0x9, 0x3, 0x6, 0xc, 0xb, 0x7, 0xe, 0xd, 0x1, 0x2, 0x4, 0x8, 0xf, 0x0];
const WATER_FLAG: u8 = 4;

fn land(city: &City, index: usize) -> i32 {
    city.altitude[index] & 31
}

fn water(city: &City, index: usize) -> i32 {
    (city.altitude[index] >> 5) & 31
}

fn visible(city: &City, index: usize) -> bool {
    let wet = city.flags[index] & WATER_FLAG != 0;
    let height = if wet { water(city, index) } else { land(city, index) };

    city.visible >= 32 || height < city.visible
}

/// The corners of the visible surface of a tile: top, right, bottom, left.
pub fn surface_polygon(city: &City, x: i32, y: i32) -> [(f64, f64); 4] {
    let index = (x * city.edge + y) as usize;
    let terrain = city.terrain[index];
    let altitude = if terrain >= DEEP_WATER_FIRST {
        water(city, index)
    } else {
        land(city, index)
    };
    let left = (
        f64::from(SIDE_MARGIN + city.edge * HALF_WIDTH + (x - y) * HALF_WIDTH),
        f64::from(TOP_MARGIN + (x + y) * HALF_HEIGHT - altitude * ALTITUDE_STEP),
    );
    let mut polygon = [
        (left.0 + f64::from(HALF_WIDTH), left.1),
        (left.0 + f64::from(TILE_WIDTH), left.1 + f64::from(HALF_HEIGHT)),
        (left.0 + f64::from(HALF_WIDTH), left.1 + f64::from(TILE_HEIGHT - 1)),
        (left.0, left.1 + f64::from(HALF_HEIGHT)),
    ];

    if terrain < DEEP_WATER_FIRST {
        let raised = CORNER_MASKS.get(usize::from(terrain & SHAPE_MASK)).copied().unwrap_or(0);

        for (corner, point) in polygon.iter_mut().enumerate() {
            if raised & (1 << corner) != 0 {
                point.1 -= f64::from(ALTITUDE_STEP);
            }
        }
    }

    polygon
}

/// True when `point` is inside the convex polygon, edges included.
fn inside(point: (f64, f64), polygon: &[(f64, f64); 4]) -> bool {
    let mut sign = 0.0_f64;

    for index in 0..4 {
        let (a, b) = (polygon[index], polygon[(index + 1) % 4]);
        let cross = (b.0 - a.0) * (point.1 - a.1) - (b.1 - a.1) * (point.0 - a.0);

        if cross != 0.0 {
            if sign != 0.0 && cross.signum() != sign {
                return false;
            }

            sign = cross.signum();
        }
    }

    true
}

/// The tile under the source `point`, or `None`.
pub fn tile_at(city: &City, point: (f64, f64)) -> Option<(i32, i32)> {
    let edge = city.edge;
    let origin = f64::from(SIDE_MARGIN + edge * HALF_WIDTH);
    let difference = (point.0 - origin - f64::from(HALF_WIDTH)) / f64::from(HALF_WIDTH);
    let mut candidates = BTreeSet::new();

    for altitude in 0..32 {
        let sum = (point.1 - f64::from(TOP_MARGIN) - f64::from(HALF_HEIGHT) + f64::from(altitude * ALTITUDE_STEP)) / f64::from(HALF_HEIGHT);
        let center = (((sum + difference) * 0.5).round() as i32, ((sum - difference) * 0.5).round() as i32);

        for dx in -1..=1 {
            for dy in -1..=1 {
                let (x, y) = (center.0 + dx, center.1 + dy);

                if (0..edge).contains(&x) && (0..edge).contains(&y) {
                    candidates.insert((x, y));
                }
            }
        }
    }

    let mut result = None;
    let mut result_order = -1_i64;

    for (x, y) in candidates {
        let order = i64::from(x + y) * i64::from(edge) + i64::from(y);

        if !visible(city, (x * edge + y) as usize) || order <= result_order {
            continue;
        }

        if inside(point, &surface_polygon(city, x, y)) {
            result = Some((x, y));
            result_order = order;
        }
    }

    result
}
