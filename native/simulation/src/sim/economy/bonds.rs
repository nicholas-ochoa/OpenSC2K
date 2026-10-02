//! Bond issue and repayment from the budget window, as BondCommand.
//!
//! Each command reads a copy of MISC and returns the changed copy, if any. The
//! issue command also stores the rebuilt city value when it issues no bond.

use super::{divide_toward_zero, to_i32};
use crate::gd_object;
use crate::sim::bytes::{read_i32_be, read_u32_be, write_u32_be};
use crate::sim::ids::sc2budget_layout as budget;
use crate::sim::ids::sc2misc_layout as misc_layout;

pub const BOND_VALUE: i64 = 10000;
pub const MAX_BONDS: i64 = 50;
/// The credit value at which the bank refuses another bond.
pub const CREDIT_LIMIT: i64 = 6;
const CREDIT_SCALE: i64 = 2500;
const RATE_SCALE: i64 = 10000;
const RATE_SIZE: i64 = 4;

pub const CONFIRMATION_UNSELECTED: i64 = -1;
pub const CONFIRMATION_CANCELLED: i64 = 0;
pub const CONFIRMATION_CONFIRMED: i64 = 1;

gd_object! {
    pub struct BondResult as "BondCommand.Result" {
        pub ok: bool = false,
        pub error: String = String::new(),
        pub status: String = String::new(),
        pub confirmation_required: bool = false,
        pub changed: bool = false,
        pub bond_count: i64 = 0,
        pub funds: i64 = 0,
        pub city_value: i64 = 0,
        pub credit_value: i64 = 0,
        pub rate: i64 = 0,
    }
}

/// A command result and the MISC copy to store, if any.
pub struct BondOutcome {
    pub result: BondResult,
    pub misc: Option<Vec<u8>>,
}

impl BondOutcome {
    fn failed(message: &str) -> Self {
        Self {
            result: BondResult {
                error: message.to_string(),
                ..Default::default()
            },
            misc: None,
        }
    }
}

struct Status {
    name: &'static str,
    confirmation_required: bool,
    changed: bool,
}

const fn status(name: &'static str, confirmation_required: bool, changed: bool) -> Status {
    Status {
        name,
        confirmation_required,
        changed,
    }
}

fn result(status: Status, bond_count: i64, funds: i64, city_value: i64, credit_value: i64, rate: i64) -> BondResult {
    BondResult {
        ok: true,
        error: String::new(),
        status: status.name.to_string(),
        confirmation_required: status.confirmation_required,
        changed: status.changed,
        bond_count,
        funds,
        city_value,
        credit_value,
        rate,
    }
}

fn to_i16(value: i64) -> i64 {
    value as i16 as i64
}

/// A bond rate holds a 16-bit value in the low half of its 32-bit field.
fn read_u16_low(misc: &[u8], offset: i64) -> i64 {
    read_u32_be(misc, offset) & 0xffff
}

fn rate_offset(index: i64) -> i64 {
    misc_layout::BOND_RATES + index * RATE_SIZE
}

fn bond_budget_offset() -> i64 {
    misc_layout::BUDGETS + budget::BONDS * budget::RECORD_SIZE
}

fn interest_sum(misc: &[u8], bond_count: i64) -> i64 {
    (0..bond_count).fold(0, |sum, index| to_i32(sum + read_u16_low(misc, rate_offset(index))))
}

fn valid_confirmation(confirmation: i64) -> bool {
    (CONFIRMATION_UNSELECTED..=CONFIRMATION_CONFIRMED).contains(&confirmation)
}

fn checked_misc(misc: &[u8], confirmation: i64) -> Result<i64, BondOutcome> {
    if !valid_confirmation(confirmation) {
        return Err(BondOutcome::failed("confirmation choice is invalid"));
    }

    if misc.len() as i64 != misc_layout::SIZE {
        return Err(BondOutcome::failed("MISC is missing or has the wrong size"));
    }

    let bond_count = read_u32_be(misc, misc_layout::BONDS);

    if bond_count > MAX_BONDS {
        return Err(BondOutcome::failed("saved bond count exceeds fifty"));
    }

    Ok(bond_count)
}

/// Store the bond count and the average rate in the bond budget record.
fn write_bond_budget(misc: &mut [u8], bond_count: i64, interest: i64) {
    let average = if bond_count > 0 {
        divide_toward_zero(to_i32(interest * RATE_SCALE), bond_count)
    } else {
        0
    };

    write_u32_be(misc, misc_layout::BONDS, bond_count);
    write_u32_be(misc, bond_budget_offset() + budget::CURRENT, bond_count);
    write_u32_be(misc, bond_budget_offset() + budget::FUNDING, average);
}

/// BondCommand.issue. `city_value` is the value that CityValuePhase.calculate
/// rebuilt; the budget handler rebuilds it before every issue attempt.
pub fn issue(misc: &[u8], city_value: i64, confirmation: i64) -> BondOutcome {
    let bond_count = match checked_misc(misc, confirmation) {
        Ok(count) => count,
        Err(outcome) => return outcome,
    };

    let mut changed = misc.to_vec();
    write_u32_be(&mut changed, misc_layout::CITY_VALUE, city_value);
    let denominator = (city_value + 1) & 0xffff_ffff;

    if denominator == 0 {
        return BondOutcome::failed("city value makes the credit calculation invalid");
    }

    let numerator = (bond_count * CREDIT_SCALE) & 0xffff_ffff;
    let credit_value = to_i16(numerator / denominator);
    let funds = read_i32_be(&changed, misc_layout::FUNDS);
    let rate = to_i16(read_u16_low(&changed, misc_layout::NATIONAL_FEDERAL_RATE) + 1);

    let refused = if credit_value >= CREDIT_LIMIT {
        Some(result(
            status("credit_denied", false, false),
            bond_count,
            funds,
            city_value,
            credit_value,
            0,
        ))
    } else if bond_count == MAX_BONDS {
        Some(result(
            status("maximum_bonds", false, false),
            bond_count,
            funds,
            city_value,
            credit_value,
            0,
        ))
    } else if confirmation == CONFIRMATION_UNSELECTED {
        let required = status("confirmation_required", true, false);
        Some(result(required, bond_count, funds, city_value, credit_value, rate))
    } else if confirmation == CONFIRMATION_CANCELLED {
        Some(result(
            status("cancelled", false, false),
            bond_count,
            funds,
            city_value,
            credit_value,
            rate,
        ))
    } else {
        None
    };

    if let Some(result) = refused {
        return BondOutcome {
            result,
            misc: Some(changed),
        };
    }

    let interest = to_i32(interest_sum(&changed, bond_count) + rate);

    // the original keeps only the low 16 bits of each saved rate
    for index in 0..MAX_BONDS {
        let offset = rate_offset(index);
        let value = read_u16_low(&changed, offset);
        write_u32_be(&mut changed, offset, value);
    }

    write_u32_be(&mut changed, rate_offset(bond_count), rate & 0xffff);
    let bond_count = bond_count + 1;
    let funds = to_i32(funds + BOND_VALUE);
    write_u32_be(&mut changed, misc_layout::FUNDS, funds);
    write_bond_budget(&mut changed, bond_count, interest);

    BondOutcome {
        result: result(status("issued", false, true), bond_count, funds, city_value, credit_value, rate),
        misc: Some(changed),
    }
}

/// BondCommand.repay: repay the oldest bond.
pub fn repay(misc: &[u8], confirmation: i64) -> BondOutcome {
    let bond_count = match checked_misc(misc, confirmation) {
        Ok(count) => count,
        Err(outcome) => return outcome,
    };

    let funds = read_i32_be(misc, misc_layout::FUNDS);

    if bond_count == 0 {
        return refused(status("no_bonds", false, false), bond_count, funds, 0);
    }

    if funds < BOND_VALUE {
        return refused(status("insufficient_funds", false, false), bond_count, funds, 0);
    }

    let oldest_rate = to_i16(read_u16_low(misc, rate_offset(0)));

    if confirmation == CONFIRMATION_UNSELECTED {
        return refused(status("confirmation_required", true, false), bond_count, funds, oldest_rate);
    }

    if confirmation == CONFIRMATION_CANCELLED {
        return refused(status("cancelled", false, false), bond_count, funds, oldest_rate);
    }

    let mut rates: Vec<i64> = (0..MAX_BONDS).map(|index| read_u16_low(misc, rate_offset(index))).collect();
    let interest = to_i32(interest_sum(misc, bond_count) - oldest_rate);
    let bond_count = bond_count - 1;
    rates.copy_within(1..=bond_count as usize, 0);

    let mut changed = misc.to_vec();

    for (index, rate) in rates.iter().enumerate() {
        write_u32_be(&mut changed, rate_offset(index as i64), *rate);
    }

    let funds = to_i32(funds - BOND_VALUE);
    write_u32_be(&mut changed, misc_layout::FUNDS, funds);
    write_bond_budget(&mut changed, bond_count, interest);

    BondOutcome {
        result: result(status("repaid", false, true), bond_count, funds, 0, 0, oldest_rate),
        misc: Some(changed),
    }
}

fn refused(status: Status, bond_count: i64, funds: i64, rate: i64) -> BondOutcome {
    BondOutcome {
        result: result(status, bond_count, funds, 0, 0, rate),
        misc: None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn misc_with(bonds: &[i64], funds: i64, federal_rate: i64) -> Vec<u8> {
        let mut misc = vec![0u8; misc_layout::SIZE as usize];
        write_u32_be(&mut misc, misc_layout::FUNDS, funds);
        write_u32_be(&mut misc, misc_layout::BONDS, bonds.len() as i64);
        write_u32_be(&mut misc, misc_layout::NATIONAL_FEDERAL_RATE, federal_rate);

        for (index, rate) in bonds.iter().enumerate() {
            write_u32_be(&mut misc, rate_offset(index as i64), *rate);
        }

        misc
    }

    #[test]
    fn an_issue_asks_for_confirmation_then_adds_a_bond_at_the_federal_rate_plus_one() {
        let misc = misc_with(&[4], 500, 5);
        let asked = issue(&misc, 100_000, CONFIRMATION_UNSELECTED);
        assert_eq!(asked.result.status, "confirmation_required");
        assert_eq!((asked.result.rate, asked.result.changed), (6, false));
        let stored = asked.misc.expect("the city value is stored");
        assert_eq!(read_u32_be(&stored, misc_layout::CITY_VALUE), 100_000);

        let issued = issue(&misc, 100_000, CONFIRMATION_CONFIRMED);
        let changed = issued.misc.expect("an issued bond");
        assert_eq!(issued.result.status, "issued");
        assert_eq!((issued.result.bond_count, issued.result.funds), (2, 10_500));
        assert_eq!(read_u32_be(&changed, rate_offset(1)), 6);
        assert_eq!(read_u32_be(&changed, bond_budget_offset() + budget::CURRENT), 2);
        assert_eq!(read_u32_be(&changed, bond_budget_offset() + budget::FUNDING), 50_000);
    }

    #[test]
    fn the_bank_refuses_a_bond_past_the_credit_limit_or_the_bond_cap() {
        let misc = misc_with(&[1; 10], 0, 1);
        let denied = issue(&misc, 1000, CONFIRMATION_CONFIRMED);
        assert_eq!((denied.result.status.as_str(), denied.result.credit_value), ("credit_denied", 24));

        let full = misc_with(&[1; MAX_BONDS as usize], 0, 1);
        assert_eq!(issue(&full, 100_000_000, CONFIRMATION_CONFIRMED).result.status, "maximum_bonds");

        let mut corrupt = misc_with(&[], 0, 1);
        write_u32_be(&mut corrupt, misc_layout::BONDS, MAX_BONDS + 1);
        assert_eq!(
            issue(&corrupt, 0, CONFIRMATION_CONFIRMED).result.error,
            "saved bond count exceeds fifty"
        );
        assert_eq!(issue(&misc, 0, 2).result.error, "confirmation choice is invalid");
        assert_eq!(
            issue(&[0; 4], 0, CONFIRMATION_CONFIRMED).result.error,
            "MISC is missing or has the wrong size"
        );
    }

    #[test]
    fn a_repayment_removes_the_oldest_bond() {
        let misc = misc_with(&[3, 7, 9], 25_000, 1);
        let asked = repay(&misc, CONFIRMATION_UNSELECTED);
        assert_eq!((asked.result.status.as_str(), asked.result.rate), ("confirmation_required", 3));
        assert!(asked.misc.is_none());

        let repaid = repay(&misc, CONFIRMATION_CONFIRMED);
        let changed = repaid.misc.expect("a repaid bond");
        assert_eq!((repaid.result.bond_count, repaid.result.funds), (2, 15_000));
        assert_eq!(
            (read_u32_be(&changed, rate_offset(0)), read_u32_be(&changed, rate_offset(1))),
            (7, 9)
        );
        assert_eq!(read_u32_be(&changed, bond_budget_offset() + budget::FUNDING), 80_000);

        assert_eq!(repay(&misc_with(&[], 25_000, 1), CONFIRMATION_CONFIRMED).result.status, "no_bonds");
        assert_eq!(
            repay(&misc_with(&[3], 9_999, 1), CONFIRMATION_CONFIRMED).result.status,
            "insufficient_funds"
        );
    }
}
