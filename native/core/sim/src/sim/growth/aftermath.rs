//! Monthly trees, news, inventions, and weather, as RciAftermathPhase.

use crate::gd_object;
use crate::gd_phase_result;
use crate::sim::bytes::{read_i32_be, read_u32_be, write_u32_be};
use crate::sim::city::City;
use crate::sim::events::NewsEvent;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::city_calendar::DAYS_PER_YEAR;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::phase::{PhaseResultLike, TimingSpan};
use crate::sim::random::SimRandom;
use crate::sim::reports::news;
use crate::sim::tools::network::replace_building;

const INVENTION_COUNT: i64 = 17;
const NEWS_JUNK: i64 = 0x01;
const NEWS_INVENTION: i64 = 0x04;
const NEWS_INNOVATION: i64 = 0x05;
const NEWS_WAR: i64 = 0x06;
const NEWS_MARKET: i64 = 0x07;
const NEWS_SPORTS: i64 = 0x08;
const NEWS_HIGH_CRIME: i64 = 0x10;
const NEWS_HIGH_TRAFFIC: i64 = 0x11;
const NEWS_HIGH_POLLUTION: i64 = 0x12;
const NEWS_POOR_EDUCATION: i64 = 0x13;
const NEWS_POOR_HEALTH: i64 = 0x14;
const NEWS_POOR_EMPLOYMENT: i64 = 0x15;
const NEWS_LOW_CRIME: i64 = 0x3d;
const NEWS_LOW_TRAFFIC: i64 = 0x3e;
const NEWS_LOW_POLLUTION: i64 = 0x3f;
const NEWS_GOOD_EDUCATION: i64 = 0x40;
const NEWS_GOOD_HEALTH: i64 = 0x41;
const NEWS_GOOD_EMPLOYMENT: i64 = 0x42;
const GRAPH_TRAFFIC: i64 = 4;
const GRAPH_POLLUTION: i64 = 5;
const GRAPH_CRIME: i64 = 7;
pub const WEATHER_NAMES: [&str; 12] = [
    "Cold",
    "Clear",
    "Hot",
    "Foggy",
    "Chilly",
    "Overcast",
    "Snow",
    "Rain",
    "Windy",
    "Blizzard",
    "Hurricane",
    "Tornado",
];
/// Four 12-by-8 season blocks. Each row is the current weather trend and each
/// column is the low three bits of the process-random value.
const WEATHER_TRANSITIONS: [i64; 384] = [
    0, 0, 0, 3, 4, 5, 1, 8, 1, 1, 1, 0, 0, 3, 4, 8, 2, 1, 1, 1, 8, 8, 5, 3, 3, 3, 0, 1, 4, 5, 8, 7, 4, 4, 0, 1, 4, 5, 7, 6, 5, 5, 1, 4, 3,
    7, 7, 8, 6, 6, 7, 7, 5, 4, 0, 9, 7, 7, 7, 6, 8, 8, 4, 3, 8, 8, 8, 7, 7, 5, 4, 4, 9, 6, 6, 6, 6, 7, 7, 3, 7, 7, 6, 6, 7, 7, 7, 8, 8, 8,
    8, 8, 8, 7, 6, 4, // season 0
    0, 0, 0, 1, 1, 1, 3, 4, 1, 1, 1, 1, 2, 2, 0, 4, 2, 2, 2, 1, 1, 5, 4, 3, 3, 3, 0, 8, 1, 1, 4, 7, 4, 4, 4, 1, 8, 0, 5, 3, 5, 5, 5, 7, 2,
    4, 1, 8, 6, 7, 7, 7, 3, 8, 5, 5, 7, 7, 7, 6, 3, 5, 8, 10, 8, 8, 8, 7, 5, 4, 1, 1, 7, 6, 6, 7, 7, 8, 8, 4, 10, 7, 7, 7, 8, 8, 4, 4, 8,
    8, 8, 8, 8, 4, 1, 2, // season 1
    0, 0, 0, 1, 1, 1, 3, 4, 1, 1, 1, 1, 2, 2, 0, 4, 2, 2, 2, 1, 1, 5, 4, 3, 3, 3, 0, 8, 1, 1, 4, 7, 4, 4, 4, 1, 8, 0, 5, 3, 5, 5, 5, 7, 2,
    4, 1, 8, 6, 7, 7, 7, 3, 8, 5, 4, 7, 7, 7, 6, 3, 5, 8, 8, 8, 8, 8, 7, 5, 4, 1, 11, 7, 6, 6, 7, 7, 8, 8, 4, 6, 7, 7, 7, 8, 8, 4, 4, 11,
    8, 8, 8, 8, 4, 1, 2, // season 2
    0, 0, 0, 3, 4, 5, 1, 8, 1, 1, 1, 0, 0, 3, 4, 8, 2, 1, 1, 1, 8, 8, 5, 3, 3, 3, 0, 1, 4, 5, 8, 7, 4, 4, 0, 1, 4, 5, 7, 6, 5, 5, 1, 4, 3,
    7, 7, 8, 6, 6, 7, 7, 5, 4, 0, 0, 7, 7, 7, 6, 8, 4, 3, 10, 8, 8, 8, 7, 7, 5, 4, 5, 6, 6, 6, 6, 7, 7, 7, 3, 10, 7, 6, 6, 7, 7, 7, 8, 8,
    8, 8, 8, 8, 7, 6, 4, // season 3
];
const WEATHER_HEAT_TARGETS: [i64; 12] = [80, 165, 210, 100, 145, 175, 80, 150, 175, 60, 140, 175];
const WEATHER_WIND_TARGETS: [i64; 12] = [15, 30, 0, 0, 15, 5, 10, 30, 60, 100, 100, 100];
const WEATHER_RAIN_TARGETS: [i64; 12] = [0, 0, 0, 15, 15, 15, 30, 30, 30, 60, 60, 60];

gd_object! {
    pub struct MapChange as "RciAftermathPhase.MapChange" {
        pub point: Vec2i = Vec2i::ZERO,
        pub old_tile: i64 = 0,
        pub new_tile: i64 = 0,
    }
}

gd_phase_result! {
    pub struct AftermathResult as "RciAftermathPhase.Result" {
        pub season: i64 = 0,
        pub old_weather_trend: i64 = 0,
        pub weather_trend: i64 = 0,
        pub weather_name: String = String::new(),
        pub weather_roll: i64 = 0,
        pub heat: i64 = 0,
        pub wind: i64 = 0,
        pub rain: i64 = 0,
        pub map_changes: Vec<MapChange> = Vec::new(),
        pub map_changed: bool = false,
        pub invention_index: i64 = -1,
    }
}

pub fn weather_transition(current_trend: i64, season: i64, roll: i64) -> i64 {
    if !(0..12).contains(&current_trend) || !(0..4).contains(&season) {
        return -1;
    }

    WEATHER_TRANSITIONS[((season * 12 + current_trend) * 8 + (roll & 7)) as usize]
}

fn to_i16(value: i64) -> i64 {
    let word = value & 0xffff;

    if word & 0x8000 != 0 { word - 0x10000 } else { word }
}

/// RciAftermathPhase.run.
pub fn run(city: &mut City, random: &mut SimRandom, season: i64) -> AftermathResult {
    let cells = city.tile_count() as usize;

    if !(0..=3).contains(&season) {
        return AftermathResult::failed("weather season is out of range");
    }

    if !city.misc.present || city.misc.data.len() as i64 != misc_layout::SIZE {
        return AftermathResult::failed("MISC is missing or has the wrong size");
    }

    for (chunk, id) in [(&city.xbld, "XBLD"), (&city.xzon, "XZON"), (&city.xbit, "XBIT")] {
        if !chunk.present || chunk.data.len() != cells {
            return AftermathResult::failed(format!("{id} is missing or has the wrong size"));
        }
    }

    if !city.xgrp.present || city.xgrp.data.len() != 16 * 52 * 4 {
        return AftermathResult::failed("XGRP is missing or has the wrong size");
    }

    let mut span = TimingSpan::new();
    span.mark("prepare data");
    let mut misc = city.misc.data.clone();
    let mut buildings = city.xbld.data.clone();
    let mut map_changes = Vec::new();
    span.mark("random tree");
    update_random_tree(
        city.map_size,
        random,
        &mut buildings,
        &city.xzon.data,
        &city.xbit.data,
        &mut misc,
        &mut map_changes,
    );
    span.mark("news decay and selection");

    if let Err(message) = news::decay_and_sort(&mut misc) {
        return AftermathResult::failed(message);
    }

    let mut news_items = vec![NewsEvent::new(NEWS_JUNK, 0)];
    append_general_news(random, &misc, &city.xgrp.data, &mut news_items, city.map_size);
    span.mark("inventions");
    let invention_index = release_invention(city.age_in_days(), random, &mut misc, &mut news_items);

    if invention_index >= 0 {
        crate::sim::civic::milestones::rebuild_reward_mask(&mut misc);
    }

    span.mark("weather");
    let old_trend = read_u32_be(&misc, misc_layout::WEATHER_TREND) & 0xff;

    if old_trend >= WEATHER_NAMES.len() as i64 {
        return AftermathResult::failed("weather trend is out of range");
    }

    let weather_roll = random.next_u15() & 7;
    let new_trend = weather_transition(old_trend, season, weather_roll);
    let trend = new_trend as usize;
    let heat = ((read_u32_be(&misc, misc_layout::WEATHER_HEAT) & 0xff) + WEATHER_HEAT_TARGETS[trend]) / 2;
    let wind = ((read_u32_be(&misc, misc_layout::WEATHER_WIND) & 0xff) + WEATHER_WIND_TARGETS[trend]) / 2;
    let rain = ((read_u32_be(&misc, misc_layout::WEATHER_RAIN) & 0xff) + WEATHER_RAIN_TARGETS[trend]) / 2;
    write_u32_be(&mut misc, misc_layout::WEATHER_HEAT, heat);
    write_u32_be(&mut misc, misc_layout::WEATHER_WIND, wind);
    write_u32_be(&mut misc, misc_layout::WEATHER_RAIN, rain);
    write_u32_be(&mut misc, misc_layout::WEATHER_TREND, new_trend);
    span.mark("news insertion");

    if let Err(message) = news::insert_items(&mut misc, &news_items) {
        return AftermathResult::failed(message);
    }

    span.mark("store monthly changes");

    // A month without tree growth must not bump the XBLD revision. The render
    // change signature reads that revision instead of hashing the whole map.
    if buildings != city.xbld.data {
        city.xbld.replace(buildings);
    }

    city.misc.replace(misc);
    let mut result = AftermathResult {
        season,
        old_weather_trend: old_trend,
        weather_trend: new_trend,
        weather_name: WEATHER_NAMES[trend].to_string(),
        weather_roll,
        heat,
        wind,
        rain,
        map_changed: !map_changes.is_empty(),
        map_changes,
        invention_index,
        ..Default::default()
    };
    result.base_mut().ok = true;
    result.base_mut().news_items = news_items;
    result.base_mut().news_queue_updated = true;
    result.base_mut().timing = span.finish();
    result
}

fn update_random_tree(
    map_edge: i64,
    random: &mut SimRandom,
    buildings: &mut [u8],
    zones: &[u8],
    flags: &[u8],
    misc: &mut [u8],
    map_changes: &mut Vec<MapChange>,
) {
    let x = random.next_u15() % map_edge;
    let y = random.next_u15() % map_edge;
    let mut point = Vec2i::new(x, y);
    let mut index = point.x * map_edge + point.y;
    let mut old_tile = buildings[index as usize] as i64;

    if old_tile == tiles::RADIOACTIVE_WASTE && random.next_u15() & 0x0f == 0 {
        replace_building(buildings, zones, misc, index, tiles::EMPTY);
        map_changes.push(MapChange {
            point,
            old_tile,
            new_tile: tiles::EMPTY,
        });
    }

    if flags[index as usize] as i64 & flag_bits::WATER != 0 {
        return;
    }

    let tree = (tiles::TREE_FIRST..=tiles::SMALL_PARK).contains(&old_tile);

    if !tree && random.next_u15() & 0x0f != 0 {
        return;
    }

    if (tiles::TREE_FIRST..=tiles::TREES_6).contains(&old_tile) {
        replace_building(buildings, zones, misc, index, old_tile + 1);
        map_changes.push(MapChange {
            point,
            old_tile,
            new_tile: old_tile + 1,
        });
    }

    match random.next_u15() & 3 {
        0 => point.x = (point.x + 1).min(map_edge - 1),
        1 => point.x = (point.x - 1).max(0),
        2 => point.y = (point.y + 1).min(map_edge - 1),
        _ => point.y = (point.y - 1).max(0),
    }

    index = point.x * map_edge + point.y;
    old_tile = buildings[index as usize] as i64;

    if flags[index as usize] as i64 & flag_bits::WATER != 0 || old_tile >= tiles::TREES_7 || old_tile == tiles::RADIOACTIVE_WASTE {
        return;
    }

    let new_tile = if old_tile < tiles::TREE_FIRST {
        tiles::TREE_FIRST
    } else {
        old_tile + 1
    };
    replace_building(buildings, zones, misc, index, new_tile);
    map_changes.push(MapChange { point, old_tile, new_tile });
}

fn append_general_news(random: &mut SimRandom, misc: &[u8], graphs: &[u8], news_items: &mut Vec<NewsEvent>, map_edge: i64) {
    match random.next_u15() % 6 {
        0 => {
            if random.next_u15() & 3 == 0 {
                news_items.push(NewsEvent::new(NEWS_WAR, 0));
            }

            if random.next_u15() & 3 == 0 {
                let trend = read_u32_be(misc, misc_layout::NATIONAL_ECONOMY_TREND) & 0xffff;
                news_items.push(NewsEvent::new(NEWS_MARKET, trend));
            }
        }
        choice => news_items.push(NewsEvent::new(0x0a + choice, 0)),
    }

    let stadium_tiles = read_u32_be(misc, misc_layout::TILE_COUNTS + tiles::STADIUM * 4);

    if (if map_edge == 128 { to_i16(stadium_tiles) } else { stadium_tiles }) > 0 {
        let team = random.next_u15() % 5;

        if to_i16(read_u32_be(misc, misc_layout::STADIUM_TEAMS)) & (1 << team) != 0 {
            news_items.push(NewsEvent::new(NEWS_SPORTS, team));
        }
    }

    for (series, high, low) in [
        (GRAPH_TRAFFIC, NEWS_HIGH_TRAFFIC, NEWS_LOW_TRAFFIC),
        (GRAPH_POLLUTION, NEWS_HIGH_POLLUTION, NEWS_LOW_POLLUTION),
        (GRAPH_CRIME, NEWS_HIGH_CRIME, NEWS_LOW_CRIME),
    ] {
        let value = read_i32_be(graphs, series * 52 * 4);

        if random.next_u15() & 0x7f < value {
            news_items.push(NewsEvent::new(high, 0));
        }

        if value < random.next_u15() & 0x0f {
            news_items.push(NewsEvent::new(low, 0));
        }
    }

    let unemployment = read_i32_be(misc, misc_layout::UNEMPLOYMENT);

    if random.next_u15() & 0x3f < unemployment {
        news_items.push(NewsEvent::new(NEWS_POOR_EMPLOYMENT, 0));
    }

    if unemployment < random.next_u15() & 3 {
        news_items.push(NewsEvent::new(NEWS_GOOD_EMPLOYMENT, 0));
    }

    let education = read_u32_be(misc, misc_layout::WORKFORCE_EDUCATION);
    let education_roll = random.next_u15() % 80;

    if education < 80 {
        if education < education_roll {
            news_items.push(NewsEvent::new(NEWS_POOR_EDUCATION, 0));
        }
    } else if education_roll < education - 80 {
        news_items.push(NewsEvent::new(NEWS_GOOD_EDUCATION, 0));
    }

    let health = read_u32_be(misc, misc_layout::WORKFORCE_LIFE_EXPECTANCY);
    let health_roll = random.next_u15() % 60;

    if health < 60 {
        if health < health_roll {
            news_items.push(NewsEvent::new(NEWS_POOR_HEALTH, 0));
        }
    } else if health_roll < health - 60 {
        news_items.push(NewsEvent::new(NEWS_GOOD_HEALTH, 0));
    }
}

fn release_invention(age_in_days: i64, random: &mut SimRandom, misc: &mut [u8], news_items: &mut Vec<NewsEvent>) -> i64 {
    if random.next_u15() & 7 != 0 {
        return -1;
    }

    let current_year = to_i16(read_u32_be(misc, misc_layout::START_YEAR)) + age_in_days / DAYS_PER_YEAR;

    for index in 0..INVENTION_COUNT {
        let offset = misc_layout::INVENTION_YEARS + index * 4;
        let year = to_i16(read_u32_be(misc, offset));

        if year == 0 || year > current_year {
            continue;
        }

        let (news_type, argument) = if index < 7 {
            (NEWS_INVENTION, index)
        } else {
            (NEWS_INNOVATION, index - 7)
        };
        news_items.push(NewsEvent::new(news_type, argument));
        write_u32_be(misc, offset, 0);

        return index;
    }

    -1
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::bytes::write_u32_be;
    use crate::sim::testing::{empty_city, sequence_random};

    /// Sports news reads the stadium count at the width of the map.
    #[test]
    fn sports_news_uses_the_wide_stadium_count() {
        for edge in [16i64, 32, 64, 128, 256, 384, 512, 640, 1024] {
            let mut city = empty_city(edge);
            write_u32_be(&mut city.misc.data, misc_layout::TILE_COUNTS + tiles::STADIUM * 4, 40000);
            write_u32_be(&mut city.misc.data, misc_layout::STADIUM_TEAMS, 1);
            let mut news = Vec::new();
            append_general_news(&mut sequence_random(&[0]), &city.misc.data, &city.xgrp.data, &mut news, edge);
            let sports = news.iter().any(|item| item.type_ == NEWS_SPORTS && item.argument == 0);
            assert_eq!(sports, edge != 128);
        }
    }
}
