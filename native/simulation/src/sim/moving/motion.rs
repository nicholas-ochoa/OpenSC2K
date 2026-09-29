//! Moving-thing motion over sub-tile positions, as MovingThingMotion.

use crate::sim::geom::Vec2i;
use crate::sim::overlay;
use crate::sim::things::{self, FIELD_LABEL, FIELD_PX, FIELD_PY, FIELD_TYPE, FIELD_X, FIELD_Y, RECORD_SIZE, TYPE_NONE};

pub const SUBTILE_LIMIT: i64 = 16;
pub const DIRECTIONS: [Vec2i; 8] = [
    Vec2i::new(0, -1),
    Vec2i::new(1, -1),
    Vec2i::new(1, 0),
    Vec2i::new(1, 1),
    Vec2i::new(0, 1),
    Vec2i::new(-1, 1),
    Vec2i::new(-1, 0),
    Vec2i::new(-1, -1),
];

pub fn direction_between(start: Vec2i, target: Vec2i) -> i64 {
    let difference = target - start;
    let absolute_x = difference.x.abs();
    let absolute_y = difference.y.abs();

    if absolute_x < (absolute_y + 1) / 2 {
        return if difference.y < 0 { 0 } else { 4 };
    }

    if absolute_y < (absolute_x + 1) / 2 {
        return if difference.x < 0 { 6 } else { 2 };
    }

    if difference.x < 0 {
        return if difference.y < 0 { 7 } else { 5 };
    }

    if difference.y < 0 { 1 } else { 3 }
}

pub fn direction_quadrant(start: Vec2i, target: Vec2i) -> i64 {
    let difference = target - start;

    if difference.x < 0 {
        if difference.y < 0 {
            return 7;
        }

        return if difference.y == 0 { 6 } else { 5 };
    }

    if difference.x == 0 {
        return if difference.y < 0 { 0 } else { 4 };
    }

    if difference.y < 0 {
        return 1;
    }

    if difference.y == 0 { 2 } else { 3 }
}

#[inline]
pub fn index(point: Vec2i, map_edge: i64) -> i64 {
    if point.x < 0 || point.x >= map_edge || point.y < 0 || point.y >= map_edge {
        return -1;
    }

    point.x * map_edge + point.y
}

pub fn remove(text: &mut [u8], data: &mut [u8], record: i64, map_edge: i64) {
    let offset = record * RECORD_SIZE;
    things::write(data, offset + FIELD_TYPE, TYPE_NONE);
    let point = Vec2i::new(things::read(data, offset + FIELD_X), things::read(data, offset + FIELD_Y));
    let position = index(point, map_edge);

    if position >= 0 {
        overlay::write(text, position, 0);
    }
}

/// Move a record. Returns -1 when it left the map, 0 inside its tile, and 1
/// after it entered a new tile.
pub fn advance(speed: i64, text: &mut [u8], data: &mut [u8], record: i64, direction: i64, map_edge: i64) -> i64 {
    if speed < 0 || direction < 0 || direction >= DIRECTIONS.len() as i64 {
        remove(text, data, record, map_edge);

        return -1;
    }

    let offset = record * RECORD_SIZE;
    let step = DIRECTIONS[direction as usize];
    let mut subtile_x = things::read(data, offset + FIELD_PX) + step.x * speed;
    let mut subtile_y = things::read(data, offset + FIELD_PY) + step.y * speed;
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

    things::write(data, offset + FIELD_PX, subtile_x);
    things::write(data, offset + FIELD_PY, subtile_y);

    if tile_delta == Vec2i::ZERO {
        return 0;
    }

    let current = Vec2i::new(things::read(data, offset + FIELD_X), things::read(data, offset + FIELD_Y));
    let current_index = index(current, map_edge);

    if current_index < 0 {
        remove(text, data, record, map_edge);

        return -1;
    }

    overlay::write(text, current_index, things::read(data, offset + FIELD_LABEL));
    let mut next = current + tile_delta;
    let mut next_index = index(next, map_edge);

    while next_index >= 0 && overlay::blocks_thing(overlay::read(text, next_index)) {
        things::write(data, offset + FIELD_X, next.x);
        things::write(data, offset + FIELD_Y, next.y);
        next = next + tile_delta;
        next_index = index(next, map_edge);
    }

    if next_index < 0 {
        remove(text, data, record, map_edge);

        return -1;
    }

    things::write(data, offset + FIELD_X, next.x);
    things::write(data, offset + FIELD_Y, next.y);
    things::write(data, offset + FIELD_LABEL, overlay::read(text, next_index));
    overlay::write(text, next_index, overlay::thing_id(record));

    1
}
