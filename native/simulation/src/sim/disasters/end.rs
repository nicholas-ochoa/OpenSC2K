//! The disaster end and the automatic Maxis Man response, as DisasterEnd and MaxisManResponse.

use super::MaxisManArrival;
use crate::gd_object;
use crate::sim::city::City;
use crate::sim::events::NewsEvent;
use crate::sim::geom::Vec2i;
use crate::sim::moving::motion::direction_between;
use crate::sim::overlay;
use crate::sim::random::{SimLfsrRandom, SimRandom};
use crate::sim::things;

const MILITARY_BASE_STATE: i64 = 0x0e4c;
const ARRIVAL_OFFSETS: [Vec2i; 4] = [Vec2i::new(16, 0), Vec2i::new(0, 16), Vec2i::new(-16, 0), Vec2i::new(0, -16)];
/// Units that leave the map at the disaster end.
const DISPATCH_TYPES: [i64; 3] = [things::TYPE_POLICE, things::TYPE_FIRE, things::TYPE_MILITARY];

gd_object! {
    pub struct DisasterEndResult as "DisasterEnd.Result" {
        pub ok: bool = false,
        pub error: String = String::new(),
        pub news_items: Vec<NewsEvent> = Vec::new(),
        pub removed_units: i64 = 0,
    }
}

/// The summary story type for each disaster type, from the switch at 0x0045d179.
fn story_type(disaster_type: i64) -> Option<i64> {
    match disaster_type {
        1 | 12 => Some(0x16),
        2 | 14 => Some(0x17),
        3 | 13 => Some(0x23),
        4 => Some(0x20),
        5 | 18 => Some(0x18),
        6 => Some(0x1b),
        7 => Some(0x1a),
        8 => Some(0x1c),
        9 => Some(0x1d),
        10 => Some(0x1e),
        11 => Some(0x1f),
        15 => Some(0x21),
        16 => Some(0x22),
        17 => Some(0x19),
        _ => None,
    }
}

/// DisasterEnd.finish: the work that the original does when the last disaster
/// marker and object are gone (0x0045cf10). It adds a summary story and removes
/// the police, fire, and military units that the disaster sent.
pub fn finish(city: &mut City, disaster_type: i64) -> DisasterEndResult {
    let mut result = DisasterEndResult::default();

    if let Some(story) = story_type(disaster_type) {
        let damage_class = city.disaster_damage_class.max(0);
        result.news_items.push(NewsEvent::new(story, damage_class & 0xff));
    }

    city.disaster_damage_class = -1;
    let removed = remove_dispatched_units(city);

    if removed < 0 {
        result.error = "cannot remove the dispatched units".to_string();

        return result;
    }

    result.removed_units = removed;
    result.ok = true;
    result
}

/// Clear the map label of each police, fire, or military unit and the type of
/// its record. The original keeps the other record fields.
fn remove_dispatched_units(city: &mut City) -> i64 {
    if city.missing_or_resized(&["XTHG"]).is_some() {
        return -1;
    }

    let mut thing_data = city.xthg.data.clone();
    let mut text = city.xtxt.data.clone();
    let record_count = things::count(&thing_data);
    let mut removed = 0;

    for tile_index in 0..overlay::count(&text) {
        if tile_index & 1023 == 0 {
            crate::sim::budget::checkpoint();
        }

        let label = overlay::read(&text, tile_index);

        if !overlay::is_thing(label) {
            continue;
        }

        let record = overlay::thing_record(label);

        if record < 0 || record >= record_count {
            continue;
        }

        let offset = record * things::RECORD_SIZE;

        if !DISPATCH_TYPES.contains(&things::read(&thing_data, offset)) {
            continue;
        }

        overlay::lift_object(&mut text, &mut thing_data, record, tile_index, 0);
        things::write(&mut thing_data, offset, things::TYPE_NONE);
        removed += 1;
    }

    if removed == 0 {
        return 0;
    }

    city.xthg.replace(thing_data);
    city.xtxt.replace(text);
    removed
}

/// MaxisManResponse.apply for a started disaster. Returns the arrival, or None
/// when no hero comes. State 1 also covers a declined proposal or failed missile
/// search. The random gate comes before the checks for an existing hero or a free slot.
pub fn maxis_man_response(
    city: &mut City,
    point: Vec2i,
    disaster_type: i64,
    disaster_record: i64,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
) -> Option<MaxisManArrival> {
    if city.misc_u32(MILITARY_BASE_STATE) != 1 || lfsr.next_mask(3) != 0 {
        return None;
    }

    let mut thing_data = city.xthg.data.clone();
    let mut record = 0;

    for candidate in 1..things::count(&thing_data) {
        let thing_type = things::read(&thing_data, candidate * things::RECORD_SIZE);

        if thing_type == things::TYPE_MAXIS_MAN {
            return None;
        }

        if thing_type == 0 && record == 0 {
            record = candidate;
        }
    }

    if record == 0 {
        return None;
    }

    let edge = city.map_size;
    let clamp = |point: Vec2i| Vec2i::new(point.x.clamp(0, edge - 1), point.y.clamp(0, edge - 1));
    let target = clamp(point);
    let arrival = clamp(target + ARRIVAL_OFFSETS[(random.next_u15() & 3) as usize]);
    let offset = record * things::RECORD_SIZE;
    // The original allocator leaves old record data in place. Disaster types
    // without a goal assignment reuse that stale goal.
    let goal = match disaster_type {
        1 | 5 | 6 | 9 | 10 | 11 | 12 => 255,
        2 | 14 => 252,
        3 | 13 => 253 + (random.next_u15() & 1),
        4 | 15 => 251,
        7 | 8 => things::target_id(disaster_record),
        _ => things::read(&thing_data, offset + 11),
    };
    let mut text = city.xtxt.data.clone();
    let tile_index = city.index_of(arrival.x, arrival.y);
    let fields = [
        things::TYPE_MAXIS_MAN,
        direction_between(arrival, target),
        0,
        arrival.x,
        arrival.y,
        city.land_altitude(arrival.x, arrival.y) + 2,
        8,
        8,
        target.x,
        target.y,
        overlay::covered(&text, tile_index),
        goal,
    ];

    for (field, value) in fields.iter().enumerate() {
        things::write(&mut thing_data, offset + field as i64, *value);
    }

    // Keep the old label under the hero, as the original does.
    overlay::write(&mut text, tile_index, overlay::thing_id(record));
    city.xthg.replace(thing_data);
    city.xtxt.replace(text);

    Some(MaxisManArrival {
        record,
        point: arrival,
        target,
        goal,
    })
}
