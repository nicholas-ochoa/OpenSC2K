//! Explosion, monster, and tornado ticks, as DisasterThingTick and DisasterThingActions.

use super::DisasterMaps;
use super::damage;
use crate::sim::bytes::{self, write_u32_be};
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2label_layout;
use crate::sim::ids::sc2microsim_layout;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::moving::motion::{self, DIRECTIONS, direction_quadrant, index};
use crate::sim::moving::result::{ConnectionChange, DisasterRequest, MovingThingResult, queue_thing_sound, record_type};
use crate::sim::overlay;
use crate::sim::random::{SimLfsrRandom, SimRandom};
use crate::sim::things::{self, RECORD_SIZE, TYPE_AIRPLANE, TYPE_HELICOPTER};
use crate::sim::tools::demolish;
use crate::sim::tools::network::replace_building;

const SOUND_EXPLOSION: i64 = 0x1f8;
const SOUND_MONSTER_DAMAGE: i64 = 0x202;
const MONSTER_SPEED: i64 = 8;
const TORNADO_SPEED: i64 = 8;
const TYPE_MILITARY_UNIT: i64 = 14;

/// City values that the tick reads from the stored MISC chunk. The tick edits a
/// copy, so these stay at their values from the start of the tick.
#[derive(Clone, Copy)]
pub struct TickCity {
    pub city_mode: i64,
    pub exact_counts: bool,
}

/// DisasterThingActions._random_direction_step.
fn random_direction_step(direction: i64, divisor: i64, random: &mut SimRandom) -> i64 {
    crate::sim::moving::air::random_direction_step(direction, divisor, random)
}

/// DisasterThingActions._record_connection_count_change.
fn record_connection_count_change(counters: &mut MovingThingResult, tile: i64, point: Vec2i) {
    let commerce = (tiles::ROAD_STRAIGHT_1..=tiles::ROAD_CROSSROADS).contains(&tile)
        || (tiles::TUNNEL_ENTRANCE_1..=tiles::ROAD_RAIL_CROSSING_2).contains(&tile)
        || tile == tiles::HIGHWAY_ROAD_CROSSING_1
        || tile == tiles::HIGHWAY_ROAD_CROSSING_2
        || (tiles::HIGHWAY_ONRAMP_1..=tiles::HIGHWAY_ONRAMP_4).contains(&tile);
    let kind = if commerce { "commerce" } else { "industry" };
    counters.connection_count_changes.push(ConnectionChange {
        kind: kind.to_string(),
        delta: -1,
        point,
    });
}

/// DisasterThingTick.update_explosion.
#[allow(clippy::too_many_arguments)]
pub fn update_explosion(
    maps: &mut DisasterMaps,
    tick_city: TickCity,
    record: i64,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    allow_disaster_damage: bool,
    counters: &mut MovingThingResult,
) {
    let edge = maps.maps.map_edge;
    let offset = record * RECORD_SIZE;
    let frame = things::read(maps.things, offset + 1);
    let disaster_type = things::read(maps.things, offset + 2);

    if frame == 0 {
        queue_thing_sound(counters, SOUND_EXPLOSION, maps.things, record);
    }

    if frame < 2 {
        things::write(maps.things, offset + 1, (frame + 1) & 0xff);

        return;
    }

    let center = Vec2i::new(things::read(maps.things, offset + 3), things::read(maps.things, offset + 4));
    let center_index = index(center, edge);
    motion::remove(maps.maps.text_overlays, maps.things, record, edge);
    counters.removed_explosions += 1;

    if center_index < 0 {
        counters.malformed_records += 1;

        return;
    }

    // The original clears the tile without a count change. Extended cities keep exact counts.
    if tick_city.exact_counts {
        crate::sim::growth::replace_building(maps.maps.buildings, maps.maps.zones, maps.maps.misc, center_index, tiles::EMPTY);
    } else {
        maps.maps.buildings[center_index as usize] = tiles::EMPTY as u8;
    }

    if things::read(maps.things, offset + 11) == 0 || !allow_disaster_damage {
        return;
    }

    let mut caused_damage = false;

    for _ in 0..4 {
        let dx = lfsr.next_mod(5) - 2;
        let dy = lfsr.next_mod(5) - 2;
        let damaged = center + Vec2i::new(dx, dy);
        let damage_result = damage::apply(maps, damaged, random, lfsr, false, None);

        match damage_result {
            1 => {
                caused_damage = true;
                counters.spread_explosion_fires += 1;
            }
            4 => {
                caused_damage = true;
                counters.spread_explosion_fires += 1;
                let tile = bytes::at(maps.maps.buildings, index(damaged, edge));
                record_connection_count_change(counters, tile, damaged);
            }
            2 => {
                caused_damage = true;
                counters.rubble_explosion_hits += 1;
            }
            3 => {
                caused_damage = true;
                counters.damaged_facilities += 1;
                counters.spread_explosion_fires += 1;
            }
            _ => {}
        }
    }

    if caused_damage && tick_city.city_mode != 2 {
        let requested_type = if disaster_type != 0 { disaster_type } else { 1 };
        write_u32_be(maps.maps.misc, misc_layout::DISASTER_TYPE, requested_type);
        counters.disaster_start_requests.push(DisasterRequest {
            type_: requested_type,
            point: center,
        });
    }
}

/// DisasterThingTick.update_monster.
#[allow(clippy::too_many_arguments)]
pub fn update_monster(
    maps: &mut DisasterMaps,
    record: i64,
    city_center: Vec2i,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    counters: &mut MovingThingResult,
) {
    let edge = maps.maps.map_edge;
    let offset = record * RECORD_SIZE;
    let current = Vec2i::new(things::read(maps.things, offset + 3), things::read(maps.things, offset + 4));
    let current_index = index(current, edge);
    let direction = things::read(maps.things, offset + 1);

    if current_index < 0 || !(0..8).contains(&direction) {
        motion::remove(maps.maps.text_overlays, maps.things, record, edge);
        counters.removed_monsters += 1;
        counters.malformed_records += 1;

        return;
    }

    let count = things::count(maps.things);

    if counters.active_airplanes > 0 {
        for checked in 1..count {
            let checked_offset = checked * RECORD_SIZE;

            if things::read(maps.things, checked_offset) == TYPE_AIRPLANE {
                things::write(maps.things, checked_offset + 2, 7);
                counters.monster_forced_airplanes += 1;
            }
        }
    }

    if counters.active_helicopters > 0 {
        for checked in 1..count {
            let checked_offset = checked * RECORD_SIZE;

            if things::read(maps.things, checked_offset) == TYPE_HELICOPTER {
                things::write(maps.things, checked_offset + 2, 5);
                counters.monster_forced_helicopters += 1;
            }
        }
    }

    let state = things::read(maps.things, offset + 2);
    let mut move_direction = direction;

    match state {
        0 => {
            if things::read(maps.things, offset + 5) < 9 {
                things::write(maps.things, offset + 2, 1);
            } else {
                let height = things::read(maps.things, offset + 5) - 1;
                things::write(maps.things, offset + 5, height);
            }

            things::write(maps.things, offset + 8, 0);
            things::write(maps.things, offset + 9, 0);
            move_direction = direction_quadrant(current, city_center);
        }
        1 => {
            if random.next_u15() % 25 == 0 {
                things::write(maps.things, offset + 2, 2);
            }

            let dx = random.next_u15() & 0x7f;
            things::write(maps.things, offset + 8, dx);
            let dy = random.next_u15() & 0x7f;
            things::write(maps.things, offset + 9, dy);
            move_direction = random_direction_step(direction, 5, random);
            monster_damage(maps, offset, current, random, lfsr, counters);
        }
        2 => {
            if things::read(maps.things, offset + 5) < 15 {
                let height = things::read(maps.things, offset + 5) + 1;
                things::write(maps.things, offset + 5, height);
            } else {
                let next_state = if random.next_u15() % 3 == 0 { 3 } else { 0 };
                things::write(maps.things, offset + 2, next_state);
            }

            let animation = (random.next_u15() & 7) * 9;
            things::write(maps.things, offset + 8, animation);
            things::write(maps.things, offset + 9, animation);
            move_direction = random_direction_step(direction, 5, random);
        }
        3 => {
            things::write(maps.things, offset + 8, 0);
            things::write(maps.things, offset + 9, 0);

            if random.next_u15() & 1 != 0 {
                things::write(maps.things, offset + 8, 36);
                things::write(maps.things, offset + 9, 36);
            }

            if lfsr.next_mod(100) == 0 {
                motion::remove(maps.maps.text_overlays, maps.things, record, edge);
                counters.removed_monsters += 1;

                return;
            }
        }
        _ => {
            motion::remove(maps.maps.text_overlays, maps.things, record, edge);
            counters.removed_monsters += 1;
            counters.malformed_records += 1;

            return;
        }
    }

    if things::read(maps.things, offset + 2) != 3 {
        let military_index = index(current + DIRECTIONS[move_direction as usize], edge);

        if military_index >= 0 {
            let marker = overlay::read(maps.maps.text_overlays, military_index);

            if overlay::is_thing(marker) && record_type(maps.things, overlay::thing_record(marker)) == TYPE_MILITARY_UNIT {
                things::write(maps.things, offset + 2, 3);
                counters.monster_military_collisions += 1;

                return;
            }
        }
    }

    things::write(maps.things, offset + 1, move_direction);

    if motion::advance(MONSTER_SPEED, maps.maps.text_overlays, maps.things, record, move_direction, edge) < 0 {
        counters.removed_monsters += 1;

        return;
    }

    counters.moved_monsters += 1;

    if things::read(maps.things, offset + 8) & 0x80 != 0 {
        queue_thing_sound(counters, SOUND_MONSTER_DAMAGE, maps.things, record);
    }
}

/// DisasterThingActions._monster_damage.
fn monster_damage(
    maps: &mut DisasterMaps,
    offset: i64,
    current: Vec2i,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    counters: &mut MovingThingResult,
) {
    let edge = maps.maps.map_edge;
    let point = current + Vec2i::new(1, 1);
    let tile_index = index(point, edge);

    if tile_index < 0 {
        return;
    }

    let i = tile_index as usize;
    let building = maps.maps.buildings[i] as i64;
    let goal = things::read(maps.things, offset + 11);

    if goal == 0 {
        if building <= tiles::RADIOACTIVE_WASTE {
            return;
        }

        let damage_result = damage::apply(maps, point, random, lfsr, false, None);

        match damage_result {
            1 => counters.spread_explosion_fires += 1,
            3 => {
                counters.damaged_facilities += 1;
                counters.spread_explosion_fires += 1;
            }
            4 => {
                counters.spread_explosion_fires += 1;
                let tile = maps.maps.buildings[i] as i64;
                record_connection_count_change(counters, tile, point);
            }
            _ => {}
        }

        if damage_result != 0 && damage_result != 2 {
            let flags = things::read(maps.things, offset + 8) | 0x80;
            things::write(maps.things, offset + 8, flags);
            counters.monster_damage_hits += 1;
        }

        return;
    }

    if maps.maps.flags[i] as i64 & flag_bits::WATER != 0 || building <= tiles::SMALL_PARK || building == tiles::WIND_POWER {
        return;
    }

    let rotation = maps.rotation;
    let demolition = demolish::demolish_point(&mut maps.maps, point, random, rotation, true, true, false, false);

    if !demolition.changed {
        return;
    }

    match goal {
        1 => {
            let rubble = (random.next_u15() & 3) + 9;
            replace_building(maps.maps.buildings, maps.maps.zones, maps.maps.misc, tile_index, rubble);
        }
        2 => {
            crate::sim::tools::terrain::place_water(&mut maps.maps, point);
        }
        3 => {
            let overlay_id = provision_wind_power(maps.maps.microsims, maps.maps.labels);
            replace_building(maps.maps.buildings, maps.maps.zones, maps.maps.misc, tile_index, tiles::WIND_POWER);
            maps.maps.zones[i] = zone::CORNERS_MASK as u8;
            maps.maps.flags[i] = ((maps.maps.flags[i] as i64 & !flag_bits::STRUCTURE_MASK & 0xff) | flag_bits::STRUCTURE_MASK) as u8;

            if overlay_id != 0 {
                overlay::write(maps.maps.text_overlays, tile_index, overlay_id);
            }
        }
        _ => {}
    }

    let flags = things::read(maps.things, offset + 8) | 0x80;
    things::write(maps.things, offset + 8, flags);
    counters.monster_damage_hits += 1;
}

/// BuildingFacilities.provision_microsim for a wind power plant. Wind power uses
/// the fixed record 4 and adds one plant and four power units to it.
fn provision_wind_power(microsims: &mut [u8], labels: &mut [u8]) -> i64 {
    const WIND_RECORD: i64 = 4;
    let offset = WIND_RECORD * sc2microsim_layout::RECORD_SIZE;
    microsims[offset as usize] = tiles::WIND_POWER as u8;
    let plants = bytes::read_u16_be(microsims, offset + 2);
    bytes::write_u16_be(microsims, offset + 2, plants + 1);
    let power = bytes::read_u16_be(microsims, offset + 4);
    bytes::write_u16_be(microsims, offset + 4, power + 4);
    let label_id = overlay::facility_id(WIND_RECORD);
    let label_offset = (label_id * sc2label_layout::RECORD_SIZE) as usize;

    if labels[label_offset] == 0 {
        let name = b"Wind Power";

        for byte in &mut labels[label_offset..label_offset + sc2label_layout::RECORD_SIZE as usize] {
            *byte = 0;
        }

        labels[label_offset] = name.len() as u8;
        labels[label_offset + 1..label_offset + 1 + name.len()].copy_from_slice(name);
    }

    label_id
}

/// DisasterThingTick.update_tornado.
pub fn update_tornado(maps: &mut DisasterMaps, record: i64, random: &mut SimRandom, counters: &mut MovingThingResult) {
    let edge = maps.maps.map_edge;
    let offset = record * RECORD_SIZE;
    let current = Vec2i::new(things::read(maps.things, offset + 3), things::read(maps.things, offset + 4));
    let tile_index = index(current, edge);
    let direction = things::read(maps.things, offset + 1);

    if tile_index < 0 || !(0..8).contains(&direction) {
        motion::remove(maps.maps.text_overlays, maps.things, record, edge);
        counters.removed_tornadoes += 1;
        counters.malformed_records += 1;

        return;
    }

    let building = maps.maps.buildings[tile_index as usize] as i64;

    if building > tiles::RADIOACTIVE_WASTE {
        let rotation = maps.rotation;
        let demolition = demolish::demolish_point(&mut maps.maps, current, random, rotation, true, true, false, false);

        if demolition.changed {
            counters.tornado_demolitions += 1;
        }
    }

    let first = random.next_u15() % 3;
    let second = random.next_u15() % 3;
    let first_direction = (direction + first - second) & 7;

    if motion::advance(TORNADO_SPEED, maps.maps.text_overlays, maps.things, record, first_direction, edge) < 0 {
        counters.removed_tornadoes += 1;

        return;
    }

    counters.moved_tornadoes += 1;

    if random.next_u15() & 0xff == 0 {
        motion::remove(maps.maps.text_overlays, maps.things, record, edge);
        counters.removed_tornadoes += 1;

        return;
    }

    if building >= tiles::SMALL_PARK {
        return;
    }

    let first = random.next_u15() & 1;
    let second = random.next_u15() & 1;
    let second_direction = (direction + first - second) & 7;

    if motion::advance(TORNADO_SPEED, maps.maps.text_overlays, maps.things, record, second_direction, edge) < 0 {
        counters.removed_tornadoes += 1;

        return;
    }

    counters.moved_tornadoes += 1;

    if random.next_u15() & 0xff == 0 {
        motion::remove(maps.maps.text_overlays, maps.things, record, edge);
        counters.removed_tornadoes += 1;
    }
}
