//! Terrain and surface water retiling, as TerrainRetile, the LandscapeCommand
//! water shapes, and the DemolishTerrain helpers.

use super::network::{self, replace_building};
use crate::sim::bytes::read_u32_be;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2altitude_layout as altitude_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;

pub const NEIGHBOR_OFFSETS: [Vec2i; 8] = [
    Vec2i::new(0, -1),
    Vec2i::new(1, -1),
    Vec2i::new(1, 0),
    Vec2i::new(1, 1),
    Vec2i::new(0, 1),
    Vec2i::new(-1, 1),
    Vec2i::new(-1, 0),
    Vec2i::new(-1, -1),
];
pub const NEIGHBOR_MASKS: [i64; 8] = [3, 2, 6, 4, 12, 8, 9, 1];
/// Raise an enclosed basin by one level before assigning its XTER tile.
pub const RAISE_BASIN: i64 = 50;
/// Index by the corners that a higher neighbor raises: 1 top, 2 right, 4 bottom, 8 left.
pub const TERRAIN_SHAPES: [i64; 16] = {
    use terrain_ids::*;
    [
        FLAT,
        CORNER_TOP,
        CORNER_RIGHT,
        SLOPE_TOP_RIGHT,
        CORNER_BOTTOM,
        RAISED,
        SLOPE_BOTTOM_RIGHT,
        RAISED_EXCEPT_LEFT,
        CORNER_LEFT,
        SLOPE_TOP_LEFT,
        RAISED,
        RAISED_EXCEPT_BOTTOM,
        SLOPE_BOTTOM_LEFT,
        RAISED_EXCEPT_RIGHT,
        RAISED_EXCEPT_TOP,
        RAISE_BASIN,
    ]
};
pub const CARDINAL_WATER_SHAPES: [i64; 15] = [13, 21, 18, 8, 19, 16, 5, 1, 20, 7, 17, 4, 6, 3, 2];
pub const DIAGONAL_WATER_SHAPES: [i64; 16] = [0, 9, 10, 0, 11, 0, 0, 0, 12, 0, 0, 0, 0, 0, 0, 0];

#[inline]
pub fn land_altitude(altitude: &[u8], index: i64) -> i64 {
    altitude[(index * 2 + 1) as usize] as i64 & altitude_layout::LEVEL_MASK
}

#[inline]
pub fn water_altitude(altitude: &[u8], index: i64) -> i64 {
    let word = ((altitude[(index * 2) as usize] as i64) << 8) | altitude[(index * 2 + 1) as usize] as i64;

    (word >> altitude_layout::WATER_SHIFT) & altitude_layout::LEVEL_MASK
}

/// TerrainEditHeights.set_land_altitude: only the low byte changes.
pub fn set_land_altitude(altitude: &mut [u8], index: i64, value: i64) {
    let offset = (index * 2 + 1) as usize;
    altitude[offset] =
        ((altitude[offset] as i64 & (!altitude_layout::LAND_MASK & 0xff)) | (value & altitude_layout::LEVEL_MASK)) as u8;
}

/// TerrainEditHeights._set_water_altitude.
pub fn set_water_altitude(altitude: &mut [u8], index: i64, value: i64) {
    let offset = (index * 2) as usize;
    let mut word = ((altitude[offset] as i64) << 8) | altitude[offset + 1] as i64;
    word = (word & (!altitude_layout::WATER_MASK & 0xffff))
        | ((value & altitude_layout::LEVEL_MASK) << altitude_layout::WATER_SHIFT);
    altitude[offset] = (word >> 8) as u8;
    altitude[offset + 1] = word as u8;
}

/// DemolishTerrain._clear_tunnel_level.
pub fn clear_tunnel_level(altitude: &mut [u8], index: i64) {
    let offset = (index * 2) as usize;
    let mut word = ((altitude[offset] as i64) << 8) | altitude[offset + 1] as i64;
    word &= !altitude_layout::TUNNEL_MASK & 0xffff;
    altitude[offset] = (word >> 8) as u8;
    altitude[offset + 1] = word as u8;
}

/// The sea level in MISC (WATER_LEVEL).
pub fn sea_level(misc: &[u8]) -> i64 {
    read_u32_be(misc, 0x0e40) & 0x1f
}

/// TerrainRetile.retile_region.
#[allow(clippy::too_many_arguments)]
pub fn retile_region(
    altitude: &mut [u8],
    buildings: &mut [u8],
    terrain: &mut [u8],
    zones: &mut [u8],
    flags: &mut [u8],
    misc: &mut [u8],
    indices: &[i64],
    sea_level: i64,
    map_edge: i64,
) {
    let level_mask = altitude_layout::LEVEL_MASK;

    for &index in indices {
        let x = index / map_edge;
        let y = index % map_edge;
        let mut land = altitude[(index * 2 + 1) as usize] as i64 & level_mask;
        let mut higher_mask = 0;

        for neighbor in 0..8 {
            let near_x = x + NEIGHBOR_OFFSETS[neighbor].x;
            let near_y = y + NEIGHBOR_OFFSETS[neighbor].y;

            if near_x >= 0
                && near_x < map_edge
                && near_y >= 0
                && near_y < map_edge
                && (altitude[((near_x * map_edge + near_y) * 2 + 1) as usize] as i64 & level_mask) > land
            {
                higher_mask |= NEIGHBOR_MASKS[neighbor];
            }
        }

        let mut shape = TERRAIN_SHAPES[higher_mask as usize];
        let i = index as usize;

        if shape != terrain_ids::FLAT {
            zones[i] = (zones[i] as i64 & zone::CORNERS_MASK) as u8;
        }

        let raised_basin = shape == RAISE_BASIN;

        if raised_basin {
            land = (land + 1).min(31);
            set_land_altitude(altitude, index, land);
            shape = terrain_ids::FLAT;
        }

        if land >= sea_level {
            flags[i] = (flags[i] as i64 & !flag_bits::WATER & 0xff) as u8;
            terrain[i] = shape as u8;
            continue;
        }

        flags[i] = (flags[i] as i64 | flag_bits::WATER) as u8;
        set_water_altitude(altitude, index, sea_level);

        if buildings[i] as i64 != tiles::EMPTY && buildings[i] as i64 != tiles::RADIOACTIVE_WASTE {
            replace_building(buildings, zones, misc, index, tiles::EMPTY);
        }

        terrain[i] = if raised_basin {
            terrain_ids::DEEP_WATER_FLAT
        } else {
            shape + if sea_level - land == 1 { terrain_ids::SHORE_FIRST } else { terrain_ids::DEEP_WATER_FIRST }
        } as u8;
    }
}

/// LandscapeCommand._water_shape.
pub fn water_shape(flags: &[u8], x: i64, y: i64, map_edge: i64) -> i64 {
    let water = |index: i64| flags[index as usize] as i64 & flag_bits::WATER != 0;
    let mut cardinal = 0;

    if y > 0 && water(x * map_edge + y - 1) {
        cardinal |= 1;
    }

    if x < map_edge - 1 && water((x + 1) * map_edge + y) {
        cardinal |= 2;
    }

    if y < map_edge - 1 && water(x * map_edge + y + 1) {
        cardinal |= 4;
    }

    if x > 0 && water((x - 1) * map_edge + y) {
        cardinal |= 8;
    }

    if cardinal < 15 {
        return CARDINAL_WATER_SHAPES[cardinal as usize];
    }

    let mut missing_diagonal = 0;

    if x > 0 && y > 0 && !water((x - 1) * map_edge + y - 1) {
        missing_diagonal |= 1;
    }

    if x < map_edge - 1 && y > 0 && !water((x + 1) * map_edge + y - 1) {
        missing_diagonal |= 2;
    }

    if x < map_edge - 1 && y < map_edge - 1 && !water((x + 1) * map_edge + y + 1) {
        missing_diagonal |= 4;
    }

    if x > 0 && y < map_edge - 1 && !water((x - 1) * map_edge + y + 1) {
        missing_diagonal |= 8;
    }

    DIAGONAL_WATER_SHAPES[missing_diagonal as usize]
}

/// LandscapeCommand._water_transition. Returns the new terrain and whether
/// the original skips the update.
pub fn water_transition(current: i64, shape: i64) -> (i64, bool) {
    if current < terrain_ids::DEEP_WATER_FIRST {
        return (shape + terrain_ids::SURFACE_WATER_FIRST, false);
    }

    if current < terrain_ids::SURFACE_WATER_FIRST {
        if current > terrain_ids::DEEP_WATER_LAST {
            if (shape ^ current) & terrain_ids::SHAPE_MASK == 0 {
                return (current, true);
            }

            return (current - terrain_ids::DEEP_WATER_FIRST, false);
        }

        return (current, false);
    }

    if current == shape + terrain_ids::SURFACE_WATER_FIRST {
        return (current, true);
    }

    (shape + terrain_ids::SURFACE_WATER_FIRST, false)
}

/// DemolishTerrain._retile_surface_water.
pub fn retile_surface_water(terrain: &mut [u8], flags: &[u8], point: Vec2i, include_center: bool, map_edge: i64) {
    for x in (point.x - 1).max(0)..(point.x + 2).min(map_edge) {
        for y in (point.y - 1).max(0)..(point.y + 2).min(map_edge) {
            if !include_center && x == point.x && y == point.y {
                continue;
            }

            let index = (x * map_edge + y) as usize;

            if flags[index] as i64 & flag_bits::WATER == 0 {
                continue;
            }

            let shape = water_shape(flags, x, y, map_edge);
            let (value, skip) = water_transition(terrain[index] as i64, shape);

            if !skip {
                terrain[index] = value as u8;
            }
        }
    }
}

/// DemolishTerrain._remove_surface_water.
#[allow(clippy::too_many_arguments)]
pub fn remove_surface_water(
    altitude: &mut [u8],
    buildings: &mut [u8],
    terrain: &mut [u8],
    zones: &mut [u8],
    flags: &mut [u8],
    misc: &mut [u8],
    point: Vec2i,
    map_edge: i64,
) {
    let index = point.x * map_edge + point.y;

    if terrain[index as usize] as i64 == terrain_ids::WATERFALL {
        let level = sea_level(misc);
        retile_region(altitude, buildings, terrain, zones, flags, misc, &[index], level, map_edge);
    } else {
        terrain[index as usize] = terrain_ids::FLAT as u8;
    }

    flags[index as usize] = (flags[index as usize] as i64 & !flag_bits::WATER & 0xff) as u8;
    retile_surface_water(terrain, flags, point, false, map_edge);
}

/// DemolishTerrain._retile_adjacent_roads.
pub fn retile_adjacent_roads(
    buildings: &mut [u8],
    terrain: &[u8],
    zones: &[u8],
    flags: &[u8],
    misc: &mut [u8],
    point: Vec2i,
    map_edge: i64,
) {
    for offset in network::DIRECTIONS {
        let neighbor = point + offset;

        if neighbor.x >= 0 && neighbor.x < map_edge && neighbor.y >= 0 && neighbor.y < map_edge {
            network::retile_surface(buildings, terrain, zones, flags, misc, neighbor, network::MODE_ROAD, &[], map_edge);
        }
    }
}

/// DemolishTerrain._retile_after_demolition.
#[allow(clippy::too_many_arguments)]
pub fn retile_after_demolition(
    buildings: &mut [u8],
    terrain: &[u8],
    zones: &[u8],
    underground: &mut [u8],
    flags: &[u8],
    misc: &mut [u8],
    points: &[Vec2i],
    text_overlays: &[u8],
    map_edge: i64,
) {
    for &point in points {
        for offset in network::DIRECTIONS {
            let neighbor = point + offset;

            if neighbor.x < 0 || neighbor.x >= map_edge || neighbor.y < 0 || neighbor.y >= map_edge {
                continue;
            }

            for mode in [network::MODE_ROAD, network::MODE_RAIL, network::MODE_POWER] {
                network::retile_surface(buildings, terrain, zones, flags, misc, neighbor, mode, text_overlays, map_edge);
            }
        }

        super::underground::retile_neighborhood(underground, terrain, point, false, map_edge);
        super::underground::retile_neighborhood(underground, terrain, point, true, map_edge);
    }
}
