//! Train and subway ticks, as TrainThingTick.

use super::motion::{self, index};
use super::result::{MovingThingResult, queue_thing_sound, spawn_explosion};
use super::spawner::VehicleCaps;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::underground_tile_ids as under;
use crate::sim::overlay;
use crate::sim::random::{GameLcgRandom, SimLfsrRandom, SimRandom};
use crate::sim::things::{
    self, FIELD_GOAL, RECORD_SIZE, TYPE_NONE, TYPE_SUBWAY_CAR, TYPE_SUBWAY_ENGINE, TYPE_TRAIN_CAR, TYPE_TRAIN_ENGINE,
};

const SOUND_TRAIN: i64 = 0x20c;
const CARDINAL_DIRECTIONS: [Vec2i; 4] = [Vec2i::new(0, -1), Vec2i::new(1, 0), Vec2i::new(0, 1), Vec2i::new(-1, 0)];
const DIRECTION_ORDERS: [[i64; 4]; 2] = [[0, 3, 1, 2], [0, 1, 3, 2]];
const TRANSITIONS: [i64; 16] = [0, 1, 2, 7, 1, 2, 3, 4, 2, 3, 4, 5, 7, 4, 5, 6];

/// Trains do not use GOAL. The engine counts its consecutive blocked ticks there.
const FIELD_BLOCKED_TICKS: i64 = FIELD_GOAL;
/// A blocked train turns back after about three seconds of 200 ms ticks.
const BLOCKED_REVERSE_TICKS: i64 = 15;
/// A train that stays blocked after it turns back leaves the map, so a new train can spawn.
const BLOCKED_REMOVE_TICKS: i64 = 50;

/// The maps that a train reads.
pub struct TrainMaps<'a> {
    pub buildings: &'a [u8],
    pub underground: &'a [u8],
    pub map_edge: i64,
    pub vehicle_caps: VehicleCaps,
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

        if spawn_explosion(text, data, current, 0, 0, 0, edge, &maps.vehicle_caps) {
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

    // after a reverse, the destination is the tile below the engine. a combined
    // index still shows the tail car there, and a layered index shows the engine
    if overlay::blocks_thing(destination_overlay)
        && destination_overlay != overlay::thing_id(record)
        && destination_overlay != overlay::thing_id(second_car)
        && !clear_stale_train_id(text, data, destination_index, destination, destination_overlay)
    {
        let blocked = count_blocked_tick(text, data, record, first_car, second_car, edge, counters);

        // a train that waits too long turns back
        if blocked == Some(BLOCKED_REVERSE_TICKS) {
            reverse(text, data, record, second_car, edge);
            counters.reversed_trains += 1;
        }

        return;
    }

    if [record, first_car, second_car]
        .iter()
        .any(|checked| record_index(data, *checked, edge) < 0)
    {
        remove_train(text, data, record, first_car, second_car, edge);
        counters.removed_trains += 1;
        counters.malformed_records += 1;

        return;
    }

    if current != destination {
        overlay::write(text, record_index(data, record, edge), overlay::thing_id(first_car));
        overlay::write(text, record_index(data, first_car, edge), overlay::thing_id(second_car));
        let tail_label = things::read(data, second_car_offset + 10);
        overlay::lift_object(text, data, second_car, record_index(data, second_car, edge), tail_label);
        copy_record(data, first_car, second_car);
        copy_record(data, record, first_car);
        overlay::push_object(text, data, record, destination_index);
        things::write(data, offset + FIELD_BLOCKED_TICKS, 0);
        counters.moved_trains += 1;
    }

    things::write(data, offset + 3, destination.x);
    things::write(data, offset + 4, destination.y);
    current = destination;
    let current_tile = maps.buildings[index(current, edge) as usize] as i64;

    if (tiles::RAIL_SUBWAY_FIRST..=tiles::DEVELOPED_FIRST).contains(&current_tile) {
        let converted = if engine_type == TYPE_TRAIN_ENGINE {
            TYPE_SUBWAY_ENGINE
        } else {
            TYPE_TRAIN_ENGINE
        };
        things::write(data, offset, converted);
        engine_type = things::read(data, offset);
    }

    direction = things::read(data, offset + 1) & 0x0f;

    if lfsr.next_mod(4) == 0 {
        let turn_direction = if lfsr.next_mod(2) == 0 {
            (direction - 1) & 3
        } else {
            (direction + 1) & 3
        };

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
            reverse(text, data, record, second_car, edge);
            counters.reversed_trains += 1;
            count_blocked_tick(text, data, record, first_car, second_car, edge, counters);

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

/// Swap the engine and the tail car. A layered index also swaps their object
/// IDs, so a later lift finds the ID of each record on its own tile.
fn reverse(text: &mut [u8], data: &mut [u8], engine_record: i64, second_car_record: i64, map_edge: i64) {
    let engine = engine_record * RECORD_SIZE;
    let second_car = second_car_record * RECORD_SIZE;
    let head_index = record_index(data, engine_record, map_edge);
    let tail_index = record_index(data, second_car_record, map_edge);

    if head_index >= 0 && tail_index >= 0 && head_index != tail_index {
        let engine_id = overlay::thing_id(engine_record);
        let second_car_id = overlay::thing_id(second_car_record);
        overlay::replace_object(text, data, head_index, engine_id, second_car_id);
        overlay::replace_object(text, data, tail_index, second_car_id, engine_id);
    }

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

/// Count one more tick without a move. A train that stays blocked leaves the
/// map, so a new train can spawn. Returns the count, or None after a removal.
fn count_blocked_tick(
    text: &mut [u8],
    data: &mut [u8],
    record: i64,
    first_car: i64,
    second_car: i64,
    map_edge: i64,
    counters: &mut MovingThingResult,
) -> Option<i64> {
    let blocked_offset = record * RECORD_SIZE + FIELD_BLOCKED_TICKS;
    let blocked = things::read(data, blocked_offset) + 1;

    if blocked >= BLOCKED_REMOVE_TICKS {
        remove_train(text, data, record, first_car, second_car, map_edge);
        counters.active_trains -= 1;
        counters.removed_trains += 1;

        return None;
    }

    things::write(data, blocked_offset, blocked);

    Some(blocked)
}

/// Remove a train ID from tile `index` of a layered index when that train
/// record is gone or is on another tile. Older saves can keep such an ID, and
/// it blocks the track. Returns true when the tile is clear.
fn clear_stale_train_id(text: &mut [u8], data: &[u8], index: i64, point: Vec2i, id: i64) -> bool {
    if !overlay::is_layered(text) || !overlay::is_thing(id) || overlay::object(text, index) != id {
        return false;
    }

    let record = overlay::thing_record(id);

    if record < 0 || record >= things::count(data) {
        return false;
    }

    let offset = record * RECORD_SIZE;
    let kind = things::read(data, offset);
    let position = Vec2i::new(things::read(data, offset + 3), things::read(data, offset + 4));
    let train = (TYPE_TRAIN_ENGINE..=TYPE_SUBWAY_CAR).contains(&kind);

    if kind != TYPE_NONE && !(train && position != point) {
        return false;
    }

    overlay::set_object(text, index, 0);

    true
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::random::Randoms;
    use crate::sim::things::TYPE_POLICE;

    const EDGE: i64 = 16;
    const ROW: i64 = 5;
    const ENGINE: i64 = 1;
    const FIRST_CAR: i64 = 2;
    const SECOND_CAR: i64 = 3;

    struct Track {
        buildings: Vec<u8>,
        underground: Vec<u8>,
        text: Vec<u8>,
        data: Vec<u8>,
        randoms: Randoms,
    }

    /// A layered SC2X city with one rail line from `first` to `last` on one row,
    /// and a train that moves east with its engine at `head`.
    fn track(first: i64, last: i64, head: i64) -> Track {
        let mut buildings = vec![0u8; (EDGE * EDGE) as usize];

        for x in first..=last {
            buildings[index(Vec2i::new(x, ROW), EDGE) as usize] = tiles::RAIL_FIRST as u8;
        }

        let mut text = overlay::layered(EDGE * EDGE);
        let mut data = vec![0u8; (40 * RECORD_SIZE * 2) as usize];

        for (car, record) in [ENGINE, FIRST_CAR, SECOND_CAR].into_iter().enumerate() {
            let offset = record * RECORD_SIZE;
            let point = Vec2i::new(head - car as i64, ROW);
            let kind = if record == ENGINE { TYPE_TRAIN_ENGINE } else { TYPE_TRAIN_CAR };
            things::write(&mut data, offset, kind);
            things::write(&mut data, offset + 1, 1);
            things::write(&mut data, offset + 2, record + 1);
            things::write(&mut data, offset + 3, point.x);
            things::write(&mut data, offset + 4, point.y);
            things::write(&mut data, offset + 6, point.x + i64::from(record == ENGINE));
            things::write(&mut data, offset + 7, point.y);
            overlay::set_object(&mut text, index(point, EDGE), overlay::thing_id(record));
        }

        Track {
            buildings,
            underground: vec![0u8; (EDGE * EDGE) as usize],
            text,
            data,
            randoms: Randoms::new(1, 1, 1),
        }
    }

    fn tick(track: &mut Track) -> MovingThingResult {
        let maps = TrainMaps {
            buildings: &track.buildings,
            underground: &track.underground,
            map_edge: EDGE,
            vehicle_caps: VehicleCaps::legacy(EDGE),
        };
        let Randoms { random, lfsr, game } = &mut track.randoms;
        let mut counters = MovingThingResult::default();
        update(&maps, &mut track.text, &mut track.data, ENGINE, random, lfsr, game, &mut counters);

        counters
    }

    fn position(track: &Track, record: i64) -> Vec2i {
        let offset = record * RECORD_SIZE;

        Vec2i::new(things::read(&track.data, offset + 3), things::read(&track.data, offset + 4))
    }

    fn block(track: &mut Track, record: i64, x: i64) {
        things::write(&mut track.data, record * RECORD_SIZE, TYPE_POLICE);
        overlay::set_object(&mut track.text, index(Vec2i::new(x, ROW), EDGE), overlay::thing_id(record));
    }

    /// Each train ID on the map is on the tile of its record.
    fn assert_train_ids_match_records(track: &Track, tick: i64) {
        for x in 0..EDGE {
            let point = Vec2i::new(x, ROW);
            let id = overlay::object(&track.text, index(point, EDGE));

            if [ENGINE, FIRST_CAR, SECOND_CAR]
                .iter()
                .any(|record| overlay::thing_id(*record) == id)
            {
                let record = overlay::thing_record(id);
                let kind = things::read(&track.data, record * RECORD_SIZE);
                assert!(kind != TYPE_NONE, "tick {tick}: a removed record keeps its ID at {x}");
                assert_eq!(position(track, record), point, "tick {tick}: the ID of record {record} is at {x}");
            }
        }
    }

    #[test]
    fn reversed_trains_keep_layered_ids_on_their_own_tiles() {
        let mut track = track(2, 6, 5);
        let mut reversed = 0;
        let mut reached_west_end = false;

        for tick_number in 0..16 {
            reversed += tick(&mut track).reversed_trains;
            assert_train_ids_match_records(&track, tick_number);
            reached_west_end |= [ENGINE, FIRST_CAR, SECOND_CAR]
                .iter()
                .any(|record| position(&track, *record).x == 2);
        }

        assert!(reversed >= 2, "the train turns back at each end of the line");
        assert!(reached_west_end, "the train leaves the east end of the line");
    }

    #[test]
    fn blocked_trains_turn_back_then_leave_the_map() {
        let mut track = track(2, 8, 5);
        block(&mut track, 10, 6);
        block(&mut track, 11, 2);

        for _ in 1..BLOCKED_REVERSE_TICKS {
            tick(&mut track);
        }

        assert_eq!(position(&track, ENGINE).x, 5, "a blocked train waits");
        assert_eq!(tick(&mut track).reversed_trains, 1);
        assert_eq!(position(&track, ENGINE).x, 3, "the engine moves to the tail");

        let mut removed_at = -1;

        for tick_number in BLOCKED_REVERSE_TICKS + 1..BLOCKED_REMOVE_TICKS + 10 {
            if tick(&mut track).removed_trains > 0 {
                removed_at = tick_number;

                break;
            }

            assert_train_ids_match_records(&track, tick_number);
        }

        assert_eq!(removed_at, BLOCKED_REMOVE_TICKS, "a boxed-in train leaves the map");

        for record in [ENGINE, FIRST_CAR, SECOND_CAR] {
            assert_eq!(things::read(&track.data, record * RECORD_SIZE), TYPE_NONE);
        }

        for x in 3..=5 {
            assert_eq!(
                overlay::object(&track.text, index(Vec2i::new(x, ROW), EDGE)),
                0,
                "the track is clear at {x}"
            );
        }

        assert_eq!(overlay::object(&track.text, index(Vec2i::new(6, ROW), EDGE)), overlay::thing_id(10));
        assert_eq!(overlay::object(&track.text, index(Vec2i::new(2, ROW), EDGE)), overlay::thing_id(11));
    }

    #[test]
    fn stale_train_ids_do_not_block_the_track() {
        let mut track = track(2, 8, 5);
        let ahead = index(Vec2i::new(6, ROW), EDGE);
        // record 9 is empty, and record 3 is the tail car on another tile
        overlay::set_object(&mut track.text, ahead, overlay::thing_id(9));
        tick(&mut track);
        assert_eq!(position(&track, ENGINE).x, 6, "an ID of an empty record does not block");

        overlay::set_object(&mut track.text, index(Vec2i::new(7, ROW), EDGE), overlay::thing_id(SECOND_CAR));
        let ahead = position(&track, ENGINE) + Vec2i::new(1, 0);
        things::write(&mut track.data, ENGINE * RECORD_SIZE + 6, ahead.x);
        things::write(&mut track.data, ENGINE * RECORD_SIZE + 7, ahead.y);
        tick(&mut track);
        assert_eq!(position(&track, ENGINE).x, 7, "a train ID away from its record does not block");
    }

    #[test]
    fn copied_records_keep_wide_fields() {
        for edge in [256i64, 512, 1024] {
            let count = 40 * (edge * edge) / 16384;
            let mut data = vec![0u8; (count * 24) as usize];
            let last = count - 1;
            things::write(&mut data, last * RECORD_SIZE, TYPE_TRAIN_ENGINE);
            things::write(&mut data, last * RECORD_SIZE + 2, last - 1);
            things::write(&mut data, last * RECORD_SIZE + 6, edge - 7);
            things::write(&mut data, last * RECORD_SIZE + 7, edge - 8);
            copy_record(&mut data, last, last - 1);
            assert_eq!(
                things::read(&data, (last - 1) * RECORD_SIZE + 6),
                edge - 7,
                "the copy keeps a wide coordinate"
            );
            assert_eq!(
                things::read(&data, last * RECORD_SIZE + 2),
                last - 1,
                "the car link keeps its width"
            );
            assert_eq!(things::read(&data, (last - 1) * RECORD_SIZE), TYPE_TRAIN_CAR);
        }
    }
}
