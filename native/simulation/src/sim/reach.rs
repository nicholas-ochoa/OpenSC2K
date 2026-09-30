//! Route exploration for the trip reach overlay, as TripReachAnalysis and the
//! reach mode of TransportTripSearch.trace.

use std::collections::HashMap;

use super::city::City;
use super::geom::{Rect2i, Vec2i};
use super::ids::building_tile_ids as tiles;
use super::ids::sc2misc_layout as misc_layout;
use super::ids::sc2tile_flags as flag_bits;
use super::random::SimRandom;
use super::tools::demolish::{building_area, find_building_site};
use super::trip::{self, TripMaps};
use super::value::{ToValue, Value};
use crate::gd_object;

gd_object! {
    pub struct ReachNode as "TransportTripReachResult.ReachNode" {
        pub point: Vec2i = Vec2i::ZERO,
        pub mode: i64 = 0,
        pub cost: i64 = 0,
    }
}

gd_object! {
    pub struct Link as "TransportTripReachResult.Link" {
        pub from: Vec2i = Vec2i::ZERO,
        pub to: Vec2i = Vec2i::ZERO,
        pub from_mode: i64 = 0,
        pub mode: i64 = 0,
        pub cost: i64 = 0,
    }
}

/// An insertion-ordered point map, as a Dictionary[Vector2i, T].
#[derive(Clone, Debug, Default)]
pub struct PointMap<T> {
    order: Vec<(Vec2i, T)>,
    positions: HashMap<Vec2i, usize>,
}

impl<T: Copy> PointMap<T> {
    pub fn get(&self, point: Vec2i) -> Option<T> {
        self.positions.get(&point).map(|position| self.order[*position].1)
    }

    pub fn set(&mut self, point: Vec2i, value: T) {
        match self.positions.get(&point) {
            Some(position) => self.order[*position].1 = value,
            None => {
                self.positions.insert(point, self.order.len());
                self.order.push((point, value));
            }
        }
    }

    pub fn has(&self, point: Vec2i) -> bool {
        self.positions.contains_key(&point)
    }

    pub fn is_empty(&self) -> bool {
        self.order.is_empty()
    }

    pub fn iter(&self) -> impl Iterator<Item = &(Vec2i, T)> {
        self.order.iter()
    }
}

impl<T: ToValue> ToValue for PointMap<T> {
    fn to_value(&self) -> Value {
        Value::Dict(
            self.order
                .iter()
                .map(|(point, value)| (Value::Vec2i(*point), value.to_value()))
                .collect(),
        )
    }
}

/// TransportTripReachResult.
#[derive(Default)]
pub struct ReachResult {
    pub trip: trip::TripResult,
    pub reachable: Vec<ReachNode>,
    pub links: Vec<Link>,
    pub destinations: PointMap<i64>,
    pub limit_points: PointMap<&'static str>,
    pub limit: i64,
    pub start: Vec2i,
    pub origin: Vec2i,
    pub clicked: Vec2i,
    pub summary: Vec<String>,
    pub rci: bool,
    pub powered: bool,
    pub demand: i64,
    pub access_tiles: PointMap<i64>,
    pub origin_tiles: PointMap<i64>,
}

impl ReachResult {
    pub fn rejected(message: &str) -> Self {
        Self {
            trip: trip::TripResult::failure(message),
            start: Vec2i::NONE,
            origin: Vec2i::NONE,
            clicked: Vec2i::NONE,
            ..Default::default()
        }
    }
}

impl ToValue for &'static str {
    fn to_value(&self) -> Value {
        Value::Str(self.to_string())
    }
}

impl ToValue for ReachResult {
    fn to_value(&self) -> Value {
        let trip = &self.trip;

        Value::Object(
            "TransportTripReachResult",
            vec![
                ("ok", Value::Bool(trip.ok)),
                ("error", Value::Str(trip.error.clone())),
                ("reached_destination", Value::Bool(trip.reached_destination)),
                ("cost", Value::Int(trip.cost)),
                ("path_length", Value::Int(trip.path_length)),
                ("used_bus", Value::Bool(trip.used_bus)),
                ("used_rail", Value::Bool(trip.used_rail)),
                ("used_subway", Value::Bool(trip.used_subway)),
                ("expanded_states", Value::Int(trip.expanded_states)),
                ("reachable", self.reachable.to_value()),
                ("links", self.links.to_value()),
                ("destinations", self.destinations.to_value()),
                ("limit_points", self.limit_points.to_value()),
                ("limit", Value::Int(self.limit)),
                ("start", Value::Vec2i(self.start)),
                ("origin", Value::Vec2i(self.origin)),
                ("clicked", Value::Vec2i(self.clicked)),
                ("summary", Value::Strings(self.summary.clone())),
                ("rci", Value::Bool(self.rci)),
                ("powered", Value::Bool(self.powered)),
                ("demand", Value::Int(self.demand)),
                ("access_tiles", self.access_tiles.to_value()),
                ("origin_tiles", self.origin_tiles.to_value()),
            ],
        )
    }
}

#[derive(Clone, Copy, Default)]
struct Endpoint {
    exit: bool,
    destination: bool,
    limited: bool,
}

/// TransportTripSearch.trace with collect_reach. It explores every route
/// within the cost limit and keeps the nodes, links, and destinations. It does
/// not write traffic.
#[allow(clippy::too_many_arguments)]
pub fn trace_reach(
    maps: &TripMaps,
    origin: Vec2i,
    zone: i64,
    traffic_weight: i64,
    random: &mut SimRandom,
    maximum_cost: i64,
    start_override: i64,
) -> ReachResult {
    use trip::*;

    let map_edge = maps.map_edge;
    let mut result = ReachResult {
        start: Vec2i::NONE,
        origin: Vec2i::NONE,
        clicked: Vec2i::NONE,
        ..Default::default()
    };

    if zone < 0 || zone >= DESTINATION_ZONE_MASKS.len() as i64 {
        result.trip.error = "zone is outside the supported range".to_string();
        return result;
    }

    if traffic_weight < 0 {
        result.trip.error = "traffic weight cannot be negative".to_string();
        return result;
    }

    let start = if start_override >= 0 {
        start_override
    } else {
        find_transport(maps.buildings, origin, map_edge)
    };

    if start < 0 {
        result.trip.ok = true;
        return result;
    }

    let mut limit = maximum_cost.max(0);

    if traffic_weight == 1 {
        limit -= limit / 4;
    }

    let turn_direction = if random.next_u15() & 1 != 0 { 1 } else { 3 };
    let start_index = start & point_index_mask(map_edge);
    let mut points = vec![Vec2i::new(start_index / map_edge, start_index % map_edge)];
    let mut indices = vec![start_index];
    let mut modes = vec![start >> point_shift(map_edge)];
    let mut costs = vec![0i64];
    let mut headings = vec![4i64];
    let mut parents = vec![-1i64];
    let mut pending: Vec<Vec<usize>> = vec![Vec::new(); limit.max(1) as usize];
    let mut best: HashMap<i64, i64> = HashMap::new();
    let mut link_keys: HashMap<(i64, i64), ()> = HashMap::new();
    let mut endpoints: PointMap<Endpoint> = PointMap::default();
    let mut winner: i64 = -1;
    let mut expanded = 0;

    if limit > 0 {
        pending[0].push(0);
    }

    best.insert(state_key(start_index, modes[0], 4), 0);

    for cost in 0..limit {
        let mut position = 0;

        while position < pending[cost as usize].len() {
            let state_index = pending[cost as usize][position];
            position += 1;
            let point = points[state_index];
            let point_index = indices[state_index];
            let mode = modes[state_index];
            let heading = headings[state_index];

            if best.get(&state_key(point_index, mode, heading)).copied() != Some(cost) {
                continue;
            }

            expanded += 1;
            result.reachable.push(ReachNode { point, mode, cost });

            if !endpoints.has(point) {
                endpoints.set(point, Endpoint::default());
            }

            let walk_destinations = walking_destinations(maps.zones, point, mode, zone, map_edge, zone == 7);

            if !walk_destinations.is_empty() {
                let mut endpoint = endpoints.get(point).unwrap_or_default();
                endpoint.destination = true;
                endpoints.set(point, endpoint);

                for target in walk_destinations {
                    let best_cost = result.destinations.get(target).unwrap_or(cost).min(cost);
                    result.destinations.set(target, best_cost);
                }

                if winner < 0 {
                    winner = state_index as i64;
                }
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
                let next_index = if next_point.x >= 0 && next_point.x < map_edge && next_point.y >= 0 && next_point.y < map_edge {
                    next_point.x * map_edge + next_point.y
                } else {
                    -1
                };
                let advance = advance(maps, point, next_point, point_index, next_index, mode, zone);

                if advance == ADVANCE_SUCCESS {
                    if winner < 0 {
                        winner = state_index as i64;
                    }

                    let mut endpoint = endpoints.get(point).unwrap_or_default();
                    endpoint.destination = true;
                    endpoints.set(point, endpoint);
                    let best_cost = result.destinations.get(next_point).unwrap_or(cost).min(cost);
                    result.destinations.set(next_point, best_cost);

                    continue;
                }

                if advance == ADVANCE_BLOCKED {
                    continue;
                }

                let next_cost = cost + (advance & 0xff);

                if next_cost >= limit {
                    let mut endpoint = endpoints.get(point).unwrap_or_default();
                    endpoint.limited = true;
                    endpoints.set(point, endpoint);
                    continue;
                }

                let parent = parents[state_index];

                if parent < 0 || next_point != points[parent as usize] {
                    let mut endpoint = endpoints.get(point).unwrap_or_default();
                    endpoint.exit = true;
                    endpoints.set(point, endpoint);
                }

                let next_mode = advance >> 8;
                let next_heading = if (HEADING_MODES >> next_mode) & 1 != 0 { direction } else { 4 };
                let next_key = state_key(next_index, next_mode, next_heading);
                let link_key = (point_index * 14 + mode, next_index * 14 + next_mode);

                if link_keys.insert(link_key, ()).is_none() {
                    result.links.push(Link {
                        from: point,
                        to: next_point,
                        from_mode: mode,
                        mode: next_mode,
                        cost: next_cost,
                    });
                }

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
        }
    }

    // The winning path gives the trip summary. A reach query writes no traffic.
    let mut path = Vec::new();
    let mut cursor = winner;

    while cursor >= 0 {
        path.push(cursor as usize);
        cursor = parents[cursor as usize];
    }

    if winner >= 0 && traffic_weight > 0 {
        for &index in &path {
            let mode = modes[index];
            result.trip.used_bus = result.trip.used_bus || mode == BUS_STOP_MODE;
            result.trip.used_rail = result.trip.used_rail || mode == RAIL_STATION_MODE;
            result.trip.used_subway = result.trip.used_subway || mode == SUBWAY_STATION_MODE;
        }
    }

    result.trip.ok = true;
    result.trip.reached_destination = winner >= 0;
    result.trip.cost = if winner >= 0 { costs[winner as usize] } else { 0 };
    result.trip.path_length = path.len() as i64;
    result.trip.expanded_states = expanded;

    for (point, endpoint) in endpoints.iter() {
        if endpoint.limited && !endpoint.exit && !endpoint.destination {
            result.limit_points.set(*point, "Trip limit reached");
        }
    }

    result.limit = limit;
    result.start = points[0];
    result.origin = origin;
    result
}

#[inline]
fn state_key(index: i64, mode: i64, heading: i64) -> i64 {
    (index * 14 + mode) * 5 + heading
}

/// The anchor corner of each view rotation, as GrowthConstants.ANCHOR_MASKS.
const ANCHOR_MASKS: [i64; 4] = [0x80, 0x10, 0x20, 0x40];

fn growth_anchor(city: &City, point: Vec2i) -> Vec2i {
    let tile = city.building_id(point.x, point.y);

    if tile < tiles::DEVELOPED_FIRST {
        return point;
    }

    let rotation = city.compass_rotation();
    let site = find_building_site(
        &city.xbld.data,
        &city.xzon.data,
        point,
        tile,
        building_area(tile),
        rotation,
        city.map_size,
    );
    let mask = ANCHOR_MASKS[rotation as usize];

    for x in site.position.x..site.end().x {
        for y in site.position.y..site.end().y {
            if city.xzon.data[city.index_of(x, y) as usize] as i64 & mask != 0 {
                return Vec2i::new(x, y);
            }
        }
    }

    point
}

/// TripReachAnalysis._building_site. Partial buildings or missing corner flags
/// keep their coverage on the actual tile.
fn building_site(city: &City, point: Vec2i) -> Rect2i {
    let tile = city.building_id(point.x, point.y);

    if tile < tiles::DEVELOPED_FIRST {
        return Rect2i::from(point, Vec2i::new(1, 1));
    }

    let site = find_building_site(
        &city.xbld.data,
        &city.xzon.data,
        point,
        tile,
        building_area(tile),
        city.compass_rotation(),
        city.map_size,
    );

    if site.has_area() {
        site
    } else {
        Rect2i::from(point, Vec2i::new(1, 1))
    }
}

fn cover_site(city: &City, point: Vec2i, cost: i64, tiles: &mut PointMap<i64>) {
    let site = building_site(city, point);

    for x in site.position.x..site.end().x {
        for y in site.position.y..site.end().y {
            let part = Vec2i::new(x, y);
            let value = tiles.get(part).unwrap_or(cost).min(cost);
            tiles.set(part, value);
        }
    }
}

fn add_building_coverage(city: &City, result: &mut ReachResult, origin: Vec2i) {
    use trip::*;

    let mut destinations = result.destinations.clone();

    for (point, cost) in result.destinations.iter() {
        if city.index_of(point.x, point.y) >= 0 {
            let cost = destinations.get(*point).unwrap_or(*cost);
            cover_site(city, *point, cost, &mut destinations);
        }
    }

    let mut access_tiles = PointMap::default();
    let access_modes = [
        ROAD_MODE,
        BUS_ROAD_MODE,
        BUS_STOP_MODE,
        BUS_RAIL_MODE,
        RAIL_STATION_MODE,
        SUBWAY_STATION_MODE,
    ];

    for node in &result.reachable {
        if !access_modes.contains(&node.mode) {
            continue;
        }

        for offset in TRANSPORT_OFFSETS {
            let point = node.point + offset;
            let index = city.index_of(point.x, point.y);

            if index >= 0 && (city.xzon.data[index as usize] & 15 != 0 || city.xbld.data[index as usize] as i64 >= tiles::DEVELOPED_FIRST) {
                cover_site(city, point, node.cost, &mut access_tiles);
            }
        }
    }

    let mut origin_tiles = PointMap::default();
    cover_site(city, origin, 0, &mut origin_tiles);
    result.destinations = destinations;
    result.access_tiles = access_tiles;
    result.origin_tiles = origin_tiles;
}

fn network_mode(tile: i64) -> i64 {
    use trip::*;

    if is_highway_span(tile) || (tiles::HIGHWAY_ONRAMP_1..=tiles::HIGHWAY_ONRAMP_4).contains(&tile) {
        return HIGHWAY_MODE;
    }

    if tile == tiles::RAIL_STATION {
        return RAIL_STATION_MODE;
    }

    if tile == tiles::SUBWAY_STATION {
        return SUBWAY_STATION_MODE;
    }

    if tile == tiles::BUS_DEPOT {
        return BUS_STOP_MODE;
    }

    if super::network::surface_road(tile) {
        return ROAD_MODE;
    }

    if is_road_bridge(tile) {
        return ROAD_BRIDGE_MODE;
    }

    if super::network::rail(tile) {
        return RAIL_MODE;
    }

    -1
}

/// GrowthSiteRules.has_power: the low-edge checks of city growth.
fn has_power(flags: &[u8], x: i64, y: i64, map_edge: i64) -> bool {
    let powered = |index: i64| flags[index as usize] as i64 & flag_bits::POWERED != 0;

    powered(x * map_edge + y)
        || (x > 1 && powered((x - 1) * map_edge + y))
        || (y > 1 && powered(x * map_edge + y - 1))
        || (x < map_edge - 1 && powered((x + 1) * map_edge + y))
        || (y < map_edge - 1 && powered(x * map_edge + y + 1))
}

/// TripReachAnalysis.inspect.
pub fn inspect(city: &City, clicked: Vec2i) -> ReachResult {
    if city.index_of(clicked.x, clicked.y) < 0 {
        return ReachResult::rejected("Select a tile inside the city.");
    }

    let edge = city.map_size;
    let origin = growth_anchor(city, clicked);
    let index = city.index_of(origin.x, origin.y) as usize;
    let zone = city.xzon.data[index] as i64 & 15;
    let rci = (1..=6).contains(&zone);
    let tile = city.xbld.data[index] as i64;
    let density = if (tiles::DEVELOPED_FIRST..=tiles::DEVELOPED_3X3_LAST).contains(&tile) {
        super::growth::development::density(tile)
    } else {
        0
    };
    let limit = if density == 1 { 75 } else { 100 };
    let mut start = -1;

    if !rci {
        let mut mode = network_mode(tile);

        if mode < 0 && super::network::subway(city.xund.data[index] as i64) {
            mode = trip::SUBWAY_MODE;
        }

        if mode >= 0 {
            start = (mode << trip::point_shift(edge)) | index as i64;
        }
    }

    let maps = TripMaps {
        buildings: &city.xbld.data,
        zones: &city.xzon.data,
        underground: &city.xund.data,
        text_overlays: &city.xtxt.data,
        altitude: &city.altm.data,
        map_edge: edge,
    };

    if !trip::valid_inputs(&maps, &city.xtrf.data) {
        return ReachResult::rejected("Transport maps for this city have the wrong size.");
    }

    let zone_argument = if rci { zone } else { 7 };
    let mut result = trace_reach(&maps, origin, zone_argument, density, &mut SimRandom::new(1), 100, start);
    add_building_coverage(city, &mut result, origin);

    if result.reachable.is_empty() {
        result.summary.push("No transport access within three tiles.".to_string());
    } else if !rci {
        result
            .summary
            .push("Network exploration. Select an RCI zone to check growth.".to_string());
    }

    result.origin = origin;
    result.clicked = clicked;
    result.limit = limit;
    result.rci = rci;
    result.powered = has_power(&city.xbit.data, origin.x, origin.y, edge);
    result.demand = if rci {
        city.misc_i32(misc_layout::DEMAND + ((zone - 1) / 2) * 4)
    } else {
        0
    };
    result
}

impl ToValue for trip::TripResult {
    fn to_value(&self) -> Value {
        Value::Object(
            "TransportTripResult",
            vec![
                ("ok", Value::Bool(self.ok)),
                ("error", Value::Str(self.error.clone())),
                ("reached_destination", Value::Bool(self.reached_destination)),
                ("cost", Value::Int(self.cost)),
                ("path_length", Value::Int(self.path_length)),
                ("used_bus", Value::Bool(self.used_bus)),
                ("used_rail", Value::Bool(self.used_rail)),
                ("used_subway", Value::Bool(self.used_subway)),
                ("expanded_states", Value::Int(self.expanded_states)),
            ],
        )
    }
}

/// TransportTrip.run: one trip that adds traffic along a completed path.
pub fn run_trip(
    city: &mut City,
    origin: Vec2i,
    zone: i64,
    traffic_weight: i64,
    random: &mut SimRandom,
    maximum_cost: i64,
) -> trip::TripResult {
    if zone < 0 || zone >= trip::DESTINATION_ZONE_MASKS.len() as i64 {
        return trip::TripResult::failure("zone is outside the supported range");
    }

    if traffic_weight < 0 {
        return trip::TripResult::failure("traffic weight cannot be negative");
    }

    if city.missing_or_resized(&["XTRF"]).is_some() {
        return trip::TripResult::failure("XTRF is missing or has the wrong size");
    }

    let mut traffic = city.xtrf.data.clone();
    let maps = TripMaps {
        buildings: &city.xbld.data,
        zones: &city.xzon.data,
        underground: &city.xund.data,
        text_overlays: &city.xtxt.data,
        altitude: &city.altm.data,
        map_edge: city.map_size,
    };

    if !trip::valid_inputs(&maps, &traffic) {
        return trip::TripResult::failure("transport input maps have the wrong size");
    }

    let mut scratch = trip::TripScratch::default();
    let result = trip::trace(
        &maps,
        &mut traffic,
        origin,
        zone,
        traffic_weight,
        random,
        maximum_cost,
        -1,
        None,
        &mut scratch,
    );

    if result.ok && result.reached_destination {
        city.xtrf.replace(traffic);
    }

    result
}
