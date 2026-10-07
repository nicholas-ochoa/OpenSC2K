//! The city sounds at the start of each moving-thing tick. SIMCITY.EXE
//! 0x00450890 plays the traffic sound and the police siren at random, from
//! the current traffic and crime graph values, before it updates the records.

use crate::sim::bytes::read_i32_be;
use crate::sim::city::City;
use crate::sim::events::SoundEvent;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2graph_layout as graph;
use crate::sim::ids::sc2misc_layout as misc;
use crate::sim::random::SimRandom;

pub const TRAFFIC_SOUND: i64 = 521;
pub const SIREN_SOUND: i64 = 506;

/// The traffic graph value above which the traffic sound can play.
const TRAFFIC_LEVEL: i64 = 0x23;

/// The crime graph value above which the siren can play.
const CRIME_LEVEL: i64 = 0x28;

const GRAPH_TRAFFIC: i64 = 4;
const GRAPH_CRIME: i64 = 7;

/// A sound plays when the low byte of a process random value is 0.
const CHANCE_MASK: i64 = 0xff;

/// The current value of a graph series, or 0 without a valid XGRP.
fn graph_current(city: &City, series: i64) -> i64 {
    if !city.xgrp.present || city.xgrp.data.len() as i64 != graph::SIZE {
        return 0;
    }

    read_i32_be(
        &city.xgrp.data,
        series * graph::SERIES_SIZE + graph::YEAR_OFFSET * graph::VALUE_SIZE,
    )
}

/// The city sounds of one tick. Each check draws a process random value only
/// when its condition holds, as the original does.
pub fn sounds(city: &City, random: &mut SimRandom) -> Vec<SoundEvent> {
    let mut result = Vec::new();

    if graph_current(city, GRAPH_TRAFFIC) > TRAFFIC_LEVEL && random.next_u15() & CHANCE_MASK == 0 {
        result.push(SoundEvent::new(TRAFFIC_SOUND));
    }

    let police_stations = city.misc_i32(misc::TILE_COUNTS + tiles::POLICE_STATION * 4);

    if police_stations != 0 && graph_current(city, GRAPH_CRIME) > CRIME_LEVEL && random.next_u15() & CHANCE_MASK == 0 {
        result.push(SoundEvent::new(SIREN_SOUND));
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::bytes::write_u32_be;
    use crate::sim::testing::empty_city;

    fn city_with(traffic: i64, crime: i64, police_tiles: i64) -> City {
        let mut city = empty_city(128);
        let graphs = city.xgrp.mutate();
        write_u32_be(graphs, GRAPH_TRAFFIC * graph::SERIES_SIZE, traffic);
        write_u32_be(graphs, GRAPH_CRIME * graph::SERIES_SIZE, crime);
        assert!(city.set_misc_u32(misc::TILE_COUNTS + tiles::POLICE_STATION * 4, police_tiles));

        city
    }

    /// A seed whose first draw has a low byte of 0.
    fn lucky_seed() -> i64 {
        (1..)
            .find(|seed| SimRandom::new(*seed).next_u15() & CHANCE_MASK == 0)
            .expect("a seed")
    }

    /// The sounds of one tick and the count of its random draws.
    fn tick(city: &City, seed: i64) -> (Vec<i64>, i64) {
        let mut random = SimRandom::new(seed);
        let sounds = sounds(city, &mut random).iter().map(|event| event.sound_id).collect();
        let mut reference = SimRandom::new(seed);
        let mut draws = 0;

        while reference.state != random.state {
            reference.next_u15();
            draws += 1;
            assert!(draws <= 2, "a tick draws at most two values");
        }

        (sounds, draws)
    }

    #[test]
    fn busy_and_unsafe_cities_make_noise() {
        let seed = lucky_seed();
        let busy = city_with(TRAFFIC_LEVEL + 1, CRIME_LEVEL, 9);
        assert_eq!(tick(&busy, seed), (vec![TRAFFIC_SOUND], 1));

        let unsafe_city = city_with(TRAFFIC_LEVEL, CRIME_LEVEL + 1, 9);
        assert_eq!(tick(&unsafe_city, seed), (vec![SIREN_SOUND], 1));

        let both = city_with(TRAFFIC_LEVEL + 1, CRIME_LEVEL + 1, 9);
        assert_eq!(tick(&both, seed + 1).1, 2, "each sound has its own draw");
        assert_eq!(tick(&both, seed).0.first(), Some(&TRAFFIC_SOUND));
    }

    #[test]
    fn quiet_cities_draw_no_random_values() {
        let seed = lucky_seed();
        assert_eq!(tick(&city_with(TRAFFIC_LEVEL, CRIME_LEVEL, 9), seed), (vec![], 0));
        assert_eq!(
            tick(&city_with(TRAFFIC_LEVEL, CRIME_LEVEL + 1, 0), seed),
            (vec![], 0),
            "the siren needs a police station"
        );
    }
}
