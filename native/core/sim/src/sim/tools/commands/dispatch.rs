//! Emergency dispatch: police, fire, and military units. This is DispatchCommand
//! of the scripts. SIMCITY.EXE 0x0044fb50 (police), 0x0044fd60 (fire), and
//! 0x0044ff70 (military) place one unit for each click; 0x0044f910 starts the
//! disaster mode and removes the units of an earlier disaster.

use crate::formats::sc2x::limits;
use crate::sim::city::City;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2misc_layout as misc;
use crate::sim::ids::sc2tile_flags as flags;
use crate::sim::overlay;
use crate::sim::things;

const FIRST_THING: i64 = 1;
const RECORD_SIZE: i64 = things::RECORD_SIZE;

/// The military units of each MISC military base type.
const MILITARY_AVAILABILITY: [i64; 6] = [0, 0, 5, 2, 3, 0];

/// The unit type of each dispatch subtool: police, fire, military.
pub const TYPE_BY_SUBTOOL: [i64; 3] = [things::TYPE_POLICE, things::TYPE_FIRE, things::TYPE_MILITARY];

/// No fixed counts: each click counts the stations of the city.
pub const NO_CAPACITY: [i64; 3] = [-1, -1, -1];

/// The disaster city mode.
const DISASTER_MODE: i64 = 2;

/// The police, fire, and military units that the city can send.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Availability {
    pub police: i64,
    pub fire: i64,
    pub military: i64,
    pub base_type: i64,
}

impl Availability {
    pub fn counts(&self) -> [i64; 3] {
        [self.police, self.fire, self.military]
    }
}

/// The units of each type: one for each eight station tiles, and the units
/// of the military base. A city without any can still send one military unit.
pub fn availability(city: &City) -> Result<Availability, String> {
    let data = city.chunk("MISC").map(|chunk| chunk.data.as_slice()).unwrap_or_default();

    if data.len() as i64 != misc::SIZE {
        return Err("MISC is missing or has the wrong size".into());
    }

    let police = city.misc_u32(misc::TILE_COUNTS + tiles::POLICE_STATION * 4) >> 3;
    let fire = city.misc_u32(misc::TILE_COUNTS + tiles::FIRE_STATION * 4) >> 3;
    let base_type = city.misc_u32(misc::MILITARY_BASE_TYPE);
    let mut military = MILITARY_AVAILABILITY.get(base_type as usize).copied().unwrap_or(0);

    if police == 0 && fire == 0 && military == 0 {
        military = 1;
    }

    Ok(Availability {
        police,
        fire,
        military,
        base_type,
    })
}

/// The disaster-mode start: fix the unit counts for the disaster and remove
/// every dispatched unit from the map.
pub fn begin_disaster(city: &mut City) -> Result<Availability, String> {
    let available = availability(city)?;

    let (Some(things_chunk), Some(text_chunk)) = (city.chunk("XTHG"), city.chunk("XTXT")) else {
        return Err("dispatch chunks are missing".into());
    };

    let mut things_data = things_chunk.data.clone();
    let mut text = text_chunk.data.clone();
    clear_existing(&mut things_data, &mut text);

    // the script stores both payloads when either one changed
    if things_data != city.xthg.data || text != city.xtxt.data {
        city.xthg.replace(things_data);
        city.xtxt.replace(text);
    }

    Ok(available)
}

/// The edit of one dispatch click or of a recall: the XTHG and XTXT payloads
/// before and after it.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct DispatchEdit {
    pub thing_type: i64,
    pub thing_index: i64,
    pub target: Vec2i,
    pub available: i64,
    pub slot_index: i64,
    pub old_things: Vec<u8>,
    pub new_things: Vec<u8>,
    pub old_text: Vec<u8>,
    pub new_text: Vec<u8>,
}

/// One click of a dispatch tool. Each type cycles its own slots 1 to N. The
/// unit that slot k placed before is removed only while it is still on its
/// tile in `slot_points`; units of other types and other slots stay. A slot
/// without a tile uses 0, 0, as the zeroed arrays of the original do.
/// `capacity` holds the counts that the disaster start fixed; a negative
/// count uses the live count.
pub fn apply(
    city: &mut City,
    subtool: i64,
    target: Vec2i,
    cycle_index: i64,
    slot_points: &[(i64, Vec2i)],
    capacity: [i64; 3],
) -> Result<DispatchEdit, String> {
    if !(0..3).contains(&subtool) {
        return Err("tool is not an emergency dispatch tool".into());
    }

    let target_index = city.index_of(target.x, target.y);

    if target_index < 0 {
        return Err("dispatch target is outside the city".into());
    }

    let counts = if capacity[0] < 0 { availability(city)?.counts() } else { capacity };
    let available_count = counts[subtool as usize];

    if available_count == 0 {
        return Err("no dispatch units of this type are available".into());
    }

    if city
        .chunk("XTHG")
        .is_none_or(|chunk| chunk.data.len() as i64 != city.decoded_size("XTHG"))
    {
        return Err("XTHG is missing or has the wrong size".into());
    }

    if city
        .chunk("XTXT")
        .is_none_or(|chunk| chunk.data.len() as i64 != city.decoded_size("XTXT"))
    {
        return Err("XTXT is missing or has the wrong size".into());
    }

    if city.xbit.data[target_index as usize] & flags::WATER as u8 != 0 {
        return Err("dispatch target is water".into());
    }

    let old_things = city.xthg.data.clone();
    let old_text = city.xtxt.data.clone();
    let mut things_data = old_things.clone();
    let mut text = old_text.clone();

    if overlay::read(&text, target_index) != 0 {
        return Err("dispatch target has a text overlay".into());
    }

    let mut slot_index = cycle_index + 1;

    if slot_index > available_count || slot_index < 1 {
        slot_index = 1;
    }

    let thing_type = TYPE_BY_SUBTOOL[subtool as usize];
    let slot_point = slot_points
        .iter()
        .find(|(slot, _)| *slot == slot_index)
        .map_or(Vec2i::ZERO, |(_, point)| *point);
    let edge = city.map_size;

    if let Some(previous) = unit_at(&things_data, &text, slot_point, thing_type, edge) {
        delete_thing(&mut things_data, &mut text, previous, edge);
    }

    let mut thing_index = first_free_thing(&things_data, thing_budget(city));

    if thing_index.is_none() && city.misc_u32(misc::CITY_MODE) == DISASTER_MODE {
        let last = things::count(&things_data) - 1;
        delete_thing(&mut things_data, &mut text, last, edge);
        thing_index = Some(last);
    }

    let Some(thing_index) = thing_index else {
        return Err("no moving-thing record is available".into());
    };

    let offset = thing_index * RECORD_SIZE;

    for byte in 0..RECORD_SIZE {
        things::write(&mut things_data, offset + byte, 0);
    }

    things::write(&mut things_data, offset, thing_type);
    things::write(&mut things_data, offset + things::FIELD_X, target.x);
    things::write(&mut things_data, offset + things::FIELD_Y, target.y);
    overlay::write(&mut text, target_index, overlay::thing_id(thing_index));

    city.xthg.replace(things_data.clone());
    city.xtxt.replace(text.clone());

    Ok(DispatchEdit {
        thing_type,
        thing_index,
        target,
        available: available_count,
        slot_index,
        old_things,
        new_things: things_data,
        old_text,
        new_text: text,
    })
}

/// Recall every dispatched unit.
pub fn recall_all(city: &mut City) -> DispatchEdit {
    let old_things = city.xthg.data.clone();
    let old_text = city.xtxt.data.clone();
    let mut things_data = old_things.clone();
    let mut text = old_text.clone();
    clear_existing(&mut things_data, &mut text);
    city.xthg.replace(things_data.clone());
    city.xtxt.replace(text.clone());

    DispatchEdit {
        old_things,
        new_things: things_data,
        old_text,
        new_text: text,
        ..DispatchEdit::default()
    }
}

/// Free each dispatched unit that links a tile, and clear its first linked
/// tile in map order.
fn clear_existing(things_data: &mut [u8], text: &mut [u8]) {
    for thing_index in FIRST_THING..things::count(things_data) {
        let kind = things::read(things_data, thing_index * RECORD_SIZE);

        if !TYPE_BY_SUBTOOL.contains(&kind) {
            continue;
        }

        let index = overlay::find(text, overlay::thing_id(thing_index), 0);

        if index >= 0 {
            overlay::lift_object(text, things_data, thing_index, index, 0);
            things::write(things_data, thing_index * RECORD_SIZE, 0);
        }
    }
}

/// The record of the unit of `thing_type` that tile `point` shows on top.
fn unit_at(things_data: &[u8], text: &[u8], point: Vec2i, thing_type: i64, edge: i64) -> Option<i64> {
    if point.x < 0 || point.y < 0 || point.x >= edge || point.y >= edge {
        return None;
    }

    let value = overlay::read(text, point.x * edge + point.y);

    if !overlay::is_thing(value) {
        return None;
    }

    let record = overlay::thing_record(value);

    if record < FIRST_THING || record >= things::count(things_data) {
        return None;
    }

    (things::read(things_data, record * RECORD_SIZE) == thing_type).then_some(record)
}

/// With a budget (an SC2X version 4 city), no record is free while the active
/// objects fill the budget, even when an imported table has more slots.
fn first_free_thing(things_data: &[u8], budget: Option<i64>) -> Option<i64> {
    let mut active = 0;
    let mut free = None;

    for thing_index in FIRST_THING..things::count(things_data) {
        if things::read(things_data, thing_index * RECORD_SIZE) != 0 {
            active += 1;
        } else if free.is_none() {
            free = Some(thing_index);

            if budget.is_none() {
                return free;
            }
        }
    }

    match budget {
        Some(budget) if active >= budget => None,
        _ => free,
    }
}

/// The usable moving-object records of an SC2X version 4 city.
fn thing_budget(city: &City) -> Option<i64> {
    if !city.is_sc2x_working() {
        return None;
    }

    Some(limits::profile_for(city.map_size as usize).map_or(1, |profile| profile.things as i64) - 1)
}

fn delete_thing(things_data: &mut [u8], text: &mut [u8], thing_index: i64, edge: i64) {
    if thing_index < FIRST_THING || thing_index >= things::count(things_data) {
        return;
    }

    let offset = thing_index * RECORD_SIZE;
    let x = things::read(things_data, offset + things::FIELD_X);
    let y = things::read(things_data, offset + things::FIELD_Y);

    if (0..edge).contains(&x) && (0..edge).contains(&y) {
        let index = x * edge + y;

        if overlay::read(text, index) == overlay::thing_id(thing_index) {
            overlay::lift_object(text, things_data, thing_index, index, 0);
        }
    }

    for byte in 0..RECORD_SIZE {
        things::write(things_data, offset + byte, 0);
    }
}
