//! Population cohorts, education, and health, as EducationHealthPhase.

use crate::gd_phase_result;
use crate::sim::bytes::write_u32_be;
use crate::sim::city::City;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::ordinance_ids as ordinances;
use crate::sim::ids::sc2budget_layout;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::phase::{PhaseResultLike, TimingSpan};
use crate::sim::random::SimRandom;

const POPULATION_STRIDE: i64 = 12;
const POPULATION_COHORTS: usize = 20;
const RAW_POPULATION_FIELD: i64 = 0;
const EDUCATION_FIELD: i64 = 4;
const LIFE_EXPECTANCY_FIELD: i64 = 8;

gd_phase_result! {
    pub struct EducationHealthResult as "EducationHealthPhase.Result" {
        pub population: i64 = 0,
        pub deaths: i64 = 0,
        pub births: i64 = 0,
        pub immigrants: i64 = 0,
        pub emigrants: i64 = 0,
        pub health_capacity: i64 = 0,
        pub school_capacity: i64 = 0,
        pub college_capacity: i64 = 0,
        pub newborn_life_expectancy: i64 = 0,
        pub pollution_penalty: i64 = 0,
        pub workforce_population: i64 = 0,
        pub workforce_percent: i64 = 0,
        pub workforce_le: i64 = 0,
        pub workforce_eq: i64 = 0,
        pub empty_city: bool = false,
    }
}

struct Tables {
    population: [i64; POPULATION_COHORTS],
    education: [i64; POPULATION_COHORTS],
    life_expectancy: [i64; POPULATION_COHORTS],
}

fn tile_count(city: &City, tile: i64) -> i64 {
    city.misc_i32(misc_layout::TILE_COUNTS + tile * 4)
}

fn budget_funding(city: &City, budget_id: i64) -> i64 {
    city.misc_i32(misc_layout::BUDGETS + budget_id * sc2budget_layout::RECORD_SIZE + 4)
}

fn write_tables(data: &mut [u8], tables: &Tables) {
    for cohort in 0..POPULATION_COHORTS {
        let offset = misc_layout::POPULATION_TABLE + cohort as i64 * POPULATION_STRIDE;
        write_u32_be(data, offset + RAW_POPULATION_FIELD, tables.population[cohort]);
        write_u32_be(data, offset + EDUCATION_FIELD, tables.education[cohort]);
        write_u32_be(data, offset + LIFE_EXPECTANCY_FIELD, tables.life_expectancy[cohort]);
    }
}

/// EducationHealthPhase.run.
pub fn run(city: &mut City, random: &mut SimRandom) -> EducationHealthResult {
    if !city.misc.present || city.misc.data.len() as i64 != misc_layout::SIZE {
        return EducationHealthResult::failed("MISC is missing or has the wrong size");
    }

    let mut span = TimingSpan::new();
    span.mark("prepare data");
    let mut tables = Tables {
        population: [0; POPULATION_COHORTS],
        education: [0; POPULATION_COHORTS],
        life_expectancy: [0; POPULATION_COHORTS],
    };

    for cohort in 0..POPULATION_COHORTS {
        let offset = misc_layout::POPULATION_TABLE + cohort as i64 * POPULATION_STRIDE;
        tables.population[cohort] = city.misc_u32(offset + RAW_POPULATION_FIELD);
        tables.education[cohort] = city.misc_u32(offset + EDUCATION_FIELD);
        tables.life_expectancy[cohort] = city.misc_u32(offset + LIFE_EXPECTANCY_FIELD);
    }

    let city_population = city.misc_u32(misc_layout::NORMAL_POPULATION);

    if city_population == 0 {
        let cleared = Tables {
            population: [0; POPULATION_COHORTS],
            education: [0; POPULATION_COHORTS],
            life_expectancy: [0; POPULATION_COHORTS],
        };
        write_tables(city.misc.mutate(), &cleared);
        let mut result = EducationHealthResult { empty_city: true, ..Default::default() };
        result.base_mut().ok = true;
        result.base_mut().timing = span.finish();

        return result;
    }

    span.mark("service capacities");
    let ordinance_flags = city.misc_u32(misc_layout::ORDINANCES);
    let mut health_capacity =
        ((tile_count(city, tiles::HOSPITAL) / 9) * budget_funding(city, sc2budget_layout::HEALTH) * 25) / 100;
    let school_capacity = ((tile_count(city, tiles::SCHOOL) / 9) * budget_funding(city, sc2budget_layout::SCHOOL) * 15) / 100;
    let college_capacity =
        ((tile_count(city, tiles::COLLEGE) / 16) * budget_funding(city, sc2budget_layout::COLLEGE) * 50) / 100;
    let mut newborn_life_expectancy = 85;

    for mask in [ordinances::ANTI_DRUG_MASK, ordinances::CPR_TRAINING_MASK, ordinances::PUBLIC_SMOKING_BAN_MASK] {
        if ordinance_flags & mask != 0 {
            newborn_life_expectancy += 5;
        }
    }

    if ordinance_flags & ordinances::FREE_CLINICS_MASK != 0 {
        health_capacity += city.misc_i32(misc_layout::BUDGETS) / 400;
    }

    span.mark("mortality, aging and schooling");
    let deaths = apply_mortality(&mut tables, random);
    let abandoned_population = city.misc_u32(misc_layout::ZONE_POPULATIONS + 7 * 4);
    let pollution_penalty =
        (city.misc_u32(misc_layout::CITY_POLLUTION) / (city_population + abandoned_population * 10 + 1)).min(3);
    apply_aging(&mut tables, school_capacity, college_capacity, pollution_penalty, ordinance_flags, random);
    span.mark("births");
    let fertile_population: i64 = tables.population[4..9].iter().sum();
    let mut births = fertile_population / 300;
    // The original subtracts pollution here instead of using the modulo remainder.
    let birth_threshold = fertile_population - pollution_penalty * 300;

    if random.next_u15() % 300 < birth_threshold {
        births += 1;
    }

    if births > 0 {
        let protected_births = births.min(health_capacity);
        tables.life_expectancy[0] += (newborn_life_expectancy - 35) * protected_births + births * 35;
        tables.education[0] += (births * city.misc_u32(misc_layout::WORKFORCE_EDUCATION)) / 5;
        tables.population[0] += births;
    }

    span.mark("migration");
    let table_population: i64 = tables.population.iter().sum();
    let mut immigrants = 0;
    let mut emigrants = 0;

    if table_population < city_population {
        immigrants = city_population - table_population;
        add_population(&mut tables, immigrants);
    } else if table_population > city_population {
        emigrants = table_population - city_population;

        if !remove_population(&mut tables, emigrants, city_population, random) {
            return EducationHealthResult::failed("demographic removal did not converge");
        }
    }

    span.mark("workforce");
    let workforce_population: i64 = tables.population[4..11].iter().sum();
    let workforce_education: i64 = tables.education[4..11].iter().sum();
    let workforce_life_expectancy: i64 = tables.life_expectancy[4..11].iter().sum();
    let mut workforce_percent = 0;
    let mut workforce_eq = 0;
    let mut workforce_le = 0;

    if workforce_population > 0 {
        workforce_percent = (workforce_population * 100) / (city_population + 1);
        workforce_eq = workforce_education / workforce_population;
        workforce_le = workforce_life_expectancy / workforce_population;
    }

    span.mark("store demographics");
    let misc = city.misc.mutate();
    write_tables(misc, &tables);
    write_u32_be(misc, misc_layout::WORKFORCE_PERCENT, workforce_percent);
    write_u32_be(misc, misc_layout::WORKFORCE_LIFE_EXPECTANCY, workforce_le);
    write_u32_be(misc, misc_layout::WORKFORCE_EDUCATION, workforce_eq);

    let mut result = EducationHealthResult {
        population: tables.population.iter().sum(),
        deaths,
        births,
        immigrants,
        emigrants,
        health_capacity,
        school_capacity,
        college_capacity,
        newborn_life_expectancy,
        pollution_penalty,
        workforce_population,
        workforce_percent,
        workforce_le,
        workforce_eq,
        ..Default::default()
    };
    result.base_mut().ok = true;
    result.base_mut().timing = span.finish();
    result
}

fn apply_mortality(tables: &mut Tables, random: &mut SimRandom) -> i64 {
    let mut total = 0;

    for cohort in 1..POPULATION_COHORTS {
        let count = tables.population[cohort];

        if count == 0 {
            continue;
        }

        let average_life_expectancy = tables.life_expectancy[cohort] / count;
        let survival_ratio = (average_life_expectancy * 100) / (cohort as i64 * 5);

        if survival_ratio >= 100 {
            continue;
        }

        let scaled_deaths = ((100 - survival_ratio) * count) / 24;
        let mut deaths = scaled_deaths / 100;

        if random.next_u15() % 100 < scaled_deaths - deaths * 100 {
            deaths += 1;
        }

        deaths = deaths.min(count);

        if deaths == 0 {
            continue;
        }

        tables.education[cohort] -= (tables.education[cohort] * deaths) / count;
        tables.life_expectancy[cohort] -= (tables.life_expectancy[cohort] * deaths) / count;
        tables.population[cohort] -= deaths;
        total += deaths;
    }

    total
}

fn apply_aging(
    tables: &mut Tables,
    school_capacity: i64,
    college_capacity: i64,
    pollution_penalty: i64,
    ordinance_flags: i64,
    random: &mut SimRandom,
) {
    for target in (1..POPULATION_COHORTS).rev() {
        let source = target - 1;
        let source_population = tables.population[source];

        if source_population == 0 {
            continue;
        }

        let mut moved_population = source_population / 60;

        if random.next_u15() % 60 < source_population % 60 {
            moved_population += 1;
        }

        moved_population = moved_population.min(source_population);

        if moved_population == 0 {
            continue;
        }

        let mut moved_education = (tables.education[source] * moved_population) / source_population;
        tables.education[source] -= moved_education;

        if target < 3 {
            moved_education += moved_population.min(school_capacity) * 35;
        } else if target == 3 {
            let educated_population = moved_population.min(college_capacity);
            moved_education += ((educated_population * moved_education) / moved_population) / 2;
        }

        if ordinance_flags & ordinances::PRO_READING_MASK == 0 {
            // Decay cannot turn the transferred education into unsigned debt.
            moved_education = (moved_education - moved_population).max(0);
        }

        tables.education[target] = (tables.education[target] + moved_education) & 0xffff_ffff;
        let moved_life_expectancy = (tables.life_expectancy[source] * moved_population) / source_population;
        tables.life_expectancy[source] -= moved_life_expectancy;
        tables.life_expectancy[target] =
            (tables.life_expectancy[target] + moved_life_expectancy - pollution_penalty) & 0xffff_ffff;
        tables.population[source] -= moved_population;
        tables.population[target] += moved_population;
    }
}

fn add_population(tables: &mut Tables, amount: i64) {
    let mut remaining = amount;
    let portion = remaining / 16 + 1;

    while remaining > 0 {
        for cohort in 4..8 {
            let added = portion.min(remaining);
            tables.life_expectancy[cohort] += (65 - cohort as i64) * added;
            tables.education[cohort] += (90 - cohort as i64) * added;
            tables.population[cohort] += added;
            remaining -= added;
        }

        for cohort in 0..12 {
            if remaining == 0 {
                return;
            }

            let added = portion.min(remaining);
            tables.life_expectancy[cohort] += (65 - cohort as i64) * added;
            let education = if cohort < 3 { 17 + cohort as i64 * 35 } else { 90 - cohort as i64 };
            tables.education[cohort] += education * added;
            tables.population[cohort] += added;
            remaining -= added;
        }
    }
}

fn remove_population(tables: &mut Tables, amount: i64, city_population: i64, random: &mut SimRandom) -> bool {
    let mut remaining = amount;
    let mut pass_count = 0;

    while remaining > 0 {
        let pass_start = remaining;

        for cohort in 0..POPULATION_COHORTS {
            if remaining == 0 {
                break;
            }

            let count = tables.population[cohort];

            if count == 0 {
                continue;
            }

            let mut removed = (count * pass_start) / (remaining + city_population);

            if removed == 0 && random.next_u15() & 3 == 0 {
                removed = 1;
            }

            removed = removed.min(count.min(remaining));

            if removed == 0 {
                continue;
            }

            tables.life_expectancy[cohort] -= (tables.life_expectancy[cohort] * removed) / count;
            tables.education[cohort] -= (tables.education[cohort] * removed) / count;
            tables.population[cohort] -= removed;
            remaining -= removed;
        }

        pass_count += 1;

        if pass_count > 100000 {
            return false;
        }
    }

    true
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::testing::sequence_random;

    /// Decay floors the transferred education and keeps the destination's points.
    #[test]
    fn education_decay_moves_only_whole_transfers() {
        for points in [0i64, 30, 60, 120] {
            for pro_reading in [false, true] {
                let mut tables = Tables {
                    population: [0; POPULATION_COHORTS],
                    education: [0; POPULATION_COHORTS],
                    life_expectancy: [0; POPULATION_COHORTS],
                };
                tables.population[4] = 60;
                tables.education[4] = points;
                tables.life_expectancy[4] = 4800;
                tables.education[5] = 7;
                let flags = if pro_reading { ordinances::PRO_READING_MASK } else { 0 };
                apply_aging(&mut tables, 0, 0, 0, flags, &mut sequence_random(&[32767]));
                let transferred = points / 60;
                let expected = 7 + if pro_reading { transferred } else { (transferred - 1).max(0) };
                assert_eq!(tables.education[5], expected);
                assert_eq!(tables.education[4], points - transferred, "the source loses only the transferred points");
            }
        }
    }
}
