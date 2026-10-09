//! Highway bridges of 2 by 2 sections, as HighwayBridges.

use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::tools::commands::network::bridge::BridgeChoice;
use crate::sim::tools::commands::{DIRECTIONS, scaled};
use crate::sim::tools::highway::{
    INVALID_TERRAIN_SHAPE, SECTION_OFFSETS, STRAIGHT_FIRST, anchor_is_in_bounds, section_altitude, terrain_section_shape,
    write_section_kind,
};

use crate::sim::tools::network::replace_building;
use crate::sim::tools::{Maps, set_corners};

pub const BRIDGE_HIGHWAY: i64 = 5;
pub const BRIDGE_REINFORCED: i64 = 6;

/// Each nibble of a terrain code counts one terrain class over the four
/// section tiles.
const WEIGHT_FLAT_LAND: i64 = 0x1000;
const WEIGHT_SLOPED_LAND: i64 = 0x0100;
const WEIGHT_OPEN_WATER: i64 = 0x0010;
const WEIGHT_SHORE: i64 = 0x0001;
const SLOPED_LAND_MASK: i64 = 0x0f00;

/// The directions that a bank of flat land faces open water, by the flat tiles of the section.
const BRIDGE_DIRECTION_MASK_BY_LAND: [i64; 16] = [0, 6, 12, 4, 9, 0, 8, 12, 3, 2, 0, 6, 1, 3, 9, 0];

/// A reinforced bridge alternates these two section kinds.
const REINFORCED_EVEN_KIND: i64 = 14;
const REINFORCED_ODD_KIND: i64 = 13;

pub fn bridge_cost(bridge_type: i64) -> i64 {
    if bridge_type == BRIDGE_REINFORCED { 300 } else { 200 }
}

pub fn bridge_type_name(bridge_type: i64) -> String {
    match bridge_type {
        BRIDGE_HIGHWAY => "Highway Bridge",
        BRIDGE_REINFORCED => "Reinforced Bridge",
        _ => "Unknown Bridge",
    }
    .to_string()
}

#[derive(Clone, Debug, Default)]
pub struct Plan {
    pub ok: bool,
    pub error: String,
    pub start: Vec2i,
    pub direction: i64,
    pub span_length: i64,
    pub reinforced_allowed: bool,
}

impl Plan {
    fn failure(message: &str) -> Self {
        Self {
            error: message.to_string(),
            ..Default::default()
        }
    }
}

/// The city maps that a bridge plan reads.
pub struct BridgeMaps<'a> {
    pub buildings: &'a [u8],
    pub terrain: &'a [u8],
    pub altitude: &'a [u8],
    pub map_edge: i64,
}

/// HighwayBridges.plan_bridge_from_start: try the directions in view order.
pub fn plan_bridge_from_start(maps: &BridgeMaps, start: Vec2i, view_rotation: i64) -> Plan {
    if !section_is_bridge_clear(maps.buildings, start, maps.map_edge) {
        return Plan::failure("highway bridge start contains a structure");
    }

    let mut code = bridge_terrain_code(maps.terrain, start, maps.map_edge);

    if code & SLOPED_LAND_MASK != 0 {
        return Plan::failure("highway bridge start terrain is invalid");
    }

    if (code >> 8) & 0xff != 0 {
        code >>= 12;
    }

    let direction_mask = BRIDGE_DIRECTION_MASK_BY_LAND[(code & 0x0f) as usize];

    for direction in [
        view_rotation & 3,
        (view_rotation + 2) & 3,
        (view_rotation + 1) & 3,
        (view_rotation - 1) & 3,
    ] {
        if direction_mask & (1 << direction) != 0 {
            return scan_bridge(maps, start, direction);
        }
    }

    Plan::failure("highway bridge does not face open water")
}

/// HighwayBridges._scan_bridge: walk the sections to the other bank.
pub fn scan_bridge(maps: &BridgeMaps, start: Vec2i, direction: i64) -> Plan {
    let edge = maps.map_edge;

    if !section_is_bridge_clear(maps.buildings, start, edge) {
        return Plan::failure("highway bridge start contains a structure");
    }

    let step = scaled(DIRECTIONS[direction as usize], 2);
    let mut span_length = 0;
    let mut checked = start;

    loop {
        checked = checked + step;
        span_length += 1;

        if !anchor_is_in_bounds(checked, edge) {
            return Plan::failure("highway bridge does not reach another bank");
        }

        if !section_is_bridge_clear(maps.buildings, checked, edge) {
            return Plan::failure("highway bridge path contains a structure");
        }

        let code = bridge_terrain_code(maps.terrain, checked, edge);

        if code & SLOPED_LAND_MASK != 0 {
            return Plan::failure("highway bridge bank terrain is invalid");
        }

        if code & 0xff == 0 {
            break;
        }
    }

    Plan {
        ok: true,
        error: String::new(),
        start,
        direction,
        span_length,
        reinforced_allowed: reinforced_bridge_is_allowed(maps, start, direction, span_length),
    }
}

/// HighwayBridges._bridge_choices.
pub fn bridge_choices(plan: &Plan) -> Vec<BridgeChoice> {
    let mut types = vec![BRIDGE_HIGHWAY];

    if plan.reinforced_allowed {
        types.push(BRIDGE_REINFORCED);
    }

    types
        .into_iter()
        .map(|bridge_type| {
            BridgeChoice::new(
                bridge_type,
                &bridge_type_name(bridge_type),
                bridge_cost(bridge_type),
                plan.span_length,
            )
        })
        .collect()
}

/// A reinforced bridge needs banks at the deck height on both ends.
fn reinforced_bridge_is_allowed(maps: &BridgeMaps, start: Vec2i, direction: i64, span_length: i64) -> bool {
    if span_length <= 2 {
        return false;
    }

    let height = section_altitude(maps.terrain, maps.altitude, start, maps.map_edge);
    let step = scaled(DIRECTIONS[direction as usize], 2);
    let behind = start - step;
    let far_bank = start + scaled(step, span_length);

    bridge_endpoint_is_allowed(maps, behind, height, direction) && bridge_endpoint_is_allowed(maps, far_bank, height, (direction + 2) & 3)
}

fn bridge_endpoint_is_allowed(maps: &BridgeMaps, anchor: Vec2i, bridge_height: i64, required_slope_direction: i64) -> bool {
    if !section_is_bridge_clear(maps.buildings, anchor, maps.map_edge) {
        return false;
    }

    let endpoint_height = section_altitude(maps.terrain, maps.altitude, anchor, maps.map_edge);

    if endpoint_height < bridge_height || endpoint_height > bridge_height + 1 {
        return false;
    }

    let shape = terrain_section_shape(maps.buildings, maps.terrain, maps.altitude, anchor, maps.map_edge);

    if shape == INVALID_TERRAIN_SHAPE {
        return false;
    }

    endpoint_height != bridge_height || shape & (1 << required_slope_direction) != 0
}

fn section_is_bridge_clear(buildings: &[u8], anchor: Vec2i, map_edge: i64) -> bool {
    anchor_is_in_bounds(anchor, map_edge)
        && SECTION_OFFSETS.iter().all(|offset| {
            let point = anchor + *offset;

            buildings[(point.x * map_edge + point.y) as usize] as i64 <= tiles::SMALL_PARK
        })
}

/// HighwayBridges.bridge_terrain_code: the terrain classes of the four tiles.
fn bridge_terrain_code(terrain: &[u8], anchor: Vec2i, map_edge: i64) -> i64 {
    if !anchor_is_in_bounds(anchor, map_edge) {
        return SLOPED_LAND_MASK;
    }

    let mut result = 0;

    for offset in [Vec2i::new(0, 1), Vec2i::new(1, 1), Vec2i::new(1, 0), Vec2i::new(0, 0)] {
        let point = anchor + offset;
        let terrain_id = terrain[(point.x * map_edge + point.y) as usize] as i64;
        result = ((result * 2) + bridge_terrain_weight(terrain_id)) & 0xffff;
    }

    result
}

fn bridge_terrain_weight(terrain_id: i64) -> i64 {
    use terrain_ids::*;

    if terrain_id == FLAT || (CHANNEL_FIRST..=CHANNEL_LAST).contains(&terrain_id) {
        return WEIGHT_FLAT_LAND;
    }

    if (SLOPE_TOP_LEFT..=LAND_LAST).contains(&terrain_id) {
        return WEIGHT_SLOPED_LAND;
    }

    if (DEEP_WATER_FIRST..=SHORE_FIRST).contains(&terrain_id) || terrain_id == SURFACE_WATER_OPEN {
        return WEIGHT_OPEN_WATER;
    }

    if (SHORE_SLOPE_TOP_LEFT..=SHORE_LAST).contains(&terrain_id) || (SURFACE_WATER_NES..=SURFACE_WATER_LAST).contains(&terrain_id) {
        return WEIGHT_SHORE;
    }

    0
}

/// The sections that a bridge wrote.
pub struct Placement {
    pub sections: Vec<Vec2i>,
    pub endpoint_sections: Vec<Vec2i>,
}

/// HighwayBridges._place_bridge.
pub fn place_bridge(maps: &mut Maps, plan: &Plan, bridge_type: i64, rotation: i64) -> Placement {
    let edge = maps.map_edge;
    let start = plan.start;
    let direction = plan.direction;
    let step = scaled(DIRECTIONS[direction as usize], 2);
    let height = section_altitude(maps.terrain, maps.altitude, start, edge);
    let mut endpoint_sections = Vec::new();

    if bridge_type == BRIDGE_REINFORCED {
        let behind = start - step;
        let behind_kind = if height - section_altitude(maps.terrain, maps.altitude, behind, edge) == -1 {
            direction & 1
        } else {
            ((direction + 1) & 3) + 4
        };

        write_bridge_endpoint(maps, behind, behind_kind, rotation);
        endpoint_sections.push(behind);

        let far_bank = start + scaled(step, plan.span_length);
        let far_kind = if height - section_altitude(maps.terrain, maps.altitude, far_bank, edge) == -1 {
            direction & 1
        } else {
            ((direction - 1) & 3) + 4
        };

        write_bridge_endpoint(maps, far_bank, far_kind, rotation);
        endpoint_sections.push(far_bank);
    }

    let mut sections = Vec::new();

    for span_index in 0..plan.span_length {
        let anchor = start + scaled(step, span_index);

        if bridge_type == BRIDGE_REINFORCED {
            let kind = if span_index & 1 == 0 {
                REINFORCED_EVEN_KIND
            } else {
                REINFORCED_ODD_KIND
            };

            write_reinforced_section(maps, anchor, kind, direction, rotation);
        } else {
            write_normal_section(maps, anchor, direction);
        }

        sections.push(anchor);
    }

    Placement {
        sections,
        endpoint_sections,
    }
}

fn section_zone_types(zones: &[u8], anchor: Vec2i, map_edge: i64) -> [u8; 4] {
    SECTION_OFFSETS.map(|offset| {
        let point = anchor + offset;

        (zones[(point.x * map_edge + point.y) as usize] as i64 & zone::TYPE_MASK) as u8
    })
}

fn restore_zone_types(zones: &mut [u8], anchor: Vec2i, types: [u8; 4], map_edge: i64) {
    for (offset, zone_type) in SECTION_OFFSETS.iter().zip(types) {
        let point = anchor + *offset;
        let index = (point.x * map_edge + point.y) as usize;
        zones[index] = ((zones[index] as i64 & zone::CORNERS_MASK) | zone_type as i64) as u8;
    }
}

/// HighwayBridges._write_bridge_endpoint: a section kind that keeps the zone types.
fn write_bridge_endpoint(maps: &mut Maps, anchor: Vec2i, kind: i64, rotation: i64) {
    let edge = maps.map_edge;
    let types = section_zone_types(maps.zones, anchor, edge);
    write_section_kind(maps, anchor, kind, rotation);
    restore_zone_types(maps.zones, anchor, types, edge);
}

fn write_normal_section(maps: &mut Maps, anchor: Vec2i, direction: i64) {
    let tile = STRAIGHT_FIRST + (direction & 1);

    for offset in SECTION_OFFSETS {
        let index = maps.index(anchor + offset);
        replace_building(maps.buildings, maps.zones, maps.misc, index, tile);
        maps.zones[index as usize] |= zone::CORNERS_MASK as u8;
    }
}

fn write_reinforced_section(maps: &mut Maps, anchor: Vec2i, kind: i64, direction: i64, rotation: i64) {
    let edge = maps.map_edge;
    let types = section_zone_types(maps.zones, anchor, edge);

    for offset in SECTION_OFFSETS {
        let index = maps.index(anchor + offset);
        replace_building(maps.buildings, maps.zones, maps.misc, index, tiles::ONRAMP_FIRST + kind);

        if direction & 1 == 0 {
            maps.flags[index as usize] &= !(flag_bits::FLIPPED as u8);
        } else {
            maps.flags[index as usize] |= flag_bits::FLIPPED as u8;
        }
    }

    set_corners(maps.zones, anchor, 2, rotation, edge);
    restore_zone_types(maps.zones, anchor, types, edge);
}

#[cfg(test)]
mod tests {
    use super::*;

    const EDGE: i64 = 128;

    /// A strip of deep water two tiles wide beside a section, as the highway
    /// terrain route test builds it.
    fn water_strip(direction: usize) -> (Vec<u8>, Vec<u8>, Vec<u8>, Vec2i) {
        let buildings = vec![0u8; (EDGE * EDGE) as usize];
        let mut terrain = vec![0u8; (EDGE * EDGE) as usize];
        let altitude = vec![0u8; (EDGE * EDGE * 2) as usize];
        let start = Vec2i::new(20, 20);
        let step = DIRECTIONS[direction];
        let side = if direction.is_multiple_of(2) {
            Vec2i::new(1, 0)
        } else {
            Vec2i::new(0, 1)
        };

        let water_start = start + [Vec2i::ZERO, Vec2i::new(1, 0), Vec2i::new(0, 1), Vec2i::ZERO][direction];

        for distance in 0..5 {
            for width in 0..2 {
                let point = water_start + scaled(step, distance) + scaled(side, width);
                terrain[(point.x * EDGE + point.y) as usize] = terrain_ids::DEEP_WATER_FLAT as u8;
            }
        }

        (buildings, terrain, altitude, start)
    }

    /// The shoreline code reads the four section tiles in the original order,
    /// and the bridge faces the opposite bank.
    #[test]
    fn shoreline_sections_face_the_water() {
        for direction in 0..4 {
            let (buildings, terrain, altitude, start) = water_strip(direction);
            let maps = BridgeMaps {
                buildings: &buildings,
                terrain: &terrain,
                altitude: &altitude,
                map_edge: EDGE,
            };

            assert_eq!(
                bridge_terrain_code(&terrain, start, EDGE),
                [0xc030, 0x9060, 0x30c0, 0x6090][direction]
            );

            let plan = plan_bridge_from_start(&maps, start, 0);
            assert!(plan.ok);
            assert_eq!((plan.direction, plan.span_length), (direction as i64, 3));
        }
    }
}
