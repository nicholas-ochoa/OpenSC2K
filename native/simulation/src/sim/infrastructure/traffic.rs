//! Monthly traffic decay, as TrafficPhase.

use crate::gd_phase_result;
use crate::sim::city::City;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::phase::{PhaseResultLike, TimingSpan};

gd_phase_result! {
    pub struct TrafficResult as "TrafficPhase.Result" {
        pub traffic_count: i64 = 0,
    }
}

pub fn run(city: &mut City) -> TrafficResult {
    if !city.xtrf.present || city.xtrf.data.len() as i64 != city.decoded_size("XTRF") {
        return TrafficResult::failed("XTRF is missing or has the wrong size");
    }

    let mut span = TimingSpan::new();
    span.mark("copy traffic map");
    let mut traffic = city.xtrf.data.clone();
    let mut total = 0i64;
    span.mark("decay and sum traffic");

    for (index, value) in traffic.iter_mut().enumerate() {
        if index & 1023 == 0 {
            crate::sim::budget::checkpoint();
        }

        let decayed = *value - (*value >> 2);
        *value = decayed;
        total += decayed as i64;
    }

    span.mark("normalize total");

    if city.full_resolution_maps() {
        total /= 4;
    }

    span.mark("store traffic map and total");

    // Decay leaves an empty map unchanged. A redundant write would repaint the
    // city, because the render change signature reads the XTRF revision.
    if traffic != city.xtrf.data {
        city.xtrf.replace(traffic);
    }

    city.set_misc_u32(misc_layout::CITY_TRAFFIC, total);
    let mut result = TrafficResult { traffic_count: total, ..Default::default() };
    result.base_mut().ok = true;
    result.base_mut().timing = span.finish();
    result
}
