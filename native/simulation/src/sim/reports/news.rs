//! The saved newspaper story queue, as NewsQueue, and the story persistence of
//! SimulationPhaseContext.persist_news.

use crate::sim::bytes::{read_u32_be, write_u32_be};
use crate::sim::city::City;
use crate::sim::events::NewsEvent;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::phase::PhaseBase;

pub const QUEUE_COUNT: i64 = 7;
pub const STORY_RECORD_COUNT: i64 = 9;
pub const STORY_FIELD_COUNT: i64 = 6;
pub const STORY_RECORD_SIZE: i64 = STORY_FIELD_COUNT * 4;
const FIRST_AUXILIARY_FIELD: i64 = 3;

/// The data_usa resources 1004 and 1005: big-endian unsigned 16-bit tables.
pub const STORY_PRIORITIES: [i64; 80] = [
    0, 0, 1000, 1000, 1000, 1000, 360, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 1000, 1000, 1000, 1000,
    1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 200, 200, 300, 200, 200, 0, 0, 0, 0, 500, 500, 500, 500, 500, 500,
    500, 500, 500, 500, 500, 500, 500, 500, 500, 200, 200, 200, 200, 200, 200, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];
pub const STORY_DECAYS: [i64; 80] = [
    0, 0, 500, 500, 250, 250, 10, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 250, 250, 250, 250, 250, 250, 250, 250, 250,
    250, 250, 250, 250, 250, 100, 50, 50, 50, 50, 50, 0, 0, 0, 0, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 500,
    500, 50, 50, 50, 50, 50, 50, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];

pub fn is_story_type(story_type: i64) -> bool {
    (0..STORY_PRIORITIES.len() as i64).contains(&story_type)
}

/// The news routine at 0x0047b5c0 opens an extra edition for these stories
/// when the extra-edition option is on.
pub fn opens_extra_edition(story_type: i64) -> bool {
    (3..=5).contains(&story_type) || story_type == 0x24
}

fn story_offset(slot: i64) -> i64 {
    misc_layout::STORIES + slot * STORY_RECORD_SIZE
}

fn to_i16(value: i64) -> i64 {
    let word = value & 0xffff;

    if word & 0x8000 != 0 { word - 0x10000 } else { word }
}

fn story_priority(misc: &[u8], slot: i64) -> i64 {
    to_i16(read_u32_be(misc, story_offset(slot) + 4))
}

fn validate(misc: &[u8]) -> Result<(), String> {
    if misc.len() as i64 != misc_layout::SIZE {
        return Err("MISC is missing or has the wrong size".to_string());
    }

    Ok(())
}

/// NewsQueue.decay_and_sort.
pub fn decay_and_sort(misc: &mut [u8]) -> Result<(), String> {
    validate(misc)?;

    for slot in 0..QUEUE_COUNT {
        let offset = story_offset(slot);
        let story_type = to_i16(read_u32_be(misc, offset));

        if !is_story_type(story_type) {
            return Err("newspaper queue story type is out of range".to_string());
        }

        let priority = to_i16(read_u32_be(misc, offset + 4));
        let decay = STORY_DECAYS[story_type as usize];
        write_u32_be(misc, offset + 4, if decay < priority { priority - decay } else { 0 });
    }

    for first in 0..QUEUE_COUNT - 1 {
        for candidate in first + 1..QUEUE_COUNT {
            if story_priority(misc, first) < story_priority(misc, candidate) {
                let a = story_offset(first) as usize;
                let b = story_offset(candidate) as usize;
                let size = STORY_RECORD_SIZE as usize;
                let (head, tail) = misc.split_at_mut(b);
                head[a..a + size].swap_with_slice(&mut tail[..size]);
            }
        }
    }

    Ok(())
}

/// NewsQueue.insert. Returns the slot and the priority.
pub fn insert(misc: &mut [u8], story_type: i64, argument: i64) -> Result<(i64, i64), String> {
    validate(misc)?;

    if !is_story_type(story_type) {
        return Err("newspaper story type is out of range".to_string());
    }

    let priority = STORY_PRIORITIES[story_type as usize];
    let mut slot = QUEUE_COUNT - 2;

    while slot >= 0 {
        if priority < story_priority(misc, slot) {
            break;
        }

        let source = story_offset(slot) as usize;
        let target = story_offset(slot + 1) as usize;
        misc.copy_within(source..source + STORY_RECORD_SIZE as usize, target);
        slot -= 1;
    }

    let inserted = slot + 1;
    let offset = story_offset(inserted);
    write_u32_be(misc, offset, story_type);
    write_u32_be(misc, offset + 4, priority);
    write_u32_be(misc, offset + 8, argument & 0xff);

    for field in FIRST_AUXILIARY_FIELD..STORY_FIELD_COUNT {
        write_u32_be(misc, offset + field * 4, 0xff);
    }

    Ok((inserted, priority))
}

/// NewsQueue.insert_items. Returns the number of stories inserted.
pub fn insert_items(misc: &mut [u8], news_items: &[NewsEvent]) -> Result<i64, String> {
    let mut inserted = 0;

    for item in news_items {
        if !is_story_type(item.type_) {
            continue;
        }

        insert(misc, item.type_, item.argument)?;
        inserted += 1;
    }

    Ok(inserted)
}

/// SimulationPhaseContext.persist_news: insert the stories of one result into
/// the saved queue. Returns the number inserted.
pub fn persist(city: &mut City, result: &mut PhaseBase) -> Result<i64, String> {
    // Monthly aftermath stores its own queue, but still needs an extra edition.
    if city.misc_u32(misc_layout::NEWSPAPER_EXTRAS) != 0 && result.news_items.iter().any(|item| opens_extra_edition(item.type_)) {
        result.newspaper_requested = true;
    }

    if result.news_queue_updated || result.news_items.is_empty() {
        return Ok(0);
    }

    if !city.misc.present || city.misc.data.len() as i64 != misc_layout::SIZE {
        return Err("MISC is missing or has the wrong size".to_string());
    }

    let mut misc = city.misc.data.clone();
    let inserted = insert_items(&mut misc, &result.news_items)?;

    if inserted == 0 {
        return Ok(0);
    }

    city.misc.replace(misc);
    result.news_queue_updated = true;
    result.news_queue_inserted = inserted;
    Ok(inserted)
}
