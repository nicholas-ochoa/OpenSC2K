//! Disaster damage to one tile, as DisasterDamage.

use super::{DisasterMaps, RuntimeEvents, altitude_word, index};
use crate::sim::geom::Vec2i;
use crate::sim::grid;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2label_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::overlay;
use crate::sim::random::{SimLfsrRandom, SimRandom};
use crate::sim::tools::demolish::{self, PointResult};
use crate::sim::tools::network::replace_building;

pub const SOUND_DAMAGE: i64 = 0x1f8;

/// Story weight of each damaged building class, from executable table
/// 0x004e8848. Classes 0 to 9 are zone types. Class 10 and up are tiles from 0xc6.
const DAMAGE_CLASS_WEIGHTS: [i64; 67] = [
    0, 1, 1, 1, 1, 1, 1, 1, 4, 8, 5, 5, 5, 5, 5, 5, 5, 5, 5, 3, 4, 4, 4, 2, 2, 3, 2, 4, 3, 2, 3, 2, 8, 8, 2, 4, 8, 1, 4, 1, 1, 8, 1, 1, 3,
    8, 2, 2, 2, 1, 1, 4, 1, 1, 2, 2, 2, 1, 3, 2, 5, 3, 6, 6, 6, 6, 6,
];

/// DisasterDamage.append_damage_events.
pub fn append_damage_events(events: Option<&mut RuntimeEvents>, damage: &PointResult) {
    let Some(events) = events else {
        return;
    };

    if damage.effect_events.is_empty() {
        return;
    }

    events.next_effect_frame = demolish::append_effect_sequence(&mut events.effect_events, &damage.effect_events, events.next_effect_frame);
    events.sound_events.push(SOUND_DAMAGE);
}

/// A sign label clear. An extended sign ID past the label records changes nothing,
/// as a failed GDScript packed-array store.
fn clear_sign_label(labels: &mut [u8], overlay_id: i64) {
    let offset = overlay_id * sc2label_layout::RECORD_SIZE;

    if offset >= 0 && (offset as usize) < labels.len() {
        labels[offset as usize] = 0;
    }
}

/// DisasterDamage.apply. Returns 0 for no change, 1 for a new fire, 2 for
/// rubble, 3 for a burned facility, and 4 for a fire on a reserved marker.
#[allow(clippy::too_many_arguments)]
pub fn apply(
    maps: &mut DisasterMaps,
    point: Vec2i,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    allow_small_tile: bool,
    events: Option<&mut RuntimeEvents>,
) -> i64 {
    let edge = maps.maps.map_edge;
    let tile_index = index(point, edge);

    if tile_index < 0 || maps.maps.flags[tile_index as usize] as i64 & flag_bits::WATER != 0 {
        return 0;
    }

    if (maps.maps.buildings[tile_index as usize] as i64) < tiles::TREES_1 && !allow_small_tile {
        return 0;
    }

    let overlay_id = overlay::read(maps.maps.text_overlays, tile_index);
    let mut result_code = 1;

    if overlay_id > 0 {
        if overlay::is_sign(overlay_id) {
            clear_sign_label(maps.maps.labels, overlay_id);
        } else if overlay::is_facility(overlay_id) {
            let damage = burn_structure(maps, point, random, lfsr, true, false, true);
            append_damage_events(events, &damage);
            result_code = 3;
        } else if overlay::is_thing(overlay_id) {
            return 0;
        } else if overlay_id < 250 {
            let rubble = lfsr.next_mod(4) + tiles::RUBBLE_FIRST;
            replace_building(maps.maps.buildings, maps.maps.zones, maps.maps.misc, tile_index, rubble);

            return 2;
        } else if overlay_id != 250 {
            return 0;
        } else {
            result_code = 4;
        }
    }

    overlay::write(maps.maps.text_overlays, tile_index, 0xff);
    let traffic_index = grid::index(maps.traffic, edge, point.x, point.y);
    crate::sim::bytes::put(maps.traffic, traffic_index, 0);

    result_code
}

/// DisasterDamage.apply_flood. Returns 0 for no change, 1 for new water, and 2 for rubble.
#[allow(clippy::too_many_arguments)]
pub fn apply_flood(
    maps: &mut DisasterMaps,
    point: Vec2i,
    maximum_altitude: i64,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    events: Option<&mut RuntimeEvents>,
) -> i64 {
    let edge = maps.maps.map_edge;
    let tile_index = index(point, edge);

    if tile_index < 0 || altitude_word(maps.maps.altitude, tile_index) & 0x1f > maximum_altitude {
        return 0;
    }

    let terrain = maps.maps.terrain[tile_index as usize] as i64;

    if (terrain_ids::DEEP_WATER_FIRST..=terrain_ids::DEEP_WATER_LAST).contains(&terrain) {
        return 0;
    }

    let overlay_id = overlay::read(maps.maps.text_overlays, tile_index);

    if overlay_id > 0 {
        if overlay::is_sign(overlay_id) {
            clear_sign_label(maps.maps.labels, overlay_id);
        } else if overlay::is_facility(overlay_id) {
            let damage = burn_structure(maps, point, random, lfsr, false, false, true);
            append_damage_events(events, &damage);
        } else if overlay::is_thing(overlay_id) {
            return 0;
        } else if overlay_id < 250 {
            let rubble = lfsr.next_mod(4) + tiles::RUBBLE_FIRST;
            replace_building(maps.maps.buildings, maps.maps.zones, maps.maps.misc, tile_index, rubble);

            return 2;
        } else {
            return 0;
        }
    }

    overlay::write(maps.maps.text_overlays, tile_index, 0xfc);
    let traffic_index = grid::index(maps.traffic, edge, point.x, point.y);
    crate::sim::bytes::put(maps.traffic, traffic_index, 0);

    1
}

/// DisasterDamage.burn_structure.
#[allow(clippy::too_many_arguments)]
pub fn burn_structure(
    maps: &mut DisasterMaps,
    point: Vec2i,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    mark_fire: bool,
    clear_current: bool,
    emit_effects: bool,
) -> PointResult {
    let edge = maps.maps.map_edge;
    let point_index = index(point, edge);
    record_damage_class(maps.damage_class, maps.maps.buildings, maps.maps.zones, point_index);
    let rotation = maps.rotation;
    let result = demolish::demolish_point(&mut maps.maps, point, random, rotation, true, true, emit_effects, false);

    if mark_fire {
        for &changed in &result.indices {
            if maps.maps.flags[changed as usize] as i64 & flag_bits::WATER == 0 {
                overlay::write(maps.maps.text_overlays, changed, 0xff);
            }
        }
    }

    if mark_fire && clear_current && point_index >= 0 && overlay::read(maps.maps.text_overlays, point_index) == 0xff {
        overlay::write(maps.maps.text_overlays, point_index, 0);
        let tile = maps.maps.buildings[point_index as usize] as i64;

        if !(tiles::TUNNEL_ENTRANCE_1..=tiles::TUNNEL_ENTRANCE_4).contains(&tile) && tile < tiles::HIGHWAY_SLOPE_1 {
            let rubble = lfsr.next_mod(4) + tiles::RUBBLE_FIRST;
            replace_building(maps.maps.buildings, maps.maps.zones, maps.maps.misc, point_index, rubble);
        }
    }

    result
}

/// DisasterDamage.record_damage_class. Keep the most important building class
/// that the disaster damaged. The original skips tunnel entrances and keeps the
/// earlier class on a tie.
pub fn record_damage_class(damage_class: &mut i64, buildings: &[u8], zones: &[u8], tile_index: i64) {
    if tile_index < 0 {
        return;
    }

    let tile = buildings[tile_index as usize] as i64;

    if (tiles::TUNNEL_ENTRANCE_1..=tiles::TUNNEL_ENTRANCE_4).contains(&tile) {
        return;
    }

    let mut class = zones[tile_index as usize] as i64 & zone::TYPE_MASK;

    if tile >= tiles::HYDRO_POWER_1 {
        class = if tile == tiles::HYDRO_POWER_1 { 10 } else { tile - 0xbd };
    }

    if class >= DAMAGE_CLASS_WEIGHTS.len() as i64 {
        return;
    }

    let current = *damage_class;

    if current < 0 || DAMAGE_CLASS_WEIGHTS[current as usize] < DAMAGE_CLASS_WEIGHTS[class as usize] {
        *damage_class = class;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::testing::{empty_full_resolution_city, sequence_lfsr, sequence_random};

    /// A fire clears only the traffic of its own tile on per-tile maps.
    #[test]
    fn fire_clears_only_the_selected_traffic_tile() {
        for edge in [128i64, 512] {
            let mut city = empty_full_resolution_city(edge);
            let point = Vec2i::new(edge - 32, edge - 32);
            let tile = (point.x * edge + point.y) as usize;
            city.xbld.data[tile] = tiles::LOWER_CLASS_HOMES_1X1_1 as u8;
            city.xbld.data[tile + 1] = tiles::LOWER_CLASS_HOMES_1X1_1 as u8;
            city.xtrf.data[tile] = 200;
            city.xtrf.data[tile + 1] = 40;
            let mut maps = city.disaster_maps();
            let result = apply(&mut maps, point, &mut sequence_random(&[0]), &mut sequence_lfsr(&[0]), false, None);
            assert_ne!(result, 0);
            assert_eq!(city.xtrf.data[tile], 0);
            assert_eq!(city.xtrf.data[tile + 1], 40);
        }
    }
}

#[cfg(test)]
mod class_tests {
    use super::*;

    /// The original keeps the damaged class with the largest story weight and
    /// skips tunnel entrances.
    #[test]
    fn damage_keeps_the_most_important_building_class() {
        let buildings = [
            tiles::LOWER_CLASS_HOMES_1X1_1 as u8,
            0xd2,
            tiles::TUNNEL_ENTRANCE_1 as u8,
            0xc6,
            0xe4,
        ];
        let zones = [1u8, 9, 8, 0, 0];
        let mut class = -1;
        let mut classes = Vec::new();

        for index in 0..buildings.len() as i64 {
            record_damage_class(&mut class, &buildings, &zones, index);
            classes.push(class);
        }

        assert_eq!(classes, vec![1, 21, 21, 10, 10]);
    }
}
