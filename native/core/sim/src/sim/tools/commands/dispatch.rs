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
use crate::sim::value::{Bytes, ToValue, Value};

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

/// The tool group of the dispatch tools.
const DISPATCH_GROUP: i64 = 2;

/// The police, fire, and military units that the city can send.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Availability {
    pub police: i64,
    pub fire: i64,
    pub military: i64,
    pub base_type: i64,
    /// True when the city has no police, fire, or military units, so the
    /// National Guard sends the one military unit (SIMCITY.EXE 0x0044f910).
    pub national_guard: bool,
}

impl Availability {
    pub fn counts(&self) -> [i64; 3] {
        [self.police, self.fire, self.military]
    }
}

/// The DispatchCommand.Availability of a count, or of its error.
pub fn availability_value(available: Result<Availability, String>) -> Value {
    let fields = match available {
        Ok(available) => vec![
            ("ok", Value::Bool(true)),
            ("error", Value::Str(String::new())),
            ("police", Value::Int(available.police)),
            ("fire", Value::Int(available.fire)),
            ("military", Value::Int(available.military)),
            ("base_type", Value::Int(available.base_type)),
        ],
        Err(error) => vec![("ok", Value::Bool(false)), ("error", Value::Str(error))],
    };

    Value::Object("DispatchCommand.Availability", fields)
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
    let national_guard = police == 0 && fire == 0 && military == 0;

    if national_guard {
        military = 1;
    }

    Ok(Availability {
        police,
        fire,
        military,
        base_type,
        national_guard,
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
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DispatchEdit {
    /// The dispatch subtool, or -1 for a recall.
    pub subtool: i64,
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

impl Default for DispatchEdit {
    fn default() -> Self {
        Self {
            subtool: -1,
            thing_type: 0,
            thing_index: -1,
            target: Vec2i::NONE,
            available: 0,
            slot_index: 0,
            old_things: Vec::new(),
            new_things: Vec::new(),
            old_text: Vec::new(),
            new_text: Vec::new(),
        }
    }
}

/// The DispatchEditResult of a successful edit.
impl ToValue for DispatchEdit {
    fn to_value(&self) -> Value {
        let group = if self.subtool >= 0 { DISPATCH_GROUP } else { -1 };
        let fields = vec![
            ("ok", Value::Bool(true)),
            ("command_type", Value::Str("dispatch".into())),
            ("group_index", Value::Int(group)),
            ("subtool_index", Value::Int(self.subtool)),
            ("thing_type", Value::Int(self.thing_type)),
            ("thing_index", Value::Int(self.thing_index)),
            ("target", Value::Vec2i(self.target)),
            ("available", Value::Int(self.available)),
            ("slot_index", Value::Int(self.slot_index)),
            ("old_things", Bytes(self.old_things.clone()).to_value()),
            ("new_things", Bytes(self.new_things.clone()).to_value()),
            ("old_text", Bytes(self.old_text.clone()).to_value()),
            ("new_text", Bytes(self.new_text.clone()).to_value()),
        ];

        Value::Object("DispatchEditResult", fields)
    }
}

/// A failed dispatch edit as a DispatchEditResult.
pub fn rejected(message: &str) -> Value {
    Value::Object(
        "DispatchEditResult",
        vec![("ok", Value::Bool(false)), ("error", Value::Str(message.to_string()))],
    )
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
        subtool,
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

#[cfg(test)]
mod tests {
    use super::*;

    fn set_ship(data: &mut [u8], record: i64) {
        things::write(data, record * RECORD_SIZE, things::TYPE_SHIP);
    }

    #[test]
    fn a_version_4_budget_limits_the_active_objects() {
        let city = crate::sim::testing::empty_sc2x_city(16);
        let budget = thing_budget(&city).expect("a version 4 city has a budget");
        assert_eq!(budget, 15, "a 16-tile city can use 15 moving-object records");

        let mut data = city.xthg.data.clone();

        for record in 1..budget {
            set_ship(&mut data, record);
        }

        assert_eq!(
            first_free_thing(&data, Some(budget)),
            Some(budget),
            "the last record under the budget is free"
        );
        set_ship(&mut data, budget);
        assert_eq!(
            first_free_thing(&data, Some(budget)),
            None,
            "a pool at its budget has no free record"
        );

        // an imported table can be larger than its budget
        let mut imported = vec![0; 32 * crate::sim::ids::sc2thing_layout::EXTENDED_RECORD_SIZE as usize];

        for record in 1..16 {
            set_ship(&mut imported, record);
        }

        assert_eq!(
            first_free_thing(&imported, Some(budget)),
            None,
            "an over-budget import allows no new object"
        );
        things::write(&mut imported, RECORD_SIZE, 0);
        assert_eq!(
            first_free_thing(&imported, Some(budget)),
            Some(1),
            "removing an object below the budget allows a new one"
        );
        assert_eq!(first_free_thing(&imported, None), Some(1), "original cities use any free record");
        assert_eq!(thing_budget(&crate::sim::testing::empty_city(128)), None);
    }
}
