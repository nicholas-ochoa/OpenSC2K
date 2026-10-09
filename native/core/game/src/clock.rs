//! The city calendar and the scheduled work of each day, as SimulationClock
//! and SimulationSchedule. Every month has 25 days.

use sc2k_sim::sim::engine::day::Schedule;
use sc2k_sim::sim::value::{Strings, ToValue, Value};

pub const DAYS_PER_MONTH: i64 = 25;
pub const MONTHS_PER_YEAR: i64 = 12;
pub const DAYS_PER_YEAR: i64 = DAYS_PER_MONTH * MONTHS_PER_YEAR;

/// The days of a month that run the growth steps.
const FIRST_GROWTH_DAY: i64 = 3;
const LAST_GROWTH_DAY: i64 = 18;

/// The work of one day.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DaySchedule {
    pub city_days: i64,
    pub elapsed_years: i64,
    pub month: i64,
    pub month_day: i64,
    pub season: i64,
    pub actions: Vec<String>,
    pub growth_step: i64,
    pub growth_substep: i64,
}

impl Default for DaySchedule {
    fn default() -> Self {
        Self {
            city_days: 0,
            elapsed_years: 0,
            month: 0,
            month_day: 0,
            season: 0,
            actions: Vec::new(),
            growth_step: -1,
            growth_substep: -1,
        }
    }
}

impl DaySchedule {
    /// The schedule of the day at city age `days`.
    pub fn for_day(days: i64) -> Self {
        let days = days.max(0);
        let month_day = days % DAYS_PER_MONTH;
        let month = (days / DAYS_PER_MONTH) % MONTHS_PER_YEAR;
        let mut schedule = DaySchedule {
            city_days: days,
            elapsed_years: days / DAYS_PER_YEAR,
            month,
            month_day,
            season: ((month + 1) % MONTHS_PER_YEAR) / 3,
            ..DaySchedule::default()
        };

        let actions: &[&str] = match month_day {
            0 => &["budget", "month_start"],
            1 => &["power"],
            2 => &["pollution_terrain_land_value"],
            19 => &["traffic"],
            20 => &["water"],
            21 => &["rci_demand", "education_health", "graphs"],
            22 => &["milestones", "scenario", "bankruptcy"],
            23 => &["statistics_windows"],
            24 => &["map", "simnation", "weather_disaster"],
            FIRST_GROWTH_DAY..=LAST_GROWTH_DAY => {
                schedule.growth_step = ((month_day - FIRST_GROWTH_DAY) / 4) % 4;
                schedule.growth_substep = (month_day + 1) % 4;
                &["growth"]
            }
            _ => &[],
        };

        schedule.actions = actions.iter().map(|action| action.to_string()).collect();

        schedule
    }

    /// The same day with only the actions after `completed`.
    pub fn after(&self, completed: &str) -> Self {
        let actions = match self.actions.iter().position(|action| action == completed) {
            Some(position) => self.actions[position + 1..].to_vec(),
            None => Vec::new(),
        };

        DaySchedule { actions, ..self.clone() }
    }

    /// The schedule that the day phases read.
    pub fn to_sim(&self) -> Schedule {
        Schedule {
            city_days: self.city_days,
            month_day: self.month_day,
            season: self.season,
            actions: self.actions.clone(),
            growth_step: self.growth_step,
            growth_substep: self.growth_substep,
        }
    }
}

impl ToValue for DaySchedule {
    fn to_value(&self) -> Value {
        Value::Object(
            "SimulationSchedule",
            vec![
                ("city_days", Value::Int(self.city_days)),
                ("elapsed_years", Value::Int(self.elapsed_years)),
                ("month", Value::Int(self.month)),
                ("month_day", Value::Int(self.month_day)),
                ("season", Value::Int(self.season)),
                ("actions", Strings(self.actions.clone()).to_value()),
                ("growth_step", Value::Int(self.growth_step)),
                ("growth_substep", Value::Int(self.growth_substep)),
            ],
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn each_day_of_the_month_has_its_work() {
        assert_eq!(DaySchedule::for_day(0).actions, ["budget", "month_start"]);
        assert_eq!(DaySchedule::for_day(24).actions, ["map", "simnation", "weather_disaster"]);

        let growth = DaySchedule::for_day(DAYS_PER_YEAR + 7);
        assert_eq!(growth.actions, ["growth"]);
        assert_eq!((growth.growth_step, growth.growth_substep), (1, 0));
        assert_eq!(growth.elapsed_years, 1);
        assert_eq!(DaySchedule::for_day(26).season, 0);
        assert_eq!(DaySchedule::for_day(2 * DAYS_PER_MONTH).season, 1);
    }

    #[test]
    fn the_rest_of_a_day_follows_the_completed_action() {
        let day = DaySchedule::for_day(22);
        assert_eq!(day.after("milestones").actions, ["scenario", "bankruptcy"]);
        assert!(day.after("unknown").actions.is_empty());
    }
}
