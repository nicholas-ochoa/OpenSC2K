//! Surface network state and retiling, as NetworkState, NetworkTiles,
//! NetworkRules, and NetworkTerrainRules.

use crate::sim::bytes::{read_u32_be, write_u32_be};
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2overlay_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::network::SHAPE_OFFSET_BY_CONNECTION_MASK as NETWORK_SHAPES;
use crate::sim::overlay;

pub const MODE_ROAD: i64 = 0;
pub const MODE_RAIL: i64 = 1;
pub const MODE_POWER: i64 = 2;
pub const MODE_SUBWAY: i64 = 3;
pub const MODE_PIPE: i64 = 4;
pub const DIRECTIONS: [Vec2i; 4] = [Vec2i::new(0, -1), Vec2i::new(1, 0), Vec2i::new(0, 1), Vec2i::new(-1, 0)];
pub const TERRAIN_REQUIRES_GRADING: [bool; 16] = [
    false, false, false, false, false, true, true, true, true, true, true, true, true, false, false, false,
];
pub const TERRAIN_IS_NETWORK_SLOPE: [bool; 16] = [
    false, true, true, true, true, false, false, false, false, true, true, true, true, false, false, false,
];
pub const NETWORK_SLOPE_SHAPES: [i64; 5] = [0, 2, 3, 4, 5];

/// One row per terrain shape, one column per direction (N, E, S, W).
const GRADED_TERRAIN: [i64; 64] = {
    use terrain_ids::*;
    [
        FLAT,
        FLAT,
        SLOPE_TOP_LEFT,
        FLAT, // FLAT
        FLAT,
        FLAT,
        FLAT,
        FLAT, // SLOPE_TOP_LEFT
        FLAT,
        FLAT,
        SLOPE_TOP_LEFT,
        SLOPE_TOP_LEFT, // SLOPE_TOP_RIGHT
        FLAT,
        FLAT,
        SLOPE_TOP_LEFT,
        SLOPE_TOP_LEFT, // SLOPE_BOTTOM_RIGHT
        FLAT,
        FLAT,
        FLAT,
        FLAT, // SLOPE_BOTTOM_LEFT
        FLAT,
        FLAT,
        FLAT,
        FLAT, // RAISED_EXCEPT_BOTTOM
        FLAT,
        FLAT,
        FLAT,
        FLAT, // RAISED_EXCEPT_LEFT
        FLAT,
        FLAT,
        FLAT,
        FLAT, // RAISED_EXCEPT_TOP
        FLAT,
        FLAT,
        FLAT,
        FLAT, // RAISED_EXCEPT_RIGHT
        SLOPE_TOP_RIGHT,
        SLOPE_TOP_LEFT,
        SLOPE_TOP_RIGHT,
        SLOPE_TOP_LEFT, // CORNER_TOP
        SLOPE_TOP_RIGHT,
        SLOPE_BOTTOM_RIGHT,
        SLOPE_TOP_RIGHT,
        SLOPE_BOTTOM_RIGHT, // CORNER_RIGHT
        SLOPE_BOTTOM_LEFT,
        SLOPE_BOTTOM_RIGHT,
        SLOPE_BOTTOM_LEFT,
        SLOPE_BOTTOM_RIGHT, // CORNER_BOTTOM
        SLOPE_BOTTOM_LEFT,
        SLOPE_TOP_LEFT,
        SLOPE_BOTTOM_LEFT,
        SLOPE_TOP_LEFT, // CORNER_LEFT
        FLAT,
        FLAT,
        SLOPE_TOP_LEFT,
        RAISED_EXCEPT_LEFT, // RAISED
        FLAT,
        FLAT,
        RAISED_EXCEPT_TOP,
        CORNER_BOTTOM, // UNUSED_0E
        SLOPE_TOP_LEFT,
        CORNER_TOP,
        SLOPE_TOP_LEFT,
        CORNER_RIGHT, // UNUSED_0F
    ]
};

/// Sc2MilitaryLayout.TILE_COUNT_INDEX. Other tiles use slot 0.
pub fn military_count_index(tile: i64) -> i64 {
    match tile {
        tiles::RUNWAY => 1,
        tiles::RUNWAY_CROSSING => 2,
        tiles::PARKING_LOT_2 => 3,
        tiles::CARGO_YARD => 4,
        tiles::RADAR => 5,
        tiles::SEAPORT_WAREHOUSE => 6,
        tiles::AIRPORT_BUILDING_1 => 7,
        tiles::AIRPORT_BUILDING_2 => 8,
        tiles::TOP_SECRET => 9,
        tiles::CRANE => 10,
        tiles::CONTROL_TOWER_2 => 11,
        tiles::FIGHTER_JET => 12,
        tiles::HANGAR_1 => 13,
        tiles::HANGAR_2 => 14,
        tiles::MISSILE_SILO => 15,
        _ => 0,
    }
}

/// The running count mask. 128 tile maps keep 16-bit counts.
#[inline]
pub fn count_mask(cells: usize) -> i64 {
    if cells == 16384 { 0xffff } else { 0xffff_ffff }
}

/// NetworkState.replace_building: move one tile count and store the tile.
pub fn replace_building(buildings: &mut [u8], zones: &[u8], misc: &mut [u8], index: i64, new_tile: i64) {
    let old_tile = buildings[index as usize] as i64;

    if old_tile == new_tile {
        return;
    }

    let zone_type = zones[index as usize] as i64 & zone::TYPE_MASK;
    let mut old_offset = misc_layout::TILE_COUNTS + old_tile * 4;
    let mut new_offset = misc_layout::TILE_COUNTS + new_tile * 4;

    if zone_type == zone::MILITARY {
        old_offset = misc_layout::MILITARY_TILE_COUNTS + military_count_index(old_tile) * 4;
        new_offset = misc_layout::MILITARY_TILE_COUNTS + military_count_index(new_tile) * 4;
    }

    let mask = count_mask(buildings.len());
    let old_count = read_u32_be(misc, old_offset);
    write_u32_be(misc, old_offset, (old_count - 1) & mask);
    let new_count = read_u32_be(misc, new_offset);
    write_u32_be(misc, new_offset, (new_count + 1) & mask);
    buildings[index as usize] = new_tile as u8;
}

pub fn road_connects(tile: i64) -> bool {
    (tiles::FIRST_ROAD..=tiles::LAST_ROAD).contains(&tile)
        || (tiles::TUNNEL_FIRST..=tiles::ROAD_RAIL_CROSSING_2).contains(&tile)
        || tile == tiles::HIGHWAY_ROAD_CROSSING_1
        || tile == tiles::HIGHWAY_ROAD_CROSSING_2
        || (tiles::ONRAMP_FIRST..=tiles::ONRAMP_LAST).contains(&tile)
}

pub fn rail_connects(tile: i64) -> bool {
    (tiles::RAIL_FIRST..=tiles::RAIL_LAST).contains(&tile)
        || (tiles::ROAD_RAIL_CROSSING_1..=tiles::RAIL_POWER_CROSSING_2).contains(&tile)
        || tile == tiles::HIGHWAY_RAIL_CROSSING_1
        || tile == tiles::HIGHWAY_RAIL_CROSSING_2
        || (tiles::RAIL_SUBWAY_FIRST..=tiles::RAIL_SUBWAY_LAST).contains(&tile)
}

/// NetworkTerrainRules.allows_connection. The executable tables at 0x004e7c70
/// and 0x004e7cb8.
pub fn allows_connection(terrain_id: i64, direction: i64) -> bool {
    use terrain_ids::*;

    if !(FLAT..=UNUSED_47).contains(&terrain_id) {
        return false;
    }

    let vertical = matches!(
        terrain_id,
        SLOPE_TOP_LEFT
            | SLOPE_BOTTOM_RIGHT
            | UNUSED_0F
            | DEEP_WATER_SLOPE_TOP_LEFT
            | DEEP_WATER_SLOPE_BOTTOM_RIGHT
            | UNUSED_1F
            | SHORE_SLOPE_TOP_LEFT
            | SHORE_SLOPE_BOTTOM_RIGHT
            | UNUSED_2F
            | CHANNEL_W
            | CHANNEL_N
            | UNUSED_46
            | UNUSED_47
    );
    let horizontal = matches!(
        terrain_id,
        SLOPE_TOP_RIGHT
            | SLOPE_BOTTOM_LEFT
            | UNUSED_0F
            | DEEP_WATER_SLOPE_TOP_RIGHT
            | DEEP_WATER_SLOPE_BOTTOM_LEFT
            | UNUSED_1F
            | SHORE_SLOPE_TOP_RIGHT
            | SHORE_SLOPE_BOTTOM_LEFT
            | UNUSED_2F
            | CHANNEL_W
            | CHANNEL_N
            | UNUSED_46
            | UNUSED_47
    );

    if direction & 1 == 0 { !vertical } else { !horizontal }
}

/// NetworkTiles._grade_surface_terrain.
pub fn grade_surface_terrain(terrain: &mut [u8], flags: &mut [u8], point: Vec2i, direction: i64, map_edge: i64) {
    let index = (point.x * map_edge + point.y) as usize;
    let terrain_id = terrain[index] as i64;

    if terrain_id >= terrain_ids::SURFACE_WATER_FIRST {
        return;
    }

    let shape = (terrain_id & terrain_ids::SHAPE_MASK) as usize;

    if !TERRAIN_REQUIRES_GRADING[shape] {
        return;
    }

    if TERRAIN_IS_NETWORK_SLOPE[shape] {
        terrain[index] = ((terrain_id & terrain_ids::GROUP_MASK) | GRADED_TERRAIN[shape * 4 + direction as usize]) as u8;

        return;
    }

    terrain[index] = if terrain_id < terrain_ids::DEEP_WATER_FIRST {
        terrain_ids::RAISED
    } else {
        terrain_ids::DEEP_WATER_RAISED
    } as u8;
    flags[index] = (flags[index] as i64 & !flag_bits::WATER) as u8;
}

/// NetworkTiles.retile_surface. `text_overlays` may be empty.
#[allow(clippy::too_many_arguments)]
pub fn retile_surface(
    buildings: &mut [u8],
    terrain: &[u8],
    zones: &[u8],
    flags: &[u8],
    misc: &mut [u8],
    point: Vec2i,
    mode: i64,
    text_overlays: &[u8],
    map_edge: i64,
) {
    let index = point.x * map_edge + point.y;
    let current = buildings[index as usize] as i64;
    let base;

    if mode == MODE_ROAD {
        if !(tiles::ROAD_STRAIGHT_1..=tiles::ROAD_CROSSROADS).contains(&current) {
            return;
        }

        base = tiles::FIRST_ROAD;
    } else if mode == MODE_RAIL {
        if !(tiles::RAIL_STRAIGHT_1..=tiles::RAIL_SLOPE_8).contains(&current) {
            return;
        }

        base = tiles::RAIL_FIRST;
    } else {
        if !(tiles::POWER_LINE_STRAIGHT_1..=tiles::POWER_LINE_CROSSROADS).contains(&current) {
            return;
        }

        base = tiles::POWER_LINE_FIRST;
    }

    let terrain_id = terrain[index as usize] as i64;

    if terrain_id < terrain_ids::SURFACE_WATER_FIRST {
        let terrain_shape = terrain_id & terrain_ids::SHAPE_MASK;

        if TERRAIN_IS_NETWORK_SLOPE[terrain_shape as usize] && terrain_shape < NETWORK_SLOPE_SHAPES.len() as i64 {
            replace_building(buildings, zones, misc, index, base + NETWORK_SLOPE_SHAPES[terrain_shape as usize]);

            return;
        }
    }

    // Flat rail at the low end of a slope uses the native transition tile.
    if mode == MODE_RAIL && terrain_id == terrain_ids::FLAT {
        const LOW_SIDE: [Vec2i; 4] = [Vec2i::new(1, 0), Vec2i::new(0, 1), Vec2i::new(-1, 0), Vec2i::new(0, -1)];

        for shape in 1..5 {
            let slope = point - LOW_SIDE[shape as usize - 1];

            if slope.x < 0 || slope.y < 0 || slope.x >= map_edge || slope.y >= map_edge {
                continue;
            }

            let slope_index = (slope.x * map_edge + slope.y) as usize;

            if terrain[slope_index] as i64 == shape && buildings[slope_index] as i64 == tiles::RAIL_STRAIGHT_2 + shape {
                replace_building(buildings, zones, misc, index, tiles::RAIL_CROSSROADS + shape);

                return;
            }
        }
    }

    let mut connections = 0;
    let has_connection_label = overlay::count(text_overlays) == map_edge * map_edge
        && overlay::marker_at(text_overlays, index) == sc2overlay_layout::CONNECTION_MARKER;

    for direction in 0..4 {
        let near = point + DIRECTIONS[direction as usize];

        if near.x < 0 || near.x >= map_edge || near.y < 0 || near.y >= map_edge {
            if has_connection_label {
                connections |= 1 << direction;
            }

            continue;
        }

        let near_index = (near.x * map_edge + near.y) as usize;
        let connects = if mode == MODE_POWER {
            flags[near_index] as i64 & flag_bits::POWERABLE != 0
        } else if mode == MODE_ROAD {
            road_connects(buildings[near_index] as i64)
        } else {
            rail_connects(buildings[near_index] as i64)
        };

        if connects && allows_connection(terrain[near_index] as i64, direction) {
            connections |= 1 << direction;
        }
    }

    replace_building(buildings, zones, misc, index, base + NETWORK_SHAPES[connections as usize]);
}

/// NetworkTiles._retile_surface_neighborhood.
#[allow(clippy::too_many_arguments)]
pub fn retile_surface_neighborhood(
    buildings: &mut [u8],
    terrain: &[u8],
    zones: &[u8],
    flags: &[u8],
    misc: &mut [u8],
    point: Vec2i,
    mode: i64,
    text_overlays: &[u8],
    map_edge: i64,
) {
    retile_surface(buildings, terrain, zones, flags, misc, point, mode, text_overlays, map_edge);

    for offset in DIRECTIONS {
        let near = point + offset;

        if near.x >= 0 && near.x < map_edge && near.y >= 0 && near.y < map_edge {
            retile_surface(buildings, terrain, zones, flags, misc, near, mode, text_overlays, map_edge);
        }
    }
}
