//! The monthly city status and disaster selection, as WeatherDisasterPhase.

use crate::gd_phase_result;
use crate::sim::bytes::{read_i32_be, read_u32_be};
use crate::sim::city::City;
use crate::sim::events::NewsEvent;
use crate::sim::geom::Vec2i;
use crate::sim::grid;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::city_calendar::DAYS_PER_MONTH;
use crate::sim::ids::sc2budget_layout as budget;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::phase::TimingSpan;
use crate::sim::random::{SimLfsrRandom, SimRandom};

const NEWS_DEMAND_BASE: i64 = 0x2e;
pub const STATUS_NONE: i64 = -1;
pub const STATUS_WEATHER: i64 = -2;
const STATUS_POWER: i64 = 0;
const STATUS_TRANSIT: i64 = 1;
const STATUS_POLICE: i64 = 2;
const STATUS_FIRE: i64 = 3;
const STATUS_WATER: i64 = 4;
const STATUS_HOSPITAL: i64 = 5;
const STATUS_SCHOOL: i64 = 6;
const STATUS_SEAPORT: i64 = 7;
const STATUS_AIRPORT: i64 = 8;
const STATUS_ZOO: i64 = 9;
const STATUS_INDUSTRIAL_CONNECTION: i64 = 13;
const STATUS_COMMERCIAL_CONNECTION: i64 = 14;
pub const DISASTER_NONE: i64 = 0;
pub const DISASTER_FIRE: i64 = 1;
pub const DISASTER_FLOOD: i64 = 2;
pub const DISASTER_RIOT: i64 = 3;
pub const DISASTER_TOXIC_SPILL: i64 = 4;
pub const DISASTER_EARTHQUAKE: i64 = 6;
pub const DISASTER_TORNADO: i64 = 7;
pub const DISASTER_MONSTER: i64 = 8;
pub const DISASTER_MELTDOWN: i64 = 9;
pub const DISASTER_MICROWAVE: i64 = 10;
pub const DISASTER_MASS_RIOTS: i64 = 13;
pub const DISASTER_MASS_FLOODS: i64 = 14;
pub const DISASTER_POLLUTION: i64 = 15;
pub const DISASTER_HURRICANE: i64 = 16;
pub const DISASTER_PLANE_CRASH: i64 = 18;
/// Simulation months by saved difficulty. The executable stores 0, 100, 60,
/// and 30 at 0x004e9908.
const DISASTER_WAIT_MONTHS: [i64; 4] = [0, 100, 60, 30];
const DIFFICULTY_EASY: i64 = 1;

gd_phase_result! {
    pub struct WeatherResult as "WeatherDisasterPhase.Result" {
        pub status_index: i64 = -1,
        pub status_news_type: i64 = -1,
        pub disaster_type: i64 = 0,
        pub disaster_point: Vec2i = Vec2i::ZERO,
        pub wait_months: i64 = 0,
        pub disaster_roll: i64 = 0,
        pub candidate_type: i64 = 0,
    }
}

fn to_i16(value: i64) -> i64 {
    let word = value & 0xffff;

    if word & 0x8000 != 0 { word - 0x10000 } else { word }
}

fn tile_count(misc: &[u8], tile: i64, map_edge: i64) -> i64 {
    let value = read_u32_be(misc, misc_layout::TILE_COUNTS + tile * 4);

    if map_edge == 128 { to_i16(value) } else { value }
}

fn budget_current(misc: &[u8], budget_id: i64) -> i64 {
    read_i32_be(misc, misc_layout::BUDGETS + budget_id * budget::RECORD_SIZE + budget::CURRENT)
}

/// WeatherDisasterPhase.run.
#[allow(clippy::too_many_arguments)]
pub fn run(
    city: &City,
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    power_usage_percent: i64,
    water_usage_percent: i64,
    commerce_connections: i64,
    industry_connections: i64,
    current_disaster_point: Vec2i,
) -> WeatherResult {
    let map_edge = city.map_size;

    if !city.misc.present || city.misc.data.len() as i64 != misc_layout::SIZE {
        return WeatherResult::failed("MISC is missing or has the wrong size");
    }

    if !city.xplt.present || city.xplt.data.len() as i64 != city.decoded_size("XPLT") {
        return WeatherResult::failed("XPLT is missing or has the wrong size");
    }

    let mut span = TimingSpan::new();
    span.mark("prepare data");
    let misc = &city.misc.data;
    span.mark("city status");
    let status_index = status_index(
        misc,
        random,
        power_usage_percent.max(0),
        water_usage_percent.max(0),
        commerce_connections & 0xffff,
        industry_connections & 0xffff,
        map_edge,
    );
    let mut news_items = Vec::new();

    if status_index >= 0 {
        news_items.push(NewsEvent::new(NEWS_DEMAND_BASE + status_index, 0));
    }

    span.mark("disaster selection and location");
    let mut result = match select_disaster(misc, &city.xplt.data, random, lfsr, current_disaster_point, map_edge) {
        Ok(selection) => selection,
        Err(message) => return WeatherResult::failed(message),
    };
    result.base.ok = true;
    result.status_index = status_index;
    result.status_news_type = if status_index >= 0 { NEWS_DEMAND_BASE + status_index } else { -1 };
    result.base.news_items = news_items;
    result.base.refresh_requests = ["toolbar", "map", "simnation", "weather_disaster"]
        .iter()
        .map(|request| request.to_string())
        .collect();
    result.base.timing = span.finish();
    result
}

/// The city status of 0x00471bc0: the first need in the original order,
/// STATUS_WEATHER, or STATUS_NONE. The recreation need draws one random value.
pub fn status_index(
    misc: &[u8],
    random: &mut SimRandom,
    power_usage_percent: i64,
    water_usage_percent: i64,
    commerce_connections: i64,
    industry_connections: i64,
    map_edge: i64,
) -> i64 {
    let count = |tile: i64| tile_count(misc, tile, map_edge);

    if read_u32_be(misc, misc_layout::WEATHER_TREND) & 0xff >= 9 {
        return STATUS_WEATHER;
    }

    if power_usage_percent >= 99 {
        return STATUS_POWER;
    }

    let population = read_u32_be(misc, misc_layout::NORMAL_POPULATION);
    let arcology_share = read_u32_be(misc, misc_layout::ARCOLOGY_POPULATION) / 12;
    let transit_capacity = count(tiles::SUBWAY_STATION) + count(tiles::RAIL_STATION) + budget_current(misc, budget::ROAD);

    if population / 100 >= transit_capacity {
        return STATUS_TRANSIT;
    }

    if population < 1000 {
        return STATUS_NONE;
    }

    let large_city_unit = population / 20000;

    if large_city_unit >= count(tiles::POLICE_STATION) / 9 + count(tiles::PRISON) / 16 {
        return STATUS_POLICE;
    }

    if large_city_unit >= count(tiles::FIRE_STATION) / 9 {
        return STATUS_FIRE;
    }

    if water_usage_percent >= 99 {
        return STATUS_WATER;
    }

    if population < 3000 {
        return STATUS_NONE;
    }

    if population / 25000 >= count(tiles::HOSPITAL) / 9 {
        return STATUS_HOSPITAL;
    }

    if large_city_unit >= count(tiles::SCHOOL) / 9 {
        return STATUS_SCHOOL;
    }

    if population < 8000 {
        return STATUS_NONE;
    }

    let industrial_population = budget_current(misc, budget::INDUSTRIAL) - arcology_share;

    if count(tiles::CRANE) + industry_connections < industrial_population / 10000 {
        if read_u32_be(misc, misc_layout::HAS_OCEAN) == 0 && read_u32_be(misc, misc_layout::HAS_RIVER) == 0 {
            return STATUS_INDUSTRIAL_CONNECTION;
        }

        return STATUS_SEAPORT;
    }

    let commercial_population = budget_current(misc, budget::COMMERCIAL) - arcology_share;

    if count(tiles::RUNWAY) + count(tiles::RUNWAY_CROSSING) + commerce_connections < commercial_population / 2000 {
        let airport_release_year = read_u32_be(misc, misc_layout::INVENTION_YEARS + 6 * 4) & 0xffff;

        return if airport_release_year == 0 {
            STATUS_AIRPORT
        } else {
            STATUS_COMMERCIAL_CONNECTION
        };
    }

    let recreation = count(tiles::BIG_PARK) / 3 + count(tiles::STADIUM) + count(tiles::ZOO) + count(tiles::MARINA);
    let residential_population = budget_current(misc, budget::RESIDENTIAL) - arcology_share * 2;

    if recreation < residential_population / 1000 {
        return STATUS_ZOO + (random.next_u15() & 3);
    }

    STATUS_NONE
}

fn random_map_point(random: &mut SimRandom, map_edge: i64) -> Vec2i {
    let y = random.next_u15() % (map_edge - 2) + 1;
    let x = random.next_u15() % (map_edge - 2) + 1;

    Vec2i::new(x, y)
}

fn random_center_point(random: &mut SimRandom, center: Vec2i, radius: i64) -> Vec2i {
    let y = (random.next_u15() & 0x1f) + center.y - radius;
    let x = (random.next_u15() & 0x1f) + center.x - radius;

    Vec2i::new(x, y)
}

/// WeatherDisasterPhase._toxic_spill_point.
pub fn toxic_spill_point(pollution: &[u8], lfsr: &mut SimLfsrRandom, map_edge: i64) -> Vec2i {
    let mut highest = 0;
    let mut point = Vec2i::NONE;
    let grid_edge = grid::edge(pollution, map_edge);

    if grid_edge == 0 {
        return point;
    }

    let scale = map_edge / grid_edge;

    for x in 0..grid_edge {
        for y in 0..grid_edge {
            let value = pollution[(x * grid_edge + y) as usize] as i64;

            if value <= 0x95 || value <= highest {
                continue;
            }

            if lfsr.next_mod(10) != 0 {
                continue;
            }

            highest = value;
            let px = x * scale + lfsr.next_mod(10) - 5;
            let py = y * scale + lfsr.next_mod(10) - 5;
            point = Vec2i::new(px, py);
        }
    }

    if point.x < 0 || point.x > map_edge - 1 || point.y < 0 || point.y > map_edge - 1 || highest == 0 {
        return Vec2i::NONE;
    }

    point
}

/// WeatherDisasterPhase._select_disaster.
pub fn select_disaster(
    misc: &[u8],
    pollution: &[u8],
    random: &mut SimRandom,
    lfsr: &mut SimLfsrRandom,
    current_point: Vec2i,
    map_edge: i64,
) -> Result<WeatherResult, String> {
    let difficulty = read_u32_be(misc, misc_layout::DIFFICULTY) & 0xffff;

    // TOMG_B1-B4 have a difficulty of 0, whose wait the original game divides
    // by. Another difficulty uses the Easy wait.
    let wait_months = if (DIFFICULTY_EASY..DISASTER_WAIT_MONTHS.len() as i64).contains(&difficulty) {
        DISASTER_WAIT_MONTHS[difficulty as usize]
    } else {
        DISASTER_WAIT_MONTHS[DIFFICULTY_EASY as usize]
    };
    let mut result = WeatherResult {
        disaster_type: DISASTER_NONE,
        disaster_point: current_point,
        wait_months,
        disaster_roll: -1,
        candidate_type: DISASTER_NONE,
        ..Default::default()
    };
    result.base.ok = true;

    if read_u32_be(misc, misc_layout::NO_DISASTERS) != 0 {
        return Ok(result);
    }

    if read_u32_be(misc, misc_layout::CITY_DAYS) / DAYS_PER_MONTH < wait_months {
        return Ok(result);
    }

    let roll = random.next_u15() % wait_months;
    result.disaster_roll = roll;
    let weather_trend = read_u32_be(misc, misc_layout::WEATHER_TREND) & 0xff;
    let has_ocean = read_u32_be(misc, misc_layout::HAS_OCEAN) != 0;
    let has_river = read_u32_be(misc, misc_layout::HAS_RIVER) != 0;

    if weather_trend == 10 && has_ocean && roll < 15 {
        result.disaster_type = DISASTER_HURRICANE;
        return Ok(result);
    }

    if weather_trend == 11 && roll < 15 {
        result.disaster_type = DISASTER_TORNADO;
        result.disaster_point = random_map_point(random, map_edge);
        return Ok(result);
    }

    if roll != 0 {
        return Ok(result);
    }

    let candidate = random.next_u15() % 19;
    result.candidate_type = candidate;
    let center = Vec2i::new(
        read_u32_be(misc, misc_layout::CITY_CENTER_X) & 0xffff,
        read_u32_be(misc, misc_layout::CITY_CENTER_Y) & 0xffff,
    );
    let population = read_u32_be(misc, misc_layout::NORMAL_POPULATION);
    let heat = read_u32_be(misc, misc_layout::WEATHER_HEAT) & 0xff;

    match candidate {
        DISASTER_FIRE => {
            if heat < (random.next_u15() & 0x7f) + 0x7f {
                return Ok(result);
            }

            result.disaster_point = random_map_point(random, map_edge);
        }
        DISASTER_TOXIC_SPILL => {
            let point = toxic_spill_point(pollution, lfsr, map_edge);

            if point.x < 0 {
                return Ok(result);
            }

            result.disaster_point = point;
        }
        DISASTER_EARTHQUAKE => result.disaster_point = random_map_point(random, map_edge),
        DISASTER_TORNADO => {
            if weather_trend < 8 {
                return Ok(result);
            }

            result.disaster_point = random_map_point(random, map_edge);
        }
        DISASTER_MONSTER => {
            if population < 45000 {
                return Ok(result);
            }

            result.disaster_point = random_center_point(random, center, 15);
        }
        DISASTER_MELTDOWN => {
            if tile_count(misc, tiles::NUCLEAR_POWER, map_edge) == 0 {
                return Ok(result);
            }
        }
        DISASTER_MICROWAVE => {
            if tile_count(misc, tiles::MICROWAVE_POWER, map_edge) == 0 {
                return Ok(result);
            }
        }
        DISASTER_RIOT | DISASTER_MASS_RIOTS => {
            if candidate == DISASTER_MASS_RIOTS && population < 30000 {
                return Ok(result);
            }

            if read_i32_be(misc, misc_layout::UNEMPLOYMENT) < 10 || heat < 170 {
                return Ok(result);
            }

            result.disaster_point = random_center_point(random, center, 16);
        }
        DISASTER_FLOOD | DISASTER_MASS_FLOODS => {
            if candidate == DISASTER_MASS_FLOODS && weather_trend < 9 {
                return Ok(result);
            }

            if (!has_ocean && !has_river) || weather_trend < 3 {
                return Ok(result);
            }

            result.disaster_point = random_map_point(random, map_edge);
        }
        DISASTER_POLLUTION => {
            if budget_current(misc, budget::INDUSTRIAL) < 10000 {
                return Ok(result);
            }

            result.disaster_point = random_center_point(random, center, 15);
        }
        DISASTER_HURRICANE => {
            if weather_trend < 8 || !has_ocean {
                return Ok(result);
            }
        }
        DISASTER_PLANE_CRASH => {
            if tile_count(misc, tiles::RUNWAY, map_edge) == 0 {
                return Ok(result);
            }

            result.disaster_point = random_map_point(random, map_edge);
        }
        _ => return Ok(result),
    }

    result.disaster_type = candidate;
    Ok(result)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::bytes::write_u32_be;
    use crate::sim::testing::{empty_city, sequence_lfsr, sequence_random};

    /// A difficulty of 0 waits as Easy does, and a roll then selects nothing.
    #[test]
    fn zero_difficulty_uses_the_easy_wait() {
        let mut city = empty_city(128);
        let misc = &mut city.misc.data;
        write_u32_be(misc, misc_layout::DIFFICULTY, 0);
        write_u32_be(misc, misc_layout::NO_DISASTERS, 0);
        write_u32_be(misc, misc_layout::CITY_DAYS, 0);
        let waiting = select_disaster(
            &city.misc.data,
            &city.xplt.data,
            &mut sequence_random(&[]),
            &mut sequence_lfsr(&[]),
            Vec2i::ZERO,
            128,
        )
        .unwrap();
        assert_eq!(waiting.wait_months, DISASTER_WAIT_MONTHS[DIFFICULTY_EASY as usize]);
        assert_eq!(waiting.disaster_roll, -1);

        write_u32_be(&mut city.misc.data, misc_layout::CITY_DAYS, 100000);
        let rolled = select_disaster(
            &city.misc.data,
            &city.xplt.data,
            &mut sequence_random(&[99, 0, 0, 0, 0]),
            &mut sequence_lfsr(&[0]),
            Vec2i::ZERO,
            128,
        )
        .unwrap();
        assert_eq!(rolled.disaster_roll, 99);
    }

    /// Random disaster points span the full interior of every map size. The y
    /// draw comes first.
    #[test]
    fn disaster_points_reach_the_far_interior() {
        for edge in [128i64, 256, 384, 512, 640, 1024] {
            let mut random = sequence_random(&[0, edge - 3, 777]);
            assert_eq!(random_map_point(&mut random, edge), Vec2i::new(edge - 2, 1));
            assert_eq!(random.next_u15(), 777, "a disaster point uses two random draws");
            let mut city = empty_city(edge);
            let misc = &mut city.misc.data;
            write_u32_be(misc, misc_layout::DIFFICULTY, 1);
            write_u32_be(misc, misc_layout::CITY_DAYS, 100000);
            write_u32_be(misc, misc_layout::NO_DISASTERS, 0);
            write_u32_be(misc, misc_layout::WEATHER_TREND, 11);
            let result = select_disaster(
                &city.misc.data,
                &city.xplt.data,
                &mut sequence_random(&[0, edge - 3, edge - 3]),
                &mut sequence_lfsr(&[0]),
                Vec2i::ZERO,
                edge,
            )
            .unwrap();
            assert!(result.disaster_type == DISASTER_TORNADO && result.disaster_point == Vec2i::new(edge - 2, edge - 2));
            let misc = &mut city.misc.data;
            write_u32_be(misc, misc_layout::WEATHER_TREND, 9);
            write_u32_be(misc, misc_layout::WEATHER_HEAT, 255);
            write_u32_be(misc, misc_layout::HAS_RIVER, 1);
            write_u32_be(misc, misc_layout::TILE_COUNTS + tiles::RUNWAY * 4, 1);

            for candidate in [
                DISASTER_FIRE,
                DISASTER_EARTHQUAKE,
                DISASTER_TORNADO,
                DISASTER_FLOOD,
                DISASTER_MASS_FLOODS,
                DISASTER_PLANE_CRASH,
            ] {
                let mut sequence = vec![0, candidate];

                if candidate == DISASTER_FIRE {
                    sequence.push(0);
                }

                sequence.extend([edge - 3, edge - 3]);
                let result = select_disaster(
                    &city.misc.data,
                    &city.xplt.data,
                    &mut sequence_random(&sequence),
                    &mut sequence_lfsr(&[0]),
                    Vec2i::ZERO,
                    edge,
                )
                .unwrap();
                assert_eq!(result.disaster_type, candidate);
                assert_eq!(
                    result.disaster_point,
                    Vec2i::new(edge - 2, edge - 2),
                    "disaster {candidate} passes the map edge"
                );
            }
        }
    }
}

#[cfg(test)]
mod count_tests {
    use super::*;
    use crate::sim::bytes::write_u32_be;
    use crate::sim::testing::{empty_city, empty_full_resolution_city, sequence_lfsr};

    #[test]
    fn tile_counts_keep_the_map_width() {
        for edge in [16i64, 32, 64, 128, 256, 384, 512, 640, 1024] {
            let mut city = empty_city(edge);
            write_u32_be(&mut city.misc.data, misc_layout::TILE_COUNTS + 0xd2 * 4, 40000);
            assert_eq!(tile_count(&city.misc.data, 0xd2, edge), if edge == 128 { -25536 } else { 40000 });
        }
    }

    /// The toxic spill search scans per-tile pollution in native coordinates.
    #[test]
    fn toxic_spills_start_at_high_native_pollution() {
        for edge in [128i64, 512] {
            let mut city = empty_full_resolution_city(edge);
            let point = Vec2i::new(edge - 32, edge - 32);
            assert_eq!(
                toxic_spill_point(&city.xplt.data, &mut sequence_lfsr(&[0]), edge).x,
                -1,
                "low pollution is not a toxic source"
            );
            city.xplt.data[(point.x * edge + point.y) as usize] = 200;
            assert_eq!(
                toxic_spill_point(&city.xplt.data, &mut sequence_lfsr(&[0]), edge),
                point - Vec2i::new(5, 5)
            );
        }
    }
}
