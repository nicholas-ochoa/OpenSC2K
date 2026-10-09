//! Graph histories, as GraphHistory.

use crate::gd_phase_result;
use crate::sim::city::City;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::city_calendar::{DAYS_PER_MONTH, DAYS_PER_YEAR};
use crate::sim::ids::sc2budget_layout;
use crate::sim::ids::sc2graph_layout as layout;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::phase::{PhaseResultLike, TimingSpan};
use crate::sim::value::Ints64;

gd_phase_result! {
    pub struct GraphResult as "GraphHistory.Result" {
        pub month: i64 = 0,
        pub elapsed_years: i64 = 0,
        pub values: Ints64 = Ints64::default(),
        pub unemployment: i64 = 0,
    }
}

/// GraphHistory.calculate_current_values: the sixteen values and unemployment.
pub fn calculate_current_values(
    city: &City,
    developed_tiles: i64,
    power_usage_percent: i64,
    water_usage_percent: i64,
) -> Result<(Vec<i64>, i64), String> {
    if !city.misc.present || city.misc.data.len() as i64 != misc_layout::SIZE {
        return Err("MISC is missing or has the wrong size".to_string());
    }

    if developed_tiles < 0 || developed_tiles > city.tile_count() {
        return Err("developed tile count is out of range".to_string());
    }

    if !(0..=100).contains(&power_usage_percent) {
        return Err("power usage percentage is out of range".to_string());
    }

    if !(0..=100).contains(&water_usage_percent) {
        return Err("water usage percentage is out of range".to_string());
    }

    let zone_populations: Vec<i64> = (0..8)
        .map(|index| city.misc_u32(misc_layout::ZONE_POPULATIONS + index * 4))
        .collect();
    let total_zone_population: i64 = zone_populations[1..7].iter().sum();
    let tax_populations = [
        zone_populations[1] + zone_populations[2],
        zone_populations[3] + zone_populations[4],
        zone_populations[5] + zone_populations[6],
    ];
    let arcology_tiles: i64 = (tiles::PLYMOUTH_ARCOLOGY..=tiles::LAUNCH_ARCOLOGY)
        .map(|tile| city.misc_i32(misc_layout::TILE_COUNTS + tile * 4))
        .sum();
    let arcology_count = arcology_tiles / 16;
    let arcology_adjustment = if arcology_count > 140 {
        (arcology_count * 5 - 700) * 4000
    } else {
        0
    };
    let arcology_population = city.misc_u32(misc_layout::ARCOLOGY_POPULATION);
    let adjusted_arcology_population = arcology_population + arcology_adjustment;
    let mut transport_cost = 1;

    for budget_id in [sc2budget_layout::ROAD, sc2budget_layout::HIGHWAY, sc2budget_layout::BRIDGE] {
        transport_cost += city.misc_i32(misc_layout::BUDGETS + budget_id * sc2budget_layout::RECORD_SIZE);
    }

    if transport_cost <= 0 {
        return Err("transport graph divisor is not positive".to_string());
    }

    let developed_divisor = developed_tiles / 4 + 1;
    let unemployment = (zone_populations[7] * 100) / (total_zone_population + zone_populations[7] + 1);
    let values = vec![
        arcology_population + total_zone_population * 10 + arcology_adjustment,
        adjusted_arcology_population / 2 + tax_populations[0] * 10,
        adjusted_arcology_population / 4 + tax_populations[1] * 10,
        adjusted_arcology_population / 4 + tax_populations[2] * 10,
        city.misc_u32(misc_layout::CITY_TRAFFIC) / transport_cost,
        city.misc_u32(misc_layout::CITY_POLLUTION) / developed_divisor,
        city.misc_u32(misc_layout::CITY_LAND_VALUE) / developed_divisor,
        city.misc_u32(misc_layout::CITY_CRIME) / developed_divisor,
        100 - power_usage_percent,
        100 - water_usage_percent,
        city.misc_u32(misc_layout::WORKFORCE_LIFE_EXPECTANCY),
        city.misc_u32(misc_layout::WORKFORCE_EDUCATION),
        unemployment,
        city.misc_u32(misc_layout::NATIONAL_VALUE),
        city.misc_u32(misc_layout::NATIONAL_POPULATION),
        city.misc_i32(misc_layout::NATIONAL_FEDERAL_RATE),
    ];

    Ok((values, unemployment))
}

fn copy_value(data: &mut [u8], series: i64, source: i64, target: i64) {
    let base = series * layout::SERIES_SIZE;
    let from = (base + source * layout::VALUE_SIZE) as usize;
    let to = (base + target * layout::VALUE_SIZE) as usize;
    data.copy_within(from..from + 4, to);
}

/// GraphHistory.advance: shift the histories and store the current values.
pub fn advance(city: &mut City, current_values: &[i64]) -> Result<(i64, i64), String> {
    if current_values.len() as i64 != layout::SERIES_COUNT {
        return Err("sixteen current graph values are required".to_string());
    }

    if !city.xgrp.present || city.xgrp.data.len() as i64 != layout::SIZE {
        return Err("XGRP is missing or has the wrong size".to_string());
    }

    let month = (city.age_in_days() % DAYS_PER_YEAR) / DAYS_PER_MONTH;
    let elapsed_years = city.age_in_days() / DAYS_PER_YEAR;
    let data = city.xgrp.mutate();

    for series in 0..layout::SERIES_COUNT {
        for index in (layout::YEAR_OFFSET + 1..layout::DECADE_OFFSET).rev() {
            copy_value(data, series, index - 1, index);
        }

        let offset = ((series * layout::VALUES_PER_SERIES + layout::YEAR_OFFSET) * layout::VALUE_SIZE) as usize;
        data[offset..offset + 4].copy_from_slice(&(current_values[series as usize] as u32).to_be_bytes());

        if month == 0 || month == 6 {
            for index in (layout::DECADE_OFFSET + 1..layout::CENTURY_OFFSET).rev() {
                copy_value(data, series, index - 1, index);
            }

            copy_value(data, series, layout::YEAR_OFFSET, layout::DECADE_OFFSET);
        }

        if month == 0 && elapsed_years % 5 == 0 {
            for index in (layout::CENTURY_OFFSET + 1..layout::VALUES_PER_SERIES).rev() {
                copy_value(data, series, index - 1, index);
            }

            copy_value(data, series, layout::YEAR_OFFSET, layout::CENTURY_OFFSET);
        }
    }

    Ok((month, elapsed_years))
}

/// GraphHistory.run.
pub fn run(city: &mut City, developed_tiles: i64, power_usage_percent: i64, water_usage_percent: i64) -> GraphResult {
    let mut span = TimingSpan::new();
    span.mark("calculate graph values");
    let (values, unemployment) = match calculate_current_values(city, developed_tiles, power_usage_percent, water_usage_percent) {
        Ok(calculated) => calculated,
        Err(message) => return GraphResult::failed(message),
    };

    if !city.xgrp.present || city.xgrp.data.len() as i64 != layout::SIZE {
        return GraphResult::failed("XGRP is missing or has the wrong size");
    }

    span.mark("store unemployment");
    city.set_misc_u32(misc_layout::UNEMPLOYMENT, unemployment);
    span.mark("shift graph histories");
    let (month, elapsed_years) = match advance(city, &values) {
        Ok(shifted) => shifted,
        Err(message) => return GraphResult::failed(message),
    };
    let mut result = GraphResult {
        month,
        elapsed_years,
        values: Ints64(values),
        unemployment,
        ..Default::default()
    };
    result.base_mut().ok = true;
    result.base_mut().timing = span.finish();
    result
}
