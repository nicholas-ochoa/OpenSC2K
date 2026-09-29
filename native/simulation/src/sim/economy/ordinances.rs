//! Ordinance costs, as OrdinanceCommand.costs_for_misc and current_cost_for_misc.

use super::{divide_toward_zero as div, to_i32};
use crate::sim::bytes::{read_i32_be, read_u32_be};
use crate::sim::ids::ordinance_ids;
use crate::sim::ids::sc2budget_layout as budget;
use crate::sim::ids::sc2misc_layout as misc_layout;

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
    let population =
        to_i32(read_u32_be(misc, misc_layout::ARCOLOGY_POPULATION) + read_u32_be(misc, misc_layout::NORMAL_POPULATION));

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
