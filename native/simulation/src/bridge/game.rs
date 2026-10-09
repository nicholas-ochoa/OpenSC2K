//! Engine and speed controller operations for SimulationEngine and
//! GameSpeedController. GDScript keeps the state between calls: a request
//! carries `engine` (the engine fields), `scenario` (the SCEN fields, or empty)
//! and, for `game.*`, `controller`. The result has `result`, `engine`,
//! `scenario_present`, `scenario_time_limit`, and `controller`.

use godot::prelude::*;

use super::convert;
use super::ops::Outcome;
use sc2k_game::clock::DaySchedule;
use sc2k_game::engine::Engine;
use sc2k_game::speed::{Speed, SpeedState};
use sc2k_game::state::EngineState;
use sc2k_sim::sim::city::City;
use sc2k_sim::sim::geom::Vec2i;
use sc2k_sim::sim::random::Randoms;
use sc2k_sim::sim::value::{Ints32, ToValue, Value};

pub const OPERATIONS: &[&str] = &[
    "engine.advance_day",
    "engine.resolve_annual_budget",
    "engine.resolve_military_proposal",
    "engine.resolve_military_notice",
    "engine.advance_disaster_tick",
    "engine.start_disaster",
    "engine.advance_moving_things",
    "engine.recalculate_mayor_house",
    "engine.advance_arcology_launch",
    "engine.menu_disaster_point",
    "engine.initialize",
    "engine.refresh_city_status",
    "game.advance_time",
    "game.resolve_annual_budget",
    "game.resolve_military_proposal",
    "game.resolve_military_notice",
    "game.run_day",
    "game.step_schedule",
];

pub fn is_game(op: &str) -> bool {
    OPERATIONS.contains(&op)
}

fn schedule_from(fields: &VarDictionary) -> Option<DaySchedule> {
    if fields.is_empty() {
        return None;
    }

    Some(DaySchedule {
        city_days: convert::int(fields, "city_days", 0),
        elapsed_years: convert::int(fields, "elapsed_years", 0),
        month: convert::int(fields, "month", 0),
        month_day: convert::int(fields, "month_day", 0),
        season: convert::int(fields, "season", 0),
        actions: convert::strings(fields, "actions"),
        growth_step: convert::int(fields, "growth_step", -1),
        growth_substep: convert::int(fields, "growth_substep", -1),
    })
}

fn state_from(args: &VarDictionary) -> EngineState {
    let fields = convert::dictionary(args, "engine");
    let capacity = convert::ints32(&fields, "dispatch_capacity");

    EngineState {
        day: convert::engine_state(args, "engine"),
        city_days: convert::int(&fields, "city_days", 0),
        pending_interaction: convert::string(&fields, "pending_interaction"),
        pending_day_schedule: schedule_from(&convert::dictionary(&fields, "pending_day_schedule")),
        pending_military_site: convert::rect(&fields, "pending_military_site"),
        pending_military_base_type: convert::int(&fields, "pending_military_base_type", 0),
        forced_military_base_type: convert::int(&fields, "forced_military_base_type", 0),
        scenario: convert::scenario(args, "scenario"),
        active_disaster_type: convert::int(&fields, "active_disaster_type", 0),
        unsupported_disaster_type: convert::int(&fields, "unsupported_disaster_type", 0),
        disaster_map_counter: convert::int(&fields, "disaster_map_counter", 0),
        disaster_hurricane_counter: convert::int(&fields, "disaster_hurricane_counter", 0),
        dispatch_capacity: match capacity.as_slice() {
            [police, fire, military] => [i64::from(*police), i64::from(*fire), i64::from(*military)],
            _ => sc2k_sim::sim::tools::commands::dispatch::NO_CAPACITY,
        },
        dispatch_epoch: convert::int(&fields, "dispatch_epoch", 0),
        vehicle_crashes_enabled: convert::boolean(&fields, "vehicle_crashes_enabled", true),
        arcology_launch_active: convert::boolean(&fields, "arcology_launch_active", false),
        arcology_launch_sites: convert::points(&fields, "arcology_launch_sites"),
        arcology_launch_wait: convert::int(&fields, "arcology_launch_wait", 0),
    }
}

fn state_value(state: &EngineState) -> Value {
    let Value::Dict(mut fields) = state.day.to_value() else {
        unreachable!("engine state is a dictionary")
    };

    let mut add = |name: &str, value: Value| fields.push((Value::Str(name.to_string()), value));
    add("city_days", Value::Int(state.city_days));
    add("pending_interaction", Value::Str(state.pending_interaction.clone()));
    add("pending_day_schedule", state.pending_day_schedule.to_value());
    add("pending_military_site", Value::Rect2i(state.pending_military_site));
    add("pending_military_base_type", Value::Int(state.pending_military_base_type));
    add("forced_military_base_type", Value::Int(state.forced_military_base_type));
    add("active_disaster_type", Value::Int(state.active_disaster_type));
    add("unsupported_disaster_type", Value::Int(state.unsupported_disaster_type));
    add("disaster_map_counter", Value::Int(state.disaster_map_counter));
    add("disaster_hurricane_counter", Value::Int(state.disaster_hurricane_counter));
    add(
        "dispatch_capacity",
        Ints32(state.dispatch_capacity.iter().map(|count| *count as i32).collect()).to_value(),
    );
    add("dispatch_epoch", Value::Int(state.dispatch_epoch));
    add("vehicle_crashes_enabled", Value::Bool(state.vehicle_crashes_enabled));
    add("arcology_launch_active", Value::Bool(state.arcology_launch_active));
    add("arcology_launch_sites", state.arcology_launch_sites.to_value());
    add("arcology_launch_wait", Value::Int(state.arcology_launch_wait));

    Value::Dict(fields)
}

fn speed_from(args: &VarDictionary) -> SpeedState {
    let fields = convert::dictionary(args, "controller");
    let float = |name: &str| fields.get(name).and_then(|value| value.try_to::<f64>().ok()).unwrap_or(0.0);

    SpeedState {
        speed: convert::int(&fields, "speed", sc2k_game::speed::PAUSED),
        accumulator_msec: float("accumulator_msec"),
        skip_next_disaster_tick: convert::boolean(&fields, "skip_next_disaster_tick", false),
        launch_elapsed_msec: float("launch_elapsed_msec"),
        subtick_counter: convert::int(&fields, "subtick_counter", 0),
        simulation_ready: convert::boolean(&fields, "simulation_ready", false),
        interaction_blocked: convert::boolean(&fields, "interaction_blocked", false),
        terminal_blocked: convert::boolean(&fields, "terminal_blocked", false),
        pause_at_day: convert::int(&fields, "pause_at_day", -1),
    }
}

fn speed_value(state: &SpeedState) -> Value {
    let fields = [
        ("speed", Value::Int(state.speed)),
        ("accumulator_msec", Value::Float(state.accumulator_msec)),
        ("skip_next_disaster_tick", Value::Bool(state.skip_next_disaster_tick)),
        ("launch_elapsed_msec", Value::Float(state.launch_elapsed_msec)),
        ("subtick_counter", Value::Int(state.subtick_counter)),
        ("simulation_ready", Value::Bool(state.simulation_ready)),
        ("interaction_blocked", Value::Bool(state.interaction_blocked)),
        ("terminal_blocked", Value::Bool(state.terminal_blocked)),
        ("pause_at_day", Value::Int(state.pause_at_day)),
    ];

    Value::Dict(
        fields
            .into_iter()
            .map(|(name, value)| (Value::Str(name.to_string()), value))
            .collect(),
    )
}

/// Run one engine or speed controller operation.
pub fn dispatch(op: &str, args: &VarDictionary, city: &mut City, randoms: &mut Randoms) -> Outcome {
    let mut state = state_from(args);
    let mut speed = speed_from(args);
    let mut engine = Engine {
        city,
        randoms,
        state: &mut state,
        detailed: convert::boolean(args, "detailed", false),
    };

    let result = match op {
        "engine.advance_day" => engine.advance_day().to_value(),
        "engine.resolve_annual_budget" => {
            let values = convert::ints32(args, "values");
            engine
                .resolve_annual_budget(&values, convert::boolean(args, "auto_budget", false))
                .to_value()
        }
        "engine.resolve_military_proposal" => engine
            .resolve_military_proposal(convert::boolean(args, "accepted", false))
            .to_value(),
        "engine.resolve_military_notice" => engine.resolve_military_notice().to_value(),
        "engine.advance_disaster_tick" => engine.advance_disaster_tick().to_value(),
        "engine.start_disaster" => {
            let point = convert::point(args, "point", Vec2i::ZERO);
            engine.start_disaster(convert::int(args, "disaster_type", 0), point)
        }
        "engine.advance_moving_things" => engine.advance_moving_things(convert::int(args, "current_time_msec", 0)).to_value(),
        "engine.recalculate_mayor_house" => engine.recalculate_mayor_house().to_value(),
        "engine.advance_arcology_launch" => engine.advance_arcology_launch(convert::int(args, "steps", 1)).to_value(),
        "engine.menu_disaster_point" => {
            let fallback = convert::point(args, "fallback", Vec2i::ZERO);
            Value::Vec2i(engine.menu_disaster_point(convert::int(args, "disaster_type", 0), fallback))
        }
        "engine.initialize" => Value::Bool(engine.initialize_loaded_city()),
        "engine.refresh_city_status" => {
            engine.refresh_city_status();
            Value::Nil
        }
        _ => {
            let mut controller = Speed {
                engine: &mut engine,
                state: &mut speed,
            };

            match op {
                "game.advance_time" => {
                    let delta = args.get("delta_msec").and_then(|value| value.try_to::<f64>().ok()).unwrap_or(0.0);
                    let now = convert::int(args, "current_time_msec", 0);
                    controller
                        .advance_time(delta, now, convert::boolean(args, "suspended", false))
                        .to_value()
                }
                "game.resolve_annual_budget" => {
                    let values = convert::ints32(args, "values");
                    controller
                        .resolve_annual_budget(&values, convert::boolean(args, "auto_budget", false))
                        .to_value()
                }
                "game.resolve_military_proposal" => controller
                    .resolve_military_proposal(convert::boolean(args, "accepted", false))
                    .to_value(),
                "game.run_day" => controller.run_one_day().to_value(),
                "game.step_schedule" => {
                    let schedule = schedule_from(&convert::dictionary(args, "schedule")).unwrap_or_default();
                    controller
                        .step_schedule(
                            schedule,
                            convert::boolean(args, "first", false),
                            convert::boolean(args, "last", false),
                        )
                        .to_value()
                }
                _ => controller.resolve_military_notice().to_value(),
            }
        }
    };

    // a failed call keeps its result, and the error drops the native city cache
    let error = match &result {
        Value::Object(_, fields) if fields.iter().any(|(name, value)| *name == "ok" && *value == Value::Bool(false)) => {
            let text = sc2k_game::values::text(&result, "error");

            if text.is_empty() { "the operation failed".into() } else { text }
        }
        _ => String::new(),
    };

    let scenario_present = state.scenario.is_some();
    let time_limit = state.scenario.as_ref().map_or(-1, |scenario| scenario.time_limit_months);
    let fields = vec![
        (Value::Str("result".into()), result),
        (Value::Str("engine".into()), state_value(&state)),
        (Value::Str("scenario_present".into()), Value::Bool(scenario_present)),
        (Value::Str("scenario_time_limit".into()), Value::Int(time_limit)),
        (Value::Str("controller".into()), speed_value(&speed)),
    ];

    Outcome {
        error,
        result: Value::Dict(fields),
    }
}

fn saved_randoms(randoms: &PackedInt64Array) -> sc2k_game::checkpoint::SavedRandoms {
    match randoms.as_slice() {
        [process, lfsr, game] => sc2k_game::checkpoint::SavedRandoms {
            process: *process,
            lfsr: *lfsr,
            game: *game,
        },
        _ => sc2k_game::checkpoint::SavedRandoms::default(),
    }
}

fn state_args(engine: &VarDictionary, controller: &VarDictionary) -> VarDictionary {
    let mut args = VarDictionary::new();
    args.set("engine", engine);
    args.set("controller", controller);
    args
}

/// `{randoms, phase_state}` of a save: the three saved random states and the
/// phase state with the engine and controller values.
pub fn checkpoint_capture(
    engine: &VarDictionary,
    controller: &VarDictionary,
    randoms: &PackedInt64Array,
    phase_state: &VarDictionary,
) -> VarDictionary {
    let args = state_args(engine, controller);
    let saved = saved_randoms(randoms);
    let mut live = Randoms::new(1, 1, 1);
    sc2k_game::checkpoint::restore_randoms(&mut live, saved);
    let (saved, state) = sc2k_game::checkpoint::capture(
        &state_from(&args),
        &speed_from(&args),
        &live,
        &super::json_value::object_from(phase_state),
    );
    let mut result = VarDictionary::new();
    result.set(
        "randoms",
        &PackedInt64Array::from([saved.process, saved.lfsr, saved.game].as_slice()),
    );
    result.set("phase_state", &super::json_value::dictionary_from(&state));
    result
}

/// `{error, engine, controller}` after a load restores the state of its file.
/// `randoms` are the saved random states; the caller sets them.
pub fn checkpoint_restore(
    engine: &VarDictionary,
    controller: &VarDictionary,
    randoms: &PackedInt64Array,
    phase_state: &VarDictionary,
) -> VarDictionary {
    let args = state_args(engine, controller);
    let mut state = state_from(&args);
    let mut speed = speed_from(&args);
    let mut live = Randoms::new(1, 1, 1);
    let error = sc2k_game::checkpoint::restore(
        &mut state,
        &mut speed,
        &mut live,
        saved_randoms(randoms),
        &super::json_value::object_from(phase_state),
    )
    .err()
    .unwrap_or_default();
    let mut result = VarDictionary::new();
    result.set("error", error.as_str());
    result.set("engine", &convert::variant(&state_value(&state)));
    result.set("controller", &convert::variant(&speed_value(&speed)));
    result
}
