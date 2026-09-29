//! SC2X v3 per-tile data maps, as NativeDataMapPhase. These rules differ from
//! the coarse grids of the original executable.

use super::grid_math;
use super::{CoverageResult, PollutionResult, building_pollution, land_value_halved, population_weight};
use super::{CRIME_REDUCTION_ORDINANCE, FIRE_COVERAGE_ORDINANCE, POLICE_COVERAGE_ORDINANCE, ZONE_BUILDING_ORIGIN};
use crate::sim::city::City;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::phase::{PhaseResultLike, TimingSpan};

/// The first missing or invalid data map, or None.
fn invalid_chunk(city: &City, count: usize) -> Option<String> {
    for id in ["XTRF", "XPLT", "XVAL", "XCRM", "XPLC", "XFIR", "XPOP", "XROG"] {
        if city.chunk(id).is_none_or(|chunk| chunk.data.len() != count) {
            return Some(format!("Native data map {id} is missing or invalid"));
        }
    }

    if !city.misc.present || city.misc.data.len() as i64 != misc_layout::SIZE {
        return Some("MISC is missing or invalid".to_string());
    }

    None
}

fn pollution_weight(building: i64) -> i64 {
    building_pollution(building) * 4 + if building == tiles::RADIOACTIVE_WASTE { 800 } else { 0 }
}

fn density_weight(building: i64) -> i64 {
    if building >= tiles::DEVELOPED_FIRST && building < tiles::HYDRO_POWER_1 {
        population_weight(building)
    } else if building >= tiles::HYDRO_POWER_1 {
        if (tiles::PLYMOUTH_ARCOLOGY..=tiles::LAUNCH_ARCOLOGY).contains(&building) { 12 } else { 2 }
    } else {
        0
    }
}

/// The residential desirability of a tile that is not empty.
fn residential_value(building: i64) -> i64 {
    if building == tiles::BIG_PARK {
        40
    } else if (tiles::TREE_FIRST..=tiles::SMALL_PARK).contains(&building) {
        20
    } else if building < tiles::TREE_FIRST {
        -20
    } else {
        0
    }
}

/// The full monthly scan. The day schedule runs the two halves on separate days.
pub fn run(city: &mut City) -> PollutionResult {
    let mut span = TimingSpan::new();
    let coverage = run_pollution_and_coverage(city);

    if !coverage.base.ok {
        return PollutionResult::failed(coverage.base.error);
    }

    let mut result = run_land_value_and_crime(city);

    if result.base.ok {
        let mut steps = coverage.base.timing.steps.clone();

        // Dictionary.merge keeps the existing coverage steps.
        for (name, value) in result.base.timing.steps.0.iter() {
            if !steps.has(name) {
                steps.set(name, *value);
            }
        }

        let total = span.finish().work_usec;
        result.base.timing = crate::sim::events::Timing::new(total, steps);
    }

    result
}

/// Pollution, the city center, and police and fire coverage.
pub fn run_pollution_and_coverage(city: &mut City) -> CoverageResult {
    let mut span = TimingSpan::new();
    span.mark("pollution sources");
    let edge = city.map_size as usize;
    let count = edge * edge;

    if let Some(message) = invalid_chunk(city, count) {
        return CoverageResult::failed(message);
    }

    let old_pollution = &city.xplt.data;
    let old_traffic = &city.xtrf.data;
    let buildings = &city.xbld.data;
    let mut sources = vec![0i32; count];
    let mut center_x_sum = 0i64;
    let mut center_y_sum = 0i64;
    let mut center_count = 0i64;

    for x in 0..edge {

        crate::sim::budget::checkpoint();
        let row = x * edge;

        for y in 0..edge {
            let index = row + y;
            let building = buildings[index] as i64;
            sources[index] =
                (old_pollution[index] as i64 + old_traffic[index] as i64 / 5 + pollution_weight(building)) as i32;

            if building >= tiles::DEVELOPED_FIRST {
                center_x_sum += x as i64;
                center_y_sum += y as i64;
                center_count += 1;
            }
        }
    }

    let half = city.map_size / 2;
    let center = if center_count == 0 {
        Vec2i::new(half, half)
    } else {
        Vec2i::new(center_x_sum / center_count, center_y_sum / center_count)
    };
    let ordinances = city.misc_u32(misc_layout::ORDINANCES);
    let divisor = super::pollution_divisor(city);
    span.mark("pollution smoothing");
    let (pollution, pollution_sum) = grid_math::smooth_bytes(&sources, edge, 4, divisor.max(1) * 2, 1, 2);
    span.mark("ordinance coverage");
    let mut police = vec![0u8; count];
    let mut fire = vec![0u8; count];

    if ordinances & (POLICE_COVERAGE_ORDINANCE | FIRE_COVERAGE_ORDINANCE) != 0 {
        let occupied: Vec<i32> = buildings
            .iter()
            .map(|&building| ((building as i64) >= tiles::DEVELOPED_FIRST && (building as i64) < tiles::HYDRO_POWER_1) as i32)
            .collect();
        let coverage = grid_math::neighborhood_bytes(&occupied, edge, 2, 32);

        if ordinances & POLICE_COVERAGE_ORDINANCE != 0 {
            police = coverage.clone();
        }

        if ordinances & FIRE_COVERAGE_ORDINANCE != 0 {
            fire = coverage;
        }
    }

    span.mark("station coverage");
    add_stations(city, &mut police, &mut fire);
    span.mark("store maps and totals");
    city.xplt.replace(pollution);
    city.xplc.replace(police);
    city.xfir.replace(fire);
    // MISC totals keep the original half-resolution area unit for economic consumers.
    let pollution_total = pollution_sum / 4;
    city.set_misc_u32(misc_layout::CITY_POLLUTION, pollution_total);
    city.set_misc_u32(misc_layout::CITY_CENTER_X, center.x);
    city.set_misc_u32(misc_layout::CITY_CENTER_Y, center.y);

    let mut result = CoverageResult { pollution_total, city_center: center, ..Default::default() };
    result.base_mut().ok = true;
    result.base_mut().timing = span.finish();
    result
}

/// Police and fire stations add a coverage pattern at their origin tile, in
/// the order of a scan by x, then by y.
fn add_stations(city: &City, police: &mut [u8], fire: &mut [u8]) {
    let edge = city.map_size;
    let (police_strength, fire_strength) = super::station_strengths(city);
    let mut patterns: Vec<(i64, Vec<i64>)> = Vec::new();

    for (index, &building) in city.xbld.data.iter().enumerate() {
        let building = building as i64;

        if building != tiles::POLICE_STATION && building != tiles::FIRE_STATION {
            continue;
        }

        if city.xzon.data[index] as i64 & ZONE_BUILDING_ORIGIN == 0 {
            continue;
        }

        let police_station = building == tiles::POLICE_STATION;
        let mut strength = if police_station { police_strength } else { fire_strength };

        if city.xbit.data[index] as i64 & flag_bits::POWERED == 0 {
            strength /= 2;
        }

        let position = match patterns.iter().position(|(known, _)| *known == strength) {
            Some(position) => position,
            None => {
                patterns.push((strength, grid_math::service_pattern(strength)));
                patterns.len() - 1
            }
        };
        let target = if police_station { &mut *police } else { &mut *fire };
        let index = index as i64;
        grid_math::apply_service_pattern(target, edge, index / edge, index % edge, &patterns[position].1);
    }
}

/// Land value, population density, growth, and crime. These read the
/// pollution, police coverage, and city center of the coverage scan.
pub fn run_land_value_and_crime(city: &mut City) -> PollutionResult {
    let mut span = TimingSpan::new();
    span.mark("land and density sources");
    let edge = city.map_size as usize;
    let count = edge * edge;

    if let Some(message) = invalid_chunk(city, count) {
        return PollutionResult::failed(message);
    }

    let buildings = &city.xbld.data;
    let flags = &city.xbit.data;
    let zones = &city.xzon.data;
    let terrain = &city.xter.data;
    let mut residential = vec![0i32; count];
    let mut industrial = vec![0i32; count];
    let mut weights = vec![0i32; count];
    let mut developed = 0i64;

    for index in 0..count {
        if index & 1023 == 0 {
            crate::sim::budget::checkpoint();
        }

        let building = buildings[index] as i64;
        let tile_flags = flags[index] as i64;

        if building >= tiles::FIRST_ROAD || zones[index] as i64 & zone::TYPE_MASK != 0 {
            developed += 1;
        }

        let mut residential_value = residential_value(building);
        let mut industrial_value = 0;

        if building == tiles::EMPTY {
            if tile_flags & flag_bits::WATER != 0 {
                residential_value = 12;
                industrial_value = 12;
            } else {
                residential_value = 4;
            }
        }

        if tile_flags & flag_bits::WATERED != 0 {
            residential_value += 4;
            industrial_value += 4;
        }

        let terrain_id = terrain[index] as i64;

        if terrain_id > terrain_ids::FLAT && terrain_id < terrain_ids::DEEP_WATER_FIRST {
            residential_value += 12;
        }

        residential[index] = residential_value as i32;
        industrial[index] = industrial_value as i32;
        weights[index] = density_weight(building) as i32;
    }

    let center = Vec2i::new(city.misc_u32(misc_layout::CITY_CENTER_X), city.misc_u32(misc_layout::CITY_CENTER_Y));
    let ordinances = city.misc_u32(misc_layout::ORDINANCES);
    span.mark("land desirability filters");
    let residential = grid_math::neighborhood(&residential, edge, 2, 16);
    let industrial = grid_math::neighborhood(&industrial, edge, 2, 16);
    let residential = grid_math::smooth(&residential, edge, 1, 1, 4, 1);
    let industrial = grid_math::smooth(&industrial, edge, 1, 1, 4, 1);
    span.mark("population density");
    let population = grid_math::neighborhood_bytes(&weights, edge, 2, 64);
    span.mark("land value, population change and crime sources");
    let pollution = &city.xplt.data;
    let police = &city.xplc.data;
    let old_growth = &city.xrog.data;
    let old_population = &city.xpop.data;
    let old_crime = &city.xcrm.data;
    let mut land_sum = 0i64;
    let mut land = vec![0u8; count];
    let mut growth = vec![0u8; count];
    let mut sources = vec![0i32; count];
    let crime_bonus = if ordinances & CRIME_REDUCTION_ORDINANCE != 0 { 16 } else { 0 };

    for x in 0..edge {

        crate::sim::budget::checkpoint();
        let row = x * edge;
        let distance_x = (center.x - x as i64).abs();

        for y in 0..edge {
            let index = row + y;
            let population_value = population[index] as i64;
            let old_population_value = old_population[index] as i64;
            growth[index] =
                ((old_growth[index] as i64 * 7 + (population_value - old_population_value) * 8 + 128) / 8).clamp(0, 255) as u8;
            let building = buildings[index] as i64;
            let zone_type = zones[index] as i64 & zone::TYPE_MASK;

            if building < tiles::FIRST_ROAD && zone_type == 0 {
                continue;
            }

            let distance_value = 64 - (distance_x + (center.y - y as i64).abs()) / 2;
            let pollution_value = pollution[index] as i64;
            let crime_value = old_crime[index] as i64;
            let mut value = residential[index] as i64;

            if zone_type == 3 || zone_type == 4 {
                value += distance_value.max(0) - pollution_value / 4 - crime_value / 3 + old_population_value / 3;
            } else if zone_type == 5 || zone_type == 6 {
                value = industrial[index] as i64 + if zone_type == 6 { 21 } else { 0 };
                value += (distance_value / 4).max(0) - pollution_value / 16 - crime_value / 4;
            } else {
                value += if old_population_value < 64 { 21 } else { 0 };
                value += (distance_value / 2).max(0) - pollution_value / 5 - crime_value / 3;
            }

            if land_value_halved(building) {
                value -= value / 2;
            }

            let value = value.clamp(0, 255);
            land[index] = value as u8;
            land_sum += value;
            sources[index] = (population_value - value / 4 - police[index] as i64 / 2 + crime_bonus) as i32;
        }
    }

    span.mark("crime smoothing");
    let (crime, crime_sum) = grid_math::smooth_bytes(&sources, edge, 2, 2, 1, 2);
    span.mark("store maps and totals");
    city.xval.replace(land);
    city.xcrm.replace(crime);
    city.xpop.replace(population);
    city.xrog.replace(growth);
    let land_total = land_sum / 4;
    let crime_total = crime_sum / 4;
    city.set_misc_u32(misc_layout::CITY_LAND_VALUE, land_total);
    city.set_misc_u32(misc_layout::CITY_CRIME, crime_total);

    let mut result = PollutionResult {
        pollution_total: city.misc_u32(misc_layout::CITY_POLLUTION),
        land_value_total: land_total,
        crime_total,
        developed_tiles: developed,
        city_center: center,
        ..Default::default()
    };
    result.base_mut().ok = true;
    result.base_mut().timing = span.finish();
    result
}
