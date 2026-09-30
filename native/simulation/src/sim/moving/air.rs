//! Airplane and helicopter ticks, as AirThingTick and AirThingMotion.

use super::motion::{self, direction_between, direction_quadrant, index};
use super::result::{MovingThingResult, queue_thing_sound};
use super::ship::turn_one_step;
use crate::sim::bytes;
use crate::sim::geom::Vec2i;
use crate::sim::grid;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::underground_tile_ids as under;
use crate::sim::overlay;
use crate::sim::random::{SimLfsrRandom, SimRandom};
use crate::sim::things::{self, RECORD_SIZE, TYPE_EXPLOSION};

const SOUND_HELICOPTER: i64 = 0x1fe;
const SOUND_AIR_DISASTER: i64 = 0x203;
const SOUND_AIRPLANE_TAKEOFF: i64 = 0x206;
const SOUND_AIRPLANE_LANDING: i64 = 0x207;
const HELICOPTER_SOUND_DELAY_MSEC: i64 = 5000;
const AIRPLANE_SPEED: i64 = 16;
const HELICOPTER_SPEED: i64 = 8;
const AIR_ROUTE_DELTAS: [Vec2i; 8] = [
    Vec2i::new(0, -3),
    Vec2i::new(3, -3),
    Vec2i::new(3, 0),
    Vec2i::new(3, 3),
    Vec2i::new(0, 3),
    Vec2i::new(-3, 3),
    Vec2i::new(-3, 0),
    Vec2i::new(-3, -3),
];
const AIR_DIRECTION_OFFSETS: [i64; 7] = [1, 7, 2, 6, 3, 5, 4];
/// Final supplied smallmed.dat metadata heights for sprite IDs 0x71 through 0xfa.
const BUILDING_SPRITE_HEIGHTS_FIRST: i64 = 0x71;
const BUILDING_SPRITE_HEIGHTS: [i64; 138] = [
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 6, 8, 7, 6, 6, 8, 12, 7, 9, 5, 8, 6, 7, 5, 5, 5, 5, 10, 11, 11, 11, 16, 14, 20, 20, 9, 11, 11, 12, 12,
    14, 19, 17, 19, 22, 11, 11, 11, 10, 10, 14, 15, 16, 10, 12, 12, 17, 14, 15, 18, 19, 18, 23, 15, 24, 16, 22, 17, 24, 16, 30, 35, 20, 28,
    38, 13, 24, 15, 15, 15, 13, 21, 17, 18, 24, 9, 9, 11, 23, 29, 21, 20, 24, 18, 28, 18, 21, 19, 17, 15, 14, 15, 22, 19, 23, 17, 13, 5, 5,
    5, 6, 11, 16, 18, 5, 6, 6, 5, 5, 6, 6, 5, 17, 10, 11, 10, 10, 10, 14, 9, 10, 10, 14, 10, 13, 14, 13, 16,
];

#[inline]
fn field(data: &[u8], offset: i64, field: i64) -> i64 {
    things::read(data, offset + field)
}

fn remove_without_crash(text: &mut [u8], data: &mut [u8], record: i64, map_edge: i64) {
    let offset = record * RECORD_SIZE;
    let point = Vec2i::new(field(data, offset, 3), field(data, offset, 4));
    let tile_index = index(point, map_edge);

    if tile_index >= 0 && overlay::read(text, tile_index) == overlay::thing_id(record) {
        let label = field(data, offset, 10);
        overlay::lift_object(text, data, record, tile_index, label);
    }

    things::write(data, offset, 0);
}

fn convert_to_explosion(data: &mut [u8], record: i64, state: i64, goal: i64) {
    let offset = record * RECORD_SIZE;
    things::write(data, offset, TYPE_EXPLOSION);
    things::write(data, offset + 1, 0);
    things::write(data, offset + 2, state);
    things::write(data, offset + 11, goal);
}

fn advance_air_direction(buildings: &[u8], data: &mut [u8], record: i64, map_edge: i64) {
    let offset = record * RECORD_SIZE;
    let mut direction = field(data, offset, 1) & 7;
    let current = Vec2i::new(field(data, offset, 3), field(data, offset, 4));

    if !air_route_blocked(buildings, current, direction, map_edge) {
        return;
    }

    for direction_offset in AIR_DIRECTION_OFFSETS {
        direction = (field(data, offset, 1) + direction_offset) & 7;

        if !air_route_blocked(buildings, current, direction, map_edge) {
            break;
        }
    }

    things::write(data, offset + 1, direction);
}

fn air_route_blocked(buildings: &[u8], current: Vec2i, direction: i64, map_edge: i64) -> bool {
    let checked_index = index(current + AIR_ROUTE_DELTAS[direction as usize], map_edge);

    checked_index >= 0 && buildings[checked_index as usize] as i64 >= tiles::PLYMOUTH_ARCOLOGY
}

/// AirThingMotion._random_direction_step.
pub fn random_direction_step(direction: i64, divisor: i64, random: &mut SimRandom) -> i64 {
    if random.next_u15() % divisor == 0 {
        return (direction + random.next_u15() % 3 - 1) & 7;
    }

    direction
}

fn steer_direction(direction: i64, start: Vec2i, target: Vec2i) -> i64 {
    let desired = direction_between(start, target);

    if desired == direction {
        direction
    } else {
        turn_one_step(direction, desired)
    }
}

fn thing_distance(start: Vec2i, target: Vec2i) -> i64 {
    (target.x - start.x).abs() + (target.y - start.y).abs()
}

/// AirThingTick.update_airplane.
#[allow(clippy::too_many_arguments)]
pub fn update_airplane(
    buildings: &[u8],
    zones: &[u8],
    text: &mut [u8],
    data: &mut [u8],
    record: i64,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    counters: &mut MovingThingResult,
    map_edge: i64,
    no_disasters: bool,
    no_accidents: bool,
) {
    let offset = record * RECORD_SIZE;
    let mut current = Vec2i::new(field(data, offset, 3), field(data, offset, 4));
    let current_index = index(current, map_edge);
    let mut direction = field(data, offset, 1);

    if current_index < 0 || !(0..8).contains(&direction) {
        motion::remove(text, data, record, map_edge);
        counters.removed_airplanes += 1;
        counters.malformed_records += 1;

        return;
    }

    let building = buildings[current_index as usize] as i64;

    // no_accidents blocks spontaneous collisions and landings. A plane already
    // falling from a disaster (state 7) still follows no_disasters.
    if !no_disasters && !no_accidents && building > tiles::DEVELOPED_FIRST && zones[current_index as usize] as i64 & zone::TYPE_MASK != 8 {
        if building > tiles::DESALINIZATION {
            let goal = if lfsr.next_mod(16) == 0 { 1 } else { 0 };
            convert_to_explosion(data, record, 5, goal);
            counters.crashed_airplanes += 1;

            return;
        }

        // Building artwork height is part of aircraft physics.
        let sprite_height = BUILDING_SPRITE_HEIGHTS[(building - BUILDING_SPRITE_HEIGHTS_FIRST) as usize];

        if field(data, offset, 5) < sprite_height / 3 {
            convert_to_explosion(data, record, 5, 1);
            counters.crashed_airplanes += 1;

            return;
        }
    }

    let state = field(data, offset, 2) & 0x0f;

    if no_disasters && state == 7 {
        remove_without_crash(text, data, record, map_edge);
        counters.removed_airplanes += 1;

        return;
    }

    match state {
        0 => {
            if motion::advance(AIRPLANE_SPEED, text, data, record, direction, map_edge) < 0 {
                counters.removed_airplanes += 1;

                return;
            }

            counters.moved_airplanes += 1;

            if field(data, offset, 5) == 0 {
                queue_thing_sound(counters, SOUND_AIRPLANE_TAKEOFF, data, record);
            }

            if field(data, offset, 5) < 14 {
                let height = field(data, offset, 5) + 1;
                things::write(data, offset + 5, height);
            } else {
                things::write(data, offset + 2, 2);
            }
        }
        1 => {
            if motion::advance(AIRPLANE_SPEED, text, data, record, direction, map_edge) < 0 {
                counters.removed_airplanes += 1;

                return;
            }

            counters.moved_airplanes += 1;
            let height = (field(data, offset, 5) - 1) & 0xff;
            things::write(data, offset + 5, height);

            if field(data, offset, 5) == 0 {
                queue_thing_sound(counters, SOUND_AIRPLANE_LANDING, data, record);
                current = Vec2i::new(field(data, offset, 3), field(data, offset, 4));
                let landing_index = index(current, map_edge);

                if landing_index >= 0 {
                    let label = field(data, offset, 10);
                    overlay::lift_object(text, data, record, landing_index, label);
                }

                if landing_index < 0 || buildings[landing_index as usize] as i64 != tiles::RUNWAY {
                    if no_disasters || no_accidents {
                        remove_without_crash(text, data, record, map_edge);
                        counters.removed_airplanes += 1;

                        return;
                    }

                    convert_to_explosion(data, record, 5, 1);
                    counters.crashed_airplanes += 1;
                } else {
                    motion::remove(text, data, record, map_edge);
                    counters.removed_airplanes += 1;
                    counters.landed_airplanes += 1;
                }
            }
        }
        2 => {
            direction = random_direction_step(direction, 5, random);
            things::write(data, offset + 1, direction);
            advance_air_direction(buildings, data, record, map_edge);
            direction = field(data, offset, 1);

            if motion::advance(AIRPLANE_SPEED, text, data, record, direction, map_edge) < 0 {
                counters.removed_airplanes += 1;

                return;
            }

            counters.moved_airplanes += 1;
        }
        3 => {
            let target = Vec2i::new(field(data, offset, 8), field(data, offset, 9));
            let planned_direction = direction_quadrant(current, target);
            things::write(data, offset + 1, planned_direction);
            advance_air_direction(buildings, data, record, map_edge);
            direction = field(data, offset, 1);

            if motion::advance(AIRPLANE_SPEED, text, data, record, direction, map_edge) < 0 {
                counters.removed_airplanes += 1;

                return;
            }

            counters.moved_airplanes += 1;
            current = Vec2i::new(field(data, offset, 3), field(data, offset, 4));

            if thing_distance(current, target) < 2 {
                let runway_axis = field(data, offset, 2) >> 4;
                things::write(data, offset + 1, turn_one_step(planned_direction, runway_axis));
                things::write(data, offset + 2, runway_axis * 0x10 + 4);
                adjust_airplane_target(data, offset, runway_axis);
            }
        }
        4 => {
            let target = Vec2i::new(field(data, offset, 8), field(data, offset, 9));
            direction = steer_direction(direction, current, target);
            things::write(data, offset + 1, direction);

            if motion::advance(AIRPLANE_SPEED, text, data, record, direction, map_edge) < 0 {
                counters.removed_airplanes += 1;

                return;
            }

            counters.moved_airplanes += 1;
            current = Vec2i::new(field(data, offset, 3), field(data, offset, 4));

            if thing_distance(current, target) < 2 {
                let runway_axis = field(data, offset, 2) >> 4;
                things::write(data, offset + 1, runway_axis);
                things::write(data, offset + 2, 1);

                match runway_axis {
                    1 | 5 => {
                        let x = field(data, offset, 8);
                        things::write(data, offset + 3, x);
                    }
                    3 | 7 => {
                        let y = field(data, offset, 9);
                        things::write(data, offset + 4, y);
                    }
                    _ => {}
                }
            }
        }
        7 => {
            if field(data, offset, 5) != 0 {
                let height = field(data, offset, 5) - 1;
                things::write(data, offset + 5, height);

                if field(data, offset, 5) == 8 {
                    queue_thing_sound(counters, SOUND_AIR_DISASTER, data, record);
                }

                let old_direction = direction;
                things::write(data, offset + 1, (direction + 1) & 7);

                if motion::advance(AIRPLANE_SPEED, text, data, record, old_direction, map_edge) < 0 {
                    counters.removed_airplanes += 1;

                    return;
                }

                counters.moved_airplanes += 1;
            } else {
                convert_to_explosion(data, record, 5, 1);
                counters.crashed_airplanes += 1;
            }
        }
        _ => {}
    }
}

fn adjust_airplane_target(data: &mut [u8], offset: i64, runway_axis: i64) {
    match runway_axis {
        1 => {
            let value = field(data, offset, 9) - 6;
            things::write(data, offset + 9, value);
        }
        3 => {
            let value = field(data, offset, 8) + 6;
            things::write(data, offset + 8, value);
        }
        5 => {
            let value = field(data, offset, 9) + 6;
            things::write(data, offset + 9, value);
        }
        7 => {
            let value = field(data, offset, 8) - 6;
            things::write(data, offset + 8, value);
        }
        _ => {}
    }
}

/// The maps that a helicopter reads.
pub struct HelicopterMaps<'a> {
    pub buildings: &'a [u8],
    pub underground: &'a [u8],
    pub traffic: &'a [u8],
    pub map_edge: i64,
}

/// AirThingTick.update_helicopter.
#[allow(clippy::too_many_arguments)]
pub fn update_helicopter(
    maps: &HelicopterMaps,
    text: &mut [u8],
    data: &mut [u8],
    record: i64,
    city_center: Vec2i,
    random: &mut SimRandom,
    counters: &mut MovingThingResult,
    no_disasters: bool,
    no_accidents: bool,
) {
    let edge = maps.map_edge;
    let offset = record * RECORD_SIZE;
    let mut current = Vec2i::new(field(data, offset, 3), field(data, offset, 4));
    let current_index = index(current, edge);
    let mut direction = field(data, offset, 1);

    if current_index < 0 || !(0..8).contains(&direction) {
        motion::remove(text, data, record, edge);
        counters.removed_helicopters += 1;
        counters.malformed_records += 1;

        return;
    }

    if no_disasters && field(data, offset, 2) == 5 {
        remove_without_crash(text, data, record, edge);
        counters.removed_helicopters += 1;

        return;
    }

    if !no_disasters && !no_accidents && maps.buildings[current_index as usize] as i64 > tiles::DESALINIZATION {
        convert_to_explosion(data, record, 5, 0);
        counters.crashed_helicopters += 1;

        return;
    }

    match field(data, offset, 2) {
        0 => {
            things::write(data, offset + 1, (direction + 1) & 7);

            if field(data, offset, 5) < 10 {
                let height = field(data, offset, 5) + 1;
                things::write(data, offset + 5, height);
            } else {
                things::write(data, offset + 2, 2);
            }
        }
        2 => {
            let target = Vec2i::new(field(data, offset, 8), field(data, offset, 9));
            direction = steer_direction(direction, current, target);
            things::write(data, offset + 1, direction);
            advance_air_direction(maps.buildings, data, record, edge);
            direction = field(data, offset, 1);

            if motion::advance(HELICOPTER_SPEED, text, data, record, direction, edge) < 0 {
                counters.removed_helicopters += 1;

                return;
            }

            counters.moved_helicopters += 1;
            current = Vec2i::new(field(data, offset, 3), field(data, offset, 4));
            let traffic_index = grid::index(maps.traffic, edge, current.x, current.y);

            if bytes::at(maps.traffic, traffic_index) > 0xa9 {
                counters.traffic_news_checks += 1;

                if counters.traffic_news_deadline_msec < counters.traffic_news_time_msec {
                    counters.traffic_news_deadline_msec = counters.traffic_news_time_msec + HELICOPTER_SOUND_DELAY_MSEC;
                    queue_thing_sound(counters, SOUND_HELICOPTER, data, record);
                }
            }

            if thing_distance(current, target) < 2 {
                let mut target_x = (random.next_u15() & 0x3f) - 0x20 + city_center.x;
                let mut target_y = (random.next_u15() & 0x3f) - 0x20 + city_center.y;

                if target_x < 0 || target_x >= edge {
                    target_x = random.next_u15() % (edge / 2) + edge / 4;
                }

                if target_y < 0 || target_y >= edge {
                    target_y = random.next_u15() % (edge / 2) + edge / 4;
                }

                things::write(data, offset + 8, target_x);
                things::write(data, offset + 9, target_y);
                let current_at = bytes::at(maps.buildings, index(current, edge));

                if random.next_u15() & 1 != 0
                    && current_at == tiles::EMPTY
                    && bytes::at(maps.underground, index(current, edge)) == under::EMPTY
                {
                    things::write(data, offset + 2, 3);
                }
            }
        }
        3 => {
            things::write(data, offset + 1, (direction + 1) & 7);

            if field(data, offset, 5) > 2 {
                let height = field(data, offset, 5) - 1;
                things::write(data, offset + 5, height);
            } else {
                things::write(data, offset + 2, 4);
            }
        }
        4 => {
            if random.next_u15() % 20 == 0 {
                things::write(data, offset + 2, 0);
            }
        }
        5 => {
            things::write(data, offset + 1, (direction + 2) & 7);

            if field(data, offset, 5) == 4 {
                queue_thing_sound(counters, SOUND_AIR_DISASTER, data, record);
            }

            if field(data, offset, 5) > 2 {
                let height = field(data, offset, 5) - 1;
                things::write(data, offset + 5, height);
            } else {
                convert_to_explosion(data, record, 0x11, 1);
                counters.crashed_helicopters += 1;
            }
        }
        _ => {}
    }
}
