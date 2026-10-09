//! Scenario goals and time limits, as ScenarioState and ScenarioPhase.

use crate::gd_phase_result;
use crate::sim::bytes::{read_i32_be, read_u16_be, read_u32_be, write_u16_be};
use crate::sim::city::City;
use crate::sim::events::GameOverEvent;
use crate::sim::ids::building_tile_ids as tiles;
use crate::sim::ids::sc2budget_layout;
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::phase::PhaseResultLike;
use crate::sim::value::Strings;

const LEGACY_SIZE: usize = 52;
const EXTENDED_SIZE: usize = 56;
const SCHEMA2_SIZE: usize = crate::formats::sc2x::scenario::SCHEMA2_SIZE;
const SCHEMA2_TIME_LIMIT: i64 = 0x0a;

/// The unmet goal names, and the value of each goal by name.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Goals {
    pub unmet: Vec<String>,
    pub values: Vec<(String, i64)>,
}

/// The SCEN fields, as ScenarioState.from_document reads them.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Scenario {
    pub format_size: usize,
    pub disaster_type: i64,
    pub disaster_x: i64,
    pub disaster_y: i64,
    pub time_limit_months: i64,
    pub city_size_goal: i64,
    pub residential_goal: i64,
    pub commercial_goal: i64,
    pub industrial_goal: i64,
    pub cash_goal: i64,
    pub land_value_goal: i64,
    pub life_expectancy_goal: i64,
    pub education_goal: i64,
    pub pollution_limit: i64,
    pub crime_limit: i64,
    pub traffic_limit: i64,
    pub first_building_id: i64,
    pub second_building_id: i64,
    pub first_building_tile_count: i64,
    pub second_building_tile_count: i64,
}

impl Scenario {
    /// The scenario of the city, or an error for a missing or invalid SCEN chunk.
    pub fn from_city(city: &City) -> Result<Scenario, String> {
        let Some(chunk) = city.chunk("SCEN") else {
            return Err("SCEN chunk is missing".to_string());
        };
        let data = &chunk.data;

        if data.len() == SCHEMA2_SIZE {
            return Self::from_schema2(data);
        }

        if data.len() != LEGACY_SIZE && data.len() != EXTENDED_SIZE {
            return Err(format!("SCEN has {} bytes; expected 52, 56, or 64", data.len()));
        }

        if read_u32_be(data, 0) != 0x8000_0000 {
            return Err("SCEN header is not 0x80000000".to_string());
        }

        let mut scenario = Scenario {
            format_size: data.len(),
            disaster_type: read_u16_be(data, 0x04),
            disaster_x: data[0x06] as i64,
            disaster_y: data[0x07] as i64,
            time_limit_months: read_u16_be(data, 0x08),
            city_size_goal: read_u32_be(data, 0x0a),
            residential_goal: read_i32_be(data, 0x0e),
            commercial_goal: read_i32_be(data, 0x12),
            industrial_goal: read_i32_be(data, 0x16),
            cash_goal: read_i32_be(data, 0x1a),
            land_value_goal: read_i32_be(data, 0x1e),
            ..Default::default()
        };
        let mut limit_offset = 0x22;

        if data.len() == EXTENDED_SIZE {
            scenario.life_expectancy_goal = read_u16_be(data, 0x22);
            scenario.education_goal = read_u16_be(data, 0x24);
            limit_offset = 0x26;
        }

        scenario.pollution_limit = read_u32_be(data, limit_offset);
        scenario.crime_limit = read_u32_be(data, limit_offset + 4);
        scenario.traffic_limit = read_u32_be(data, limit_offset + 8);
        scenario.first_building_id = data[(limit_offset + 12) as usize] as i64;
        scenario.second_building_id = data[(limit_offset + 13) as usize] as i64;
        scenario.first_building_tile_count = read_u16_be(data, limit_offset + 14);
        scenario.second_building_tile_count = read_u16_be(data, limit_offset + 16);

        Ok(scenario)
    }

    /// SCEN schema 2 of an SC2X version 4 city. See formats::sc2x::scenario.
    fn from_schema2(data: &[u8]) -> Result<Scenario, String> {
        let parsed = crate::formats::sc2x::scenario::Scenario::from_schema2(data, usize::MAX)?;

        Ok(Scenario {
            format_size: data.len(),
            disaster_type: parsed.disaster_type as i64,
            disaster_x: parsed.disaster_x as i64,
            disaster_y: parsed.disaster_y as i64,
            time_limit_months: parsed.time_limit_months as i64,
            city_size_goal: parsed.city_size_goal as i64,
            residential_goal: parsed.residential_goal as i64,
            commercial_goal: parsed.commercial_goal as i64,
            industrial_goal: parsed.industrial_goal as i64,
            cash_goal: parsed.cash_goal as i64,
            land_value_goal: parsed.land_value_goal as i64,
            life_expectancy_goal: parsed.life_expectancy_goal as i64,
            education_goal: parsed.education_goal as i64,
            pollution_limit: parsed.pollution_limit as i64,
            crime_limit: parsed.crime_limit as i64,
            traffic_limit: parsed.traffic_limit as i64,
            first_building_id: parsed.first_building_id as i64,
            second_building_id: parsed.second_building_id as i64,
            first_building_tile_count: parsed.first_building_tile_count as i64,
            second_building_tile_count: parsed.second_building_tile_count as i64,
        })
    }

    /// ScenarioState.evaluate_goals: the unmet goal names.
    pub fn unmet_goals(&self, city: &City) -> Vec<String> {
        self.goals(city).unmet
    }

    /// The unmet goal names and the value of each goal.
    pub fn goals(&self, city: &City) -> Goals {
        let mut unmet = Vec::new();
        let budget = |id: i64| city.misc_i32(misc_layout::BUDGETS + id * sc2budget_layout::RECORD_SIZE);
        let city_size = city.misc_u32(misc_layout::NORMAL_POPULATION);
        let residential = city.misc_i32(misc_layout::BUDGETS);
        let commercial = budget(sc2budget_layout::COMMERCIAL);
        let industrial = budget(sc2budget_layout::INDUSTRIAL);
        let mut cash_after_bonds = city.funds() - city.misc_i32(misc_layout::BONDS);
        let mut land_value = city.misc_i32(misc_layout::CITY_LAND_VALUE);
        let mut life_expectancy = city.misc_i32(misc_layout::WORKFORCE_LIFE_EXPECTANCY);
        let mut education = city.misc_i32(misc_layout::WORKFORCE_EDUCATION);
        let pollution = city.misc_u32(misc_layout::CITY_POLLUTION);
        let crime = city.misc_u32(misc_layout::CITY_CRIME);
        let traffic = city.misc_u32(misc_layout::CITY_TRAFFIC);
        let original_format = !city.is_extended();
        let mut required_land_value = self.land_value_goal;
        let mut required_life_expectancy = self.life_expectancy_goal;
        let mut required_education = self.education_goal;

        if original_format {
            cash_after_bonds = signed_32(cash_after_bonds);
            land_value &= 0xffff_ffff;
            life_expectancy &= 0xffff_ffff;
            education &= 0xffff_ffff;
            required_land_value &= 0xffff_ffff;
            required_life_expectancy = signed_16(required_life_expectancy) & 0xffff_ffff;
            required_education = signed_16(required_education) & 0xffff_ffff;
        }

        let mut values = vec![
            ("city_size", city_size),
            ("residential", residential),
            ("commercial", commercial),
            ("industrial", industrial),
            ("cash_after_bonds", cash_after_bonds),
            ("land_value", land_value),
            ("life_expectancy", life_expectancy),
            ("education", education),
            ("pollution", pollution),
            ("crime", crime),
            ("traffic", traffic),
        ];

        let mut minimum = |name: &str, actual: i64, required: i64, zero_disables: bool| {
            if (!zero_disables || required != 0) && actual < required {
                unmet.push(name.to_string());
            }
        };
        minimum("city_size", city_size, self.city_size_goal, true);
        minimum("residential", residential, self.residential_goal, false);
        minimum("commercial", commercial, self.commercial_goal, false);
        minimum("industrial", industrial, self.industrial_goal, false);
        minimum("cash", cash_after_bonds, self.cash_goal, false);
        minimum("land_value", land_value, required_land_value, false);
        minimum("life_expectancy", life_expectancy, required_life_expectancy, false);
        minimum("education", education, required_education, false);
        let limit_of = |limit: i64| {
            if original_format { signed_32(limit) } else { limit }
        };

        for (name, actual, limit) in [
            ("pollution", pollution, limit_of(self.pollution_limit)),
            ("crime", crime, limit_of(self.crime_limit)),
            ("traffic", traffic, limit_of(self.traffic_limit)),
        ] {
            if limit > 0 && actual > limit {
                unmet.push(name.to_string());
            }
        }

        for (name, value_name, building, required) in [
            (
                "first_building",
                "first_building_tiles",
                self.first_building_id,
                self.first_building_tile_count,
            ),
            (
                "second_building",
                "second_building_tiles",
                self.second_building_id,
                self.second_building_tile_count,
            ),
        ] {
            if building == tiles::EMPTY {
                continue;
            }

            let count = city.misc_u32(misc_layout::TILE_COUNTS + building * 4);
            values.push((value_name, count));
            let short = if original_format {
                signed_16(count) < signed_16(required)
            } else {
                count < required
            };

            if short {
                unmet.push(name.to_string());
            }
        }

        Goals {
            unmet,
            values: values.into_iter().map(|(name, value)| (name.to_string(), value)).collect(),
        }
    }

    /// ScenarioState.set_time_limit_months.
    pub fn set_time_limit_months(&mut self, city: &mut City, value: i64) -> bool {
        if !(0..=0xffff).contains(&value) {
            return false;
        }

        let Some(chunk) = city.chunk_mut("SCEN") else {
            return false;
        };

        if chunk.data.len() != self.format_size {
            return false;
        }

        let offset = if self.format_size == SCHEMA2_SIZE {
            SCHEMA2_TIME_LIMIT
        } else {
            0x08
        };
        write_u16_be(chunk.mutate(), offset, value);
        self.time_limit_months = value;
        true
    }
}

fn signed_16(value: i64) -> i64 {
    let word = value & 0xffff;

    if word & 0x8000 != 0 { word - 0x10000 } else { word }
}

fn signed_32(value: i64) -> i64 {
    value as i32 as i64
}

gd_phase_result! {
    pub struct ScenarioResult as "ScenarioPhase.Result" {
        pub active: bool = false,
        pub outcome: String = String::new(),
        pub remaining_months: i64 = 0,
        pub unmet: Strings = Strings::default(),
    }
}

/// ScenarioPhase.run. `None` is an inactive scenario, as after the scenario ended.
/// The engine keeps the scenario, and a caller can change its goals.
pub fn run(city: &mut City, scenario: Option<&mut Scenario>) -> ScenarioResult {
    let mut result = ScenarioResult::default();

    let Some(scenario) = scenario else {
        result.base_mut().ok = true;
        return result;
    };

    let unmet = scenario.unmet_goals(city);

    if unmet.is_empty() {
        result.base.ok = true;
        result.active = true;
        result.outcome = "victory".to_string();
        result.remaining_months = scenario.time_limit_months;
        result.base.game_over_events = vec![GameOverEvent::new("scenario_victory", 0)];

        return result;
    }

    let remaining = (scenario.time_limit_months - 1) & 0xffff;

    if !scenario.set_time_limit_months(city, remaining) {
        return ScenarioResult::failed("cannot store the scenario time limit");
    }

    let failure = remaining == 0;
    result.base.ok = true;
    result.active = true;
    result.outcome = if failure { "failure".to_string() } else { String::new() };
    result.remaining_months = remaining;
    result.unmet = Strings(unmet);

    if failure {
        result.base.game_over_events.push(GameOverEvent::new("scenario_failure", 0));
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::formats::sc2x::scenario::Scenario as Schema2;
    use crate::sim::city::Chunk;
    use crate::sim::testing::empty_sc2x_city;

    #[test]
    fn schema_2_scenarios_read_wide_fields_and_count_down_their_time_limit() {
        let mut city = empty_sc2x_city(256);
        let saved = Schema2 {
            disaster_type: 4,
            disaster_x: 200,
            disaster_y: 255,
            time_limit_months: 12,
            first_building_id: 0xd2,
            first_building_tile_count: 70000,
            ..Default::default()
        };
        city.scen = Chunk::new(saved.to_schema2());
        let mut scenario = Scenario::from_city(&city).unwrap();
        assert_eq!((scenario.disaster_x, scenario.disaster_y), (200, 255));
        assert_eq!(scenario.first_building_tile_count, 70000);
        assert!(scenario.set_time_limit_months(&mut city, 11));
        assert_eq!(Schema2::from_schema2(&city.scen.data, 256).unwrap().time_limit_months, 11);
    }
}
