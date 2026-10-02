//! Ordinance costs and the ordinance window commands, as OrdinanceCommand.

use super::{divide_toward_zero as div, to_i32};
use crate::gd_object;
use crate::sim::bytes::{read_i32_be, read_u32_be, write_u32_be};
use crate::sim::ids::city_calendar as calendar;
use crate::sim::ids::ordinance_ids;
use crate::sim::ids::sc2budget_layout as budget;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::value::Ints32;

pub fn budget_offset(budget_id: i64) -> i64 {
    misc_layout::BUDGETS + budget_id * budget::RECORD_SIZE
}

/// The monthly cost of each ordinance. Revenue is negative.
pub fn costs_for_misc(misc: &[u8]) -> Vec<i64> {
    if misc.len() as i64 != misc_layout::SIZE {
        return Vec::new();
    }

    let residential = read_i32_be(misc, budget_offset(budget::RESIDENTIAL));
    let commercial = read_i32_be(misc, budget_offset(budget::COMMERCIAL));
    let industrial = read_i32_be(misc, budget_offset(budget::INDUSTRIAL));
    let population = to_i32(read_u32_be(misc, misc_layout::ARCOLOGY_POPULATION) + read_u32_be(misc, misc_layout::NORMAL_POPULATION));

    vec![
        commercial,
        residential,
        to_i32(commercial * 2),
        div(residential, 2),
        div(residential, -3),
        div(commercial, -6),
        -div(residential, 2),
        -div(residential, 4),
        div(residential, -6),
        div(residential, -5),
        div(residential, -6),
        div(residential, -3),
        -commercial,
        -industrial,
        -div(residential, 4),
        div(commercial, -3),
        -population,
        0,
        -div(residential, 2),
        -industrial,
    ]
}

pub fn current_cost_for_misc(misc: &[u8]) -> i64 {
    if misc.len() as i64 != misc_layout::SIZE {
        return 0;
    }

    let costs = costs_for_misc(misc);
    let flags = read_u32_be(misc, misc_layout::ORDINANCES);
    let mut total = 0;

    for ordinance in 0..ordinance_ids::COUNT {
        if flags & (1 << ordinance) != 0 {
            total = to_i32(total + costs[ordinance as usize]);
        }
    }

    total
}

/// The budget window shows ordinance costs in these units.
pub const DISPLAY_CURRENT_DIVISOR: i64 = 75;
pub const DISPLAY_ANNUAL_DIVISOR: i64 = 900;
/// Each budget-window category holds four ordinances.
pub const ORDINANCES_PER_CATEGORY: i64 = 4;
pub const CATEGORY_COUNT: usize = 5;

gd_object! {
    pub struct OrdinanceResult as "OrdinanceCommand.Result" {
        pub ok: bool = false,
        pub error: String = String::new(),
        pub changed: bool = false,
        pub flags: i64 = 0,
        pub current_raw: i64 = 0,
        pub raw_costs: Ints32 = Ints32::default(),
        pub item_amounts: Ints32 = Ints32::default(),
        pub category_amounts: Ints32 = Ints32::default(),
        pub year_to_date_amount: i64 = 0,
        pub estimated_amount: i64 = 0,
        pub month: i64 = 0,
    }
}

impl OrdinanceResult {
    pub fn failed(message: &str) -> Self {
        Self {
            error: message.to_string(),
            ..Default::default()
        }
    }
}

fn ints32(values: impl IntoIterator<Item = i64>) -> Ints32 {
    Ints32(values.into_iter().map(|value| value as i32).collect())
}

fn misc_error(misc: &[u8]) -> Option<OrdinanceResult> {
    if misc.len() as i64 != misc_layout::SIZE {
        return Some(OrdinanceResult::failed("MISC is missing or has the wrong size"));
    }

    None
}

/// OrdinanceCommand.snapshot: the costs and budget-window amounts.
pub fn snapshot(misc: &[u8]) -> OrdinanceResult {
    if let Some(failure) = misc_error(misc) {
        return failure;
    }

    let flags = read_u32_be(misc, misc_layout::ORDINANCES);
    let raw_costs = costs_for_misc(misc);
    let mut item_amounts = Vec::new();
    let mut category_raw = [0i64; CATEGORY_COUNT];
    let mut current_raw = 0;

    for ordinance in 0..ordinance_ids::COUNT {
        let raw = if flags & (1 << ordinance) != 0 {
            raw_costs[ordinance as usize]
        } else {
            0
        };
        item_amounts.push(div(raw, DISPLAY_CURRENT_DIVISOR));
        current_raw = to_i32(current_raw + raw);
        let category = (ordinance / ORDINANCES_PER_CATEGORY) as usize;
        category_raw[category] = to_i32(category_raw[category] + raw);
    }

    let budget_offset = budget_offset(budget::ORDINANCES);
    let year_to_date_raw = read_i32_be(misc, budget_offset + budget::YEAR_TO_DATE);
    let day_of_year = read_u32_be(misc, misc_layout::CITY_DAYS) % calendar::DAYS_PER_YEAR;
    let month = day_of_year / calendar::DAYS_PER_MONTH;

    let estimated_raw = if read_u32_be(misc, misc_layout::YEAR_END) == 0 {
        to_i32((calendar::MONTHS_PER_YEAR - 1 - month) * current_raw + year_to_date_raw)
    } else {
        to_i32(current_raw * calendar::MONTHS_PER_YEAR)
    };

    OrdinanceResult {
        ok: true,
        flags,
        raw_costs: ints32(raw_costs),
        item_amounts: ints32(item_amounts),
        category_amounts: ints32(category_raw.iter().map(|&raw| div(raw, DISPLAY_CURRENT_DIVISOR))),
        current_raw,
        year_to_date_amount: div(year_to_date_raw, DISPLAY_ANNUAL_DIVISOR),
        estimated_amount: div(estimated_raw, DISPLAY_ANNUAL_DIVISOR),
        month,
        ..Default::default()
    }
}

/// OrdinanceCommand.synchronize_current: store the current ordinance total in
/// the ordinance budget record. Returns the changed MISC copy, if any.
pub fn synchronize_current(misc: &[u8]) -> (OrdinanceResult, Option<Vec<u8>>) {
    if let Some(failure) = misc_error(misc) {
        return (failure, None);
    }

    let offset = budget_offset(budget::ORDINANCES) + budget::CURRENT;
    let current = current_cost_for_misc(misc);
    let mut result = OrdinanceResult {
        ok: true,
        current_raw: current,
        ..Default::default()
    };

    if read_i32_be(misc, offset) == current {
        return (result, None);
    }

    let mut changed = misc.to_vec();
    write_u32_be(&mut changed, offset, current);
    result.changed = true;

    (result, Some(changed))
}

/// OrdinanceCommand.set_enabled. Returns the changed MISC copy, if any.
pub fn set_enabled(misc: &[u8], ordinance: i64, enabled: bool) -> (OrdinanceResult, Option<Vec<u8>>) {
    if !(0..ordinance_ids::COUNT).contains(&ordinance) {
        return (OrdinanceResult::failed("ordinance is outside the valid range"), None);
    }

    if let Some(failure) = misc_error(misc) {
        return (failure, None);
    }

    let old_flags = read_u32_be(misc, misc_layout::ORDINANCES);
    let mask = 1 << ordinance;
    let new_flags = if enabled { old_flags | mask } else { old_flags & !mask };
    let mut changed = misc.to_vec();
    write_u32_be(&mut changed, misc_layout::ORDINANCES, new_flags);
    let current = current_cost_for_misc(&changed);
    write_u32_be(&mut changed, budget_offset(budget::ORDINANCES) + budget::CURRENT, current);
    let has_change = changed != misc;
    let result = OrdinanceResult {
        ok: true,
        changed: has_change,
        flags: new_flags,
        current_raw: current,
        ..Default::default()
    };

    (result, has_change.then_some(changed))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn misc_with(residential: i64, commercial: i64, flags: i64) -> Vec<u8> {
        let mut misc = vec![0u8; misc_layout::SIZE as usize];
        write_u32_be(&mut misc, budget_offset(budget::RESIDENTIAL), residential);
        write_u32_be(&mut misc, budget_offset(budget::COMMERCIAL), commercial);
        write_u32_be(&mut misc, misc_layout::ORDINANCES, flags);
        misc
    }

    #[test]
    fn enabling_an_ordinance_updates_its_flag_and_the_budget_total() {
        let misc = misc_with(3000, 1200, 0);
        let (result, changed) = set_enabled(&misc, ordinance_ids::ID_SALES_TAX, true);
        let changed = changed.expect("a new flag");
        assert_eq!((result.flags, result.current_raw), (1, 1200));
        assert_eq!(read_i32_be(&changed, budget_offset(budget::ORDINANCES) + budget::CURRENT), 1200);

        let (again, unchanged) = set_enabled(&changed, ordinance_ids::ID_SALES_TAX, true);
        assert!(!again.changed && unchanged.is_none());

        let (_, cleared) = set_enabled(&changed, ordinance_ids::ID_SALES_TAX, false);
        assert_eq!(cleared.expect("a cleared flag"), misc);
        assert_eq!(
            set_enabled(&misc, ordinance_ids::COUNT, true).0.error,
            "ordinance is outside the valid range"
        );
    }

    #[test]
    fn a_snapshot_groups_costs_by_category_and_estimates_the_year() {
        // income tax (finance) and volunteer fire department (safety)
        let flags = (1 << ordinance_ids::ID_INCOME_TAX) | (1 << ordinance_ids::ID_VOLUNTEER_FIRE);
        let mut misc = misc_with(3000, 1200, flags);
        write_u32_be(
            &mut misc,
            misc_layout::CITY_DAYS,
            calendar::DAYS_PER_YEAR + 2 * calendar::DAYS_PER_MONTH,
        );
        write_u32_be(&mut misc, budget_offset(budget::ORDINANCES) + budget::YEAR_TO_DATE, 9000);

        let result = snapshot(&misc);
        assert!(result.ok);
        assert_eq!(result.current_raw, 3000 - 1000);
        assert_eq!(result.item_amounts.0[1], 40);
        assert_eq!(result.item_amounts.0[4], -13);
        assert_eq!(result.category_amounts.0, vec![40, -13, 0, 0, 0]);
        assert_eq!(result.month, 2);
        assert_eq!(result.year_to_date_amount, 10);
        assert_eq!(result.estimated_amount, (9 * 2000 + 9000) / 900);

        write_u32_be(&mut misc, misc_layout::YEAR_END, 1);
        assert_eq!(snapshot(&misc).estimated_amount, 2000 * 12 / 900);
    }

    #[test]
    fn synchronizing_stores_only_a_changed_total() {
        let misc = misc_with(3000, 1200, 1 << ordinance_ids::ID_INCOME_TAX);
        let (result, changed) = synchronize_current(&misc);
        assert!(result.changed);
        let changed = changed.expect("a new total");
        let (again, unchanged) = synchronize_current(&changed);
        assert!(again.ok && !again.changed && unchanged.is_none());
    }
}
