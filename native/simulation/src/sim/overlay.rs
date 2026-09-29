//! XTXT links, as OverlayData. Original IDs are unchanged. SC2X v2 adds
//! disjoint 16-bit ID ranges in a second byte plane.

use super::ids::sc2microsim_layout;
use super::ids::sc2overlay_layout as layout;
use super::ids::sc2thing_layout;

pub const EXTRA_FACILITY: i64 = layout::EXTRA_FACILITY;
pub const EXTRA_SIGN: i64 = layout::EXTRA_SIGN;
pub const EXTRA_THING: i64 = layout::EXTRA_THING;

/// A wide map stores a low and a high plane, so its cell count is half its bytes.
#[inline]
pub fn cells_for(byte_count: i64) -> i64 {
    match byte_count {
        131072 | 294912 | 524288 | 819200 | 2097152 => byte_count / 2,
        _ => byte_count,
    }
}

#[inline]
pub fn count(data: &[u8]) -> i64 {
    cells_for(data.len() as i64)
}

#[inline]
pub fn read(data: &[u8], index: i64) -> i64 {
    let cells = count(data);
    let low = data[index as usize] as i64;

    if cells != data.len() as i64 {
        low | ((data[(cells + index) as usize] as i64) << 8)
    } else {
        low
    }
}

#[inline]
pub fn write(data: &mut [u8], index: i64, value: i64) {
    data[index as usize] = value as u8;
    let cells = count(data);

    if cells != data.len() as i64 {
        data[(cells + index) as usize] = (value >> 8) as u8;
    }
}

pub fn is_sign(id: i64) -> bool {
    (layout::ORIGINAL_SIGN_FIRST..=layout::ORIGINAL_SIGN_LAST).contains(&id) || (EXTRA_SIGN..EXTRA_THING).contains(&id)
}

pub fn is_facility(id: i64) -> bool {
    (layout::ORIGINAL_FACILITY_FIRST..=layout::ORIGINAL_FACILITY_LAST).contains(&id) || (EXTRA_FACILITY..EXTRA_SIGN).contains(&id)
}

pub fn is_thing(id: i64) -> bool {
    (layout::ORIGINAL_THING_FIRST..=layout::ORIGINAL_THING_LAST).contains(&id) || id >= EXTRA_THING
}

pub fn blocks_thing(id: i64) -> bool {
    is_thing(id) || (layout::ORIGINAL_RESERVED_FIRST..=layout::ORIGINAL_MAX_ID).contains(&id)
}

pub fn facility_id(record: i64) -> i64 {
    if record < sc2microsim_layout::ORIGINAL_COUNT {
        record + layout::ORIGINAL_FACILITY_FIRST
    } else {
        EXTRA_FACILITY + record - sc2microsim_layout::ORIGINAL_COUNT
    }
}

pub fn facility_record(id: i64) -> i64 {
    if id <= layout::ORIGINAL_FACILITY_LAST {
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
pub fn find(data: &[u8], value: i64, start: i64) -> i64 {
    let cells = count(data);
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
