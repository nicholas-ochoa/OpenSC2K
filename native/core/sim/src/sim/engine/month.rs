//! Month start and the monthly music choice, as MonthStartPhase,
//! MonthlyMusicResult, and MusicDirector.monthly_track.

use crate::gd_phase_result;
use crate::sim::bytes::write_u32_be;
use crate::sim::city::City;
use crate::sim::ids::city_calendar::{DAYS_PER_MONTH, MONTHS_PER_YEAR};
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::phase::PhaseResultLike;
use crate::sim::random::SimRandom;
use crate::sim::value::Ints32;

const ZONE_POPULATION_COUNT: i64 = 8;
/// The original opens the subscribed newspaper after the April and August budget.
const SUBSCRIPTION_MONTHS: [i64; 2] = [3, 7];
pub const FIRST_TRACK_ID: i64 = 10000;
pub const TRACK_COUNT: i64 = 19;

gd_phase_result! {
    pub struct MonthStartResult as "MonthStartPhase.Result" {
        pub cleared_population_fields: i64 = 0,
    }
}

gd_phase_result! {
    /// The monthly MIDI gate. Active playback skips the selection and its draw.
    pub struct MonthlyMusicResult as "MonthlyMusicResult" {
        pub playback_was_active: bool = false,
        pub selection_attempted: bool = false,
    }
}

/// MonthStartPhase.run.
pub fn month_start(city: &mut City) -> MonthStartResult {
    if !city.misc.present || city.misc.data.len() as i64 != misc_layout::SIZE {
        return MonthStartResult::failed("MISC is missing or has the wrong size");
    }

    let misc = city.misc.mutate();

    for index in 0..ZONE_POPULATION_COUNT {
        write_u32_be(misc, misc_layout::ZONE_POPULATIONS + index * 4, 0);
    }

    let month = (city.age_in_days() / DAYS_PER_MONTH) % MONTHS_PER_YEAR;
    let mut result = MonthStartResult {
        cleared_population_fields: ZONE_POPULATION_COUNT,
        ..Default::default()
    };
    result.base_mut().ok = true;
    result.base_mut().newspaper_requested = city.misc_u32(misc_layout::NEWSPAPER_SUBSCRIPTION) != 0 && SUBSCRIPTION_MONTHS.contains(&month);
    result
}

/// MusicDirector.monthly_track. -1 means no new track.
pub fn monthly_track(speed: i64, playback_active: bool, random: &mut SimRandom) -> i64 {
    if playback_active {
        return -1;
    }

    let effective_speed = if speed == 1 { 2 } else { speed };
    let divisor = (effective_speed * 3 - 3) * 8;

    if divisor <= 0 || random.next_u15() % divisor != 0 {
        return -1;
    }

    FIRST_TRACK_ID + random.next_u15() % TRACK_COUNT
}

pub fn music_result(was_active: bool, requests: Vec<i32>) -> MonthlyMusicResult {
    let mut result = MonthlyMusicResult {
        playback_was_active: was_active,
        selection_attempted: !was_active,
        ..Default::default()
    };
    result.base.ok = true;
    result.base.music_track_requests = Ints32(requests);
    result
}
