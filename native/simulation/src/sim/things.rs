//! XTHG records, as ThingData. SCLG stores equal low and high record planes.
//! SCDH remains byte-exact.

use super::geom::Vec2i;
use super::ids::sc2thing_layout as layout;
use super::overlay;

pub const BASE_SIZE: i64 = layout::ORIGINAL_SIZE;
pub const RECORD_SIZE: i64 = layout::RECORD_SIZE;

pub const FIELD_TYPE: i64 = layout::FIELD_TYPE;
pub const FIELD_DIRECTION: i64 = layout::FIELD_DIRECTION;
pub const FIELD_STATE: i64 = layout::FIELD_STATE;
pub const FIELD_X: i64 = layout::FIELD_X;
pub const FIELD_Y: i64 = layout::FIELD_Y;
pub const FIELD_Z: i64 = layout::FIELD_Z;
pub const FIELD_PX: i64 = layout::FIELD_PX;
pub const FIELD_PY: i64 = layout::FIELD_PY;
pub const FIELD_DX: i64 = layout::FIELD_DX;
pub const FIELD_DY: i64 = layout::FIELD_DY;
pub const FIELD_LABEL: i64 = layout::FIELD_LABEL;
pub const FIELD_GOAL: i64 = layout::FIELD_GOAL;

pub const TYPE_NONE: i64 = layout::TYPE_NONE;
pub const TYPE_AIRPLANE: i64 = layout::TYPE_AIRPLANE;
pub const TYPE_HELICOPTER: i64 = layout::TYPE_HELICOPTER;
pub const TYPE_SHIP: i64 = layout::TYPE_SHIP;
pub const TYPE_BULLDOZER: i64 = layout::TYPE_BULLDOZER;
pub const TYPE_MONSTER: i64 = layout::TYPE_MONSTER;
pub const TYPE_EXPLOSION: i64 = layout::TYPE_EXPLOSION;
pub const TYPE_POLICE: i64 = layout::TYPE_POLICE;
pub const TYPE_FIRE: i64 = layout::TYPE_FIRE;
pub const TYPE_SAILBOAT: i64 = layout::TYPE_SAILBOAT;
pub const TYPE_TRAIN_ENGINE: i64 = layout::TYPE_TRAIN_ENGINE;
pub const TYPE_TRAIN_CAR: i64 = layout::TYPE_TRAIN_CAR;
pub const TYPE_SUBWAY_ENGINE: i64 = layout::TYPE_SUBWAY_ENGINE;
pub const TYPE_SUBWAY_CAR: i64 = layout::TYPE_SUBWAY_CAR;
pub const TYPE_MILITARY: i64 = layout::TYPE_MILITARY;
pub const TYPE_TORNADO: i64 = layout::TYPE_TORNADO;
pub const TYPE_MAXIS_MAN: i64 = layout::TYPE_MAXIS_MAN;

/// Only some fields widen, and which ones depends on the object type.
#[inline]
fn wide(data: &[u8], index: i64) -> bool {
    let field = index % RECORD_SIZE;
    let kind = data[(index - field) as usize] as i64;

    field == FIELD_X
        || field == FIELD_Y
        || field == FIELD_DX
        || field == FIELD_DY
        || field == FIELD_LABEL
        || ((TYPE_TRAIN_ENGINE..=TYPE_SUBWAY_CAR).contains(&kind) && (field == FIELD_STATE || field == FIELD_PX || field == FIELD_PY))
        || (kind == TYPE_MAXIS_MAN && field == FIELD_GOAL)
}

#[inline]
pub fn read(data: &[u8], index: i64) -> i64 {
    let mut value = data[index as usize] as i64;

    if data.len() as i64 > BASE_SIZE && wide(data, index) {
        value |= (data[(data.len() as i64 / 2 + index) as usize] as i64) << 8;
    }

    value
}

#[inline]
pub fn write(data: &mut [u8], index: i64, value: i64) {
    data[index as usize] = value as u8;

    if data.len() as i64 > BASE_SIZE {
        let field = index % RECORD_SIZE;
        let ship = data[(index - field) as usize] as i64 == TYPE_SHIP;

        if !(ship && (field == FIELD_TYPE || field == FIELD_DIRECTION || field == FIELD_STATE || field == FIELD_Z)) {
            let high = if wide(data, index) { (value >> 8) as u8 } else { 0 };
            data[(data.len() as i64 / 2 + index) as usize] = high;
        }
    }
}

/// Read one field of one record.
#[inline]
pub fn field(data: &[u8], record: i64, field: i64) -> i64 {
    read(data, record * RECORD_SIZE + field)
}

/// Write one field of one record.
#[inline]
pub fn set_field(data: &mut [u8], record: i64, field: i64, value: i64) {
    write(data, record * RECORD_SIZE + field, value)
}

pub fn count(data: &[u8]) -> i64 {
    data.len() as i64
        / if data.len() as i64 > BASE_SIZE {
            layout::EXTENDED_RECORD_SIZE
        } else {
            RECORD_SIZE
        }
}

pub fn target_id(record: i64) -> i64 {
    if record < 241 { record } else { overlay::thing_id(record) }
}

pub fn target_record(goal: i64) -> i64 {
    if goal >= overlay::EXTRA_THING {
        overlay::thing_record(goal)
    } else {
        goal
    }
}

pub fn is_record_target(goal: i64) -> bool {
    !(241..overlay::EXTRA_THING).contains(&goal)
}

/// Ship home lives in spare high-plane bytes. They store a coordinate plus one
/// because zero means missing.
pub fn set_ship_home(data: &mut [u8], record: i64, point: Vec2i) {
    if data.len() as i64 <= BASE_SIZE {
        return;
    }

    let offset = (data.len() as i64 / 2 + record * RECORD_SIZE) as usize;
    data[offset + layout::SHIPHOMEFIELD_X_LOW as usize] = ((point.x + 1) & 255) as u8;
    data[offset + layout::SHIPHOMEFIELD_X_HIGH as usize] = ((point.x + 1) >> 8) as u8;
    data[offset + layout::SHIPHOMEFIELD_Y_LOW as usize] = ((point.y + 1) & 255) as u8;
    data[offset + layout::SHIPHOMEFIELD_Y_HIGH as usize] = ((point.y + 1) >> 8) as u8;
}

pub fn ship_home(data: &[u8], record: i64, fallback: Vec2i) -> Vec2i {
    if data.len() as i64 <= BASE_SIZE {
        return fallback;
    }

    let offset = (data.len() as i64 / 2 + record * RECORD_SIZE) as usize;
    let x = (data[offset + layout::SHIPHOMEFIELD_X_LOW as usize] as i64
        | ((data[offset + layout::SHIPHOMEFIELD_X_HIGH as usize] as i64) << 8))
        - 1;
    let y = (data[offset + layout::SHIPHOMEFIELD_Y_LOW as usize] as i64
        | ((data[offset + layout::SHIPHOMEFIELD_Y_HIGH as usize] as i64) << 8))
        - 1;

    if x >= 0 && y >= 0 {
        Vec2i::new(x, y)
    } else {
        Vec2i::new(field(data, record, FIELD_X), field(data, record, FIELD_Y))
    }
}
