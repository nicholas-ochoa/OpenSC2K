//! One moving-thing tick, as MovingThingPhase.

use super::air::{self, HelicopterMaps};
use super::maxis_man;
use super::result::MovingThingResult;
use super::sailboat;
use super::ship::{self, ShipMaps};
use super::train::{self, TrainMaps};
use crate::sim::city::City;
use crate::sim::disasters::Snapshot;
use crate::sim::disasters::things::{self as disaster_things, TickCity};
use crate::sim::geom::Vec2i;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::random::{GameLcgRandom, SimLfsrRandom, SimRandom};
use crate::sim::things::{self, *};

/// The map chunks that disaster records write, after XTHG and XTXT.
const MAP_CHUNKS: [&str; 10] = ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTRF", "XLAB", "XMIC", "MISC"];

/// The tick options, as the MovingThingPhase.run arguments.
pub struct TickOptions {
    pub ship_home: Vec2i,
    pub allow_disaster_damage: bool,
    pub traffic_news_time_msec: i64,
    pub traffic_news_deadline_msec: i64,
    pub suppress_vehicle_crashes: bool,
}

fn inputs_are_valid(city: &City) -> bool {
    let tile_count = city.map_size * city.map_size;
    let expected = [
        ("XTHG", city.decoded_size("XTHG")),
        ("XTXT", city.decoded_size("XTXT")),
        ("ALTM", tile_count * 2),
        ("XBLD", tile_count),
        ("XTER", tile_count),
        ("XZON", tile_count),
        ("XUND", tile_count),
        ("XBIT", tile_count),
        ("XTRF", city.decoded_size("XTRF")),
        ("XLAB", city.decoded_size("XLAB")),
        ("XMIC", city.decoded_size("XMIC")),
        ("MISC", 4800),
    ];

    expected
        .iter()
        .all(|(id, size)| city.chunk(id).is_some_and(|chunk| chunk.data.len() as i64 == *size))
}

/// MovingThingPhase.run. Each record updates with its type's tick rule, in record
/// order. Ordinary vehicles write only XTHG and XTXT. The map chunks are copied
/// just before the first disaster record, and only then compared at the end.
pub fn run(
    city: &mut City,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    game: &mut GameLcgRandom,
    options: &TickOptions,
) -> MovingThingResult {
    if !inputs_are_valid(city) {
        return MovingThingResult::failed("moving-thing input chunks are missing or have the wrong size");
    }

    let map_edge = city.map_size;
    let city_center = Vec2i::new(city.misc_u32(misc_layout::CITY_CENTER_X), city.misc_u32(misc_layout::CITY_CENTER_Y));
    let no_disasters = city.no_disasters_enabled();
    let tick_city = TickCity {
        city_mode: city.city_mode(),
        exact_counts: city.is_extended(),
    };
    let original_things = city.xthg.data.clone();
    let original_text = city.xtxt.data.clone();
    let mut map_snapshot: Option<Snapshot> = None;
    let mut counters = MovingThingResult {
        scanned_records: things::count(&city.xthg.data) - 1,
        traffic_news_time_msec: options.traffic_news_time_msec,
        traffic_news_deadline_msec: options.traffic_news_deadline_msec,
        ..Default::default()
    };
    let record_count = things::count(&city.xthg.data);

    for record in 1..record_count {
        crate::sim::budget::checkpoint();
        let offset = record * RECORD_SIZE;
        let thing_type = things::read(&city.xthg.data, offset);

        if matches!(thing_type, TYPE_MONSTER | TYPE_EXPLOSION | TYPE_TORNADO) && map_snapshot.is_none() {
            map_snapshot = Snapshot::take(city, &MAP_CHUNKS);
        }

        let mut maps = city.disaster_maps();

        match thing_type {
            TYPE_AIRPLANE => {
                counters.active_airplanes += 1;
                air::update_airplane(
                    maps.maps.buildings,
                    maps.maps.zones,
                    maps.maps.text_overlays,
                    maps.things,
                    record,
                    random,
                    lfsr,
                    &mut counters,
                    map_edge,
                    no_disasters,
                    options.suppress_vehicle_crashes,
                );
            }
            TYPE_HELICOPTER => {
                counters.active_helicopters += 1;
                let helicopter_maps = HelicopterMaps {
                    buildings: maps.maps.buildings,
                    underground: maps.maps.underground,
                    traffic: maps.traffic,
                    map_edge,
                };
                air::update_helicopter(
                    &helicopter_maps,
                    maps.maps.text_overlays,
                    maps.things,
                    record,
                    city_center,
                    random,
                    &mut counters,
                    no_disasters,
                    options.suppress_vehicle_crashes,
                );
            }
            TYPE_SHIP => {
                counters.active_ships += 1;
                let home = things::ship_home(maps.things, record, options.ship_home);
                let ship_maps = ShipMaps {
                    buildings: maps.maps.buildings,
                    underground: maps.maps.underground,
                    flags: maps.maps.flags,
                    map_edge,
                };
                ship::update(
                    &ship_maps,
                    maps.maps.text_overlays,
                    maps.things,
                    record,
                    home,
                    random,
                    lfsr,
                    &mut counters,
                );
            }
            TYPE_MONSTER => {
                counters.active_monsters += 1;
                disaster_things::update_monster(&mut maps, record, city_center, random, lfsr, &mut counters);
            }
            TYPE_EXPLOSION => {
                counters.active_explosions += 1;
                disaster_things::update_explosion(
                    &mut maps,
                    tick_city,
                    record,
                    random,
                    lfsr,
                    options.allow_disaster_damage,
                    &mut counters,
                );
            }
            TYPE_SAILBOAT => {
                counters.active_sailboats += 1;
                sailboat::update(
                    maps.maps.buildings,
                    maps.maps.flags,
                    maps.maps.text_overlays,
                    maps.things,
                    record,
                    random,
                    lfsr,
                    &mut counters,
                    map_edge,
                );
            }
            TYPE_TRAIN_ENGINE | TYPE_SUBWAY_ENGINE => {
                counters.active_trains += 1;
                let train_maps = TrainMaps {
                    buildings: maps.maps.buildings,
                    underground: maps.maps.underground,
                    map_edge,
                    vehicle_caps: maps.maps.vehicle_caps,
                };
                train::update(
                    &train_maps,
                    maps.maps.text_overlays,
                    maps.things,
                    record,
                    random,
                    lfsr,
                    game,
                    &mut counters,
                );
            }
            TYPE_TORNADO => {
                counters.active_tornadoes += 1;
                disaster_things::update_tornado(&mut maps, record, random, &mut counters);
            }
            TYPE_MAXIS_MAN => {
                counters.active_maxis_men += 1;
                maxis_man::update(
                    maps.maps.altitude,
                    maps.maps.flags,
                    maps.maps.text_overlays,
                    maps.things,
                    record,
                    random,
                    &mut counters,
                    map_edge,
                    &maps.maps.vehicle_caps,
                );
            }
            _ => {}
        }
    }

    city.xthg.commit_if_changed(&original_things);
    city.xtxt.commit_if_changed(&original_text);

    if let Some(snapshot) = map_snapshot {
        snapshot.commit(city);
    }

    counters.base.ok = true;
    counters.sailboats_complete = true;
    counters.train_routes_complete = true;
    counters.helicopters_save_visible_complete = true;
    counters.ships_save_visible_complete = true;
    counters.airplanes_save_visible_complete = true;
    counters.explosion_records_complete = true;
    counters.tornadoes_save_visible_complete = true;
    counters.maxis_man_save_visible_complete = true;
    counters.monsters_save_visible_complete = true;
    counters.explosion_map_damage_complete = counters.deferred_facility_explosion_hits == 0;
    counters.base.complete = counters.explosion_map_damage_complete;
    counters
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::ids::building_tile_ids as tiles;
    use crate::sim::random::Randoms;
    use crate::sim::testing::empty_city;

    fn tick(city: &mut City) -> MovingThingResult {
        let options = TickOptions {
            ship_home: Vec2i::NONE,
            allow_disaster_damage: true,
            traffic_news_time_msec: 0,
            traffic_news_deadline_msec: 0,
            suppress_vehicle_crashes: false,
        };
        let mut randoms = Randoms::new(123, 456, 789);
        let Randoms { random, lfsr, game } = &mut randoms;
        run(city, random, lfsr, game, &options)
    }

    /// Ordinary vehicles write only XTHG and XTXT. A disaster record writes the map.
    #[test]
    fn only_disaster_records_write_the_map() {
        for edge in [128i64, 256] {
            for kind in [TYPE_SAILBOAT, TYPE_EXPLOSION] {
                let mut city = empty_city(edge);
                city.xbld.data[(10 * edge + 10) as usize] = tiles::RUBBLE_1 as u8;
                city.xbit.data[(10 * edge + 10) as usize] = 4;
                let direction = if kind == TYPE_EXPLOSION { 2 } else { 0 };

                for (field, value) in [(0, kind), (1, direction), (3, 10), (4, 10), (6, 8), (7, 8)] {
                    things::write(&mut city.xthg.data, RECORD_SIZE + field, value);
                }

                assert!(tick(&mut city).base.ok);
                assert!(city.xthg.written);

                if kind == TYPE_EXPLOSION {
                    assert_eq!(city.xbld.data[(10 * edge + 10) as usize], 0, "the explosion clears its tile");
                    assert!(city.xbld.written);
                } else {
                    assert!(
                        !city.xbld.written && !city.misc.written && !city.altm.written,
                        "a vehicle leaves the map chunks"
                    );
                }
            }
        }
    }
}
