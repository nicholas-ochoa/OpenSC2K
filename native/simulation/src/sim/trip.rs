//! Transport trips, as TransportTripSearch and TransportTripSteps.
//!
//! The search is a bounded Dijkstra queue over cost buckets. Equal-cost choices
//! use the process random generator, so the call order must match the original.

use std::collections::HashMap;
use std::hash::{BuildHasherDefault, Hasher};

use super::geom::Vec2i;
use super::grid;
use super::ids::building_tile_ids as tiles;
use super::ids::sc2altitude_layout as altitude;
use super::ids::sc2overlay_layout;
use super::ids::sc2zone_layout as zone_layout;
use super::network;
use super::overlay;
use super::random::SimRandom;

pub const CONNECTION_LABEL: i64 = sc2overlay_layout::CONNECTION_MARKER;
pub const ROAD_MODE: i64 = 0;
pub const HIGHWAY_MODE: i64 = 1;
pub const ROAD_TUNNEL_MODE: i64 = 2;
pub const ROAD_BRIDGE_MODE: i64 = 3;
pub const BUS_ROAD_MODE: i64 = 4;
pub const BUS_HIGHWAY_MODE: i64 = 5;
pub const BUS_TUNNEL_MODE: i64 = 6;
pub const BUS_BRIDGE_MODE: i64 = 7;
pub const BUS_STOP_MODE: i64 = 8;
pub const BUS_RAIL_MODE: i64 = 9;
pub const RAIL_STATION_MODE: i64 = 10;
pub const SUBWAY_STATION_MODE: i64 = 11;
pub const RAIL_MODE: i64 = 12;
pub const SUBWAY_MODE: i64 = 13;
pub const ADVANCE_BLOCKED: i64 = -1;
pub const ADVANCE_SUCCESS: i64 = -2;
pub const POINT_INDEX_MASK: i64 = 0x3fff;
pub const LARGE_POINT_INDEX_MASK: i64 = 0xfffff;

pub const TRANSPORT_OFFSETS: [Vec2i; 24] = [
    Vec2i::new(0, 1),
    Vec2i::new(1, 0),
    Vec2i::new(0, -1),
    Vec2i::new(-1, 0),
    Vec2i::new(0, 2),
    Vec2i::new(2, 0),
    Vec2i::new(0, -2),
    Vec2i::new(-2, 0),
    Vec2i::new(0, 3),
    Vec2i::new(3, 0),
    Vec2i::new(0, -3),
    Vec2i::new(-3, 0),
    Vec2i::new(1, 1),
    Vec2i::new(-1, 1),
    Vec2i::new(1, -1),
    Vec2i::new(-1, -1),
    Vec2i::new(2, 1),
    Vec2i::new(-2, 1),
    Vec2i::new(2, -1),
    Vec2i::new(-2, -1),
    Vec2i::new(1, 2),
    Vec2i::new(-1, 2),
    Vec2i::new(1, -2),
    Vec2i::new(-1, -2),
];
pub const DIRECTIONS: [Vec2i; 4] = [Vec2i::new(0, -1), Vec2i::new(1, 0), Vec2i::new(0, 1), Vec2i::new(-1, 0)];
pub const FORWARD_DIRECTION_MASKS: [i64; 4] = [0x0b, 0x07, 0x0e, 0x0d];
pub const DESTINATION_ZONE_MASKS: [i64; 8] = [0xffff, 0xfff8, 0xfff8, 0xffe6, 0xffe6, 0xff9e, 0xff9e, 0];
pub const WALK_ACCESS_MODES: i64 = (1 << ROAD_MODE) | (1 << BUS_ROAD_MODE) | (1 << BUS_STOP_MODE) | (1 << BUS_RAIL_MODE);
pub const TUNNEL_HEADING_MODES: i64 = (1 << ROAD_TUNNEL_MODE) | (1 << BUS_TUNNEL_MODE);
pub const HEADING_MODES: i64 = (1 << ROAD_BRIDGE_MODE) | (1 << BUS_BRIDGE_MODE) | TUNNEL_HEADING_MODES;
pub const ANY_RCI_ZONE_MASK: i64 = 0x7e;
pub const LANE_CORNERS: [Vec2i; 4] = [Vec2i::new(0, 0), Vec2i::new(0, 1), Vec2i::new(1, 1), Vec2i::new(1, 0)];
pub const INGRESS_CORNERS: [i64; 4] = [0, 3, 2, 1];
pub const EGRESS_CORNERS: [i64; 4] = [3, 2, 1, 0];

/// The corrected lane model. Port bits: north, east, south, west.
pub fn highway_ports(tile: i64) -> i64 {
    match tile {
        tiles::HIGHWAY_STRAIGHT_1 => 5,
        tiles::HIGHWAY_STRAIGHT_2 => 10,
        tiles::HIGHWAY_ROAD_CROSSING_1 => 5,
        tiles::HIGHWAY_ROAD_CROSSING_2 => 10,
        tiles::HIGHWAY_RAIL_CROSSING_1 => 5,
        tiles::HIGHWAY_RAIL_CROSSING_2 => 10,
        tiles::HIGHWAY_POWER_CROSSING_1 => 5,
        tiles::HIGHWAY_POWER_CROSSING_2 => 10,
        tiles::HIGHWAY_SLOPE_1 => 10,
        tiles::HIGHWAY_SLOPE_2 => 5,
        tiles::HIGHWAY_SLOPE_3 => 10,
        tiles::HIGHWAY_SLOPE_4 => 5,
        tiles::HIGHWAY_CURVE_1 => 3,
        tiles::HIGHWAY_CURVE_2 => 6,
        tiles::HIGHWAY_CURVE_3 => 12,
        tiles::HIGHWAY_CURVE_4 => 9,
        tiles::HIGHWAY_INTERSECTION => 15,
        _ => 0,
    }
}

/// The mode sits above the start index. 128 tile maps keep the original 14 bits.
pub fn point_shift(map_edge: i64) -> i64 {
    if map_edge == 128 { 14 } else { 20 }
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct TripResult {
    pub ok: bool,
    pub error: String,
    pub reached_destination: bool,
    pub cost: i64,
    pub path_length: i64,
    pub used_bus: bool,
    pub used_rail: bool,
    pub used_subway: bool,
    pub expanded_states: i64,
}

impl TripResult {
    pub fn failure(message: &str) -> Self {
        Self { error: message.to_string(), ..Default::default() }
    }
}

/// The maps that a trip reads. `altitude` is the ALTM payload.
pub struct TripMaps<'a> {
    pub buildings: &'a [u8],
    pub zones: &'a [u8],
    pub underground: &'a [u8],
    pub text_overlays: &'a [u8],
    pub altitude: &'a [u8],
    pub map_edge: i64,
}

impl TripMaps<'_> {
    /// The tunnel field is in the high byte of the ALTM word.
    #[inline]
    fn has_tunnel(&self, index: i64) -> bool {
        ((self.altitude[index as usize * 2] as i64) << 8) & altitude::TUNNEL_FIELD_MASK != 0
    }
}

/// A fast hasher for state keys. Keys are small unique integers.
#[derive(Default)]
pub struct KeyHasher(u64);

impl Hasher for KeyHasher {
    fn finish(&self) -> u64 {
        self.0
    }

    fn write(&mut self, bytes: &[u8]) {
        for byte in bytes {
            self.0 = (self.0.rotate_left(5) ^ *byte as u64).wrapping_mul(0x51_7cc1_b727_220a_95);
        }
    }

    fn write_i64(&mut self, value: i64) {
        self.0 = (value as u64).wrapping_mul(0x9e37_79b9_7f4a_7c15);
    }
}

pub type KeyMap = HashMap<i64, i64, BuildHasherDefault<KeyHasher>>;

/// Search buffers reused across the trips of one growth scan.
#[derive(Default)]
pub struct TripScratch {
    points: Vec<Vec2i>,
    indices: Vec<i64>,
    modes: Vec<i64>,
    costs: Vec<i64>,
    headings: Vec<i64>,
    parents: Vec<i64>,
    pending: Vec<Vec<usize>>,
    best: KeyMap,
    path: Vec<usize>,
}

pub fn valid_inputs(maps: &TripMaps, traffic: &[u8]) -> bool {
    let cells = maps.map_edge * maps.map_edge;

    maps.buildings.len() as i64 == cells
        && maps.zones.len() as i64 == cells
        && maps.underground.len() as i64 == cells
        && overlay::count(maps.text_overlays) == cells
        && maps.altitude.len() as i64 == cells * 2
        && grid::valid(traffic, maps.map_edge, 2)
}

#[inline]
fn state_key(index: i64, mode: i64, heading: i64) -> i64 {
    (index * 14 + mode) * 5 + heading
}

#[inline]
fn index_of(point: Vec2i, map_edge: i64) -> i64 {
    if point.x < 0 || point.x >= map_edge || point.y < 0 || point.y >= map_edge {
        return -1;
    }

    point.x * map_edge + point.y
}

/// The same catchment as the reach query, stopping at the first match.
fn has_walking_destination(zones: &[u8], point: Vec2i, mode: i64, origin_zone: i64, map_edge: i64) -> bool {
    if (WALK_ACCESS_MODES >> mode) & 1 == 0 {
        return false;
    }

    let zone_mask = DESTINATION_ZONE_MASKS[origin_zone as usize];

    for offset in TRANSPORT_OFFSETS {
        let target = point + offset;

        if target.x < 0 || target.x >= map_edge || target.y < 0 || target.y >= map_edge {
            continue;
        }

        if zone_mask & (1 << (zones[(target.x * map_edge + target.y) as usize] as i64 & 15)) != 0 {
            return true;
        }
    }

    false
}

/// The walking destinations of a reach query. `any_rci` accepts every RCI zone.
pub fn walking_destinations(
    zones: &[u8],
    point: Vec2i,
    mode: i64,
    origin_zone: i64,
    map_edge: i64,
    any_rci: bool,
) -> Vec<Vec2i> {
    let mut result = Vec::new();

    if (WALK_ACCESS_MODES >> mode) & 1 == 0 {
        return result;
    }

    let zone_mask = if any_rci { ANY_RCI_ZONE_MASK } else { DESTINATION_ZONE_MASKS[origin_zone as usize] };

    for offset in TRANSPORT_OFFSETS {
        let target = point + offset;

        if target.x < 0 || target.x >= map_edge || target.y < 0 || target.y >= map_edge {
            continue;
        }

        if zone_mask & (1 << (zones[(target.x * map_edge + target.y) as usize] as i64 & 15)) != 0 {
            result.push(target);
        }
    }

    result
}

/// The first nearby transport tile, with its mode above the flat index.
pub fn find_transport(buildings: &[u8], origin: Vec2i, map_edge: i64) -> i64 {
    if buildings.len() as i64 != map_edge * map_edge {
        return -1;
    }

    let shift = point_shift(map_edge);

    for offset in TRANSPORT_OFFSETS {
        let index = index_of(origin + offset, map_edge);

        if index < 0 {
            continue;
        }

        let tile = buildings[index as usize] as i64;

        if network::surface_road(tile) {
            return (ROAD_MODE << shift) | index;
        }

        if tile == tiles::BUS_DEPOT {
            return (BUS_STOP_MODE << shift) | index;
        }

        if tile == tiles::RAIL_STATION {
            return (RAIL_STATION_MODE << shift) | index;
        }

        if tile == tiles::SUBWAY_STATION {
            return (SUBWAY_STATION_MODE << shift) | index;
        }
    }

    -1
}

pub fn has_nearby_transport(buildings: &[u8], origin: Vec2i, map_edge: i64) -> bool {
    find_transport(buildings, origin, map_edge) >= 0
}

/// A growth trip. It writes traffic along a completed path. `walking_access`
/// caches the catchment per tile: 0 unknown, 1 no destination, 2 destination.
#[allow(clippy::too_many_arguments)]
pub fn trace(
    maps: &TripMaps,
    traffic: &mut [u8],
    origin: Vec2i,
    zone: i64,
    traffic_weight: i64,
    random: &mut SimRandom,
    maximum_cost: i64,
    start_override: i64,
    walking_access: Option<&mut [u8]>,
    scratch: &mut TripScratch,
) -> TripResult {
    let map_edge = maps.map_edge;
    let mut result = TripResult::default();

    if zone < 0 || zone >= DESTINATION_ZONE_MASKS.len() as i64 {
        result.error = "zone is outside the supported range".to_string();
        return result;
    }

    if traffic_weight < 0 {
        result.error = "traffic weight cannot be negative".to_string();
        return result;
    }

    let start = if start_override >= 0 { start_override } else { find_transport(maps.buildings, origin, map_edge) };

    if start < 0 {
        result.ok = true;
        return result;
    }

    let mut limit = maximum_cost.max(0);

    if traffic_weight == 1 {
        limit -= limit / 4;
    }

    let mut walking_access = walking_access;
    let turn_direction = if random.next_u15() & 1 != 0 { 1 } else { 3 };
    let start_index = start & if map_edge == 128 { POINT_INDEX_MASK } else { LARGE_POINT_INDEX_MASK };
    let TripScratch { points, indices, modes, costs, headings, parents, pending, best, path } = scratch;
    points.clear();
    indices.clear();
    modes.clear();
    costs.clear();
    headings.clear();
    parents.clear();
    best.clear();

    for bucket in pending.iter_mut() {
        bucket.clear();
    }

    if pending.len() < limit.max(1) as usize {
        pending.resize_with(limit.max(1) as usize, Vec::new);
    }

    points.push(Vec2i::new(start_index / map_edge, start_index % map_edge));
    indices.push(start_index);
    modes.push(start >> point_shift(map_edge));
    costs.push(0);
    headings.push(4);
    parents.push(-1);

    if limit > 0 {
        pending[0].push(0);
    }

    best.insert(state_key(start_index, modes[0], 4), 0);
    let mut winner: i64 = -1;
    let mut expanded = 0;

    for cost in 0..limit {
        let mut position = 0;

        // Growth trips can append to this bucket. Read its length each time.
        while position < pending[cost as usize].len() {
            let state_index = pending[cost as usize][position];
            position += 1;
            let point = points[state_index];
            let point_index = indices[state_index];
            let mode = modes[state_index];
            let heading = headings[state_index];
            let key = state_key(point_index, mode, heading);

            if best.get(&key).copied() != Some(cost) {
                continue;
            }

            expanded += 1;
            let walks = (WALK_ACCESS_MODES >> mode) & 1 != 0;

            let reached = match walking_access.as_deref_mut() {
                Some(access) => {
                    if walks && access[point_index as usize] == 0 {
                        let found = has_walking_destination(maps.zones, point, mode, zone, map_edge);
                        access[point_index as usize] = 1 + found as u8;
                    }

                    walks && access[point_index as usize] == 2
                }
                None => has_walking_destination(maps.zones, point, mode, zone, map_edge),
            };

            if reached {
                if winner < 0 {
                    winner = state_index as i64;
                }

                break;
            }

            let mut direction = random.next_u15() & 3;
            let mut direction_mask = 0x0f;

            if heading < 4 {
                direction_mask = if (TUNNEL_HEADING_MODES >> mode) & 1 != 0 {
                    FORWARD_DIRECTION_MASKS[heading as usize]
                } else {
                    1 << heading
                };
            }

            for _ in 0..4 {
                direction = (direction + turn_direction) & 3;

                if direction_mask & (1 << direction) == 0 {
                    continue;
                }

                let next_point = point + DIRECTIONS[direction as usize];
                let next_index = index_of(next_point, map_edge);
                let advance = advance(maps, point, next_point, point_index, next_index, mode, zone);

                if advance == ADVANCE_SUCCESS {
                    if winner < 0 {
                        winner = state_index as i64;
                    }

                    break;
                }

                if advance == ADVANCE_BLOCKED {
                    continue;
                }

                let next_cost = cost + (advance & 0xff);

                if next_cost >= limit {
                    continue;
                }

                let next_mode = advance >> 8;
                let next_heading = if (HEADING_MODES >> next_mode) & 1 != 0 { direction } else { 4 };
                let next_key = state_key(next_index, next_mode, next_heading);

                if next_cost >= best.get(&next_key).copied().unwrap_or(limit) {
                    continue;
                }

                best.insert(next_key, next_cost);
                pending[next_cost as usize].push(points.len());
                points.push(next_point);
                indices.push(next_index);
                modes.push(next_mode);
                costs.push(next_cost);
                headings.push(next_heading);
                parents.push(state_index as i64);
            }

            if winner >= 0 {
                break;
            }
        }

        if winner >= 0 {
            break;
        }
    }

    // Record the path and add its traffic.
    path.clear();
    let mut cursor = winner;

    while cursor >= 0 {
        path.push(cursor as usize);
        cursor = parents[cursor as usize];
    }

    path.reverse();
    let mut used_bus = false;
    let mut used_rail = false;
    let mut used_subway = false;

    if winner >= 0 && traffic_weight > 0 {
        for &index in path.iter() {
            let mode = modes[index];
            used_bus = used_bus || mode == BUS_STOP_MODE;
            used_rail = used_rail || mode == RAIL_STATION_MODE;
            used_subway = used_subway || mode == SUBWAY_STATION_MODE;

            if mode == ROAD_MODE || mode == HIGHWAY_MODE || mode == ROAD_BRIDGE_MODE {
                let point = points[index];
                let traffic_index = grid::index(traffic, map_edge, point.x, point.y);
                let slot = super::bytes::slot(traffic.len(), traffic_index);
                traffic[slot] = (traffic[slot] as i64 + traffic_weight).min(0xff) as u8;
            }
        }
    }

    result.ok = true;
    result.reached_destination = winner >= 0;
    result.cost = if winner >= 0 { costs[winner as usize] } else { 0 };
    result.path_length = path.len() as i64;
    result.used_bus = used_bus;
    result.used_rail = used_rail;
    result.used_subway = used_subway;
    result.expanded_states = expanded;
    result
}

#[inline]
fn moved(mode: i64, cost: i64) -> i64 {
    (mode << 8) | cost
}

pub fn is_road_bridge(tile: i64) -> bool {
    (tiles::SUSPENSION_BRIDGE_1..=tiles::POWER_BRIDGE).contains(&tile)
        || tile == tiles::HIGHWAY_BRIDGE
        || tile == tiles::REINFORCED_HIGHWAY_BRIDGE
}

pub fn is_highway_span(tile: i64) -> bool {
    (tiles::HIGHWAY_SLOPE_FIRST..=tiles::HIGHWAY_INTERSECTION).contains(&tile)
        || (tiles::HIGHWAY_STRAIGHT_1..=tiles::HIGHWAY_POWER_CROSSING_2).contains(&tile)
}

#[inline]
fn is_onramp(tile: i64) -> bool {
    (tiles::ONRAMP_FIRST..=tiles::ONRAMP_LAST).contains(&tile)
}

#[inline]
fn is_tunnel(tile: i64) -> bool {
    (tiles::TUNNEL_FIRST..=tiles::TUNNEL_LAST).contains(&tile)
}

/// One step of a trip. A next index of -1 is a map exit.
pub fn advance(
    maps: &TripMaps,
    current: Vec2i,
    next_point: Vec2i,
    current_index: i64,
    index: i64,
    mode: i64,
    origin_zone: i64,
) -> i64 {
    let map_edge = maps.map_edge;

    if index < 0 {
        if current_index >= 0 && overlay::read(maps.text_overlays, current_index) == CONNECTION_LABEL {
            return ADVANCE_SUCCESS;
        }

        return ADVANCE_BLOCKED;
    }

    let tile = maps.buildings[index as usize] as i64;
    let destination = DESTINATION_ZONE_MASKS[origin_zone as usize]
        & (1 << (maps.zones[index as usize] as i64 & zone_layout::TYPE_MASK))
        != 0;
    let road = network::surface_road(tile);

    match mode {
        ROAD_MODE => {
            if is_highway_span(tile) && highway_step(maps.buildings, current, next_point, map_edge) {
                let current_tile = maps.buildings[current_index as usize] as i64;

                if is_onramp(current_tile) {
                    return moved(HIGHWAY_MODE, 1);
                }
            }

            if destination {
                return ADVANCE_SUCCESS;
            }

            if is_tunnel(tile) {
                return moved(ROAD_TUNNEL_MODE, 3);
            }

            if is_road_bridge(tile) {
                return moved(ROAD_BRIDGE_MODE, 3);
            }

            if is_onramp(tile) {
                return moved(HIGHWAY_MODE, 2);
            }

            if road {
                return moved(ROAD_MODE, 3);
            }

            if tile == tiles::BUS_DEPOT {
                return moved(BUS_STOP_MODE, 4);
            }

            if tile == tiles::RAIL_STATION {
                return moved(RAIL_STATION_MODE, 4);
            }

            if tile == tiles::SUBWAY_STATION {
                return moved(SUBWAY_STATION_MODE, 4);
            }
        }
        HIGHWAY_MODE => {
            if is_highway_span(tile) && highway_step(maps.buildings, current, next_point, map_edge) {
                return moved(HIGHWAY_MODE, 1);
            }

            if is_onramp(tile) && highway_exit(maps.buildings, current, next_point, map_edge) {
                return moved(ROAD_MODE, 1);
            }
        }
        ROAD_TUNNEL_MODE => {
            if maps.has_tunnel(index) {
                return moved(ROAD_TUNNEL_MODE, 3);
            }

            if road {
                return moved(ROAD_MODE, 3);
            }
        }
        ROAD_BRIDGE_MODE => {
            if is_road_bridge(tile) {
                return moved(ROAD_BRIDGE_MODE, 3);
            }

            if road {
                return moved(ROAD_MODE, 3);
            }
        }
        BUS_ROAD_MODE => {
            if destination {
                return ADVANCE_SUCCESS;
            }

            if is_tunnel(tile) {
                return moved(BUS_TUNNEL_MODE, 2);
            }

            if is_road_bridge(tile) {
                return moved(BUS_BRIDGE_MODE, 2);
            }

            if is_onramp(tile) {
                return moved(BUS_HIGHWAY_MODE, 2);
            }

            if road {
                return moved(BUS_ROAD_MODE, 2);
            }

            if tile == tiles::BUS_DEPOT {
                return moved(BUS_RAIL_MODE, 4);
            }

            if tile == tiles::RAIL_STATION {
                return moved(RAIL_STATION_MODE, 4);
            }

            if tile == tiles::SUBWAY_STATION {
                return moved(SUBWAY_STATION_MODE, 4);
            }
        }
        BUS_HIGHWAY_MODE => {
            if is_highway_span(tile) && highway_step(maps.buildings, current, next_point, map_edge) {
                return moved(BUS_HIGHWAY_MODE, 1);
            }

            if is_onramp(tile) && highway_exit(maps.buildings, current, next_point, map_edge) {
                return moved(BUS_ROAD_MODE, 1);
            }
        }
        BUS_TUNNEL_MODE => {
            if maps.has_tunnel(index) {
                return moved(BUS_TUNNEL_MODE, 2);
            }

            if road {
                return moved(BUS_ROAD_MODE, 2);
            }
        }
        BUS_BRIDGE_MODE => {
            if is_road_bridge(tile) {
                return moved(BUS_BRIDGE_MODE, 2);
            }

            if road {
                return moved(BUS_ROAD_MODE, 2);
            }
        }
        BUS_STOP_MODE => {
            if destination {
                return ADVANCE_SUCCESS;
            }

            if tile == tiles::BUS_DEPOT {
                return moved(BUS_STOP_MODE, 4);
            }

            if road {
                return moved(BUS_ROAD_MODE, 2);
            }
        }
        BUS_RAIL_MODE => {
            if destination {
                return ADVANCE_SUCCESS;
            }

            if tile == tiles::BUS_DEPOT || tile == tiles::RAIL_STATION {
                return moved(BUS_RAIL_MODE, 4);
            }

            if road {
                return moved(ROAD_MODE, 3);
            }
        }
        RAIL_STATION_MODE => {
            if tile == tiles::RAIL_STATION {
                return moved(RAIL_STATION_MODE, 4);
            }

            if network::rail(tile) {
                return moved(RAIL_MODE, 1);
            }
        }
        SUBWAY_STATION_MODE => {
            if network::subway(maps.underground[index as usize] as i64) {
                return moved(SUBWAY_MODE, 1);
            }
        }
        RAIL_MODE => {
            if tile == tiles::RAIL_STATION {
                return moved(BUS_RAIL_MODE, 4);
            }

            if network::rail(tile) {
                return moved(RAIL_MODE, 1);
            }

            if tile > tiles::DESALINIZATION {
                return ADVANCE_SUCCESS;
            }
        }
        SUBWAY_MODE => {
            if tile == tiles::SUBWAY_STATION {
                return moved(BUS_RAIL_MODE, 4);
            }

            if network::subway(maps.underground[index as usize] as i64) {
                return moved(SUBWAY_MODE, 1);
            }
        }
        _ => {}
    }

    ADVANCE_BLOCKED
}

fn find_direction(delta: Vec2i) -> i64 {
    DIRECTIONS.iter().position(|&direction| direction == delta).map_or(-1, |position| position as i64)
}

fn find_corner(corner: Vec2i) -> i64 {
    LANE_CORNERS.iter().position(|&lane| lane == corner).map_or(-1, |position| position as i64)
}

/// Lane corners come from coordinate parity. This is not a plain flood fill.
pub fn highway_step(buildings: &[u8], current: Vec2i, next_point: Vec2i, map_edge: i64) -> bool {
    let tile = super::bytes::at(buildings, index_of(current, map_edge));
    let next_tile = super::bytes::at(buildings, index_of(next_point, map_edge));
    let direction = find_direction(next_point - current);
    let ports = highway_ports(tile);
    let next_ports = highway_ports(next_tile);
    let corner = find_corner(Vec2i::new(current.x & 1, current.y & 1));
    let next_corner = find_corner(Vec2i::new(next_point.x & 1, next_point.y & 1));

    if is_onramp(tile) {
        // Ramps enter the adjacent outside lane. They cannot cross the median.
        return ramp_side(next_point, current, next_ports);
    }

    if (current.x & !1) != (next_point.x & !1) || (current.y & !1) != (next_point.y & !1) {
        return ports & (1 << direction) != 0
            && next_ports & (1 << ((direction + 2) & 3)) != 0
            && corner == EGRESS_CORNERS[direction as usize];
    }

    if next_corner != (corner + 1) % 4 {
        return false;
    }

    // Cross into the return lane only at an unconnected highway endpoint.
    for exit_direction in 0..4 {
        let exit_bit = 1 << exit_direction;

        if corner != EGRESS_CORNERS[exit_direction as usize] || ports & next_ports & exit_bit == 0 {
            continue;
        }

        let forward = current + DIRECTIONS[exit_direction as usize];
        let forward_index = index_of(forward, map_edge);
        let forward_ports =
            if forward_index >= 0 { highway_ports(buildings[forward_index as usize] as i64) } else { 0 };

        if forward_ports & (1 << ((exit_direction + 2) & 3)) == 0 {
            return true;
        }
    }

    for entry in 0..4 {
        if ports & (1 << entry) == 0 {
            continue;
        }

        for leave in 0..4 {
            if leave == entry || ports & (1 << leave) == 0 {
                continue;
            }

            let mut step = INGRESS_CORNERS[entry];

            while step != EGRESS_CORNERS[leave] {
                if step == corner {
                    return true;
                }

                step = (step + 1) % 4;
            }
        }
    }

    false
}

fn ramp_side(highway: Vec2i, ramp: Vec2i, ports: i64) -> bool {
    let delta = ramp - highway;

    if ports == 5 {
        return delta == Vec2i::new(if highway.x & 1 == 0 { -1 } else { 1 }, 0);
    }

    if ports == 10 {
        return delta == Vec2i::new(0, if highway.y & 1 == 0 { -1 } else { 1 });
    }

    false
}

fn highway_exit(buildings: &[u8], current: Vec2i, next_point: Vec2i, map_edge: i64) -> bool {
    ramp_side(current, next_point, highway_ports(super::bytes::at(buildings, index_of(current, map_edge))))
}
