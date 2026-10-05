//! Godot entry points. Each call receives the saved city chunks and the engine
//! state, runs one simulation operation, and returns the written chunks and
//! the result as Godot values. GDScript builds the result objects.

mod budgets;
mod city_cache;
mod codec;
mod convert;
mod document;
mod game;
mod json_value;
mod newspaper;
mod ops;
mod platform;
mod reports;
mod sc2x;
mod tool_ops;
mod tool_queries;

use godot::prelude::*;

/// Static entry points for GDScript. No instance holds simulation state.
#[derive(GodotClass)]
#[class(no_init, base = Object)]
pub struct NativeSimulation {}

#[godot_api]
impl NativeSimulation {
    /// Run the operation that `request.op` names. See `ops.rs` for the fields.
    #[func]
    fn run(request: VarDictionary) -> VarDictionary {
        ops::run(&request)
    }

    /// A new slice budget. Free it with `budget_free`.
    #[func]
    fn budget_create() -> i64 {
        budgets::create()
    }

    #[func]
    fn budget_free(handle: i64) {
        budgets::free(handle)
    }

    #[func]
    fn budget_checkpoint(handle: i64) {
        if let Some(budget) = budgets::get(handle) {
            budget.checkpoint();
        }
    }

    #[func]
    fn budget_grant(handle: i64, usec: i64) {
        if let Some(budget) = budgets::get(handle) {
            budget.grant(usec);
        }
    }

    #[func]
    fn budget_cancel(handle: i64) {
        if let Some(budget) = budgets::get(handle) {
            budget.cancel();
        }
    }

    #[func]
    fn budget_finish(handle: i64) {
        if let Some(budget) = budgets::get(handle) {
            budget.finish();
        }
    }

    #[func]
    fn budget_parked_usec(handle: i64) -> i64 {
        budgets::get(handle).map_or(0, |budget| budget.parked_usec())
    }

    /// `{slices, max_slice_usec, waiting, cancelled, elapsed_usec, parked_usec}`.
    #[func]
    fn budget_metrics(handle: i64) -> VarDictionary {
        let metrics = budgets::get(handle).map(|budget| budget.metrics()).unwrap_or_default();
        let mut result = VarDictionary::new();
        result.set("slices", metrics.slices);
        result.set("max_slice_usec", metrics.max_slice_usec);
        result.set("waiting", metrics.waiting);
        result.set("cancelled", metrics.cancelled);
        result.set("elapsed_usec", metrics.elapsed_usec);
        result.set("parked_usec", metrics.parked_usec);
        result
    }

    /// A new native city cache. Free it with `cache_free`.
    #[func]
    fn cache_create() -> i64 {
        city_cache::create()
    }

    #[func]
    fn cache_free(handle: i64) {
        city_cache::free(handle)
    }

    /// A chunk revision that no other chunk content has. See `city_cache.rs`.
    #[func]
    fn next_revision() -> i64 {
        city_cache::next_revision()
    }

    /// `{ok, error, fields}`: the SCEN fields of a scenario. See `sim/civic/scenario.rs`.
    #[func]
    fn scenario_read(scen: PackedByteArray) -> VarDictionary {
        scenario_value(&scen).0
    }

    /// `{unmet, values}`: the goals of `scenario` (the fields of `scenario_read`)
    /// for a city with `misc`.
    #[func]
    fn scenario_goals(scenario: VarDictionary, misc: PackedByteArray, map_size: i64, large_version: i64) -> VarDictionary {
        let field = |name: &str| convert::int(&scenario, name, 0);
        let scenario = sc2k_sim::sim::civic::scenario::Scenario {
            format_size: field("format_size") as usize,
            disaster_type: field("disaster_type"),
            disaster_x: field("disaster_x"),
            disaster_y: field("disaster_y"),
            time_limit_months: field("time_limit_months"),
            city_size_goal: field("city_size_goal"),
            residential_goal: field("residential_goal"),
            commercial_goal: field("commercial_goal"),
            industrial_goal: field("industrial_goal"),
            cash_goal: field("cash_goal"),
            land_value_goal: field("land_value_goal"),
            life_expectancy_goal: field("life_expectancy_goal"),
            education_goal: field("education_goal"),
            pollution_limit: field("pollution_limit"),
            crime_limit: field("crime_limit"),
            traffic_limit: field("traffic_limit"),
            first_building_id: field("first_building_id"),
            second_building_id: field("second_building_id"),
            first_building_tile_count: field("first_building_tile_count"),
            second_building_tile_count: field("second_building_tile_count"),
        };

        let mut city = sc2k_sim::sim::city::City::new(map_size, large_version);
        city.misc = sc2k_sim::sim::city::Chunk::new(misc.to_vec());
        let goals = scenario.goals(&city);
        let mut values = VarDictionary::new();

        for (name, value) in &goals.values {
            values.set(name.as_str(), *value);
        }

        let mut result = VarDictionary::new();
        result.set("unmet", &goals.unmet.iter().map(GString::from).collect::<PackedStringArray>());
        result.set("values", &values);
        result
    }

    /// The saved random states and phase state of an SC2X save. See sc2k_game::checkpoint.
    #[func]
    fn checkpoint_capture(
        engine: VarDictionary,
        controller: VarDictionary,
        randoms: PackedInt64Array,
        phase_state: VarDictionary,
    ) -> VarDictionary {
        game::checkpoint_capture(&engine, &controller, &randoms, &phase_state)
    }

    /// The engine and controller state after a load restores its saved phase state.
    #[func]
    fn checkpoint_restore(
        engine: VarDictionary,
        controller: VarDictionary,
        randoms: PackedInt64Array,
        phase_state: VarDictionary,
    ) -> VarDictionary {
        game::checkpoint_restore(&engine, &controller, &randoms, &phase_state)
    }

    /// The text that blocks a save, or an empty string.
    #[func]
    fn checkpoint_save_error(pending_interaction: GString) -> GString {
        let state = sc2k_game::state::EngineState {
            pending_interaction: pending_interaction.to_string(),
            ..Default::default()
        };

        GString::from(sc2k_game::checkpoint::save_error(&state).as_str())
    }

    /// The operations that this library implements.
    #[func]
    fn operations() -> PackedStringArray {
        ops::OPERATIONS
            .iter()
            .chain(tool_ops::OPERATIONS)
            .chain(game::OPERATIONS)
            .map(|name| GString::from(*name))
            .collect()
    }
}

fn scenario_value(scen: &PackedByteArray) -> (VarDictionary, Option<sc2k_sim::sim::civic::scenario::Scenario>) {
    let mut city = sc2k_sim::sim::city::City::new(128, 2);
    city.scen = sc2k_sim::sim::city::Chunk::new(scen.to_vec());
    let mut result = VarDictionary::new();

    match sc2k_sim::sim::civic::scenario::Scenario::from_city(&city) {
        Ok(scenario) => {
            let mut fields = VarDictionary::new();

            for (name, value) in [
                ("format_size", scenario.format_size as i64),
                ("disaster_type", scenario.disaster_type),
                ("disaster_x", scenario.disaster_x),
                ("disaster_y", scenario.disaster_y),
                ("time_limit_months", scenario.time_limit_months),
                ("city_size_goal", scenario.city_size_goal),
                ("residential_goal", scenario.residential_goal),
                ("commercial_goal", scenario.commercial_goal),
                ("industrial_goal", scenario.industrial_goal),
                ("cash_goal", scenario.cash_goal),
                ("land_value_goal", scenario.land_value_goal),
                ("life_expectancy_goal", scenario.life_expectancy_goal),
                ("education_goal", scenario.education_goal),
                ("pollution_limit", scenario.pollution_limit),
                ("crime_limit", scenario.crime_limit),
                ("traffic_limit", scenario.traffic_limit),
                ("first_building_id", scenario.first_building_id),
                ("second_building_id", scenario.second_building_id),
                ("first_building_tile_count", scenario.first_building_tile_count),
                ("second_building_tile_count", scenario.second_building_tile_count),
            ] {
                fields.set(name, value);
            }

            result.set("ok", true);
            result.set("error", "");
            result.set("fields", &fields);

            (result, Some(scenario))
        }
        Err(error) => {
            result.set("ok", false);
            result.set("error", error.as_str());

            (result, None)
        }
    }
}
