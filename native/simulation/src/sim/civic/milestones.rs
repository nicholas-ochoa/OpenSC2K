//! Population milestones and rewards, as MilestonePhase.

use crate::gd_phase_result;
use crate::sim::bytes::{read_u32_be, write_u32_be};
use crate::sim::city::City;
use crate::sim::events::NewsEvent;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::phase::PhaseResultLike;

const NEWS_GROWTH: i64 = 3;
const PROGRESSION_REQUIREMENTS: [i64; 10] = [2000, 10000, 30000, 60000, 90000, 120000, 500000, 1000000, 5000000, 10000000];
const ARCOLOGY_FIRST_INVENTION: i64 = 12;
const ARCOLOGY_LAST_INVENTION: i64 = 15;

gd_phase_result! {
    pub struct MilestoneResult as "MilestonePhase.Result" {
        pub advanced: bool = false,
        pub old_progression: i64 = 0,
        pub progression: i64 = 0,
        pub population: i64 = 0,
        pub requirement: i64 = 0,
        pub reward_id: i64 = -1,
        pub military_proposal_pending: bool = false,
    }
}

/// ToolAvailability.rebuild_reward_mask: arcologies become available after the
/// sixth milestone once one of them is invented.
pub fn rebuild_reward_mask(misc: &mut [u8]) -> i64 {
    if misc.len() as i64 != misc_layout::SIZE {
        return 0;
    }

    let mut mask = read_u32_be(misc, misc_layout::GRANTED_REWARDS);
    let progression = read_u32_be(misc, misc_layout::PROGRESSION) & 0xffff;
    let arcology_count = (ARCOLOGY_FIRST_INVENTION..=ARCOLOGY_LAST_INVENTION)
        .filter(|index| read_u32_be(misc, misc_layout::INVENTION_YEARS + index * 4) & 0xffff == 0)
        .count();

    if progression >= 6 && arcology_count > 0 {
        mask |= 0x10;
    }

    write_u32_be(misc, misc_layout::GRANTED_REWARDS, mask);
    mask
}

/// MilestonePhase.run.
pub fn run(city: &mut City) -> MilestoneResult {
    if !city.misc.present || city.misc.data.len() as i64 != misc_layout::SIZE {
        return MilestoneResult::failed("MISC is missing or has the wrong size");
    }

    let mut misc = city.misc.data.clone();
    let mut progression = read_u32_be(&misc, misc_layout::PROGRESSION) & 0xffff;
    let population = read_u32_be(&misc, misc_layout::NORMAL_POPULATION);
    let mut result = MilestoneResult { old_progression: progression, progression, population, ..Default::default() };
    result.base_mut().ok = true;

    if progression >= PROGRESSION_REQUIREMENTS.len() as i64 {
        return result;
    }

    let requirement = PROGRESSION_REQUIREMENTS[progression as usize];
    result.requirement = requirement;

    if population <= requirement {
        return result;
    }

    let old_progression = progression;
    progression += 1;
    write_u32_be(&mut misc, misc_layout::PROGRESSION, progression);
    let mut reward_id = -1;
    let mut military_proposal_pending = false;

    if progression < 4 {
        reward_id = progression - 1;
    } else if progression == 4 {
        military_proposal_pending = true;
    } else if progression == 5 {
        reward_id = 3;
    }

    if reward_id >= 0 {
        let rewards = read_u32_be(&misc, misc_layout::GRANTED_REWARDS);
        write_u32_be(&mut misc, misc_layout::GRANTED_REWARDS, rewards | (1 << reward_id));
    }

    rebuild_reward_mask(&mut misc);
    city.misc.replace(misc);
    result.advanced = true;
    result.progression = progression;
    result.reward_id = reward_id;
    result.military_proposal_pending = military_proposal_pending;
    result.base.news_items = vec![NewsEvent::new(NEWS_GROWTH, old_progression)];
    result.base.complete = !military_proposal_pending;
    result
}
