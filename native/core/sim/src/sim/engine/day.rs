//! One scheduled day, as SimulationDaySchedule, SimulationDayPhases, and the
//! day phase classes. The engine state crosses in and out as EngineState.

use crate::sim::city::City;
use crate::sim::civic::scenario::{self, Scenario};
use crate::sim::civic::{annual, education, mayor, milestones, nation};
use crate::sim::data_maps;
use crate::sim::disasters::weather;
use crate::sim::economy::{self, budget, city_value};
use crate::sim::engine::month;
use crate::sim::events::Timing;
use crate::sim::geom::Vec2i;
use crate::sim::growth::{self, aftermath, demand};
use crate::sim::ids::sc2misc_layout as misc_layout;
use crate::sim::infrastructure::{power, traffic, water};
use crate::sim::phase::{PhaseBase, PhaseResultLike, PlainPhaseResult, TimingSpan};
use crate::sim::random::{Randoms, SimRandom};
use crate::sim::reports::{graphs, news};
use crate::sim::value::{Strings, ToValue, Value};

/// SimulationPhaseContext.ENGINE_STATE.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct EngineState {
    pub developed_tiles: i64,
    pub power_usage_percent: i64,
    pub water_usage_percent: i64,
    pub bus_passengers: i64,
    pub rail_passengers: i64,
    pub subway_passengers: i64,
    pub ship_home: Vec2i,
    pub city_status_resource_id: i64,
    pub commerce_connections: i64,
    pub industry_connections: i64,
    pub mayor_approval: i64,
    pub midi_playback_active: bool,
    pub pending_disaster_type: i64,
    pub pending_disaster_point: Vec2i,
    pub terminal_state: bool,
    pub traffic_news_deadline_msec: i64,
    /// True when an arcology launch demolishes the arcologies in timed
    /// batches after the annual update. False keeps the original launch.
    pub stage_arcology_launch: bool,
}

impl ToValue for EngineState {
    fn to_value(&self) -> Value {
        let fields = [
            ("developed_tiles", Value::Int(self.developed_tiles)),
            ("power_usage_percent", Value::Int(self.power_usage_percent)),
            ("water_usage_percent", Value::Int(self.water_usage_percent)),
            ("bus_passengers", Value::Int(self.bus_passengers)),
            ("rail_passengers", Value::Int(self.rail_passengers)),
            ("subway_passengers", Value::Int(self.subway_passengers)),
            ("ship_home", Value::Vec2i(self.ship_home)),
            ("city_status_resource_id", Value::Int(self.city_status_resource_id)),
            ("commerce_connections", Value::Int(self.commerce_connections)),
            ("industry_connections", Value::Int(self.industry_connections)),
            ("mayor_approval", Value::Int(self.mayor_approval)),
            ("midi_playback_active", Value::Bool(self.midi_playback_active)),
            ("pending_disaster_type", Value::Int(self.pending_disaster_type)),
            ("pending_disaster_point", Value::Vec2i(self.pending_disaster_point)),
            ("terminal_state", Value::Bool(self.terminal_state)),
            ("traffic_news_deadline_msec", Value::Int(self.traffic_news_deadline_msec)),
            ("stage_arcology_launch", Value::Bool(self.stage_arcology_launch)),
        ];

        Value::Dict(
            fields
                .into_iter()
                .map(|(name, value)| (Value::Str(name.to_string()), value))
                .collect(),
        )
    }
}

/// SimulationSchedule.
#[derive(Clone, Debug, Default)]
pub struct Schedule {
    pub city_days: i64,
    pub month_day: i64,
    pub season: i64,
    pub actions: Vec<String>,
    pub growth_step: i64,
    pub growth_substep: i64,
}

/// The day result fields that the GDScript SimulationDayResult receives.
#[derive(Default)]
pub struct DayOutcome {
    pub error: String,
    pub applied: Vec<String>,
    pub pending: Vec<String>,
    pub phase_results: Vec<(String, Value)>,
    pub interaction: String,
    pub scenario_cleared: bool,
    pub timing: Timing,
}

impl DayOutcome {
    fn failure(message: impl Into<String>) -> Self {
        Self {
            error: message.into(),
            ..Default::default()
        }
    }
}

/// What a phase reports to the schedule, as the PhaseResult that SimulationDayPhase.run returns.
struct PhaseOutcome {
    ok: bool,
    error: String,
    complete: bool,
    game_over: bool,
    terminal: bool,
}

impl PhaseOutcome {
    fn of(base: &PhaseBase) -> Self {
        Self {
            ok: base.ok,
            error: base.error.clone(),
            complete: base.complete,
            game_over: !base.game_over_events.is_empty(),
            terminal: base.game_over_events.iter().any(|event| event.is_terminal()),
        }
    }

    fn failed(message: impl Into<String>) -> Self {
        Self {
            ok: false,
            error: message.into(),
            complete: true,
            game_over: false,
            terminal: false,
        }
    }
}

/// SimulationPhaseContext.
struct Context<'a> {
    city: &'a mut City,
    randoms: &'a mut Randoms,
    scenario: Option<Scenario>,
    state: EngineState,
    schedule: &'a Schedule,
    annual_budget_approved: bool,
    detailed: bool,
    action: String,
    phase_results: Vec<(String, Value)>,
    rci_demand: Option<(i64, i64)>,
    interaction: String,
    span: TimingSpan,
}

impl Context<'_> {
    /// SimulationPhaseContext.record: persist the stories, then keep the result.
    /// An existing name keeps its position, as a Dictionary assignment.
    fn record<T: PhaseResultLike>(&mut self, name: &str, result: &mut T) -> Result<(), String> {
        news::persist(self.city, result.base_mut())?;
        let value = result.to_value();

        match self.phase_results.iter_mut().find(|(existing, _)| existing == name) {
            Some(slot) => slot.1 = value,
            None => self.phase_results.push((name.to_string(), value)),
        }

        Ok(())
    }

    /// Record `result` and report it, or report the phase failure.
    fn finish<T: PhaseResultLike>(&mut self, name: &str, mut result: T) -> PhaseOutcome {
        if !result.base().ok {
            return PhaseOutcome::of(result.base());
        }

        match self.record(name, &mut result) {
            Ok(()) => PhaseOutcome::of(result.base()),
            Err(message) => PhaseOutcome::failed(message),
        }
    }
}

/// SimulationDaySchedule._execute_day_schedule.
pub fn run_schedule(
    city: &mut City,
    randoms: &mut Randoms,
    scenario: Option<Scenario>,
    state: EngineState,
    schedule: &Schedule,
    annual_budget_approved: bool,
    detailed: bool,
) -> (DayOutcome, EngineState, Option<Scenario>) {
    let mut span = TimingSpan::new();

    // Extended cities correct their tile counts before the budget reads them.
    if schedule.month_day == 0 && city.is_extended() {
        span.mark("tile recount");

        if mayor::recount_tiles(city) < 0 {
            return (DayOutcome::failure("cannot store the tile counts"), state, scenario);
        }
    }

    // The supplied executable rebuilds the city value only before a bond
    // issue, so the saved value and the Bonds advisor go stale. As sc2kfix
    // does, the value is rebuilt at the start of every day.
    span.mark("city value");
    city_value::run(city);

    let mut context = Context {
        city,
        randoms,
        scenario,
        state,
        schedule,
        annual_budget_approved,
        detailed,
        action: String::new(),
        phase_results: Vec::new(),
        rci_demand: None,
        interaction: String::new(),
        span,
    };
    let mut outcome = DayOutcome::default();

    for (position, action) in schedule.actions.iter().enumerate() {
        context.span.mark(action);
        crate::sim::budget::checkpoint();

        if !is_known(action) || !is_ready(&context, action) {
            outcome.pending.push(action.clone());
            continue;
        }

        context.action = action.clone();
        let result = run_phase(&mut context, action);

        if result.ok && result.game_over {
            context.state.terminal_state = context.state.terminal_state || result.terminal;
            context.scenario = None;
            outcome.scenario_cleared = true;
        }

        if !result.ok {
            let failed = DayOutcome::failure(result.error);

            return (failed, context.state, context.scenario);
        }

        if !context.interaction.is_empty() {
            outcome.pending.push(action.clone());
            outcome.pending.extend(schedule.actions[position + 1..].iter().cloned());
            outcome.interaction = context.interaction.clone();
            outcome.phase_results = std::mem::take(&mut context.phase_results);
            outcome.timing = context.span.finish();

            return (outcome, context.state, context.scenario);
        }

        if result.complete {
            outcome.applied.push(action.clone());
        } else {
            outcome.pending.push(action.clone());
        }
    }

    outcome.phase_results = std::mem::take(&mut context.phase_results);
    outcome.timing = context.span.finish();

    (outcome, context.state, context.scenario)
}

fn is_known(action: &str) -> bool {
    matches!(
        action,
        "month_start"
            | "budget"
            | "power"
            | "growth"
            | "pollution_terrain_land_value"
            | "water"
            | "traffic"
            | "rci_demand"
            | "education_health"
            | "graphs"
            | "milestones"
            | "scenario"
            | "bankruptcy"
            | "statistics_windows"
            | "map"
            | "simnation"
            | "weather_disaster"
    )
}

fn is_ready(context: &Context, action: &str) -> bool {
    if action != "graphs" {
        return true;
    }

    context.state.developed_tiles >= 0 && context.state.power_usage_percent >= 0 && context.state.water_usage_percent >= 0
}

fn run_phase(context: &mut Context, action: &str) -> PhaseOutcome {
    match action {
        "month_start" => {
            let result = month::month_start(context.city);
            context.finish(action, result)
        }
        "budget" => run_budget(context),
        "power" => run_power(context),
        "growth" => run_growth(context),
        "pollution_terrain_land_value" => {
            let scan = if context.city.full_resolution_maps() {
                data_maps::native::run_land_value_and_crime(context.city)
            } else {
                data_maps::coarse::run(context.city)
            };
            let developed = scan.developed_tiles;
            let outcome = context.finish(action, scan);

            if outcome.ok {
                context.state.developed_tiles = developed;
            }

            outcome
        }
        "water" => {
            let result = water::run(context.city);
            let usage = result.usage_percent;
            let outcome = context.finish(action, result);

            if outcome.ok {
                context.state.water_usage_percent = usage;
            }

            outcome
        }
        "traffic" => {
            let result = traffic::run(context.city);
            context.finish(action, result)
        }
        "rci_demand" => run_rci_demand(context),
        "education_health" => run_education_health(context),
        "graphs" => {
            let state = &context.state;
            let result = graphs::run(
                context.city,
                state.developed_tiles,
                state.power_usage_percent,
                state.water_usage_percent,
            );
            context.finish(action, result)
        }
        "milestones" => {
            let result = milestones::run(context.city);
            let pending = result.military_proposal_pending;
            let outcome = context.finish(action, result);

            if outcome.ok && pending {
                context.interaction = "military_proposal".to_string();
            }

            outcome
        }
        "scenario" => {
            let result = scenario::run(context.city, context.scenario.as_mut());
            context.finish(action, result)
        }
        "bankruptcy" => {
            let result = economy::bankruptcy(context.city);
            context.finish(action, result)
        }
        "statistics_windows" => refresh(context, action, &["population", "industries", "graphs"]),
        "map" => refresh(context, action, &["toolbar", "map"]),
        "simnation" => refresh(context, action, &["simnation"]),
        "weather_disaster" => run_weather(context),
        _ => PhaseOutcome::failed("the phase does nothing"),
    }
}

fn refresh(context: &mut Context, action: &str, requests: &[&str]) -> PhaseOutcome {
    let result = PlainPhaseResult::refreshing(requests);
    context.finish(action, result)
}

/// The budget day phase. The original settles the year, runs the annual
/// facility update, and then does the monthly budget work.
fn run_budget(context: &mut Context) -> PhaseOutcome {
    let action = context.action.clone();
    let mut settlement = budget::settle_year(context.city, context.annual_budget_approved);

    if !settlement.base.ok {
        return PhaseOutcome::of(&settlement.base);
    }

    if settlement.requires_annual_budget {
        return match context.record(&action, &mut settlement) {
            Ok(()) => PhaseOutcome::of(&settlement.base),
            Err(message) => PhaseOutcome::failed(message),
        };
    }

    let mut annual_complete = true;

    if settlement.settled_year {
        context.span.mark("annual_microsim");
        measure_unknown_utilities(context);
        let state = context.state.clone();
        let Randoms { random, lfsr, game } = &mut *context.randoms;
        let mut inputs = annual::AnnualInputs {
            bus_passengers: state.bus_passengers,
            rail_passengers: state.rail_passengers,
            subway_passengers: state.subway_passengers,
            random: Some(random),
            lfsr: Some(lfsr),
            game: Some(game),
            power_usage_percent: state.power_usage_percent,
            water_usage_percent: state.water_usage_percent,
            australian_locale: false,
            mayor_approval: state.mayor_approval,
            stage_launch: state.stage_arcology_launch,
        };
        let mut annual_result = annual::run(context.city, &mut inputs);

        if !annual_result.base.ok {
            return PhaseOutcome::of(&annual_result.base);
        }

        if let Err(message) = context.record("annual_microsim", &mut annual_result) {
            return PhaseOutcome::failed(message);
        }

        annual_complete = annual_result.base.complete;
        context.state.bus_passengers = 0;
        context.state.rail_passengers = 0;
        context.state.subway_passengers = 0;
        context.span.mark(&action);
    }

    let mut result = budget::run_month(context.city, &mut context.randoms.random, &settlement);

    if !result.base.ok {
        return PhaseOutcome::of(&result.base);
    }

    // A completed annual update completes the budget action.
    result.base.complete = annual_complete;

    match context.record(&action, &mut result) {
        Ok(()) => PhaseOutcome::of(&result.base),
        Err(message) => PhaseOutcome::failed(message),
    }
}

fn measure_unknown_utilities(context: &mut Context) {
    measure_utilities(context.city, &context.randoms.random, &mut context.state);
}

/// The original scans power and then water when it loads a city. After a load,
/// the engine has no value until the first scheduled scan. Scan a copy here so
/// that the city and its random state do not change.
fn measure_utilities(city: &City, random: &SimRandom, state: &mut EngineState) {
    if state.power_usage_percent >= 0 && state.water_usage_percent >= 0 {
        return;
    }

    let mut copy = city.clone();

    if state.power_usage_percent < 0 {
        let mut random = SimRandom::new(random.state);
        let power = power::run(&mut copy, &mut random);

        if power.base.ok {
            state.power_usage_percent = power.usage_percent;
        }
    }

    if state.water_usage_percent < 0 {
        let water = water::run(&mut copy);

        if water.base.ok {
            state.water_usage_percent = water.usage_percent;
        }
    }
}

/// The status part of SIMCITY.EXE 0x00471bc0. The original also runs that
/// routine when the city enters normal mode (0x00406a50): when a city opens,
/// when a new city starts, and when a disaster ends. This check skips the
/// random disaster, adds no newspaper story, and changes neither the city nor
/// its random state.
pub fn refresh_city_status(city: &City, random: &SimRandom, state: &mut EngineState) {
    if !city.misc.present || city.misc.data.len() as i64 != misc_layout::SIZE {
        return;
    }

    measure_utilities(city, random, state);
    let status_index = weather::status_index(
        &city.misc.data,
        &mut SimRandom::new(random.state),
        state.power_usage_percent.max(0),
        state.water_usage_percent.max(0),
        state.commerce_connections & 0xffff,
        state.industry_connections & 0xffff,
        city.map_size,
    );
    state.city_status_resource_id = monthly_resource(status_index, city.weather_type());
}

fn run_power(context: &mut Context) -> PhaseOutcome {
    let action = context.action.clone();
    let mut result = power::run(context.city, &mut context.randoms.random);

    if !result.base.ok {
        return PhaseOutcome::of(&result.base);
    }

    if let Err(message) = context.record(&action, &mut result) {
        return PhaseOutcome::failed(message);
    }

    context.state.power_usage_percent = result.usage_percent;

    // Per-tile maps move pollution and service coverage from the data-map day
    // to here. They need the new powered flags and nothing from day 3.
    if !context.city.full_resolution_maps() {
        return PhaseOutcome::of(&result.base);
    }

    context.span.mark("pollution_coverage");
    let coverage = data_maps::native::run_pollution_and_coverage(context.city);
    let stored = context.finish("pollution_coverage", coverage);

    if !stored.ok {
        return stored;
    }

    PhaseOutcome::of(&result.base)
}

fn run_growth(context: &mut Context) -> PhaseOutcome {
    let action = context.action.clone();
    crate::sim::budget::checkpoint();
    let (step, substep) = (context.schedule.growth_step, context.schedule.growth_substep);
    let mut result = growth::run(context.city, context.randoms, step, substep, context.detailed);

    if !result.base.ok {
        return PhaseOutcome::of(&result.base);
    }

    if let Err(message) = context.record(&action, &mut result) {
        return PhaseOutcome::failed(message);
    }

    let state = &mut context.state;
    state.bus_passengers = (state.bus_passengers + result.bus_passengers) & 0xffff_ffff;
    state.rail_passengers = (state.rail_passengers + result.rail_passengers) & 0xffff_ffff;
    state.subway_passengers = (state.subway_passengers + result.subway_passengers) & 0xffff_ffff;

    if result.ship_home_found {
        state.ship_home = result.ship_home;
    }

    if result.spawned_helicopters > 0 {
        state.traffic_news_deadline_msec = 0;
    }

    PhaseOutcome::of(&result.base)
}

fn run_rci_demand(context: &mut Context) -> PhaseOutcome {
    let action = context.action.clone();
    let mut music_span = TimingSpan::new();
    music_span.mark("music choice");
    let playback_was_active = context.state.midi_playback_active;
    let speed = context.city.simulation_speed();
    let selected = if playback_was_active {
        -1
    } else {
        month::monthly_track(speed, playback_was_active, &mut context.randoms.random)
    };
    let mut requests = Vec::new();

    if selected >= month::FIRST_TRACK_ID {
        requests.push(selected as i32);

        if context.city.music_enabled() {
            context.state.midi_playback_active = true;
        }
    }

    let mut music = month::music_result(playback_was_active, requests);

    if let Err(message) = context.record("music", &mut music) {
        return PhaseOutcome::failed(message);
    }

    let music_timing = music_span.finish();
    let mut result = demand::rci_demand(context.city);

    if !result.base.ok {
        return PhaseOutcome::of(&result.base);
    }

    // The music choice runs first in the demand action. Show it as the first demand step.
    let mut steps = music_timing.steps.clone();

    for (label, value) in &result.base.timing.steps.0 {
        if !steps.has(label) {
            steps.set(label, *value);
        }
    }

    result.base.timing = Timing::new(result.base.timing.work_usec + music_timing.work_usec, steps);
    context.rci_demand = Some((result.normal_population, result.previous_population));

    if let Err(message) = context.record(&action, &mut result) {
        return PhaseOutcome::failed(message);
    }

    context.span.mark("rci_aftermath");
    let aftermath = aftermath::run(context.city, &mut context.randoms.random, context.schedule.season);
    context.finish("rci_aftermath", aftermath)
}

fn run_education_health(context: &mut Context) -> PhaseOutcome {
    let action = context.action.clone();
    context.span.mark("simnation calculation");
    let nation = nation::run(context.city, &mut context.randoms.random);
    let stored = context.finish("simnation", nation);

    if !stored.ok {
        return stored;
    }

    let (normal, previous) = context.rci_demand.unwrap_or((0, 0));
    let population_growth = (normal - previous).max(0);
    context.span.mark("industries");
    let industries = {
        let Randoms { random, lfsr, .. } = &mut *context.randoms;
        demand::industry(context.city, random, lfsr, population_growth)
    };
    let stored = context.finish("industries", industries);

    if !stored.ok {
        return stored;
    }

    context.span.mark("education_health");
    let demographics = education::run(context.city, &mut context.randoms.random);
    context.finish(&action, demographics)
}

/// CityStatusMessages.monthly_resource.
fn monthly_resource(status_index: i64, weather_trend: i64) -> i64 {
    const NEED_FIRST: i64 = 265;
    const NEED_COUNT: i64 = 15;
    const WARNING_FIRST: i64 = 281;
    const WEATHER_COUNT: i64 = 12;

    if (0..NEED_COUNT).contains(&status_index) {
        return NEED_FIRST + status_index;
    }

    if status_index == weather::STATUS_WEATHER && (9..WEATHER_COUNT).contains(&weather_trend) {
        return WARNING_FIRST + weather_trend - 9;
    }

    0
}

fn run_weather(context: &mut Context) -> PhaseOutcome {
    let action = context.action.clone();
    let state = context.state.clone();
    let result = {
        let Randoms { random, lfsr, .. } = &mut *context.randoms;
        weather::run(
            context.city,
            random,
            lfsr,
            state.power_usage_percent,
            state.water_usage_percent,
            state.commerce_connections,
            state.industry_connections,
            state.pending_disaster_point,
        )
    };
    let status_index = result.status_index;
    let disaster_type = result.disaster_type;
    let disaster_point = result.disaster_point;
    let stored = context.finish(&action, result);

    if !stored.ok {
        return stored;
    }

    context.state.city_status_resource_id = monthly_resource(status_index, context.city.weather_type());

    if disaster_type != 0 {
        context.state.pending_disaster_type = disaster_type;
        context.state.pending_disaster_point = disaster_point;
    }

    stored
}

impl ToValue for DayOutcome {
    fn to_value(&self) -> Value {
        let phase_results = Value::Dict(
            self.phase_results
                .iter()
                .map(|(name, value)| (Value::Str(name.clone()), value.clone()))
                .collect(),
        );
        let fields = [
            ("ok", Value::Bool(self.error.is_empty())),
            ("error", Value::Str(self.error.clone())),
            ("applied", Strings(self.applied.clone()).to_value()),
            ("pending", Strings(self.pending.clone()).to_value()),
            ("phase_results", phase_results),
            ("interaction", Value::Str(self.interaction.clone())),
            ("scenario_cleared", Value::Bool(self.scenario_cleared)),
            ("timing", self.timing.to_value()),
        ];

        Value::Dict(
            fields
                .into_iter()
                .map(|(name, value)| (Value::Str(name.to_string()), value))
                .collect(),
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sim::bytes::{read_i32_be, write_u32_be};
    use crate::sim::ids::building_tile_ids as tiles;
    use crate::sim::ids::sc2misc_layout as misc_layout;
    use crate::sim::testing::empty_city;

    #[test]
    fn every_day_rebuilds_the_saved_city_value() {
        for edge in [128, 256] {
            let mut city = empty_city(edge);
            let misc = city.misc.mutate();
            write_u32_be(misc, misc_layout::TILE_COUNTS + tiles::ROAD_STRAIGHT_1 * 4, 40);
            write_u32_be(misc, misc_layout::CITY_VALUE, 12345);
            let mut randoms = Randoms::new(1, 1, 1);
            let schedule = Schedule {
                month_day: 7,
                ..Default::default()
            };
            let (outcome, _, _) = run_schedule(&mut city, &mut randoms, None, EngineState::default(), &schedule, false, false);

            assert!(outcome.error.is_empty(), "{}", outcome.error);
            assert_eq!(read_i32_be(&city.misc.data, misc_layout::CITY_VALUE), 400, "map edge {edge}");
        }
    }
}
