//! The saved newspaper papers and story queue, as NewsQueue, and the story
//! persistence of SimulationPhaseContext.persist_news.

use crate::sim::bytes::{read_u32_be, write_u32_be};
use crate::sim::city::City;
use crate::sim::events::NewsEvent;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::phase::PhaseBase;

pub use sc2k_assets::data_usa::{STORY_DECAYS, STORY_PRIORITIES};

pub const PAPER_COUNT: i64 = 6;
pub const PAPER_FIELD_COUNT: i64 = 5;
pub const PAPER_RECORD_SIZE: i64 = PAPER_FIELD_COUNT * 4;
const PAPER_NAME_FIELD: i64 = 0;
const PAPER_LAYOUT_FIELD: i64 = 1;
const PAPER_PRICE_FIELD: i64 = 2;
const PAPER_OPINION_FIELD: i64 = 3;
const PAPER_WEATHER_FIELD: i64 = 4;
/// The paper layouts and prices repeat in groups of three.
const PAPER_STYLE_COUNT: i64 = 3;
/// The shuffle passes of a new session. Each pass swaps each paper field once.
const SHUFFLE_PASSES: i64 = 12;
/// The draws of `initialize_session`: two choices and two draws per swap.
pub const SESSION_RANDOM_CALLS: i64 = 2 + SHUFFLE_PASSES * PAPER_FIELD_COUNT * 2;
/// The first story type of the placeholder stories of a new session.
const PLACEHOLDER_STORY_FIRST: i64 = 11;
/// The display slots that the newspaper opener fills.
const WEATHER_SLOT: i64 = 7;
const OPINION_SLOT: i64 = 8;
/// The opinion story type of each paper opinion style.
const OPINION_STORY_TYPES: [i64; 6] = [42, 43, 43, 44, 44, 45];
const NO_SUBSTITUTION: i64 = 0xff;
pub const AUXILIARY_COUNT: usize = 3;
const PROGRESSION_SIGN: i64 = 0x8000;

pub const QUEUE_COUNT: i64 = 7;
pub const STORY_RECORD_COUNT: i64 = 9;
pub const STORY_FIELD_COUNT: i64 = 6;
pub const STORY_RECORD_SIZE: i64 = STORY_FIELD_COUNT * 4;
const ARGUMENT_FIELD: i64 = 2;
const FIRST_AUXILIARY_FIELD: i64 = 3;

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

fn paper_field_offset(paper: i64, field: i64) -> i64 {
    misc_layout::PAPERS + paper * PAPER_RECORD_SIZE + field * 4
}

fn swap_paper_field(misc: &mut [u8], first: i64, second: i64, field: i64) {
    let first_offset = paper_field_offset(first, field);
    let second_offset = paper_field_offset(second, field);
    let first_value = read_u32_be(misc, first_offset);
    write_u32_be(misc, first_offset, read_u32_be(misc, second_offset));
    write_u32_be(misc, second_offset, first_value);
}

/// NewsQueue.initialize_session: deal the six papers their names, layouts,
/// prices, opinions, and weather styles, and clear the story records.
/// `next_u15` gives each SimRandom draw; a session takes SESSION_RANDOM_CALLS.
pub fn initialize_session(misc: &mut [u8], mut next_u15: impl FnMut() -> i64) -> Result<(), String> {
    validate(misc)?;

    for paper in 0..PAPER_COUNT {
        write_u32_be(misc, paper_field_offset(paper, PAPER_NAME_FIELD), paper);
        write_u32_be(misc, paper_field_offset(paper, PAPER_LAYOUT_FIELD), paper % PAPER_STYLE_COUNT);
        write_u32_be(misc, paper_field_offset(paper, PAPER_PRICE_FIELD), paper % PAPER_STYLE_COUNT);
        write_u32_be(misc, paper_field_offset(paper, PAPER_OPINION_FIELD), paper);
        write_u32_be(misc, paper_field_offset(paper, PAPER_WEATHER_FIELD), paper);
    }

    swap_paper_field(misc, 0, 3 + (next_u15() & 1), PAPER_OPINION_FIELD);

    if next_u15() & 1 != 0 {
        swap_paper_field(misc, 0, 1, PAPER_LAYOUT_FIELD);
    }

    // (field, first paper, paper count) of each swap of one pass
    const SWAPS: [(i64, i64, i64); 5] = [
        (PAPER_NAME_FIELD, 0, 6),
        (PAPER_LAYOUT_FIELD, 1, 5),
        (PAPER_PRICE_FIELD, 0, 6),
        (PAPER_OPINION_FIELD, 1, 5),
        (PAPER_WEATHER_FIELD, 0, 6),
    ];

    for _ in 0..SHUFFLE_PASSES {
        for (field, first, count) in SWAPS {
            let source = first + next_u15() % count;
            let target = first + next_u15() % count;
            swap_paper_field(misc, source, target, field);
        }
    }

    for slot in 0..STORY_RECORD_COUNT {
        let offset = story_offset(slot);
        write_u32_be(misc, offset, PLACEHOLDER_STORY_FIRST + slot);
        write_u32_be(misc, offset + 4, 0);
        write_u32_be(misc, offset + 8, 0);

        for field in FIRST_AUXILIARY_FIELD..STORY_FIELD_COUNT {
            write_u32_be(misc, offset + field * 4, NO_SUBSTITUTION);
        }
    }

    Ok(())
}

/// NewsQueue.available_paper_count. The menu builder at 0x00406d70 reads a
/// signed progression word.
pub fn available_paper_count(progression: i64) -> i64 {
    let mut level = progression & 0xffff;

    if level & PROGRESSION_SIGN != 0 {
        level -= 0x10000;
    }

    (level + 1).clamp(0, PAPER_COUNT)
}

/// NewsQueue.prepare_weather_report: the newspaper opener sets display slot 7
/// to weather story type 0 and the current trend.
pub fn prepare_weather_report(misc: &mut [u8], weather: i64) -> Result<(), String> {
    validate(misc)?;
    let offset = story_offset(WEATHER_SLOT);
    write_u32_be(misc, offset, 0);
    write_u32_be(misc, offset + ARGUMENT_FIELD * 4, weather & 0xff);

    Ok(())
}

/// NewsQueue.prepare_opinion_report: the opener selects the story type of
/// display slot 8 from the opinion style of the paper.
pub fn prepare_opinion_report(misc: &mut [u8], style: i64, subject: i64) -> Result<(), String> {
    validate(misc)?;
    let offset = story_offset(OPINION_SLOT);
    let style = style.clamp(0, OPINION_STORY_TYPES.len() as i64 - 1);
    write_u32_be(misc, offset, OPINION_STORY_TYPES[style as usize]);
    write_u32_be(misc, offset + ARGUMENT_FIELD * 4, subject & 0xff);

    Ok(())
}

/// NewsQueue.update_story_substitutions.
pub fn update_story_substitutions(misc: &mut [u8], slot: i64, argument: i64, auxiliary: &[u8]) -> Result<(), String> {
    validate(misc)?;

    if !(0..STORY_RECORD_COUNT).contains(&slot) {
        return Err("newspaper story slot is out of range".to_string());
    }

    if auxiliary.len() != AUXILIARY_COUNT {
        return Err("newspaper story auxiliary data has the wrong size".to_string());
    }

    let offset = story_offset(slot);
    write_u32_be(misc, offset + ARGUMENT_FIELD * 4, argument & 0xff);

    for (index, value) in auxiliary.iter().enumerate() {
        write_u32_be(misc, offset + (FIRST_AUXILIARY_FIELD + index as i64) * 4, i64::from(*value));
    }

    Ok(())
}

/// One saved story record: type, priority, argument, and auxiliary values.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct StoryRecord {
    pub story_type: i64,
    pub priority: i64,
    pub argument: i64,
    pub auxiliary: [u8; AUXILIARY_COUNT],
}

/// NewsQueue.story_record.
pub fn story_record(misc: &[u8], slot: i64) -> Option<StoryRecord> {
    if validate(misc).is_err() || !(0..STORY_RECORD_COUNT).contains(&slot) {
        return None;
    }

    let offset = story_offset(slot);
    let field = |index: i64| read_u32_be(misc, offset + index * 4);

    Some(StoryRecord {
        story_type: to_i16(field(0)),
        priority: to_i16(field(1)),
        argument: field(ARGUMENT_FIELD) & 0xff,
        auxiliary: [0, 1, 2].map(|index| field(FIRST_AUXILIARY_FIELD + index) as u8),
    })
}

/// NewsQueue.paper_record: name, layout, price, opinion, and weather style.
pub fn paper_record(misc: &[u8], paper: i64) -> Option<[i64; PAPER_FIELD_COUNT as usize]> {
    if validate(misc).is_err() || !(0..PAPER_COUNT).contains(&paper) {
        return None;
    }

    Some([0, 1, 2, 3, 4].map(|field| read_u32_be(misc, paper_field_offset(paper, field)) & 0xff))
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

#[cfg(test)]
mod tests {
    use super::*;

    fn misc() -> Vec<u8> {
        vec![0u8; misc_layout::SIZE as usize]
    }

    #[test]
    fn a_session_takes_its_draws_in_order_and_clears_the_stories() {
        let mut first = misc();
        let mut calls = 0;
        initialize_session(&mut first, || {
            calls += 1;
            calls * 7
        })
        .expect("a valid MISC");
        assert_eq!(calls, SESSION_RANDOM_CALLS);

        let mut names: Vec<i64> = (0..PAPER_COUNT).map(|paper| paper_record(&first, paper).unwrap()[0]).collect();
        names.sort();
        assert_eq!(names, vec![0, 1, 2, 3, 4, 5], "the shuffle keeps each paper name once");

        let story = story_record(&first, 4).unwrap();
        assert_eq!(
            (story.story_type, story.priority, story.argument),
            (PLACEHOLDER_STORY_FIRST + 4, 0, 0)
        );
        assert_eq!(story.auxiliary, [0xff; 3]);

        let mut zero = misc();
        initialize_session(&mut zero, || 0).unwrap();
        let mut odd = misc();
        initialize_session(&mut odd, || 1).unwrap();
        assert_eq!(paper_record(&zero, 0).unwrap()[PAPER_OPINION_FIELD as usize], 3);
        assert_eq!(paper_record(&odd, 0).unwrap()[PAPER_OPINION_FIELD as usize], 4);
    }

    #[test]
    fn stories_insert_by_priority_and_decay() {
        let mut data = misc();
        initialize_session(&mut data, || 0).unwrap();
        assert_eq!(insert(&mut data, 6, 0x1ff), Ok((0, 360)));
        assert_eq!(insert(&mut data, 2, 9), Ok((0, 1000)));
        assert_eq!(insert(&mut data, 7, 1), Ok((2, 200)));
        assert_eq!(story_record(&data, 1).unwrap().argument, 0xff);

        decay_and_sort(&mut data).unwrap();
        let priorities: Vec<i64> = (0..3).map(|slot| story_record(&data, slot).unwrap().priority).collect();
        assert_eq!(priorities, vec![500, 350, 150]);
        assert!(insert(&mut data, STORY_PRIORITIES.len() as i64, 0).is_err());
    }

    #[test]
    fn the_opener_fills_the_weather_and_opinion_slots() {
        let mut data = misc();
        prepare_weather_report(&mut data, 0x103).unwrap();
        prepare_opinion_report(&mut data, 99, 4).unwrap();
        update_story_substitutions(&mut data, 2, 5, &[1, 2, 3]).unwrap();
        assert_eq!(story_record(&data, WEATHER_SLOT).unwrap().argument, 3);
        assert_eq!(story_record(&data, OPINION_SLOT).unwrap().story_type, 45);
        assert_eq!(story_record(&data, 2).unwrap().auxiliary, [1, 2, 3]);
        assert!(update_story_substitutions(&mut data, 9, 0, &[0; 3]).is_err());
        assert!(update_story_substitutions(&mut data, 0, 0, &[0; 2]).is_err());
        assert!(story_record(&data, 9).is_none() && paper_record(&[0; 4], 0).is_none());
    }

    fn result_with(items: &[(i64, i64)]) -> PhaseBase {
        PhaseBase {
            ok: true,
            news_items: items
                .iter()
                .map(|&(story_type, argument)| NewsEvent::new(story_type, argument))
                .collect(),
            ..PhaseBase::default()
        }
    }

    #[test]
    fn persistence_stores_stories_once_and_skips_notifications() {
        let mut city = crate::sim::testing::empty_city(128);
        let mut result = result_with(&[(0x1fe, 0), (9, 4)]);
        assert_eq!(persist(&mut city, &mut result), Ok(1));
        assert!(result.news_queue_updated && result.news_queue_inserted == 1);

        let story = story_record(&city.misc.data, 0).unwrap();
        assert_eq!((story.story_type, story.priority, story.argument), (9, 200, 4));

        let before = city.misc.data.clone();
        let mut again = result_with(&[(3, 0)]);
        again.news_queue_updated = true;
        assert_eq!(persist(&mut city, &mut again), Ok(0));
        assert_eq!(city.misc.data, before, "a stored result does not insert twice");
    }

    #[test]
    fn extra_editions_open_for_milestones_inventions_and_plants() {
        for extras in [0, 1] {
            for story_type in [3, 4, 5, 0x24, 2, 6, 0x25, 0x29] {
                let mut city = crate::sim::testing::empty_city(128);
                assert!(city.set_misc_u32(misc_layout::NEWSPAPER_EXTRAS, extras));

                let mut result = result_with(&[(story_type, 0)]);
                assert_eq!(persist(&mut city, &mut result), Ok(1));

                let expected = extras != 0 && ((3..=5).contains(&story_type) || story_type == 0x24);
                assert_eq!(result.newspaper_requested, expected, "story {story_type} with extras {extras}");
            }
        }
    }

    #[test]
    fn the_paper_count_follows_the_signed_progression() {
        assert_eq!([0, 2, 5, 9, 0xffff, 0x1_0002].map(available_paper_count), [1, 3, 6, 6, 0, 3]);
    }
}
