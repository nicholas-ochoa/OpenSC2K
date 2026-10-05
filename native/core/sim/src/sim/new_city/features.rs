//! The water features of an extended landform: rivers and their branches,
//! deltas, bays, peninsulas, islands, oxbow lakes and lakes. This is
//! TerrainFeatures and TerrainLakes of the scripts; see `gd.rs` for the number rules.

use super::elevation;
use super::gd::{Vector2, closest_point_to_segment, lerpf, maxf, minf, signf, smoothstep};
use super::heights::EDGE;
use super::noise::Noise;
use crate::sim::random::GameLcgRandom;
use std::f64::consts::{PI, TAU};

/// The options of `carve`.
pub struct Carve<'a> {
    pub sea: i64,
    pub features: &'a [String],
    pub ocean: bool,
    pub river: bool,
    pub water: i64,
    pub hills: i64,
}

impl Carve<'_> {
    fn has(&self, feature: &str) -> bool {
        self.features.iter().any(|selected| selected == feature)
    }
}

pub type Path = Vec<Vector2>;

/// The sample of a map tile in the unit square, turned by `-angle`.
pub fn map_point(x: i64, y: i64, angle: f64) -> Vector2 {
    (Vector2::from_ints(x, y).divided(127.0) - Vector2::new(0.5, 0.5)).rotated(-angle)
}

fn index(x: i64, y: i64) -> usize {
    (x * EDGE + y) as usize
}

pub fn carve(heights: &mut [i32], flags: &mut [u8], options: &Carve, random: &mut GameLcgRandom) {
    let sea = options.sea;
    let wetness = options.water as f64 / 47.0;
    let angle = random.next_mod(6283) as f64 / 1000.0;
    let phase = random.next_mod(6283) as f64 / 1000.0;
    let split = -0.18 + random.next_mod(280) as f64 / 1000.0;
    let bend = -0.12 + random.next_mod(240) as f64 / 1000.0;
    let width = lerpf(0.022, 0.052, wetness);
    let islands = options.has("island") || options.has("islands");
    let mut paths: Vec<Path> = Vec::new();
    let mut junction = Vector2::new(bend, split);
    let delta = options.has("delta") && !islands;
    let mouth = Vector2::new(0.0, if delta { 0.02 } else { 0.9 });

    if !islands {
        if options.has("rejoin") {
            let start = Vector2::new(bend, -0.30);
            let end = Vector2::new(bend * -0.5, if delta { -0.08 } else { 0.30 });
            paths.push(channel(Vector2::new(-bend, -0.9), start, 0.04, phase));
            paths.push(channel(start, end, -0.18, phase));
            paths.push(channel(start, end, 0.20, phase + 1.0));
            paths.push(channel(end, mouth, 0.04, phase));
            junction = end;
        } else if options.river || options.has("crossing") || options.has("branch") {
            paths.push(channel(junction, mouth, 0.055, phase));
            paths.push(channel(Vector2::new(-bend, -0.9), junction, 0.075, phase + 1.3));
        }

        if options.has("branch") {
            paths.push(channel(Vector2::new(-0.72, -0.80), junction, -0.08, phase + 2.4));
        }

        if options.has("crossing") {
            // one tributary ends at the shared channel: a t, not an x
            let side = if random.next_mod(2) == 0 { -1.0 } else { 1.0 };
            paths.push(channel(Vector2::new(side * 0.9, split - 0.12), junction, 0.08, phase + 0.8));
        }
    }

    if delta {
        // distributaries fan out from one shared river mouth into the coast
        for branch in 0..3 {
            let spread = (branch as f64 - 1.0) * 0.42;
            let end = Vector2::new(spread + 0.04 * (phase + branch as f64).sin(), 0.9);
            paths.push(channel(mouth, end, spread * 0.20, phase + branch as f64));
        }
    }

    if options.has("peninsula") && !islands {
        // route the shared river beside the neck instead of through the headland
        for path in &mut paths {
            for point in path.iter_mut() {
                point.x = (point.fx() - 0.24) as f32;
            }
        }
    }

    let oxbows = if options.has("meander") && !islands {
        meander_channels(&mut paths, width, angle, phase, random)
    } else {
        Vec::new()
    };

    let noise = Noise::new(random.next_mod(2_147_483_647), 7.0, 3);
    let scale = lerpf(1.08, 0.83, wetness);

    // each path bounding box contains every segment box that `near_channel` checks
    let bounds: Vec<(Vector2, Vector2)> = paths.iter().map(path_bounds).collect();

    for x in 0..EDGE {
        for y in 0..EDGE {
            let point = map_point(x, y, angle);
            let rough = f64::from(noise.get_2d(point.x, point.y));

            let wet = if islands {
                island_wet(options, point, rough, scale, phase, x, y)
            } else {
                mainland_wet(options, point, rough, wetness, delta, width, phase, &paths, &bounds)
            };

            let at = index(x, y);

            if wet {
                heights[at] = (sea - 2).max(0) as i32;

                if options.ocean || islands || options.has("bay") {
                    flags[at] |= 1;
                }
            } else {
                heights[at] = i64::from(heights[at]).max(sea + 1) as i32;
            }
        }
    }

    keep_main_water(heights, flags, sea);

    // preserve intentional abandoned bends after removing accidental coast pools
    for lake in &oxbows {
        for x in 0..EDGE {
            for y in 0..EDGE {
                if near_channel(map_point(x, y, angle), lake, 0.012) {
                    let at = index(x, y);
                    heights[at] = (sea - 2).max(0) as i32;
                    flags[at] = 0;
                }
            }
        }
    }

    if options.has("lake") || options.has("lakes") {
        carve_lakes(heights, flags, sea, if options.has("lakes") { 2 } else { 1 }, random, options.water);
    }

    elevation::apply(heights, sea, options.features, angle, phase, &noise, options.hills);
}

fn path_bounds(path: &Path) -> (Vector2, Vector2) {
    let mut low = Vector2::new(f64::INFINITY, f64::INFINITY);
    let mut high = Vector2::new(f64::NEG_INFINITY, f64::NEG_INFINITY);

    for point in path {
        low = Vector2::new(minf(low.fx(), point.fx()), minf(low.fy(), point.fy()));
        high = Vector2::new(maxf(high.fx(), point.fx()), maxf(high.fy(), point.fy()));
    }

    (low, high)
}

fn island_wet(options: &Carve, point: Vector2, rough: f64, scale: f64, phase: f64, x: i64, y: i64) -> bool {
    let distance = if options.has("islands") {
        let first = island_distance(point, Vector2::new(-0.235, -0.06), Vector2::new(0.165, 0.28).scaled(scale), phase);
        let second = island_distance(
            point,
            Vector2::new(0.235, 0.075),
            Vector2::new(0.16, 0.255).scaled(scale),
            phase + 2.1,
        );
        minf(first, second)
    } else {
        island_distance(point, Vector2::ZERO, Vector2::new(0.34, 0.30).scaled(scale), phase)
    };

    let mut wet = distance + rough * 0.05 > 0.0;

    if options.has("bay") {
        let inlet_center = if options.has("islands") {
            Vector2::new(-0.235, 0.19)
        } else {
            Vector2::new(0.03, 0.34)
        };
        let inlet = f64::from(((point - inlet_center) / Vector2::new(0.09, 0.18)).length());
        wet = wet || inlet < 1.0 + rough * 0.15;
    }

    // always retain a continuous ocean at the map border
    wet || x < 3 || y < 3 || x > 124 || y > 124
}

#[allow(clippy::too_many_arguments)]
fn mainland_wet(
    options: &Carve,
    point: Vector2,
    rough: f64,
    wetness: f64,
    delta: bool,
    width: f64,
    phase: f64,
    paths: &[Path],
    bounds: &[(Vector2, Vector2)],
) -> bool {
    let (px, py) = (point.fx(), point.fy());
    let mut wet = false;

    if options.ocean {
        wet = py > lerpf(0.34, 0.23, wetness) + rough * 0.12 + 0.04 * (px * 12.0 + phase).sin();
    }

    if options.has("bay") {
        let bay_center = if delta { 0.86 } else { 0.64 };
        let bay = f64::from(Vector2::new(px / lerpf(0.27, 0.36, wetness), (py - bay_center) / lerpf(0.65, 0.77, wetness)).length());
        wet = wet || bay < 1.0 + rough * 0.20 + 0.08 * (px * 19.0 + phase).sin();
    }

    if options.has("peninsula") {
        let axis = 0.08 + 0.04 * (py * 8.0 + phase).sin();
        let neck_width = lerpf(0.17, 0.14, wetness) * (1.0 + 0.13 * (py * 12.0 + phase).sin() + rough * 0.20);
        let neck = (px - axis) / neck_width;
        let coast = lerpf(-0.20, -0.25, wetness)
            + 0.55 * (-neck.abs().powf(4.0)).exp()
            + rough * 0.045
            + 0.016 * (px * 23.0 + py * 13.0 + phase).sin();

        // keep the headland attached to the mainland; channels can cross it
        wet = py > coast;

        if options.has("bay") && px < axis - 0.15 {
            wet = wet || py > -0.28 + rough * 0.06;
        }
    }

    if wet {
        return true;
    }

    let mut local_width = width * (1.0 + rough * 0.50 + 0.12 * (py * 31.0 + phase).sin());

    if options.has("meander") {
        local_width = width * (1.0 + rough * 0.20 + 0.06 * (py * 10.0 + phase).sin());
    }

    for (path, (low, high)) in paths.iter().zip(bounds) {
        if px < low.fx() - local_width || px > high.fx() + local_width || py < low.fy() - local_width || py > high.fy() + local_width {
            continue;
        }

        if near_channel(point, path, local_width) {
            return true;
        }
    }

    false
}

pub(super) fn meander_channels(paths: &mut [Path], width: f64, angle: f64, phase: f64, random: &mut GameLcgRandom) -> Vec<Path> {
    let amplitude = 0.19 + random.next_mod(60) as f64 / 1000.0;
    let frequency = TAU * (1.45 + random.next_mod(350) as f64 / 1000.0);
    let mut bends: Vec<Vector2> = Vec::new();

    for path in paths.iter_mut() {
        for point in path.iter_mut() {
            let fade = smoothstep(0.9, 0.6, point.fy().abs());
            point.x = (point.fx() + fade * amplitude * (point.fy() * frequency + phase).sin()) as f32;
        }

        for index in 1..path.len().saturating_sub(1) {
            let point = path[index];

            if point.fx().abs() < 0.12 || point.fy().abs() > 0.32 {
                continue;
            }

            if (point.fx() - path[index - 1].fx()) * (path[index + 1].fx() - point.fx()) < 0.0 {
                bends.push(point);
            }
        }
    }

    let mut lakes: Vec<Path> = Vec::new();

    // most maps have no oxbows. a suitable bend is still required on selected maps
    if bends.is_empty() || random.next_mod(100) >= 35 {
        return lakes;
    }

    let first = random.next_mod(bends.len() as i64) as usize;
    let limit = 1 + random.next_mod(2) as usize;

    for attempt in 0..bends.len() {
        let point = bends[(first + attempt) % bends.len()];
        let side = signf(point.fx());
        let center = point + Vector2::new(side * (width * 1.5 + 0.07), 0.0);
        let mut lake = Vec::new();
        let mut clear = true;

        for index in 0..17 {
            let t = -PI * 0.5 + PI * index as f64 / 16.0;
            let sample = center + Vector2::new(side * 0.045 * t.cos(), 0.055 * t.sin());
            let world = sample.rotated(angle);

            if world.fx().abs() > 0.46 || world.fy().abs() > 0.46 {
                clear = false;
            }

            for path in paths.iter() {
                if near_channel(sample, path, width * 1.5 + 0.04) {
                    clear = false;
                }
            }

            lake.push(sample);
        }

        if clear {
            lakes.push(lake);
        }

        if lakes.len() >= limit {
            break;
        }
    }

    lakes
}

fn island_distance(point: Vector2, center: Vector2, radius: Vector2, phase: f64) -> f64 {
    let local = (point - center) / radius;
    let angle = f64::from(local.angle());
    let edge =
        1.0 + 0.17 * (3.0 * angle + phase).sin() + 0.10 * (5.0 * angle - phase * 1.7).sin() + 0.045 * (9.0 * angle + phase * 2.3).sin();

    f64::from(local.length()) - edge
}

fn channel(start: Vector2, end: Vector2, bend: f64, phase: f64) -> Path {
    let normal = (end - start).normalized().orthogonal();

    (0..33)
        .map(|step| {
            let t = step as f64 / 32.0;
            let meander = (t * PI).sin() * (bend + 0.026 * (t * TAU * 1.5 + phase).sin());

            start.lerp(end, t) + normal.scaled(meander)
        })
        .collect()
}

fn near_channel(point: Vector2, path: &[Vector2], width: f64) -> bool {
    for pair in path.windows(2) {
        let (a, b) = (pair[0], pair[1]);

        if point.fx() < minf(a.fx(), b.fx()) - width || point.fx() > maxf(a.fx(), b.fx()) + width {
            continue;
        }

        if point.fy() < minf(a.fy(), b.fy()) - width || point.fy() > maxf(a.fy(), b.fy()) + width {
            continue;
        }

        if f64::from(point.distance_squared_to(closest_point_to_segment(point, a, b))) <= width * width {
            return true;
        }
    }

    false
}

/// The four neighbors in the order of the scripts: left, right, up, down.
pub const NEIGHBORS: [(i64, i64); 4] = [(-1, 0), (1, 0), (0, -1), (0, 1)];

/// Fine coast noise can cut off a few pixels. Keep the connected water body.
fn keep_main_water(heights: &mut [i32], flags: &mut [u8], sea: i64) {
    let cells = heights.len();
    let mut seen = vec![false; cells];
    let mut largest: Vec<usize> = Vec::new();

    for start in 0..cells {
        if seen[start] || i64::from(heights[start]) >= sea {
            continue;
        }

        let mut queue = vec![start];
        seen[start] = true;
        let mut cursor = 0;

        while cursor < queue.len() {
            let current = queue[cursor] as i64;
            cursor += 1;
            let (x, y) = (current / EDGE, current % EDGE);

            for (dx, dy) in NEIGHBORS {
                let (nx, ny) = (x + dx, y + dy);

                if nx < 0 || ny < 0 || nx >= EDGE || ny >= EDGE {
                    continue;
                }

                let next = index(nx, ny);

                if !seen[next] && i64::from(heights[next]) < sea {
                    seen[next] = true;
                    queue.push(next);
                }
            }
        }

        if queue.len() > largest.len() {
            largest = queue;
        }
    }

    let mut kept = vec![false; cells];

    for at in largest {
        kept[at] = true;
    }

    for at in 0..cells {
        if i64::from(heights[at]) < sea && !kept[at] {
            heights[at] = (sea + 1) as i32;
            flags[at] = 0;
        }
    }
}

/// TerrainLakes.carve: one or two lakes away from other water.
fn carve_lakes(heights: &mut [i32], flags: &mut [u8], sea: i64, count: i64, random: &mut GameLcgRandom, water: i64) {
    for _ in 0..count {
        let distance = elevation::water_distances(heights, sea);
        let preferred_x = 24 + random.next_mod(80);
        let preferred_y = 24 + random.next_mod(80);
        let preferred = Vector2::from_ints(preferred_x, preferred_y);
        let phase = random.next_mod(6283) as f64 / 1000.0;

        let desired = if count == 2 {
            lerpf(10.0, 30.0, water as f64 / 47.0)
        } else {
            lerpf(13.0, 20.0, water as f64 / 47.0)
        };

        let mut center = Vector2::ZERO;
        let mut clearance = 0.0;
        let mut best = f64::NEG_INFINITY;

        for x in (8..120).step_by(2) {
            for y in (8..120).step_by(2) {
                if i64::from(heights[index(x, y)]) < sea {
                    continue;
                }

                let border = x.min(y).min((127 - x).min(127 - y));
                let space = minf(f64::from(distance[index(x, y)]) * 0.7, border as f64);
                let score = minf(space, desired + 4.0) * 4.0 - f64::from(Vector2::from_ints(x, y).distance_to(preferred)) * 0.03;

                if score > best {
                    best = score;
                    center = Vector2::from_ints(x, y);
                    clearance = space;
                }
            }
        }

        if clearance < 3.0 {
            continue;
        }

        let radius = minf(desired, clearance * 0.75);

        for x in 0..EDGE {
            for y in 0..EDGE {
                let point = (Vector2::from_ints(x, y) - center) / Vector2::new(radius, radius * 0.85);
                let angle = f64::from(point.angle());
                let edge = 1.0 + 0.10 * (angle * 3.0 + phase).sin() + 0.06 * (angle * 5.0 - phase).sin();

                if f64::from(point.length()) < edge {
                    let at = index(x, y);
                    heights[at] = (sea - 2).max(0) as i32;
                    flags[at] = 0;
                }
            }
        }
    }
}
