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

    Spawned { spawned: true, record, point, ..Default::default() }
}

pub fn spawn_airplane(
    data: &mut [u8],
    text: &mut [u8],
    point: Vec2i,
    runway_axis: i64,
    random: &mut SimRandom,
    map_edge: i64,
) -> Spawned {
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

    Spawned { spawned: true, record, point: attached, ..Default::default() }
}

pub fn spawn_ship(
    terrain: &[u8],
    data: &mut [u8],
    text: &mut [u8],
    target: Vec2i,
    random: &mut SimRandom,
    map_edge: i64,
) -> Spawned {
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

    Spawned { spawned: true, record, point: start, target, goal: 0 }
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
pub fn spawn_maxis_man(
    data: &mut [u8],
    text: &mut [u8],
    point: Vec2i,
    target: Vec2i,
    goal: i64,
    height: i64,
    map_edge: i64,
) -> Spawned {
    let index = motion::index(point, map_edge);
    let target_index = motion::index(target, map_edge);

    if index < 0
        || target_index < 0
        || overlay::blocks_thing(overlay::read(text, index))
        || count_type(data, TYPE_MAXIS_MAN) >= 1
        || (things::is_record_target(goal)
            && (goal < FIRST_RECORD || things::target_record(goal) >= things::count(data)))
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

    Spawned { spawned: true, record, point, target, goal }
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

        if index >= 0
            && !overlay::blocks_thing(overlay::read(text, index))
            && train_route_tile(buildings[index as usize] as i64)
        {
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
