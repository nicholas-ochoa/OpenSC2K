//! Budget, bankruptcy, ordinance costs, and city value.

pub mod budget;
pub mod city_value;
pub mod ordinances;

use crate::gd_phase_result;
use crate::sim::city::City;
use crate::sim::events::GameOverEvent;
use crate::sim::phase::PhaseResultLike;

/// Truncate to a signed 32-bit value.
#[inline]
pub fn to_i32(value: i64) -> i64 {
    value as i32 as i64
}

/// Division toward zero. A zero divisor gives zero.
#[inline]
pub fn divide_toward_zero(value: i64, divisor: i64) -> i64 {
    if divisor == 0 { 0 } else { value / divisor }
}

gd_phase_result! {
    pub struct BankruptcyResult as "BankruptcyPhase.Result" {
        pub bankrupt: bool = false,
        pub funds: i64 = 0,
    }
}

pub const BANKRUPTCY_LIMIT: i64 = -100000;

/// BankruptcyPhase.run.
pub fn bankruptcy(city: &City) -> BankruptcyResult {
    let funds = city.funds();
    let bankrupt = funds < BANKRUPTCY_LIMIT;
    let mut result = BankruptcyResult { bankrupt, funds, ..Default::default() };
    result.base_mut().ok = true;

    if bankrupt {
        result.base_mut().game_over_events.push(GameOverEvent::new("bankruptcy", funds));
    }

    result
}
