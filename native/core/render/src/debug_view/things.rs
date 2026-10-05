//! The moving things of the thing path view: the record, type, tile and
//! target tile of each XTHG record inside a tile window.

use super::geometry::TileWindow;

/// XTHG record bytes in the low plane.
const RECORD_SIZE: usize = 12;
/// The original table has one plane. Larger and smaller tables keep a high
/// plane after the low plane.
const ORIGINAL_SIZE: usize = RECORD_SIZE * 40;
const FIELD_TYPE: usize = 0;
const FIELD_X: usize = 3;
const FIELD_Y: usize = 4;
const FIELD_DX: usize = 8;
const FIELD_DY: usize = 9;
/// Values in each returned row.
pub const ROW: usize = 6;

/// Rows of `record, type, x, y, dx, dy` for the records whose tile is inside
/// `window`. Record zero is unused, and an empty type is no thing.
pub fn rows(data: &[u8], window: TileWindow) -> Vec<i32> {
    let wide = data.len() != ORIGINAL_SIZE;
    let count = data.len() / if wide { RECORD_SIZE * 2 } else { RECORD_SIZE };
    let high = data.len() / 2;
    let mut result = Vec::new();

    for record in 1..count {
        let offset = record * RECORD_SIZE;
        let kind = data[offset + FIELD_TYPE];

        if kind == 0 {
            continue;
        }

        // coordinates are wide fields of every type
        let field = |at: usize| i32::from(data[offset + at]) | if wide { i32::from(data[high + offset + at]) << 8 } else { 0 };
        let (x, y) = (field(FIELD_X), field(FIELD_Y));

        if x < window.x0 as i32 || y < window.y0 as i32 || x >= window.x1 as i32 || y >= window.y1 as i32 {
            continue;
        }

        result.extend([record as i32, i32::from(kind), x, y, field(FIELD_DX), field(FIELD_DY)]);
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    fn record(data: &mut [u8], record: usize, kind: u8, x: u16, y: u16) {
        let high = data.len() / 2;
        let offset = record * RECORD_SIZE;
        data[offset] = kind;
        data[offset + FIELD_X] = x as u8;
        data[offset + FIELD_Y] = y as u8;
        data[high + offset + FIELD_X] = (x >> 8) as u8;
        data[high + offset + FIELD_Y] = (y >> 8) as u8;
    }

    #[test]
    fn wide_tables_read_both_planes_and_skip_empty_records() {
        let mut data = vec![0_u8; RECORD_SIZE * 2 * 4];
        record(&mut data, 1, 2, 300, 5);
        record(&mut data, 3, 3, 10, 12);
        let rows = rows(&data, TileWindow::clipped(0, 0, 400, 400, 400));

        assert_eq!(rows.len(), ROW * 2);
        assert_eq!(&rows[..4], &[1, 2, 300, 5]);
        assert_eq!(&rows[ROW..ROW + 4], &[3, 3, 10, 12]);
    }

    #[test]
    fn records_outside_the_window_are_left_out() {
        let mut data = vec![0_u8; RECORD_SIZE * 2 * 4];
        record(&mut data, 1, 2, 300, 5);
        record(&mut data, 2, 2, 10, 12);

        assert_eq!(rows(&data, TileWindow::clipped(0, 0, 100, 100, 400)), vec![2, 2, 10, 12, 0, 0]);
    }

    #[test]
    fn the_original_table_has_one_plane() {
        let mut data = vec![0_u8; ORIGINAL_SIZE];
        data[RECORD_SIZE] = 1;
        data[RECORD_SIZE + FIELD_X] = 7;
        data[RECORD_SIZE + FIELD_DX] = 9;

        assert_eq!(rows(&data, TileWindow::clipped(0, 0, 128, 128, 128)), vec![1, 1, 7, 0, 9, 0]);
    }
}
