//! Road, rail, and power line bridges over water, as NetworkBridges.

use super::{DIRECTIONS, in_bounds, scaled};
use crate::gd_object;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::tools::Maps;
use crate::sim::tools::network::{MODE_POWER, MODE_RAIL, MODE_ROAD, replace_building};
use crate::sim::tools::terrain::{land_altitude, set_land_altitude};

pub const BRIDGE_CANCELLED: i64 = -2;
pub const BRIDGE_UNSELECTED: i64 = -1;
pub const BRIDGE_WIRE: i64 = 0;
pub const BRIDGE_RAIL: i64 = 1;
pub const BRIDGE_ROAD_CAUSEWAY: i64 = 2;
pub const BRIDGE_ROAD_RAISING: i64 = 3;
pub const BRIDGE_ROAD_SUSPENSION: i64 = 4;

const BRIDGE_NAMES: [&str; 5] = ["Raised Wires", "Rail Bridge", "Causeway", "Raising Bridge", "Suspension Bridge"];
pub const BRIDGE_COSTS: [i64; 5] = [10, 75, 25, 50, 75];

/// The bridge types of each network mode: road, rail, and power.
const BRIDGE_MODE_MASKS: [i64; 3] = [0x1c, 0x02, 0x01];

/// The directions that a shoreline shape faces open water.
const BRIDGE_SHORE_DIRECTIONS: [i64; 16] = [0, 2, 4, 8, 1, 6, 12, 9, 3, 0, 0, 0, 0, 0, 0, 0];

/// A raising bridge needs a span longer than this and shorter than the next limit.
const RAISING_SPAN_FIRST: i64 = 5;
const RAISING_SPAN_END: i64 = 12;

/// A suspension bridge needs a span longer than this.
const SUSPENSION_SPAN_MINIMUM: i64 = 7;

/// A suspension bridge repeats five cable tiles.
const SUSPENSION_PATTERN: i64 = 5;

gd_object! {
    /// One bridge type that the player may choose.
    pub struct BridgeChoice as "BridgeChoice" {
        pub type_: i64 = -1,
        pub name: String = String::new(),
        pub cost_per_tile: i64 = 0,
        pub cost: i64 = 0,
    }
}

impl BridgeChoice {
    pub fn new(bridge_type: i64, name: &str, cost_per_tile: i64, span_length: i64) -> Self {
        Self {
            type_: bridge_type,
            name: name.to_string(),
            cost_per_tile,
            cost: span_length * cost_per_tile,
        }
    }
}

pub fn bridge_type_name(bridge_type: i64) -> String {
    usize::try_from(bridge_type)
        .ok()
        .and_then(|index| BRIDGE_NAMES.get(index))
        .map_or("Unknown Bridge", |name| name)
        .to_string()
}

/// A bridge from one shore across the water.
#[derive(Clone, Debug, Default)]
pub struct Plan {
    pub ok: bool,
    pub error: String,
    pub start: Vec2i,
    pub direction: i64,
    pub span_length: i64,
    pub direction_allowed: bool,
}

impl Plan {
    fn failure(message: &str, allowed: bool) -> Self {
        Self {
            error: message.to_string(),
            direction_allowed: allowed,
            ..Default::default()
        }
    }
}

/// NetworkBridges._is_bridge_wrapper_tile: open or deep water, not a channel.
pub fn is_bridge_wrapper_tile(terrain: &[u8], flags: &[u8], point: Vec2i, map_edge: i64) -> bool {
    if !in_bounds(point, map_edge) {
        return false;
    }

    let index = (point.x * map_edge + point.y) as usize;

    flags[index] as i64 & flag_bits::WATER != 0 && (terrain[index] as i64) < terrain_ids::CHANNEL_FIRST
}

/// NetworkBridges._plan_bridge_from_start: try the directions in view order.
pub fn plan_bridge_from_start(buildings: &[u8], terrain: &[u8], start: Vec2i, view_rotation: i64, map_edge: i64) -> Plan {
    for direction in [
        view_rotation & 3,
        (view_rotation + 2) & 3,
        (view_rotation + 1) & 3,
        (view_rotation - 1) & 3,
    ] {
        let plan = scan_bridge(buildings, terrain, start, direction, true, map_edge);

        if plan.direction_allowed {
            return plan;
        }
    }

    Plan::failure("bridge does not face open water", false)
}

/// NetworkBridges._scan_bridge: walk from the shoreline to the other bank.
pub fn scan_bridge(buildings: &[u8], terrain: &[u8], start: Vec2i, direction: i64, require_direction: bool, map_edge: i64) -> Plan {
    if !in_bounds(start, map_edge) {
        return Plan::failure("bridge start is outside the city", false);
    }

    let terrain_id = terrain[(start.x * map_edge + start.y) as usize] as i64;

    if !(terrain_ids::SHORE_FIRST..terrain_ids::CHANNEL_FIRST).contains(&terrain_id) {
        return Plan::failure("bridge must start on shoreline terrain", false);
    }

    let direction_mask = BRIDGE_SHORE_DIRECTIONS[(terrain_id & terrain_ids::SHAPE_MASK) as usize];

    if direction_mask == 0 {
        return Plan::failure("bridge shoreline shape is not eligible", false);
    }

    let direction_allowed = direction_mask & (1 << direction) != 0;

    if require_direction && !direction_allowed {
        return Plan::failure("", false);
    }

    let mut span_length = 0;
    let mut checked = start;

    loop {
        if span_length != 0 && buildings[(checked.x * map_edge + checked.y) as usize] as i64 != tiles::EMPTY {
            return Plan::failure("bridge path contains a structure", true);
        }

        checked = checked + DIRECTIONS[direction as usize];

        if !in_bounds(checked, map_edge) {
            return Plan::failure("bridge does not reach another bank", true);
        }

        span_length += 1;
        let checked_terrain = terrain[(checked.x * map_edge + checked.y) as usize] as i64;

        if checked_terrain <= terrain_ids::LAND_LAST || checked_terrain >= terrain_ids::CHANNEL_FIRST {
            break;
        }
    }

    Plan {
        ok: true,
        error: String::new(),
        start,
        direction,
        span_length,
        direction_allowed: true,
    }
}

/// NetworkBridges.bridge_choices: the bridge types of `mode` for this span.
pub fn bridge_choices(span_length: i64, mode: i64) -> Vec<BridgeChoice> {
    let mut available = 0x07;

    if (RAISING_SPAN_FIRST..RAISING_SPAN_END).contains(&span_length) {
        available |= 0x08;
    }

    if span_length >= SUSPENSION_SPAN_MINIMUM {
        available |= 0x10;
    }

    available &= BRIDGE_MODE_MASKS[mode as usize];

    (0..BRIDGE_NAMES.len() as i64)
        .filter(|bridge_type| available & (1 << bridge_type) != 0)
        .map(|bridge_type| {
            BridgeChoice::new(
                bridge_type,
                BRIDGE_NAMES[bridge_type as usize],
                BRIDGE_COSTS[bridge_type as usize],
                span_length,
            )
        })
        .collect()
}

/// NetworkBridges._place_bridge. Returns the bridge points, banks included.
pub fn place_bridge(maps: &mut Maps, plan: &Plan, bridge_type: i64) -> Vec<Vec2i> {
    let edge = maps.map_edge;
    let start = plan.start;
    let direction = plan.direction;
    let span_length = plan.span_length;
    let offset = DIRECTIONS[direction as usize];
    let mut result = Vec::new();

    place_bridge_bank(maps, start, direction, bridge_type, true);
    result.push(start);

    for span_index in 1..span_length - 1 {
        let point = start + scaled(offset, span_index);
        let index = point.x * edge + point.y;

        if direction & 1 != 0 {
            maps.flags[index as usize] |= flag_bits::FLIPPED as u8;
        }

        replace_building(
            maps.buildings,
            maps.zones,
            maps.misc,
            index,
            bridge_tile(bridge_type, span_length, span_index, direction),
        );

        if bridge_type == BRIDGE_WIRE {
            maps.flags[index as usize] |= flag_bits::POWERABLE as u8;
        }

        result.push(point);
    }

    let finish = start + scaled(offset, 1.max(span_length - 1));
    place_bridge_bank(maps, finish, direction, bridge_type, false);
    result.push(finish);

    result
}

/// NetworkBridges._place_bridge_bank: slope the bank up to the deck and
/// place the network tile on it.
fn place_bridge_bank(maps: &mut Maps, point: Vec2i, direction: i64, bridge_type: i64, first: bool) {
    let index = point.x * maps.map_edge + point.y;
    let i = index as usize;

    if (maps.terrain[i] as i64) < terrain_ids::SURFACE_WATER_FIRST {
        let raised = land_altitude(maps.altitude, index) + 1;
        set_land_altitude(maps.altitude, index, raised);
    }

    maps.terrain[i] = (((direction + if first { 1 } else { -1 }) & 3) + 1) as u8;
    maps.flags[i] &= !(flag_bits::WATER as u8);

    let mode = if bridge_type == BRIDGE_RAIL {
        MODE_RAIL
    } else if bridge_type >= BRIDGE_ROAD_CAUSEWAY {
        MODE_ROAD
    } else {
        MODE_POWER
    };

    super::network_edit::place_surface(maps, point, mode, direction, false);
}

/// NetworkBridges._bridge_tile: the deck tile at `span_index`.
pub fn bridge_tile(bridge_type: i64, span_length: i64, span_index: i64, direction: i64) -> i64 {
    match bridge_type {
        BRIDGE_WIRE => tiles::POWER_BRIDGE,
        BRIDGE_RAIL => {
            let middle = span_length / 2;

            if span_index != middle && (middle - 2..=middle + 2).contains(&span_index) {
                tiles::RAIL_BRIDGE_PYLON
            } else {
                tiles::RAIL_BRIDGE
            }
        }
        BRIDGE_ROAD_RAISING => {
            let quarter = (span_length + 1) / 4;

            if span_index < quarter {
                tiles::ROAD_BRIDGE
            } else if span_index == quarter {
                tiles::RAISING_BRIDGE_TOWER
            } else if span_index < span_length - quarter - 1 {
                tiles::RAISING_BRIDGE_CLOSED
            } else if span_length - quarter - span_index == 1 {
                tiles::RAISING_BRIDGE_TOWER
            } else {
                tiles::ROAD_BRIDGE
            }
        }
        BRIDGE_ROAD_SUSPENSION => {
            let pattern_span = (span_length - 2) % SUSPENSION_PATTERN + 2;
            let first_pattern = pattern_span / 2;
            let pattern_end = span_length - (pattern_span + 1) / 2;

            if span_index < first_pattern || span_index >= pattern_end {
                return tiles::ROAD_BRIDGE;
            }

            let pattern_index = (span_index - first_pattern) % SUSPENSION_PATTERN;

            if direction == 0 || direction == 3 {
                tiles::SUSPENSION_BRIDGE_1 + pattern_index
            } else {
                tiles::SUSPENSION_BRIDGE_5 - pattern_index
            }
        }
        _ => tiles::ROAD_BRIDGE,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Raising bridges need a span of 5 to 11 tiles; suspension bridges 7 or more.
    #[test]
    fn road_bridge_choices_follow_the_span() {
        let counts: Vec<usize> = [4, 5, 7, 12].iter().map(|&span| bridge_choices(span, MODE_ROAD).len()).collect();

        assert_eq!(counts, vec![1, 2, 3, 2]);
        assert_eq!(
            bridge_choices(8, MODE_RAIL).iter().map(|choice| choice.type_).collect::<Vec<_>>(),
            vec![BRIDGE_RAIL]
        );
        assert_eq!(bridge_choices(8, MODE_POWER)[0].cost, 8 * BRIDGE_COSTS[BRIDGE_WIRE as usize]);
    }
}
