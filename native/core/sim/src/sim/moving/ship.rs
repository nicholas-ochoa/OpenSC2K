//! Ship ticks, as ShipThingTick.

use super::motion::{self, direction_between, index};
use super::result::{MovingThingResult, queue_thing_sound};
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::underground_tile_ids as under;
use crate::sim::overlay;
use crate::sim::random::{SimLfsrRandom, SimRandom};
use crate::sim::things::{self, RECORD_SIZE, TYPE_EXPLOSION};

const SOUND_SHIP: i64 = 0x205;
const ROUTE_DELTAS: [Vec2i; 8] = [
    Vec2i::new(0, -4),
    Vec2i::new(3, -3),
    Vec2i::new(4, 0),
    Vec2i::new(3, 3),
    Vec2i::new(0, 4),
    Vec2i::new(-3, 3),
    Vec2i::new(-4, 0),
    Vec2i::new(-3, -3),
];
const DIRECTION_OFFSETS: [i64; 9] = [0, 1, 2, 3, 4, 5, 6, 7, 0];
const REVERSE_OFFSETS: [i64; 8] = [0, 7, 6, 5, 4, 3, 2, 1];
const PIER_DELTAS: [Vec2i; 4] = [Vec2i::new(2, 0), Vec2i::new(0, 2), Vec2i::new(-2, 0), Vec2i::new(0, -2)];

/// The maps that a ship reads.
pub struct ShipMaps<'a> {
    pub buildings: &'a [u8],
    pub underground: &'a [u8],
    pub flags: &'a [u8],
    pub map_edge: i64,
}

/// ShipThingTick.update.
#[allow(clippy::too_many_arguments)]
pub fn update(
    maps: &ShipMaps,
    text: &mut [u8],
    data: &mut [u8],
    record: i64,
    ship_home: Vec2i,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    counters: &mut MovingThingResult,
) {
    let edge = maps.map_edge;
    let offset = record * RECORD_SIZE;

    if random.next_u15() & 0xff == 0 {
        queue_thing_sound(counters, SOUND_SHIP, data, record);
    }

    let current = Vec2i::new(things::read(data, offset + 3), things::read(data, offset + 4));
    let current_index = index(current, edge);
    let mut direction = things::read(data, offset + 1);

    if current_index < 0 || !(0..8).contains(&direction) {
        convert_to_explosion(data, record);
        counters.crashed_ships += 1;
        counters.malformed_records += 1;

        return;
    }

    if maps.flags[current_index as usize] as i64 & flag_bits::WATER == 0 {
        convert_to_explosion(data, record);
        counters.crashed_ships += 1;

        return;
    }

    let target = Vec2i::new(things::read(data, offset + 8), things::read(data, offset + 9));

    match things::read(data, offset + 2) {
        0 => {
            if lfsr.next_mod(10) == 0 {
                let turned = steer_direction(direction, current, target);

                if route_is_valid(maps, text, current, turned) {
                    direction = turned;
                    things::write(data, offset + 1, direction);
                }
            }

            if route_is_valid(maps, text, current, direction) {
                if !advance(text, data, record, direction, edge) {
                    counters.removed_ships += 1;

                    return;
                }

                counters.moved_ships += 1;
            } else {
                things::write(data, offset + 2, 1);
            }

            for pier_delta in PIER_DELTAS {
                let pier_index = index(current + pier_delta, edge);

                if pier_index >= 0 && maps.buildings[pier_index as usize] as i64 == tiles::PIER {
                    things::write(data, offset + 2, 3);
                    counters.docked_ships += 1;
                }
            }
        }
        1 => {
            let desired = direction_between(current, target);
            direction = turn_one_step(direction, desired);
            things::write(data, offset + 1, direction);

            if direction == desired {
                let state = if route_is_valid(maps, text, current, desired) { 0 } else { 2 };
                things::write(data, offset + 2, state);
            }
        }
        2 => {
            let reverse = lfsr.next_mod(2) == 0;
            let offsets: &[i64] = if reverse { &REVERSE_OFFSETS } else { &DIRECTION_OFFSETS[..8] };
            let mut found = false;

            for direction_offset in offsets {
                direction = (things::read(data, offset + 1) + direction_offset) & 7;

                if route_is_valid(maps, text, current, direction) {
                    found = true;
                    break;
                }
            }

            if !found {
                motion::remove(text, data, record, edge);
                counters.removed_ships += 1;
                let stored = things::read(data, offset + 1);
                direction = if reverse { (stored + 2) & 7 } else { stored & 7 };
            }

            things::write(data, offset + 1, direction);
            things::write(data, offset + 2, 0);
        }
        3 => {
            if lfsr.next_mod(30) == 0 {
                things::write(data, offset + 2, 4);
                queue_thing_sound(counters, SOUND_SHIP, data, record);
                counters.departing_ships += 1;
                let home = if index(ship_home, edge) >= 0 { ship_home } else { current };
                things::write(data, offset + 8, home.x);
                things::write(data, offset + 9, home.y);
            }
        }
        4 => {
            if route_is_valid(maps, text, current, direction) {
                if !advance(text, data, record, direction, edge) {
                    counters.removed_ships += 1;

                    return;
                }

                counters.moved_ships += 1;

                return;
            }

            let start_offset = lfsr.next_mod(2);

            for order_index in start_offset..DIRECTION_OFFSETS.len() as i64 {
                direction = (things::read(data, offset + 1) + DIRECTION_OFFSETS[order_index as usize]) & 7;

                if route_is_valid(maps, text, current, direction) {
                    break;
                }
            }

            things::write(data, offset + 1, direction);
        }
        _ => {}
    }
}

fn route_is_valid(maps: &ShipMaps, text: &[u8], current: Vec2i, direction: i64) -> bool {
    let route_index = index(current + ROUTE_DELTAS[direction as usize], maps.map_edge);

    if route_index < 0 {
        return true;
    }

    is_water_route(maps, route_index) && !overlay::blocks_thing(overlay::read(text, route_index))
}

fn is_water_route(maps: &ShipMaps, tile_index: i64) -> bool {
    let i = tile_index as usize;

    if maps.flags[i] as i64 & flag_bits::WATER == 0 {
        return false;
    }

    let underground = maps.underground[i] as i64;

    if (under::PIPE_FIRST..=under::PIPE_TB_SUBWAY_LR).contains(&underground) {
        return false;
    }

    let building = maps.buildings[i] as i64;

    if building == tiles::MARINA {
        return false;
    }

    building == tiles::EMPTY
        || matches!(
            building,
            tiles::SUSPENSION_BRIDGE_1
                | tiles::SUSPENSION_BRIDGE_2
                | tiles::SUSPENSION_BRIDGE_4
                | tiles::SUSPENSION_BRIDGE_5
                | tiles::RAISING_BRIDGE_CLOSED
                | tiles::RAISING_BRIDGE_OPEN
                | tiles::RAIL_BRIDGE_PYLON
                | tiles::POWER_BRIDGE
                | tiles::REINFORCED_HIGHWAY_BRIDGE
        )
}

fn advance(text: &mut [u8], data: &mut [u8], record: i64, direction: i64, map_edge: i64) -> bool {
    let offset = record * RECORD_SIZE;
    let delta = ROUTE_DELTAS[direction as usize];
    let mut subtile_x = things::read(data, offset + 6) + delta.x;
    let mut subtile_y = things::read(data, offset + 7) + delta.y;
    let mut tile_delta = Vec2i::ZERO;

    if subtile_x > 12 {
        subtile_x -= 12;
        tile_delta.x = 1;
    } else if subtile_x < 0 {
        subtile_x += 12;
        tile_delta.x = -1;
    }

    if subtile_y > 12 {
        subtile_y -= 12;
        tile_delta.y = 1;
    } else if subtile_y < 0 {
        subtile_y += 12;
        tile_delta.y = -1;
    }

    things::write(data, offset + 6, subtile_x);
    things::write(data, offset + 7, subtile_y);

    if tile_delta == Vec2i::ZERO {
        return true;
    }

    let current = Vec2i::new(things::read(data, offset + 3), things::read(data, offset + 4));
    let current_index = index(current, map_edge);

    if current_index >= 0 {
        let label = things::read(data, offset + 10);
        overlay::lift_object(text, data, record, current_index, label);
    }

    let next = current + tile_delta;
    let next_index = index(next, map_edge);

    if next_index < 0 {
        things::write(data, offset, 0);

        return false;
    }

    things::write(data, offset + 3, next.x);
    things::write(data, offset + 4, next.y);
    overlay::push_object(text, data, record, next_index);

    true
}

fn convert_to_explosion(data: &mut [u8], record: i64) {
    let offset = record * RECORD_SIZE;
    things::write(data, offset, TYPE_EXPLOSION);
    things::write(data, offset + 1, 0);
    things::write(data, offset + 2, 0);
    things::write(data, offset + 11, 0);
}

fn steer_direction(direction: i64, start: Vec2i, target: Vec2i) -> i64 {
    let desired = direction_between(start, target);

    if desired == direction {
        direction
    } else {
        turn_one_step(direction, desired)
    }
}

pub fn turn_one_step(direction: i64, target: i64) -> i64 {
    if direction <= target {
        return if target - direction > 4 {
            (direction - 1) & 7
        } else {
            (direction + 1) & 7
        };
    }

    if direction - target > 4 {
        (direction + 1) & 7
    } else {
        (direction - 1) & 7
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::moving::motion::DIRECTIONS;
    use crate::sim::testing::{sequence_lfsr, sequence_random};

    #[test]
    fn ships_leave_at_each_edge_and_corner() {
        for (direction, delta) in DIRECTIONS.iter().enumerate() {
            let direction = direction as i64;
            let axis = |value: i64| {
                if value < 0 {
                    0
                } else if value > 0 {
                    127
                } else {
                    64
                }
            };
            let point = Vec2i::new(axis(delta.x), axis(delta.y));
            let tile = (point.x * 128 + point.y) as usize;
            let mut text = vec![0u8; 16384];
            let mut data = vec![0u8; things::BASE_SIZE as usize];
            data[0] = 3;
            data[3] = point.x as u8;
            data[4] = point.y as u8;
            data[6] = if delta.x > 0 { 12 } else { 0 };
            data[7] = if delta.y > 0 { 12 } else { 0 };
            data[10] = 42;
            text[tile] = 201;
            assert!(!advance(&mut text, &mut data, 0, direction, 128));
            assert_eq!(data[0], 0, "the ship leaves at a map edge or corner");
            assert_eq!(text[tile], 42, "the saved text marker returns");

            for state in [0u8, 4] {
                data[0] = 3;
                data[1] = direction as u8;
                data[2] = state;
                data[6] = if delta.x > 0 { 12 } else { 0 };
                data[7] = if delta.y > 0 { 12 } else { 0 };
                text[tile] = 201;
                let blank = vec![0u8; 16384];
                let water = vec![4u8; 16384];
                let maps = ShipMaps {
                    buildings: &blank,
                    underground: &blank,
                    flags: &water,
                    map_edge: 128,
                };
                let mut counters = MovingThingResult::default();
                let mut random = sequence_random(&[1]);
                let mut lfsr = sequence_lfsr(&[1]);
                update(&maps, &mut text, &mut data, 0, point, &mut random, &mut lfsr, &mut counters);
                assert!(data[0] == 0 && counters.removed_ships == 1 && counters.moved_ships == 0);
                assert_eq!(text[tile], 42);
            }
        }
    }
}
