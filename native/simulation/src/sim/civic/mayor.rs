//! Mayor approval and the tile recount, as MayorApprovalPhase and CityTileCounts.

use crate::gd_phase_result;
use crate::sim::bytes::{read_i32_be, read_u16_be, read_u32_be, write_u16_be};
use crate::sim::city::City;
use crate::sim::events::NewsEvent;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2budget_layout as budget;
use crate::sim::ids::sc2graph_layout as graph_layout;
use crate::sim::ids::sc2microsim_layout as microsim;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::random::SimRandom;
use crate::sim::value::Ints32;

const GRAPH_TRAFFIC: i64 = 4;
const GRAPH_POLLUTION: i64 = 5;
const GRAPH_LAND_VALUE: i64 = 6;
const GRAPH_CRIME: i64 = 7;
const NEWS_HIGH_APPROVAL: i64 = 0x201;

gd_phase_result! {
    pub struct MayorApprovalResult as "MayorApprovalPhase.Result" {
        pub approval: i64 = 0,
        pub previous_approval: i64 = 0,
        pub weights: Ints32 = Ints32::default(),
        pub survey_counts: Ints32 = Ints32::default(),
        pub ranking: Ints32 = Ints32::default(),
        pub updated_mayor_house_records: i64 = 0,
    }
}

fn to_i16(value: i64) -> i64 {
    let wrapped = value & 0xffff;

    if wrapped >= 0x8000 { wrapped - 0x10000 } else { wrapped }
}

fn graph_current(graphs: &[u8], graph_id: i64) -> i64 {
    read_u32_be(graphs, graph_id * graph_layout::VALUES_PER_SERIES * graph_layout::VALUE_SIZE)
}

fn inputs_are_valid(city: &City) -> bool {
    city.misc.present
        && city.misc.data.len() as i64 == misc_layout::SIZE
        && city.xgrp.present
        && city.xgrp.data.len() as i64 == graph_layout::SIZE
}

/// MayorApprovalPhase.complaint_weights. Empty when MISC or XGRP is invalid.
pub fn complaint_weights(city: &City) -> Vec<i64> {
    if !inputs_are_valid(city) {
        return Vec::new();
    }

    let misc = &city.misc.data;
    let graphs = &city.xgrp.data;
    let funding = read_i32_be(
        misc,
        misc_layout::BUDGETS + budget::RESIDENTIAL * budget::RECORD_SIZE + budget::FUNDING,
    );

    vec![
        to_i16(graph_current(graphs, GRAPH_TRAFFIC)),
        to_i16(graph_current(graphs, GRAPH_POLLUTION)),
        to_i16(graph_current(graphs, GRAPH_CRIME)),
        to_i16(read_u32_be(misc, misc_layout::UNEMPLOYMENT)),
        to_i16(funding * 3),
        (100 - to_i16(read_u32_be(misc, misc_layout::WORKFORCE_EDUCATION))).max(0),
        (70 - to_i16(read_u32_be(misc, misc_layout::WORKFORCE_LIFE_EXPECTANCY))).max(0),
    ]
}

/// MayorApprovalPhase.run.
pub fn run(city: &mut City, random: &mut SimRandom, previous_approval: i64) -> MayorApprovalResult {
    if !inputs_are_valid(city) || !city.xmic.present || city.xmic.data.len() as i64 != city.decoded_size("XMIC") {
        return MayorApprovalResult::failed("MISC, XGRP, or XMIC has the wrong size");
    }

    let weights = complaint_weights(city);
    let mut total = to_i16(graph_current(&city.xgrp.data, GRAPH_LAND_VALUE)) + 50;

    for weight in &weights {
        total = to_i16(total + weight);
    }

    let mut approval = to_i16(previous_approval);
    let mut survey_counts = [0i64; 7];

    if total != 0 && read_u32_be(&city.misc.data, misc_layout::NORMAL_POPULATION) > 99 {
        approval = 0;

        for _ in 0..100 {
            let mut selection = random.next_u15() % total;
            let mut category = 0;

            while category < weights.len() {
                if to_i16(selection) < weights[category] {
                    break;
                }

                selection = to_i16(selection - weights[category]) & 0xffff;
                category += 1;
            }

            if category == weights.len() {
                approval += 1;
            } else {
                survey_counts[category] += 1;
            }
        }
    }

    let microsims = city.xmic.mutate();
    let mut updated_records = 0;

    for record in 1..microsims.len() as i64 / microsim::RECORD_SIZE {
        let offset = record * microsim::RECORD_SIZE;

        if microsims[(offset + microsim::TILE_ID) as usize] as i64 != tiles::MAYOR_HOUSE {
            continue;
        }

        write_u16_be(microsims, offset + microsim::STAT_2, approval);
        let remaining = read_u16_be(microsims, offset + microsim::STAT_3);

        if remaining != 0 {
            write_u16_be(microsims, offset + microsim::STAT_3, remaining - 1);
            let stat = (offset + microsim::STAT_0) as usize;
            microsims[stat] = microsims[stat].wrapping_add(1);
        }

        updated_records += 1;
    }

    let mut ranking = [0usize, 1, 2, 3, 4, 5, 6];

    for end in (1..ranking.len()).rev() {
        for index in 0..end {
            if survey_counts[ranking[index]] < survey_counts[ranking[index + 1]] {
                ranking.swap(index, index + 1);
            }
        }
    }

    let mut result = MayorApprovalResult {
        approval,
        previous_approval,
        weights: Ints32(weights.iter().map(|value| *value as i32).collect()),
        survey_counts: Ints32(survey_counts.iter().map(|value| *value as i32).collect()),
        ranking: Ints32(ranking.iter().map(|value| *value as i32).collect()),
        updated_mayor_house_records: updated_records,
        ..Default::default()
    };
    result.base.ok = true;

    if previous_approval < 80 && approval > 79 {
        result.base.news_items.push(NewsEvent::new(NEWS_HIGH_APPROVAL, 0));
    }

    result
}

/// CityTileCounts.recount: store the tiles of each building ID outside military
/// zones. Only changed values are written. Returns the changed count, or -1
/// when MISC is too short.
/// The tiles of each building ID outside military zones. Military bases keep
/// separate counts.
pub fn building_counts(buildings: &[u8], zones: &[u8]) -> [i64; tiles::COUNT as usize] {
    let mut counts = [0i64; tiles::COUNT as usize];

    for (building, zone_byte) in buildings.iter().zip(zones) {
        if *zone_byte as i64 & zone::TYPE_MASK != zone::MILITARY {
            counts[*building as usize] += 1;
        }
    }

    counts
}

pub fn recount_tiles(city: &mut City) -> i64 {
    let count_end = misc_layout::TILE_COUNTS + tiles::COUNT * 4;

    if !city.misc.present || (city.misc.data.len() as i64) < count_end {
        return -1;
    }

    let counts = building_counts(&city.xbld.data, &city.xzon.data);
    let mut changed = 0;

    for (tile, count) in counts.iter().enumerate() {
        let offset = misc_layout::TILE_COUNTS + tile as i64 * 4;

        if read_u32_be(&city.misc.data, offset) != *count {
            city.set_misc_u32(offset, *count);
            changed += 1;
        }
    }

    changed
}
