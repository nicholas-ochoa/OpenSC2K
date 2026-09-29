//! New-city terrain on the map, as the map-size stages of NewCityTerrain.generate.
//!
//! GDScript makes the 128 by 128 landform, because its layout features use Godot
//! noise and float vectors. This module scales the landform to the map, grades it,
//! retiles the terrain, grows trees, and runs the streams.

use super::Maps;
use super::terrain::{self, NEIGHBOR_MASKS, NEIGHBOR_OFFSETS};
use crate::sim::bytes::write_u32_be;
use crate::sim::city::City;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2altitude_layout as altitude_layout;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::random::SimRandom;
use crate::sim::value::{ToValue, Value};

/// The edge of the generated landform.
pub const LANDFORM_EDGE: usize = 128;

const STREAM_X_OFFSETS: [i64; 4] = [-1, 0, 1, 0];
const STREAM_Y_OFFSETS: [i64; 4] = [0, 1, 0, -1];
const STREAM_TURN_ORDER: [i64; 4] = [0, 1, 3, 2];

/// The landform and the options that the map stages read.
#[derive(Clone, Debug, Default)]
pub struct Landform {
    /// Heights of the 128 by 128 landform, indexed x * 128 + y. An extended
    /// landform is graded here before it is scaled.
    pub heights: Vec<i32>,
    /// XBIT flags of the landform, such as salt water along the ocean.
    pub coast_flags: Vec<u8>,
    pub extended: bool,
    pub smooth_slopes: bool,
    pub has_ocean: bool,
    pub has_river: bool,
    pub water_level: i64,
    pub water: i64,
    pub trees: i64,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct TerrainSummary {
    pub water_tiles: i64,
    pub salt_water_tiles: i64,
    pub tree_tiles: i64,
    pub minimum_altitude: i64,
    pub maximum_altitude: i64,
}

impl ToValue for TerrainSummary {
    fn to_value(&self) -> Value {
        Value::Dict(
            [
                ("water_tiles", self.water_tiles),
                ("salt_water_tiles", self.salt_water_tiles),
                ("tree_tiles", self.tree_tiles),
                ("minimum_altitude", self.minimum_altitude),
                ("maximum_altitude", self.maximum_altitude),
            ]
            .into_iter()
            .map(|(key, value)| (Value::Str(key.into()), Value::Int(value)))
            .collect(),
        )
    }
}

/// Write the terrain of `landform` to the city. The caller checks the chunk sizes
/// and the landform size. ALTM, XTER, XBLD, XZON, XBIT, and MISC are written.
/// Stream water changes a copy of XTXT, which the city does not keep.
pub fn generate(city: &mut City, landform: &Landform, random: &mut SimRandom) -> TerrainSummary {
    let map_edge = city.map_size;
    let edge = map_edge as usize;
    let cells = edge * edge;
    let mut altitude = vec![0u8; city.altm.data.len()];
    let mut terrain = vec![0u8; city.xter.data.len()];
    let mut buildings = vec![0u8; city.xbld.data.len()];
    let mut zones = vec![0u8; city.xzon.data.len()];
    let mut text_overlays = city.xtxt.data.clone();
    let mut misc = city.misc.data.clone();

    let mut landform_heights = landform.heights.clone();

    if landform.extended {
        grade_layout(&mut landform_heights, LANDFORM_EDGE);
    }

    let (mut heights, mut flags) = if edge != LANDFORM_EDGE {
        let mut flags = vec![0u8; city.xbit.data.len()];
        let heights = enlarge_landform(&landform_heights, &landform.coast_flags, &mut flags, edge);

        (heights, flags)
    } else {
        (landform_heights, landform.coast_flags.clone())
    };

    grade_heights(&mut heights, edge);

    if landform.smooth_slopes || landform.extended || edge != LANDFORM_EDGE {
        grade_layout(&mut heights, edge);
        fill_unsupported_slopes(&mut heights, edge);
    }

    for index in 0..cells {
        altitude[index * 2 + 1] = (heights[index] as i64 & altitude_layout::LEVEL_MASK) as u8;
    }

    write_u32_be(&mut misc, misc_layout::WATER_LEVEL, landform.water_level);
    write_u32_be(&mut misc, misc_layout::HAS_OCEAN, landform.has_ocean as i64);
    write_u32_be(&mut misc, misc_layout::HAS_RIVER, landform.has_river as i64);

    let all_indices = (0..cells as i64).collect::<Vec<i64>>();
    terrain::retile_region(
        &mut altitude,
        &mut buildings,
        &mut terrain,
        &mut zones,
        &mut flags,
        &mut misc,
        &all_indices,
        landform.water_level,
        map_edge,
    );

    let cluster_count = (((landform.trees * landform.trees) >> 1) * map_edge * map_edge) / 16384;
    grow_trees(&mut buildings, &flags, cluster_count, random, map_edge);

    if landform.has_ocean {
        finish_ocean(&mut flags, edge);
    }

    let streams = if landform.extended { 0 } else { landform.water >> 2 };

    for _ in 0..streams {
        let start = Vec2i::new(random.next_u15() % map_edge, random.next_u15() % map_edge);
        let length = (((random.next_u15() & 0x7f) + 50) * map_edge) / 128;
        let mut labels = [];
        let mut microsims = [];
        let mut underground = [];
        let mut maps = Maps {
            map_edge,
            altitude: &mut altitude,
            buildings: &mut buildings,
            terrain: &mut terrain,
            zones: &mut zones,
            underground: &mut underground,
            flags: &mut flags,
            text_overlays: &mut text_overlays,
            labels: &mut labels,
            wide_labels: false,
            vehicle_caps: crate::sim::moving::spawner::VehicleCaps::legacy(edge as i64),
            microsims: &mut microsims,
            misc: &mut misc,
        };
        make_stream(&mut maps, start, length, random);
    }

    recount_buildings(&buildings, &mut misc);

    let summary = TerrainSummary {
        water_tiles: flags.iter().filter(|&&value| value as i64 & flag_bits::WATER != 0).count() as i64,
        salt_water_tiles: flags.iter().filter(|&&value| value as i64 & flag_bits::SALT_WATER != 0).count() as i64,
        tree_tiles: buildings
            .iter()
            .filter(|&&value| (tiles::TREE_FIRST..=tiles::TREE_LAST).contains(&(value as i64)))
            .count() as i64,
        minimum_altitude: (0..cells).map(|index| land_altitude(&altitude, index)).fold(31, i64::min),
        maximum_altitude: (0..cells).map(|index| land_altitude(&altitude, index)).fold(0, i64::max),
    };

    city.altm.replace(altitude);
    city.xter.replace(terrain);
    city.xbld.replace(buildings);
    city.xzon.replace(zones);
    city.xbit.replace(flags);
    city.misc.replace(misc);

    summary
}

#[inline]
fn land_altitude(altitude: &[u8], index: usize) -> i64 {
    altitude[index * 2 + 1] as i64 & altitude_layout::LEVEL_MASK
}

/// Godot `lerpf`.
#[inline]
fn lerp(from: f64, to: f64, weight: f64) -> f64 {
    from + (to - from) * weight
}

/// Scale the 128 by 128 landform to an `edge` by `edge` map. The coast flags take
/// the nearest landform tile.
fn enlarge_landform(source: &[i32], coast: &[u8], flags: &mut [u8], edge: usize) -> Vec<i32> {
    let mut result = vec![0; edge * edge];
    let last = (LANDFORM_EDGE - 1) as f64;

    for x in 0..edge {
        let u = x as f64 * last / (edge - 1) as f64;
        let left = u.floor() as usize;
        let right = (left + 1).min(LANDFORM_EDGE - 1);

        for y in 0..edge {
            let v = y as f64 * last / (edge - 1) as f64;
            let top = v.floor() as usize;
            let bottom = (top + 1).min(LANDFORM_EDGE - 1);
            let a = lerp(
                source[left * LANDFORM_EDGE + top] as f64,
                source[right * LANDFORM_EDGE + top] as f64,
                u - left as f64,
            );
            let b = lerp(
                source[left * LANDFORM_EDGE + bottom] as f64,
                source[right * LANDFORM_EDGE + bottom] as f64,
                u - left as f64,
            );
            let index = x * edge + y;

            result[index] = lerp(a, b, v - top as f64).round() as i32;
            flags[index] = coast[u.round() as usize * LANDFORM_EDGE + v.round() as usize];
        }
    }

    result
}

/// Lower each tile until no cardinal neighbor is more than one level lower.
/// This visits the tiles in the order of the recursive GDScript grade.
fn grade_heights(heights: &mut [i32], edge: usize) {
    let mut stack = Vec::new();

    for x in 0..edge {
        for y in 0..edge {
            grade_cell(heights, x, y, edge, &mut stack);
        }
    }
}

/// One frame of the grade: a lowered tile and the next neighbor to visit.
struct GradeFrame {
    x: usize,
    y: usize,
    current: i32,
    next: u8,
}

fn grade_cell(heights: &mut [i32], x: usize, y: usize, edge: usize, stack: &mut Vec<GradeFrame>) {
    if let Some(frame) = lower_cell(heights, x, y, edge) {
        stack.push(frame);
    }

    // Visit neighbors north, east, south, then west, as CARDINAL_OFFSETS does.
    while let Some(frame) = stack.last_mut() {
        let (x, y, current) = (frame.x, frame.y, frame.current);
        let direction = frame.next;
        frame.next += 1;

        let neighbor = match direction {
            0 if y > 0 => Some((x, y - 1)),
            1 if x + 1 < edge => Some((x + 1, y)),
            2 if y + 1 < edge => Some((x, y + 1)),
            3 if x > 0 => Some((x - 1, y)),
            0..=3 => None,
            _ => {
                stack.pop();
                continue;
            }
        };

        if let Some((near_x, near_y)) = neighbor
            && current < heights[near_x * edge + near_y]
            && let Some(frame) = lower_cell(heights, near_x, near_y, edge)
        {
            stack.push(frame);
        }
    }
}

/// Lower one tile by one level when a cardinal neighbor is more than one level lower.
fn lower_cell(heights: &mut [i32], x: usize, y: usize, edge: usize) -> Option<GradeFrame> {
    let index = x * edge + y;
    let current = heights[index];

    if !((y > 0 && heights[index - 1] + 1 < current)
        || (x + 1 < edge && heights[index + edge] + 1 < current)
        || (y + 1 < edge && heights[index + 1] + 1 < current)
        || (x > 0 && heights[index - edge] + 1 < current))
    {
        return None;
    }

    heights[index] = current - 1;

    Some(GradeFrame {
        x,
        y,
        current: current - 1,
        next: 0,
    })
}

/// Native slopes span at most one level across a tile, including diagonals.
/// Two distance-transform sweeps constrain all eight neighbors. Each sweep reads
/// the neighbors that it has already updated.
fn grade_layout(heights: &mut [i32], edge: usize) {
    for x in 0..edge {
        for y in 0..edge {
            let index = x * edge + y;
            let mut height = heights[index];

            if x > 0 {
                let previous_row = index - edge;
                height = height.min(heights[previous_row] + 1);

                if y > 0 {
                    height = height.min(heights[previous_row - 1] + 1);
                }

                if y + 1 < edge {
                    height = height.min(heights[previous_row + 1] + 1);
                }
            }

            if y > 0 {
                height = height.min(heights[index - 1] + 1);
            }

            heights[index] = height;
        }
    }

    for x in (0..edge).rev() {
        for y in (0..edge).rev() {
            let index = x * edge + y;
            let mut height = heights[index];

            if x + 1 < edge {
                let next_row = index + edge;
                height = height.min(heights[next_row] + 1);

                if y > 0 {
                    height = height.min(heights[next_row - 1] + 1);
                }

                if y + 1 < edge {
                    height = height.min(heights[next_row + 1] + 1);
                }
            }

            if y + 1 < edge {
                height = height.min(heights[index + 1] + 1);
            }

            heights[index] = height;
        }
    }
}

/// The sprite set has no opposite-corner saddle. Fill these depressions and
/// propagate a one-level diagonal grade before choosing slope sprites.
fn fill_unsupported_slopes(heights: &mut [i32], edge: usize) {
    let mut queue = (0..heights.len()).collect::<Vec<usize>>();
    let mut pending = vec![true; edge * edge];
    let mut cursor = 0;

    while cursor < queue.len() {
        let index = queue[cursor];
        cursor += 1;
        pending[index] = false;

        let x = (index / edge) as i64;
        let y = (index % edge) as i64;
        let height = heights[index];
        let mut mask = 0;
        let mut maximum = height;

        for neighbor in 0..8 {
            let near_x = x + NEIGHBOR_OFFSETS[neighbor].x;
            let near_y = y + NEIGHBOR_OFFSETS[neighbor].y;

            if near_x >= 0 && near_x < edge as i64 && near_y >= 0 && near_y < edge as i64 {
                let near_height = heights[near_x as usize * edge + near_y as usize];
                maximum = maximum.max(near_height);

                if near_height > height {
                    mask |= NEIGHBOR_MASKS[neighbor];
                }
            }
        }

        let mut target = height.max(maximum - 1);

        if mask == 5 || mask == 10 || mask == 15 {
            target = target.max(height + 1);
        }

        if target == height {
            continue;
        }

        heights[index] = target;

        for offset in NEIGHBOR_OFFSETS {
            let near_x = x + offset.x;
            let near_y = y + offset.y;

            if near_x >= 0 && near_x < edge as i64 && near_y >= 0 && near_y < edge as i64 {
                let next = near_x as usize * edge + near_y as usize;

                if !pending[next] {
                    pending[next] = true;
                    queue.push(next);
                }
            }
        }
    }
}

fn grow_trees(buildings: &mut [u8], flags: &[u8], cluster_count: i64, random: &mut SimRandom, map_edge: i64) {
    for _ in 0..cluster_count {
        let base_x = random.next_u15() % map_edge;
        let base_y = random.next_u15() % map_edge;
        let attempts = random.next_u15() & 0x3f;

        for _ in 0..attempts {
            let x = base_x + random.next_u15() % 5 - random.next_u15() % 5;
            let y = base_y + random.next_u15() % 5 - random.next_u15() % 5;

            if x < 0 || x >= map_edge || y < 0 || y >= map_edge {
                continue;
            }

            let index = (x * map_edge + y) as usize;

            if flags[index] as i64 & flag_bits::WATER != 0 {
                continue;
            }

            let current = buildings[index] as i64;

            if current < tiles::TREE_FIRST {
                buildings[index] = (tiles::TREE_FIRST + (random.next_u15() & 1)) as u8;
            } else if current < tiles::TREES_6 {
                buildings[index] = (current + 1) as u8;
            } else if current <= tiles::TREE_LAST {
                buildings[index] = (tiles::TREES_6 + (random.next_u15() & 1)) as u8;
            }
        }
    }
}

/// Keep salt water only where it reaches the ocean from the far corner.
fn finish_ocean(flags: &mut [u8], edge: usize) {
    let salt = flag_bits::SALT_WATER as u8;
    let both = salt | flag_bits::WATER as u8;

    for _ in 0..4 {
        for y in 1..edge {
            for x in 1..edge {
                let index = x * edge + y;
                let water_bits = flags[index] & both;

                if water_bits == salt {
                    flags[index] &= !salt;
                } else if water_bits == both {
                    flags[index - 1] |= salt;
                    flags[index - edge] |= salt;
                }
            }
        }
    }
}

/// The landscape editor stream, as LandscapeEditorCommand. It runs one generator
/// stream from `start`, then turns changed water below a higher neighbor into a
/// waterfall. Only the chunks that change are marked written.
pub fn editor_stream(city: &mut City, start: Vec2i, length: i64, random: &mut SimRandom) {
    let map_edge = city.map_size;
    let originals = [&city.altm, &city.xbld, &city.xter, &city.xzon, &city.xbit, &city.misc].map(|chunk| chunk.data.clone());
    let previous_terrain = &originals[2];
    let previous_flags = &originals[4];

    {
        let mut maps = city.maps();
        make_stream(&mut maps, start, length, random);
    }

    let altitude = &city.altm.data;
    let terrain = &mut city.xter.data;
    let flags = &city.xbit.data;

    for index in 0..(map_edge * map_edge) as usize {
        if terrain[index] == previous_terrain[index] && flags[index] == previous_flags[index] {
            continue;
        }

        let tile = terrain[index] as i64;

        if !(terrain_ids::SURFACE_WATER_FIRST..=terrain_ids::CHANNEL_LAST).contains(&tile) || flags[index] as i64 & flag_bits::WATER == 0 {
            continue;
        }

        let x = index as i64 / map_edge;
        let y = index as i64 % map_edge;
        let height = terrain::land_altitude(altitude, index as i64);

        for (dx, dy) in [(0, -1), (1, 0), (0, 1), (-1, 0)] {
            let (near_x, near_y) = (x + dx, y + dy);

            if near_x >= 0
                && near_x < map_edge
                && near_y >= 0
                && near_y < map_edge
                && terrain::land_altitude(altitude, near_x * map_edge + near_y) > height
            {
                terrain[index] = terrain_ids::WATERFALL as u8;
                break;
            }
        }
    }

    for (chunk, original) in [
        &mut city.altm,
        &mut city.xbld,
        &mut city.xter,
        &mut city.xzon,
        &mut city.xbit,
        &mut city.misc,
    ]
    .into_iter()
    .zip(&originals)
    {
        chunk.commit_if_changed(original);
    }
}

fn make_stream(maps: &mut Maps, start: Vec2i, length: i64, random: &mut SimRandom) {
    let map_edge = maps.map_edge;
    let mut point = start;
    let mut direction = 1;
    make_water(maps, point);

    for _ in 0..length {
        let index = point.x * map_edge + point.y;
        let mut altitude_limit = terrain::land_altitude(maps.altitude, index);

        if maps.terrain[index as usize] as i64 == terrain_ids::WATERFALL {
            altitude_limit += 1;
        }

        let mut accepted = None;

        for (attempt, turn) in STREAM_TURN_ORDER.iter().enumerate() {
            let candidate_direction = ((turn + direction) & 3) as usize;
            let candidate = Vec2i::new(
                point.x + STREAM_X_OFFSETS[candidate_direction],
                point.y + STREAM_Y_OFFSETS[candidate_direction],
            );

            if candidate.x < 0 || candidate.x >= map_edge || candidate.y < 0 || candidate.y >= map_edge {
                return;
            }

            let candidate_index = candidate.x * map_edge + candidate.y;
            let candidate_altitude = terrain::land_altitude(maps.altitude, candidate_index);
            let candidate_terrain = maps.terrain[candidate_index as usize] as i64;

            if candidate_altitude > altitude_limit {
                continue;
            }

            if (terrain_ids::DEEP_WATER_FIRST..terrain_ids::SURFACE_WATER_FIRST).contains(&candidate_terrain) {
                return;
            }

            if candidate_altitude < altitude_limit || candidate_terrain == terrain_ids::FLAT {
                accepted = Some((attempt, candidate));
                break;
            }
        }

        let Some((attempt, next_point)) = accepted else {
            return;
        };

        point = next_point;
        make_water(maps, point);
        direction += STREAM_TURN_ORDER[attempt];

        if random.next_u15() % 3 != 0 {
            direction = (direction + random.next_u15() * 2 + 1) & 3;
        }
    }
}

fn make_water(maps: &mut Maps, point: Vec2i) {
    let index = (point.x * maps.map_edge + point.y) as usize;
    let current = maps.terrain[index] as i64;

    if current == terrain_ids::FORBIDDEN_COAST || current == terrain_ids::WATERFALL {
        return;
    }

    if maps.flags[index] as i64 & flag_bits::WATER != 0 {
        let shape = terrain::water_shape(maps.flags, point.x, point.y, maps.map_edge);
        let (value, early_return) = terrain::water_transition(current, shape);

        if !early_return {
            maps.terrain[index] = value as u8;
        }

        return;
    }

    terrain::place_water(maps, point);
}

fn recount_buildings(buildings: &[u8], misc: &mut [u8]) {
    let mut counts = [0i64; tiles::COUNT as usize];

    for &building in buildings {
        counts[building as usize] += 1;
    }

    for (building_id, count) in counts.iter().enumerate() {
        write_u32_be(misc, misc_layout::TILE_COUNTS + building_id as i64 * 4, *count);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn recursive_grade(heights: &mut [i32], x: usize, y: usize, edge: usize) {
        let index = x * edge + y;
        let mut current = heights[index];

        if !((y > 0 && heights[index - 1] + 1 < current)
            || (x + 1 < edge && heights[index + edge] + 1 < current)
            || (y + 1 < edge && heights[index + 1] + 1 < current)
            || (x > 0 && heights[index - edge] + 1 < current))
        {
            return;
        }

        current -= 1;
        heights[index] = current;

        if y > 0 && current < heights[index - 1] {
            recursive_grade(heights, x, y - 1, edge);
        }

        if x + 1 < edge && current < heights[index + edge] {
            recursive_grade(heights, x + 1, y, edge);
        }

        if y + 1 < edge && current < heights[index + 1] {
            recursive_grade(heights, x, y + 1, edge);
        }

        if x > 0 && current < heights[index - edge] {
            recursive_grade(heights, x - 1, y, edge);
        }
    }

    fn test_heights(edge: usize, seed: i64) -> Vec<i32> {
        let mut random = SimRandom::new(seed);

        (0..edge * edge).map(|_| (random.next_u15() % 24) as i32).collect()
    }

    #[test]
    fn grade_matches_the_recursive_order() {
        for seed in 1..6 {
            let edge = 40;
            let mut expected = test_heights(edge, seed);
            let mut actual = expected.clone();

            for x in 0..edge {
                for y in 0..edge {
                    recursive_grade(&mut expected, x, y, edge);
                }
            }

            grade_heights(&mut actual, edge);

            assert_eq!(actual, expected);
        }
    }

    #[test]
    fn graded_layout_has_no_steep_or_saddle_tiles() {
        let edge = 64;
        let mut heights = test_heights(edge, 9);

        grade_heights(&mut heights, edge);
        grade_layout(&mut heights, edge);
        fill_unsupported_slopes(&mut heights, edge);

        for x in 0..edge as i64 {
            for y in 0..edge as i64 {
                let height = heights[(x * edge as i64 + y) as usize];

                for offset in NEIGHBOR_OFFSETS {
                    let (near_x, near_y) = (x + offset.x, y + offset.y);

                    if near_x >= 0 && near_x < edge as i64 && near_y >= 0 && near_y < edge as i64 {
                        assert!((heights[(near_x * edge as i64 + near_y) as usize] - height).abs() <= 1);
                    }
                }
            }
        }
    }

    #[test]
    fn enlarged_landform_keeps_corners_and_coast() {
        let mut source = vec![0; LANDFORM_EDGE * LANDFORM_EDGE];
        let mut coast = vec![0u8; LANDFORM_EDGE * LANDFORM_EDGE];
        source[LANDFORM_EDGE * LANDFORM_EDGE - 1] = 9;
        coast[LANDFORM_EDGE * LANDFORM_EDGE - 1] = 1;
        let mut flags = vec![0u8; 256 * 256];

        let heights = enlarge_landform(&source, &coast, &mut flags, 256);

        assert_eq!(heights[256 * 256 - 1], 9);
        assert_eq!(flags[256 * 256 - 1], 1);
        assert_eq!(heights[0], 0);
    }

    #[test]
    fn ocean_salt_stays_with_connected_water() {
        let edge = 8;
        let salt = flag_bits::SALT_WATER as u8;
        let water = flag_bits::WATER as u8;
        let mut flags = vec![0u8; edge * edge];
        flags[7 * edge + 7] = salt | water;
        flags[6 * edge + 7] = water;
        flags[2 * edge + 2] = salt;

        finish_ocean(&mut flags, edge);

        assert_eq!(flags[6 * edge + 7], salt | water);
        assert_eq!(flags[2 * edge + 2], 0);
    }

    #[test]
    fn recount_writes_every_building_count() {
        let mut misc = vec![0xffu8; misc_layout::SIZE as usize];
        let mut buildings = vec![0u8; 16384];
        buildings[..3].fill(tiles::TREE_FIRST as u8);

        recount_buildings(&buildings, &mut misc);

        assert_eq!(
            crate::sim::bytes::read_u32_be(&misc, misc_layout::TILE_COUNTS + tiles::TREE_FIRST * 4),
            3
        );
        assert_eq!(crate::sim::bytes::read_u32_be(&misc, misc_layout::TILE_COUNTS), 16381);
        assert_eq!(crate::sim::bytes::read_u32_be(&misc, misc_layout::TILE_COUNTS + 0xff * 4), 0);
    }
}
