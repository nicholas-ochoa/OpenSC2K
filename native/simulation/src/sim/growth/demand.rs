//! RCI demand and industries, as RciDemandPhase and IndustryPhase.

use crate::gd_phase_result;
use crate::sim::bytes::{read_u32_be, write_u32_be};
use crate::sim::city::City;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::ordinance_ids as ordinances;
use crate::sim::ids::sc2budget_layout;
use crate::sim::ids::sc2industry_layout as industry_layout;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2overlay_layout;
use crate::sim::overlay;
use crate::sim::phase::{PhaseResultLike, TimingSpan};
use crate::sim::random::{SimLfsrRandom, SimRandom};
use crate::sim::value::{Ints32, Ints64};

const RATIO_SCALE: f64 = 600.0;
/// The GDScript literal 0.000006666666666666667. The Godot parser does not
/// round it to the nearest double, so keep its exact bits.
const COMMERCIAL_SCALE: f64 = f64::from_bits(0x3edb_f647_612f_17d7);
const INDUSTRIAL_MIX_SCALE: f64 = 0.01;
const MINIMUM_INDUSTRIAL_TARGET: f64 = 15.0;
const TAX_EFFECT: [i64; 23] =
    [200, 160, 120, 100, 75, 50, 25, 0, -25, -50, -100, -150, -200, -250, -300, -350, -400, -450, -500, -550, -600, -650, -700];
const INDUSTRIAL_DIFFICULTY: [f64; 4] = [0.0, 1.2, 1.1, 0.95];
const COMMERCE_CONNECTION_RANGES: [(i64, i64); 4] = [
    (tiles::ROAD_STRAIGHT_1, tiles::ROAD_CROSSROADS),
    (tiles::TUNNEL_ENTRANCE_1, tiles::TUNNEL_ENTRANCE_4),
    (tiles::HIGHWAY_ROAD_CROSSING_1, tiles::HIGHWAY_ROAD_CROSSING_2),
    (tiles::HIGHWAY_ONRAMP_1, tiles::HIGHWAY_ONRAMP_4),
];
const INDUSTRY_CONNECTION_RANGES: [(i64, i64); 3] = [
    (tiles::RAIL_STRAIGHT_1, tiles::RAIL_SLOPE_8),
    (tiles::ROAD_RAIL_CROSSING_1, tiles::HIGHWAY_POWER_CROSSING_2),
    (tiles::HIGHWAY_SLOPE_1, tiles::HIGHWAY_INTERSECTION),
];

gd_phase_result! {
    pub struct RciDemandResult as "RciDemandPhase.Result" {
        pub previous_population: i64 = 0,
        pub normal_population: i64 = 0,
        pub tax_population: Ints64 = Ints64::default(),
        pub targets: Vec<f64> = Vec::new(),
        pub demands: Ints32 = Ints32::default(),
        pub commerce_connections: i64 = 0,
        pub industry_connections: i64 = 0,
    }
}

/// Neighbor connections: commerce reaches roads and industry reaches rails
/// and highways at the connection label.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct ConnectionCounts {
    pub commerce: i64,
    pub industry: i64,
}

fn in_ranges(value: i64, ranges: &[(i64, i64)]) -> bool {
    ranges.iter().any(|(first, last)| value >= *first && value <= *last)
}

pub fn connection_counts(city: &City) -> ConnectionCounts {
    let overlays = &city.xtxt.data;
    let buildings = &city.xbld.data;
    let cells = overlay::count(overlays);
    let low_byte = (sc2overlay_layout::CONNECTION_MARKER & 0xff) as u8;
    let mut counts = ConnectionCounts::default();
    let mut index = overlay::find_byte(overlays, low_byte, 0);

    // The high bytes of an SC2X label plane follow the low bytes.
    while index >= 0 && index < cells {
        let tile = buildings[index as usize] as i64;
        let labelled = overlay::read(overlays, index) == sc2overlay_layout::CONNECTION_MARKER;
        index = overlay::find_byte(overlays, low_byte, index + 1);

        if !labelled {
            continue;
        }

        if in_ranges(tile, &COMMERCE_CONNECTION_RANGES) {
            counts.commerce += 1;
        }

        if in_ranges(tile, &INDUSTRY_CONNECTION_RANGES) {
            counts.industry += 1;
        }
    }

    counts
}

fn tile_count(city: &City, tile: i64) -> i64 {
    city.misc_i32(misc_layout::TILE_COUNTS + tile * 4)
}

fn ordinance_adjusted_tax_rate(category: i64, mut rate: i64, flags: i64) -> i64 {
    match category {
        0 => {
            if flags & ordinances::INCOME_TAX_MASK != 0 {
                rate += 1;
            }

            if flags & ordinances::CITY_BEAUTIFICATION_MASK != 0 {
                rate -= 1;
            }
        }
        1 => {
            if flags & ordinances::SALES_TAX_MASK != 0 {
                rate += 1;
            }

            for mask in [ordinances::TOURIST_ADVERTISING_MASK, ordinances::ANNUAL_CARNIVAL_MASK, ordinances::HOMELESS_SHELTER_MASK] {
                if flags & mask != 0 {
                    rate -= 1;
                }
            }
        }
        _ => {
            if flags & ordinances::BUSINESS_ADVERTISING_MASK != 0 {
                rate -= 1;
            }

            if flags & ordinances::POLLUTION_CONTROLS_MASK != 0 {
                rate += 1;
            }
        }
    }

    rate.max(0)
}

/// RciDemandPhase.run.
pub fn rci_demand(city: &mut City) -> RciDemandResult {
    if !city.misc.present || city.misc.data.len() < 0x1054 {
        return RciDemandResult::failed("MISC data is missing or too short");
    }

    let mut span = TimingSpan::new();
    span.mark("prepare data");
    let mut zone_population = [0i64; 8];

    for (index, value) in zone_population.iter_mut().enumerate() {
        *value = city.misc_i32(misc_layout::ZONE_POPULATIONS + index as i64 * 4);
    }

    zone_population[0] = zone_population[1..7].iter().sum();
    let tax_population = [
        zone_population[1] + zone_population[2],
        zone_population[3] + zone_population[4],
        zone_population[5] + zone_population[6],
    ];
    span.mark("demand targets");
    let previous_population = city.misc_i32(misc_layout::NORMAL_POPULATION);
    let normal_population = zone_population[0] * 10;
    let old_residential = city.misc_i32(misc_layout::OLD_RESIDENTIAL_POPULATION);
    let jobs = (tax_population[1] + tax_population[2]) as f64;
    let resident_job_ratio = old_residential as f64 / (jobs + 1.0);
    let mut residential_target = (tax_population[0] / 50) as f64 + jobs;
    let amenities = tile_count(city, tiles::BIG_PARK) / 3
        + tile_count(city, tiles::STADIUM)
        + tile_count(city, tiles::ZOO)
        + 10
        + tile_count(city, tiles::MARINA);
    residential_target = residential_target.min((amenities * 150) as f64);
    residential_target = residential_target.min((tax_population[1] * 4 + 500) as f64);
    let industrial_population = tax_population[2] as f64;
    let mut commercial_target =
        (normal_population + 50000) as f64 * COMMERCIAL_SCALE * resident_job_ratio * industrial_population;
    let difficulty = city.difficulty().clamp(0, INDUSTRIAL_DIFFICULTY.len() as i64 - 1) as usize;
    let mut industrial_target = (city.misc_i32(misc_layout::INDUSTRIAL_MIX_BONUS) as f64 * INDUSTRIAL_MIX_SCALE
        + INDUSTRIAL_DIFFICULTY[difficulty])
        * resident_job_ratio
        * industrial_population;
    industrial_target = industrial_target.max(MINIMUM_INDUSTRIAL_TARGET);
    span.mark("neighbor connections");
    let connections = connection_counts(city);
    span.mark("demand caps and taxes");
    let airports = connections.commerce + tile_count(city, tiles::RUNWAY) + tile_count(city, tiles::RUNWAY_CROSSING);
    commercial_target = commercial_target.min((((airports / 5) * 4 + 4) * 375) as f64);
    industrial_target = industrial_target.min(((tile_count(city, tiles::CRANE) + 1 + connections.industry) * 1500) as f64);
    let targets = [residential_target, commercial_target, industrial_target];
    let ordinance_flags = city.misc_u32(misc_layout::ORDINANCES);
    let mut demands = [0i64; 3];

    for index in 0..3 {
        let mut tax_rate = city.misc_i32(misc_layout::BUDGETS + index as i64 * sc2budget_layout::RECORD_SIZE + 4);
        tax_rate = ordinance_adjusted_tax_rate(index as i64, tax_rate, ordinance_flags);
        tax_rate = tax_rate.clamp(0, TAX_EFFECT.len() as i64 - 1);
        let ratio = targets[index] / (tax_population[index] + 1) as f64 - 1.0;
        let change = (ratio * RATIO_SCALE + TAX_EFFECT[tax_rate as usize] as f64) as i64;
        demands[index] = (city.misc_i32(misc_layout::DEMAND + index as i64 * 4) + change).clamp(-2000, 2000);
    }

    span.mark("store demand and population");
    let garbage = city.misc_i32(misc_layout::GARBAGE);
    let arcology_population = city.misc_i32(misc_layout::ARCOLOGY_POPULATION);
    let misc = city.misc.mutate();
    write_u32_be(misc, misc_layout::ZONE_POPULATIONS, zone_population[0]);
    write_u32_be(misc, misc_layout::NORMAL_POPULATION, normal_population);
    write_u32_be(misc, misc_layout::GARBAGE, garbage + normal_population);
    write_u32_be(misc, misc_layout::OLD_RESIDENTIAL_POPULATION, tax_population[0]);

    for index in 0..3 {
        let budget_population = tax_population[index] * 10 + arcology_population / if index == 0 { 6 } else { 12 };
        write_u32_be(misc, misc_layout::BUDGETS + index as i64 * sc2budget_layout::RECORD_SIZE, budget_population);
        write_u32_be(misc, misc_layout::DEMAND + index as i64 * 4, demands[index]);
    }

    let mut result = RciDemandResult {
        previous_population,
        normal_population,
        tax_population: Ints64(tax_population.to_vec()),
        targets: targets.to_vec(),
        demands: Ints32(demands.iter().map(|&demand| demand as i32).collect()),
        commerce_connections: connections.commerce,
        industry_connections: connections.industry,
        ..Default::default()
    };
    result.base_mut().ok = true;
    result.base_mut().timing = span.finish();
    result
}

// Five 50-year rows from the executable table at 0x004e9458.
const WORLD_DEMAND: [[i64; 11]; 5] = [
    [20, 20, 10, 10, 15, 5, 0, 15, 8, 0, 10],
    [30, 20, 40, 10, 20, 40, 20, 20, 16, 10, 20],
    [35, 20, 30, 10, 25, 40, 30, 25, 24, 80, 30],
    [20, 50, 20, 10, 20, 30, 40, 30, 40, 80, 40],
    [10, 20, 10, 10, 20, 20, 50, 30, 20, 80, 50],
];
const POLLUTING_INDUSTRIES: [usize; 4] = [0, 1, 2, 5];
const MID_EQ_INDUSTRIES: [usize; 6] = [2, 5, 7, 8, 6, 9];
const HIGH_EQ_INDUSTRIES: [usize; 2] = [6, 9];

gd_phase_result! {
    pub struct IndustryResult as "IndustryPhase.Result" {
        pub start_year: i64 = 0,
        pub elapsed_years: i64 = 0,
        pub world_demands: Ints32 = Ints32::default(),
        pub demands: Ints32 = Ints32::default(),
        pub adjusted_demands: Ints32 = Ints32::default(),
        pub ratios: Ints64 = Ints64::default(),
        pub ratio_total_before: i64 = 0,
        pub ratio_total_after: i64 = 0,
        pub industrial_population: i64 = 0,
        pub positive_demand_total: i64 = 0,
        pub pollution_share: i64 = 0,
        pub pollution_bonus: i64 = 0,
        pub maximum_share: i64 = 0,
        pub mix_bonus: i64 = 0,
    }
}

fn to_i16(value: i64) -> i64 {
    let word = value & 0xffff;

    if word & 0x8000 != 0 { word - 0x10000 } else { word }
}

/// IndustryPhase._divide_toward_zero divides as floats.
fn float_divide(value: i64, divisor: i64) -> i64 {
    (value as f64 / divisor as f64) as i64
}

pub fn world_demands(start_year: i64, elapsed_years: i64) -> Vec<i64> {
    let period = float_divide(start_year - 1900, 50) + elapsed_years / 50;

    if period < 0 {
        return Vec::new();
    }

    if period >= WORLD_DEMAND.len() as i64 - 1 {
        return WORLD_DEMAND[WORLD_DEMAND.len() - 1].to_vec();
    }

    let remainder = elapsed_years % 50;
    let period = period as usize;

    (0..industry_layout::COUNT as usize)
        .map(|industry| {
            (WORLD_DEMAND[period + 1][industry] * remainder + (50 - remainder) * WORLD_DEMAND[period][industry]) / 50
        })
        .collect()
}

/// PackedInt32Array stores wrap to 32 bits.
fn scale_demands(values: &mut [i64], industries: &[usize], factor: f64) {
    for &industry in industries {
        values[industry] = ((values[industry] as f64 * factor) as i64) as i32 as i64;
    }
}

/// IndustryPhase.run.
pub fn industry(city: &mut City, random: &mut SimRandom, lfsr: &mut SimLfsrRandom, population_growth: i64) -> IndustryResult {
    if population_growth < 0 {
        return IndustryResult::failed("population growth is negative");
    }

    if !city.misc.present || city.misc.data.len() as i64 != misc_layout::SIZE {
        return IndustryResult::failed("MISC is missing or has the wrong size");
    }

    let mut data = city.misc.data.clone();
    let start_year = to_i16(read_u32_be(&data, misc_layout::START_YEAR));
    let elapsed_years = read_u32_be(&data, misc_layout::CITY_DAYS) / crate::sim::ids::city_calendar::DAYS_PER_YEAR;
    let targets = world_demands(start_year, elapsed_years);

    if targets.is_empty() {
        return IndustryResult::failed("the industry era is before 1900");
    }

    let count = industry_layout::COUNT as usize;
    let base = |industry: usize| misc_layout::INDUSTRIES + industry as i64 * industry_layout::RECORD_SIZE;
    let mut demands = Vec::with_capacity(count);
    let mut ratios = Vec::with_capacity(count);
    let mut ratio_total = 0;

    for (industry, target) in targets.iter().enumerate() {
        let old_demand = to_i16(read_u32_be(&data, base(industry) + industry_layout::DEMAND));
        let mut random_sum = 0;

        for _ in 0..4 {
            random_sum += lfsr.next_mask(0x7f);
        }

        let random_target = float_divide(random_sum * target, 256);
        demands.push(float_divide(random_target + old_demand * 3, 4) as i32 as i64);
        let ratio = read_u32_be(&data, base(industry) + industry_layout::RATIO);
        ratios.push(ratio);
        ratio_total += ratio;
    }

    let mut adjusted = demands.clone();
    let ordinance_flags = read_u32_be(&data, misc_layout::ORDINANCES);

    if ordinance_flags & ordinances::POLLUTION_CONTROLS_MASK != 0 {
        scale_demands(&mut adjusted, &POLLUTING_INDUSTRIES, 0.9);
    }

    if population_growth != 0 {
        scale_demands(&mut adjusted, &[4], 1.1);
    }

    let workforce_eq = read_u32_be(&data, misc_layout::WORKFORCE_EDUCATION);

    if workforce_eq > 130 {
        scale_demands(&mut adjusted, &HIGH_EQ_INDUSTRIES, 1.2);
    } else if workforce_eq > 100 {
        scale_demands(&mut adjusted, &MID_EQ_INDUSTRIES, 1.1);
    } else if workforce_eq < 60 {
        scale_demands(&mut adjusted, &HIGH_EQ_INDUSTRIES, 0.8);
    }

    let mut positive_total = 0;

    for (industry, value) in adjusted.iter_mut().enumerate() {
        *value = (*value - to_i16(read_u32_be(&data, base(industry) + industry_layout::TAX_RATE))) as i32 as i64;

        if *value <= 0 {
            *value = 0;
        } else {
            positive_total += *value;
        }
    }

    let industrial_population = read_u32_be(&data, misc_layout::ZONE_POPULATIONS + 5 * 4)
        + read_u32_be(&data, misc_layout::ZONE_POPULATIONS + 6 * 4);

    if ratio_total > industrial_population {
        let excess = ratio_total - industrial_population;

        for ratio in ratios.iter_mut() {
            let scaled = (excess * 100 * *ratio) / ratio_total;
            *ratio -= scaled / 100;

            if random.next_u15() % 100 < scaled % 100 {
                *ratio -= 1;
            }
        }
    } else if ratio_total < industrial_population && positive_total != 0 {
        let shortage = industrial_population - ratio_total;

        for (industry, ratio) in ratios.iter_mut().enumerate() {
            if adjusted[industry] == 0 {
                continue;
            }

            let scaled = (shortage * 100 * adjusted[industry]) / positive_total;
            *ratio += scaled / 100;

            if random.next_u15() % 100 < scaled % 100 {
                *ratio += 1;
            }
        }
    }

    let pollution_share = ((ratios[0] + ratios[1] + ratios[2] + ratios[5]) * 100) / (industrial_population + 1);
    let pollution_bonus = if pollution_share < 20 { 0xffff } else { (pollution_share - 20) / 30 };
    let maximum_share = ratios.iter().map(|ratio| (ratio * 100) / (industrial_population + 1)).fold(0, i64::max);
    let mix_bonus = if maximum_share < 20 { 0 } else { (maximum_share - 20) / 5 };

    for industry in 0..count {
        write_u32_be(&mut data, base(industry) + industry_layout::DEMAND, demands[industry]);
        write_u32_be(&mut data, base(industry) + industry_layout::RATIO, ratios[industry]);
    }

    write_u32_be(&mut data, misc_layout::INDUSTRIAL_MIX_BONUS, mix_bonus);
    write_u32_be(&mut data, misc_layout::INDUSTRIAL_POLLUTION_BONUS, pollution_bonus);
    city.misc.replace(data);

    let mut result = IndustryResult {
        start_year,
        elapsed_years,
        world_demands: Ints32(targets.iter().map(|&value| value as i32).collect()),
        demands: Ints32(demands.iter().map(|&value| value as i32).collect()),
        adjusted_demands: Ints32(adjusted.iter().map(|&value| value as i32).collect()),
        ratio_total_after: ratios.iter().sum(),
        ratios: Ints64(ratios),
        ratio_total_before: ratio_total,
        industrial_population,
        positive_demand_total: positive_total,
        pollution_share,
        pollution_bonus,
        maximum_share,
        mix_bonus,
        ..Default::default()
    };
    result.base_mut().ok = true;
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Each ordinance moves one category's tax rate. Unknown bits change nothing.
    #[test]
    fn ordinances_adjust_the_tax_rate() {
        let deltas: [&[(i64, i64)]; 3] = [&[(1, 1), (14, -1)], &[(0, 1), (12, -1), (15, -1), (18, -1)], &[(13, -1), (19, 1)]];
        let mut flag_cases = vec![0i64, 0xfffff, 0x8000_0000, 0x85_4003];
        flag_cases.extend((0..20).map(|bit| 1i64 << bit));

        for (category, category_deltas) in deltas.iter().enumerate() {
            for rate in [0i64, 7, 20] {
                for flags in &flag_cases {
                    let expected: i64 = rate
                        + category_deltas.iter().filter(|(bit, _)| flags & (1 << bit) != 0).map(|(_, delta)| delta).sum::<i64>();
                    assert_eq!(ordinance_adjusted_tax_rate(category as i64, rate, *flags), expected.max(0));
                }
            }
        }
    }
}
