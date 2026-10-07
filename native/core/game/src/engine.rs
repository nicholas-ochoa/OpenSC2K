//! The simulation engine of one city: days, player answers, disasters, moving
//! objects, the staged arcology launch and the mayor's house. This is
//! SimulationEngine and SimulationDaySchedule of the scripts. The state stays
//! in `EngineState` between calls.

use crate::clock::DaySchedule;
use crate::results::{DayResult, InteractionRequest};
use crate::state::EngineState;
use crate::values;
use sc2k_sim::sim::budget::checkpoint;
use sc2k_sim::sim::city::City;
use sc2k_sim::sim::civic::{annual, mayor, military};
use sc2k_sim::sim::disasters::{DisasterMapResult, DisasterStartResult, end as disaster_end, map as disaster_map, start as disaster_start};
use sc2k_sim::sim::economy::budget;
use sc2k_sim::sim::engine::{day, load};
use sc2k_sim::sim::events::{SoundEvent, Timing};
use sc2k_sim::sim::geom::{Rect2i, Vec2i};
use sc2k_sim::sim::ids::sc2misc_layout as misc;
use sc2k_sim::sim::moving::phase::{self as moving, TickOptions};
use sc2k_sim::sim::moving::result::{ConnectionChange, MovingThingResult};
use sc2k_sim::sim::phase::{PhaseBase, TimingSpan};
use sc2k_sim::sim::random::Randoms;
use sc2k_sim::sim::reports::news;
use sc2k_sim::sim::things;
use sc2k_sim::sim::tools::commands::dispatch::{self, NO_CAPACITY};
use sc2k_sim::sim::value::{ToValue, Value};

/// City modes in MISC.
const NORMAL_MODE: i64 = 1;
const DISASTER_MODE: i64 = 2;

/// The sound of the arrival of the Maxis Man.
const MAXIS_MAN_ARRIVAL_SOUND: i64 = 513;

/// The notice when the National Guard comes: SIMCITY.EXE string 119, which
/// 0x0044f910 shows with picture 406 and sound 513.
pub const NATIONAL_GUARD_NOTICE: i32 = 119;
const NATIONAL_GUARD_SOUND: i64 = 513;

/// The newspaper that the end of a disaster opens: the first one, not the
/// player's choice.
const DISASTER_END_PAPER: i64 = 0;

/// An airplane in this state is crashing.
const CRASHING_AIRPLANE_STATE: i64 = 7;

pub struct Engine<'a> {
    pub city: &'a mut City,
    pub randoms: &'a mut Randoms,
    pub state: &'a mut EngineState,
    /// The day phases measure each step.
    pub detailed: bool,
}

impl Engine<'_> {
    /// One moving-object tick. `current_time_msec` paces the traffic news.
    pub fn advance_moving_things(&mut self, current_time_msec: i64) -> MovingThingResult {
        let mut span = TimingSpan::new();
        let mut result = self.timed_advance_moving_things(current_time_msec);
        result.base.timing = span.finish();

        result
    }

    fn timed_advance_moving_things(&mut self, current_time_msec: i64) -> MovingThingResult {
        if self.state.day.terminal_state {
            return MovingThingResult::failed("the game has ended");
        }

        // 0x004546f0: with No Disasters, an explosion damages its neighbors only in a scenario
        let options = TickOptions {
            ship_home: self.state.day.ship_home,
            allow_disaster_damage: self.city.misc_u32(misc::NO_DISASTERS) == 0 || self.state.scenario.is_some(),
            traffic_news_time_msec: current_time_msec,
            traffic_news_deadline_msec: self.state.day.traffic_news_deadline_msec,
            suppress_vehicle_crashes: !self.state.vehicle_crashes_enabled,
        };

        let Randoms { random, lfsr, game } = &mut *self.randoms;
        let mut result = moving::run(self.city, random, lfsr, game, &options);

        if !result.base.ok {
            return result;
        }

        if let Err(error) = news::persist(self.city, &mut result.base) {
            return MovingThingResult::failed(error);
        }

        self.state.day.traffic_news_deadline_msec = result.traffic_news_deadline_msec;
        self.apply_connection_changes(&result.connection_count_changes);

        for request in &result.disaster_start_requests {
            self.state.day.pending_disaster_type = request.type_;
            self.state.day.pending_disaster_point = request.point;
        }

        result
    }

    fn apply_connection_changes(&mut self, changes: &[ConnectionChange]) {
        for change in changes {
            self.change_connection_count(&change.kind, change.delta);
        }
    }

    /// Neighbor connection counts are process-local 16-bit values, as in the
    /// original. `kind` is "commerce" or "industry".
    pub fn change_connection_count(&mut self, kind: &str, delta: i64) {
        if kind == "commerce" {
            self.state.day.commerce_connections = (self.state.day.commerce_connections + delta) & 0xffff;
        } else {
            self.state.day.industry_connections = (self.state.day.industry_connections + delta) & 0xffff;
        }
    }

    /// The next day.
    pub fn advance_day(&mut self) -> DayResult {
        let mut span = TimingSpan::new();
        let result = self.timed_advance_day();

        with_measured_timing(result, &mut span)
    }

    fn timed_advance_day(&mut self) -> DayResult {
        if !self.state.pending_interaction.is_empty() {
            return DayResult::failure(format!("{} interaction is pending", self.state.pending_interaction));
        }

        if self.state.day.terminal_state {
            return DayResult::failure("the game has ended");
        }

        if self.state.active_disaster_type != 0 {
            return DayResult::failure("a disaster is active");
        }

        if self.state.arcology_launch_active {
            return DayResult::failure("an arcology launch is active");
        }

        self.state.city_days += 1;
        let schedule = DaySchedule::for_day(self.state.city_days);

        if self.state.city_days < 0 || !self.city.set_age_in_days(self.state.city_days) {
            return DayResult::failure("cannot store the new simulation day");
        }

        // the day asks for the annual budget first when the year needs one
        let result = self.run_day_schedule(schedule, false, true);

        self.append_pending_disaster(result)
    }

    pub fn resolve_annual_budget(&mut self, funding_values: &[i32], auto_budget: bool) -> DayResult {
        let mut span = TimingSpan::new();
        let result = self.timed_resolve_annual_budget(funding_values, auto_budget);

        with_measured_timing(result, &mut span)
    }

    fn timed_resolve_annual_budget(&mut self, funding_values: &[i32], auto_budget: bool) -> DayResult {
        let Some(schedule) = self
            .state
            .pending_day_schedule
            .clone()
            .filter(|_| self.state.pending_interaction == "annual_budget")
        else {
            return DayResult::failure("no annual budget interaction is pending");
        };

        let stored = budget::set_funding(self.city, funding_values, auto_budget);

        if !stored.base.ok {
            return DayResult::failure(stored.base.error);
        }

        let result = self.run_day_schedule(schedule, true, false);

        if result.ok {
            self.state.pending_interaction.clear();
            self.state.pending_day_schedule = None;
        }

        self.append_pending_disaster(result)
    }

    pub fn resolve_military_proposal(&mut self, accepted: bool) -> DayResult {
        let mut span = TimingSpan::new();
        let result = self.timed_resolve_military_proposal(accepted);

        with_measured_timing(result, &mut span)
    }

    fn timed_resolve_military_proposal(&mut self, accepted: bool) -> DayResult {
        let Some(schedule) = self
            .state
            .pending_day_schedule
            .clone()
            .filter(|_| self.state.pending_interaction == "military_proposal")
        else {
            return DayResult::failure("no military proposal interaction is pending");
        };

        let forced = self.state.forced_military_base_type;
        let proposal = military::resolve(self.city, accepted, Some(&mut self.randoms.game), true, forced);
        self.state.forced_military_base_type = 0;

        if !proposal.base.ok {
            return DayResult::failure(proposal.base.error);
        }

        if proposal.notice_id >= 0 {
            self.state.pending_interaction = "military_notice".into();
            self.state.pending_military_site = if proposal.base.complete { Rect2i::default() } else { proposal.site };
            self.state.pending_military_base_type = proposal.base_type;

            let mut result = DayResult {
                ok: true,
                day: self.state.city_days,
                pending: schedule.actions.clone(),
                schedule: Some(schedule),
                interaction_requests: vec![InteractionRequest::new("military_notice")],
                ..DayResult::default()
            };

            result.set_phase("military_proposal", proposal.to_value());

            return result;
        }

        self.complete_military_proposal(proposal.to_value())
    }

    pub fn resolve_military_notice(&mut self) -> DayResult {
        if self.state.pending_interaction != "military_notice" || self.state.pending_day_schedule.is_none() {
            return DayResult::failure("no military notice is pending");
        }

        let mut proposal = military::MilitaryProposalResult {
            base_type: self.state.pending_military_base_type,
            ..Default::default()
        };
        proposal.base.ok = true;

        if self.state.pending_military_site.size.x > 0 && self.state.pending_military_site.size.y > 0 {
            proposal = military::reserve_land_site(
                self.city,
                self.state.pending_military_base_type,
                self.state.pending_military_site,
                -1,
            );

            if !proposal.base.ok {
                return DayResult::failure(proposal.base.error);
            }
        }

        self.state.pending_military_site = Rect2i::default();
        self.state.pending_military_base_type = 0;

        self.complete_military_proposal(proposal.to_value())
    }

    fn complete_military_proposal(&mut self, proposal: Value) -> DayResult {
        let original = self.state.pending_day_schedule.clone().unwrap_or_default();
        let remaining = original.after("milestones");
        self.state.pending_interaction.clear();
        self.state.pending_day_schedule = None;
        let mut result = self.run_day_schedule(remaining, false, false);

        if !result.ok {
            return result;
        }

        let mut applied = vec!["milestones".to_string()];
        applied.append(&mut result.applied);

        // a later result of the same name replaces the proposal at its position
        let later = std::mem::take(&mut result.phase_results);
        result.phase_results = vec![("military_proposal".to_string(), proposal)];

        for (name, value) in later {
            result.set_phase(&name, value);
        }

        result.schedule = Some(original);
        result.applied = applied;

        self.append_pending_disaster(result)
    }

    /// One disaster update.
    pub fn advance_disaster_tick(&mut self) -> DisasterMapResult {
        let mut span = TimingSpan::new();
        let mut result = self.timed_advance_disaster_tick();
        result.base.timing = span.finish();

        result
    }

    fn timed_advance_disaster_tick(&mut self) -> DisasterMapResult {
        if self.state.active_disaster_type == 0 {
            return DisasterMapResult::failed("no disaster is active");
        }

        let Randoms { random, lfsr, .. } = &mut *self.randoms;
        let mut result = disaster_map::run_all(
            self.city,
            Some(random),
            Some(lfsr),
            self.state.disaster_map_counter,
            self.state.disaster_hurricane_counter,
        );

        if !result.base.ok {
            return result;
        }

        self.state.disaster_map_counter = result.map_counter;
        self.state.disaster_hurricane_counter = result.hurricane_counter;
        let changes = result.connection_count_changes.clone();
        self.apply_connection_changes(&changes);

        let still_active = result.active || has_active_object(self.city);
        let mut ended_type = 0;

        if !still_active {
            ended_type = self.state.active_disaster_type;
            self.state.active_disaster_type = 0;
            self.state.disaster_map_counter = 0;
            self.state.disaster_hurricane_counter = 0;

            let finished = disaster_end::finish(self.city, ended_type);

            if !finished.ok {
                return DisasterMapResult::failed(finished.error);
            }

            result.base.news_items.extend(finished.news_items);
            result.map_changed = result.map_changed || finished.removed_units > 0;
            result.base.newspaper_requested = true;
            result.base.newspaper_paper = DISASTER_END_PAPER;

            if !self.city.set_misc_u32(misc::CITY_MODE, NORMAL_MODE) {
                return DisasterMapResult::failed("cannot restore city mode after the disaster");
            }
        }

        if let Err(error) = news::persist(self.city, &mut result.base) {
            return DisasterMapResult::failed(error);
        }

        result.active = still_active;
        result.disaster_type = if still_active {
            self.state.active_disaster_type
        } else {
            ended_type
        };
        result.ended_type = ended_type;
        result.base.complete = !still_active;

        result
    }

    /// SIMCITY.EXE 0x00406a50 enters disaster mode from normal mode only. It
    /// fixes the dispatch counts and removes the units of an earlier disaster.
    /// True when the city has no units, so the National Guard comes.
    fn begin_disaster_mode(&mut self) -> bool {
        if self.city.city_mode() == DISASTER_MODE {
            return false;
        }

        let (capacity, national_guard) = match dispatch::begin_disaster(self.city) {
            Ok(available) => (available.counts(), available.national_guard),
            Err(_) => (NO_CAPACITY, false),
        };
        self.state.dispatch_capacity = capacity;
        self.state.dispatch_epoch += 1;

        national_guard
    }

    /// The point that a Disasters or Debug menu item of SIMCITY.EXE gives a
    /// disaster (0x0040f5b0 to 0x0040f7b0 and 0x00412340 to 0x004124a0). Some
    /// items draw process random values; the first value is the Y coordinate.
    /// `fallback` is for the types without a menu item and for Air Crash and
    /// Hurricane, whose starts do not use the point.
    pub fn menu_disaster_point(&mut self, disaster_type: i64, fallback: Vec2i) -> Vec2i {
        let edge = self.city.map_size;
        let center = Vec2i::new(
            self.city.misc_u32(misc::CITY_CENTER_X) & 0xffff,
            self.city.misc_u32(misc::CITY_CENTER_Y) & 0xffff,
        );
        let random = &mut self.randoms.random;

        use disaster_start::{
            DISASTER_EARTHQUAKE, DISASTER_FIRE, DISASTER_FIRESTORM, DISASTER_FLOOD, DISASTER_MASS_FLOODS, DISASTER_MASS_RIOTS,
            DISASTER_MELTDOWN, DISASTER_MICROWAVE, DISASTER_MONSTER, DISASTER_RIOT, DISASTER_TORNADO, DISASTER_TOXIC_SPILL,
            DISASTER_VOLCANO,
        };

        match disaster_type {
            DISASTER_FIRE => {
                let y = random.next_u15() % 40 + center.y - 20;
                Vec2i::new(random.next_u15() % 40 + center.x - 20, y)
            }
            DISASTER_TORNADO | DISASTER_EARTHQUAKE | DISASTER_VOLCANO | DISASTER_MASS_FLOODS => {
                let y = random.next_u15() % (edge - 2) + 1;
                Vec2i::new(random.next_u15() % (edge - 2) + 1, y)
            }
            DISASTER_MONSTER | DISASTER_RIOT => {
                let y = (random.next_u15() & 0x1f) + center.y - 15;
                Vec2i::new((random.next_u15() & 0x1f) + center.x - 15, y)
            }
            DISASTER_FLOOD | DISASTER_TOXIC_SPILL | DISASTER_FIRESTORM | DISASTER_MASS_RIOTS => center,
            DISASTER_MELTDOWN | DISASTER_MICROWAVE => Vec2i::ZERO,
            _ => fallback,
        }
    }

    /// Start a disaster at `point`. SIMCITY.EXE also starts a disaster during
    /// another one (0x0045cf10): the new type replaces the active type, and
    /// the markers of both spread.
    pub fn start_disaster(&mut self, disaster_type: i64, point: Vec2i) -> Value {
        if self.state.day.terminal_state {
            return DisasterStartResult::failed("the game has ended").to_value();
        }

        if !self.state.pending_interaction.is_empty() {
            return DisasterStartResult::failed(format!("{} interaction is pending", self.state.pending_interaction)).to_value();
        }

        let mut started = self.start_disaster_phase(disaster_type, point);

        if !started.base.ok {
            return started.to_value();
        }

        if !started.started {
            if !started.base.complete {
                self.state.unsupported_disaster_type = disaster_type;
            }

            return started.to_value();
        }

        let changes = started.connection_count_changes.clone();
        self.apply_connection_changes(&changes);

        let previous = (
            self.state.active_disaster_type,
            self.state.disaster_map_counter,
            self.state.disaster_hurricane_counter,
        );
        self.state.active_disaster_type = disaster_type;

        // only a flood or a hurricane sets the counters. another start keeps them
        if started.map_counter != 0 {
            self.state.disaster_map_counter = started.map_counter;
        }

        if started.hurricane_counter != 0 {
            self.state.disaster_hurricane_counter = started.hurricane_counter;
        }

        self.state.unsupported_disaster_type = 0;

        if self.begin_disaster_mode() {
            national_guard_notice(&mut started.base);
        }

        if !self.city.set_misc_u32(misc::CITY_MODE, DISASTER_MODE) {
            (
                self.state.active_disaster_type,
                self.state.disaster_map_counter,
                self.state.disaster_hurricane_counter,
            ) = previous;

            return DisasterStartResult::failed("cannot store active disaster mode").to_value();
        }

        if let Err(error) = news::persist(self.city, &mut started.base) {
            return DisasterStartResult::failed(error).to_value();
        }

        // the original runs the first disaster update in the same step as the start
        let first_update = self.advance_disaster_tick();

        if !first_update.base.ok {
            return DisasterStartResult::failed(first_update.base.error).to_value();
        }

        let mut value = started.to_value();
        values::set(&mut value, "first_update", first_update.to_value());

        value
    }

    /// The mayor's house and its approval.
    pub fn recalculate_mayor_house(&mut self) -> mayor::MayorApprovalResult {
        let mut result = mayor::run(self.city, &mut self.randoms.random, self.state.day.mayor_approval);

        if result.base.ok {
            self.state.day.mayor_approval = result.approval;

            if let Err(error) = news::persist(self.city, &mut result.base) {
                return mayor::MayorApprovalResult::failed(error);
            }
        }

        result
    }

    /// Turn the runtime points with the map.
    pub fn rotate_runtime_coordinates(&mut self, counter_clockwise: bool) {
        let edge = EngineState::map_edge(self.city);

        if self.state.day.ship_home.x >= 0 && self.state.day.ship_home.y >= 0 {
            self.state.day.ship_home = rotate_point(self.state.day.ship_home, counter_clockwise, edge);
        }

        // the next launch step scans the rotated map
        self.state.arcology_launch_sites.clear();
        self.state.arcology_launch_wait = 0;

        if self.state.day.pending_disaster_type != 0 {
            self.state.day.pending_disaster_point = rotate_point(self.state.day.pending_disaster_point, counter_clockwise, edge);
        }
    }

    /// Run `steps` steps of a staged arcology launch.
    pub fn advance_arcology_launch(&mut self, steps: i64) -> annual::LaunchStepResult {
        let mut span = TimingSpan::new();
        let sites = self.state.arcology_launch_sites.clone();
        let mut result = annual::launch_step(self.city, &mut self.randoms.random, sites, self.state.arcology_launch_wait, steps);
        result.base.timing = span.finish();

        if !result.base.ok {
            return result;
        }

        self.state.arcology_launch_sites = result.sites.clone();
        self.state.arcology_launch_wait = result.wait;

        if result.base.complete {
            self.state.arcology_launch_active = false;
        }

        result
    }

    /// The original loads a city file, then scans power and water and counts
    /// the developed tiles. The power scan uses the process random state.
    pub fn initialize_loaded_city(&mut self) -> bool {
        let Some(scan) = load::initialize_loaded_city(self.city, &mut self.randoms.random) else {
            return false;
        };

        self.state.day.power_usage_percent = scan.power_usage_percent;
        self.state.day.water_usage_percent = scan.water_usage_percent;
        self.state.day.developed_tiles = scan.developed_tiles;

        true
    }

    /// Run a schedule, as the debug steps and the days do. `check_annual_budget`
    /// asks for the annual budget first when the year needs one.
    pub fn run_day_schedule(&mut self, schedule: DaySchedule, annual_budget_approved: bool, check_annual_budget: bool) -> DayResult {
        let mut span = TimingSpan::new();
        let mut result = self.execute_day_schedule(schedule, annual_budget_approved, check_annual_budget);
        let steps = result.timing.steps.clone();
        result.timing = span.finish();
        result.timing.steps = steps;

        if result
            .phase("annual_microsim")
            .is_some_and(|annual| values::boolean(annual, "arcology_launch_staged"))
        {
            self.state.arcology_launch_active = true;
        }

        result
    }

    /// Run the scheduled actions. The engine state crosses in and out.
    fn execute_day_schedule(&mut self, schedule: DaySchedule, annual_budget_approved: bool, check_annual_budget: bool) -> DayResult {
        // the original asks for the annual budget before it runs the day
        if check_annual_budget && budget::requires_annual_budget(self.city) {
            let funding = budget::funding_values(self.city);
            self.state.pending_interaction = "annual_budget".into();
            self.state.pending_day_schedule = Some(schedule.clone());

            return DayResult {
                ok: true,
                day: self.state.city_days,
                pending: schedule.actions.clone(),
                schedule: Some(schedule),
                interaction_requests: vec![InteractionRequest::annual_budget(funding)],
                complete: false,
                ..DayResult::default()
            };
        }

        let (outcome, day_state, scenario) = day::run_schedule(
            self.city,
            self.randoms,
            self.state.scenario.clone(),
            self.state.day.clone(),
            &schedule.to_sim(),
            annual_budget_approved,
            self.detailed,
        );

        self.state.day = day_state;

        if outcome.scenario_cleared {
            self.state.scenario = None;
        } else if let (Some(current), Some(updated)) = (self.state.scenario.as_mut(), scenario) {
            current.time_limit_months = updated.time_limit_months;
        }

        if !outcome.error.is_empty() {
            return DayResult::failure(outcome.error);
        }

        let mut requests = Vec::new();

        if !outcome.interaction.is_empty() {
            self.state.pending_interaction = outcome.interaction.clone();
            self.state.pending_day_schedule = Some(schedule.clone());
            requests.push(InteractionRequest::military_proposal());
        }

        DayResult {
            ok: true,
            day: self.state.city_days,
            schedule: Some(schedule),
            complete: outcome.pending.is_empty(),
            applied: outcome.applied,
            pending: outcome.pending,
            phase_results: outcome.phase_results,
            interaction_requests: requests,
            disaster_results: Vec::new(),
            timing: Timing::new(-1, outcome.timing.steps),
            error: String::new(),
        }
    }

    /// Start the disaster that the day left pending.
    pub fn append_pending_disaster(&mut self, mut result: DayResult) -> DayResult {
        if !result.ok || !result.interaction_requests.is_empty() || self.state.day.pending_disaster_type == 0 {
            return result;
        }

        let disaster_type = self.state.day.pending_disaster_type;
        self.state.day.pending_disaster_type = 0;

        if !self.city.set_misc_u32(misc::DISASTER_TYPE, 0) {
            return DayResult::failure("cannot clear the pending disaster type");
        }

        let point = self.state.day.pending_disaster_point;
        let mut started = self.start_disaster_phase(disaster_type, point);

        if !started.base.ok {
            return DayResult::failure(started.base.error);
        }

        if let Err(error) = news::persist(self.city, &mut started.base) {
            return DayResult::failure(error);
        }

        if started.started {
            let changes = started.connection_count_changes.clone();
            self.apply_connection_changes(&changes);
            self.state.active_disaster_type = disaster_type;
            self.state.disaster_map_counter = started.map_counter;
            self.state.disaster_hurricane_counter = started.hurricane_counter;

            if self.begin_disaster_mode() {
                national_guard_notice(&mut started.base);
            }

            if !self.city.set_misc_u32(misc::CITY_MODE, DISASTER_MODE) {
                return DayResult::failure("cannot store active disaster mode");
            }

            result.set_phase("disaster_start", started.to_value());
            result.applied.push("disaster_start".into());

            // the original runs the first disaster update in the same step as the start
            let first_update = self.advance_disaster_tick();

            if !first_update.base.ok {
                return DayResult::failure(first_update.base.error);
            }

            result.disaster_results.push(first_update.to_value());
        } else {
            result.set_phase("disaster_start", started.to_value());

            if !started.base.complete {
                self.state.unsupported_disaster_type = disaster_type;
                result.pending.push("disaster_start".into());
                result.complete = false;
            }
        }

        result
    }

    /// DisasterStartPhase.start and MaxisManResponse.apply.
    fn start_disaster_phase(&mut self, disaster_type: i64, point: Vec2i) -> DisasterStartResult {
        let scenario = self.state.scenario.is_some();
        let Randoms { random, lfsr, .. } = &mut *self.randoms;
        let mut started = disaster_start::start(self.city, disaster_type, point, Some(&mut *random), Some(&mut *lfsr), scenario);

        if !started.base.ok || !started.started {
            return started;
        }

        let arrival = disaster_end::maxis_man_response(self.city, started.point, started.disaster_type, started.record, random, lfsr);

        if let Some(arrival) = arrival {
            started.base.sound_events.push(SoundEvent::new(MAXIS_MAN_ARRIVAL_SOUND));
            started.base.view_center_requests.push(arrival.point);
            started.maxis_man_response = Some(arrival);
        }

        started
    }
}

/// SIMCITY.EXE 0x0044f910 plays sound 513 and shows notice 119 with picture
/// 406 when the city has no police, fire, or military units at a disaster start.
fn national_guard_notice(base: &mut PhaseBase) {
    base.sound_events.push(SoundEvent::new(NATIONAL_GUARD_SOUND));
    base.notice_ids.0.push(NATIONAL_GUARD_NOTICE);
}

/// The measured time of a day with the steps of its schedule, and the
/// remaining time as "day setup and events".
fn with_measured_timing(mut result: DayResult, span: &mut TimingSpan) -> DayResult {
    if result.ok {
        let scheduled = result.timing.clone();
        let mut measured = span.finish();
        measured.steps = scheduled.steps;
        let setup = (measured.work_usec - scheduled.work_usec).max(0);
        measured.steps.set("day setup and events", setup);
        result.timing = measured;
    }

    result
}

/// A monster, a tornado, an explosion, or a crashing airplane keeps a
/// disaster active.
fn has_active_object(city: &City) -> bool {
    let data = match city.chunk("XTHG") {
        Some(chunk) if chunk.data.len() as i64 == city.decoded_size("XTHG") => chunk.data.as_slice(),
        _ => return false,
    };

    for record in 1..things::count(data) {
        checkpoint();
        let kind = things::field(data, record, things::FIELD_TYPE);

        if kind == things::TYPE_MONSTER || kind == things::TYPE_TORNADO || kind == things::TYPE_EXPLOSION {
            return true;
        }

        if kind == things::TYPE_AIRPLANE && things::field(data, record, things::FIELD_STATE) == CRASHING_AIRPLANE_STATE {
            return true;
        }
    }

    false
}

fn rotate_point(point: Vec2i, counter_clockwise: bool, edge: i64) -> Vec2i {
    if counter_clockwise {
        Vec2i::new(point.y, edge - 1 - point.x)
    } else {
        Vec2i::new(edge - 1 - point.y, point.x)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use sc2k_sim::sim::new_city::{city_of, template};
    use sc2k_sim::sim::random::SimRandom;

    const SEED: i64 = 77;

    /// The menu point of `disaster_type` on a 128-tile city with its center at (40, 50).
    fn menu_point(disaster_type: i64) -> (Vec2i, i64) {
        let mut city = city_of(&template::empty_city(128));
        assert!(city.set_misc_u32(misc::CITY_CENTER_X, 40) && city.set_misc_u32(misc::CITY_CENTER_Y, 50));

        let mut randoms = Randoms::new(SEED, 1, 1);
        let mut state = EngineState::default();
        let mut engine = Engine {
            city: &mut city,
            randoms: &mut randoms,
            state: &mut state,
            detailed: false,
        };
        let point = engine.menu_disaster_point(disaster_type, Vec2i::new(1, 2));

        (point, randoms.random.state)
    }

    #[test]
    fn each_menu_item_selects_its_own_place() {
        let mut random = SimRandom::new(SEED);
        let y = random.next_u15() % 126 + 1;
        let x = random.next_u15() % 126 + 1;

        for disaster_type in [disaster_start::DISASTER_EARTHQUAKE, disaster_start::DISASTER_TORNADO] {
            assert_eq!(menu_point(disaster_type), (Vec2i::new(x, y), random.state));
        }

        let mut random = SimRandom::new(SEED);
        let y = (random.next_u15() & 0x1f) + 50 - 15;
        let x = (random.next_u15() & 0x1f) + 40 - 15;
        assert_eq!(menu_point(disaster_start::DISASTER_MONSTER), (Vec2i::new(x, y), random.state));

        let unused = SimRandom::new(SEED).state;
        assert_eq!(menu_point(disaster_start::DISASTER_FLOOD), (Vec2i::new(40, 50), unused));
        assert_eq!(menu_point(disaster_start::DISASTER_MELTDOWN), (Vec2i::ZERO, unused));
        assert_eq!(menu_point(disaster_start::DISASTER_PLANE_CRASH), (Vec2i::new(1, 2), unused));
    }

    /// The notice IDs of a monster start on a 128-tile city with
    /// `police_tiles` police station tiles, and whether a second start of
    /// disaster mode would show the notice again.
    fn monster_notices(police_tiles: i64) -> (Vec<i32>, bool) {
        let mut city = city_of(&template::empty_city(128));
        let police_count = misc::TILE_COUNTS + sc2k_sim::sim::ids::building_tile_ids::POLICE_STATION * 4;
        assert!(city.set_misc_u32(police_count, police_tiles));

        let mut randoms = Randoms::new(SEED, 1, 1);
        let mut state = EngineState::for_city(&city);
        let mut engine = Engine {
            city: &mut city,
            randoms: &mut randoms,
            state: &mut state,
            detailed: false,
        };
        let started = engine.start_disaster(disaster_start::DISASTER_MONSTER, Vec2i::new(20, 20));
        assert!(values::boolean(&started, "ok") && values::boolean(&started, "started"));

        (values::ints(&started, "notice_ids"), engine.begin_disaster_mode())
    }

    #[test]
    fn the_national_guard_comes_to_a_city_without_units() {
        assert_eq!(
            monster_notices(0),
            (vec![NATIONAL_GUARD_NOTICE], false),
            "only the start of disaster mode shows it"
        );
        assert_eq!(
            monster_notices(8).0,
            Vec::<i32>::new(),
            "one police unit keeps the National Guard away"
        );
    }
}
