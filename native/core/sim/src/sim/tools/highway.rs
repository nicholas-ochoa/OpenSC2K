//! Highway sections, as HighwayGeometry, HighwayRoutes.select_section_kind,
//! and the HighwayPlacement retiling that demolition uses.

use super::network::replace_building;
use super::{Maps, set_corners};
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2altitude_layout as altitude_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;

pub const STRAIGHT_FIRST: i64 = tiles::HIGHWAY_STRAIGHT_1;
pub const STRAIGHT_LAST: i64 = tiles::HIGHWAY_POWER_CROSSING_2;
pub const SHAPED_FIRST: i64 = tiles::HIGHWAY_SLOPE_FIRST;
pub const SHAPED_LAST: i64 = tiles::REINFORCED_HIGHWAY_BRIDGE;
pub const DIRECTIONS: [Vec2i; 4] = [Vec2i::new(0, -1), Vec2i::new(1, 0), Vec2i::new(0, 1), Vec2i::new(-1, 0)];
pub const SECTION_OFFSETS: [Vec2i; 4] = [Vec2i::new(0, 0), Vec2i::new(1, 0), Vec2i::new(1, 1), Vec2i::new(0, 1)];
pub const SHAPE_BY_CONNECTIONS: [i64; 16] = [2, 2, 3, 8, 2, 2, 9, 12, 3, 11, 3, 12, 10, 12, 12, 12];
pub const GRADED_SHAPE_BY_CONNECTIONS: [i64; 16] = [2, 2, 3, 3, 2, 2, 3, 2, 3, 3, 3, 2, 3, 2, 2, 2];
pub const EAST_WEST_KIND_CONNECTIONS: [bool; 18] = [
    false, false, true, false, true, false, true, false, true, true, true, true, true, false, true, false, true, false,
];
pub const NORTH_SOUTH_KIND_CONNECTIONS: [bool; 18] = [
    false, true, false, true, false, true, false, true, true, true, true, true, true, true, false, true, false, false,
];
pub const INVALID_TERRAIN_SHAPE: i64 = -1;
pub const FLAT_TERRAIN_SHAPE: i64 = 0x0f;
pub const FILLED_FLAT_TERRAIN_SHAPE: i64 = 0x4000;

pub fn anchor_is_in_bounds(anchor: Vec2i, map_edge: i64) -> bool {
    anchor.x >= 0 && anchor.x <= map_edge - 2 && anchor.y >= 0 && anchor.y <= map_edge - 2
}

pub fn is_highway_tile(tile: i64) -> bool {
    (STRAIGHT_FIRST..=STRAIGHT_LAST).contains(&tile) || (SHAPED_FIRST..=SHAPED_LAST).contains(&tile)
}

/// HighwayGeometry._land_altitude reads the whole word, then masks it.
#[inline]
fn land_altitude(altitude: &[u8], index: i64) -> i64 {
    (((altitude[(index * 2) as usize] as i64) << 8) | altitude[(index * 2 + 1) as usize] as i64) & altitude_layout::LEVEL_MASK
}

/// HighwayGeometry._section_kind.
pub fn section_kind(buildings: &[u8], zones: &[u8], flags: &[u8], anchor: Vec2i, map_edge: i64) -> i64 {
    if !anchor_is_in_bounds(anchor, map_edge) {
        return -1;
    }

    let anchor_index = (anchor.x * map_edge + anchor.y) as usize;
    let anchor_tile = buildings[anchor_index] as i64;

    if !is_highway_tile(anchor_tile) {
        return -1;
    }

    if zones[anchor_index] as i64 & zone::CORNERS_MASK != zone::CORNERS_MASK {
        let shaped_kind = anchor_tile - tiles::HIGHWAY_ONRAMP_1;

        if shaped_kind > 12 {
            let south_index = (anchor.x * map_edge + anchor.y + 1) as usize;

            return if flags[south_index] as i64 & flag_bits::FLIPPED != 0 {
                16
            } else {
                15
            };
        }

        return shaped_kind;
    }

    let mut last_tile = anchor_tile;

    for offset in SECTION_OFFSETS {
        let point = anchor + offset;
        let index = (point.x * map_edge + point.y) as usize;
        last_tile = buildings[index] as i64;

        if (tiles::HIGHWAY_ROAD_CROSSING_1..=tiles::HIGHWAY_POWER_CROSSING_2).contains(&last_tile) {
            return last_tile & 1;
        }

        if flags[index] as i64 & flag_bits::WATER != 0 {
            return if last_tile == tiles::HIGHWAY_STRAIGHT_1 { 13 } else { 14 };
        }
    }

    if (STRAIGHT_FIRST..=tiles::HIGHWAY_STRAIGHT_2).contains(&last_tile) {
        return (last_tile & 1) + 2;
    }

    -1
}

/// HighwayGeometry._section_altitude.
pub fn section_altitude(terrain: &[u8], altitude: &[u8], anchor: Vec2i, map_edge: i64) -> i64 {
    let mut result = 0;

    for offset in SECTION_OFFSETS {
        let point = anchor + offset;
        let index = point.x * map_edge + point.y;
        let mut height = land_altitude(altitude, index);

        if terrain[index as usize] as i64 != terrain_ids::FLAT {
            height += 1;
        }

        result = result.max(height);
    }

    result
}

fn terrain_class(terrain_id: i64) -> usize {
    use terrain_ids::*;

    if (SLOPE_TOP_LEFT..=SLOPE_BOTTOM_LEFT).contains(&terrain_id)
        || (DEEP_WATER_SLOPE_BOTTOM_RIGHT..=SHORE_RAISED_EXCEPT_LEFT).contains(&terrain_id)
    {
        return 1;
    }

    if (RAISED_EXCEPT_BOTTOM..=RAISED_EXCEPT_RIGHT).contains(&terrain_id) {
        return 2;
    }

    if (CORNER_TOP..=CORNER_LEFT).contains(&terrain_id) {
        return 3;
    }

    if terrain_id == RAISED { 4 } else { 0 }
}

pub fn building_is_allowed(tile: i64) -> bool {
    if (SHAPED_FIRST..=SHAPED_LAST).contains(&tile) || (STRAIGHT_FIRST..=STRAIGHT_LAST).contains(&tile) {
        return true;
    }

    if tile == tiles::SMALL_PARK || tile == tiles::RADIOACTIVE_WASTE {
        return false;
    }

    if (tiles::ROAD_SLOPE_1..=tiles::ROAD_CROSSROADS).contains(&tile) {
        return false;
    }

    if (tiles::RAIL_SLOPE_1..=tiles::RAIL_POWER_CROSSING_2).contains(&tile) {
        return false;
    }

    tile <= STRAIGHT_LAST
}

/// HighwayGeometry.terrain_section_shape.
pub fn terrain_section_shape(buildings: &[u8], terrain: &[u8], altitude: &[u8], anchor: Vec2i, map_edge: i64) -> i64 {
    if !anchor_is_in_bounds(anchor, map_edge) {
        return INVALID_TERRAIN_SHAPE;
    }

    let cells = (map_edge * map_edge) as usize;

    if buildings.len() != cells || terrain.len() != cells || altitude.len() != cells * 2 {
        return INVALID_TERRAIN_SHAPE;
    }

    let mut class_masks = [0i64; 5];
    let mut heights = [0i64; 4];

    for (offset_index, offset) in SECTION_OFFSETS.iter().enumerate() {
        let point = anchor + *offset;
        let index = point.x * map_edge + point.y;

        if !building_is_allowed(buildings[index as usize] as i64) {
            return INVALID_TERRAIN_SHAPE;
        }

        class_masks[terrain_class(terrain[index as usize] as i64)] |= 1 << offset_index;
        heights[offset_index] = land_altitude(altitude, index);
    }

    let odd_slope_mask = class_masks[1] | class_masks[3];
    let terrain_mask = class_masks[1] | class_masks[2] | class_masks[3] | class_masks[4];

    if terrain_mask == 0 {
        return FLAT_TERRAIN_SHAPE;
    }

    if (heights[2] < heights[0] && terrain_mask & 1 != 0)
        || (heights[0] < heights[2] && terrain_mask & 4 != 0)
        || (heights[3] < heights[1] && terrain_mask & 2 != 0)
        || (heights[1] < heights[3] && terrain_mask & 8 != 0)
    {
        return INVALID_TERRAIN_SHAPE;
    }

    let minimum_height = heights.iter().copied().min().unwrap_or(0);
    let mut raised_mask = 0;

    for (height_index, height) in heights.iter().enumerate() {
        if minimum_height < *height {
            raised_mask |= 1 << height_index;
        }
    }

    if 0x0f - raised_mask == class_masks[4] {
        return FILLED_FLAT_TERRAIN_SHAPE;
    }

    if raised_mask == 0 && terrain[(anchor.x * map_edge + anchor.y) as usize] as i64 == terrain_ids::RAISED {
        return FILLED_FLAT_TERRAIN_SHAPE;
    }

    let mut result = 0;

    if raised_mask == 0 {
        if matches!(odd_slope_mask, 8 | 1 | 9) {
            result |= 1;
        }

        if matches!(odd_slope_mask, 1..=3) {
            result |= 2;
        }

        if matches!(odd_slope_mask, 2 | 4 | 6) {
            result |= 4;
        }

        if matches!(odd_slope_mask, 4 | 8 | 12) {
            result |= 8;
        }
    }

    if matches!(raised_mask, 8 | 1 | 9) && odd_slope_mask & 6 == 6 {
        result |= 1;
    }

    if matches!(raised_mask, 1..=3) && odd_slope_mask & 12 == 12 {
        result |= 2;
    }

    if matches!(raised_mask, 2 | 4 | 6) && odd_slope_mask & 9 == 9 {
        result |= 4;
    }

    if matches!(raised_mask, 4 | 8 | 12) && odd_slope_mask & 3 == 3 {
        result |= 8;
    }

    if terrain_mask == 7 {
        if class_masks[3] & 1 != 0 {
            result |= 4;
        }

        if class_masks[3] & 4 != 0 {
            result |= 2;
        }
    }

    if terrain_mask == 11 {
        if class_masks[3] & 8 != 0 {
            result |= 2;
        }

        if class_masks[3] & 2 != 0 {
            result |= 1;
        }
    }

    if terrain_mask == 13 {
        if class_masks[3] & 4 != 0 {
            result |= 1;
        }

        if class_masks[3] & 1 != 0 {
            result |= 8;
        }
    }

    if terrain_mask == 14 {
        if class_masks[3] & 8 != 0 {
            result |= 4;
        }

        if class_masks[3] & 2 != 0 {
            result |= 8;
        }
    }

    result
}

pub fn grade_kind_for_shape(terrain_shape: i64) -> i64 {
    if terrain_shape & 2 != 0 {
        return 5;
    }

    if terrain_shape & 8 != 0 {
        return 7;
    }

    if terrain_shape & 1 != 0 {
        return 4;
    }

    if terrain_shape & 4 != 0 {
        return 6;
    }

    -1
}

fn neighbor_kind_connects(
    buildings: &[u8],
    terrain: &[u8],
    altitude: &[u8],
    neighbor: Vec2i,
    neighbor_kind: i64,
    direction_index: i64,
    map_edge: i64,
) -> bool {
    let north_south = direction_index == 0 || direction_index == 2;

    if north_south {
        if neighbor_kind == 1 || neighbor_kind == 3 {
            return true;
        }

        if neighbor_kind > 3
            && neighbor_kind < NORTH_SOUTH_KIND_CONNECTIONS.len() as i64
            && NORTH_SOUTH_KIND_CONNECTIONS[neighbor_kind as usize]
        {
            return true;
        }

        return neighbor_kind == 2 && terrain_section_shape(buildings, terrain, altitude, neighbor, map_edge) != FILLED_FLAT_TERRAIN_SHAPE;
    }

    if neighbor_kind == 0 || neighbor_kind == 2 {
        return true;
    }

    if neighbor_kind > 3 && neighbor_kind < EAST_WEST_KIND_CONNECTIONS.len() as i64 && EAST_WEST_KIND_CONNECTIONS[neighbor_kind as usize] {
        return true;
    }

    neighbor_kind == 3 && terrain_section_shape(buildings, terrain, altitude, neighbor, map_edge) != FILLED_FLAT_TERRAIN_SHAPE
}

#[allow(clippy::too_many_arguments)]
fn neighbor_connection_flags(
    buildings: &[u8],
    terrain: &[u8],
    zones: &[u8],
    flags: &[u8],
    altitude: &[u8],
    anchor: Vec2i,
    current_height: i64,
    direction_index: i64,
    map_edge: i64,
) -> i64 {
    let step = DIRECTIONS[direction_index as usize];
    let neighbor = anchor + Vec2i::new(step.x * 2, step.y * 2);

    if !anchor_is_in_bounds(neighbor, map_edge) {
        return 0;
    }

    let neighbor_kind = section_kind(buildings, zones, flags, neighbor, map_edge);

    if !neighbor_kind_connects(buildings, terrain, altitude, neighbor, neighbor_kind, direction_index, map_edge) {
        return 0;
    }

    let neighbor_height = section_altitude(terrain, altitude, neighbor, map_edge);
    let mut result = 1 << direction_index;
    let (rising, falling, same_kind) = match direction_index {
        0 => (0x10, 0x40, 5),
        1 => (0x20, 0x80, 6),
        2 => (0x40, 0x10, 7),
        _ => (0x80, 0x20, 4),
    };

    if current_height < neighbor_height && neighbor_kind != same_kind {
        result |= rising;
    }

    if neighbor_height < current_height || (neighbor_height == current_height && neighbor_kind == same_kind) {
        result |= falling;
    }

    result
}

/// HighwayRoutes.select_section_kind.
#[allow(clippy::too_many_arguments)]
pub fn select_section_kind(
    buildings: &[u8],
    terrain: &[u8],
    zones: &[u8],
    flags: &[u8],
    altitude: &[u8],
    anchor: Vec2i,
    direction: i64,
    map_edge: i64,
) -> i64 {
    if !anchor_is_in_bounds(anchor, map_edge) {
        return -1;
    }

    let current_kind = section_kind(buildings, zones, flags, anchor, map_edge);

    if current_kind == 0 || current_kind == 1 || (4..=7).contains(&current_kind) || current_kind > 12 {
        return -1;
    }

    let current_height = section_altitude(terrain, altitude, anchor, map_edge);
    let mut connections = 0;

    for direction_index in 0..4 {
        connections |= neighbor_connection_flags(
            buildings,
            terrain,
            zones,
            flags,
            altitude,
            anchor,
            current_height,
            direction_index,
            map_edge,
        );
    }

    let terrain_shape = terrain_section_shape(buildings, terrain, altitude, anchor, map_edge);

    if terrain_shape == INVALID_TERRAIN_SHAPE {
        return -1;
    }

    if current_kind == 2 || current_kind == 3 {
        if connections == 1 || connections == 4 {
            return 2;
        }

        if connections == 2 || connections == 8 {
            return 3;
        }

        if terrain_shape == FILLED_FLAT_TERRAIN_SHAPE {
            return -1;
        }
    }

    if connections == 0 {
        if current_kind == 2 || current_kind == 3 {
            // No adjacent geometry changed. Keep the installed straight pixels.
            return -1;
        }

        if terrain_shape == FLAT_TERRAIN_SHAPE {
            return (direction & 1) + 2;
        }

        let grade_kind = grade_kind_for_shape(terrain_shape);

        if grade_kind >= 0 {
            return grade_kind;
        }
    }

    if connections & 0x10 != 0 && terrain_shape & 2 != 0 {
        return 5;
    }

    if connections & 0x40 != 0 && terrain_shape & 8 != 0 {
        return 7;
    }

    if connections & 0x80 != 0 && terrain_shape & 1 != 0 {
        return 4;
    }

    if connections & 0x20 != 0 && terrain_shape & 4 != 0 {
        return 6;
    }

    let connection_mask = (connections & 0x0f) as usize;

    if terrain_shape != FLAT_TERRAIN_SHAPE {
        if connections & 1 != 0 && terrain_shape & 2 != 0 {
            return 5;
        }

        if connections & 4 != 0 && terrain_shape & 8 != 0 {
            return 7;
        }

        if connections & 8 != 0 && terrain_shape & 1 != 0 {
            return 4;
        }

        if connections & 2 != 0 && terrain_shape & 4 != 0 {
            return 6;
        }

        return GRADED_SHAPE_BY_CONNECTIONS[connection_mask];
    }

    SHAPE_BY_CONNECTIONS[connection_mask]
}

fn straight_replacement(old_tile: i64, orientation: i64) -> i64 {
    match old_tile {
        tiles::POWER_LINE_STRAIGHT_1 => tiles::HIGHWAY_POWER_CROSSING_2,
        tiles::POWER_LINE_STRAIGHT_2 => tiles::HIGHWAY_POWER_CROSSING_1,
        tiles::ROAD_STRAIGHT_1 => tiles::HIGHWAY_ROAD_CROSSING_2,
        tiles::ROAD_STRAIGHT_2 => tiles::HIGHWAY_ROAD_CROSSING_1,
        tiles::RAIL_STRAIGHT_1 => tiles::HIGHWAY_RAIL_CROSSING_2,
        tiles::RAIL_STRAIGHT_2 => tiles::HIGHWAY_RAIL_CROSSING_1,
        _ => STRAIGHT_FIRST + orientation,
    }
}

/// HighwayPlacement._place_straight_section. The offsets visit the section in
/// its own order.
fn place_straight_section(maps: &mut Maps, anchor: Vec2i, orientation: i64) {
    let edge = maps.map_edge;

    for offset in [Vec2i::new(0, 0), Vec2i::new(1, 0), Vec2i::new(0, 1), Vec2i::new(1, 1)] {
        let point = anchor + offset;
        let index = point.x * edge + point.y;
        let i = index as usize;
        maps.zones[i] = (maps.zones[i] as i64 & zone::CORNERS_MASK) as u8;
        let tile = straight_replacement(maps.buildings[i] as i64, orientation);
        replace_building(maps.buildings, maps.zones, maps.misc, index, tile);
        maps.zones[i] = (maps.zones[i] as i64 | zone::CORNERS_MASK) as u8;
    }
}

fn prepare_flat_terrain(terrain: &mut [u8], altitude: &[u8], anchor: Vec2i, map_edge: i64) {
    let target = section_altitude(terrain, altitude, anchor, map_edge);

    for offset in SECTION_OFFSETS {
        let point = anchor + offset;
        let index = point.x * map_edge + point.y;

        if land_altitude(altitude, index) < target {
            terrain[index as usize] = terrain_ids::RAISED as u8;
        }
    }
}

fn prepare_shaped_terrain(terrain: &mut [u8], altitude: &[u8], anchor: Vec2i, map_edge: i64) {
    let target = section_altitude(terrain, altitude, anchor, map_edge);

    for offset in SECTION_OFFSETS {
        let point = anchor + offset;
        let index = point.x * map_edge + point.y;

        if terrain[index as usize] as i64 != terrain_ids::FLAT || land_altitude(altitude, index) < target {
            terrain[index as usize] = terrain_ids::RAISED as u8;
        }
    }
}

/// HighwayPlacement._set_land_altitude replaces the low five bits of the word.
fn set_section_land_altitude(altitude: &mut [u8], index: i64, value: i64) {
    let offset = (index * 2) as usize;
    let mut word = ((altitude[offset] as i64) << 8) | altitude[offset + 1] as i64;
    word = (word & !altitude_layout::LEVEL_MASK) | (value & altitude_layout::LEVEL_MASK);
    altitude[offset] = (word >> 8) as u8;
    altitude[offset + 1] = word as u8;
}

fn place_graded_section(maps: &mut Maps, anchor: Vec2i, kind: i64, rotation: i64) {
    let edge = maps.map_edge;
    let target = section_altitude(maps.terrain, maps.altitude, anchor, edge);
    let all_at_target = SECTION_OFFSETS
        .iter()
        .all(|offset| land_altitude(maps.altitude, maps.index(anchor + *offset)) == target);

    if !all_at_target {
        for offset in SECTION_OFFSETS {
            let index = maps.index(anchor + offset);
            set_section_land_altitude(maps.altitude, index, target - 1);
        }
    }

    use terrain_ids::*;
    let pattern = match kind {
        4 => [RAISED, SLOPE_TOP_LEFT, SLOPE_TOP_LEFT, RAISED],
        5 => [RAISED, RAISED, SLOPE_TOP_RIGHT, SLOPE_TOP_RIGHT],
        6 => [SLOPE_BOTTOM_RIGHT, RAISED, RAISED, SLOPE_BOTTOM_RIGHT],
        7 => [SLOPE_BOTTOM_LEFT, SLOPE_BOTTOM_LEFT, RAISED, RAISED],
        _ => return,
    };

    let tile = tiles::HIGHWAY_ONRAMP_1 + kind;

    for (offset_index, offset) in SECTION_OFFSETS.iter().enumerate() {
        let index = maps.index(anchor + *offset);
        let i = index as usize;
        maps.terrain[i] = pattern[offset_index] as u8;
        maps.zones[i] = (maps.zones[i] as i64 & zone::CORNERS_MASK) as u8;
        replace_building(maps.buildings, maps.zones, maps.misc, index, tile);
    }

    set_corners(maps.zones, anchor, 2, rotation, edge);
}

fn write_shape(maps: &mut Maps, anchor: Vec2i, kind: i64, rotation: i64) {
    if kind == 2 || kind == 3 {
        place_straight_section(maps, anchor, kind - 2);

        return;
    }

    let tile = tiles::HIGHWAY_ONRAMP_1 + kind;

    for offset in SECTION_OFFSETS {
        let index = maps.index(anchor + offset);
        maps.zones[index as usize] = 0;
        replace_building(maps.buildings, maps.zones, maps.misc, index, tile);
    }

    set_corners(maps.zones, anchor, 2, rotation, maps.map_edge);
}

pub fn write_section_kind(maps: &mut Maps, anchor: Vec2i, kind: i64, rotation: i64) {
    let edge = maps.map_edge;

    if kind < 4 {
        prepare_flat_terrain(maps.terrain, maps.altitude, anchor, edge);
        let mut orientation = kind & 1;

        for offset in SECTION_OFFSETS {
            let old_tile = maps.buildings[maps.index(anchor + offset) as usize] as i64;

            if old_tile == tiles::POWER_LINE_STRAIGHT_1 || old_tile == tiles::ROAD_STRAIGHT_1 || old_tile == tiles::RAIL_STRAIGHT_1 {
                orientation = 1;
            } else if old_tile == tiles::POWER_LINE_STRAIGHT_2 || old_tile == tiles::ROAD_STRAIGHT_2 || old_tile == tiles::RAIL_STRAIGHT_2 {
                orientation = 0;
            }
        }

        place_straight_section(maps, anchor, orientation);

        return;
    }

    if (4..=7).contains(&kind) {
        place_graded_section(maps, anchor, kind, rotation);

        return;
    }

    if (8..=12).contains(&kind) {
        prepare_shaped_terrain(maps.terrain, maps.altitude, anchor, edge);
        write_shape(maps, anchor, kind, rotation);
    }
}

/// HighwayGeometry.snap_anchor: sections start on even coordinates.
pub fn snap_anchor(point: Vec2i) -> Vec2i {
    Vec2i::new(point.x & !1, point.y & !1)
}

/// The neighboring section anchor in `direction`.
pub fn neighbor_anchor(anchor: Vec2i, direction: usize) -> Vec2i {
    anchor + Vec2i::new(DIRECTIONS[direction].x * 2, DIRECTIONS[direction].y * 2)
}

/// A placed section: the kind it holds, and whether it is a new grade.
pub struct Placement {
    pub ok: bool,
    pub error: &'static str,
    pub kind: i64,
    pub graded: bool,
}

/// HighwayPlacement._place_section: write the section, then retile the
/// highway sections around it and the section itself.
pub fn place_section(maps: &mut Maps, anchor: Vec2i, direction: i64, rotation: i64) -> Placement {
    let edge = maps.map_edge;

    if terrain_section_shape(maps.buildings, maps.terrain, maps.altitude, anchor, edge) == INVALID_TERRAIN_SHAPE {
        return Placement {
            ok: false,
            error: "highway terrain grade is invalid",
            kind: 0,
            graded: false,
        };
    }

    for offset in SECTION_OFFSETS {
        let index = maps.index(anchor + offset) as usize;
        maps.zones[index] = (maps.zones[index] as i64 & zone::CORNERS_MASK) as u8;
    }

    let old_kind = section_kind(maps.buildings, maps.zones, maps.flags, anchor, edge);
    let kind = select_section_kind(
        maps.buildings,
        maps.terrain,
        maps.zones,
        maps.flags,
        maps.altitude,
        anchor,
        direction,
        edge,
    );

    if kind >= 0 {
        write_section_kind(maps, anchor, kind, rotation);
    }

    for step in 0..DIRECTIONS.len() {
        let neighbor = neighbor_anchor(anchor, step);

        if anchor_is_in_bounds(neighbor, edge) && section_kind(maps.buildings, maps.zones, maps.flags, neighbor, edge) > 1 {
            retile_section(maps, neighbor, direction, rotation);
        }
    }

    retile_section(maps, anchor, direction, rotation);

    Placement {
        ok: true,
        error: "",
        kind: if kind >= 0 { kind } else { old_kind },
        graded: (4..=7).contains(&kind),
    }
}

/// HighwayPlacement._retile_section. Returns the new kind, or -1 when it stays.
pub fn retile_section(maps: &mut Maps, anchor: Vec2i, direction: i64, rotation: i64) -> i64 {
    let edge = maps.map_edge;
    let kind = select_section_kind(
        maps.buildings,
        maps.terrain,
        maps.zones,
        maps.flags,
        maps.altitude,
        anchor,
        direction,
        edge,
    );

    if kind >= 0 {
        write_section_kind(maps, anchor, kind, rotation);
    }

    kind
}

/// HighwayPlacement._retile_affected_sections with no route directions.
pub fn retile_affected_sections(maps: &mut Maps, placed: &[Vec2i], rotation: i64) {
    retile_route_sections(maps, placed, rotation, &[]);
}

/// HighwayPlacement._retile_affected_sections: the placed sections and their
/// highway neighbors, each with its route direction or 0.
pub fn retile_route_sections(maps: &mut Maps, placed: &[Vec2i], rotation: i64, route_directions: &[(Vec2i, i64)]) {
    let edge = maps.map_edge;
    let mut affected: Vec<Vec2i> = Vec::new();

    for &anchor in placed {
        if !affected.contains(&anchor) {
            affected.push(anchor);
        }

        for step in 0..DIRECTIONS.len() {
            let neighbor = neighbor_anchor(anchor, step);

            if anchor_is_in_bounds(neighbor, edge)
                && section_kind(maps.buildings, maps.zones, maps.flags, neighbor, edge) > 1
                && !affected.contains(&neighbor)
            {
                affected.push(neighbor);
            }
        }
    }

    for anchor in affected {
        let direction = route_directions
            .iter()
            .find(|(section, _)| *section == anchor)
            .map_or(0, |(_, direction)| *direction);

        retile_section(maps, anchor, direction, rotation);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A lone section beside a connection label keeps the straight kind of
    /// its direction, at the map edge too.
    #[test]
    fn edge_sections_keep_their_direction() {
        for edge in [128i64, 256, 1024] {
            let cells = (edge * edge) as usize;
            let (buildings, terrain, zones, flags, altitude) = (
                vec![0u8; cells],
                vec![0u8; cells],
                vec![0u8; cells],
                vec![0u8; cells],
                vec![0u8; cells * 2],
            );

            for anchor in [
                Vec2i::new(20, 20),
                Vec2i::new(edge - 10, edge - 10),
                Vec2i::new(edge - 2, 20),
                Vec2i::new(20, edge - 2),
            ] {
                for direction in 0..2 {
                    assert_eq!(
                        select_section_kind(&buildings, &terrain, &zones, &flags, &altitude, anchor, direction, edge),
                        direction + 2
                    );
                }
            }
        }
    }
}
