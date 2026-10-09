//! The relief features of an extended landform: plateau, ridge, valley,
//! rolling hills, basin, canyon and cliffs. This is TerrainElevation of the
//! scripts; see `gd.rs` for the number rules.

use super::features::{NEIGHBORS, map_point};
use super::gd::{Vector2, lerpf, maxf, roundi, smoothstep};
use super::heights::EDGE;
use super::noise::Noise;
use std::f64::consts::TAU;

const FEATURES: [&str; 7] = ["plateau", "ridge", "valley", "rolling", "basin", "canyon", "cliffs"];

/// The highest landform height.
const MAXIMUM_HEIGHT: i64 = 31;

/// The tiles along the map border, which the plateau anchor walks.
const BORDER_TILES: i64 = 508;

pub fn apply(heights: &mut [i32], sea: i64, selected: &[String], angle: f64, phase: f64, noise: &Noise, hills: i64) {
    let has = |feature: &str| selected.iter().any(|name| name == feature);

    if !FEATURES.iter().any(|feature| has(feature)) {
        return;
    }

    let distances = water_distances(heights, sea);
    let sea_value = sea as f64;
    let relief = 7.0 + hills as f64 / 5.0;
    let inland_base = sea_value + if has("cliffs") { relief } else { 0.0 };
    let plateau_anchor = plateau_anchor(heights, sea, angle).rotated(-angle);
    let sample = |x: f64, y: f64| f64::from(noise.get_2d(x as f32, y as f32));

    for x in 0..EDGE {
        for y in 0..EDGE {
            let at = (x * EDGE + y) as usize;

            if i64::from(heights[at]) < sea {
                continue;
            }

            let point = map_point(x, y, angle);
            let (px, py) = (point.fx(), point.fy());
            let rough = f64::from(noise.get_2d(point.x, point.y));
            let mut value = f64::from(heights[at]);

            if has("cliffs") {
                // keep the inland tableland high. grading supplies the coastal descent
                value = sea_value + relief.round();
            }

            if has("plateau") {
                let radius = f64::from(((point - plateau_anchor) / Vector2::new(0.42, 0.36)).length()) + rough * 0.22;
                let top = 1.0 - smoothstep(0.72, 1.12, radius);
                value = lerpf(value, sea_value + relief + 2.0, top);
            }

            if has("ridge") {
                let axis = 0.06 * (py * 8.0 + phase).sin();
                let across = (px - axis) / 0.13;
                let peaks = 0.80 + 0.20 * (py * 17.0 + phase).sin();
                value += relief * (-across * across).exp() * peaks;
            }

            if has("rolling") {
                let warp = Vector2::new(sample(px + 13.0, py), sample(px, py - 17.0)).scaled(0.16);
                let broad = sample((px + warp.fx()) * 0.45 + 21.3, (py + warp.fy()) * 0.45 - 9.7);
                let waves = (0.5 + broad * 1.3 + rough * 0.08).clamp(0.0, 1.0);
                value = inland_base + 2.0 + waves * relief * 0.85;
            }

            if has("basin") {
                let mut local = point - Vector2::new(0.06 * phase.sin(), 0.05 * phase.cos());
                local = local + Vector2::new(rough, sample(px + 7.0, py - 11.0)).scaled(0.14);
                let local_angle = f64::from(local.angle());
                let edge = 1.0 + 0.16 * (local_angle * 3.0 + phase).sin() + 0.10 * (local_angle * 5.0 - phase).sin();
                let radius = f64::from((local / Vector2::new(1.0, 0.87)).length()) / edge + rough * 0.04;
                value = inland_base + 1.0 + relief * smoothstep(0.08, 0.48, radius);
            }

            if has("valley") {
                let distance = f64::from(distances[at]) / 127.0;
                // leave a buildable floodplain before the gentle valley sides rise
                let rise = smoothstep(0.065, 0.295, distance);
                value = lerpf(sea_value + 1.0, maxf(value, sea_value + relief), rise);
            }

            if has("canyon") {
                let axis = 0.14 * (py * 6.0 + phase).sin() + 0.035 * (py * 11.0 - phase).sin();
                let distance = (px - axis).abs();
                let floor_width = 0.09 + 0.015 * (py * 4.0 + phase).sin();
                let rise = smoothstep(floor_width, floor_width + 0.08, distance);
                value = lerpf(sea_value + 1.0, maxf(value, sea_value + relief), rise);
            }

            heights[at] = clamp(roundi(value), sea + 1, MAXIMUM_HEIGHT) as i32;
        }
    }
}

/// `clampi`, which keeps the minimum when the limits cross.
fn clamp(value: i64, minimum: i64, maximum: i64) -> i64 {
    if value < minimum {
        minimum
    } else if value > maximum {
        maximum
    } else {
        value
    }
}

/// The steps from each tile to the nearest water below `sea`.
pub fn water_distances(heights: &[i32], sea: i64) -> Vec<i32> {
    let mut distances = vec![(EDGE * 2) as i32; heights.len()];
    let mut queue: Vec<usize> = Vec::new();

    for (at, height) in heights.iter().enumerate() {
        if i64::from(*height) < sea {
            distances[at] = 0;
            queue.push(at);
        }
    }

    let mut cursor = 0;

    while cursor < queue.len() {
        let at = queue[cursor];
        cursor += 1;
        let (x, y) = (at as i64 / EDGE, at as i64 % EDGE);

        for (dx, dy) in NEIGHBORS {
            let (nx, ny) = (x + dx, y + dy);

            if nx < 0 || ny < 0 || nx >= EDGE || ny >= EDGE {
                continue;
            }

            let next = (nx * EDGE + ny) as usize;

            if distances[next] > distances[at] + 1 {
                distances[next] = distances[at] + 1;
                queue.push(next);
            }
        }
    }

    distances
}

/// The first land tile along the border from the point that the angle names.
fn plateau_anchor(heights: &[i32], sea: i64, angle: f64) -> Vector2 {
    let start = roundi(angle / TAU * BORDER_TILES as f64).rem_euclid(BORDER_TILES);

    for step in 0..BORDER_TILES {
        let along = (start + step) % BORDER_TILES;
        let side = along / 127;
        let offset = along % 127;

        let (x, y) = match side {
            0 => (offset, 0),
            1 => (127, offset),
            2 => (127 - offset, 127),
            _ => (0, 127 - offset),
        };

        if i64::from(heights[(x * EDGE + y) as usize]) >= sea {
            return Vector2::from_ints(x, y).divided(127.0) - Vector2::new(0.5, 0.5);
        }
    }

    Vector2::new(0.0, -0.5)
}
