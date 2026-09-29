//! The yearly settlement and the monthly budget, as BudgetPhase.

use super::ordinances::{budget_offset, current_cost_for_misc};
use super::{divide_toward_zero, to_i32};
use crate::gd_phase_result;
use crate::sim::bytes::{read_i32_be, read_u32_be, write_u32_be};
use crate::sim::city::City;
use crate::sim::events::NewsEvent;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::city_calendar::{DAYS_PER_MONTH, DAYS_PER_YEAR, MONTHS_PER_YEAR};
use crate::sim::ids::sc2budget_layout as budget;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::phase::{PhaseResultLike, TimingSpan};
use crate::sim::random::SimRandom;
use crate::sim::value::Ints32;

const ANNUAL_DIVISOR_FACTORS: [i64; 16] = [75, 75, 75, 75, -100, -1, -1, -2, -4, -1, -1000, -500, -400, -250, -250, -250];
const SERVICE_TILE_IDS: [(i64, i64); 5] = [
    (budget::POLICE, tiles::POLICE_STATION),
    (budget::FIRE, tiles::FIRE_STATION),
    (budget::HEALTH, tiles::HOSPITAL),
    (budget::SCHOOL, tiles::SCHOOL),
    (budget::COLLEGE, tiles::COLLEGE),
];
pub const NEWS_ORDINANCE: i64 = 0x29;
/// The city council message when negative funds turn off Auto Budget.
pub const NOTICE_FISCAL_CRISIS: i32 = 292;

gd_phase_result! {
    pub struct BudgetResult as "BudgetPhase.Result" {
        pub month: i64 = 0,
        pub settled_year: bool = false,
        pub funds_before: i64 = 0,
        pub funds_after: i64 = 0,
        pub auto_budget_disabled: bool = false,
        pub requires_annual_budget: bool = false,
        pub current_costs: Ints32 = Ints32::default(),
        pub annual_microsim_update_pending: bool = false,
    }
}

fn month(city: &City) -> i64 {
    (city.age_in_days() % DAYS_PER_YEAR) / DAYS_PER_MONTH
}

fn misc_valid(city: &City) -> bool {
    city.misc.present && city.misc.data.len() as i64 == misc_layout::SIZE
}

fn tile_count(misc: &[u8], tile: i64) -> i64 {
    read_i32_be(misc, misc_layout::TILE_COUNTS + tile * 4)
}

fn add_current(misc: &mut [u8], budget_id: i64, value: i64) {
    let offset = budget_offset(budget_id);
    let current = read_i32_be(misc, offset);
    write_u32_be(misc, offset, to_i32(current + value));
}

/// BudgetPhase.settle_year: the first part of the January budget. The
/// original runs the annual facility update after this part.
pub fn settle_year(city: &mut City, annual_budget_approved: bool) -> BudgetResult {
    if !misc_valid(city) {
        return BudgetResult::failed("MISC is missing or has the wrong size");
    }

    let mut span = TimingSpan::new();
    span.mark("prepare data");
    let mut misc = city.misc.data.clone();
    let month = month(city);
    let funds_before = read_i32_be(&misc, misc_layout::FUNDS);
    let mut funds = funds_before;
    let mut settled_year = false;
    let year_end = read_u32_be(&misc, misc_layout::YEAR_END) != 0;

    if year_end && month == 0 && read_u32_be(&misc, misc_layout::AUTO_BUDGET) == 0 && !annual_budget_approved {
        let mut interactive = BudgetResult {
            month,
            requires_annual_budget: true,
            ..Default::default()
        };
        interactive.base.ok = true;
        interactive.base.complete = false;
        interactive.base.timing = span.finish();

        return interactive;
    }

    if year_end && month == 0 {
        span.mark("annual settlement");
        settled_year = true;

        for budget_id in 0..budget::COUNT {
            let offset = budget_offset(budget_id);
            let factor = ANNUAL_DIVISOR_FACTORS[budget_id as usize];

            if factor != 0 {
                let year_to_date = read_i32_be(&misc, offset + budget::YEAR_TO_DATE);
                funds = to_i32(funds + divide_toward_zero(year_to_date, factor * MONTHS_PER_YEAR));
            }

            write_u32_be(&mut misc, offset + budget::YEAR_TO_DATE, 0);
        }

        write_u32_be(&mut misc, misc_layout::YEAR_END, 0);
        write_u32_be(&mut misc, misc_layout::FUNDS, funds);
        city.misc.replace(misc);
    }

    let mut result = BudgetResult {
        month,
        settled_year,
        funds_before,
        funds_after: funds,
        annual_microsim_update_pending: settled_year,
        ..Default::default()
    };
    result.base.ok = true;
    result.base.complete = !settled_year;
    result.base.timing = span.finish();
    result
}

/// BudgetPhase.run_month: the Auto Budget check after a settlement, the
/// monthly history, the next costs, and the random ordinance.
pub fn run_month(city: &mut City, random: &mut SimRandom, settlement: &BudgetResult) -> BudgetResult {
    if !settlement.base.ok {
        return BudgetResult::failed("the annual settlement is missing");
    }

    if !misc_valid(city) {
        return BudgetResult::failed("MISC is missing or has the wrong size");
    }

    let mut span = TimingSpan::new();
    span.mark("prepare data");
    let mut misc = city.misc.data.clone();
    let month = month(city);
    let mut auto_budget_disabled = false;

    // The annual facility update can change funds before this check.
    if settlement.settled_year && read_i32_be(&misc, misc_layout::FUNDS) < 0 && read_u32_be(&misc, misc_layout::AUTO_BUDGET) != 0 {
        write_u32_be(&mut misc, misc_layout::AUTO_BUDGET, 0);
        auto_budget_disabled = true;
    }

    span.mark("monthly history");

    for budget_id in 0..budget::COUNT {
        let offset = budget_offset(budget_id);
        let current = read_i32_be(&misc, offset + budget::CURRENT);
        let funding = read_i32_be(&misc, offset + budget::FUNDING);
        let month_offset = offset + budget::MONTHS + month * budget::MONTH_RECORD_SIZE;
        write_u32_be(&mut misc, month_offset, current);
        write_u32_be(&mut misc, month_offset + budget::MONTH_FUNDING, funding);
        let year_to_date = read_i32_be(&misc, offset + budget::YEAR_TO_DATE);
        let funded_cost = to_i32(current * funding);
        write_u32_be(&mut misc, offset + budget::YEAR_TO_DATE, to_i32(year_to_date + funded_cost));
    }

    if month == MONTHS_PER_YEAR - 1 {
        write_u32_be(&mut misc, misc_layout::YEAR_END, 1);
    }

    let bonds = read_i32_be(&misc, misc_layout::BONDS);
    write_u32_be(&mut misc, budget_offset(budget::BONDS), bonds);
    span.mark("service and network costs");

    for (budget_id, tile) in SERVICE_TILE_IDS {
        let divisor = if budget_id == budget::COLLEGE { 16 } else { 9 };
        let count = tile_count(&misc, tile);
        write_u32_be(&mut misc, budget_offset(budget_id), divide_toward_zero(count, divisor));
    }

    for budget_id in budget::ROAD..=budget::TUNNEL {
        write_u32_be(&mut misc, budget_offset(budget_id), 0);
    }

    for tile in tiles::FIRST_ROAD..tiles::DEVELOPED_FIRST {
        let count = tile_count(&misc, tile);

        if (tiles::ROAD_STRAIGHT_1..=tiles::ROAD_CROSSROADS).contains(&tile)
            || (tiles::TUNNEL_ENTRANCE_1..=tiles::ROAD_RAIL_CROSSING_2).contains(&tile)
            || tile == tiles::HIGHWAY_ROAD_CROSSING_1
            || tile == tiles::HIGHWAY_ROAD_CROSSING_2
            || (tiles::HIGHWAY_ONRAMP_1..=tiles::HIGHWAY_ONRAMP_4).contains(&tile)
        {
            add_current(&mut misc, budget::ROAD, count);
        }

        if (tiles::RAIL_STRAIGHT_1..=tiles::RAIL_SLOPE_8).contains(&tile)
            || (tiles::ROAD_RAIL_CROSSING_1..=tiles::RAIL_POWER_CROSSING_2).contains(&tile)
            || (tiles::RAIL_SUBWAY_ENTRANCE_1..=tiles::RAIL_SUBWAY_ENTRANCE_4).contains(&tile)
            || tile == tiles::HIGHWAY_RAIL_CROSSING_1
            || tile == tiles::HIGHWAY_RAIL_CROSSING_2
        {
            add_current(&mut misc, budget::RAIL, count);
        }

        if (tiles::SUSPENSION_BRIDGE_1..=tiles::POWER_BRIDGE).contains(&tile)
            || tile == tiles::HIGHWAY_BRIDGE
            || tile == tiles::REINFORCED_HIGHWAY_BRIDGE
        {
            add_current(&mut misc, budget::BRIDGE, count);
        }

        if (tiles::HIGHWAY_SLOPE_1..=tiles::REINFORCED_HIGHWAY_BRIDGE).contains(&tile)
            || (tiles::HIGHWAY_STRAIGHT_1..=tiles::HIGHWAY_POWER_CROSSING_2).contains(&tile)
        {
            add_current(&mut misc, budget::HIGHWAY, count);
        }

        if (tiles::TUNNEL_ENTRANCE_1..=tiles::TUNNEL_ENTRANCE_4).contains(&tile) {
            add_current(&mut misc, budget::TUNNEL, count);
        }
    }

    let subway = tile_count(&misc, tiles::SUBWAY_STATION) + read_u32_be(&misc, misc_layout::SUBWAY_COUNT);
    write_u32_be(&mut misc, budget_offset(budget::SUBWAY), subway);
    let rail_stations = tile_count(&misc, tiles::RAIL_STATION);
    add_current(&mut misc, budget::RAIL, rail_stations);
    let bus_depots = tile_count(&misc, tiles::BUS_DEPOT);
    add_current(&mut misc, budget::ROAD, divide_toward_zero(bus_depots, 4) * 250);
    let ordinance_cost = current_cost_for_misc(&misc);
    write_u32_be(&mut misc, budget_offset(budget::ORDINANCES), ordinance_cost);
    span.mark("ordinance events");
    let mut news_items = Vec::new();

    if read_u32_be(&misc, misc_layout::NO_DISASTERS) == 0
        && random.next_u15() & 7 == 0
        && (random.next_u15() & 0xffff) + 50000 < read_i32_be(&misc, misc_layout::FUNDS)
    {
        let ordinance = random.next_u15() % 20;
        let flags = read_u32_be(&misc, misc_layout::ORDINANCES);
        write_u32_be(&mut misc, misc_layout::ORDINANCES, flags | (1 << ordinance));
        news_items.push(NewsEvent::new(NEWS_ORDINANCE, ordinance));
    }

    span.mark("store budget");
    let current_costs = (0..budget::COUNT)
        .map(|budget_id| read_i32_be(&misc, budget_offset(budget_id)) as i32)
        .collect();
    let funds_after = read_i32_be(&misc, misc_layout::FUNDS);
    city.misc.replace(misc);

    let mut result = BudgetResult {
        month,
        settled_year: settlement.settled_year,
        funds_before: settlement.funds_before,
        funds_after,
        auto_budget_disabled,
        current_costs: Ints32(current_costs),
        annual_microsim_update_pending: settlement.settled_year,
        ..Default::default()
    };
    result.base.ok = true;

    if auto_budget_disabled {
        result.base.notice_ids.0.push(NOTICE_FISCAL_CRISIS);
    }

    result.base.news_items = news_items;
    result.base.complete = !settlement.settled_year;
    result.base.timing = span.finish();

    for (label, value) in settlement.base.timing.steps.0.iter() {
        let total = result.base.timing.steps.get(label).copied().unwrap_or(0) + value;
        result.base.timing.steps.set(label, total);
    }

    result.base.timing.work_usec += settlement.base.timing.work_usec;
    result
}

/// BudgetPhase.run: settle the year and do the monthly work, without the
/// annual facility update.
pub fn run(city: &mut City, random: &mut SimRandom, annual_budget_approved: bool) -> BudgetResult {
    let settlement = settle_year(city, annual_budget_approved);

    if !settlement.base.ok || settlement.requires_annual_budget {
        return settlement;
    }

    run_month(city, random, &settlement)
}

pub fn requires_annual_budget(city: &City) -> bool {
    city.age_in_days() % DAYS_PER_YEAR == 0 && city.misc_u32(misc_layout::YEAR_END) != 0 && city.misc_u32(misc_layout::AUTO_BUDGET) == 0
}

pub fn funding_values(city: &City) -> Vec<i32> {
    (0..budget::COUNT)
        .map(|budget_id| city.misc_i32(budget_offset(budget_id) + budget::FUNDING) as i32)
        .collect()
}

/// BudgetPhase.set_funding.
pub fn set_funding(city: &mut City, values: &[i32], auto_budget: bool) -> BudgetResult {
    if values.len() as i64 != budget::COUNT {
        return BudgetResult::failed("sixteen budget funding values are required");
    }

    if !misc_valid(city) {
        return BudgetResult::failed("MISC is missing or has the wrong size");
    }

    let mut misc = city.misc.data.clone();

    for (budget_id, value) in values.iter().enumerate() {
        write_u32_be(&mut misc, budget_offset(budget_id as i64) + budget::FUNDING, *value as i64);
    }

    write_u32_be(&mut misc, misc_layout::AUTO_BUDGET, auto_budget as i64);
    city.misc.replace(misc);
    let mut result = BudgetResult::default();
    result.base_mut().ok = true;
    result
}
