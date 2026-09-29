//! The city value, as CityValuePhase. These rules reproduce the executable at
//! 0x0046a270. Some values are defects. In particular, each underground subway
//! tile subtracts one dollar. The executable indexes shifted cost tables for
//! 0xc6 through 0xcf. These are valuation constants, not the matching
//! buildings' construction costs.

use super::to_i32;
use crate::gd_phase_result;
use crate::sim::bytes::write_u32_be;
use crate::sim::city::City;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::phase::PhaseResultLike;

gd_phase_result! {
    pub struct CityValueResult as "CityValuePhase.Result" {
        pub city_value: i64 = 0,
    }
}

const BUILDING_RULES: [(i64, i64, i64); 47] = [
    (tiles::HYDRO_POWER_1, 1, 4000),
    (tiles::HYDRO_POWER_2, 1, 400),
    (tiles::WIND_POWER, 1, 6600),
    (tiles::GAS_POWER, 16, 6600),
    (tiles::OIL_POWER, 16, 2000),
    (tiles::NUCLEAR_POWER, 16, 15000),
    (tiles::SOLAR_POWER, 16, 100),
    (tiles::MICROWAVE_POWER, 16, 1300),
    (tiles::FUSION_POWER, 16, 28000),
    (tiles::COAL_POWER, 16, 40000),
    (tiles::HOSPITAL, 9, 500),
    (tiles::POLICE_STATION, 9, 500),
    (tiles::FIRE_STATION, 9, 500),
    (tiles::MUSEUM, 9, 1000),
    (tiles::BIG_PARK, 9, 150),
    (tiles::SCHOOL, 9, 250),
    (tiles::STADIUM, 16, 3000),
    (tiles::PRISON, 16, 3000),
    (tiles::COLLEGE, 16, 1000),
    (tiles::ZOO, 16, 5000),
    (tiles::WATER_PUMP, 1, 100),
    (tiles::RUNWAY, 1, 250),
    (tiles::RUNWAY_CROSSING, 1, 250),
    (tiles::PIER, 1, 150),
    (tiles::CRANE, 1, 150),
    (tiles::CONTROL_TOWER_1, 1, 250),
    (tiles::SEAPORT_WAREHOUSE, 1, 150),
    (tiles::AIRPORT_BUILDING_1, 1, 250),
    (tiles::AIRPORT_BUILDING_2, 1, 250),
    (tiles::TARMAC, 1, 250),
    (tiles::SUBWAY_STATION, 1, 250),
    (tiles::RADAR, 1, 250),
    (tiles::WATER_TOWER, 4, 250),
    (tiles::BUS_DEPOT, 4, 250),
    (tiles::RAIL_STATION, 4, 500),
    (tiles::PARKING_LOT_1, 1, 250),
    (tiles::LOADING_BAY, 1, 150),
    (tiles::CARGO_YARD, 1, 150),
    (tiles::WATER_TREATMENT, 9, 500),
    (tiles::LIBRARY, 4, 500),
    (tiles::HANGAR_2, 1, 250),
    (tiles::MARINA, 9, 1000),
    (tiles::DESALINIZATION, 9, 1000),
    (tiles::PLYMOUTH_ARCOLOGY, 16, 100000),
    (tiles::FOREST_ARCOLOGY, 16, 120000),
    (tiles::DARCO_ARCOLOGY, 16, 150000),
    (tiles::LAUNCH_ARCOLOGY, 16, 200000),
];

/// A saved count. 128 tile maps read the signed low word.
fn read_count(misc: &[u8], offset: i64, map_edge: i64) -> i64 {
    let o = offset as usize;

    if map_edge == 128 {
        let value = ((misc[o + 2] as i64) << 8) | misc[o + 3] as i64;
        return if value & 0x8000 != 0 { value - 0x10000 } else { value };
    }

    ((misc[o] as i64) << 24) | ((misc[o + 1] as i64) << 16) | ((misc[o + 2] as i64) << 8) | misc[o + 3] as i64
}

/// CityValuePhase.calculate.
pub fn calculate(city: &City) -> CityValueResult {
    if !city.misc.present || city.misc.data.len() as i64 != misc_layout::SIZE {
        return CityValueResult::failed("MISC is missing or has the wrong size");
    }

    let misc = &city.misc.data;
    let edge = city.map_size;
    let count = |tile: i64| read_count(misc, misc_layout::TILE_COUNTS + tile * 4, edge);
    let mut value = to_i32(-read_count(misc, misc_layout::SUBWAY_COUNT, edge));

    for tile in tiles::POWER_LINE_FIRST..tiles::DEVELOPED_FIRST {
        let cost = if tile < tiles::ROAD_STRAIGHT_1 {
            2
        } else if tile < tiles::RAIL_STRAIGHT_1 {
            10
        } else if tile < tiles::TUNNEL_ENTRANCE_1 {
            25
        } else if tile < tiles::SUSPENSION_BRIDGE_1 {
            15
        } else {
            // Bridges, highways, and rail-subway entrances.
            if tile < tiles::RAIL_SUBWAY_ENTRANCE_1 { 100 } else { 250 }
        };
        value = to_i32(value + to_i32(count(tile) * cost));
    }

    for (tile, divisor, cost) in BUILDING_RULES {
        value = to_i32(value + to_i32((count(tile) / divisor) * cost));
    }

    let mut result = CityValueResult { city_value: value, ..Default::default() };
    result.base_mut().ok = true;
    result
}

/// CityValuePhase.run: calculate and store the city value.
pub fn run(city: &mut City) -> CityValueResult {
    let calculated = calculate(city);

    if calculated.base.ok {
        write_u32_be(city.misc.mutate(), misc_layout::CITY_VALUE, calculated.city_value);
    }

    calculated
}
