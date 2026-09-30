//! Disaster marker spread each tick, as DisasterMapScanDispatch,
//! DisasterMapFireFlood, DisasterMapMarkers, and DisasterMapState.

use super::damage::{self, append_damage_events, burn_structure};
use super::{
    CARDINAL_DIRECTIONS, DisasterMapResult, DisasterMaps, FIRE_OVERLAY, FLOOD_OVERLAY, MAP_CHUNKS, RIOT_OVERLAY_FORWARD,
    RIOT_OVERLAY_REVERSE, RuntimeEvents, Snapshot, TOXIC_OVERLAY, altitude_word, index, sounds,
};
use crate::sim::bytes;
use crate::sim::city::City;
use crate::sim::geom::{Rect2i, Vec2i};
use crate::sim::grid;
use crate::sim::growth::development::{self, ZoneMaps};
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::moving::spawner::VehicleCaps;
use crate::sim::overlay;
use crate::sim::random::{SimLfsrRandom, SimRandom};
use crate::sim::things;
use crate::sim::tools::demolish::{self, building_area, find_building_site};
use crate::sim::tools::network::replace_building;
use crate::sim::value::OrderedMap;

pub const SOUND_FIRE: i64 = 0x1fb;
pub const SOUND_FLOOD: i64 = 0x1ff;
pub const SOUND_RIOT: i64 = 0x200;
pub const SOUND_HURRICANE: i64 = 0x1f6;
const TYPE_FIRE_DISPATCH: i64 = 8;
const RANDOM_REQUIRED: &str = "a compatible process random generator is required";
const LFSR_REQUIRED: &str = "a compatible LFSR generator is required";

/// The scan counters, in the DisasterMapScanDispatch._new_map_counters order.
#[derive(Default)]
struct Counters {
    fire_markers_scanned: i64,
    fire_updates: i64,
    spread_attempts: i64,
    spread_fires: i64,
    water_extinctions: i64,
    coverage_extinctions: i64,
    structure_collapses: i64,
    created_explosions: i64,
    toxic_markers: i64,
    flood_markers_scanned: i64,
    flood_updates: i64,
    flood_spread_attempts: i64,
    spread_floods: i64,
    expired_floods: i64,
    random_extinctions: i64,
    damaged_structures: i64,
    toxic_markers_scanned: i64,
    toxic_updates: i64,
    lfsr_expirations: i64,
    water_expirations: i64,
    moved_markers: i64,
    blocked_moves: i64,
    abandoned_structures: i64,
    riot_markers_scanned: i64,
    riot_updates: i64,
    expired_riots: i64,
    damage_attempts: i64,
    started_fires: i64,
    traffic_cells_cleared: i64,
    propagated_riots: i64,
    blocked_propagations: i64,
    hurricane_damage_attempts: i64,
    hurricane_damaged_structures: i64,
}

impl Counters {
    fn fire(&self) -> Vec<(&'static str, i64)> {
        vec![
            ("fire_markers_scanned", self.fire_markers_scanned),
            ("fire_updates", self.fire_updates),
            ("spread_attempts", self.spread_attempts),
            ("spread_fires", self.spread_fires),
            ("water_extinctions", self.water_extinctions),
            ("coverage_extinctions", self.coverage_extinctions),
            ("structure_collapses", self.structure_collapses),
            ("created_explosions", self.created_explosions),
            ("toxic_markers", self.toxic_markers),
        ]
    }

    /// `flood_spread_attempts` has the name `spread_attempts` in run_flood.
    fn flood(&self, spread_name: &'static str) -> Vec<(&'static str, i64)> {
        vec![
            ("flood_markers_scanned", self.flood_markers_scanned),
            ("flood_updates", self.flood_updates),
            (spread_name, self.flood_spread_attempts),
            ("spread_floods", self.spread_floods),
            ("expired_floods", self.expired_floods),
            ("random_extinctions", self.random_extinctions),
            ("damaged_structures", self.damaged_structures),
        ]
    }

    fn toxic(&self) -> Vec<(&'static str, i64)> {
        vec![
            ("toxic_markers_scanned", self.toxic_markers_scanned),
            ("toxic_updates", self.toxic_updates),
            ("lfsr_expirations", self.lfsr_expirations),
            ("water_expirations", self.water_expirations),
            ("moved_markers", self.moved_markers),
            ("blocked_moves", self.blocked_moves),
            ("abandoned_structures", self.abandoned_structures),
        ]
    }

    fn riot(&self) -> Vec<(&'static str, i64)> {
        vec![
            ("riot_markers_scanned", self.riot_markers_scanned),
            ("riot_updates", self.riot_updates),
            ("expired_riots", self.expired_riots),
            ("damage_attempts", self.damage_attempts),
            ("started_fires", self.started_fires),
            ("traffic_cells_cleared", self.traffic_cells_cleared),
            ("propagated_riots", self.propagated_riots),
            ("blocked_propagations", self.blocked_propagations),
        ]
    }

    fn all(&self) -> Vec<(&'static str, i64)> {
        let mut values = self.fire();
        values.extend(self.flood("flood_spread_attempts"));
        values.extend(self.toxic());
        values.extend(self.riot());
        values.push(("hurricane_damage_attempts", self.hurricane_damage_attempts));
        values.push(("hurricane_damaged_structures", self.hurricane_damaged_structures));
        values
    }
}

#[derive(Default)]
struct DispatchCounters {
    dispatch_markers_scanned: i64,
    fire_suppression_attempts: i64,
    fire_extinctions: i64,
    riot_suppression_attempts: i64,
    riot_suppressions: i64,
}

impl DispatchCounters {
    fn map(&self) -> OrderedMap<i64> {
        ordered(vec![
            ("dispatch_markers_scanned", self.dispatch_markers_scanned),
            ("fire_suppression_attempts", self.fire_suppression_attempts),
            ("fire_extinctions", self.fire_extinctions),
            ("riot_suppression_attempts", self.riot_suppression_attempts),
            ("riot_suppressions", self.riot_suppressions),
        ])
    }
}

fn ordered(values: Vec<(&'static str, i64)>) -> OrderedMap<i64> {
    OrderedMap(values.into_iter().map(|(name, value)| (name.to_string(), value)).collect())
}

fn remaining_riots(text: &[u8]) -> i64 {
    overlay::occurrences(text, RIOT_OVERLAY_FORWARD) + overlay::occurrences(text, RIOT_OVERLAY_REVERSE)
}

/// The common checks of each map tick. The snapshot is the map copy.
fn prepare(
    city: &City,
    random: &Option<&mut SimRandom>,
    lfsr: &Option<&mut SimLfsrRandom>,
    missing: &'static str,
) -> Result<Snapshot, &'static str> {
    if random.is_none() {
        return Err(RANDOM_REQUIRED);
    }

    if lfsr.is_none() {
        return Err(LFSR_REQUIRED);
    }

    Snapshot::take(city, &MAP_CHUNKS).ok_or(missing)
}

/// DisasterMapScanDispatch.run_all: one scan that updates each marker kind and
/// the dispatched units.
pub fn run_all(
    city: &mut City,
    random: Option<&mut SimRandom>,
    lfsr: Option<&mut SimLfsrRandom>,
    map_counter: i64,
    hurricane_counter: i64,
) -> DisasterMapResult {
    let snapshot = match prepare(city, &random, &lfsr, "disaster-map input chunks are missing or invalid") {
        Ok(snapshot) => snapshot,
        Err(error) => return DisasterMapResult::failed(error),
    };
    let (Some(random), Some(lfsr)) = (random, lfsr) else {
        unreachable!();
    };
    let edge = city.map_size;
    let counter = (map_counter - 1).max(0);
    let mut counters = Counters::default();
    let mut dispatch = DispatchCounters::default();
    let mut events = RuntimeEvents::default();
    let mut fire_active = false;
    let mut flood_active = false;
    let mut toxic_active = false;
    let mut riot_active = false;
    let mut view_center_requests = Vec::new();
    let mut maps = city.disaster_maps();
    let layered = overlay::is_layered(maps.maps.text_overlays);

    for x in 0..edge {
        crate::sim::budget::checkpoint();

        for y in 0..edge {
            let tile_index = x * edge + y;
            let marker = overlay::marker_at(maps.maps.text_overlays, tile_index);
            // a layered index keeps objects apart from markers; both act
            let object = if layered {
                overlay::object(maps.maps.text_overlays, tile_index)
            } else {
                marker
            };
            let point = Vec2i::new(x, y);

            if marker == FIRE_OVERLAY {
                fire_active = true;
                process_fire_cell(&mut maps, point, tile_index, random, lfsr, &mut counters, &mut events);
            } else if marker == RIOT_OVERLAY_REVERSE || marker == RIOT_OVERLAY_FORWARD {
                riot_active = true;
                process_riot_cell(&mut maps, point, tile_index, marker, random, lfsr, &mut counters, &mut events);
            } else if marker == TOXIC_OVERLAY {
                toxic_active = true;
                process_toxic_cell(&mut maps, point, tile_index, random, lfsr, &mut counters);
            } else if marker == FLOOD_OVERLAY {
                flood_active = true;
                process_flood_cell(&mut maps, point, tile_index, counter, random, lfsr, &mut counters, &mut events);
            } else if !layered && overlay::is_thing(object) {
                process_dispatch_cell(&mut maps, point, object, random, lfsr, &mut dispatch);
            }

            if layered && overlay::is_thing(object) {
                process_dispatch_cell(&mut maps, point, object, random, lfsr, &mut dispatch);
            }
        }
    }

    if riot_active && random.next_u15() & 7 == 0 {
        events.sound_events.push(SOUND_RIOT);
    }

    if flood_active && random.next_u15() & 7 == 0 {
        events.sound_events.push(SOUND_FLOOD);
    }

    if fire_active {
        events.sound_events.push(SOUND_FIRE);
    }

    let mut next_hurricane_counter = hurricane_counter;

    if counter != 0 && hurricane_counter != 0 {
        if random.next_u15() & 7 == 0 {
            events.sound_events.push(SOUND_HURRICANE);
        }

        if lfsr.next_mask(1) == 0 {
            let x = lfsr.next_mod(edge);
            let y = lfsr.next_mod(edge);
            let hurricane_point = Vec2i::new(x, y);
            let hurricane_index = index(hurricane_point, edge);

            if bytes::at(maps.maps.buildings, hurricane_index) > tiles::LOWER_CLASS_HOMES_1X1_1 {
                counters.hurricane_damage_attempts += 1;
                let damage = burn_structure(&mut maps, hurricane_point, random, lfsr, false, false, true);

                if damage.changed {
                    counters.hurricane_damaged_structures += 1;
                }

                append_damage_events(Some(&mut events), &damage);
                view_center_requests.push(hurricane_point);
            }
        }

        next_hurricane_counter = (hurricane_counter - 1).max(0);
    }

    let map_changed = snapshot.changed(city);
    snapshot.commit(city);
    let text = &city.xtxt.data;
    let mut values = counters.all();
    values.push(("remaining_fires", overlay::occurrences(text, FIRE_OVERLAY)));
    values.push(("remaining_floods", overlay::occurrences(text, FLOOD_OVERLAY)));
    values.push(("remaining_toxic", overlay::occurrences(text, TOXIC_OVERLAY)));
    values.push(("remaining_riots", remaining_riots(text)));
    let mut dispatch_map = DisasterMapResult {
        map_changed,
        counters: dispatch.map(),
        ..Default::default()
    };
    dispatch_map.base.ok = true;
    let mut result = DisasterMapResult {
        active: fire_active || flood_active || toxic_active || riot_active,
        active_markers: OrderedMap(vec![
            ("fire".to_string(), fire_active),
            ("flood".to_string(), flood_active),
            ("toxic".to_string(), toxic_active),
            ("riot".to_string(), riot_active),
        ]),
        counters: ordered(values),
        map_counter: counter,
        hurricane_counter: next_hurricane_counter,
        map_changed,
        dispatch_map: Some(Box::new(dispatch_map)),
        ..Default::default()
    };
    result.base.ok = true;
    result.base.effect_events = events.effect_events;
    result.base.sound_events = sounds(&events.sound_events);
    result.base.view_center_requests = view_center_requests;
    result
}

/// DisasterMapScanDispatch.run_dispatch.
pub fn run_dispatch(city: &mut City, random: Option<&mut SimRandom>, lfsr: Option<&mut SimLfsrRandom>) -> DisasterMapResult {
    let snapshot = match prepare(city, &random, &lfsr, "dispatch-map input chunks are missing or invalid") {
        Ok(snapshot) => snapshot,
        Err(error) => return DisasterMapResult::failed(error),
    };
    let (Some(random), Some(lfsr)) = (random, lfsr) else {
        unreachable!();
    };
    let edge = city.map_size;
    let mut dispatch = DispatchCounters::default();
    let mut maps = city.disaster_maps();

    for x in 0..edge {
        crate::sim::budget::checkpoint();

        for y in 0..edge {
            let marker = overlay::read(maps.maps.text_overlays, x * edge + y);

            if overlay::is_thing(marker) {
                process_dispatch_cell(&mut maps, Vec2i::new(x, y), marker, random, lfsr, &mut dispatch);
            }
        }
    }

    let map_changed = snapshot.changed(city);
    snapshot.commit(city);
    let mut result = DisasterMapResult {
        map_changed,
        counters: dispatch.map(),
        ..Default::default()
    };
    result.base.ok = true;
    result
}

/// The marker kinds of the single-kind ticks.
#[derive(Clone, Copy, PartialEq)]
enum Kind {
    Fire,
    Flood,
    Toxic,
    Riot,
}

/// DisasterMapFireFlood.run_fire, run_flood, and DisasterMapMarkers.run_toxic
/// and run_riot. Each updates one marker kind.
fn run_kind(
    city: &mut City,
    random: Option<&mut SimRandom>,
    lfsr: Option<&mut SimLfsrRandom>,
    kind: Kind,
    map_counter: i64,
) -> DisasterMapResult {
    let missing = match kind {
        Kind::Fire => "fire-map input chunks are missing or invalid",
        Kind::Flood => "flood-map input chunks are missing or invalid",
        Kind::Toxic => "toxic-map input chunks are missing or invalid",
        Kind::Riot => "riot-map input chunks are missing or invalid",
    };
    let snapshot = match prepare(city, &random, &lfsr, missing) {
        Ok(snapshot) => snapshot,
        Err(error) => return DisasterMapResult::failed(error),
    };
    let (Some(random), Some(lfsr)) = (random, lfsr) else {
        unreachable!();
    };
    let edge = city.map_size;
    let counter = (map_counter - 1).max(0);
    let mut counters = Counters::default();
    let mut events = RuntimeEvents::default();
    let mut active = false;
    let mut maps = city.disaster_maps();

    for x in 0..edge {
        crate::sim::budget::checkpoint();

        for y in 0..edge {
            let tile_index = x * edge + y;
            let marker = overlay::marker_at(maps.maps.text_overlays, tile_index);
            let point = Vec2i::new(x, y);

            match kind {
                Kind::Fire if marker == FIRE_OVERLAY => {
                    active = true;
                    process_fire_cell(&mut maps, point, tile_index, random, lfsr, &mut counters, &mut events);
                }
                Kind::Flood if marker == FLOOD_OVERLAY => {
                    active = true;
                    process_flood_cell(&mut maps, point, tile_index, counter, random, lfsr, &mut counters, &mut events);
                }
                Kind::Toxic if marker == TOXIC_OVERLAY => {
                    active = true;
                    process_toxic_cell(&mut maps, point, tile_index, random, lfsr, &mut counters);
                }
                Kind::Riot if marker == RIOT_OVERLAY_FORWARD || marker == RIOT_OVERLAY_REVERSE => {
                    active = true;
                    process_riot_cell(&mut maps, point, tile_index, marker, random, lfsr, &mut counters, &mut events);
                }
                _ => {}
            }
        }
    }

    let map_changed = snapshot.changed(city);
    snapshot.commit(city);
    let text = &city.xtxt.data;
    let mut result = DisasterMapResult {
        active,
        map_changed,
        ..Default::default()
    };
    let values = match kind {
        Kind::Fire => {
            if active {
                events.sound_events.push(SOUND_FIRE);
            }

            let mut values = counters.fire();
            values.push(("remaining_fires", overlay::occurrences(text, FIRE_OVERLAY)));
            values
        }
        Kind::Flood => {
            if active && random.next_u15() & 7 == 0 {
                events.sound_events.push(SOUND_FLOOD);
            }

            result.map_counter = counter;
            let mut values = counters.flood("spread_attempts");
            values.push(("remaining_floods", overlay::occurrences(text, FLOOD_OVERLAY)));
            values
        }
        Kind::Toxic => {
            events = RuntimeEvents::default();
            let mut values = counters.toxic();
            values.push(("remaining_toxic", overlay::occurrences(text, TOXIC_OVERLAY)));
            values
        }
        Kind::Riot => {
            if active && random.next_u15() & 7 == 0 {
                events.sound_events.push(SOUND_RIOT);
            }

            let mut values = counters.riot();
            values.push(("remaining_riots", remaining_riots(text)));
            values
        }
    };
    result.counters = ordered(values);
    result.base.ok = true;
    result.base.effect_events = events.effect_events;
    result.base.sound_events = sounds(&events.sound_events);
    result
}

pub fn run_fire(city: &mut City, random: Option<&mut SimRandom>, lfsr: Option<&mut SimLfsrRandom>) -> DisasterMapResult {
    run_kind(city, random, lfsr, Kind::Fire, 0)
}

pub fn run_flood(city: &mut City, random: Option<&mut SimRandom>, lfsr: Option<&mut SimLfsrRandom>, map_counter: i64) -> DisasterMapResult {
    run_kind(city, random, lfsr, Kind::Flood, map_counter)
}

pub fn run_toxic(city: &mut City, random: Option<&mut SimRandom>, lfsr: Option<&mut SimLfsrRandom>) -> DisasterMapResult {
    run_kind(city, random, lfsr, Kind::Toxic, 0)
}

pub fn run_riot(city: &mut City, random: Option<&mut SimRandom>, lfsr: Option<&mut SimLfsrRandom>) -> DisasterMapResult {
    run_kind(city, random, lfsr, Kind::Riot, 0)
}

fn starts_fire(result_code: i64) -> bool {
    result_code == 1 || result_code == 3 || result_code == 4
}

fn is_special_toxic(tile: i64) -> bool {
    tile == tiles::CHEMICAL_STORAGE_1X1 || tile == tiles::CHEMICAL_PROCESSING_2X2 || tile == tiles::CHEMICAL_PROCESSING_3X3
}

/// DisasterMapState._collapse_structure.
fn collapse_structure(maps: &mut DisasterMaps, point: Vec2i, random: &mut SimRandom, lfsr: &mut SimLfsrRandom) {
    burn_structure(maps, point, random, lfsr, true, true, false);
}

/// DisasterMapFireFlood._process_fire_cell.
fn process_fire_cell(
    maps: &mut DisasterMaps,
    point: Vec2i,
    tile_index: i64,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    counters: &mut Counters,
    events: &mut RuntimeEvents,
) {
    let edge = maps.maps.map_edge;
    counters.fire_markers_scanned += 1;

    if random.next_u15() & 3 != 0 {
        return;
    }

    counters.fire_updates += 1;

    if maps.maps.flags[tile_index as usize] & 0x04 != 0 {
        overlay::set_marker_at(maps.maps.text_overlays, tile_index, 0);
        counters.water_extinctions += 1;

        return;
    }

    let choice = random.next_u15() & 7;

    if choice < 4 {
        counters.spread_attempts += 1;
        let target = point + CARDINAL_DIRECTIONS[choice as usize];

        if starts_fire(damage::apply(maps, target, random, lfsr, false, Some(events))) {
            counters.spread_fires += 1;
        }
    } else if choice == 5 {
        let tile = maps.maps.buildings[tile_index as usize] as i64;

        if tile > tiles::RAIL_SUBWAY_ENTRANCE_4 {
            let special = is_special_toxic(tile);
            let mut toxic_site = Rect2i::default();

            if special {
                toxic_site = find_building_site(
                    maps.maps.buildings,
                    maps.maps.zones,
                    point,
                    tile,
                    building_area(tile),
                    maps.rotation,
                    edge,
                );
            }

            collapse_structure(maps, point, random, lfsr);
            counters.structure_collapses += 1;

            if lfsr.next_mask(0x0f) == 0
                && spawn_explosion(maps.maps.text_overlays, maps.things, point, 0, 0, 1, edge, &maps.maps.vehicle_caps)
            {
                counters.created_explosions += 1;
            }

            if special {
                counters.toxic_markers += seed_special_toxic(maps.maps.text_overlays, toxic_site, point, edge);
            }
        }
    } else {
        let coverage_index = grid::index(maps.fire_coverage, edge, point.x, point.y);
        let coverage = bytes::at(maps.fire_coverage, coverage_index) + 8;

        if (random.next_u15() & 0xff) < coverage {
            collapse_structure(maps, point, random, lfsr);
            counters.coverage_extinctions += 1;
        }
    }
}

/// DisasterMapFireFlood._process_flood_cell.
#[allow(clippy::too_many_arguments)]
fn process_flood_cell(
    maps: &mut DisasterMaps,
    point: Vec2i,
    tile_index: i64,
    counter: i64,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    counters: &mut Counters,
    events: &mut RuntimeEvents,
) {
    counters.flood_markers_scanned += 1;

    if counter == 0 && lfsr.next_mask(1) != 0 {
        overlay::set_marker_at(maps.maps.text_overlays, tile_index, 0);
        counters.expired_floods += 1;

        return;
    }

    let update = counter > 51 || random.next_u15() & 3 == 0;

    if !update {
        return;
    }

    counters.flood_updates += 1;

    if counter < 30 && random.next_u15() & 3 == 0 {
        if maps.maps.buildings[tile_index as usize] as i64 > tiles::RAIL_SUBWAY_ENTRANCE_4 {
            burn_structure(maps, point, random, lfsr, false, false, false);
            counters.damaged_structures += 1;
        }

        overlay::set_marker_at(maps.maps.text_overlays, tile_index, 0);
        counters.random_extinctions += 1;
    }

    if counter > 0 {
        counters.flood_spread_attempts += 1;
        let target = point + CARDINAL_DIRECTIONS[(random.next_u15() & 3) as usize];
        let maximum_altitude = altitude_word(maps.maps.altitude, tile_index) & 0x1f;

        if damage::apply_flood(maps, target, maximum_altitude, random, lfsr, Some(events)) == 1 {
            counters.spread_floods += 1;
        }
    }
}

/// DisasterMapMarkers._process_toxic_cell.
fn process_toxic_cell(
    maps: &mut DisasterMaps,
    point: Vec2i,
    tile_index: i64,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    counters: &mut Counters,
) {
    let edge = maps.maps.map_edge;
    counters.toxic_markers_scanned += 1;

    if random.next_u15() & 1 != 0 {
        return;
    }

    counters.toxic_updates += 1;

    if lfsr.next_mask(0x3f) == 0 {
        overlay::set_marker_at(maps.maps.text_overlays, tile_index, 0);
        counters.lfsr_expirations += 1;

        return;
    }

    if maps.maps.flags[tile_index as usize] & 0x04 != 0 && random.next_u15() & 0x0f == 0 {
        overlay::set_marker_at(maps.maps.text_overlays, tile_index, 0);
        counters.water_expirations += 1;

        return;
    }

    if abandon_toxic_structure(maps, point, random) {
        counters.abandoned_structures += 1;
    }

    let mut direction = lowest_toxic_direction(maps.maps.altitude, point, edge);

    if direction < 0 {
        direction = random.next_u15() & 3;
    }

    overlay::set_marker_at(maps.maps.text_overlays, tile_index, 0);
    let target = point + CARDINAL_DIRECTIONS[direction as usize];

    if place_toxic_marker(maps.maps.text_overlays, target, edge) {
        counters.moved_markers += 1;
    } else {
        counters.blocked_moves += 1;
    }
}

/// DisasterMapMarkers._process_riot_cell.
#[allow(clippy::too_many_arguments)]
fn process_riot_cell(
    maps: &mut DisasterMaps,
    point: Vec2i,
    tile_index: i64,
    marker: i64,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    counters: &mut Counters,
    events: &mut RuntimeEvents,
) {
    let edge = maps.maps.map_edge;
    counters.riot_markers_scanned += 1;

    if random.next_u15() & 3 != 0 {
        return;
    }

    counters.riot_updates += 1;

    if random.next_u15() & 0xff == 0 || maps.maps.flags[tile_index as usize] & 0x04 != 0 {
        overlay::set_marker_at(maps.maps.text_overlays, tile_index, 0);
        counters.expired_riots += 1;

        return;
    }

    let traffic_index = grid::index(maps.traffic, edge, point.x, point.y);

    if bytes::at(maps.traffic, traffic_index) != 0 {
        counters.traffic_cells_cleared += 1;
    }

    bytes::put(maps.traffic, traffic_index, 0);
    let damage_direction = random.next_u15() & 0x7f;

    if damage_direction < 4 {
        counters.damage_attempts += 1;
        let target = point + CARDINAL_DIRECTIONS[damage_direction as usize];

        if starts_fire(damage::apply(maps, target, random, lfsr, false, Some(events))) {
            counters.started_fires += 1;
        }
    }

    let reverse = marker == RIOT_OVERLAY_REVERSE;
    let first_direction = if reverse { 0 } else { 2 };
    let second_direction = if reverse { 1 } else { 3 };
    let mut connections = 0;

    if riot_supports(maps.maps.buildings, point + CARDINAL_DIRECTIONS[first_direction], edge) {
        connections |= 1;
    }

    if riot_supports(maps.maps.buildings, point + CARDINAL_DIRECTIONS[second_direction], edge) {
        connections |= 2;
    }

    let opposite_marker = if reverse { RIOT_OVERLAY_FORWARD } else { RIOT_OVERLAY_REVERSE };

    if connections == 0 {
        overlay::write(maps.maps.text_overlays, tile_index, opposite_marker);

        return;
    }

    let next_marker = if random.next_u15() & 7 == 0 { opposite_marker } else { 0 };
    overlay::write(maps.maps.text_overlays, tile_index, next_marker);

    if connections == 3 {
        connections = (random.next_u15() & 1) + 1;
    }

    let spread_direction = if connections == 1 { first_direction } else { second_direction };

    if place_riot_marker(maps.maps.text_overlays, point + CARDINAL_DIRECTIONS[spread_direction], marker, edge) {
        counters.propagated_riots += 1;
    } else {
        counters.blocked_propagations += 1;
    }
}

/// DisasterMapScanDispatch._process_dispatch_cell.
fn process_dispatch_cell(
    maps: &mut DisasterMaps,
    point: Vec2i,
    marker: i64,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    counters: &mut DispatchCounters,
) {
    let edge = maps.maps.map_edge;
    let record = overlay::thing_record(marker);
    let offset = record * things::RECORD_SIZE;
    let thing_type = if offset >= 0 {
        maps.things.get(offset as usize).copied().unwrap_or(0) as i64
    } else {
        0
    };
    counters.dispatch_markers_scanned += 1;
    let mut suppresses_fire = thing_type == TYPE_FIRE_DISPATCH || thing_type == things::TYPE_MILITARY;

    if thing_type == things::TYPE_POLICE {
        suppresses_fire = lfsr.next_mask(0x0f) == 0;
    }

    if suppresses_fire {
        counters.fire_suppression_attempts += 1;
        let target = point + CARDINAL_DIRECTIONS[(random.next_u15() & 3) as usize];

        if extinguish_dispatch_fire(maps, target, random, lfsr) {
            counters.fire_extinctions += 1;
        }
    }

    if thing_type == things::TYPE_POLICE || thing_type == things::TYPE_MILITARY {
        counters.riot_suppression_attempts += 1;
        let target = point + CARDINAL_DIRECTIONS[(random.next_u15() & 3) as usize];

        if clear_riot_marker(maps.maps.text_overlays, target, edge) {
            counters.riot_suppressions += 1;
        }
    }
}

/// DisasterMapScanDispatch._extinguish_dispatch_fire.
fn extinguish_dispatch_fire(maps: &mut DisasterMaps, point: Vec2i, random: &mut SimRandom, lfsr: &mut SimLfsrRandom) -> bool {
    let tile_index = index(point, maps.maps.map_edge);

    if tile_index < 0 || overlay::marker_at(maps.maps.text_overlays, tile_index) != FIRE_OVERLAY {
        return false;
    }

    overlay::set_marker_at(maps.maps.text_overlays, tile_index, 0);
    let tile = maps.maps.buildings[tile_index as usize] as i64;

    if (tiles::TUNNEL_ENTRANCE_1..=tiles::TUNNEL_ENTRANCE_4).contains(&tile) {
        return true;
    }

    let rotation = maps.rotation;

    if tile < tiles::HIGHWAY_SLOPE_1 {
        demolish::demolish_point(&mut maps.maps, point, random, rotation, true, true, false, false);
        let rubble = lfsr.next_mod(4) + tiles::RUBBLE_FIRST;
        replace_building(maps.maps.buildings, maps.maps.zones, maps.maps.misc, tile_index, rubble);
    } else if maps.maps.flags[tile_index as usize] & 0xf0 == 0xf0 {
        demolish::demolish_point(&mut maps.maps, point, random, rotation, true, true, false, false);
    }

    true
}

/// DisasterMapState._clear_riot_marker.
fn clear_riot_marker(text: &mut [u8], point: Vec2i, map_edge: i64) -> bool {
    let tile_index = index(point, map_edge);

    if tile_index < 0 {
        return false;
    }

    let marker = overlay::marker_at(text, tile_index);

    if marker != RIOT_OVERLAY_FORWARD && marker != RIOT_OVERLAY_REVERSE {
        return false;
    }

    overlay::set_marker_at(text, tile_index, 0);

    true
}

/// DisasterMapState._place_toxic_marker.
fn place_toxic_marker(text: &mut [u8], point: Vec2i, map_edge: i64) -> bool {
    place_marker(text, point, TOXIC_OVERLAY, map_edge)
}

/// DisasterMapMarkers._place_riot_marker.
fn place_riot_marker(text: &mut [u8], point: Vec2i, marker: i64, map_edge: i64) -> bool {
    place_marker(text, point, marker, map_edge)
}

fn place_marker(text: &mut [u8], point: Vec2i, marker: i64, map_edge: i64) -> bool {
    let tile_index = index(point, map_edge);

    if tile_index < 0 {
        return false;
    }

    let current = overlay::read(text, tile_index);

    if current != 0 && !overlay::is_sign(current) {
        return false;
    }

    overlay::write(text, tile_index, marker);

    true
}

/// DisasterMapState._seed_special_toxic.
fn seed_special_toxic(text: &mut [u8], site: Rect2i, point: Vec2i, map_edge: i64) -> i64 {
    let site = if site.size == Vec2i::ZERO {
        Rect2i::from(point, Vec2i::new(1, 1))
    } else {
        site
    };
    let mut changed = 0;

    for x in site.position.x..site.end().x {
        for y in site.position.y..site.end().y {
            let tile_index = x * map_edge + y;

            if overlay::read(text, tile_index) < 51 {
                overlay::write(text, tile_index, TOXIC_OVERLAY);
                changed += 1;
            }
        }
    }

    changed
}

/// DisasterMapState._spawn_explosion.
#[allow(clippy::too_many_arguments)]
pub fn spawn_explosion(
    text: &mut [u8],
    thing_data: &mut [u8],
    point: Vec2i,
    height: i64,
    state: i64,
    goal: i64,
    map_edge: i64,
    caps: &VehicleCaps,
) -> bool {
    let tile_index = index(point, map_edge);

    if tile_index < 0 || overlay::blocks_thing(overlay::read(text, tile_index)) {
        return false;
    }

    let record = caps.free_record(thing_data);

    if record == 0 {
        return false;
    }

    let offset = record * things::RECORD_SIZE;
    things::write(thing_data, offset, things::TYPE_EXPLOSION);
    things::write(thing_data, offset + 1, 0);
    things::write(thing_data, offset + 2, state);
    things::write(thing_data, offset + 3, point.x);
    things::write(thing_data, offset + 4, point.y);
    things::write(thing_data, offset + 5, height);
    things::write(thing_data, offset + 6, 8);
    things::write(thing_data, offset + 7, 8);
    things::write(thing_data, offset + 10, overlay::covered(text, tile_index));
    things::write(thing_data, offset + 11, goal);
    overlay::write(text, tile_index, overlay::thing_id(record));

    true
}

/// DisasterMapMarkers._abandon_toxic_structure.
fn abandon_toxic_structure(maps: &mut DisasterMaps, point: Vec2i, random: &mut SimRandom) -> bool {
    let edge = maps.maps.map_edge;
    let tile_index = index(point, edge);
    let tile = maps.maps.buildings[tile_index as usize] as i64;

    if !(tiles::DEVELOPED_FIRST..=tiles::DEVELOPED_3X3_LAST).contains(&tile) || is_construction_or_abandoned(tile) {
        return false;
    }

    let area = building_area(tile);
    let site = find_building_site(maps.maps.buildings, maps.maps.zones, point, tile, area, maps.rotation, edge);

    if site.size == Vec2i::ZERO {
        return false;
    }

    let anchor = Vec2i::new(site.position.x, site.end().y - 1);
    let mut zone_maps = ZoneMaps {
        buildings: &mut *maps.maps.buildings,
        zones: &mut *maps.maps.zones,
        flags: &mut *maps.maps.flags,
        misc: &mut *maps.maps.misc,
        land_value: &*maps.land_value,
        altitude: &*maps.maps.altitude,
        rotation: maps.rotation,
        map_edge: edge,
        allow_edge_buildings: false,
    };
    development::abandon(&mut zone_maps, anchor, if area == 3 { 4 } else { area }, 0, random);

    maps.maps.buildings[tile_index as usize] as i64 != tile
}

fn is_construction_or_abandoned(tile: i64) -> bool {
    (tiles::CONSTRUCTION_1X1_FIRST..=tiles::DEVELOPED_1X1_LAST).contains(&tile)
        || (tiles::CONSTRUCTION_2X2_FIRST..=tiles::DEVELOPED_2X2_LAST).contains(&tile)
        || (tiles::CONSTRUCTION_3X3_FIRST..=tiles::DEVELOPED_3X3_LAST).contains(&tile)
}

fn lowest_toxic_direction(altitude: &[u8], point: Vec2i, map_edge: i64) -> i64 {
    let point_index = index(point, map_edge);
    let mut lowest = altitude_word(altitude, point_index) & 0x1f;
    let mut direction = -1;

    for (checked, offset) in CARDINAL_DIRECTIONS.iter().enumerate() {
        let target_index = index(point + *offset, map_edge);

        if target_index < 0 {
            continue;
        }

        let height = altitude_word(altitude, target_index) & 0x1f;

        if height < lowest {
            lowest = height;
            direction = checked as i64;
        }
    }

    direction
}

fn riot_supports(buildings: &[u8], point: Vec2i, map_edge: i64) -> bool {
    let tile_index = index(point, map_edge);

    if tile_index < 0 {
        return false;
    }

    let tile = buildings[tile_index as usize] as i64;

    (tile > tiles::EMPTY && tile < tiles::RADIOACTIVE_WASTE)
        || (tile > tiles::ROAD_STRAIGHT_1 && tile < tiles::RAIL_STRAIGHT_1)
        || (tile > tiles::RAIL_SLOPE_8 && tile < tiles::RAIL_POWER_CROSSING_1)
        || tile == tiles::HIGHWAY_ROAD_CROSSING_1
        || tile == tiles::HIGHWAY_ROAD_CROSSING_2
        || (tile > tiles::POWER_BRIDGE && tile < tiles::HIGHWAY_SLOPE_1)
}
