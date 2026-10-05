//! The tiles that a road, rail, power line, subway, or pipe may enter, as
//! NetworkRules and NetworkTerrainRules.

use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2altitude_layout as altitude_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::ids::underground_tile_ids as under;
use crate::sim::tools::commands::in_bounds;
use crate::sim::tools::network::{MODE_PIPE, MODE_POWER, MODE_RAIL, MODE_ROAD, MODE_SUBWAY, rail_connects, road_connects};
use crate::sim::tools::underground::underground_connects;

/// One row per terrain shape, one column per direction (N, E, S, W): true
/// where a network may not enter the tile.
const ENTRY_BLOCKS_DIRECTION: [bool; 64] = [
    false, false, false, false, // FLAT
    true, false, true, false, // SLOPE_TOP_LEFT
    false, true, false, true, // SLOPE_TOP_RIGHT
    true, false, true, false, // SLOPE_BOTTOM_RIGHT
    false, true, false, true, // SLOPE_BOTTOM_LEFT
    false, false, false, false, // RAISED_EXCEPT_BOTTOM
    false, false, false, false, // RAISED_EXCEPT_LEFT
    false, false, false, false, // RAISED_EXCEPT_TOP
    false, false, false, false, // RAISED_EXCEPT_RIGHT
    false, false, false, false, // CORNER_TOP
    false, false, false, false, // CORNER_RIGHT
    false, false, false, false, // CORNER_BOTTOM
    false, false, false, false, // CORNER_LEFT
    false, false, false, false, // RAISED
    true, false, true, false, // UNUSED_0E
    true, false, true, false, // UNUSED_0F
];

/// The raised part of a shape adds one level to the height of the step.
const HEIGHT_ADJUSTMENTS: [i64; 16] = [0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0, 0];

/// A tunnel at these levels blocks a subway or pipe.
const TUNNEL_BLOCKS_UNDERGROUND: [i64; 2] = [1, 2];

/// The city maps that a route reads.
pub struct RouteMaps<'a> {
    pub buildings: &'a [u8],
    pub terrain: &'a [u8],
    pub zones: &'a [u8],
    pub underground: &'a [u8],
    pub flags: &'a [u8],
    pub altitude: &'a [u8],
    pub map_edge: i64,
}

/// NetworkTerrainRules.allows_entry.
pub fn allows_entry(terrain_id: i64, direction: i64) -> bool {
    terrain_id >= terrain_ids::CHANNEL_FIRST || !ENTRY_BLOCKS_DIRECTION[((terrain_id & terrain_ids::SHAPE_MASK) * 4 + direction) as usize]
}

/// NetworkTerrainRules.allows_height_step, from the executable at 0x00448f50.
/// Going downhill is not uphill with a minus sign.
pub fn allows_height_step(
    current_terrain: i64,
    current_height: i64,
    next_terrain: i64,
    next_height: i64,
    keep_straight: bool,
    rail: bool,
) -> bool {
    if keep_straight {
        return !rail || next_terrain == terrain_ids::FLAT || next_height == current_height;
    }

    let effective = current_height + HEIGHT_ADJUSTMENTS[(current_terrain & terrain_ids::SHAPE_MASK) as usize];
    let difference = next_height - effective;

    if HEIGHT_ADJUSTMENTS[(next_terrain & terrain_ids::SHAPE_MASK) as usize] != 0 && (difference == 0 || difference == -2) {
        return false;
    }

    next_terrain != terrain_ids::FLAT || difference != -1
}

/// NetworkRules._surface_fixed_axis: existing mixed crossings cannot turn.
/// Returns -1 when the tile has no fixed axis for `mode`.
pub fn surface_fixed_axis(tile: i64, mode: i64) -> i64 {
    use tiles::*;

    match mode {
        MODE_ROAD => match tile {
            ROAD_POWER_CROSSING_1 | ROAD_RAIL_CROSSING_1 | HIGHWAY_ROAD_CROSSING_2 => 0,
            ROAD_POWER_CROSSING_2 | ROAD_RAIL_CROSSING_2 | HIGHWAY_ROAD_CROSSING_1 => 1,
            _ => -1,
        },
        MODE_RAIL => match tile {
            ROAD_RAIL_CROSSING_2 | RAIL_POWER_CROSSING_1 | HIGHWAY_RAIL_CROSSING_2 => 0,
            ROAD_RAIL_CROSSING_1 | RAIL_POWER_CROSSING_2 | HIGHWAY_RAIL_CROSSING_1 => 1,
            _ => -1,
        },
        _ => match tile {
            ROAD_POWER_CROSSING_2 | RAIL_POWER_CROSSING_2 | HIGHWAY_POWER_CROSSING_2 => 0,
            ROAD_POWER_CROSSING_1 | RAIL_POWER_CROSSING_1 | HIGHWAY_POWER_CROSSING_1 => 1,
            _ => -1,
        },
    }
}

/// NetworkRules._reuses_surface: the route passes this tile without building.
pub fn reuses_surface(tile: i64, mode: i64) -> bool {
    match mode {
        MODE_ROAD => road_connects(tile),
        MODE_RAIL => rail_connects(tile),
        MODE_POWER => {
            (tiles::POWER_LINE_FIRST..=tiles::POWER_LINE_LAST).contains(&tile)
                || (tiles::ROAD_POWER_CROSSING_1..=tiles::ROAD_POWER_CROSSING_2).contains(&tile)
                || (tiles::RAIL_POWER_CROSSING_1..=tiles::RAIL_POWER_CROSSING_2).contains(&tile)
                || (tiles::HIGHWAY_POWER_CROSSING_1..=tiles::HIGHWAY_POWER_CROSSING_2).contains(&tile)
        }
        _ => false,
    }
}

/// NetworkRules._reuses_underground.
pub fn reuses_underground(tile: i64, mode: i64) -> bool {
    (mode == MODE_PIPE || mode == MODE_SUBWAY) && underground_connects(tile, mode == MODE_PIPE)
}

/// True for a straight network tile that runs across `direction`.
pub fn crosses_straight(tile: i64, direction: i64) -> bool {
    let directional = tile + (direction & 1);

    directional == tiles::POWER_LINE_STRAIGHT_2
        || directional == tiles::ROAD_STRAIGHT_2
        || directional == tiles::RAIL_STRAIGHT_2
        || directional == tiles::HIGHWAY_STRAIGHT_2
}

/// NetworkRules._tile_is_eligible: the route may enter `point` going `direction`.
pub fn tile_is_eligible(maps: &RouteMaps, point: Vec2i, mode: i64, direction: i64) -> bool {
    let edge = maps.map_edge;

    if !in_bounds(point, edge) {
        return false;
    }

    let index = (point.x * edge + point.y) as usize;

    if maps.zones[index] as i64 & zone::TYPE_MASK == zone::MILITARY {
        return false;
    }

    let terrain_id = maps.terrain[index] as i64;

    if !allows_entry(terrain_id, direction) {
        return false;
    }

    if mode == MODE_SUBWAY || mode == MODE_PIPE {
        let word = ((maps.altitude[index * 2] as i64) << 8) | maps.altitude[index * 2 + 1] as i64;
        let tunnel = (word & altitude_layout::TUNNEL_MASK) >> altitude_layout::TUNNEL_SHIFT;

        if TUNNEL_BLOCKS_UNDERGROUND.contains(&tunnel) {
            return false;
        }

        let under_tile = maps.underground[index] as i64;

        if reuses_underground(under_tile, mode) {
            // A pipe and subway crossing keeps each network on its own axis.
            if under_tile == under::PIPE_TB_SUBWAY_LR || under_tile == under::PIPE_LR_SUBWAY_TB {
                let mut axis = under_tile - under::PIPE_TB_SUBWAY_LR;

                if mode == MODE_PIPE {
                    axis = 1 - axis;
                }

                return (direction & 1) == axis;
            }

            return true;
        }

        if under_tile == under::EMPTY {
            return true;
        }

        return under_tile + (direction & 1) == under::PIPE_TB;
    }

    if maps.flags[index] as i64 & flag_bits::WATER != 0 && terrain_id < terrain_ids::CHANNEL_FIRST {
        return false;
    }

    if (terrain_ids::DEEP_WATER_FIRST..terrain_ids::SHORE_FIRST).contains(&terrain_id) {
        return false;
    }

    let building = maps.buildings[index] as i64;

    if reuses_surface(building, mode) {
        let axis = surface_fixed_axis(building, mode);

        return axis < 0 || (direction & 1) == axis;
    }

    if building == tiles::RADIOACTIVE_WASTE || building == tiles::SMALL_PARK || building > tiles::HIGHWAY_POWER_CROSSING_2 {
        return false;
    }

    if building <= tiles::TREE_LAST {
        return true;
    }

    crosses_straight(building, direction)
}
