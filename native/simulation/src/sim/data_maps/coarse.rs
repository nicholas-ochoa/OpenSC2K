//! The original coarse data maps, as PollutionPhase and PollutionMaps. The
//! passes keep their scan order.

use super::{CRIME_REDUCTION_ORDINANCE, FIRE_COVERAGE_ORDINANCE, POLICE_COVERAGE_ORDINANCE, ZONE_BUILDING_ORIGIN};
use super::{PollutionResult, building_pollution, land_value_halved, population_weight};
use crate::sim::city::City;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::ids::sc2tile_flags as flag_bits;
use crate::sim::ids::sc2zone_layout as zone;
use crate::sim::ids::terrain_tile_ids as terrain_ids;
use crate::sim::phase::{PhaseResultLike, TimingSpan};

/// PollutionValues._add_service_cell.
fn add_service_cell(values: &mut [u8], x: i64, y: i64, strength: i64, map_edge: i64) {
    let quarter_edge = map_edge / 4;

    if x < 0 || x >= quarter_edge || y < 0 || y >= quarter_edge {
        return;
    }

    let index = (x * quarter_edge + y) as usize;
    values[index] = (values[index] as i64 + strength).clamp(0, 0xff) as u8;
}

/// PollutionValues._add_service: a station pattern on the quarter grid.
pub fn add_service(values: &mut [u8], x: i64, y: i64, strength: i64, map_edge: i64) {
    add_service_cell(values, x, y, strength, map_edge);
    let cardinal = (strength * 4) / 5;

    for (px, py) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)] {
        add_service_cell(values, px, py, cardinal, map_edge);
    }

    let diagonal = (cardinal * 3) / 4;

    for dx in [-1, 1] {
        for dy in [-1, 1] {
            add_service_cell(values, x + dx, y + dy, diagonal, map_edge);
        }
    }

    let outer = (diagonal * 2) / 3;

    for major in [-2, 2] {
        for minor in [-1, 0, 1] {
            add_service_cell(values, x + major, y + minor, outer, map_edge);
            add_service_cell(values, x + minor, y + major, outer, map_edge);
        }
    }

    let fringe = outer / 2;

    for major in [-3, 3] {
        for minor in [-1, 0, 1] {
            add_service_cell(values, x + major, y + minor, fringe, map_edge);
            add_service_cell(values, x + minor, y + major, fringe, map_edge);
        }
    }

    for dx in [-2, 2] {
        for dy in [-2, 2] {
            add_service_cell(values, x + dx, y + dy, fringe, map_edge);
        }
    }
}

/// PollutionValues._average_service_grid. The neighbor rows step by the full
/// map edge, as in the original.
fn average_service_grid(values: &[i32], x: i64, y: i64, x_offset: i64, map_edge: i64) -> i64 {
    let quarter_edge = map_edge / 4;
    let center = (x + x_offset) * map_edge + y;
    let at = |index: i64| values[index as usize] as i64;
    let mut total = at(center);
    let mut divisor = 1;

    if x > 0 {
        total += at(center - map_edge);
        divisor += 1;
    }

    if x < quarter_edge - 1 {
        total += at(center + map_edge);
        divisor += 1;
    }

    if y > 0 {
        total += at(center - 1);
        divisor += 1;
    }

    if y < quarter_edge - 1 {
        total += at(center + 1);
        divisor += 1;
    }

    total / divisor
}

/// PollutionPhase.run for coarse maps.
pub fn run(city: &mut City) -> PollutionResult {
    let map_edge = city.map_size;
    let half_edge = map_edge / 2;
    let quarter_edge = map_edge / 4;
    let mut span = TimingSpan::new();
    span.mark("pollution sources");

    if !city.misc.present || city.misc.data.len() != 4800 {
        return PollutionResult::failed("MISC is missing or has the wrong size");
    }

    for (id, size) in [("XTRF", half_edge * half_edge), ("XPLT", half_edge * half_edge)] {
        if city.chunk(id).is_none_or(|chunk| chunk.data.len() as i64 != size) {
            return PollutionResult::failed(format!("{id} is missing or has the wrong size"));
        }
    }

    for (id, size) in [
        ("XVAL", half_edge * half_edge),
        ("XCRM", half_edge * half_edge),
        ("XPLC", quarter_edge * quarter_edge),
        ("XFIR", quarter_edge * quarter_edge),
        ("XPOP", quarter_edge * quarter_edge),
        ("XROG", quarter_edge * quarter_edge),
    ] {
        if city.chunk(id).is_none_or(|chunk| chunk.data.len() as i64 != size) {
            return PollutionResult::failed(format!("{id} is missing or has the wrong size"));
        }
    }

    let edge = map_edge as usize;
    let half = half_edge as usize;
    let quarter = quarter_edge as usize;
    let buildings = &city.xbld.data;
    let zones = &city.xzon.data;

    // Sum traffic, previous pollution, and polluting buildings for each
    // half-grid cell. The sources use full-grid rows.
    let mut sources = vec![0i32; edge * edge];
    let old_traffic = &city.xtrf.data;
    let old_pollution = &city.xplt.data;

    for x in 0..half {
        crate::sim::budget::checkpoint();
        for y in 0..half {
            let map_index = x * half + y;
            let mut value = old_traffic[map_index] as i64 / 5 + old_pollution[map_index] as i64;

            for full_x in x * 2..x * 2 + 2 {
                for full_y in y * 2..y * 2 + 2 {
                    let building = buildings[full_x * edge + full_y] as i64;

                    if building >= tiles::DEVELOPED_FIRST {
                        value += building_pollution(building);
                    }

                    if building == tiles::RADIOACTIVE_WASTE {
                        value += 200;
                    }
                }
            }

            sources[x * edge + y] = value as i32;
        }
    }

    span.mark("pollution smoothing");
    let base_divisor = super::pollution_divisor(city);
    let mut pollution = vec![0u8; half * half];
    let mut total = 0i64;

    for x in 0..half {
        crate::sim::budget::checkpoint();
        for y in 0..half {
            let source = x * edge + y;
            let mut numerator = sources[source] as i64 * 2;
            let mut divisor = base_divisor;

            if x > 0 {
                numerator += sources[source - edge] as i64;
                divisor += 1;
            }

            if x < half - 1 {
                numerator += sources[source + edge] as i64;
                divisor += 1;
            }

            if y > 0 {
                numerator += sources[source - 1] as i64;
                divisor += 1;
            }

            if y < half - 1 {
                numerator += sources[source + 1] as i64;
                divisor += 1;
            }

            let value = (numerator / divisor).min(0xff);
            pollution[x * half + y] = value as u8;
            total += value;
        }
    }

    // Find the centroid of tiles with buildings and clear their mark flags.
    span.mark("city center");
    let mut flags = city.xbit.data.clone();
    let mut sum_x = 0i64;
    let mut sum_y = 0i64;
    let mut center_divisor = 1i64;

    for x in 0..edge {
        crate::sim::budget::checkpoint();
        for y in 0..edge {
            let index = x * edge + y;

            if buildings[index] as i64 > tiles::RAIL_SUBWAY_ENTRANCE_4 {
                sum_x += x as i64;
                sum_y += y as i64;
                center_divisor += 1;
                flags[index] = (flags[index] as i64 & !flag_bits::MARK & 0xff) as u8;
            }
        }
    }

    let center_x = sum_x / (center_divisor * 2);
    let center_y = sum_y / (center_divisor * 2);

    // Score terrain desirability into quarter-grid scratch cells, and mark the
    // half-grid cells that hold development.
    span.mark("terrain desirability");
    let terrain = &city.xter.data;
    let mut temporary = vec![0i32; edge * edge];
    let mut developed_tiles = 0i64;

    for x in 0..edge {
        crate::sim::budget::checkpoint();
        let quarter_x = x >> 2;
        let residential_row = quarter_x * edge;
        let industrial_row = (quarter_x + quarter) * edge;
        let marked_row = (x >> 1) * edge;

        for y in 0..edge {
            let index = x * edge + y;
            let quarter_y = y >> 2;
            let residential_index = residential_row + quarter_y;
            let industrial_index = industrial_row + quarter_y;
            let mut residential = temporary[residential_index] as i64;
            let mut industrial = temporary[industrial_index] as i64;
            let building = buildings[index] as i64;

            if building == tiles::EMPTY {
                if flags[index] as i64 & flag_bits::WATER != 0 {
                    residential += 12;
                    industrial += 12;
                } else {
                    residential += 4;
                }
            } else if building == tiles::BIG_PARK {
                residential += 40;
            } else if (tiles::TREE_FIRST..=tiles::SMALL_PARK).contains(&building) {
                residential += 20;
            } else if building < tiles::TREE_FIRST {
                residential -= 20;
            }

            if building >= tiles::FIRST_ROAD || zones[index] as i64 & zone::TYPE_MASK != 0 {
                let marked = marked_row + (y >> 1);
                flags[marked] = (flags[marked] as i64 | flag_bits::MARK) as u8;
                developed_tiles += 1;
            }

            if flags[index] as i64 & flag_bits::WATERED != 0 {
                residential += 4;
                industrial += 4;
            }

            let terrain_id = terrain[index] as i64;

            if terrain_id != terrain_ids::FLAT && terrain_id < terrain_ids::DEEP_WATER_FIRST {
                residential += 12;
            }

            temporary[residential_index] = residential as i32;
            temporary[industrial_index] = industrial as i32;
        }
    }

    // Land value for each marked half-grid cell, by zone class.
    span.mark("land value");
    let old_crime = &city.xcrm.data;
    let old_population = &city.xpop.data;
    let mut land_value = vec![0u8; half * half];
    let mut land_value_total = 0i64;

    for x in 0..half {
        crate::sim::budget::checkpoint();
        let full_x = x * 2;

        for y in 0..half {
            let map_index = x * half + y;

            if flags[x * edge + y] as i64 & flag_bits::MARK == 0 {
                continue;
            }

            let full_index = full_x * edge + y * 2;
            let mut zone_type = zones[full_index] as i64 & zone::TYPE_MASK;

            if zone_type == 0 {
                zone_type = zones[full_index + edge + 1] as i64 & zone::TYPE_MASK;
            }

            let service_x = (x >> 1) as i64;
            let service_y = (y >> 1) as i64;
            let service_index = (service_x * quarter_edge + service_y) as usize;
            let distance_value = 64 - (center_x - x as i64).abs() - (center_y - y as i64).abs();
            let pollution_value = pollution[map_index] as i64;
            let crime_value = old_crime[map_index] as i64;
            let mut value;

            match zone_type {
                3 | 4 => {
                    value = average_service_grid(&temporary, service_x, service_y, 0, map_edge);
                    value += distance_value.max(0);
                    value -= pollution_value / 4;
                    value -= crime_value / 3;
                    value += old_population[service_index] as i64 / 3;
                }
                5 | 6 => {
                    value = average_service_grid(&temporary, service_x, service_y, quarter_edge, map_edge);

                    if zone_type == 6 {
                        value += 21;
                    }

                    value += (distance_value / 4).max(0);
                    value -= pollution_value / 16;
                    value -= crime_value / 4;
                }
                _ => {
                    value = average_service_grid(&temporary, service_x, service_y, 0, map_edge);

                    if (old_population[service_index] as i64) < 0x40 {
                        value += 21;
                    }

                    value += (distance_value / 2).max(0);
                    value -= pollution_value / 5;
                    value -= crime_value / 3;
                }
            }

            let building = buildings[full_index] as i64;

            if building >= tiles::DEVELOPED_FIRST && land_value_halved(building) {
                value -= value / 2;
            }

            let value = value.clamp(0, 0xff);
            land_value[map_index] = value as u8;
            land_value_total += value;
        }
    }

    // Reset the scratch cells that the service pass accumulates population into.
    for x in 0..quarter {
        crate::sim::budget::checkpoint();
        for y in 0..quarter {
            temporary[x * edge + y] = 0;
        }
    }

    // Police and fire coverage and building population weights.
    span.mark("services and population sources");
    let mut police = vec![0u8; quarter * quarter];
    let mut fire = vec![0u8; quarter * quarter];
    let ordinances = city.misc_u32(misc_layout::ORDINANCES);
    let (police_strength, fire_strength) = super::station_strengths(city);

    for x in 1..edge - 1 {
        crate::sim::budget::checkpoint();
        let service_x = x >> 2;
        let temporary_row = service_x * edge;

        for y in 1..edge - 1 {
            let index = x * edge + y;
            let building = buildings[index] as i64;
            let service_y = y >> 2;
            let service_index = service_x * quarter + service_y;

            if building >= tiles::DEVELOPED_FIRST && building < tiles::HYDRO_POWER_1 {
                temporary[temporary_row + service_y] += population_weight(building) as i32;

                if ordinances & POLICE_COVERAGE_ORDINANCE != 0 && police[service_index] < 0xfe {
                    police[service_index] += 2;
                }

                if ordinances & FIRE_COVERAGE_ORDINANCE != 0 && fire[service_index] < 0xfe {
                    fire[service_index] += 2;
                }
            } else if building >= tiles::HYDRO_POWER_1 {
                let arcology = (tiles::PLYMOUTH_ARCOLOGY..=tiles::LAUNCH_ARCOLOGY).contains(&building);
                temporary[temporary_row + service_y] += if arcology { 12 } else { 2 };

                if zones[index] as i64 & ZONE_BUILDING_ORIGIN == 0 {
                    continue;
                }

                let unpowered = flags[index] as i64 & flag_bits::POWERED == 0;

                if building == tiles::POLICE_STATION {
                    let strength = if unpowered { police_strength / 2 } else { police_strength };
                    add_service(&mut police, service_x as i64, service_y as i64, strength, map_edge);
                } else if building == tiles::FIRE_STATION {
                    let strength = if unpowered { fire_strength / 2 } else { fire_strength };
                    add_service(&mut fire, service_x as i64, service_y as i64, strength, map_edge);
                }
            }
        }
    }

    // Scale population sources into the population map and blend the change
    // into the growth-rate map.
    span.mark("population and population change");
    let old_growth = &city.xrog.data;
    let mut population = vec![0u8; quarter * quarter];
    let mut growth = vec![0u8; quarter * quarter];

    for x in 0..quarter {
        crate::sim::budget::checkpoint();
        for y in 0..quarter {
            let index = x * quarter + y;
            let population_value = (temporary[x * edge + y] as i64 * 4).min(0xff);
            population[index] = population_value as u8;
            let numerator = old_growth[index] as i64 * 7 + (population_value - old_population[index] as i64) * 8 + 128;
            growth[index] = (numerator / 8).clamp(0, 0xff) as u8;
        }
    }

    // Crime sources for marked half-grid cells.
    for x in 0..half {
        crate::sim::budget::checkpoint();
        let service_row = (x >> 1) * quarter;

        for y in 0..half {
            let index = x * half + y;
            let temporary_index = x * edge + y;

            if flags[temporary_index] as i64 & flag_bits::MARK == 0 {
                temporary[temporary_index] = 0;
                continue;
            }

            let service_index = service_row + (y >> 1);
            let mut value = population[service_index] as i64;
            value -= land_value[index] as i64 / 4;
            value -= police[service_index] as i64 / 2;

            if ordinances & CRIME_REDUCTION_ORDINANCE != 0 {
                value += 16;
            }

            temporary[temporary_index] = value as i32;
        }
    }

    span.mark("crime smoothing");
    let mut crime = vec![0u8; half * half];
    let mut crime_total = 0i64;

    for x in 0..half {
        crate::sim::budget::checkpoint();
        for y in 0..half {
            let index = x * edge + y;
            let mut numerator = temporary[index] as i64;
            let mut divisor = 1;

            if x > 0 {
                numerator += temporary[index - edge] as i64;
                divisor += 1;
            }

            if x < half - 1 {
                numerator += temporary[index + edge] as i64;
                divisor += 1;
            }

            if y > 0 {
                numerator += temporary[index - 1] as i64;
                divisor += 1;
            }

            if y < half - 1 {
                numerator += temporary[index + 1] as i64;
                divisor += 1;
            }

            let value = (numerator / divisor).clamp(0, 0xff);
            crime[x * half + y] = value as u8;
            crime_total += value;
        }
    }

    span.mark("store maps and totals");
    city.xplt.replace(pollution);
    city.xval.replace(land_value);
    city.xplc.replace(police);
    city.xfir.replace(fire);
    city.xpop.replace(population);
    city.xrog.replace(growth);
    city.xcrm.replace(crime);
    city.xbit.replace(flags);

    for (offset, value) in [
        (misc_layout::CITY_POLLUTION, total),
        (misc_layout::CITY_LAND_VALUE, land_value_total),
        (misc_layout::CITY_CRIME, crime_total),
        (misc_layout::CITY_CENTER_X, center_x * 2),
        (misc_layout::CITY_CENTER_Y, center_y * 2),
    ] {
        city.set_misc_u32(offset, value);
    }

    let mut result = PollutionResult {
        pollution_total: total,
        land_value_total,
        crime_total,
        developed_tiles,
        city_center: Vec2i::new(center_x * 2, center_y * 2),
        ..Default::default()
    };
    result.base_mut().ok = true;
    result.base_mut().timing = span.finish();
    result
}
