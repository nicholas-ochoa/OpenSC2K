//! The simulation state that an SC2X version 4 file saves in metadata, as
//! Sc2xCheckpoint. MISC and the other structures hold the city; these values
//! belong to the engine and the speed controller. A save happens at a
//! completed day: a day that waits for the player cannot be saved.
//!
//! Saved: the three random states and the `phase_state` keys, including the
//! results of the load scan, the fire timer, and a staged arcology launch. Not
//! saved: frame timing, the traffic news deadline, music playback, the vehicle
//! layer switch, and pause targets.

use crate::speed::SpeedState;
use crate::state::EngineState;
use sc2k_formats::json::{Object, Value};
use sc2k_sim::formats::sc2x::metadata::{FIRE_TIMER_KEY, LAUNCH_ACTIVE_KEY, phase_state_error};
use sc2k_sim::sim::geom::Vec2i;
use sc2k_sim::sim::random::Randoms;

const RANDOM_MASK: i64 = 0xffff_ffff;
/// The subtick counter counts eight base ticks.
const SUBTICK_MASK: i64 = 7;

/// The random states that a file saves.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct SavedRandoms {
    pub process: i64,
    pub lfsr: i64,
    pub game: i64,
}

/// Empty when the engine is at a completed day and can be saved.
pub fn save_error(state: &EngineState) -> String {
    if state.pending_interaction.is_empty() {
        String::new()
    } else {
        format!("Finish the {} before saving the city.", state.pending_interaction.replace('_', " "))
    }
}

fn point(value: Vec2i) -> Value {
    Value::Array(vec![Value::Int(value.x), Value::Int(value.y)])
}

/// The random states and the phase state of a save. Unknown phase state keys stay.
pub fn capture(state: &EngineState, speed: &SpeedState, randoms: &Randoms, phase_state: &Object) -> (SavedRandoms, Object) {
    let saved = SavedRandoms {
        process: randoms.random.state & RANDOM_MASK,
        // the LFSR never leaves zero; the loader rejects it
        lfsr: if randoms.lfsr.state != 0 { randoms.lfsr.state } else { 1 },
        game: randoms.game.state & RANDOM_MASK,
    };
    let day = &state.day;
    let mut result = phase_state.clone();
    let fields = [
        ("ship_home", point(day.ship_home)),
        ("commerce_connections", Value::Int(day.commerce_connections)),
        ("industry_connections", Value::Int(day.industry_connections)),
        ("bus_passengers", Value::Int(day.bus_passengers)),
        ("rail_passengers", Value::Int(day.rail_passengers)),
        ("subway_passengers", Value::Int(day.subway_passengers)),
        ("mayor_approval", Value::Int(day.mayor_approval)),
        ("pending_disaster_type", Value::Int(day.pending_disaster_type)),
        ("pending_disaster_point", point(day.pending_disaster_point)),
        ("active_disaster_type", Value::Int(state.active_disaster_type)),
        ("unsupported_disaster_type", Value::Int(state.unsupported_disaster_type)),
        ("disaster_map_counter", Value::Int(state.disaster_map_counter)),
        ("disaster_hurricane_counter", Value::Int(state.disaster_hurricane_counter)),
        ("terminal_state", Value::Bool(day.terminal_state)),
        ("subtick_counter", Value::Int(speed.subtick_counter)),
        ("simulation_ready", Value::Bool(speed.simulation_ready)),
        ("developed_tiles", Value::Int(day.developed_tiles)),
        ("power_usage_percent", Value::Int(day.power_usage_percent)),
        ("water_usage_percent", Value::Int(day.water_usage_percent)),
        ("city_status_resource_id", Value::Int(day.city_status_resource_id)),
        // the fire timer advances in whole base ticks while a fire burns
        (FIRE_TIMER_KEY, Value::Int(speed.fire_elapsed_msec.round() as i64)),
        (LAUNCH_ACTIVE_KEY, Value::Bool(state.arcology_launch_active)),
    ];

    for (key, value) in fields {
        result.insert(key, value);
    }

    (saved, result)
}

/// Restore the random states of a loaded file. A load restores them before the load scan.
pub fn restore_randoms(randoms: &mut Randoms, saved: SavedRandoms) {
    randoms.random.state = saved.process;
    randoms.lfsr.state = saved.lfsr;
    randoms.game.state = saved.game;
}

/// Restore the state of a loaded file. A phase state with a value of the wrong
/// type changes nothing and returns the error.
pub fn restore(
    state: &mut EngineState,
    speed: &mut SpeedState,
    randoms: &mut Randoms,
    saved: SavedRandoms,
    phase_state: &Object,
) -> Result<(), String> {
    phase_state_error(phase_state)?;
    restore_randoms(randoms, saved);

    if phase_state.is_empty() {
        return Ok(());
    }

    let int = |key: &str| phase_state.get(key).map_or(0, Value::to_int);
    let flag = |key: &str| phase_state.get(key).and_then(Value::as_bool).unwrap_or(false);
    let point = |key: &str| match phase_state.get(key).and_then(Value::as_array) {
        Some([x, y, ..]) => Vec2i::new(x.to_int(), y.to_int()),
        _ => Vec2i::ZERO,
    };
    let day = &mut state.day;
    day.ship_home = point("ship_home");
    day.commerce_connections = int("commerce_connections");
    day.industry_connections = int("industry_connections");
    day.bus_passengers = int("bus_passengers");
    day.rail_passengers = int("rail_passengers");
    day.subway_passengers = int("subway_passengers");
    day.mayor_approval = int("mayor_approval");
    day.pending_disaster_type = int("pending_disaster_type");
    day.pending_disaster_point = point("pending_disaster_point");
    day.terminal_state = flag("terminal_state");
    day.developed_tiles = int("developed_tiles");
    day.power_usage_percent = int("power_usage_percent");
    day.water_usage_percent = int("water_usage_percent");
    day.city_status_resource_id = int("city_status_resource_id");
    state.active_disaster_type = int("active_disaster_type");
    state.unsupported_disaster_type = int("unsupported_disaster_type");
    state.disaster_map_counter = int("disaster_map_counter");
    state.disaster_hurricane_counter = int("disaster_hurricane_counter");
    state.arcology_launch_active = flag(LAUNCH_ACTIVE_KEY);
    speed.subtick_counter = int("subtick_counter") & SUBTICK_MASK;
    speed.simulation_ready = flag("simulation_ready");
    speed.terminal_blocked = state.day.terminal_state;
    speed.fire_elapsed_msec = phase_state.get(FIRE_TIMER_KEY).map_or(0.0, |timer| timer.to_int() as f64);

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_capture_restores_the_same_state() {
        let mut state = EngineState::default();
        state.day.ship_home = Vec2i::new(4, 5);
        state.day.mayor_approval = 61;
        state.active_disaster_type = 2;
        state.arcology_launch_active = true;
        let speed = SpeedState {
            subtick_counter: 3,
            fire_elapsed_msec: 399.6,
            ..SpeedState::default()
        };
        let mut unknown = Object::new();
        unknown.insert("future_key", Value::Int(9));
        let (saved, phase_state) = capture(&state, &speed, &Randoms::new(11, 0, 13), &unknown);
        assert_eq!(
            saved,
            SavedRandoms {
                process: 11,
                lfsr: 1,
                game: 13
            },
            "a zero LFSR saves as 1"
        );
        assert_eq!(phase_state.get("future_key"), Some(&Value::Int(9)));
        assert_eq!(phase_state.get(FIRE_TIMER_KEY), Some(&Value::Int(400)));

        let mut restored = EngineState::default();
        let mut restored_speed = SpeedState::default();
        let mut randoms = Randoms::new(1, 1, 1);
        restore(&mut restored, &mut restored_speed, &mut randoms, saved, &phase_state).expect("a valid phase state");
        assert_eq!(
            (restored.day.ship_home, restored.day.mayor_approval, restored.active_disaster_type),
            (Vec2i::new(4, 5), 61, 2)
        );
        assert!(restored.arcology_launch_active);
        assert_eq!((restored_speed.subtick_counter, restored_speed.fire_elapsed_msec), (3, 400.0));
        assert_eq!((randoms.random.state, randoms.game.state), (11, 13));
    }

    #[test]
    fn a_pending_answer_blocks_a_save() {
        let mut state = EngineState::default();
        assert!(save_error(&state).is_empty());
        state.pending_interaction = "annual_budget".into();
        assert_eq!(save_error(&state), "Finish the annual budget before saving the city.");
    }
}
