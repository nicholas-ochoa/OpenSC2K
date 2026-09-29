//! Sailboat ticks, as SailboatThingTick.

use super::motion::{self, index};
use super::result::{MovingThingResult, queue_thing_sound};
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::overlay;
use crate::sim::random::{SimLfsrRandom, SimRandom};
use crate::sim::things::{self, RECORD_SIZE};

const SOUND_DISTRESS: i64 = 0x20f;
const SUBTILE_LIMIT: i64 = 16;
const SUBTILE_X: [i64; 4] = [0, 16, 0, -16];
const SUBTILE_Y: [i64; 4] = [-16, 0, 16, 0];
const DIRECTIONS: [Vec2i; 4] = [Vec2i::new(0, -1), Vec2i::new(1, 0), Vec2i::new(0, 1), Vec2i::new(-1, 0)];

/// SailboatThingTick.update.
#[allow(clippy::too_many_arguments)]
pub fn update(
    buildings: &[u8],
    flags: &[u8],
    text: &mut [u8],
    data: &mut [u8],
    record: i64,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    counters: &mut MovingThingResult,
    map_edge: i64,
) {
    let offset = record * RECORD_SIZE;

    if counters.active_sailboats > 4 * ((map_edge * map_edge) / 16384).max(1) {
        motion::remove(text, data, record, map_edge);
        counters.removed_sailboats += 1;

        return;
    }

    let direction = things::read(data, offset + 1);

    if direction < 0 || direction >= DIRECTIONS.len() as i64 {
        motion::remove(text, data, record, map_edge);
        counters.removed_sailboats += 1;
        counters.malformed_records += 1;

        return;
    }

    if things::read(data, offset + 2) != 0 {
        if lfsr.next_mod(5) == 0 {
            motion::remove(text, data, record, map_edge);
            counters.removed_sailboats += 1;
        }

        return;
    }

    if lfsr.next_mod(4) == 0 {
        let current = Vec2i::new(things::read(data, offset + 3), things::read(data, offset + 4));
        let current_index = index(current, map_edge);

        if current_index < 0 || flags[current_index as usize] as i64 & flag_bits::WATER == 0 {
            motion::remove(text, data, record, map_edge);
            counters.removed_sailboats += 1;

            return;
        }

        if lfsr.next_mod(4000) == 0 {
            things::write(data, offset + 2, 1);
            counters.distressed_sailboats += 1;
            queue_thing_sound(counters, SOUND_DISTRESS, data, record);
        }

        let turned = (direction + random.next_u15() % 3 - 1) & 3;
        things::write(data, offset + 1, turned);
        counters.turned_sailboats += 1;

        return;
    }

    let route_state = route_state(buildings, flags, text, data, record, direction, map_edge);

    if route_state < 0 {
        counters.removed_sailboats += 1;
    } else if route_state > 0 {
        advance(text, data, record, direction, counters, map_edge);
    }
}

fn route_state(
    buildings: &[u8],
    flags: &[u8],
    text: &mut [u8],
    data: &mut [u8],
    record: i64,
    direction: i64,
    map_edge: i64,
) -> i64 {
    let offset = record * RECORD_SIZE;
    let next = Vec2i::new(things::read(data, offset + 3), things::read(data, offset + 4)) + DIRECTIONS[direction as usize];
    let next_index = index(next, map_edge);

    if next_index < 0 {
        return 1;
    }

    let building = buildings[next_index as usize] as i64;

    if building == tiles::MARINA {
        motion::remove(text, data, record, map_edge);

        return -1;
    }

    if building == tiles::PIER || overlay::read(text, next_index) != 0 {
        return 0;
    }

    if flags[next_index as usize] as i64 & flag_bits::WATER != 0 { 1 } else { 0 }
}

fn advance(text: &mut [u8], data: &mut [u8], record: i64, direction: i64, counters: &mut MovingThingResult, map_edge: i64) {
    let offset = record * RECORD_SIZE;
    let mut subtile_x = things::read(data, offset + 6) + SUBTILE_X[direction as usize];
    let mut subtile_y = things::read(data, offset + 7) + SUBTILE_Y[direction as usize];
    let mut tile_delta = Vec2i::ZERO;

    if subtile_x > SUBTILE_LIMIT {
        subtile_x -= SUBTILE_LIMIT;
        tile_delta.x = 1;
    } else if subtile_x < 0 {
        subtile_x += SUBTILE_LIMIT;
        tile_delta.x = -1;
    }

    if subtile_y > SUBTILE_LIMIT {
        subtile_y -= SUBTILE_LIMIT;
        tile_delta.y = 1;
    } else if subtile_y < 0 {
        subtile_y += SUBTILE_LIMIT;
        tile_delta.y = -1;
    }

    things::write(data, offset + 6, subtile_x);
    things::write(data, offset + 7, subtile_y);

    if tile_delta != Vec2i::ZERO {
        let old_point = Vec2i::new(things::read(data, offset + 3), things::read(data, offset + 4));
        let old_index = index(old_point, map_edge);

        if old_index >= 0 {
            overlay::write(text, old_index, 0);
        }

        let next = old_point + tile_delta;

        if next.x < 0 || next.x > map_edge - 2 || next.y < 0 || next.y > map_edge - 2 {
            motion::remove(text, data, record, map_edge);
            counters.removed_sailboats += 1;

            return;
        }

        things::write(data, offset + 3, next.x);
        things::write(data, offset + 4, next.y);
        overlay::write(text, index(next, map_edge), overlay::thing_id(record));
    }

    counters.moved_sailboats += 1;
}
