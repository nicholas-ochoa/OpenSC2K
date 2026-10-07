//! The game speed: base ticks of 200 milliseconds, moving objects on each tick,
//! and days at the pace of the speed. This is GameSpeedController of the
//! scripts. The controller state stays in `SpeedState` between calls.

use crate::engine::Engine;
use crate::results::{DayResult, TickResult};
use crate::values;
use sc2k_sim::sim::value::{ToValue, Value};

pub const PAUSED: i64 = 1;
pub const TURTLE: i64 = 2;
pub const LLAMA: i64 = 3;
pub const CHEETAH: i64 = 4;
pub const AFRICAN_SWALLOW: i64 = 5;

pub const BASE_TICK_MSEC: f64 = 200.0;

/// A staged arcology launch ignites one arcology and launches one in each step.
pub const LAUNCH_STEP_MSEC: f64 = 50.0;

/// The most launch steps that one call runs after a slow frame.
pub const LAUNCH_MAX_STEPS: i64 = 4;

#[derive(Clone, Debug, PartialEq)]
pub struct SpeedState {
    pub speed: i64,
    pub accumulator_msec: f64,
    /// True when disaster mode drops the next due tick. SIMCITY.EXE 0x0040c100
    /// drops every other due tick of a disaster, except at African Swallow.
    pub skip_next_disaster_tick: bool,
    pub launch_elapsed_msec: f64,
    pub subtick_counter: i64,
    pub simulation_ready: bool,
    pub interaction_blocked: bool,
    pub terminal_blocked: bool,
    /// The city age at which the simulation pauses, or -1.
    pub pause_at_day: i64,
}

impl Default for SpeedState {
    fn default() -> Self {
        Self {
            speed: PAUSED,
            accumulator_msec: 0.0,
            skip_next_disaster_tick: false,
            launch_elapsed_msec: 0.0,
            subtick_counter: 0,
            simulation_ready: false,
            interaction_blocked: false,
            terminal_blocked: false,
            pause_at_day: -1,
        }
    }
}

pub fn is_speed(value: i64) -> bool {
    (PAUSED..=AFRICAN_SWALLOW).contains(&value)
}

/// The speed controller over one engine call.
pub struct Speed<'a, 'b> {
    pub engine: &'a mut Engine<'b>,
    pub state: &'a mut SpeedState,
}

impl Speed<'_, '_> {
    /// Change the speed and save it in MISC. A pause from any source cancels
    /// the target day.
    pub fn set_speed(&mut self, value: i64) -> bool {
        if !is_speed(value) || !self.engine.city.set_simulation_speed(value) {
            return false;
        }

        self.state.speed = value;

        if value == PAUSED {
            self.state.pause_at_day = -1;
        }

        true
    }

    fn running(&self, suspended: bool) -> bool {
        self.state.speed > PAUSED && !suspended && !self.state.interaction_blocked && !self.state.terminal_blocked
    }

    /// Run the base ticks of `delta_msec` frame time.
    pub fn advance_time(&mut self, delta_msec: f64, current_time_msec: i64, suspended: bool) -> TickResult {
        let mut result = TickResult::new();

        if delta_msec < 0.0 {
            result.error = "elapsed time cannot be negative".into();

            return result;
        }

        if let Err(error) = self.run_launch_steps(&mut result, delta_msec, suspended) {
            result.error = error;

            return result;
        }

        self.state.accumulator_msec += delta_msec;
        let mut ran_swallow_day = false;

        while self.state.accumulator_msec >= BASE_TICK_MSEC {
            self.state.accumulator_msec -= BASE_TICK_MSEC;
            result.base_ticks += 1;
            self.state.subtick_counter = (self.state.subtick_counter + 1) & 7;
            self.state.simulation_ready = self.state.simulation_ready || self.is_day_due(self.state.subtick_counter);
            self.drop_alternate_disaster_tick();

            let pulse_time = current_time_msec - self.state.accumulator_msec as i64;

            if self.running(suspended) {
                let moving = self.engine.advance_moving_things(pulse_time);

                if !moving.base.ok {
                    result.error = moving.base.error;

                    return result;
                }

                let value = moving.to_value();
                append_events(&mut result, &value);
                result.moving_results.push(value);
            }

            if self.running(suspended) && self.state.simulation_ready {
                if let Err(error) = self.run_day(&mut result) {
                    result.error = error;

                    return result;
                }

                if self.pause_on_target_day(&mut result) {
                    break;
                }

                // African Swallow runs a day in each frame. A disaster scan waits for a base tick
                if self.state.speed == AFRICAN_SWALLOW && self.engine.state.active_disaster_type == 0 {
                    ran_swallow_day = true;
                } else {
                    self.state.simulation_ready = false;
                }
            }
        }

        if self.running(suspended) && self.state.simulation_ready && !ran_swallow_day {
            if let Err(error) = self.run_day(&mut result) {
                result.error = error;

                return result;
            }

            self.pause_on_target_day(&mut result);

            if self.state.speed != AFRICAN_SWALLOW || self.engine.state.active_disaster_type != 0 {
                self.state.simulation_ready = false;
            }
        }

        result.ok = true;

        result
    }

    pub fn resolve_annual_budget(&mut self, funding_values: &[i32], auto_budget: bool) -> TickResult {
        if !self.state.interaction_blocked {
            return failed("no annual budget interaction is pending");
        }

        let day = self.engine.resolve_annual_budget(funding_values, auto_budget);
        self.answered(day)
    }

    pub fn resolve_military_proposal(&mut self, accepted: bool) -> TickResult {
        if !self.state.interaction_blocked {
            return failed("no military proposal interaction is pending");
        }

        let day = self.engine.resolve_military_proposal(accepted);
        self.answered(day)
    }

    pub fn resolve_military_notice(&mut self) -> TickResult {
        if !self.state.interaction_blocked {
            return failed("no military notice is pending");
        }

        let day = self.engine.resolve_military_notice();
        self.answered(day)
    }

    fn answered(&mut self, day: DayResult) -> TickResult {
        if !day.ok {
            return failed(&day.error);
        }

        let mut result = TickResult::new();
        self.state.interaction_blocked = false;
        self.consume_day_result(&mut result, day);
        result.ok = true;

        result
    }

    /// One day or disaster tick now, as the debug step of a day.
    pub fn run_one_day(&mut self) -> TickResult {
        let mut result = TickResult::new();

        match self.run_day(&mut result) {
            Ok(()) => result.ok = true,
            Err(error) => result.error = error,
        }

        result
    }

    /// Run part of a day, as the debug step of a phase. `first` asks for the
    /// annual budget first; `last` starts the disaster that the day left pending.
    pub fn step_schedule(&mut self, schedule: crate::clock::DaySchedule, first: bool, last: bool) -> TickResult {
        let mut day = self.engine.run_day_schedule(schedule, false, first);

        if last && day.ok {
            day = self.engine.append_pending_disaster(day);
        }

        let mut result = TickResult::new();
        result.ok = day.ok;
        result.error = day.error.clone();

        if day.ok {
            self.consume_day_result(&mut result, day);
        }

        result
    }

    pub fn acknowledge_game_over(&mut self) {
        self.state.interaction_blocked = !self.engine.state.pending_interaction.is_empty();
    }

    /// Stop at the end of the target day. The remaining base ticks of the call do no work.
    fn pause_on_target_day(&mut self, result: &mut TickResult) -> bool {
        if self.state.pause_at_day < 0 || self.engine.city.age_in_days() < self.state.pause_at_day {
            return false;
        }

        result.paused_on_target_day = self.set_speed(PAUSED);
        self.state.pause_at_day = -1;

        true
    }

    /// True when `advance_time(delta_msec)` runs a day or a disaster tick. The
    /// delta must not exceed one base tick.
    pub fn tick_runs_day(&self, delta_msec: f64) -> bool {
        if self.state.simulation_ready {
            return true;
        }

        self.state.accumulator_msec + delta_msec >= BASE_TICK_MSEC && self.is_day_due((self.state.subtick_counter + 1) & 7)
    }

    /// The timer of SIMCITY.EXE (0x0040c100) runs this check on each base tick,
    /// also while the game is paused. In disaster mode it drops every other
    /// due tick, so disaster scans run at half the day pace. African Swallow
    /// keeps every due tick.
    fn drop_alternate_disaster_tick(&mut self) {
        if !self.state.simulation_ready || self.engine.state.active_disaster_type == 0 || self.state.speed == AFRICAN_SWALLOW {
            return;
        }

        let skip = self.state.skip_next_disaster_tick;
        self.state.skip_next_disaster_tick = !skip;

        if skip {
            self.state.simulation_ready = false;
        }
    }

    fn is_day_due(&self, counter: i64) -> bool {
        match self.state.speed {
            PAUSED => counter == 0,
            TURTLE => counter & 3 == 0,
            LLAMA => counter & 1 == 0,
            CHEETAH | AFRICAN_SWALLOW => true,
            _ => false,
        }
    }

    /// A staged arcology launch runs on frame time, not on base ticks, so the
    /// launches follow each other. The days wait until it ends.
    fn run_launch_steps(&mut self, result: &mut TickResult, delta_msec: f64, suspended: bool) -> Result<(), String> {
        if !self.engine.state.arcology_launch_active {
            self.state.launch_elapsed_msec = 0.0;

            return Ok(());
        }

        if !self.running(suspended) {
            return Ok(());
        }

        self.state.launch_elapsed_msec += delta_msec;
        let steps = ((self.state.launch_elapsed_msec / LAUNCH_STEP_MSEC) as i64).min(LAUNCH_MAX_STEPS);

        if steps <= 0 {
            return Ok(());
        }

        self.state.launch_elapsed_msec %= LAUNCH_STEP_MSEC;
        let step = self.engine.advance_arcology_launch(steps);

        if !step.base.ok {
            return Err(step.base.error);
        }

        let value = step.to_value();
        append_runtime_events(result, &value);
        result.notice_ids.extend(values::ints(&value, "notice_ids"));
        result.launch_results.push(value);

        Ok(())
    }

    fn run_day(&mut self, result: &mut TickResult) -> Result<(), String> {
        if self.engine.state.arcology_launch_active {
            return Ok(());
        }

        if self.engine.state.active_disaster_type != 0 {
            let disaster = self.engine.advance_disaster_tick();

            if !disaster.base.ok {
                return Err(disaster.base.error);
            }

            let value = disaster.to_value();
            append_runtime_events(result, &value);
            result.disaster_results.push(value);

            return Ok(());
        }

        let day = self.engine.advance_day();

        if !day.ok {
            return Err(day.error);
        }

        if self.engine.state.active_disaster_type != 0 && self.slow_for_disaster() {
            result.disaster_slowed = true;
        }

        self.consume_day_result(result, day);

        Ok(())
    }

    /// The original drops African Swallow to Cheetah when a disaster starts
    /// (0x00406a50). True when the speed changed.
    pub fn slow_for_disaster(&mut self) -> bool {
        self.state.speed == AFRICAN_SWALLOW && self.set_speed(CHEETAH)
    }

    fn consume_day_result(&mut self, result: &mut TickResult, day: DayResult) {
        if !day.interaction_requests.is_empty() {
            self.state.interaction_blocked = true;
        }

        result
            .interaction_requests
            .extend(day.interaction_requests.iter().map(ToValue::to_value));

        for action in &day.pending {
            if !result.pending_actions.contains(action) {
                result.pending_actions.push(action.clone());
            }
        }

        for (_, phase) in &day.phase_results {
            for request in values::strings(phase, "refresh_requests") {
                if !result.refresh_requests.contains(&request) {
                    result.refresh_requests.push(request);
                }
            }

            result.effect_events.extend(values::items(phase, "effect_events"));
            result.game_over_events.extend(values::items(phase, "game_over_events"));

            if values::class(phase) == "GrowthResult" {
                result.effect_events.extend(values::items(phase, "bridge_effects"));
            }

            result.news_items.extend(values::items(phase, "news_items"));
            result.sound_events.extend(values::items(phase, "sound_events"));
            result.music_track_requests.extend(values::ints(phase, "music_track_requests"));
            result.view_center_requests.extend(values::items(phase, "view_center_requests"));
            result.notice_ids.extend(values::ints(phase, "notice_ids"));
            append_newspaper_request(result, phase);
        }

        for disaster in &day.disaster_results {
            append_runtime_events(result, disaster);
            result.disaster_results.push(disaster.clone());
        }

        for event in &result.game_over_events {
            let terminal = values::text(event, "type") != "scenario_victory";
            self.state.terminal_blocked = self.state.terminal_blocked || terminal;
            self.state.interaction_blocked = true;
        }

        result.day_results.push(day.to_value());
    }
}

fn failed(message: &str) -> TickResult {
    TickResult {
        error: message.to_string(),
        ..TickResult::new()
    }
}

fn append_events(result: &mut TickResult, phase: &Value) {
    result.news_items.extend(values::items(phase, "news_items"));
    result.effect_events.extend(values::items(phase, "effect_events"));
    result.sound_events.extend(values::items(phase, "sound_events"));
    result.view_center_requests.extend(values::items(phase, "view_center_requests"));
}

fn append_runtime_events(result: &mut TickResult, phase: &Value) {
    append_events(result, phase);
    append_newspaper_request(result, phase);
}

/// A request that names a paper replaces a request for the saved choice.
fn append_newspaper_request(result: &mut TickResult, phase: &Value) {
    if !values::boolean(phase, "newspaper_requested") {
        return;
    }

    result.newspaper_requested = true;
    let paper = values::int(phase, "newspaper_paper", -1);

    if paper >= 0 {
        result.newspaper_paper = paper;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::state::EngineState;
    use sc2k_sim::sim::city::City;
    use sc2k_sim::sim::disasters::{FIRE_OVERLAY, TOXIC_OVERLAY};
    use sc2k_sim::sim::new_city::{city_of, template};
    use sc2k_sim::sim::overlay;
    use sc2k_sim::sim::random::Randoms;

    const RIOT: i64 = 3;
    const TOXIC_SPILL: i64 = 4;
    const FIRESTORM: i64 = 12;

    /// The markers fill this square, so a few scans do not clear them.
    const MARKER_FIRST: i64 = 30;
    const MARKER_END: i64 = 50;

    /// A city with an active disaster and a square of its markers.
    struct Disaster {
        city: City,
        randoms: Randoms,
        engine: EngineState,
        speed: SpeedState,
    }

    impl Disaster {
        fn new(edge: i64, disaster_type: i64, marker: i64, speed: i64) -> Self {
            let mut city = city_of(&template::empty_city(edge));
            let mut text = city.xtxt.data.clone();

            for x in MARKER_FIRST..MARKER_END {
                for y in MARKER_FIRST..MARKER_END {
                    overlay::set_marker_at(&mut text, x * edge + y, marker);
                }
            }

            city.xtxt.replace(text);
            let mut engine = EngineState::for_city(&city);
            engine.active_disaster_type = disaster_type;

            Self {
                city,
                randoms: Randoms::new(5, 1, 1),
                engine,
                speed: SpeedState {
                    speed,
                    ..SpeedState::default()
                },
            }
        }

        /// The disaster scans of `frames` frames of `frame_msec`. No day runs.
        fn scans(&mut self, frame_msec: f64, frames: i64) -> usize {
            let mut engine = Engine {
                city: &mut self.city,
                randoms: &mut self.randoms,
                state: &mut self.engine,
                detailed: false,
            };
            let mut controller = Speed {
                engine: &mut engine,
                state: &mut self.speed,
            };
            let mut scans = 0;

            for _ in 0..frames {
                let result = controller.advance_time(frame_msec, 1000, false);
                assert!(result.ok && result.day_results.is_empty(), "{}", result.error);
                scans += result.disaster_results.len();
            }

            scans
        }
    }

    /// SIMCITY.EXE drops every other due tick in disaster mode. Cheetah has
    /// five due ticks each second, so it scans 3 and then 2 times.
    #[test]
    fn every_disaster_scans_on_every_other_due_tick() {
        for edge in [128, 256] {
            for (disaster_type, marker) in [
                (1, FIRE_OVERLAY),
                (FIRESTORM, FIRE_OVERLAY),
                (RIOT, FIRE_OVERLAY),
                (TOXIC_SPILL, TOXIC_OVERLAY),
            ] {
                let mut disaster = Disaster::new(edge, disaster_type, marker, CHEETAH);
                let scans = [disaster.scans(1000.0, 1), disaster.scans(1000.0, 1)];
                assert_eq!(scans, [3, 2], "type {disaster_type} on a {edge} map");
            }
        }
    }

    #[test]
    fn slower_speeds_scan_at_half_their_day_pace() {
        // Llama has a due tick on each second base tick: 5 in 2 seconds.
        let mut llama = Disaster::new(128, 1, FIRE_OVERLAY, LLAMA);
        assert_eq!(llama.scans(2000.0, 1), 3);

        // Turtle has a due tick on each fourth base tick: 5 in 4 seconds.
        let mut turtle = Disaster::new(128, TOXIC_SPILL, TOXIC_OVERLAY, TURTLE);
        assert_eq!(turtle.scans(4000.0, 1), 3);
    }

    #[test]
    fn african_swallow_scans_once_per_base_tick() {
        for (disaster_type, marker) in [(TOXIC_SPILL, TOXIC_OVERLAY), (1, FIRE_OVERLAY)] {
            let mut disaster = Disaster::new(128, disaster_type, marker, AFRICAN_SWALLOW);
            assert_eq!(
                disaster.scans(20.0, 50),
                5,
                "type {disaster_type} scans once per base tick, not once per frame"
            );
            assert!(!disaster.speed.skip_next_disaster_tick, "African Swallow keeps every due tick");
        }
    }

    /// The timer alternates while the game is paused, as the original timer does.
    #[test]
    fn a_paused_disaster_waits() {
        let mut fire = Disaster::new(128, 1, FIRE_OVERLAY, PAUSED);
        assert_eq!(fire.scans(5000.0, 1), 0);

        fire.speed.speed = CHEETAH;
        assert_eq!(fire.scans(1000.0, 1) + fire.scans(1000.0, 1), 5);
    }

    #[test]
    fn a_day_without_a_disaster_keeps_every_due_tick() {
        let mut quiet = Disaster::new(128, 1, FIRE_OVERLAY, CHEETAH);
        quiet.engine.active_disaster_type = 0;
        let mut engine = Engine {
            city: &mut quiet.city,
            randoms: &mut quiet.randoms,
            state: &mut quiet.engine,
            detailed: false,
        };
        let mut controller = Speed {
            engine: &mut engine,
            state: &mut quiet.speed,
        };
        let result = controller.advance_time(1000.0, 1000, false);
        assert!(result.ok, "{}", result.error);
        assert_eq!(result.day_results.len(), 5);
        assert!(!quiet.speed.skip_next_disaster_tick);
    }
}
