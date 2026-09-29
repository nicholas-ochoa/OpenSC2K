//! Maxis Man ticks, as MaxisManThingTick.

use super::motion::{self, DIRECTIONS, direction_quadrant, index};
use super::result::{MovingThingResult, queue_thing_sound, spawn_explosion};
use crate::sim::geom::Vec2i;
use crate::sim::ids::sc2altitude_layout as altitude_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::overlay;
use crate::sim::random::SimRandom;
use crate::sim::things::{self, RECORD_SIZE, TYPE_MAXIS_MAN};

const SOUND_EXPLOSION: i64 = 0x1f8;
const SPEED: i64 = 16;

/// MaxisManThingTick.TargetResult. None is a missing target.
enum Target {
    Point(Vec2i),
    Missing,
    Malformed,
}

/// MaxisManThingTick.update.
#[allow(clippy::too_many_arguments)]
pub fn update(
    altitude: &[u8],
    flags: &[u8],
    text: &mut [u8],
    data: &mut [u8],
    record: i64,
    random: &mut SimRandom,
    counters: &mut MovingThingResult,
    map_edge: i64,
) {
    let offset = record * RECORD_SIZE;
    let mut current = Vec2i::new(things::read(data, offset + 3), things::read(data, offset + 4));
    let current_index = index(current, map_edge);
    let state = things::read(data, offset + 2);
    let goal = things::read(data, offset + 11);

    if current_index < 0 || state > 2 {
        motion::remove(text, data, record, map_edge);
        counters.removed_maxis_men += 1;
        counters.malformed_records += 1;

        return;
    }

    match state {
        0 => {
            let target = match maxis_man_target(text, data, offset, current, goal, map_edge) {
                Target::Point(point) => point,
                missing => {
                    if matches!(missing, Target::Malformed) {
                        counters.malformed_records += 1;
                    }

                    update_height(altitude, flags, data, offset, map_edge);

                    return;
                }
            };
            let direction = direction_quadrant(current, target);
            things::write(data, offset + 1, direction);
            let next = current + DIRECTIONS[direction as usize];
            let next_index = index(next, map_edge);
            let marker = if next_index >= 0 { overlay::read(text, next_index) } else { 0 };

            if marker > 250 && marker <= 255 {
                if random.next_u15() & 1 != 0 {
                    overlay::write(text, next_index, 0);
                    counters.maxis_man_extinguished_fires += 1;
                    move_maxis_man(text, data, record, direction, counters, map_edge);
                }
            } else if overlay::is_thing(marker) {
                let target_record = things::target_record(goal);

                if marker == overlay::thing_id(target_record) && random.next_u15() & 3 == 0 {
                    motion::remove(text, data, target_record, map_edge);
                    counters.maxis_man_destroyed_targets += 1;
                    queue_thing_sound(counters, SOUND_EXPLOSION, data, record);
                    let height = things::read(data, offset + 5);

                    if spawn_explosion(text, data, next, height, 0, 1, map_edge) {
                        counters.maxis_man_explosions += 1;
                    }

                    things::write(data, offset + 2, 2);
                } else {
                    things::write(data, offset + 2, 1);
                }
            } else {
                if !move_maxis_man(text, data, record, direction, counters, map_edge) {
                    return;
                }

                current = Vec2i::new(things::read(data, offset + 3), things::read(data, offset + 4));
                let ahead_index = index(current + DIRECTIONS[direction as usize], map_edge);

                if (ahead_index < 0 || !overlay::blocks_thing(overlay::read(text, ahead_index)))
                    && !move_maxis_man(text, data, record, direction, counters, map_edge)
                {
                    return;
                }
            }
        }
        1 => {
            if random.next_u15() & 3 == 0 {
                things::write(data, offset + 2, 0);
            } else {
                let direction = random.next_u15() & 7;
                // The original checks x twice here.
                let step = DIRECTIONS[direction as usize];
                let bugged_check = Vec2i::new(current.x + step.x, current.x + step.y);
                let check_index = index(bugged_check, map_edge);

                if check_index >= 0
                    && !overlay::blocks_thing(overlay::read(text, check_index))
                    && move_maxis_man(text, data, record, direction, counters, map_edge)
                {
                    things::write(data, offset + 1, direction);
                }
            }
        }
        _ => {
            let direction = things::read(data, offset + 1);

            if !(0..8).contains(&direction) {
                motion::remove(text, data, record, map_edge);
                counters.malformed_records += 1;

                return;
            }

            if !move_maxis_man(text, data, record, direction, counters, map_edge) {
                return;
            }

            if !move_maxis_man(text, data, record, direction, counters, map_edge) {
                return;
            }
        }
    }

    if things::read(data, offset) == TYPE_MAXIS_MAN {
        update_height(altitude, flags, data, offset, map_edge);
    }
}

fn maxis_man_target(text: &[u8], data: &mut [u8], offset: i64, current: Vec2i, goal: i64, map_edge: i64) -> Target {
    if things::is_record_target(goal) {
        if goal < 0 || things::target_record(goal) >= things::count(data) {
            return Target::Malformed;
        }

        let target_offset = things::target_record(goal) * RECORD_SIZE;

        return Target::Point(Vec2i::new(things::read(data, target_offset + 3), things::read(data, target_offset + 4)));
    }

    let is_disaster_marker = |text: &[u8], tile_index: i64| {
        let marker = overlay::read(text, tile_index);
        (241..=255).contains(&marker)
    };
    let target = Vec2i::new(things::read(data, offset + 8), things::read(data, offset + 9));
    let target_index = index(target, map_edge);

    if target_index >= 0 && is_disaster_marker(text, target_index) {
        return Target::Point(target);
    }

    things::write(data, offset + 2, 2);

    for x in current.x - 32..current.x + 33 {
        for y in current.y - 32..current.y + 33 {
            let tile_index = index(Vec2i::new(x, y), map_edge);

            if tile_index >= 0 && is_disaster_marker(text, tile_index) {
                things::write(data, offset + 8, x);
                things::write(data, offset + 9, y);
                things::write(data, offset + 2, 0);

                return Target::Point(Vec2i::new(x, y));
            }
        }
    }

    Target::Missing
}

fn move_maxis_man(
    text: &mut [u8],
    data: &mut [u8],
    record: i64,
    direction: i64,
    counters: &mut MovingThingResult,
    map_edge: i64,
) -> bool {
    if motion::advance(SPEED, text, data, record, direction, map_edge) < 0 {
        counters.removed_maxis_men += 1;

        return false;
    }

    counters.moved_maxis_men += 1;

    true
}

fn update_height(altitude: &[u8], flags: &[u8], data: &mut [u8], offset: i64, map_edge: i64) {
    let goal = things::read(data, offset + 11);

    if things::is_record_target(goal) && goal >= 0 && things::target_record(goal) < things::count(data) {
        let height = things::read(data, things::target_record(goal) * RECORD_SIZE + 5);
        things::write(data, offset + 5, height);

        return;
    }

    let point = Vec2i::new(things::read(data, offset + 3), things::read(data, offset + 4));
    let tile_index = index(point, map_edge);

    if tile_index < 0 {
        return;
    }

    let i = tile_index as usize;
    let word = ((altitude[i * 2] as i64) << 8) | altitude[i * 2 + 1] as i64;
    let mut ground = word & altitude_layout::LEVEL_MASK;

    if flags[i] as i64 & flag_bits::WATER != 0 {
        ground = (word >> altitude_layout::WATER_SHIFT) & altitude_layout::LEVEL_MASK;
    }

    let height = (ground + things::read(data, offset + 2)) & 0xff;
    things::write(data, offset + 5, height);
}
