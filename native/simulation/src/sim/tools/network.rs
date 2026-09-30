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
#[cfg(test)]
use crate::sim::ids::underground_tile_ids as under;
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::tools::underground::retile_underground;

    const EDGE: i64 = 16;
    const POINT: Vec2i = Vec2i::new(8, 8);

    /// The road tile of each north, east, south, and west connection mask.
    const ROAD_TILES: [i64; 16] = [
        0x1d, 0x1d, 0x1e, 0x23, 0x1d, 0x1d, 0x24, 0x28, 0x1e, 0x26, 0x1e, 0x27, 0x25, 0x2a, 0x29, 0x2b,
    ];

    fn empty() -> Vec<u8> {
        vec![0; (EDGE * EDGE) as usize]
    }

    fn index(point: Vec2i) -> usize {
        (point.x * EDGE + point.y) as usize
    }

    fn neighbors(point: Vec2i, mask: i64) -> impl Iterator<Item = Vec2i> {
        (0..4)
            .filter(move |direction| mask & (1 << direction) != 0)
            .map(move |direction| point + DIRECTIONS[direction as usize])
            .filter(|near| near.x >= 0 && near.y >= 0 && near.x < EDGE && near.y < EDGE)
    }

    /// The surface tile at `point` with the neighbors of `mask`, on `slope`.
    fn surface(mask: i64, point: Vec2i, mode: i64, slope: u8, connection: bool) -> i64 {
        let base = [tiles::ROAD_STRAIGHT_1, tiles::RAIL_STRAIGHT_1, tiles::POWER_LINE_STRAIGHT_1][mode as usize];
        let (mut buildings, mut terrain, zones, mut flags, mut overlays) = (empty(), empty(), empty(), empty(), empty());
        let mut misc = vec![0u8; 4800];
        let center = index(point);
        buildings[center] = base as u8;
        terrain[center] = slope;
        overlays[center] = if connection {
            sc2overlay_layout::CONNECTION_MARKER as u8
        } else {
            0
        };
        write_u32_be(&mut misc, misc_layout::TILE_COUNTS + base * 4, 1);

        for near in neighbors(point, mask) {
            buildings[index(near)] = base as u8;
            flags[index(near)] = flag_bits::POWERABLE as u8;
        }

        retile_surface(&mut buildings, &terrain, &zones, &flags, &mut misc, point, mode, &overlays, EDGE);
        buildings[center] as i64
    }

    fn underground(mask: i64, point: Vec2i, pipes: bool, slope: u8) -> i64 {
        let base = if pipes { under::PIPE_FIRST } else { under::SUBWAY_FIRST };
        let (mut layer, mut terrain) = (empty(), empty());
        layer[index(point)] = base as u8;
        terrain[index(point)] = slope;

        for near in neighbors(point, mask) {
            layer[index(near)] = base as u8;
        }

        retile_underground(&mut layer, &terrain, point, pipes, EDGE);
        layer[index(point)] as i64
    }

    /// Every connection mask selects the shared shape of each network.
    #[test]
    fn shapes_follow_the_connection_mask() {
        for mask in 0..16 {
            let road = ROAD_TILES[mask as usize];
            assert_eq!(surface(mask, POINT, MODE_ROAD, 0, false), road);
            assert_eq!(surface(mask, POINT, MODE_RAIL, 0, false), road + 15);
            assert_eq!(surface(mask, POINT, MODE_POWER, 0, false), road - 15);
            assert_eq!(underground(mask, POINT, false, 0), road - 28);
            assert_eq!(underground(mask, POINT, true, 0), if mask == 0 { 30 } else { road - 13 });
        }

        // A slope has its own shape even where the mask asks for a junction.
        for slope in 1..5u8 {
            assert_eq!(surface(15, POINT, MODE_ROAD, slope, false), 30 + slope as i64);
            assert_eq!(underground(15, POINT, false, slope), 2 + slope as i64);
            assert_eq!(underground(0, POINT, true, slope), 17 + slope as i64);
        }
    }

    /// Neighbors outside the map do not connect, except through a connection label.
    #[test]
    fn map_edges_connect_only_through_labels() {
        let edges = [
            Vec2i::new(0, 8),
            Vec2i::new(8, 0),
            Vec2i::new(15, 8),
            Vec2i::new(8, 15),
            Vec2i::new(0, 0),
        ];
        let roads = [40, 41, 42, 39, 36];

        for (point, road) in edges.into_iter().zip(roads) {
            assert_eq!(surface(15, point, MODE_ROAD, 0, false), road);
            assert_eq!(underground(15, point, false, 0), road - 28);
            assert_eq!(surface(15, point, MODE_ROAD, 0, true), tiles::ROAD_CROSSROADS);
        }
    }

    /// A subway connects to an entrance, not to a pipe, and terrain can block it.
    #[test]
    fn subway_neighbors_follow_their_rules() {
        let (mut layer, mut terrain) = (empty(), empty());
        let (center, east, south) = (index(POINT), index(POINT + Vec2i::new(1, 0)), index(POINT + Vec2i::new(0, 1)));
        layer[center] = under::SUBWAY_FIRST as u8;
        layer[east] = under::SUBWAY_ENTRANCE as u8;
        layer[south] = under::PIPE_FIRST as u8;
        retile_underground(&mut layer, &terrain, POINT, false, EDGE);
        assert_eq!(layer[center], 2);

        layer[center] = under::SUBWAY_FIRST as u8;
        terrain[east] = 2;
        retile_underground(&mut layer, &terrain, POINT, false, EDGE);
        assert_eq!(layer[center], 1);

        layer[center] = under::SUBWAY_ENTRANCE as u8;
        retile_underground(&mut layer, &terrain, POINT, false, EDGE);
        assert_eq!(layer[center] as i64, under::SUBWAY_ENTRANCE);
    }
}
