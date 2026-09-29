//! Network decay and facility microsimulation during growth, as GrowthMaintenance.

use super::{Counters, replace_building};
use crate::sim::bytes::{read_i32_be, read_u32_be, write_u32_be};
use crate::sim::events::{NewsEvent, SoundEvent};
use crate::sim::geom::Vec2i;
use crate::sim::grid;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2budget_layout;
use crate::sim::ids::sc2microsim_layout;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::ids::underground_tile_ids as under;
use crate::sim::moving::spawner;
use crate::sim::network;
use crate::sim::overlay;
use crate::sim::random::{GameLcgRandom, SimLfsrRandom, SimRandom};
use crate::sim::things;
use crate::sim::tools::Maps;
use crate::sim::tools::demolish;
use crate::sim::tools::network::count_mask;

pub const NEWSPAPER_BRIDGE_COLLAPSE: i64 = 39;
pub const SOUND_EXPLODE: i64 = 504;

/// GrowthMaintenance._maintenance_fails. The random draw happens only when
/// the funding is not full.
pub fn maintenance_fails(misc: &[u8], budget_index: i64, random: &mut SimRandom, random_range: i64, additional: i64) -> bool {
    let funding = read_i32_be(
        misc,
        misc_layout::BUDGETS + budget_index * sc2budget_layout::RECORD_SIZE + 4,
    );

    funding != 100 && additional + random.next_u15() % random_range >= funding
}

fn is_bridge_budget_tile(tile: i64) -> bool {
    (tiles::SUSPENSION_BRIDGE_1..=tiles::POWER_BRIDGE).contains(&tile)
        || tile == tiles::HIGHWAY_BRIDGE
        || tile == tiles::REINFORCED_HIGHWAY_BRIDGE
}

fn is_highway_budget_tile(tile: i64) -> bool {
    (tiles::HIGHWAY_STRAIGHT_1..=tiles::HIGHWAY_POWER_CROSSING_2).contains(&tile)
        || (tiles::HIGHWAY_SLOPE_FIRST..=tiles::HIGHWAY_INTERSECTION).contains(&tile)
}

#[inline]
fn index_of(point: Vec2i, map_edge: i64) -> i64 {
    if point.x < 0 || point.x >= map_edge || point.y < 0 || point.y >= map_edge {
        return -1;
    }

    point.x * map_edge + point.y
}

/// Surface network decay for a tile without a zone.
pub fn process_surface(
    maps: &mut Maps,
    point: Vec2i,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    rotation: i64,
    counters: &mut Counters,
) {
    let edge = maps.map_edge;
    let index = index_of(point, edge);
    let tile = crate::sim::bytes::at(maps.buildings, index);

    if tile < tiles::FIRST_ROAD || lfsr.next_mask(0x7f) != 0 {
        return;
    }

    let i = index as usize;

    if network::surface_road(tile) {
        if maintenance_fails(maps.misc, 10, random, 100, 0) {
            let rubble = tiles::RUBBLE_FIRST + (random.next_u15() & 3);
            replace_building(maps.buildings, maps.zones, maps.misc, index, rubble);
            maps.flags[i] = (maps.flags[i] as i64 & !flag_bits::POWERABLE & 0xff) as u8;
            counters.decayed_roads += 1;
        }

        return;
    }

    if network::rail(tile) {
        if maintenance_fails(maps.misc, 13, random, 100, 0) {
            let rubble = tiles::RUBBLE_FIRST + (random.next_u15() & 3);
            replace_building(maps.buildings, maps.zones, maps.misc, index, rubble);
            maps.flags[i] = (maps.flags[i] as i64 & !flag_bits::POWERABLE & 0xff) as u8;
            counters.decayed_rails += 1;
        }

        return;
    }

    if is_bridge_budget_tile(tile) {
        let wind = read_u32_be(maps.misc, misc_layout::WEATHER_WIND) & 0xff;

        if maintenance_fails(maps.misc, 12, random, 50, wind) {
            let result = demolish::damage_structure(maps, point, random, rotation, true);

            if !result.changed {
                counters.deferred_bridge_collapses += 1;

                return;
            }

            counters.collapsed_bridges += 1;
            counters.bridge_effects.extend(result.effect_events);
            counters.view_center_requests.push(point);
            counters.news_items.push(NewsEvent::new(NEWSPAPER_BRIDGE_COLLAPSE, 0));
            counters.sound_events.push(SoundEvent::new(SOUND_EXPLODE));
        }

        return;
    }

    if is_highway_budget_tile(tile) {
        if point.x & 1 != 0 || point.y & 1 != 0 {
            return;
        }

        if !maintenance_fails(maps.misc, 11, random, 100, 0) {
            return;
        }

        for offset in [Vec2i::new(0, 0), Vec2i::new(1, 0), Vec2i::new(0, 1), Vec2i::new(1, 1)] {
            let highway_index = index_of(point + offset, edge);
            let h = crate::sim::bytes::slot(maps.flags.len(), highway_index);
            let mut replacement = tiles::EMPTY;

            if maps.flags[h] as i64 & flag_bits::WATER == 0 {
                replacement = tiles::RUBBLE_FIRST + (random.next_u15() & 3);
            }

            replace_building(maps.buildings, maps.zones, maps.misc, h as i64, replacement);
            counters.decayed_highway_tiles += 1;
        }
    }
}

/// Train, sailboat, and arcology work for a tile without a zone. `tile` is the
/// building before surface maintenance ran.
#[allow(clippy::too_many_arguments)]
pub fn process_microsim(
    maps: &mut Maps,
    things_data: &mut [u8],
    land_value: &[u8],
    crime: &[u8],
    pollution: &[u8],
    point: Vec2i,
    tile: i64,
    game_random: &mut GameLcgRandom,
    lfsr: &mut SimLfsrRandom,
    counters: &mut Counters,
) {
    let edge = maps.map_edge;
    let index = index_of(point, edge);
    let i = index as usize;

    if tile == tiles::RAIL_STATION {
        if maps.flags[i] as i64 & flag_bits::POWERED == 0 || lfsr.next_mask(3) != 0 {
            return;
        }

        let train_limit = super::special::tile_count(maps.misc, tiles::RAIL_STATION, false, edge) / 4;

        if spawner::count_type(things_data, things::TYPE_TRAIN_ENGINE) < train_limit
            && spawner::spawn_train(maps.buildings, things_data, maps.text_overlays, point, game_random, lfsr, edge)
        {
            counters.spawned_trains += 1;
        }

        return;
    }

    if tile == tiles::MARINA {
        if maps.flags[i] as i64 & flag_bits::POWERED == 0 || lfsr.next_mask(3) != 0 {
            return;
        }

        let sailboat_limit = super::special::tile_count(maps.misc, tiles::MARINA, false, edge) / 9;

        if spawner::count_type(things_data, things::TYPE_SAILBOAT) < sailboat_limit {
            counters.spawned_sailboats +=
                spawner::spawn_sailboats(maps.buildings, maps.flags, things_data, maps.text_overlays, point, lfsr, edge);
        }

        return;
    }

    if !(tiles::PLYMOUTH_ARCOLOGY..=tiles::LAUNCH_ARCOLOGY).contains(&tile)
        || maps.zones[i] as i64 & zone::CORNERS_MASK != 0x80
    {
        return;
    }

    let label = overlay::read(maps.text_overlays, index);

    if !overlay::is_facility(label) {
        return;
    }

    let record_offset = overlay::facility_record(label) * sc2microsim_layout::RECORD_SIZE;
    let record_tile = crate::sim::bytes::at(maps.microsims, record_offset);

    if !(tiles::PLYMOUTH_ARCOLOGY..=tiles::LAUNCH_ARCOLOGY).contains(&record_tile) {
        return;
    }

    let coarse = grid::index(land_value, edge, point.x, point.y);
    let mut value = (crate::sim::bytes::at(land_value, coarse) >> 5) - (crate::sim::bytes::at(crime, coarse) >> 5)
        - (crate::sim::bytes::at(pollution, coarse) >> 5)
        + 12;

    if maps.flags[i] as i64 & flag_bits::POWERED == 0 {
        value = (value as f64 / 2.0) as i64;
    }

    if maps.flags[i] as i64 & flag_bits::WATERED == 0 {
        value = (value as f64 / 2.0) as i64;
    }

    crate::sim::bytes::put(maps.microsims, record_offset + 1, value.clamp(0, 12));
    counters.arcologies_updated += 1;
}

fn replace_underground(underground: &mut [u8], zones: &[u8], misc: &mut [u8], index: i64, new_tile: i64) {
    let old_tile = underground[index as usize] as i64;

    if old_tile == new_tile {
        return;
    }

    if zones[index as usize] as i64 & zone::TYPE_MASK != 7 {
        let mask = count_mask(underground.len());
        let mut count = read_u32_be(misc, misc_layout::SUBWAY_COUNT);

        if network::subway(old_tile) {
            count = (count - 1) & mask;
        }

        if network::subway(new_tile) {
            count = (count + 1) & mask;
        }

        write_u32_be(misc, misc_layout::SUBWAY_COUNT, count);
    }

    underground[index as usize] = new_tile as u8;
}

/// Subway decay. It runs after the zone work of every scanned tile.
pub fn process_subway(
    maps: &mut Maps,
    things_data: &mut [u8],
    point: Vec2i,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    counters: &mut Counters,
) {
    if lfsr.next_mask(0x7f) != 0 {
        return;
    }

    let index = index_of(point, maps.map_edge);
    let i = index as usize;
    let old_tile = maps.underground[i] as i64;

    if !network::subway(old_tile) {
        return;
    }

    if !maintenance_fails(maps.misc, 14, random, 100, 0) {
        return;
    }

    let replacement = if old_tile == under::PIPE_TB_SUBWAY_LR {
        under::PIPE_TB
    } else if old_tile == under::PIPE_LR_SUBWAY_TB {
        under::PIPE_LR
    } else if old_tile == under::SUBWAY_ENTRANCE {
        if maps.buildings[i] as i64 != tiles::SUBWAY_STATION {
            counters.deferred_station_removals += 1;

            return;
        }

        let mut surface = tiles::EMPTY;

        if maps.terrain[i] as i64 == terrain_ids::FLAT {
            surface = tiles::RUBBLE_FIRST + (random.next_u15() & 3);
        }

        replace_building(maps.buildings, maps.zones, maps.misc, index, surface);
        maps.zones[i] = (maps.zones[i] as i64 & zone::TYPE_MASK) as u8;
        maps.flags[i] = (maps.flags[i] as i64 & !(flag_bits::FLIPPED | flag_bits::POWER_MASK) & 0xff) as u8;
        let linked = overlay::read(maps.text_overlays, index);
        demolish::release_overlay(maps.text_overlays, maps.labels, maps.microsims, index);

        // Original demolition detaches the thing but keeps its record and XTXT.
        if overlay::is_thing(linked) {
            let record = overlay::thing_record(linked);
            things::write(things_data, record * things::RECORD_SIZE + things::FIELD_LABEL, 0);
        }

        replace_underground(maps.underground, maps.zones, maps.misc, index, under::EMPTY);
        counters.removed_subway_stations += 1;
        counters.decayed_subway_tiles += 1;

        return;
    } else {
        under::EMPTY
    };

    replace_underground(maps.underground, maps.zones, maps.misc, index, replacement);
    counters.decayed_subway_tiles += 1;
}
