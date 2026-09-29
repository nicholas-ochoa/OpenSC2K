//! New moving things, as MovingThingSpawner.

use super::motion;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2tile_flags as flags;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::overlay;
use crate::sim::random::{GameLcgRandom, SimLfsrRandom, SimRandom};
use crate::sim::things::{self, *};

pub const FIRST_RECORD: i64 = 1;
pub const LAST_RECORD: i64 = 39;
pub const TEXT_LABEL_BASE: i64 = 201;
pub const CARDINAL_DIRECTIONS: [Vec2i; 4] = [Vec2i::new(0, -1), Vec2i::new(1, 0), Vec2i::new(0, 1), Vec2i::new(-1, 0)];
pub const TRAIN_SEARCH_OFFSETS: [Vec2i; 4] = [Vec2i::new(0, -2), Vec2i::new(2, 0), Vec2i::new(0, 2), Vec2i::new(-2, 0)];
pub const TRAIN_DIRECTION_ORDERS: [[i64; 4]; 2] = [[0, 3, 1, 2], [0, 1, 3, 2]];

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Spawned {
    pub spawned: bool,
    pub record: i64,
    pub point: Vec2i,
    pub target: Vec2i,
    pub goal: i64,
}

pub fn count_type(data: &[u8], thing_type: i64) -> i64 {
    let mut count = 0;

    for record in FIRST_RECORD..things::count(data) {
        if things::read(data, record * RECORD_SIZE + FIELD_TYPE) == thing_type {
            count += 1;
        }
    }

    count
}

pub fn first_free_record(data: &[u8]) -> i64 {
    for record in FIRST_RECORD..things::count(data) {
        if things::read(data, record * RECORD_SIZE + FIELD_TYPE) == 0 {
            return record;
        }
    }

    0
}

fn scale(map_edge: i64) -> i64 {
    ((map_edge * map_edge) / 16384).max(1)
}

pub fn spawn_helicopter(data: &mut [u8], text: &mut [u8], point: Vec2i, random: &mut SimRandom, map_edge: i64) -> Spawned {
    let index = motion::index(point, map_edge);

    if index < 0
        || overlay::blocks_thing(overlay::read(text, index))
        || count_type(data, TYPE_MONSTER) != 0
        || count_type(data, TYPE_HELICOPTER) >= scale(map_edge)
    {
        return Spawned::default();
    }

    let record = first_free_record(data);

    if record == 0 {
        return Spawned::default();
    }

    let offset = record * RECORD_SIZE;
    things::write(data, offset + FIELD_TYPE, TYPE_HELICOPTER);
    things::write(data, offset + FIELD_DIRECTION, 2);
    things::write(data, offset + FIELD_STATE, 0);
    things::write(data, offset + FIELD_X, point.x);
    things::write(data, offset + FIELD_Y, point.y);
    things::write(data, offset + FIELD_Z, 0);
    things::write(data, offset + FIELD_PX, 8);
    things::write(data, offset + FIELD_PY, 8);
    let dx = random.next_u15() % map_edge;
    things::write(data, offset + FIELD_DX, dx);
    let dy = random.next_u15() % map_edge;
    things::write(data, offset + FIELD_DY, dy);
    things::write(data, offset + FIELD_LABEL, overlay::read(text, index));
    overlay::write(text, index, overlay::thing_id(record));

    Spawned {
        spawned: true,
        record,
        point,
        ..Default::default()
    }
}

pub fn spawn_airplane(data: &mut [u8], text: &mut [u8], point: Vec2i, runway_axis: i64, random: &mut SimRandom, map_edge: i64) -> Spawned {
    let source_index = motion::index(point, map_edge);

    if source_index < 0
        || overlay::blocks_thing(overlay::read(text, source_index))
        || count_type(data, TYPE_MONSTER) != 0
        || count_type(data, TYPE_AIRPLANE) >= 2 * scale(map_edge)
    {
        return Spawned::default();
    }

    let record = first_free_record(data);

    if record == 0 {
        return Spawned::default();
    }

    let offset = record * RECORD_SIZE;
    things::write(data, offset + FIELD_TYPE, TYPE_AIRPLANE);
    things::write(data, offset + FIELD_PX, 8);
    things::write(data, offset + FIELD_PY, 8);
    let mut attached = point;
    // Keep the original entry margins at 128 and above. Small maps use the same
    // proportions so each edge coordinate stays inside the map.
    let entry_low = ((10 * map_edge) / 128).max(1).min(10);
    let entry_high = ((18 * map_edge) / 128).max(1).min(18);
    let entry_span = map_edge - entry_low - entry_high;

    if random.next_u15() % 10 < 5 {
        match random.next_u15() & 3 {
            0 => {
                attached = Vec2i::new(0, random.next_u15() % entry_span + entry_low);
                things::write(data, offset + FIELD_DIRECTION, 3);
            }
            1 => {
                attached = Vec2i::new(random.next_u15() % entry_span + entry_low, 0);
                things::write(data, offset + FIELD_DIRECTION, 5);
            }
            2 => {
                attached = Vec2i::new(map_edge - 1, random.next_u15() % entry_span + entry_low);
                things::write(data, offset + FIELD_DIRECTION, 7);
            }
            _ => {
                attached = Vec2i::new(random.next_u15() % entry_span + entry_low, map_edge - 1);
                things::write(data, offset + FIELD_DIRECTION, 1);
            }
        }

        things::write(data, offset + FIELD_STATE, runway_axis * 0x10 + 3);
        things::write(data, offset + FIELD_Z, 0x10);

        if runway_axis == 0 {
            things::write(data, offset + FIELD_DX, point.x);
            things::write(data, offset + FIELD_DY, point.y + 0x10);
        } else {
            things::write(data, offset + FIELD_DX, point.x - 0x10);
            things::write(data, offset + FIELD_DY, point.y);
        }
    } else {
        things::write(data, offset + FIELD_DIRECTION, runway_axis);
        things::write(data, offset + FIELD_STATE, 0);
        things::write(data, offset + FIELD_Z, 0);
        things::write(data, offset + FIELD_DX, 0x14);
        things::write(data, offset + FIELD_DY, 0x14);
    }

    things::write(data, offset + FIELD_X, attached.x);
    things::write(data, offset + FIELD_Y, attached.y);
    let attached_index = motion::index(attached, map_edge);
    things::write(data, offset + FIELD_LABEL, overlay::read(text, attached_index));
    overlay::write(text, attached_index, overlay::thing_id(record));

    Spawned {
        spawned: true,
        record,
        point: attached,
        ..Default::default()
    }
}

pub fn spawn_ship(terrain: &[u8], data: &mut [u8], text: &mut [u8], target: Vec2i, random: &mut SimRandom, map_edge: i64) -> Spawned {
    if count_type(data, TYPE_SHIP) >= scale(map_edge) {
        return Spawned::default();
    }

    let mut start = Vec2i::NONE;
    let deep = terrain_ids::DEEP_WATER_FLAT as u8;

    match random.next_u15() & 3 {
        0 => {
            for y in 0..map_edge {
                if terrain[(2 * map_edge + y) as usize] == deep {
                    start = Vec2i::new(2, y);
                }
            }
        }
        1 => {
            for y in 0..map_edge {
                if terrain[((map_edge - 2) * map_edge + y) as usize] == deep {
                    start = Vec2i::new(map_edge - 2, y);
                }
            }
        }
        2 => {
            for x in 0..map_edge {
                if terrain[(x * map_edge + 2) as usize] == deep {
                    start = Vec2i::new(x, 2);
                }
            }
        }
        _ => {
            for x in 0..map_edge {
                if terrain[(x * map_edge + (map_edge - 2)) as usize] == deep {
                    start = Vec2i::new(x, map_edge - 2);
                }
            }
        }
    }

    if start.x < 0 {
        return Spawned::default();
    }

    let start_index = motion::index(start, map_edge);

    if overlay::blocks_thing(overlay::read(text, start_index)) {
        return Spawned::default();
    }

    let record = first_free_record(data);

    if record == 0 {
        return Spawned::default();
    }

    let offset = record * RECORD_SIZE;
    things::write(data, offset + FIELD_TYPE, TYPE_SHIP);
    things::write(data, offset + FIELD_DIRECTION, motion::direction_between(start, target));
    things::write(data, offset + FIELD_STATE, 0);
    things::write(data, offset + FIELD_X, start.x);
    things::write(data, offset + FIELD_Y, start.y);
    things::write(data, offset + FIELD_Z, 1);
    things::write(data, offset + FIELD_PX, 8);
    things::write(data, offset + FIELD_PY, 8);
    things::write(data, offset + FIELD_LABEL, overlay::read(text, start_index));
    overlay::write(text, start_index, overlay::thing_id(record));
    things::set_ship_home(data, record, start);

    Spawned {
        spawned: true,
        record,
        point: start,
        target,
        goal: 0,
    }
}

pub fn spawn_sailboats(
    buildings: &[u8],
    tile_flags: &[u8],
    data: &mut [u8],
    text: &mut [u8],
    point: Vec2i,
    lfsr_random: &mut SimLfsrRandom,
    map_edge: i64,
) -> i64 {
    if count_type(data, TYPE_SAILBOAT) >= 4 * scale(map_edge) {
        return 0;
    }

    let mut spawned = 0;

    for direction in CARDINAL_DIRECTIONS {
        let start = point + direction;
        let index = motion::index(start, map_edge);
        let record = first_free_record(data);

        if record == 0
            || index < 0
            || tile_flags[index as usize] as i64 & flags::WATER == 0
            || buildings[index as usize] as i64 != tiles::EMPTY
            || overlay::read(text, index) != 0
        {
            continue;
        }

        let offset = record * RECORD_SIZE;
        things::write(data, offset + FIELD_TYPE, TYPE_SAILBOAT);
        things::write(data, offset + FIELD_DIRECTION, lfsr_random.next_mod(3));
        things::write(data, offset + FIELD_STATE, 0);
        things::write(data, offset + FIELD_X, start.x);
        things::write(data, offset + FIELD_Y, start.y);
        things::write(data, offset + FIELD_Z, 0);
        things::write(data, offset + FIELD_PX, 4);
        things::write(data, offset + FIELD_PY, 4);
        things::write(data, offset + FIELD_LABEL, 0);
        overlay::write(text, index, overlay::thing_id(record));
        spawned += 1;
    }

    spawned
}

#[allow(clippy::too_many_arguments)]
pub fn spawn_maxis_man(data: &mut [u8], text: &mut [u8], point: Vec2i, target: Vec2i, goal: i64, height: i64, map_edge: i64) -> Spawned {
    let index = motion::index(point, map_edge);
    let target_index = motion::index(target, map_edge);

    if index < 0
        || target_index < 0
        || overlay::blocks_thing(overlay::read(text, index))
        || count_type(data, TYPE_MAXIS_MAN) >= 1
        || (things::is_record_target(goal) && (goal < FIRST_RECORD || things::target_record(goal) >= things::count(data)))
    {
        return Spawned::default();
    }

    let record = first_free_record(data);

    if record == 0 {
        return Spawned::default();
    }

    let offset = record * RECORD_SIZE;
    things::write(data, offset + FIELD_TYPE, TYPE_MAXIS_MAN);
    things::write(data, offset + FIELD_DIRECTION, motion::direction_between(point, target));
    things::write(data, offset + FIELD_STATE, 0);
    things::write(data, offset + FIELD_X, point.x);
    things::write(data, offset + FIELD_Y, point.y);
    things::write(data, offset + FIELD_Z, height.clamp(0, 0xff));
    things::write(data, offset + FIELD_PX, 8);
    things::write(data, offset + FIELD_PY, 8);
    things::write(data, offset + FIELD_DX, target.x);
    things::write(data, offset + FIELD_DY, target.y);
    things::write(data, offset + FIELD_LABEL, overlay::read(text, index));
    things::write(data, offset + FIELD_GOAL, goal);
    overlay::write(text, index, overlay::thing_id(record));

    Spawned {
        spawned: true,
        record,
        point,
        target,
        goal,
    }
}

pub fn spawn_train(
    buildings: &[u8],
    data: &mut [u8],
    text: &mut [u8],
    station: Vec2i,
    game_random: &mut GameLcgRandom,
    lfsr_random: &mut SimLfsrRandom,
    map_edge: i64,
) -> bool {
    for search_offset in TRAIN_SEARCH_OFFSETS {
        if spawn_train_record(buildings, data, text, station + search_offset, game_random, lfsr_random, map_edge) {
            return true;
        }
    }

    false
}

pub fn spawn_train_record(
    buildings: &[u8],
    data: &mut [u8],
    text: &mut [u8],
    start: Vec2i,
    game_random: &mut GameLcgRandom,
    lfsr_random: &mut SimLfsrRandom,
    map_edge: i64,
) -> bool {
    if count_type(data, TYPE_TRAIN_ENGINE) >= 5 * scale(map_edge) {
        return false;
    }

    if start.x < 2 || start.x > map_edge - 4 || start.y < 2 || start.y > map_edge - 4 {
        return false;
    }

    let index = motion::index(start, map_edge);
    let tile = buildings[index as usize] as i64;

    if !(tiles::RAIL_STRAIGHT_1..=tiles::RAIL_CURVE_4).contains(&tile) || overlay::read(text, index) != 0 {
        return false;
    }

    let initial_direction = lfsr_random.next_mod(4);
    let order = game_random.next_mod(2);
    let direction = train_direction(buildings, text, start, initial_direction, order, map_edge);

    if direction < 0 {
        return false;
    }

    // The original skips all three allocation checks. If no slot is free, it
    // writes the train into reserved record 0.
    let engine_record = first_free_record(data);
    things::write(data, engine_record * RECORD_SIZE + FIELD_TYPE, TYPE_TRAIN_ENGINE);
    let first_car_record = first_free_record(data);
    things::write(data, first_car_record * RECORD_SIZE + FIELD_TYPE, TYPE_TRAIN_CAR);
    let second_car_record = first_free_record(data);
    things::write(data, second_car_record * RECORD_SIZE + FIELD_TYPE, TYPE_TRAIN_CAR);

    for record in [engine_record, first_car_record, second_car_record] {
        let offset = record * RECORD_SIZE;
        things::write(data, offset + FIELD_DIRECTION, direction);
        things::write(data, offset + FIELD_X, start.x);
        things::write(data, offset + FIELD_Y, start.y);
        things::write(data, offset + FIELD_Z, 0);
    }

    let engine_offset = engine_record * RECORD_SIZE;
    let first_car_offset = first_car_record * RECORD_SIZE;
    let second_car_offset = second_car_record * RECORD_SIZE;
    // Train PX and PY store the next tile. STATE links each car to the next record.
    let step = CARDINAL_DIRECTIONS[direction as usize];
    things::write(data, engine_offset + FIELD_PX, start.x + step.x);
    things::write(data, engine_offset + FIELD_PY, start.y + step.y);
    things::write(data, first_car_offset + FIELD_PX, start.x);
    things::write(data, first_car_offset + FIELD_PY, start.y);
    things::write(data, second_car_offset + FIELD_PX, start.x);
    things::write(data, second_car_offset + FIELD_PY, start.y);
    things::write(data, engine_offset + FIELD_LABEL, overlay::read(text, index));
    things::write(data, first_car_offset + FIELD_LABEL, 0);
    things::write(data, second_car_offset + FIELD_LABEL, 0);
    things::write(data, engine_offset + FIELD_STATE, first_car_record);
    things::write(data, first_car_offset + FIELD_STATE, second_car_record);
    overlay::write(text, index, overlay::thing_id(engine_record));

    true
}

fn train_direction(buildings: &[u8], text: &[u8], point: Vec2i, initial_direction: i64, order: i64, map_edge: i64) -> i64 {
    for offset in TRAIN_DIRECTION_ORDERS[(order & 1) as usize] {
        let direction = (initial_direction + offset) & 3;
        let neighbor = point + CARDINAL_DIRECTIONS[direction as usize];
        let index = motion::index(neighbor, map_edge);

        if index >= 0 && !overlay::blocks_thing(overlay::read(text, index)) && train_route_tile(buildings[index as usize] as i64) {
            return direction;
        }
    }

    -1
}

pub fn train_route_tile(tile: i64) -> bool {
    (tiles::RAIL_STRAIGHT_1..=tiles::RAIL_SLOPE_8).contains(&tile)
        || (tiles::ROAD_RAIL_CROSSING_1..=tiles::RAIL_POWER_CROSSING_2).contains(&tile)
        || (tiles::RAIL_SUBWAY_ENTRANCE_1..=tiles::RAIL_SUBWAY_ENTRANCE_4).contains(&tile)
        || tile == tiles::HIGHWAY_RAIL_CROSSING_1
        || tile == tiles::HIGHWAY_RAIL_CROSSING_2
        || tile == tiles::RAIL_BRIDGE
        || tile == tiles::RAIL_BRIDGE_PYLON
}

/// A moving thing that the debug menu adds near `points`, as
/// CityDebugActions.spawn_moving_thing. Returns the spawn point, count, and record.
/// The records change only when something was added. The record is the
/// helicopter, airplane, or ship record, or 0.
#[allow(clippy::too_many_arguments)]
pub fn spawn_near(
    city: &mut crate::sim::city::City,
    kind: i64,
    points: &[Vec2i],
    view_center: Vec2i,
    random: &mut SimRandom,
    lfsr_random: &mut SimLfsrRandom,
    game_random: &mut GameLcgRandom,
) -> (Vec2i, i64, i64) {
    let map_edge = city.map_size;
    let mut data = city.xthg.data.clone();
    let mut text = city.xtxt.data.clone();
    let mut point = Vec2i::NONE;
    let mut count = 0;
    let mut record = 0;

    match kind {
        0 => {
            for near in points {
                let spawned = spawn_helicopter(&mut data, &mut text, *near, random, map_edge);

                if spawned.spawned {
                    (point, record) = (*near, spawned.record);
                    break;
                }
            }
        }
        1 => {
            for near in points {
                let spawned = spawn_airplane(&mut data, &mut text, *near, 0, random, map_edge);

                if spawned.spawned {
                    (point, record) = (spawned.point, spawned.record);
                    break;
                }
            }
        }
        2 => {
            let spawned = spawn_ship(&city.xter.data, &mut data, &mut text, view_center, random, map_edge);

            if spawned.spawned {
                (point, record) = (spawned.point, spawned.record);
            }
        }
        3 => {
            for near in points {
                count = spawn_sailboats(&city.xbld.data, &city.xbit.data, &mut data, &mut text, *near, lfsr_random, map_edge);

                if count > 0 {
                    point = *near;
                    break;
                }
            }
        }
        4 => {
            if let Some(found) = points
                .iter()
                .find(|near| spawn_train_record(&city.xbld.data, &mut data, &mut text, **near, game_random, lfsr_random, map_edge))
            {
                point = *found;
            }
        }
        _ => {}
    }

    if kind != 3 && point.x >= 0 {
        count = 1;
    }

    if count > 0 {
        city.xthg.replace(data);
        city.xtxt.replace(text);
    }

    (point, count, record)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::testing::{empty_city, sequence_game, sequence_lfsr, sequence_random};

    #[test]
    fn small_maps_keep_vehicle_capacity() {
        for edge in [16i64, 32, 64] {
            for direction in 0..4 {
                for roll in [0, 32767] {
                    let mut city = empty_city(edge);
                    let mut random = sequence_random(&[0, direction, roll, 999]);
                    let spawned = spawn_airplane(&mut city.xthg.data, &mut city.xtxt.data, Vec2i::new(5, 5), 0, &mut random, edge);
                    assert!(spawned.spawned, "a small map admits an incoming airplane");
                    let entry = spawned.point;
                    assert!(entry.x >= 0 && entry.y >= 0 && entry.x < edge && entry.y < edge);
                    assert_eq!(random.next_u15(), 999, "the aircraft entry uses three draws");
                }
            }

            let mut city = empty_city(edge);
            let point = Vec2i::new(5, 5);
            let (data, text) = (&mut city.xthg.data, &mut city.xtxt.data);
            assert!(spawn_helicopter(data, text, point, &mut SimRandom::new(1), edge).spawned);
            assert!(
                !spawn_helicopter(data, text, Vec2i::new(6, 6), &mut SimRandom::new(1), edge).spawned,
                "a small map keeps the one-helicopter limit"
            );

            let mut city = empty_city(edge);
            city.xter.data.fill(0x10);
            let spawned = spawn_ship(
                &city.xter.data,
                &mut city.xthg.data,
                &mut city.xtxt.data,
                point,
                &mut sequence_random(&[0]),
                edge,
            );
            assert!(spawned.spawned, "a small map keeps cargo ship capacity");

            let mut city = empty_city(edge);
            city.xbit.data.fill(4);
            let mut lfsr = sequence_lfsr(&[0]);
            let (buildings, flags) = (&city.xbld.data, &city.xbit.data);
            assert_eq!(
                spawn_sailboats(buildings, flags, &mut city.xthg.data, &mut city.xtxt.data, point, &mut lfsr, edge),
                4
            );
            let far = Vec2i::new(8, 8);
            assert_eq!(
                spawn_sailboats(buildings, flags, &mut city.xthg.data, &mut city.xtxt.data, far, &mut lfsr, edge),
                0,
                "a small map enforces its sailboat limit"
            );
            let options = crate::sim::moving::phase::TickOptions {
                ship_home: Vec2i::NONE,
                allow_disaster_damage: true,
                traffic_news_time_msec: 0,
                traffic_news_deadline_msec: 0,
                suppress_vehicle_crashes: false,
            };
            let mut randoms = crate::sim::random::Randoms::new(1, 1, 1);
            let crate::sim::random::Randoms { random, lfsr, game } = &mut randoms;
            assert!(
                crate::sim::moving::phase::run(&mut city, random, lfsr, game, &options).base.ok,
                "small-map sailboats tick"
            );
        }
    }

    #[test]
    fn trains_keep_the_edge_margin_and_wide_coordinates() {
        for edge in [16i64, 32, 64, 128, 256, 384, 512, 640, 1024] {
            for start in [Vec2i::new(edge - 4, edge - 4), Vec2i::new(edge - 3, edge - 3)] {
                let mut city = empty_city(edge);

                for delta in [
                    Vec2i::ZERO,
                    Vec2i::new(-1, 0),
                    Vec2i::new(1, 0),
                    Vec2i::new(0, -1),
                    Vec2i::new(0, 1),
                ] {
                    let track = start + delta;
                    city.xbld.data[(track.x * edge + track.y) as usize] = tiles::RAIL_STRAIGHT_1 as u8;
                }

                let spawned = spawn_train_record(
                    &city.xbld.data,
                    &mut city.xthg.data,
                    &mut city.xtxt.data,
                    start,
                    &mut sequence_game(&[0]),
                    &mut sequence_lfsr(&[0]),
                    edge,
                );
                assert_eq!(spawned, start.x == edge - 4, "trains use the actual edge margin at {edge}");

                if spawned {
                    assert_eq!(
                        things::read(&city.xthg.data, RECORD_SIZE + FIELD_X),
                        start.x,
                        "trains keep wide coordinates"
                    );
                }
            }
        }
    }

    #[test]
    fn creators_store_the_original_record_fields() {
        let mut data = vec![0u8; 480];
        let mut text = vec![0u8; 128 * 128];
        let spawned = spawn_airplane(&mut data, &mut text, Vec2i::new(20, 20), 2, &mut sequence_random(&[0, 2, 7]), 128);
        assert!(spawned.spawned, "the airplane creator accepts an empty moving-thing pool");
        assert_eq!(
            &data[13..18],
            &[7, 0x23, 127, 17, 16],
            "a map-edge airplane stores its edge, direction, height, and runway state"
        );
        assert_eq!(
            (data[20], data[21], text[127 * 128 + 17]),
            (4, 20, 202),
            "a map-edge airplane stores its runway target and link"
        );

        let mut data = vec![0u8; 480];
        let mut text = vec![0u8; 128 * 128];
        text[30 * 128 + 20] = 0xff;
        let spawned = spawn_maxis_man(&mut data, &mut text, Vec2i::new(18, 20), Vec2i::new(30, 20), 241, 7, 128);
        assert!(spawned.spawned && spawned.record == 1);
        assert_eq!(data[12] as i64, TYPE_MAXIS_MAN);
        assert_eq!(
            (data[13], data[15], data[16], data[17], data[20], data[21], data[23]),
            (2, 18, 20, 7, 30, 20, 241)
        );
        assert_eq!(text[18 * 128 + 20], 202, "Maxis Man links its record and target");
        let again = spawn_maxis_man(&mut data, &mut text, Vec2i::new(17, 20), Vec2i::new(30, 20), 241, 7, 128);
        assert!(!again.spawned, "Maxis Man dispatch keeps one active hero");

        let mut buildings = vec![0u8; 128 * 128];
        let mut data = vec![0u8; 480];
        let mut text = vec![0u8; 128 * 128];
        buildings[20 * 128 + 18] = tiles::RAIL_STRAIGHT_1 as u8;
        buildings[20 * 128 + 17] = tiles::RAIL_STRAIGHT_1 as u8;

        for record in 1..40 {
            data[record * 12] = 7;
        }

        let spawned = spawn_train(
            &buildings,
            &mut data,
            &mut text,
            Vec2i::new(20, 20),
            &mut sequence_game(&[0]),
            &mut sequence_lfsr(&[0]),
            128,
        );
        assert!(spawned, "a full-pool train keeps the unchecked allocation result");
        assert!(
            data[0] == 11 && text[20 * 128 + 18] == 201,
            "a full-pool train writes reserved record zero like the original"
        );
    }
}
