//! The national economy and the neighbor cities, as SimNationPhase.

use crate::gd_phase_result;
use crate::sim::bytes::{read_u32_be, write_u32_be};
use crate::sim::city::City;
use crate::sim::events::NewsEvent;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::phase::PhaseResultLike;
use crate::sim::random::SimRandom;
use crate::sim::value::Ints64;

const NEIGHBOR_STRIDE: i64 = 0x10;
const NEIGHBOR_POPULATION: i64 = 0x04;
const NEIGHBOR_VALUE: i64 = 0x08;
const NEIGHBOR_COUNT: i64 = 4;
const NATIONAL_POPULATION_CENTER: i64 = 5_000_000;
const NATIONAL_VALUE_CENTER: i64 = 3_500_000;
const MONTHLY_SCALE: f64 = 1200.0;
const ECONOMY_FACTORS: [i64; 4] = [6, 3, 0, -3];
const NEWS_NATIONAL_ECONOMY: i64 = 0x07;
const NEWS_FEDERAL_RATE_UP: i64 = 0x09;
const NEWS_FEDERAL_RATE_DOWN: i64 = 0x0a;

gd_phase_result! {
    pub struct SimNationResult as "SimNationPhase.Result" {
        pub national_population: i64 = 0,
        pub national_value: i64 = 0,
        pub federal_rate: i64 = 0,
        pub economy_trend: i64 = 0,
        pub neighbor_populations: Ints64 = Ints64::default(),
        pub neighbor_values: Ints64 = Ints64::default(),
        pub shocked_neighbor: i64 = -1,
    }
}

pub fn economy_level(score: i64) -> i64 {
    if score < 45 {
        0
    } else if score < 60 {
        1
    } else if score < 75 {
        2
    } else {
        3
    }
}

fn scaled_change(value: i64, factor: i64) -> i64 {
    (value as f64 * factor as f64 / MONTHLY_SCALE) as i64
}

fn move_about_center(value: i64, change: i64, center: i64) -> i64 {
    (if value > center { value - change } else { value + change }) & 0xffff_ffff
}

fn to_i16(value: i64) -> i64 {
    let word = value & 0xffff;

    if word & 0x8000 != 0 { word - 0x10000 } else { word }
}

/// SimNationPhase.run.
pub fn run(city: &mut City, random: &mut SimRandom) -> SimNationResult {
    if !city.misc.present || city.misc.data.len() as i64 != misc_layout::SIZE {
        return SimNationResult::failed("MISC is missing or has the wrong size");
    }

    let mut data = city.misc.data.clone();
    let mut economy_trend = to_i16(read_u32_be(&data, misc_layout::NATIONAL_ECONOMY_TREND));

    if economy_trend < 0 || economy_trend >= ECONOMY_FACTORS.len() as i64 {
        return SimNationResult::failed("the national economy trend is out of range");
    }

    let mut federal_rate = to_i16(read_u32_be(&data, misc_layout::NATIONAL_FEDERAL_RATE));

    if federal_rate <= 0 {
        return SimNationResult::failed("the national federal rate is not positive");
    }

    let mut news_items = Vec::new();
    let mut national_population = read_u32_be(&data, misc_layout::NATIONAL_POPULATION);
    let population_change = scaled_change(national_population, economy_trend);
    national_population = move_about_center(national_population, population_change, NATIONAL_POPULATION_CENTER);
    write_u32_be(&mut data, misc_layout::NATIONAL_POPULATION, national_population);
    let mut national_value = read_u32_be(&data, misc_layout::NATIONAL_VALUE);
    let value_change = scaled_change(national_value, ECONOMY_FACTORS[economy_trend as usize]);
    national_value = move_about_center(national_value, value_change, NATIONAL_VALUE_CENTER);
    write_u32_be(&mut data, misc_layout::NATIONAL_VALUE, national_value);

    if random.next_u15() % 10 == 0 {
        let national_score = (national_value as f64 / (national_population + 1) as f64 * 100.0) as i64;

        if random.next_u15() % 5 < 2 {
            if random.next_u15() % (federal_rate * 25) < national_score {
                federal_rate += 1;
                write_u32_be(&mut data, misc_layout::NATIONAL_FEDERAL_RATE, federal_rate);
                news_items.push(NewsEvent::new(NEWS_FEDERAL_RATE_UP, federal_rate));
            }

            if national_score < random.next_u15() % (federal_rate * 25) {
                federal_rate -= 1;

                if federal_rate == 0 {
                    federal_rate = 1;
                } else {
                    news_items.push(NewsEvent::new(NEWS_FEDERAL_RATE_DOWN, federal_rate));
                }

                write_u32_be(&mut data, misc_layout::NATIONAL_FEDERAL_RATE, federal_rate);
            }
        }

        if random.next_u15() % 3 == 0 {
            let new_trend = economy_level(national_score);

            if new_trend != economy_trend {
                economy_trend = new_trend;
                write_u32_be(&mut data, misc_layout::NATIONAL_ECONOMY_TREND, economy_trend);
                news_items.push(NewsEvent::new(NEWS_NATIONAL_ECONOMY, economy_trend));
            }
        }
    }

    let mut neighbor_populations = Vec::new();
    let mut neighbor_values = Vec::new();

    for neighbor in 0..NEIGHBOR_COUNT {
        let base = misc_layout::NEIGHBORS + neighbor * NEIGHBOR_STRIDE;
        let mut population = read_u32_be(&data, base + NEIGHBOR_POPULATION);
        let mut value = read_u32_be(&data, base + NEIGHBOR_VALUE);

        if population != 0 {
            let factor = economy_trend + random.next_u15() % 3;
            let change = scaled_change(population, factor);
            population = move_about_center(population, change, NATIONAL_POPULATION_CENTER);

            if change == 0 {
                population = (population + (random.next_u15() & 1)) & 0xffff_ffff;
            }

            write_u32_be(&mut data, base + NEIGHBOR_POPULATION, population);
            let neighbor_score = (value as f64 / population as f64 * 100.0) as i64;
            let value_factor = ECONOMY_FACTORS[economy_trend as usize] + random.next_u15() % 5
                - federal_rate
                - economy_level(neighbor_score);
            let change = scaled_change(value, value_factor);
            value = move_about_center(value, change, NATIONAL_VALUE_CENTER);
            write_u32_be(&mut data, base + NEIGHBOR_VALUE, value);
        }

        neighbor_populations.push(population);
        neighbor_values.push(value);
    }

    let mut shocked_neighbor = -1;

    if random.next_u15() & 0x3f == 0 {
        shocked_neighbor = random.next_u15() & 3;
        let index = shocked_neighbor as usize;
        let shock_base = misc_layout::NEIGHBORS + shocked_neighbor * NEIGHBOR_STRIDE;
        neighbor_populations[index] = (neighbor_populations[index] as f64 * 0.75) as i64;
        neighbor_values[index] = (neighbor_values[index] as f64 * 0.5) as i64;
        write_u32_be(&mut data, shock_base + NEIGHBOR_POPULATION, neighbor_populations[index]);
        write_u32_be(&mut data, shock_base + NEIGHBOR_VALUE, neighbor_values[index]);
    }

    city.misc.replace(data);
    let mut result = SimNationResult {
        national_population,
        national_value,
        federal_rate,
        economy_trend,
        neighbor_populations: Ints64(neighbor_populations),
        neighbor_values: Ints64(neighbor_values),
        shocked_neighbor,
        ..Default::default()
    };
    result.base_mut().ok = true;
    result.base_mut().news_items = news_items;
    result
}
