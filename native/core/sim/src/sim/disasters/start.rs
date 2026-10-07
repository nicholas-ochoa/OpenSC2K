//! Disaster starts, as DisasterStartPhase and the DisasterStart helper classes.

use std::collections::HashSet;

use super::damage::{self, append_damage_events, burn_structure};
use super::{DisasterStartResult, RuntimeEvents, START_CHUNKS, Snapshot, index, sounds};
use crate::sim::bytes::read_u32_be;
use crate::sim::city::City;
use crate::sim::events::{EffectEvent, SoundEvent};
use crate::sim::geom::Vec2i;
use crate::sim::growth::special::replace_special_building;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::overlay;
use crate::sim::random::{SimLfsrRandom, SimRandom};
use crate::sim::things;
use crate::sim::tools::demolish::find_building_site;
use crate::sim::tools::terrain::retile_region;
use crate::sim::value::Ints32;

pub const DISASTER_NONE: i64 = 0;
pub const DISASTER_FIRE: i64 = 1;
pub const DISASTER_FLOOD: i64 = 2;
pub const DISASTER_RIOT: i64 = 3;
pub const DISASTER_TOXIC_SPILL: i64 = 4;
pub const DISASTER_AIR_CRASH: i64 = 5;
pub const DISASTER_EARTHQUAKE: i64 = 6;
pub const DISASTER_TORNADO: i64 = 7;
pub const DISASTER_MONSTER: i64 = 8;
pub const DISASTER_MELTDOWN: i64 = 9;
pub const DISASTER_MICROWAVE: i64 = 10;
pub const DISASTER_VOLCANO: i64 = 11;
pub const DISASTER_FIRESTORM: i64 = 12;
pub const DISASTER_MASS_RIOTS: i64 = 13;
pub const DISASTER_MASS_FLOODS: i64 = 14;
pub const DISASTER_POLLUTION: i64 = 15;
pub const DISASTER_HURRICANE: i64 = 16;
pub const DISASTER_HELICOPTER_CRASH: i64 = 17;
pub const DISASTER_PLANE_CRASH: i64 = 18;
pub const SOUND_SIREN: i64 = 520;
pub const SOUND_FLOOD: i64 = 511;
pub const SOUND_RIOT: i64 = 512;
pub const SOUND_MICROWAVE: i64 = 514;
pub const SOUND_EARTHQUAKE: i64 = 504;
pub const SOUND_VOLCANO: i64 = 507;
pub const SOUND_HURRICANE: i64 = 502;
/// SIMCITY.EXE 0x0045cf10 loops the siren for five plays when a disaster starts.
pub const SIREN_PLAYS: i64 = 5;
const VOLCANO_BUDGET: i64 = 25000;
const FIRE_SPIRAL: [Vec2i; 4] = [Vec2i::new(0, -1), Vec2i::new(1, 0), Vec2i::new(0, 1), Vec2i::new(-1, 0)];
const EIGHT_DIRECTIONS: [Vec2i; 8] = [
    Vec2i::new(0, -1),
    Vec2i::new(1, -1),
    Vec2i::new(1, 0),
    Vec2i::new(1, 1),
    Vec2i::new(0, 1),
    Vec2i::new(-1, 1),
    Vec2i::new(-1, 0),
    Vec2i::new(-1, -1),
];
const RANDOM_REQUIRED: &str = "a compatible process random generator is required";
const LFSR_REQUIRED: &str = "a compatible LFSR generator is required";

/// The start sounds, then the siren loop.
fn start_sounds(ids: &[i64]) -> Vec<SoundEvent> {
    let mut events = sounds(ids);
    events.push(SoundEvent::looped(SOUND_SIREN, SIREN_PLAYS));
    events
}

/// DisasterStartObjectsState._result.
fn result(disaster_type: i64, point: Vec2i, started: bool, complete: bool, record: i64) -> DisasterStartResult {
    let mut result = DisasterStartResult {
        disaster_type,
        point,
        started,
        implemented: complete,
        record,
        ..Default::default()
    };
    result.base.ok = true;

    if started {
        result.base.sound_events = start_sounds(&[]);
        result.base.view_center_requests.push(point);
    }

    result.base.complete = complete;
    result
}

fn starts_fire(result_code: i64) -> bool {
    result_code == 1 || result_code == 3 || result_code == 4
}

/// The signed 16-bit attempt count from the city population.
fn population_attempts(city: &City) -> i64 {
    let count = (city.misc_u32(misc_layout::NORMAL_POPULATION) / 10000 + 5) & 0xffff;

    if count & 0x8000 != 0 { count - 0x10000 } else { count }
}

/// DisasterStartPhase.start. `scenario` is true while a scenario runs.
pub fn start(
    city: &mut City,
    disaster_type: i64,
    point: Vec2i,
    random: Option<&mut SimRandom>,
    lfsr: Option<&mut SimLfsrRandom>,
    scenario: bool,
) -> DisasterStartResult {
    match disaster_type {
        DISASTER_NONE => result(disaster_type, point, false, true, 0),
        DISASTER_FIRE => start_fire(city, random, lfsr),
        DISASTER_FLOOD => match lfsr {
            Some(lfsr) => start_flood(city, point, lfsr),
            None => DisasterStartResult::failed(LFSR_REQUIRED),
        },
        DISASTER_RIOT => start_riot(city, point, random),
        DISASTER_TOXIC_SPILL => start_toxic_spill(city, point),
        DISASTER_AIR_CRASH | DISASTER_HELICOPTER_CRASH => {
            let mut result = result(disaster_type, point, true, true, 0);
            result.base.view_center_requests.clear();
            result
        }
        DISASTER_EARTHQUAKE => start_earthquake(city, point, random, lfsr),
        DISASTER_MELTDOWN => start_meltdown(city, point, random, lfsr),
        DISASTER_MICROWAVE => start_microwave(city, random, lfsr),
        DISASTER_VOLCANO => start_volcano(city, point, random),
        DISASTER_FIRESTORM => start_firestorm(city, point, random, lfsr),
        DISASTER_MASS_RIOTS => start_mass_riots(city, point, random),
        DISASTER_MASS_FLOODS => start_mass_floods(city, point, random, lfsr),
        DISASTER_POLLUTION => start_pollution(city, point, random),
        DISASTER_HURRICANE => start_hurricane(city, point, random, lfsr),
        DISASTER_PLANE_CRASH => start_plane_crash(city, lfsr),
        DISASTER_TORNADO | DISASTER_MONSTER => start_moving_disaster(city, disaster_type, point, random, scenario),
        _ => result(disaster_type, point, false, false, 0),
    }
}

/// The tornado and monster part of DisasterStartPhase.start (0x0045f090,
/// 0x0045ee10).
fn start_moving_disaster(
    city: &mut City,
    disaster_type: i64,
    point: Vec2i,
    random: Option<&mut SimRandom>,
    scenario: bool,
) -> DisasterStartResult {
    let Some(random) = random else {
        return DisasterStartResult::failed(RANDOM_REQUIRED);
    };

    if city.missing_or_resized(&["XTHG", "XTXT"]).is_some() {
        return DisasterStartResult::failed("disaster moving-object data is missing or invalid");
    }

    let edge = city.map_size;
    let caps = crate::sim::moving::spawner::VehicleCaps::for_city(city);
    let tornado = disaster_type == DISASTER_TORNADO;
    let thing_type = if tornado { things::TYPE_TORNADO } else { things::TYPE_MONSTER };
    let mut thing_data = city.xthg.data.clone();
    let mut text = city.xtxt.data.clone();

    if count_type(&thing_data, thing_type) > 0 {
        return result(disaster_type, point, false, true, 0);
    }

    let clamped = Vec2i::new(point.x.clamp(0, edge - 1), point.y.clamp(0, edge - 1));
    let tile_index = clamped.x * edge + clamped.y;
    let overlay_id = overlay::read(&text, tile_index);

    if overlay::is_thing(overlay_id) {
        remove_thing(&mut thing_data, &mut text, overlay::thing_record(overlay_id), edge);
    }

    let record = caps.free_record(&thing_data);

    if record == 0 {
        return result(disaster_type, clamped, false, false, 0);
    }

    let offset = record * things::RECORD_SIZE;
    things::write(&mut thing_data, offset, thing_type);
    let direction = if tornado { random.next_u15() & 7 } else { 2 };
    things::write(&mut thing_data, offset + 1, direction);
    things::write(&mut thing_data, offset + 2, 0);
    things::write(&mut thing_data, offset + 3, clamped.x);
    things::write(&mut thing_data, offset + 4, clamped.y);
    let height = if tornado { city.land_altitude(clamped.x, clamped.y) } else { 15 };
    things::write(&mut thing_data, offset + 5, height);
    things::write(&mut thing_data, offset + 6, 8);
    things::write(&mut thing_data, offset + 7, 8);
    let dx = random.next_u15() & 0x7f;
    things::write(&mut thing_data, offset + 8, dx);
    let dy = random.next_u15() & 0x7f;
    things::write(&mut thing_data, offset + 9, dy);
    things::write(&mut thing_data, offset + 10, overlay::covered(&text, tile_index));

    // a monster in a scenario only starts fires and draws no random numbers
    if disaster_type == DISASTER_MONSTER {
        things::write(&mut thing_data, offset + 11, 0);

        if !scenario && random.next_u15() & 1 == 0 {
            let goal = random.next_u15() % 3 + 1;
            things::write(&mut thing_data, offset + 11, goal);
        }
    }

    overlay::write(&mut text, tile_index, overlay::thing_id(record));
    city.xthg.replace(thing_data);
    city.xtxt.replace(text);
    let mut result = result(disaster_type, clamped, true, true, record);

    // the original centers a monster 8 tiles up and to the left
    if disaster_type == DISASTER_MONSTER {
        result.base.view_center_requests = vec![Vec2i::new((clamped.x - 8).max(0), (clamped.y - 8).max(0))];
    }

    result
}

fn start_plane_crash(city: &mut City, lfsr: Option<&mut SimLfsrRandom>) -> DisasterStartResult {
    let Some(lfsr) = lfsr else {
        return DisasterStartResult::failed(LFSR_REQUIRED);
    };

    if city.missing_or_resized(&["XTHG", "XTXT"]).is_some() {
        return DisasterStartResult::failed("plane-crash moving-object data is missing or invalid");
    }

    let edge = city.map_size;
    let mut point;

    loop {
        let x = lfsr.next_mask(0xffff) % (edge / 2) + edge / 4;
        let y = lfsr.next_mask(0xffff) % (edge / 2) + edge / 4;
        point = Vec2i::new(x, y);

        if overlay::read(&city.xtxt.data, index(point, edge)) == 0 {
            break;
        }
    }

    // an sc2x city counts disaster aircraft against its airplane cap
    let caps = crate::sim::moving::spawner::VehicleCaps::for_city(city);
    let at_cap = caps.sc2x && count_type(&city.xthg.data, things::TYPE_AIRPLANE) >= caps.airplanes;
    let record = if at_cap { 0 } else { caps.free_record(&city.xthg.data) };

    if record == 0 {
        return result(DISASTER_PLANE_CRASH, point, false, true, 0);
    }

    let offset = record * things::RECORD_SIZE;
    let thing_data = city.xthg.mutate();
    things::write(thing_data, offset, things::TYPE_AIRPLANE);
    things::write(thing_data, offset + 2, 7);
    things::write(thing_data, offset + 3, point.x);
    things::write(thing_data, offset + 4, point.y);
    things::write(thing_data, offset + 5, 16);
    things::write(thing_data, offset + 6, 8);
    things::write(thing_data, offset + 7, 8);
    things::write(thing_data, offset + 10, 0);
    overlay::write(city.xtxt.mutate(), index(point, edge), overlay::thing_id(record));

    result(DISASTER_PLANE_CRASH, point, true, true, record)
}

fn count_type(thing_data: &[u8], thing_type: i64) -> i64 {
    (1..things::count(thing_data))
        .filter(|record| things::read(thing_data, record * things::RECORD_SIZE) == thing_type)
        .count() as i64
}

fn remove_thing(thing_data: &mut [u8], text: &mut [u8], record: i64, map_edge: i64) {
    if record <= 0 || record >= things::count(thing_data) {
        return;
    }

    let offset = record * things::RECORD_SIZE;
    let point = Vec2i::new(things::read(thing_data, offset + 3), things::read(thing_data, offset + 4));

    if point.x < map_edge && point.y < map_edge {
        let tile_index = point.x * map_edge + point.y;

        if overlay::read(text, tile_index) == overlay::thing_id(record) {
            let label = things::read(thing_data, offset + 10);
            overlay::lift_object(text, thing_data, record, tile_index, label);
        }
    }

    for byte_index in 0..things::RECORD_SIZE {
        things::write(thing_data, offset + byte_index, 0);
    }
}

fn start_toxic_spill(city: &mut City, point: Vec2i) -> DisasterStartResult {
    let tile_index = index(point, city.map_size);

    if tile_index < 0 {
        return result(DISASTER_TOXIC_SPILL, point, false, true, 0);
    }

    if city.missing_or_resized(&["XTXT"]).is_some() {
        return DisasterStartResult::failed("toxic-spill map data is missing or invalid");
    }

    overlay::write(city.xtxt.mutate(), tile_index, 0xfb);

    result(DISASTER_TOXIC_SPILL, point, true, true, 0)
}

fn start_riot(city: &mut City, point: Vec2i, random: Option<&mut SimRandom>) -> DisasterStartResult {
    let Some(random) = random else {
        return DisasterStartResult::failed(RANDOM_REQUIRED);
    };

    if city.missing_or_resized(&["XBLD", "XBIT", "XTXT"]).is_some() {
        return DisasterStartResult::failed("riot disaster map data is missing or invalid");
    }

    let edge = city.map_size;
    let mut text = city.xtxt.data.clone();
    let mut current = point;
    let mut seed_points = Vec::new();

    for _ in 0..3 {
        crate::sim::budget::checkpoint();
        let seed = find_riot_seed(current, &city.xbld.data, &city.xbit.data, &text, edge);

        if seed.x < 0 {
            if seed_points.is_empty() {
                return riot_result(DISASTER_RIOT, point, seed_points, 3);
            }

            continue;
        }

        current = seed;
        let marker = super::RIOT_OVERLAY_FORWARD + (random.next_u15() & 1);
        overlay::write(&mut text, index(seed, edge), marker);
        seed_points.push(seed);
    }

    city.xtxt.replace(text);

    riot_result(DISASTER_RIOT, current, seed_points, 3)
}

fn start_mass_riots(city: &mut City, point: Vec2i, random: Option<&mut SimRandom>) -> DisasterStartResult {
    let Some(random) = random else {
        return DisasterStartResult::failed(RANDOM_REQUIRED);
    };

    if city.missing_or_resized(&["XBLD", "XBIT", "XTXT"]).is_some() {
        return DisasterStartResult::failed("mass-riot disaster map data is missing or invalid");
    }

    let edge = city.map_size;
    let attempt_count = population_attempts(city);
    let mut text = city.xtxt.data.clone();
    let mut final_point = point;
    let mut seed_points = Vec::new();

    for _ in 0..attempt_count.max(0) {
        let dx = (random.next_u15() & 0x1f) - 16;
        let dy = (random.next_u15() & 0x1f) - 16;
        let candidate = point + Vec2i::new(dx, dy);

        if index(candidate, edge) < 0 {
            continue;
        }

        final_point = candidate;
        let seed = find_riot_seed(candidate, &city.xbld.data, &city.xbit.data, &text, edge);

        if seed.x < 0 {
            continue;
        }

        final_point = seed;
        let marker = super::RIOT_OVERLAY_FORWARD + (random.next_u15() & 1);
        overlay::write(&mut text, index(seed, edge), marker);
        seed_points.push(seed);
    }

    if !seed_points.is_empty() {
        city.xtxt.replace(text);
    }

    riot_result(DISASTER_MASS_RIOTS, final_point, seed_points, attempt_count.max(0))
}

fn find_riot_seed(origin: Vec2i, buildings: &[u8], flags: &[u8], text: &[u8], map_edge: i64) -> Vec2i {
    let mut point = origin;
    let mut direction = 0;
    let mut run_length = 1;
    let mut step = 0;

    while run_length < map_edge {
        point = point + FIRE_SPIRAL[direction];
        let tile_index = index(point, map_edge);

        if tile_index >= 0
            && riot_start_supports(buildings[tile_index as usize] as i64)
            && flags[tile_index as usize] as i64 & flag_bits::WATER == 0
            && overlay::read(text, tile_index) == 0
        {
            return point;
        }

        step += 1;

        if step >= run_length {
            step = 0;

            if direction & 1 != 0 {
                run_length += 1;
            }

            direction = (direction + 1) & 3;
        }
    }

    Vec2i::NONE
}

fn riot_start_supports(tile: i64) -> bool {
    (tiles::ROAD_STRAIGHT_1..=tiles::ROAD_CROSSROADS).contains(&tile)
        || (tiles::TUNNEL_ENTRANCE_1..=tiles::ROAD_RAIL_CROSSING_2).contains(&tile)
        || tile == tiles::HIGHWAY_ROAD_CROSSING_1
        || tile == tiles::HIGHWAY_ROAD_CROSSING_2
        || (tiles::HIGHWAY_ONRAMP_1..=tiles::HIGHWAY_ONRAMP_4).contains(&tile)
}

fn riot_result(disaster_type: i64, point: Vec2i, seed_points: Vec<Vec2i>, attempt_count: i64) -> DisasterStartResult {
    let started = !seed_points.is_empty();
    let mut result = result(disaster_type, point, started, true, 0);
    result.counters.set("attempt_count", attempt_count);
    result.counters.set("seed_writes", seed_points.len() as i64);
    let ids = vec![SOUND_RIOT; seed_points.len()];
    result.seed_points = seed_points;
    result.base.sound_events = if started { start_sounds(&ids) } else { sounds(&ids) };
    result
}

fn start_pollution(city: &mut City, point: Vec2i, random: Option<&mut SimRandom>) -> DisasterStartResult {
    let Some(random) = random else {
        return DisasterStartResult::failed(RANDOM_REQUIRED);
    };

    if city.missing_or_resized(&["XTXT"]).is_some() {
        return DisasterStartResult::failed("pollution-disaster map data is missing or invalid");
    }

    let edge = city.map_size;
    let attempt_count = population_attempts(city);
    let mut text = city.xtxt.data.clone();
    let mut seed_writes = 0;
    // 0x0045d8b0 moves the disaster point to each seed and centers the view
    // on the requested point
    let mut last_seed = point;

    for _ in 0..attempt_count.max(0) {
        let dx = (random.next_u15() & 7) - 4;
        let dy = (random.next_u15() & 7) - 4;
        let seed = point + Vec2i::new(dx, dy);
        let tile_index = index(seed, edge);

        if tile_index < 0 {
            continue;
        }

        overlay::write(&mut text, tile_index, 0xfb);
        seed_writes += 1;
        last_seed = seed;
    }

    if seed_writes > 0 {
        city.xtxt.replace(text);
    }

    let mut result = result(DISASTER_POLLUTION, last_seed, seed_writes > 0, true, 0);

    if seed_writes > 0 {
        result.base.view_center_requests = vec![point];
    }

    result.counters.set("attempt_count", attempt_count.max(0));
    result.counters.set("seed_writes", seed_writes);
    result
}

fn start_meltdown(
    city: &mut City,
    requested_point: Vec2i,
    random: Option<&mut SimRandom>,
    lfsr: Option<&mut SimLfsrRandom>,
) -> DisasterStartResult {
    let Some(random) = random else {
        return DisasterStartResult::failed(RANDOM_REQUIRED);
    };

    let Some(lfsr) = lfsr else {
        return DisasterStartResult::failed(LFSR_REQUIRED);
    };

    let Some(snapshot) = Snapshot::take(city, &START_CHUNKS) else {
        return DisasterStartResult::failed("meltdown disaster input chunks are missing or invalid");
    };

    let edge = city.map_size;
    let mut events = RuntimeEvents::default();
    let plant_point = find_nuclear_power_plant(&city.xbld.data, requested_point, edge);

    if plant_point.x < 0 {
        return result(DISASTER_MELTDOWN, requested_point, false, true, 0);
    }

    let mut maps = city.disaster_maps();
    let mut center = plant_point;
    let site = find_building_site(
        maps.maps.buildings,
        maps.maps.zones,
        plant_point,
        tiles::NUCLEAR_POWER,
        4,
        maps.rotation,
        edge,
    );

    if site.size != Vec2i::ZERO {
        center = Vec2i::new(site.position.x + 1, site.end().y - 2);
    }

    // 0x0045f2b0 burns the plant with fire marks and leaves the fire burning
    let plant_damage = burn_structure(&mut maps, center, random, lfsr, true, false, true);
    append_damage_events(Some(&mut events), &plant_damage);
    let mut gate_hits = 0;
    let mut fire_damage_attempts = 0;
    let mut structure_damage_attempts = 0;
    let mut radioactive_writes = 0;
    let mut toxic_writes = 0;

    for x_offset in -32..33 {
        crate::sim::budget::checkpoint();

        for y_offset in -32..33 {
            if random.next_u15() & 0x1f != 0 {
                continue;
            }

            gate_hits += 1;
            let target = center + Vec2i::new(x_offset, y_offset);
            let tile_index = index(target, edge);

            if tile_index < 0 {
                continue;
            }

            if random.next_u15() & 3 == 0 {
                fire_damage_attempts += 1;
                damage::apply(&mut maps, target, random, lfsr, true, Some(&mut events));
            } else {
                structure_damage_attempts += 1;
                burn_structure(&mut maps, target, random, lfsr, false, false, false);

                if random.next_u15() & 1 != 0 {
                    if maps.maps.flags[tile_index as usize] & 0x04 == 0 {
                        if write_radioactivity(&mut maps, target) {
                            radioactive_writes += 1;
                        }
                    } else {
                        overlay::write(maps.maps.text_overlays, tile_index, 0xfb);
                        toxic_writes += 1;
                    }
                }
            }
        }
    }

    for x_offset in -1..3 {
        crate::sim::budget::checkpoint();

        for y_offset in -2..2 {
            if random.next_u15() & 1 != 0 && write_radioactivity(&mut maps, center + Vec2i::new(x_offset, y_offset)) {
                radioactive_writes += 1;
            }
        }
    }

    let map_changed = snapshot.changed(city);
    snapshot.commit(city);
    let mut result = result(DISASTER_MELTDOWN, center, true, true, 0);
    result.plant_point = plant_point;
    result.plant_site = site;
    result.counters.set("gate_attempts", 65 * 65);
    result.counters.set("gate_hits", gate_hits);
    result.counters.set("fire_damage_attempts", fire_damage_attempts);
    result.counters.set("structure_damage_attempts", structure_damage_attempts);
    result.counters.set("radioactive_writes", radioactive_writes);
    result.counters.set("toxic_writes", toxic_writes);
    result.map_changed = map_changed;
    result.base.effect_events = events.effect_events;
    result.connection_count_changes = events.connection_changes;
    result.base.sound_events = start_sounds(&events.sound_events);
    result
}

fn find_nuclear_power_plant(buildings: &[u8], requested_point: Vec2i, map_edge: i64) -> Vec2i {
    let requested_index = index(requested_point, map_edge);

    if requested_index >= 0 && buildings[requested_index as usize] as i64 == tiles::NUCLEAR_POWER {
        return requested_point;
    }

    find_first_building(buildings, tiles::NUCLEAR_POWER, map_edge)
}

fn find_first_building(buildings: &[u8], tile: i64, map_edge: i64) -> Vec2i {
    match buildings.iter().position(|value| *value as i64 == tile) {
        Some(position) => Vec2i::new(position as i64 / map_edge, position as i64 % map_edge),
        None => Vec2i::NONE,
    }
}

fn write_radioactivity(maps: &mut super::DisasterMaps, point: Vec2i) -> bool {
    let tile_index = index(point, maps.maps.map_edge);

    if tile_index < 0 {
        return false;
    }

    let old_tile = maps.maps.buildings[tile_index as usize] as i64;
    replace_special_building(
        maps.maps.buildings,
        maps.maps.zones,
        maps.maps.misc,
        tile_index,
        tiles::RADIOACTIVE_WASTE,
    );

    old_tile != tiles::RADIOACTIVE_WASTE
}

fn start_microwave(city: &mut City, random: Option<&mut SimRandom>, lfsr: Option<&mut SimLfsrRandom>) -> DisasterStartResult {
    let Some(random) = random else {
        return DisasterStartResult::failed(RANDOM_REQUIRED);
    };

    let Some(lfsr) = lfsr else {
        return DisasterStartResult::failed(LFSR_REQUIRED);
    };

    let Some(snapshot) = Snapshot::take(city, &START_CHUNKS) else {
        return DisasterStartResult::failed("microwave disaster input chunks are missing or invalid");
    };

    let edge = city.map_size;
    let plant_point = find_first_building(&city.xbld.data, tiles::MICROWAVE_POWER, edge);

    if plant_point.x < 0 {
        return result(DISASTER_MICROWAVE, plant_point, false, true, 0);
    }

    let mut maps = city.disaster_maps();
    let mut point = plant_point;
    let mut remaining = 39;
    let mut direction = random.next_u15();
    let mut damage_points = Vec::new();
    let mut toxic_writes = 0;
    let mut view_centers = vec![plant_point];
    let mut events = RuntimeEvents::default();

    while remaining > 0 {
        let tile_index = index(point, edge);

        if tile_index < 0 {
            break;
        }

        if maps.maps.buildings[tile_index as usize] as i64 != tiles::MICROWAVE_POWER {
            if maps.maps.flags[tile_index as usize] & 0x04 != 0 {
                overlay::write(maps.maps.text_overlays, tile_index, 0xfb);
                toxic_writes += 1;
            }

            if remaining % 10 == 0 {
                view_centers.push(point);
            }

            damage::apply(&mut maps, point, random, lfsr, true, Some(&mut events));
            damage_points.push(point);
            events.sound_events.push(SOUND_MICROWAVE);
        }

        remaining -= 1;
        point = point + EIGHT_DIRECTIONS[(direction & 7) as usize];
        direction = random.next_u15();
    }

    let map_changed = snapshot.changed(city);
    snapshot.commit(city);
    let mut result = result(DISASTER_MICROWAVE, plant_point, true, true, 0);
    result.base.sound_events = start_sounds(&events.sound_events);
    result.base.effect_events = events.effect_events;
    result.connection_count_changes = events.connection_changes;
    result.base.view_center_requests = view_centers;
    result.plant_point = plant_point;
    result.path_finish = point;
    result.counters.set("path_steps", 39 - remaining);
    result.counters.set("damage_attempts", damage_points.len() as i64);
    result.damage_points = damage_points;
    result.counters.set("toxic_writes", toxic_writes);
    result.map_changed = map_changed;
    result
}

/// DisasterStartFloodWeather._start_flood.
pub fn start_flood(city: &mut City, requested_point: Vec2i, lfsr: &mut SimLfsrRandom) -> DisasterStartResult {
    let Some(snapshot) = Snapshot::take(city, &START_CHUNKS) else {
        return DisasterStartResult::failed("flood disaster input chunks are missing or invalid");
    };

    let edge = city.map_size;
    let shore = find_flood_shore(&city.xter.data, requested_point, edge);

    if shore.x >= 0 {
        let offset = shore - requested_point;

        if offset.x > 0 {
            seed_flood_if_dry(city, shore + Vec2i::new(-1, 0));
        }

        if offset.y > 0 {
            seed_flood_if_dry(city, shore + Vec2i::new(0, -1));
        }

        if offset.x < edge - 1 {
            seed_flood_if_dry(city, shore + Vec2i::new(1, 0));
        }

        if offset.y < edge - 1 {
            seed_flood_if_dry(city, shore + Vec2i::new(0, 1));
        }

        snapshot.commit(city);
        return flood_result(shore, true);
    }

    for _ in 0..200 {
        crate::sim::budget::checkpoint();
        let x = lfsr.next_mod(edge);
        let y = lfsr.next_mod(edge);
        let tile_index = index(Vec2i::new(x, y), edge);

        if city.xter.data[tile_index as usize] as i64 == terrain_ids::FLAT {
            overlay::write(&mut city.xtxt.data, tile_index, 0xfc);
            snapshot.commit(city);

            return flood_result(Vec2i::new(x, y), true);
        }
    }

    flood_result(requested_point, false)
}

/// DisasterStartFloodWeather.find_flood_shore.
pub fn find_flood_shore(terrain: &[u8], origin: Vec2i, map_edge: i64) -> Vec2i {
    let is_shore = |tile: i64| (terrain_ids::SHORE_FIRST..terrain_ids::SURFACE_WATER_FIRST).contains(&tile);

    // Retain the original search for legacy cities. Extended cities select the
    // same first match: smallest square radius, then increasing x and y.
    if map_edge == 128 {
        for radius in 0..map_edge {
            for dx in -radius..=radius {
                for dy in -radius..=radius {
                    let point = origin + Vec2i::new(dx, dy);
                    let tile_index = index(point, map_edge);

                    if tile_index >= 0 && is_shore(terrain[tile_index as usize] as i64) {
                        return point;
                    }
                }
            }
        }

        return Vec2i::NONE;
    }

    let mut selected = Vec2i::NONE;
    let mut nearest_radius = map_edge;

    for x in 0..map_edge {
        for y in 0..map_edge {
            if !is_shore(terrain[(x * map_edge + y) as usize] as i64) {
                continue;
            }

            let radius = (x - origin.x).abs().max((y - origin.y).abs());

            if radius < nearest_radius {
                nearest_radius = radius;
                selected = Vec2i::new(x, y);
            }
        }
    }

    selected
}

fn seed_flood_if_dry(city: &mut City, point: Vec2i) {
    let tile_index = index(point, city.map_size);

    if tile_index >= 0 && city.xbit.data[tile_index as usize] & 0x04 == 0 {
        overlay::write(&mut city.xtxt.data, tile_index, 0xfc);
    }
}

fn flood_result(point: Vec2i, started: bool) -> DisasterStartResult {
    let mut result = result(DISASTER_FLOOD, point, started, true, 0);

    if started {
        result.base.sound_events = start_sounds(&[SOUND_FLOOD]);
    }

    result.map_counter = if started { 60 } else { 0 };
    result
}

fn start_mass_floods(
    city: &mut City,
    center: Vec2i,
    random: Option<&mut SimRandom>,
    lfsr: Option<&mut SimLfsrRandom>,
) -> DisasterStartResult {
    let Some(random) = random else {
        return DisasterStartResult::failed(RANDOM_REQUIRED);
    };

    let Some(lfsr) = lfsr else {
        return DisasterStartResult::failed(LFSR_REQUIRED);
    };

    let Some(snapshot) = Snapshot::take(city, &START_CHUNKS) else {
        return DisasterStartResult::failed("mass-flood disaster input chunks are missing or invalid");
    };

    let edge = city.map_size;
    let attempt_count = population_attempts(city);
    let mut candidate_points = Vec::new();
    let mut seed_points = Vec::new();

    for _ in 0..attempt_count.max(0) {
        let dx = (random.next_u15() & 0x1f) - 16;
        let dy = (random.next_u15() & 0x1f) - 16;
        let candidate = center + Vec2i::new(dx, dy);

        if index(candidate, edge) < 0 {
            continue;
        }

        candidate_points.push(candidate);
        let flood = start_flood(city, candidate, lfsr);

        if !flood.base.ok {
            return flood;
        }

        if flood.started {
            seed_points.push(flood.point);
        }
    }

    let started = !seed_points.is_empty();
    let map_changed = snapshot.changed(city);
    let mut result = result(DISASTER_MASS_FLOODS, center, started, true, 0);
    result.counters.set("attempt_count", attempt_count.max(0));
    result.counters.set("valid_candidates", candidate_points.len() as i64);
    result.counters.set("seed_writes", seed_points.len() as i64);
    result.counters.set("successful_starts", seed_points.len() as i64);
    result.counters.set("delay_frames", candidate_points.len() as i64);
    result.candidate_points = candidate_points;
    result.map_changed = map_changed;

    if started {
        let ids = vec![SOUND_FLOOD; seed_points.len()];
        result.base.sound_events = start_sounds(&ids);
        result.map_counter = 60;
    }

    result.seed_points = seed_points;
    result
}

fn start_hurricane(
    city: &mut City,
    requested_point: Vec2i,
    random: Option<&mut SimRandom>,
    lfsr: Option<&mut SimLfsrRandom>,
) -> DisasterStartResult {
    let Some(random) = random else {
        return DisasterStartResult::failed(RANDOM_REQUIRED);
    };

    let Some(lfsr) = lfsr else {
        return DisasterStartResult::failed(LFSR_REQUIRED);
    };

    let Some(snapshot) = Snapshot::take(city, &START_CHUNKS) else {
        return DisasterStartResult::failed("hurricane disaster input chunks are missing or invalid");
    };

    let edge = city.map_size;
    let direction = (city.compass_rotation() + 1) & 3;
    let mut maps = city.disaster_maps();
    let mut damage_points = Vec::new();
    let mut flood_points = Vec::new();
    let mut events = RuntimeEvents::default();
    // The sounds and the damage sounds share one list, as in GDScript.
    events.sound_events.push(SOUND_HURRICANE);
    let mut damage_scans = 0;
    let tall = |maps: &super::DisasterMaps, x: i64, y: i64| maps.maps.buildings[(x * edge + y) as usize] as i64 > tiles::TREES_7;

    match direction {
        0 => {
            for _ in 0..20 {
                damage_scans += 1;
                let x = lfsr.next_mod(edge);
                let mut y = edge - 1;

                while y >= 0 {
                    if y > 0 && tall(&maps, x, y) {
                        break;
                    }

                    y -= lfsr.next_mod(20);
                }

                if y > 0 {
                    hurricane_damage(&mut maps, Vec2i::new(x, y), random, lfsr, &mut damage_points, &mut events, true);
                }
            }

            events.sound_events.push(SOUND_HURRICANE);
            hurricane_flood_edge(&mut maps, lfsr, direction, 50, &mut flood_points);
        }
        1 => {
            for _ in 0..20 {
                damage_scans += 1;
                let y = lfsr.next_mod(edge);
                let mut x = edge - 1;

                while x >= 0 {
                    if x > 0 && tall(&maps, x, y) {
                        break;
                    }

                    x -= lfsr.next_mod(20);
                }

                if x > 0 {
                    hurricane_damage(&mut maps, Vec2i::new(x, y), random, lfsr, &mut damage_points, &mut events, false);
                }
            }

            events.sound_events.push(SOUND_HURRICANE);
            hurricane_flood_edge(&mut maps, lfsr, direction, 100, &mut flood_points);
        }
        2 => {
            let mut attempt = 0;

            while attempt < 20 {
                damage_scans += 1;
                let mut next_attempt = attempt + 1;
                let x = lfsr.next_mod(edge);
                let mut y = 0;

                while y < edge {
                    if y < edge - 1 && tall(&maps, x, y) {
                        break;
                    }

                    y += lfsr.next_mod(20);
                }

                if y < edge - 1 {
                    next_attempt = attempt + 2;
                    hurricane_damage(&mut maps, Vec2i::new(x, y), random, lfsr, &mut damage_points, &mut events, false);
                }

                attempt = next_attempt;
            }

            events.sound_events.push(SOUND_HURRICANE);
            hurricane_flood_edge(&mut maps, lfsr, direction, 100, &mut flood_points);
        }
        _ => {
            for _ in 0..20 {
                damage_scans += 1;
                let y = lfsr.next_mod(edge);
                let mut x = 0;

                while x < edge {
                    if x < edge - 1 && tall(&maps, x, y) {
                        break;
                    }

                    x += lfsr.next_mod(20);
                }

                if x < edge - 1 {
                    hurricane_damage(&mut maps, Vec2i::new(x, y), random, lfsr, &mut damage_points, &mut events, true);
                }
            }

            events.sound_events.push(SOUND_HURRICANE);
            hurricane_flood_edge(&mut maps, lfsr, direction, 50, &mut flood_points);
        }
    }

    events.sound_events.push(SOUND_HURRICANE);
    let map_changed = snapshot.changed(city);
    snapshot.commit(city);
    let mut result = result(DISASTER_HURRICANE, requested_point, true, true, 0);
    result.base.sound_events = start_sounds(&events.sound_events);
    result.base.view_center_requests.clear();
    result.base.effect_events = events.effect_events;
    result.connection_count_changes = events.connection_changes;
    result.map_counter = 60;
    result.hurricane_counter = 50;
    result.direction = direction;
    result.counters.set("damage_scans", damage_scans);
    result.counters.set("damage_attempts", damage_points.len() as i64);
    result.damage_points = damage_points;
    result
        .counters
        .set("flood_attempts", if direction == 0 || direction == 3 { 50 } else { 100 });
    result.counters.set("flood_writes", flood_points.len() as i64);
    result.flood_points = flood_points;
    result.map_changed = map_changed;
    result
}

#[allow(clippy::too_many_arguments)]
fn hurricane_damage(
    maps: &mut super::DisasterMaps,
    point: Vec2i,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    damage_points: &mut Vec<Vec2i>,
    events: &mut RuntimeEvents,
    emit_effects: bool,
) {
    let damage = burn_structure(maps, point, random, lfsr, false, false, emit_effects);
    damage_points.push(point);

    if emit_effects {
        append_damage_events(Some(events), &damage);
    }
}

fn hurricane_flood_edge(
    maps: &mut super::DisasterMaps,
    lfsr: &mut SimLfsrRandom,
    direction: i64,
    attempt_count: i64,
    flood_points: &mut Vec<Vec2i>,
) {
    let edge = maps.maps.map_edge;
    let low = |maps: &super::DisasterMaps, point: Vec2i| {
        maps.maps.buildings[(point.x * edge + point.y) as usize] as i64 <= tiles::RADIOACTIVE_WASTE
    };

    for _ in 0..attempt_count {
        let fixed = lfsr.next_mod(edge);
        let mut point;

        match direction {
            0 => {
                point = Vec2i::new(fixed, edge - 1);

                while point.y >= 0 && low(maps, point) {
                    point.y -= 1;
                }

                if point.y <= 0 {
                    continue;
                }
            }
            1 => {
                point = Vec2i::new(edge - 1, fixed);

                while point.x >= 0 && low(maps, point) {
                    point.x -= 1;
                }

                if point.x <= 0 {
                    continue;
                }
            }
            2 => {
                point = Vec2i::new(fixed, 0);

                while point.y < edge - 1 && low(maps, point) {
                    point.y += 1;
                }

                if point.y >= edge - 1 {
                    continue;
                }
            }
            _ => {
                point = Vec2i::new(0, fixed);

                while point.x < edge && low(maps, point) {
                    point.x += 1;
                }

                if point.x >= edge - 1 {
                    continue;
                }
            }
        }

        overlay::write(maps.maps.text_overlays, index(point, edge), 0xfc);
        flood_points.push(point);
    }
}

fn start_fire(city: &mut City, random: Option<&mut SimRandom>, lfsr: Option<&mut SimLfsrRandom>) -> DisasterStartResult {
    let Some(random) = random else {
        return DisasterStartResult::failed(RANDOM_REQUIRED);
    };

    let Some(lfsr) = lfsr else {
        return DisasterStartResult::failed(LFSR_REQUIRED);
    };

    let Some(snapshot) = Snapshot::take(city, &START_CHUNKS) else {
        return DisasterStartResult::failed("fire disaster input chunks are missing or invalid");
    };

    let edge = city.map_size;
    let mut events = RuntimeEvents::default();
    let center_x = read_u32_be(&city.misc.data, misc_layout::CITY_CENTER_X);
    let center_y = read_u32_be(&city.misc.data, misc_layout::CITY_CENTER_Y);
    let x = center_x - 20 + random.next_u15() % 40;
    let y = center_y - 20 + random.next_u15() % 40;
    let mut point = Vec2i::new(x, y);
    let mut direction = 0;
    let mut run_length = 1;
    let mut step = 0;
    let mut started = false;

    {
        let mut maps = city.disaster_maps();

        while run_length < 64 {
            point = point + FIRE_SPIRAL[direction];
            let tile_index = index(point, edge);

            if tile_index >= 0
                && maps.maps.buildings[tile_index as usize] as i64 > tiles::RAIL_SUBWAY_ENTRANCE_4
                && starts_fire(damage::apply(&mut maps, point, random, lfsr, false, Some(&mut events)))
            {
                started = true;
                break;
            }

            step += 1;

            if step >= run_length {
                step = 0;

                if direction & 1 != 0 {
                    run_length += 1;
                }

                direction = (direction + 1) & 3;
            }
        }

        if !started {
            for _ in 0..200 {
                crate::sim::budget::checkpoint();
                let x = lfsr.next_mod(edge);
                let y = lfsr.next_mod(edge);
                point = Vec2i::new(x, y);

                if starts_fire(damage::apply(&mut maps, point, random, lfsr, false, Some(&mut events))) {
                    started = true;
                    break;
                }
            }
        }
    }

    if !started {
        snapshot.restore(city);
        let mut result = result(DISASTER_FIRE, point, false, true, 0);
        result.base.notice_ids = Ints32(vec![0xf5]);

        return result;
    }

    snapshot.commit(city);
    let mut result = result(DISASTER_FIRE, point, true, true, 0);
    result.base.effect_events = events.effect_events;
    result.connection_count_changes = events.connection_changes;
    result.base.sound_events = start_sounds(&events.sound_events);
    result
}

fn start_earthquake(
    city: &mut City,
    point: Vec2i,
    random: Option<&mut SimRandom>,
    lfsr: Option<&mut SimLfsrRandom>,
) -> DisasterStartResult {
    let Some(random) = random else {
        return DisasterStartResult::failed(RANDOM_REQUIRED);
    };

    let Some(lfsr) = lfsr else {
        return DisasterStartResult::failed(LFSR_REQUIRED);
    };

    let Some(snapshot) = Snapshot::take(city, &START_CHUNKS) else {
        return DisasterStartResult::failed("earthquake disaster input chunks are missing or invalid");
    };

    let edge = city.map_size;
    let mut maps = city.disaster_maps();
    let mut events = RuntimeEvents::default();
    let mut gate_hits = 0;
    let mut eligible_targets = 0;
    let mut fire_damage_attempts = 0;
    let mut structure_damage_attempts = 0;

    for x_offset in -32..33 {
        crate::sim::budget::checkpoint();

        for y_offset in -32..33 {
            if random.next_u15() & 0x3f != 0 {
                continue;
            }

            gate_hits += 1;
            let target = point + Vec2i::new(x_offset, y_offset);
            let tile_index = index(target, edge);

            if tile_index < 0 || maps.maps.buildings[tile_index as usize] as i64 <= tiles::SMALL_PARK {
                continue;
            }

            eligible_targets += 1;

            if random.next_u15() & 3 == 0 {
                fire_damage_attempts += 1;
                damage::apply(&mut maps, target, random, lfsr, false, Some(&mut events));
            } else {
                structure_damage_attempts += 1;
                burn_structure(&mut maps, target, random, lfsr, false, false, false);
            }
        }
    }

    let map_changed = snapshot.changed(city);
    snapshot.commit(city);
    let mut result = result(DISASTER_EARTHQUAKE, point, true, true, 0);
    result.counters.set("gate_attempts", 65 * 65);
    result.counters.set("gate_hits", gate_hits);
    result.counters.set("eligible_targets", eligible_targets);
    result.counters.set("fire_damage_attempts", fire_damage_attempts);
    result.counters.set("structure_damage_attempts", structure_damage_attempts);
    result.map_changed = map_changed;
    let mut effect_events = vec![EffectEvent::earthquake()];
    effect_events.append(&mut events.effect_events);
    result.connection_count_changes = std::mem::take(&mut events.connection_changes);
    result.base.effect_events = effect_events;
    let mut ids = vec![SOUND_EARTHQUAKE; 24];
    ids.append(&mut events.sound_events);
    result.base.sound_events = start_sounds(&ids);
    result
}

fn start_firestorm(
    city: &mut City,
    center: Vec2i,
    random: Option<&mut SimRandom>,
    lfsr: Option<&mut SimLfsrRandom>,
) -> DisasterStartResult {
    let Some(random) = random else {
        return DisasterStartResult::failed(RANDOM_REQUIRED);
    };

    let Some(lfsr) = lfsr else {
        return DisasterStartResult::failed(LFSR_REQUIRED);
    };

    let Some(snapshot) = Snapshot::take(city, &START_CHUNKS) else {
        return DisasterStartResult::failed("firestorm disaster input chunks are missing or invalid");
    };

    let edge = city.map_size;
    let mut maps = city.disaster_maps();
    let mut point = center;
    let mut direction = 0;
    let mut run_length = 1;
    let mut run_step = 0;
    let mut remaining = 65;
    let mut scan_steps = 0;
    let mut attempted_in_map = 0;
    let mut result_codes = Vec::new();
    let mut accepted_points = Vec::new();
    let mut events = RuntimeEvents::default();

    while remaining > 0 && run_length < edge {
        point = point + FIRE_SPIRAL[direction];
        scan_steps += 1;

        if index(point, edge) >= 0 {
            attempted_in_map += 1;
            let result_code = damage::apply(&mut maps, point, random, lfsr, true, Some(&mut events));

            // the original reports rubble as no damage, so rubble does not count
            if starts_fire(result_code) {
                remaining -= 1;
                result_codes.push(result_code as i32);
                accepted_points.push(point);
            }
        }

        run_step += 1;

        if run_step >= run_length {
            run_step = 0;

            if direction & 1 != 0 {
                run_length += 1;
            }

            direction = (direction + 1) & 3;
        }
    }

    let started = remaining < 65;
    let map_changed = snapshot.changed(city);
    snapshot.commit(city);
    // 0x0045e030 moves the disaster point to each new fire
    let last_fire = accepted_points.last().copied().unwrap_or(center);
    let mut result = result(DISASTER_FIRESTORM, last_fire, started, true, 0);
    result.requested_point = center;
    result.scan_finish = point;
    result.counters.set("scan_steps", scan_steps);
    result.counters.set("attempted_in_map", attempted_in_map);
    result.counters.set("successful_cells", 65 - remaining);
    result.counters.set("remaining_cells", remaining);
    result.result_codes = Ints32(result_codes);
    result.accepted_points = accepted_points;
    result.map_changed = map_changed;
    result.base.effect_events = events.effect_events;
    result.connection_count_changes = events.connection_changes;

    if started {
        result.base.view_center_requests = vec![point];
        result.base.sound_events = start_sounds(&events.sound_events);
    }

    result
}

// The volcano raises terrain with the TerrainEditHeights raise planner.

const MAX_RAISE_SOURCE: i64 = 29;
const NEIGHBOR_OFFSETS: [Vec2i; 8] = EIGHT_DIRECTIONS;
const CARDINAL_OFFSETS: [Vec2i; 4] = FIRE_SPIRAL;
const RAISE_DEPENDENCY_OFFSETS: [Vec2i; 4] = [Vec2i::new(-1, 0), Vec2i::new(0, -1), Vec2i::new(1, 0), Vec2i::new(0, 1)];

/// Insertion-ordered unique indices, as a PackedInt32Array with has() checks.
#[derive(Default)]
struct OrderedIndices {
    order: Vec<i64>,
    seen: HashSet<i64>,
}

impl OrderedIndices {
    fn add(&mut self, value: i64) {
        if self.seen.insert(value) {
            self.order.push(value);
        }
    }
}

/// A TerrainEditHeights.Plan. The trial heights are a change set over the
/// current heights, so that a plan does not copy the height map.
struct RaisePlan {
    changes: std::collections::HashMap<i64, i64>,
    modified: OrderedIndices,
    zone_indices: Vec<i64>,
    funds: i64,
}

struct TrialHeights<'a> {
    base: &'a [i64],
    changes: std::collections::HashMap<i64, i64>,
}

impl TrialHeights<'_> {
    fn get(&self, index: i64) -> i64 {
        self.changes.get(&index).copied().unwrap_or(self.base[index as usize])
    }

    fn set(&mut self, index: i64, value: i64) {
        self.changes.insert(index, value);
    }
}

fn in_bounds(point: Vec2i, map_edge: i64) -> bool {
    point.x >= 0 && point.x < map_edge && point.y >= 0 && point.y < map_edge
}

fn is_military(zones: &[u8], index: i64) -> bool {
    zones[index as usize] as i64 & zone::TYPE_MASK == zone::MILITARY
}

/// TerrainEditHeights.plan_raise. None is an invalid plan.
fn plan_raise(heights: &[i64], zones: &[u8], buildings: &[u8], start: Vec2i, funds: i64, map_edge: i64) -> Option<RaisePlan> {
    let mut visiting = HashSet::new();
    let mut visited = HashSet::new();
    let mut postorder = Vec::new();

    if !collect_raise_dependencies(heights, zones, start, &mut visiting, &mut visited, &mut postorder, map_edge) {
        return None;
    }

    let mut trial = TrialHeights {
        base: heights,
        changes: std::collections::HashMap::new(),
    };
    let mut modified = OrderedIndices::default();
    let mut zone_indices = Vec::new();
    let mut remaining = funds;
    let mut cost = 0;

    for point in postorder {
        if remaining < 25 {
            continue;
        }

        let tile_index = point.x * map_edge + point.y;
        trial.set(tile_index, trial.get(tile_index) + 1);
        remaining -= 25;
        cost += 25;
        zone_indices.push(tile_index);
        modified.add(tile_index);
        normalize_cardinal_slopes(&mut trial, buildings, point, &mut modified, map_edge);
    }

    if cost == 0 {
        return None;
    }

    Some(RaisePlan {
        changes: trial.changes,
        modified,
        zone_indices,
        funds: remaining,
    })
}

fn collect_raise_dependencies(
    heights: &[i64],
    zones: &[u8],
    point: Vec2i,
    visiting: &mut HashSet<i64>,
    visited: &mut HashSet<i64>,
    postorder: &mut Vec<Vec2i>,
    map_edge: i64,
) -> bool {
    let tile_index = point.x * map_edge + point.y;

    if visited.contains(&tile_index) || visiting.contains(&tile_index) {
        return true;
    }

    if is_military(zones, tile_index) || heights[tile_index as usize] > MAX_RAISE_SOURCE {
        return false;
    }

    for offset in NEIGHBOR_OFFSETS {
        let neighbor = point + offset;

        if in_bounds(neighbor, map_edge) && is_military(zones, neighbor.x * map_edge + neighbor.y) {
            return false;
        }
    }

    visiting.insert(tile_index);

    for offset in RAISE_DEPENDENCY_OFFSETS {
        let neighbor = point + offset;

        if !in_bounds(neighbor, map_edge) {
            continue;
        }

        let neighbor_index = neighbor.x * map_edge + neighbor.y;

        if heights[neighbor_index as usize] < heights[tile_index as usize]
            && !collect_raise_dependencies(heights, zones, neighbor, visiting, visited, postorder, map_edge)
        {
            return false;
        }
    }

    visiting.remove(&tile_index);
    visited.insert(tile_index);
    postorder.push(point);

    true
}

fn normalize_cardinal_slopes(heights: &mut TrialHeights, buildings: &[u8], point: Vec2i, modified: &mut OrderedIndices, map_edge: i64) {
    let tile_index = point.x * map_edge + point.y;

    for offset in CARDINAL_OFFSETS {
        let neighbor = point + offset;

        if !in_bounds(neighbor, map_edge) {
            continue;
        }

        let neighbor_index = neighbor.x * map_edge + neighbor.y;

        if buildings[neighbor_index as usize] as i64 >= tiles::SMALL_PARK {
            continue;
        }

        let height = heights.get(tile_index);
        let difference = height - heights.get(neighbor_index);

        if difference >= 2 {
            heights.set(neighbor_index, height - 1);
        } else if difference <= -2 {
            heights.set(neighbor_index, height + 1);
        } else {
            continue;
        }

        modified.add(neighbor_index);
        normalize_cardinal_slopes(heights, buildings, neighbor, modified, map_edge);
    }
}

/// TerrainEditSurface._expanded_indices.
fn expanded_indices(indices: &[i64], map_edge: i64) -> Vec<i64> {
    let mut result = OrderedIndices::default();

    for &tile_index in indices {
        let point = Vec2i::new(tile_index / map_edge, tile_index % map_edge);

        for x in (point.x - 1).max(0)..(point.x + 2).min(map_edge) {
            for y in (point.y - 1).max(0)..(point.y + 2).min(map_edge) {
                result.add(x * map_edge + y);
            }
        }
    }

    result.order
}

fn volcano_raise_is_valid(heights: &[i64], zones: &[u8], flags: &[u8], point: Vec2i, visited: &mut HashSet<i64>, map_edge: i64) -> bool {
    let tile_index = index(point, map_edge);

    if tile_index < 0 || visited.contains(&tile_index) {
        return true;
    }

    if is_military(zones, tile_index) {
        return false;
    }

    if flags[tile_index as usize] as i64 & flag_bits::WATER != 0 || heights[tile_index as usize] > MAX_RAISE_SOURCE {
        return false;
    }

    visited.insert(tile_index);

    for offset in NEIGHBOR_OFFSETS {
        let neighbor_index = index(point + offset, map_edge);

        if neighbor_index < 0 {
            continue;
        }

        if is_military(zones, neighbor_index) || flags[neighbor_index as usize] as i64 & flag_bits::WATER != 0 {
            return false;
        }
    }

    for offset in CARDINAL_OFFSETS {
        let neighbor = point + offset;
        let neighbor_index = index(neighbor, map_edge);

        if neighbor_index >= 0
            && heights[neighbor_index as usize] < heights[tile_index as usize]
            && !volcano_raise_is_valid(heights, zones, flags, neighbor, visited, map_edge)
        {
            return false;
        }
    }

    true
}

fn start_volcano(city: &mut City, center: Vec2i, random: Option<&mut SimRandom>) -> DisasterStartResult {
    let Some(random) = random else {
        return DisasterStartResult::failed(RANDOM_REQUIRED);
    };

    let Some(snapshot) = Snapshot::take(city, &START_CHUNKS) else {
        return DisasterStartResult::failed("volcano disaster input chunks are missing or invalid");
    };

    let edge = city.map_size;
    let maps = city.disaster_maps();
    let maps = maps.maps;
    let mut heights: Vec<i64> = (0..(edge * edge) as usize)
        .map(|tile| maps.altitude[tile * 2 + 1] as i64 & 0x1f)
        .collect();
    let mut remaining_budget = VOLCANO_BUDGET;
    let mut iterations = 0;
    let mut successful_raises = 0;
    let mut rejected_raises = 0;
    let mut near_toxic_writes = 0;
    let mut near_fire_writes = 0;
    let mut distant_toxic_writes = 0;
    let mut distant_fire_writes = 0;
    let mut changed_indices = OrderedIndices::default();
    let mut ids = vec![SOUND_VOLCANO];

    while remaining_budget > 0 {
        let near_point = loop {
            let dx = random.next_u15() % 5 - 2;
            let dy = random.next_u15() % 5 - 2;
            let near_point = center + Vec2i::new(dx, dy);

            if index(near_point, edge) >= 0 {
                break near_point;
            }
        };
        let near_index = index(near_point, edge);

        if random.next_u15() & 1 == 0 {
            overlay::write(maps.text_overlays, near_index, 0xfb);
            near_toxic_writes += 1;
        } else {
            overlay::write(maps.text_overlays, near_index, 0xff);
            near_fire_writes += 1;
        }

        let mut visited = HashSet::new();
        let plan = if volcano_raise_is_valid(&heights, maps.zones, maps.flags, near_point, &mut visited, edge) {
            plan_raise(&heights, maps.zones, maps.buildings, near_point, remaining_budget, edge)
        } else {
            None
        };

        match plan {
            Some(plan) => {
                for (&tile_index, &height) in &plan.changes {
                    heights[tile_index as usize] = height;
                }

                remaining_budget = plan.funds;

                for &tile_index in &plan.modified.order {
                    crate::sim::tools::terrain::set_land_altitude(maps.altitude, tile_index, heights[tile_index as usize]);
                }

                for &tile_index in &plan.zone_indices {
                    maps.zones[tile_index as usize] &= 0xf0;
                }

                let retile_indices = expanded_indices(&plan.modified.order, edge);
                let sea_level = read_u32_be(maps.misc, 0x0e40);
                retile_region(
                    maps.altitude,
                    maps.buildings,
                    maps.terrain,
                    maps.zones,
                    maps.flags,
                    maps.misc,
                    &retile_indices,
                    sea_level,
                    edge,
                );

                for tile_index in retile_indices {
                    changed_indices.add(tile_index);
                }

                successful_raises += 1;
            }
            None => {
                remaining_budget -= 1000;
                rejected_raises += 1;
            }
        }

        let dx = (random.next_u15() & 0x1f) - 16;
        let dy = (random.next_u15() & 0x1f) - 16;
        let distant_index = index(center + Vec2i::new(dx, dy), edge);

        if distant_index >= 0 {
            if maps.flags[distant_index as usize] & 0x04 != 0 {
                overlay::write(maps.text_overlays, distant_index, 0xfb);
                distant_toxic_writes += 1;
            } else {
                overlay::write(maps.text_overlays, distant_index, 0xff);
                distant_fire_writes += 1;
            }
        }

        iterations += 1;

        if random.next_u15() & 7 != 0 {
            ids.push(SOUND_EARTHQUAKE);
        }
    }

    let map_changed = snapshot.changed(city);
    snapshot.commit(city);
    let mut result = result(DISASTER_VOLCANO, center, true, true, 0);
    result.base.sound_events = start_sounds(&ids);
    result.counters.set("iterations", iterations);
    result.counters.set("successful_raises", successful_raises);
    result.counters.set("rejected_raises", rejected_raises);
    result.counters.set("temporary_budget_spent", VOLCANO_BUDGET - remaining_budget);
    result.counters.set("near_toxic_writes", near_toxic_writes);
    result.counters.set("near_fire_writes", near_fire_writes);
    result.counters.set("distant_toxic_writes", distant_toxic_writes);
    result.counters.set("distant_fire_writes", distant_fire_writes);
    result.terrain_indices = Ints32(changed_indices.order.iter().map(|value| *value as i32).collect());
    result.map_changed = map_changed;
    result
}

#[cfg(test)]
mod rule_tests {
    use super::*;
    use crate::sim::testing::{empty_city, sequence_lfsr, sequence_random};

    /// 0x0045ee10 gives a monster no goal in a scenario and draws no random
    /// numbers for it. Outside a scenario, half the monsters get a goal.
    #[test]
    fn scenario_monsters_have_no_goal() {
        for (scenario, goal, next) in [(true, 0, 0), (false, 2, 9)] {
            let mut city = empty_city(128);
            let mut random = sequence_random(&[5, 6, 0, 1, 9]);
            let result = start(&mut city, DISASTER_MONSTER, Vec2i::new(20, 20), Some(&mut random), None, scenario);
            assert!(result.started);
            assert_eq!(things::read(&city.xthg.data, result.record * things::RECORD_SIZE + 11), goal);
            assert_eq!(random.next_u15(), next, "the next random value");
            assert_eq!(result.base.view_center_requests, vec![Vec2i::new(12, 12)]);
        }
    }

    /// A pollution disaster moves the disaster point to its last seed, where
    /// a Maxis Man goes, and centers the view on the requested point.
    #[test]
    fn pollution_reports_its_last_seed() {
        let mut city = empty_city(128);
        let point = Vec2i::new(40, 40);
        let result = start(
            &mut city,
            DISASTER_POLLUTION,
            point,
            Some(&mut sequence_random(&[5, 6, 1, 2])),
            None,
            false,
        );
        assert!(result.started);
        // five attempts at a zero population; the last uses 5 and 6
        assert_eq!(result.point, point + Vec2i::new(1, 2));
        assert_eq!(result.base.view_center_requests, vec![point]);
    }

    /// A firestorm counts only new fires. Rubble on a reserved marker is no
    /// damage in the original, so a map of such markers starts no firestorm.
    #[test]
    fn firestorms_do_not_count_rubble() {
        let edge = 128i64;
        let mut city = empty_city(edge);

        for tile in 0..edge * edge {
            overlay::write(&mut city.xtxt.data, tile, 0xf1);
        }

        let result = start(
            &mut city,
            DISASTER_FIRESTORM,
            Vec2i::new(64, 64),
            Some(&mut sequence_random(&[0])),
            Some(&mut sequence_lfsr(&[0])),
            false,
        );
        assert!(!result.started);
        assert_eq!(
            result
                .counters
                .0
                .iter()
                .find(|(name, _)| name == "successful_cells")
                .map(|(_, value)| *value),
            Some(0)
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Extended cities select the same shore as the original square search.
    #[test]
    fn flood_shores_keep_the_original_search_order() {
        for edge in [128i64, 256, 384, 512, 640, 1024] {
            let mut legacy = vec![0u8; 128 * 128];
            let mut enlarged = vec![0u8; (edge * edge) as usize];
            let shift = Vec2i::new(edge - 128, edge - 128);

            for point in [
                Vec2i::new(4, 4),
                Vec2i::new(12, 4),
                Vec2i::new(4, 12),
                Vec2i::new(12, 12),
                Vec2i::new(80, 100),
            ] {
                legacy[(point.x * 128 + point.y) as usize] = 0x20;
                let moved = point + shift;
                enlarged[(moved.x * edge + moved.y) as usize] = 0x20;
            }

            for origin in [Vec2i::new(8, 8), Vec2i::ZERO, Vec2i::new(127, 127), Vec2i::new(90, 90)] {
                let expected = find_flood_shore(&legacy, origin, 128);
                assert_eq!(
                    find_flood_shore(&enlarged, origin + shift, edge),
                    expected + shift,
                    "edge {edge} origin {origin:?}"
                );
            }
        }
    }
}
