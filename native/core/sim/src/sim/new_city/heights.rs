//! The heights of the original 128 by 128 landform: seeded hills, midpoint
//! interpolation, the classic ocean and river, smoothing, and scaling. Index
//! `x * 128 + y`. This is NewTerrainHeights of the scripts.

use crate::sim::ids::sc2tile_flags as flags;
use crate::sim::random::{GameLcgRandom, SimRandom};

/// The edge of the landform.
pub const EDGE: i64 = 128;

/// The steps and midpoint masks of the interpolation passes.
pub const INTERPOLATION_PASSES: [(i64, i64); 4] = [(8, 15), (4, 7), (2, 3), (1, 1)];

/// The spacing of the seeded hills.
const HILL_SPACING: i64 = 16;

const OCEAN_MINIMUM_WIDTH: i64 = 10;
const OCEAN_WIDTH_RANGE: i64 = 10;
const OCEAN_TARGET_RANGE: i64 = 30;
const RIVER_HALF_WIDTH: i64 = 3;
const RIVER_BANK: i64 = 4;
const RIVER_MARGIN: i64 = 5;

fn index(x: i64, y: i64) -> usize {
    (x * EDGE + y) as usize
}

pub fn seed_hills(heights: &mut [i32], maximum: i64, random: &mut SimRandom) {
    for x in (0..EDGE).step_by(HILL_SPACING as usize) {
        for y in (0..EDGE).step_by(HILL_SPACING as usize) {
            heights[index(x, y)] = (random.next_u15() % maximum + 1) as i32;
        }
    }
}

pub fn interpolate(heights: &mut [i32], step: i64, mask: i64, edge_height: i64, has_ocean: bool, random: &mut SimRandom) {
    let neighbor = |heights: &[i32], x: i64, y: i64| -> i64 {
        if x < 0 || !(0..EDGE).contains(&y) {
            return edge_height;
        }

        if x >= EDGE {
            return if has_ocean { 0 } else { edge_height };
        }

        i64::from(heights[index(x, y)])
    };

    for x in (0..EDGE).step_by(step as usize) {
        let x_midpoint = mask & x != 0;

        for y in (0..EDGE).step_by(step as usize) {
            let y_midpoint = mask & y != 0;

            if !x_midpoint && !y_midpoint {
                continue;
            }

            let variation = random.next_u15() % step;

            let value = if x_midpoint && y_midpoint {
                (neighbor(heights, x - step, y + step)
                    + neighbor(heights, x + step, y + step)
                    + neighbor(heights, x - step, y - step)
                    + neighbor(heights, x + step, y - step))
                    >> 2
            } else if y_midpoint {
                (neighbor(heights, x, y + step) + neighbor(heights, x, y - step)) >> 1
            } else {
                (neighbor(heights, x - step, y) + neighbor(heights, x + step, y)) >> 1
            };

            heights[index(x, y)] = (value + variation).max(1) as i32;
        }
    }
}

pub fn carve_ocean(heights: &mut [i32], coast_flags: &mut [u8], water_level: i64, random: &mut GameLcgRandom) {
    let mut width = random.next_mod(OCEAN_WIDTH_RANGE) + OCEAN_MINIMUM_WIDTH;

    for y in 0..EDGE {
        let bank_x = EDGE - width;
        heights[index(bank_x, y)] = (water_level - 2) as i32;

        for x in bank_x + 1..EDGE {
            heights[index(x, y)] = (water_level - 3) as i32;
            coast_flags[index(x, y)] |= flags::SALT_WATER as u8;
        }

        let target = random.next_mod(OCEAN_TARGET_RANGE);

        if width < target {
            width += 1;
        } else if target < width {
            width -= 1;
        }
    }
}

pub fn carve_river(heights: &mut [i32], water_level: i64, random: &mut GameLcgRandom) {
    let mut center = EDGE / 2;
    let mut bend = random.next_mod(3) - 1;

    for y in (0..EDGE).rev() {
        for x in center - RIVER_HALF_WIDTH..=center + RIVER_HALF_WIDTH {
            heights[index(x, y)] = (water_level - 3) as i32;
        }

        heights[index(center - RIVER_BANK, y)] = (water_level - 2) as i32;
        heights[index(center + RIVER_BANK, y)] = (water_level - 2) as i32;

        if random.next_mod(8) == 0 {
            bend = random.next_mod(3) - 1;
        }

        center += bend + random.next_mod(3) - 1;
        center = center.clamp(RIVER_MARGIN, EDGE - 6);
    }
}

pub fn smooth(heights: &mut [i32]) {
    let source = heights.to_vec();
    let edge = EDGE as usize;

    for x in 0..edge {
        for y in 0..edge {
            let at = x * edge + y;
            let center = source[at];
            let north = if y > 0 { source[at - 1] } else { center };
            let east = if x < edge - 1 { source[at + edge] } else { center };
            let south = if y < edge - 1 { source[at + 1] } else { center };
            let west = if x > 0 { source[at - edge] } else { center };
            heights[at] = (((north + east + south + west) >> 2) + center) >> 1;
        }
    }
}

pub fn scale(heights: &mut [i32]) {
    for height in heights.iter_mut() {
        let scaled = (*height + 3) >> 1;
        let shifted = scaled - 4;

        *height = if shifted >= 4 {
            shifted
        } else if shifted >= 0 {
            4
        } else {
            scaled
        };
    }
}
