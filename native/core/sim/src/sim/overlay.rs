//! XTXT links, as OverlayData. Original IDs are unchanged. SC2X v2 adds
//! disjoint 16-bit ID ranges in a second byte plane.
//!
//! A layered tile index keeps each kind of tile content in its own planes:
//! the marker byte, the facility ID (low and high plane), and the ID of the top
//! moving object (low and high plane). A facility, a marker, and a moving
//! object can share one tile. `read` gives the value that a combined index
//! would show on top: the object, else the marker, else the facility. `write`
//! changes the layer of the value; zero clears the top layer. Code that must
//! keep the other layers uses the layer functions.

use super::ids::sc2microsim_layout;
use super::ids::sc2overlay_layout as layout;
use super::ids::sc2thing_layout;

pub const EXTRA_FACILITY: i64 = layout::EXTRA_FACILITY;
pub const EXTRA_SIGN: i64 = layout::EXTRA_SIGN;
pub const EXTRA_THING: i64 = layout::EXTRA_THING;
/// Facility records past the 3,990 of the extra range. Only the 2048 and 4096
/// tile maps of SC2X version 4 reach them. Moving objects end below this ID.
pub const EXTRA_FACILITY_HIGH: i64 = 16384;
pub const HIGH_FACILITY_FIRST_RECORD: i64 = sc2microsim_layout::ORIGINAL_COUNT + EXTRA_SIGN - EXTRA_FACILITY;

/// Planes of a layered tile index.
pub const LAYERED_PLANES: i64 = 5;
const FACILITY_PLANE: i64 = 1;
const OBJECT_PLANE: i64 = 3;

/// A wide map stores a low and a high plane, so its cell count is half its bytes.
/// A layered index has five planes. No square narrow plane of a supported map
/// size has one of these sizes.
#[inline]
pub fn cells_for(byte_count: i64) -> i64 {
    match byte_count {
        512 | 2048 | 8192 | 32768 | 131072 | 294912 | 524288 | 819200 | 2097152 | 8388608 | 33554432 => byte_count / 2,
        1280 | 5120 | 20480 | 81920 | 327680 | 737280 | 1310720 | 2048000 | 5242880 | 20971520 | 83886080 => byte_count / LAYERED_PLANES,
        _ => byte_count,
    }
}

#[inline]
pub fn is_layered(data: &[u8]) -> bool {
    let cells = count(data);

    cells != data.len() as i64 && cells * LAYERED_PLANES == data.len() as i64
}

/// An empty layered index of `cells` tiles.
pub fn layered(cells: i64) -> Vec<u8> {
    vec![0; (cells * LAYERED_PLANES) as usize]
}

#[inline]
fn wide_at(data: &[u8], plane: i64, index: i64) -> i64 {
    let cells = data.len() as i64 / LAYERED_PLANES;

    data[(plane * cells + index) as usize] as i64 | ((data[((plane + 1) * cells + index) as usize] as i64) << 8)
}

#[inline]
fn set_wide_at(data: &mut [u8], plane: i64, index: i64, value: i64) {
    let cells = data.len() as i64 / LAYERED_PLANES;
    data[(plane * cells + index) as usize] = value as u8;
    data[((plane + 1) * cells + index) as usize] = (value >> 8) as u8;
}

/// The marker byte of a layered index.
#[inline]
pub fn marker(data: &[u8], index: i64) -> i64 {
    data[index as usize] as i64
}

#[inline]
pub fn set_marker(data: &mut [u8], index: i64, value: i64) {
    data[index as usize] = value as u8;
}

/// The facility ID of a layered index, or 0.
#[inline]
pub fn facility(data: &[u8], index: i64) -> i64 {
    wide_at(data, FACILITY_PLANE, index)
}

#[inline]
pub fn set_facility(data: &mut [u8], index: i64, id: i64) {
    set_wide_at(data, FACILITY_PLANE, index, id);
}

/// The ID of the top moving object of a layered index, or 0.
#[inline]
pub fn object(data: &[u8], index: i64) -> i64 {
    wide_at(data, OBJECT_PLANE, index)
}

#[inline]
pub fn set_object(data: &mut [u8], index: i64, id: i64) {
    set_wide_at(data, OBJECT_PLANE, index, id);
}

/// The marker of a tile: the marker layer of a layered index, else the value
/// of a combined index.
#[inline]
pub fn marker_at(data: &[u8], index: i64) -> i64 {
    if is_layered(data) { marker(data, index) } else { read(data, index) }
}

/// Set or clear the marker of a tile. A combined index writes the value.
#[inline]
pub fn set_marker_at(data: &mut [u8], index: i64, value: i64) {
    if is_layered(data) {
        set_marker(data, index, value);
    } else {
        write(data, index, value);
    }
}

/// The facility layer of a layered index, else the value of a combined index.
/// The caller checks `is_facility`.
#[inline]
pub fn facility_at(data: &[u8], index: i64) -> i64 {
    if is_layered(data) {
        facility(data, index)
    } else {
        read(data, index)
    }
}

/// What a moving object covers when it arrives on tile `index`: the value of
/// a combined index, or the top object of a layered index. The object keeps it
/// in its label field.
#[inline]
pub fn covered(data: &[u8], index: i64) -> i64 {
    if is_layered(data) { object(data, index) } else { read(data, index) }
}

/// Put moving object `record` on top of tile `index`.
pub fn push_object(text: &mut [u8], things_data: &mut [u8], record: i64, index: i64) {
    let below = covered(text, index);
    super::things::write(
        things_data,
        record * sc2thing_layout::RECORD_SIZE + sc2thing_layout::FIELD_LABEL,
        below,
    );
    write(text, index, thing_id(record));
}

/// Take moving object `record` off tile `index`. A combined index gets
/// `legacy`: the label field that the object kept, or zero. A layered index
/// shows the object below it again, and its other layers stay unchanged.
pub fn lift_object(text: &mut [u8], things_data: &mut [u8], record: i64, index: i64, legacy: i64) {
    if !is_layered(text) {
        write(text, index, legacy);

        return;
    }

    let id = thing_id(record);
    let records = super::things::count(things_data);
    let label = |data: &[u8], record: i64| super::things::field(data, record, sc2thing_layout::FIELD_LABEL);
    let own = label(things_data, record);
    let below = if is_thing(own) && own != id { own } else { 0 };
    let mut above = object(text, index);

    if above == id {
        set_object(text, index, below);

        return;
    }

    // an object that another object covers leaves the chain of its tile
    for _ in 0..records {
        let above_record = thing_record(above);

        if !is_thing(above) || above_record < 0 || above_record >= records {
            return;
        }

        if label(things_data, above_record) == id {
            super::things::write(
                things_data,
                above_record * sc2thing_layout::RECORD_SIZE + sc2thing_layout::FIELD_LABEL,
                below,
            );

            return;
        }

        above = label(things_data, above_record);
    }
}

/// Put object `new_id` in the place of object `old_id` in the object chain of
/// tile `index`. Only a layered index keeps object IDs in a chain, so a
/// combined index stays unchanged.
pub fn replace_object(text: &mut [u8], things_data: &mut [u8], index: i64, old_id: i64, new_id: i64) {
    if !is_layered(text) {
        return;
    }

    let mut above = object(text, index);

    if above == old_id {
        set_object(text, index, new_id);

        return;
    }

    let records = super::things::count(things_data);

    for _ in 0..records {
        let above_record = thing_record(above);

        if !is_thing(above) || above_record < 0 || above_record >= records {
            return;
        }

        let label_offset = above_record * sc2thing_layout::RECORD_SIZE + sc2thing_layout::FIELD_LABEL;
        let below = super::things::read(things_data, label_offset);

        if below == old_id {
            super::things::write(things_data, label_offset, new_id);

            return;
        }

        above = below;
    }
}

/// The facility of a tile: the facility layer of a layered index, else the
/// base of the tile's object chain in a combined index.
pub fn base_facility(data: &[u8], things_data: &[u8], index: i64) -> i64 {
    if is_layered(data) {
        return facility(data, index);
    }

    let mut id = read(data, index);
    let mut hops = 0;

    while is_thing(id) && hops < super::things::count(things_data) {
        id = super::things::field(things_data, thing_record(id), sc2thing_layout::FIELD_LABEL);
        hops += 1;
    }

    if is_facility(id) { id } else { 0 }
}

#[inline]
pub fn count(data: &[u8]) -> i64 {
    cells_for(data.len() as i64)
}

#[inline]
pub fn read(data: &[u8], index: i64) -> i64 {
    let cells = count(data);
    let low = data[index as usize] as i64;

    if cells == data.len() as i64 {
        low
    } else if cells * 2 == data.len() as i64 {
        low | ((data[(cells + index) as usize] as i64) << 8)
    } else {
        let object = object(data, index);

        if object != 0 {
            object
        } else if low != 0 {
            low
        } else {
            facility(data, index)
        }
    }
}

#[inline]
pub fn write(data: &mut [u8], index: i64, value: i64) {
    let cells = count(data);

    if cells * 2 < data.len() as i64 {
        write_layer(data, index, value);

        return;
    }

    data[index as usize] = value as u8;

    if cells != data.len() as i64 {
        data[(cells + index) as usize] = (value >> 8) as u8;
    }
}

/// `write` of a layered index: the value goes to its own layer. A sign ID has
/// no layer; signs of a layered city are XSGN records.
fn write_layer(data: &mut [u8], index: i64, value: i64) {
    if value == 0 {
        if object(data, index) != 0 {
            set_object(data, index, 0);
        } else if marker(data, index) != 0 {
            set_marker(data, index, 0);
        } else {
            set_facility(data, index, 0);
        }
    } else if is_thing(value) {
        set_object(data, index, value);
    } else if is_facility(value) {
        set_facility(data, index, value);
    } else if (layout::ORIGINAL_RESERVED_FIRST..=layout::ORIGINAL_MAX_ID).contains(&value) {
        set_marker(data, index, value);
    }
}

pub fn is_sign(id: i64) -> bool {
    (layout::ORIGINAL_SIGN_FIRST..=layout::ORIGINAL_SIGN_LAST).contains(&id) || (EXTRA_SIGN..EXTRA_THING).contains(&id)
}

pub fn is_facility(id: i64) -> bool {
    (layout::ORIGINAL_FACILITY_FIRST..=layout::ORIGINAL_FACILITY_LAST).contains(&id)
        || (EXTRA_FACILITY..EXTRA_SIGN).contains(&id)
        || (EXTRA_FACILITY_HIGH..=0xffff).contains(&id)
}

pub fn is_thing(id: i64) -> bool {
    (layout::ORIGINAL_THING_FIRST..=layout::ORIGINAL_THING_LAST).contains(&id) || (EXTRA_THING..EXTRA_FACILITY_HIGH).contains(&id)
}

pub fn blocks_thing(id: i64) -> bool {
    is_thing(id) || (layout::ORIGINAL_RESERVED_FIRST..=layout::ORIGINAL_MAX_ID).contains(&id)
}

pub fn facility_id(record: i64) -> i64 {
    if record >= HIGH_FACILITY_FIRST_RECORD {
        EXTRA_FACILITY_HIGH + record - HIGH_FACILITY_FIRST_RECORD
    } else if record < sc2microsim_layout::ORIGINAL_COUNT {
        record + layout::ORIGINAL_FACILITY_FIRST
    } else {
        EXTRA_FACILITY + record - sc2microsim_layout::ORIGINAL_COUNT
    }
}

pub fn facility_record(id: i64) -> i64 {
    if id >= EXTRA_FACILITY_HIGH {
        id - EXTRA_FACILITY_HIGH + HIGH_FACILITY_FIRST_RECORD
    } else if id <= layout::ORIGINAL_FACILITY_LAST {
        id - layout::ORIGINAL_FACILITY_FIRST
    } else {
        id - EXTRA_FACILITY + sc2microsim_layout::ORIGINAL_COUNT
    }
}

pub fn thing_id(record: i64) -> i64 {
    if record < sc2thing_layout::ORIGINAL_COUNT {
        record + layout::ORIGINAL_THING_FIRST
    } else {
        EXTRA_THING + record - sc2thing_layout::ORIGINAL_COUNT
    }
}

pub fn thing_record(id: i64) -> i64 {
    if id <= layout::ORIGINAL_THING_LAST {
        id - layout::ORIGINAL_THING_FIRST
    } else {
        id - EXTRA_THING + sc2thing_layout::ORIGINAL_COUNT
    }
}

/// PackedByteArray.find for one byte value.
#[inline]
pub fn find_byte(data: &[u8], value: u8, start: i64) -> i64 {
    let start = start.max(0) as usize;

    if start >= data.len() {
        return -1;
    }

    match data[start..].iter().position(|&byte| byte == value) {
        Some(offset) => (start + offset) as i64,
        None => -1,
    }
}

/// OverlayData.find: the first cell at or after `start` that holds `value`.
/// A layered index searches the layer of the value.
pub fn find(data: &[u8], value: i64, start: i64) -> i64 {
    let cells = count(data);

    if is_layered(data) {
        let (plane, wide) = if is_thing(value) {
            (OBJECT_PLANE, true)
        } else if is_facility(value) {
            (FACILITY_PLANE, true)
        } else if (1..=layout::ORIGINAL_MAX_ID).contains(&value) && !is_sign(value) {
            (0, false)
        } else {
            return -1;
        };
        let plane_data = &data[(plane * cells) as usize..((plane + 1) * cells) as usize];
        let mut found = find_byte(plane_data, (value & 255) as u8, start);

        while found >= 0 {
            if !wide || wide_at(data, plane, found) == value {
                return found;
            }

            found = find_byte(plane_data, (value & 255) as u8, found + 1);
        }

        return -1;
    }
    let mut found = find_byte(data, (value & 255) as u8, start);

    while found >= 0 && found < cells {
        if read(data, found) == value {
            return found;
        }

        found = find_byte(data, (value & 255) as u8, found + 1);
    }

    -1
}

pub fn occurrences(data: &[u8], value: i64) -> i64 {
    if is_layered(data) && (1..=layout::ORIGINAL_MAX_ID).contains(&value) && !is_facility(value) && !is_thing(value) {
        let cells = count(data) as usize;

        return data[..cells].iter().filter(|&&byte| byte as i64 == value).count() as i64;
    }

    if count(data) == data.len() as i64 {
        if !(0..=255).contains(&value) {
            return 0;
        }

        return data.iter().filter(|&&byte| byte as i64 == value).count() as i64;
    }

    let mut total = 0;
    let mut index = find(data, value, 0);

    while index >= 0 {
        total += 1;
        index = find(data, value, index + 1);
    }

    total
}

/// OverlayData.sign_indices: the cells in `start..end` that hold a sign ID,
/// in cell order. A negative `end` scans to the last cell. A layered index
/// holds no sign links; its signs are XSGN records.
pub fn sign_indices(data: &[u8], start: i64, end: i64) -> Vec<i32> {
    if is_layered(data) {
        return Vec::new();
    }

    let cells = count(data) as usize;
    let end = if end < 0 { cells } else { (end as usize).min(cells) };
    let start = (start.max(0) as usize).min(end);
    let low = &data[start..end];
    let mut result = Vec::new();

    if cells == data.len() {
        for (offset, &byte) in low.iter().enumerate() {
            if is_sign(i64::from(byte)) {
                result.push((start + offset) as i32);
            }
        }

        return result;
    }

    let high = &data[cells + start..cells + end];

    for (offset, (&byte, &high_byte)) in low.iter().zip(high).enumerate() {
        if is_sign(i64::from(byte) | (i64::from(high_byte) << 8)) {
            result.push((start + offset) as i32);
        }
    }

    result
}

pub fn valid_id(id: i64, edge: i64) -> bool {
    if (0..=layout::ORIGINAL_MAX_ID).contains(&id) {
        return true;
    }

    if edge == 128 {
        return false;
    }

    let factor = (edge * edge) / 16384;

    (is_facility(id) && facility_record(id) < super::city::facility_capacity(factor))
        || (is_sign(id) && id < EXTRA_SIGN + layout::ORIGINAL_SIGN_COUNT * factor - layout::ORIGINAL_SIGN_COUNT)
        || (is_thing(id) && thing_record(id) < sc2thing_layout::ORIGINAL_COUNT * factor)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_map_size_has_one_tile_index_layout() {
        for edge in [16i64, 32, 64, 128, 256, 384, 512, 640, 1024, 2048, 4096] {
            let narrow = edge * edge;
            assert_eq!(cells_for(narrow), narrow, "a narrow {edge} plane");
            assert_eq!(cells_for(narrow * 2), narrow, "a wide {edge} plane");
            assert_eq!(cells_for(narrow * LAYERED_PLANES), narrow, "a layered {edge} index");
        }
    }

    #[test]
    fn a_layered_index_keeps_a_facility_a_marker_and_an_object_on_one_tile() {
        for edge in [16i64, 128, 4096] {
            let cells = edge * edge;
            let mut data = layered(cells);
            assert_eq!(cells_for(data.len() as i64), cells);
            assert!(is_layered(&data));
            assert!(!is_layered(&vec![0; cells as usize]) && !is_layered(&vec![0; cells as usize * 2]));
            let index = cells - 1;
            let facility_value = facility_id(HIGH_FACILITY_FIRST_RECORD + 5);
            let object_value = thing_id(900);
            write(&mut data, index, facility_value);
            write(&mut data, index, 0xff);
            write(&mut data, index, object_value);
            assert_eq!(
                (facility(&data, index), marker(&data, index), object(&data, index)),
                (facility_value, 0xff, object_value)
            );
            assert_eq!(read(&data, index), object_value, "the object is on top");
            assert!(blocks_thing(read(&data, index)));
            assert_eq!(find(&data, facility_value, 0), index);
            assert_eq!(find(&data, object_value, 0), index);
            assert_eq!(find(&data, 0xff, 0), index);
            assert_eq!(occurrences(&data, 0xff), 1);
            assert_eq!(base_facility(&data, &[], index), facility_value);

            write(&mut data, index, 0);
            assert_eq!(read(&data, index), 0xff, "clearing the top shows the marker");
            write(&mut data, index, 0);
            assert_eq!(read(&data, index), facility_value);
            write(&mut data, index, 0);
            assert_eq!(data, layered(cells));
        }
    }

    #[test]
    fn sign_indices_find_original_and_extended_signs() {
        let cells = 16 * 16;
        let mut narrow = vec![0u8; cells];
        narrow[0] = 1;
        narrow[7] = 50;
        narrow[8] = 51;
        narrow[cells - 1] = 25;
        assert_eq!(sign_indices(&narrow, 0, -1), vec![0, 7, cells as i32 - 1]);
        assert_eq!(sign_indices(&narrow, 1, 8), vec![7]);
        assert_eq!(sign_indices(&narrow, 0, cells as i64 + 100), vec![0, 7, cells as i32 - 1]);

        let mut wide = vec![0u8; cells * 2];

        for (index, id) in [
            (3, 1),
            (4, EXTRA_SIGN),
            (5, EXTRA_THING - 1),
            (6, EXTRA_THING),
            (9, EXTRA_SIGN - 1),
            (10, 0x0101),
        ] {
            write(&mut wide, index, id);
        }

        assert_eq!(sign_indices(&wide, 0, -1), vec![3, 4, 5]);
        assert_eq!(sign_indices(&wide, 4, 6), vec![4, 5]);

        let mut layered_index = layered(cells as i64);
        layered_index[0] = 1;
        assert!(sign_indices(&layered_index, 0, -1).is_empty());
    }

    #[test]
    fn the_high_facility_range_stays_apart_from_objects_and_signs() {
        let first = HIGH_FACILITY_FIRST_RECORD;
        assert_eq!((facility_id(first - 1), facility_id(first)), (EXTRA_SIGN - 1, EXTRA_FACILITY_HIGH));
        assert_eq!(facility_record(0xffff), first + 0xffff - EXTRA_FACILITY_HIGH);

        for id in [EXTRA_FACILITY_HIGH, 0xffff] {
            assert!(is_facility(id) && !is_thing(id) && !is_sign(id) && blocks_thing(id) == is_thing(id));
        }

        assert!(is_thing(EXTRA_FACILITY_HIGH - 1) && !is_facility(EXTRA_FACILITY_HIGH - 1));
    }
}
