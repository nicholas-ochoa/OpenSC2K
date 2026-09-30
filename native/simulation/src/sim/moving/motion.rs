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
        overlay::lift_object(text, data, record, position, 0);
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

    let label = things::read(data, offset + FIELD_LABEL);
    overlay::lift_object(text, data, record, current_index, label);
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
    overlay::push_object(text, data, record, next_index);

    1
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::overlay;
    use crate::sim::things;

    fn prepare(text: &mut [u8], data: &mut [u8], record: i64, point: Vec2i, edge: i64) {
        for (field, value) in [(0, 1), (3, point.x), (4, point.y), (6, 8), (7, 8), (10, 51)] {
            things::write(data, record * RECORD_SIZE + field, value);
        }

        overlay::write(text, point.x * edge + point.y, overlay::thing_id(record));
    }

    /// A layered index: the object leaves the facility and the marker of its
    /// tiles in place, and a covered object leaves without breaking the stack.
    #[test]
    fn a_layered_object_moves_without_changing_other_layers() {
        let edge = 128i64;
        let record = 30;
        let offset = record * RECORD_SIZE;
        let origin = Vec2i::new(10, 10);
        let next = origin + DIRECTIONS[2];
        let (from, to) = (origin.x * edge + origin.y, next.x * edge + next.y);
        let mut text = overlay::layered(edge * edge);
        let mut data = vec![0u8; 512 * 24];
        let facility = overlay::facility_id(700);
        overlay::write(&mut text, from, facility);
        overlay::write(&mut text, to, facility);

        for (field, value) in [(0, 1), (3, origin.x), (4, origin.y), (6, 8), (7, 8)] {
            things::write(&mut data, offset + field, value);
        }

        overlay::push_object(&mut text, &mut data, record, from);
        assert_eq!(things::read(&data, offset + 10), 0, "an object covers no other object");
        // a fire starts under the object
        overlay::set_marker_at(&mut text, from, 0xff);
        assert_eq!(advance(16, &mut text, &mut data, record, 2, edge), 1);
        assert_eq!(
            (
                overlay::object(&text, from),
                overlay::marker(&text, from),
                overlay::facility(&text, from)
            ),
            (0, 0xff, facility)
        );
        assert_eq!(
            (overlay::object(&text, to), overlay::facility(&text, to)),
            (overlay::thing_id(record), facility)
        );

        // a second object covers the first; the first leaves from under it
        let top = 31;
        for (field, value) in [(0, 1), (3, next.x), (4, next.y)] {
            things::write(&mut data, top * RECORD_SIZE + field, value);
        }

        overlay::push_object(&mut text, &mut data, top, to);
        assert_eq!(things::read(&data, top * RECORD_SIZE + 10), overlay::thing_id(record));
        remove(&mut text, &mut data, record, edge);
        assert_eq!(overlay::object(&text, to), overlay::thing_id(top));
        assert_eq!(
            things::read(&data, top * RECORD_SIZE + 10),
            0,
            "the stack closes over the removed object"
        );
        remove(&mut text, &mut data, top, edge);
        assert_eq!(overlay::read(&text, to), facility, "only the facility stays");
    }

    #[test]
    fn directions_point_at_targets() {
        for (direction, step) in DIRECTIONS.iter().enumerate() {
            let target = Vec2i::new(step.x * 9, step.y * 9);
            assert_eq!(direction_between(Vec2i::ZERO, target), direction as i64);
            assert_eq!(direction_quadrant(Vec2i::ZERO, target), direction as i64);
        }

        assert_eq!(direction_between(Vec2i::ZERO, Vec2i::ZERO), 3);
        assert_eq!(direction_quadrant(Vec2i::ZERO, Vec2i::ZERO), 4);
        assert_eq!(direction_between(Vec2i::ZERO, Vec2i::new(1, 3)), 4);
        assert_eq!(direction_quadrant(Vec2i::ZERO, Vec2i::new(1, 3)), 3);
    }

    #[test]
    fn records_move_between_tiles_in_both_formats() {
        for edge in [128i64, 256] {
            let record = if edge == 128 { 1 } else { 241 };
            let text_size = (edge * edge * if edge == 128 { 1 } else { 2 }) as usize;
            let thing_size = if edge == 128 { 480 } else { 512 * 24 };
            let origin = if edge == 128 { Vec2i::new(10, 10) } else { Vec2i::new(200, 200) };
            let offset = record * RECORD_SIZE;

            for (direction, step) in DIRECTIONS.iter().enumerate() {
                let mut text = vec![0u8; text_size];
                let mut data = vec![0u8; thing_size];
                prepare(&mut text, &mut data, record, origin, edge);
                let next = origin + *step;
                overlay::write(&mut text, next.x * edge + next.y, 77);
                assert_eq!(advance(16, &mut text, &mut data, record, direction as i64, edge), 1);
                assert_eq!((things::read(&data, offset + 3), things::read(&data, offset + 4)), (next.x, next.y));
                assert_eq!(overlay::read(&text, origin.x * edge + origin.y), 51, "old overlay restored");
                assert_eq!(overlay::read(&text, next.x * edge + next.y), overlay::thing_id(record));
                assert_eq!(things::read(&data, offset + 10), 77, "new underlay saved");
            }

            let mut text = vec![0u8; text_size];
            let mut data = vec![0u8; thing_size];
            prepare(&mut text, &mut data, record, origin, edge);

            for step in [1, 2] {
                overlay::write(&mut text, (origin.x + step) * edge + origin.y, 251);
            }

            assert_eq!(advance(16, &mut text, &mut data, record, 2, edge), 1, "blocked tiles skipped");
            assert_eq!(things::read(&data, offset + 3), origin.x + 3);
            assert_eq!(
                overlay::read(&text, (origin.x + 1) * edge + origin.y),
                251,
                "blocked overlay retained"
            );

            let mut text = vec![0u8; text_size];
            let mut data = vec![0u8; thing_size];
            prepare(&mut text, &mut data, record, Vec2i::ZERO, edge);
            assert_eq!(advance(16, &mut text, &mut data, record, 7, edge), -1, "map exit");
            assert!(
                things::read(&data, offset) == 0 && overlay::read(&text, 0) == 0,
                "exit removes record"
            );

            let mut text = vec![0u8; text_size];
            let mut data = vec![0u8; thing_size];
            prepare(&mut text, &mut data, record, origin, edge);
            things::write(&mut data, offset + 6, 0);
            assert_eq!(advance(16, &mut text, &mut data, record, 2, edge), 0, "subtile limit stays on tile");
            assert_eq!(things::read(&data, offset + 6), 16);
        }
    }
}
