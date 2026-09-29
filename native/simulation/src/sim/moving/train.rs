//! Train and subway ticks, as TrainThingTick.

use super::motion::{self, index};
use super::result::{MovingThingResult, queue_thing_sound, spawn_explosion};
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::underground_tile_ids as under;
use crate::sim::overlay;
use crate::sim::random::{GameLcgRandom, SimLfsrRandom, SimRandom};
use crate::sim::things::{self, RECORD_SIZE, TYPE_SUBWAY_CAR, TYPE_SUBWAY_ENGINE, TYPE_TRAIN_CAR, TYPE_TRAIN_ENGINE};

const SOUND_TRAIN: i64 = 0x20c;
const CARDINAL_DIRECTIONS: [Vec2i; 4] = [Vec2i::new(0, -1), Vec2i::new(1, 0), Vec2i::new(0, 1), Vec2i::new(-1, 0)];
const DIRECTION_ORDERS: [[i64; 4]; 2] = [[0, 3, 1, 2], [0, 1, 3, 2]];
const TRANSITIONS: [i64; 16] = [0, 1, 2, 7, 1, 2, 3, 4, 2, 3, 4, 5, 7, 4, 5, 6];

/// The maps that a train reads.
pub struct TrainMaps<'a> {
    pub buildings: &'a [u8],
    pub underground: &'a [u8],
    pub map_edge: i64,
}

/// TrainThingTick.update.
#[allow(clippy::too_many_arguments)]
pub fn update(
    maps: &TrainMaps,
    text: &mut [u8],
    data: &mut [u8],
    record: i64,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    game: &mut GameLcgRandom,
    counters: &mut MovingThingResult,
) {
    let edge = maps.map_edge;
    let offset = record * RECORD_SIZE;
    let mut engine_type = things::read(data, offset);
    let first_car = things::read(data, offset + 2);
    let count = things::count(data);

    if first_car < 0 || first_car >= count {
        motion::remove(text, data, record, edge);
        counters.removed_trains += 1;
        counters.malformed_records += 1;

        return;
    }

    let second_car = things::read(data, first_car * RECORD_SIZE + 2);

    if second_car < 0 || second_car >= count {
        motion::remove(text, data, record, edge);
        motion::remove(text, data, first_car, edge);
        counters.removed_trains += 1;
        counters.malformed_records += 1;

        return;
    }

    let second_car_offset = second_car * RECORD_SIZE;
    let mut current = Vec2i::new(things::read(data, offset + 3), things::read(data, offset + 4));
    let mut direction = things::read(data, offset + 1) & 0x0f;

    if direction >= CARDINAL_DIRECTIONS.len() as i64 {
        remove_train(text, data, record, first_car, second_car, edge);
        counters.removed_trains += 1;
        counters.malformed_records += 1;

        return;
    }

    if engine_type == TYPE_TRAIN_ENGINE && lfsr.next_mask(1) != 0 {
        let mut station_offset = Vec2i::ZERO;

        if direction & 1 == 0 {
            station_offset.x = if game.next_mod(2) == 0 { -1 } else { 1 };
        } else {
            station_offset.y = if game.next_mod(2) == 0 { -1 } else { 1 };
        }

        let station_index = index(current + station_offset, edge);

        if station_index >= 0 && maps.buildings[station_index as usize] as i64 == tiles::RAIL_STATION {
            counters.paused_trains += 1;

            return;
        }
    }

    if !current_route_is_valid(maps, current) {
        remove_train(text, data, record, first_car, second_car, edge);
        counters.active_trains -= 1;
        counters.removed_trains += 1;

        if spawn_explosion(text, data, current, 0, 0, 0, edge) {
            counters.created_train_crash_explosions += 1;
        }

        return;
    }

    let destination = Vec2i::new(things::read(data, offset + 6), things::read(data, offset + 7));
    let destination_index = index(destination, edge);

    if destination_index < 0 {
        remove_train(text, data, record, first_car, second_car, edge);
        counters.removed_trains += 1;
        counters.malformed_records += 1;

        return;
    }

    let destination_overlay = overlay::read(text, destination_index);

    if overlay::blocks_thing(destination_overlay) && destination_overlay != overlay::thing_id(second_car) {
        return;
    }

    if [record, first_car, second_car].iter().any(|checked| record_index(data, *checked, edge) < 0) {
        remove_train(text, data, record, first_car, second_car, edge);
        counters.removed_trains += 1;
        counters.malformed_records += 1;

        return;
    }

    if current != destination {
        overlay::write(text, record_index(data, record, edge), overlay::thing_id(first_car));
        overlay::write(text, record_index(data, first_car, edge), overlay::thing_id(second_car));
        let tail_label = things::read(data, second_car_offset + 10);
        overlay::write(text, record_index(data, second_car, edge), tail_label);
        copy_record(data, first_car, second_car);
        copy_record(data, record, first_car);
        things::write(data, offset + 10, overlay::read(text, destination_index));
        overlay::write(text, destination_index, overlay::thing_id(record));
        counters.moved_trains += 1;
    }

    things::write(data, offset + 3, destination.x);
    things::write(data, offset + 4, destination.y);
    current = destination;
    let current_tile = maps.buildings[index(current, edge) as usize] as i64;

    if (tiles::RAIL_SUBWAY_FIRST..=tiles::DEVELOPED_FIRST).contains(&current_tile) {
        let converted = if engine_type == TYPE_TRAIN_ENGINE { TYPE_SUBWAY_ENGINE } else { TYPE_TRAIN_ENGINE };
        things::write(data, offset, converted);
        engine_type = things::read(data, offset);
    }

    direction = things::read(data, offset + 1) & 0x0f;

    if lfsr.next_mod(4) == 0 {
        let turn_direction = if lfsr.next_mod(2) == 0 { (direction - 1) & 3 } else { (direction + 1) & 3 };

        if route_is_valid(maps, text, current + CARDINAL_DIRECTIONS[turn_direction as usize], engine_type) {
            direction = turn_direction;
            counters.turned_trains += 1;
        }

        if random.next_u15() & 0xff == 0 {
            queue_thing_sound(counters, SOUND_TRAIN, data, record);
        }
    }

    let mut next = current + CARDINAL_DIRECTIONS[direction as usize];

    if !route_is_valid(maps, text, next, engine_type) {
        let selected = select_direction(maps, text, current, direction, engine_type, game);

        if selected < 0 {
            reverse(data, record, second_car);
            counters.reversed_trains += 1;

            return;
        }

        things::write(data, offset + 1, selected);
        things::write(data, offset + 8, TRANSITIONS[(direction * 4 + selected) as usize]);
        next = current + CARDINAL_DIRECTIONS[selected as usize];
    } else {
        let stored = things::read(data, offset + 1) & 0x0f;
        things::write(data, offset + 1, stored);
        things::write(data, offset + 8, direction * 2);
    }

    things::write(data, offset + 6, next.x);
    things::write(data, offset + 7, next.y);
}

fn current_route_is_valid(maps: &TrainMaps, point: Vec2i) -> bool {
    let tile_index = index(point, maps.map_edge);

    if tile_index < 0 {
        return false;
    }

    let surface = maps.buildings[tile_index as usize] as i64;

    if is_surface_route(surface) || (tiles::RAIL_SUBWAY_FIRST..=tiles::DEVELOPED_FIRST).contains(&surface) {
        return true;
    }

    is_underground_route(maps.underground[tile_index as usize] as i64)
}

fn route_is_valid(maps: &TrainMaps, text: &[u8], point: Vec2i, engine_type: i64) -> bool {
    let tile_index = index(point, maps.map_edge);

    if tile_index < 0 || overlay::blocks_thing(overlay::read(text, tile_index)) {
        return false;
    }

    let surface = maps.buildings[tile_index as usize] as i64;

    if engine_type == TYPE_TRAIN_ENGINE {
        return is_surface_route(surface);
    }

    is_underground_route(maps.underground[tile_index as usize] as i64)
        || (tiles::RAIL_SUBWAY_FIRST..=tiles::DEVELOPED_FIRST).contains(&surface)
}

fn is_surface_route(tile: i64) -> bool {
    (tiles::RAIL_FIRST..=tiles::RAIL_LAST).contains(&tile)
        || (tiles::ROAD_RAIL_CROSSING_1..=tiles::RAIL_POWER_CROSSING_2).contains(&tile)
        || (tiles::RAIL_SUBWAY_FIRST..=tiles::RAIL_SUBWAY_LAST).contains(&tile)
        || tile == tiles::HIGHWAY_RAIL_CROSSING_1
        || tile == tiles::HIGHWAY_RAIL_CROSSING_2
        || tile == tiles::RAIL_BRIDGE
        || tile == tiles::RAIL_BRIDGE_PYLON
}

fn is_underground_route(tile: i64) -> bool {
    (tile > under::EMPTY && tile < under::PIPE_FIRST)
        || tile == under::PIPE_TB_SUBWAY_LR
        || tile == under::PIPE_LR_SUBWAY_TB
        || tile == under::MISSILE_SILO
        || tile == under::SUBWAY_ENTRANCE
}

fn select_direction(
    maps: &TrainMaps,
    text: &[u8],
    point: Vec2i,
    initial_direction: i64,
    engine_type: i64,
    game: &mut GameLcgRandom,
) -> i64 {
    let order_index = game.next_mod(2);

    for direction_offset in DIRECTION_ORDERS[order_index as usize] {
        let direction = (initial_direction + direction_offset) & 3;

        if route_is_valid(maps, text, point + CARDINAL_DIRECTIONS[direction as usize], engine_type) {
            return direction;
        }
    }

    -1
}

fn copy_record(data: &mut [u8], source_record: i64, destination_record: i64) {
    let source = source_record * RECORD_SIZE;
    let destination = destination_record * RECORD_SIZE;

    for field in [0, 3, 4, 6, 7, 10, 1, 8] {
        let value = things::read(data, source + field);
        things::write(data, destination + field, value);
    }

    let copied = things::read(data, destination);

    if copied == TYPE_TRAIN_ENGINE {
        things::write(data, destination, TYPE_TRAIN_CAR);
    } else if copied == TYPE_SUBWAY_ENGINE {
        things::write(data, destination, TYPE_SUBWAY_CAR);
    }
}

fn reverse(data: &mut [u8], engine_record: i64, second_car_record: i64) {
    let engine = engine_record * RECORD_SIZE;
    let second_car = second_car_record * RECORD_SIZE;
    let tail_x = things::read(data, second_car + 3);
    let tail_y = things::read(data, second_car + 4);
    let tail_label = things::read(data, second_car + 10);
    let reverse_direction = (things::read(data, second_car + 1) + 2) & 3;

    for field in [3, 4, 6, 7, 10] {
        let value = things::read(data, engine + field);
        things::write(data, second_car + field, value);
    }

    things::write(data, engine + 3, tail_x);
    things::write(data, engine + 4, tail_y);
    things::write(data, engine + 6, tail_x);
    things::write(data, engine + 7, tail_y);
    things::write(data, engine + 10, tail_label);
    things::write(data, engine + 8, reverse_direction + 4);
    things::write(data, engine + 1, reverse_direction);
}

fn record_index(data: &[u8], record: i64, map_edge: i64) -> i64 {
    let offset = record * RECORD_SIZE;

    index(Vec2i::new(things::read(data, offset + 3), things::read(data, offset + 4)), map_edge)
}

fn remove_train(text: &mut [u8], data: &mut [u8], engine: i64, first_car: i64, second_car: i64, map_edge: i64) {
    motion::remove(text, data, engine, map_edge);
    motion::remove(text, data, first_car, map_edge);
    motion::remove(text, data, second_car, map_edge);
}
