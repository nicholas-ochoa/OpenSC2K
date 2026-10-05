//! Pollution, land value, crime, population, growth, and service coverage maps.
//! `coarse` keeps the original half and quarter grids. `native` is the SC2X v3
//! per-tile scan.

pub mod coarse;
pub mod grid_math;
pub mod native;

use crate::gd_phase_result;
use crate::sim::city::City;
use crate::sim::geom::Vec2i;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::ordinance_ids;
use crate::sim::ids::sc2budget_layout;
use crate::sim::ids::sc2misc_layout as misc_layout;

pub const CLEAN_INDUSTRY_ORDINANCE: i64 = ordinance_ids::POLLUTION_CONTROLS_MASK;
pub const POLICE_COVERAGE_ORDINANCE: i64 = ordinance_ids::NEIGHBORHOOD_WATCH_MASK;
pub const FIRE_COVERAGE_ORDINANCE: i64 = ordinance_ids::VOLUNTEER_FIRE_MASK;
pub const CRIME_REDUCTION_ORDINANCE: i64 = ordinance_ids::LEGALIZED_GAMBLING_MASK;
pub const ZONE_BUILDING_ORIGIN: i64 = 0x80;

gd_phase_result! {
    pub struct PollutionResult as "PollutionPhase.Result" {
        pub pollution_total: i64 = 0,
        pub land_value_total: i64 = 0,
        pub crime_total: i64 = 0,
        pub developed_tiles: i64 = 0,
        pub city_center: Vec2i = Vec2i::ZERO,
    }
}

gd_phase_result! {
    pub struct CoverageResult as "NativeDataMapPhase.PollutionCoverageResult" {
        pub pollution_total: i64 = 0,
        pub city_center: Vec2i = Vec2i::ZERO,
    }
}

/// Nonzero bytes from the executable table at 0x004e95b8.
pub const fn building_pollution(tile: i64) -> i64 {
    match tile {
        tiles::WAREHOUSE_1X1_2 | tiles::CHEMICAL_STORAGE_1X1 | tiles::WAREHOUSE_1X1_3 | tiles::INDUSTRIAL_SUBSTATION_1X1 => 6,
        tiles::WAREHOUSE_2X2 | tiles::CHEMICAL_PROCESSING_2X2 | tiles::FACTORY_2X2_1 | tiles::FACTORY_2X2_2 => 12,
        tiles::FACTORY_2X2_3 | tiles::FACTORY_2X2_4 | tiles::FACTORY_2X2_5 | tiles::FACTORY_2X2_6 => 18,
        tiles::CHEMICAL_PROCESSING_3X3
        | tiles::LARGE_FACTORY_3X3
        | tiles::INDUSTRIAL_THINGAMAJIG_3X3
        | tiles::FACTORY_3X3
        | tiles::LARGE_WAREHOUSE_3X3
        | tiles::WAREHOUSE_3X3 => 24,
        tiles::GAS_POWER => 10,
        tiles::OIL_POWER => 25,
        tiles::NUCLEAR_POWER | tiles::FUSION_POWER => 2,
        tiles::COAL_POWER => 50,
        tiles::STADIUM => 4,
        tiles::PRISON => 10,
        tiles::WATER_PUMP => 2,
        tiles::RUNWAY | tiles::RUNWAY_CROSSING | tiles::PIER => 10,
        tiles::CRANE | tiles::SEAPORT_WAREHOUSE | tiles::AIRPORT_BUILDING_1 | tiles::AIRPORT_BUILDING_2 => 5,
        tiles::TARMAC | tiles::FIGHTER_JET => 10,
        tiles::SUBWAY_STATION => 5,
        tiles::BUS_DEPOT => 3,
        tiles::RAIL_STATION => 4,
        tiles::PARKING_LOT_1 | tiles::PARKING_LOT_2 | tiles::LOADING_BAY | tiles::TOP_SECRET => 2,
        tiles::CARGO_YARD | tiles::WATER_TREATMENT => 10,
        tiles::HANGAR_2 => 5,
        tiles::PLYMOUTH_ARCOLOGY => 25,
        tiles::FOREST_ARCOLOGY => 10,
        tiles::DARCO_ARCOLOGY => 12,
        tiles::LAUNCH_ARCOLOGY => 15,
        _ => 0,
    }
}

pub const fn land_value_halved(tile: i64) -> bool {
    matches!(
        tile,
        tiles::ABANDONED_1X1_1
            | tiles::ABANDONED_1X1_2
            | tiles::ABANDONED_2X2_1
            | tiles::ABANDONED_2X2_2
            | tiles::ABANDONED_2X2_3
            | tiles::ABANDONED_2X2_4
            | tiles::ABANDONED_3X3_1
            | tiles::ABANDONED_3X3_2
    )
}

/// PollutionValues._population_weight.
pub fn population_weight(building: i64) -> i64 {
    use tiles::*;

    if (DEVELOPED_FIRST..=CONSTRUCTION_1X1_LAST).contains(&building) {
        1
    } else if (RESIDENTIAL_2X2_FIRST..=NICE_APARTMENTS_2X2_1).contains(&building) {
        2
    } else if (NICE_APARTMENTS_2X2_2..=RESIDENTIAL_2X2_LAST).contains(&building) {
        3
    } else if (COMMERCIAL_2X2_FIRST..=OFFICE_BUILDING_2X2_2).contains(&building) {
        2
    } else if (OFFICE_RETAIL_2X2..=COMMERCIAL_2X2_LAST).contains(&building) {
        3
    } else if (INDUSTRIAL_2X2_FIRST..=FACTORY_2X2_2).contains(&building) {
        2
    } else if (FACTORY_2X2_3..=INDUSTRIAL_2X2_LAST).contains(&building) {
        3
    } else if (CONSTRUCTION_2X2_FIRST..=CONSTRUCTION_2X2_2).contains(&building) {
        2
    } else if (CONSTRUCTION_2X2_3..=CONSTRUCTION_2X2_LAST).contains(&building) {
        3
    } else if (RESIDENTIAL_3X3_FIRST..=CONSTRUCTION_3X3_LAST).contains(&building) {
        4
    } else {
        0
    }
}

/// PollutionValues.pollution_divisor. It sign-extends the low word, so
/// 0x0000ffff means -1 here.
pub fn pollution_divisor(city: &City) -> i64 {
    let mut value = city.misc_u32(misc_layout::TREATMENT_SUFFICIENT) - city.misc_u32(misc_layout::INDUSTRIAL_POLLUTION_BONUS) + 4;

    if city.misc_u32(misc_layout::ORDINANCES) & CLEAN_INDUSTRY_ORDINANCE != 0 {
        value += 1;
    }

    value &= 0xffff;

    if value >= 0x8000 {
        value -= 0x10000;
    }

    value.max(1)
}

/// PollutionValues._budget_funding.
pub fn budget_funding(city: &City, budget_id: i64) -> i64 {
    city.misc_i32(misc_layout::BUDGETS + budget_id * sc2budget_layout::RECORD_SIZE + 4)
}

/// The police and fire station strengths from the budget and the prison bonus.
pub fn station_strengths(city: &City) -> (i64, i64) {
    let police = ((city.misc_i32(misc_layout::PRISON_BONUS) + 5) * budget_funding(city, sc2budget_layout::POLICE)) / 2;
    let fire = (budget_funding(city, sc2budget_layout::FIRE) * 5) / 2;

    (police, fire)
}
