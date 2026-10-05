//! The results of the engine and the speed controller, as the script classes
//! SimulationDayResult, SimulationInteractionRequest and SimulationTickResult.

use crate::clock::DaySchedule;
use sc2k_sim::sim::events::Timing;
use sc2k_sim::sim::geom::Vec2i;
use sc2k_sim::sim::value::{Ints32, Strings, ToValue, Value};

/// The notice of a military base proposal.
const MILITARY_PROPOSAL_NOTICE: i64 = 0xf0;

/// A question that stops the simulation until the player answers.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct InteractionRequest {
    pub kind: String,
    pub funding_values: Vec<i32>,
    pub auto_budget: bool,
    pub notification_id: i64,
}

impl InteractionRequest {
    pub fn new(kind: &str) -> Self {
        Self {
            kind: kind.to_string(),
            ..Self::default()
        }
    }

    pub fn annual_budget(values: Vec<i32>) -> Self {
        Self {
            funding_values: values,
            ..Self::new("annual_budget")
        }
    }

    pub fn military_proposal() -> Self {
        Self {
            notification_id: MILITARY_PROPOSAL_NOTICE,
            ..Self::new("military_proposal")
        }
    }
}

impl ToValue for InteractionRequest {
    fn to_value(&self) -> Value {
        Value::Object(
            "SimulationInteractionRequest",
            vec![
                ("type", Value::Str(self.kind.clone())),
                ("funding_values", Ints32(self.funding_values.clone()).to_value()),
                ("auto_budget", Value::Bool(self.auto_budget)),
                ("notification_id", Value::Int(self.notification_id)),
            ],
        )
    }
}

/// The work of one day, or of the rest of a day after an answer.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct DayResult {
    pub ok: bool,
    pub error: String,
    pub day: i64,
    pub schedule: Option<DaySchedule>,
    pub applied: Vec<String>,
    pub pending: Vec<String>,
    /// The results of the day phases, by phase name, in completion order.
    pub phase_results: Vec<(String, Value)>,
    pub interaction_requests: Vec<InteractionRequest>,
    /// The first disaster update, when a disaster starts after the day.
    pub disaster_results: Vec<Value>,
    pub complete: bool,
    pub timing: Timing,
}

impl DayResult {
    pub fn failure(message: impl Into<String>) -> Self {
        Self {
            error: message.into(),
            ..Self::default()
        }
    }

    pub fn phase(&self, name: &str) -> Option<&Value> {
        self.phase_results.iter().find(|(key, _)| key == name).map(|(_, value)| value)
    }

    /// Set the result of `name`. An existing name keeps its position.
    pub fn set_phase(&mut self, name: &str, value: Value) {
        match self.phase_results.iter_mut().find(|(key, _)| key == name) {
            Some(slot) => slot.1 = value,
            None => self.phase_results.push((name.to_string(), value)),
        }
    }
}

impl ToValue for DayResult {
    fn to_value(&self) -> Value {
        let phases = Value::Dict(
            self.phase_results
                .iter()
                .map(|(name, value)| (Value::Str(name.clone()), value.clone()))
                .collect(),
        );

        Value::Object(
            "SimulationDayResult",
            vec![
                ("ok", Value::Bool(self.ok)),
                ("error", Value::Str(self.error.clone())),
                ("day", Value::Int(self.day)),
                ("schedule", self.schedule.to_value()),
                ("applied", Strings(self.applied.clone()).to_value()),
                ("pending", Strings(self.pending.clone()).to_value()),
                ("phase_results", phases),
                ("interaction_requests", self.interaction_requests.to_value()),
                ("disaster_results", Value::Array(self.disaster_results.clone())),
                ("complete", Value::Bool(self.complete)),
                ("timing", self.timing.to_value()),
            ],
        )
    }
}

/// The work of one call of the speed controller.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct TickResult {
    pub ok: bool,
    pub error: String,
    pub base_ticks: i64,
    pub moving_results: Vec<Value>,
    pub disaster_results: Vec<Value>,
    pub launch_results: Vec<Value>,
    pub day_results: Vec<Value>,
    pub news_items: Vec<Value>,
    pub effect_events: Vec<Value>,
    pub sound_events: Vec<Value>,
    pub view_center_requests: Vec<Value>,
    pub refresh_requests: Vec<String>,
    pub interaction_requests: Vec<Value>,
    pub game_over_events: Vec<Value>,
    pub music_track_requests: Vec<i32>,
    pub notice_ids: Vec<i32>,
    pub newspaper_requested: bool,
    /// -1 opens the saved newspaper choice.
    pub newspaper_paper: i64,
    pub pending_actions: Vec<String>,
    pub paused_on_target_day: bool,
    /// True when a disaster start dropped African Swallow to Cheetah.
    pub disaster_slowed: bool,
}

impl TickResult {
    pub fn new() -> Self {
        Self {
            newspaper_paper: -1,
            ..Self::default()
        }
    }
}

impl ToValue for TickResult {
    fn to_value(&self) -> Value {
        let strings = |items: &[String]| Value::Array(items.iter().map(|item| Value::Str(item.clone())).collect());

        Value::Object(
            "SimulationTickResult",
            vec![
                ("ok", Value::Bool(self.ok)),
                ("error", Value::Str(self.error.clone())),
                ("base_ticks", Value::Int(self.base_ticks)),
                ("moving_results", Value::Array(self.moving_results.clone())),
                ("disaster_results", Value::Array(self.disaster_results.clone())),
                ("launch_results", Value::Array(self.launch_results.clone())),
                ("day_results", Value::Array(self.day_results.clone())),
                ("news_items", Value::Array(self.news_items.clone())),
                ("effect_events", Value::Array(self.effect_events.clone())),
                ("sound_events", Value::Array(self.sound_events.clone())),
                ("view_center_requests", Value::Array(self.view_center_requests.clone())),
                ("refresh_requests", strings(&self.refresh_requests)),
                ("interaction_requests", Value::Array(self.interaction_requests.clone())),
                ("game_over_events", Value::Array(self.game_over_events.clone())),
                ("music_track_requests", Value::Ints32(self.music_track_requests.clone())),
                ("notice_ids", Value::Ints32(self.notice_ids.clone())),
                ("newspaper_requested", Value::Bool(self.newspaper_requested)),
                ("newspaper_paper", Value::Int(self.newspaper_paper)),
                ("pending_actions", Strings(self.pending_actions.clone()).to_value()),
                ("paused_on_target_day", Value::Bool(self.paused_on_target_day)),
                ("disaster_slowed", Value::Bool(self.disaster_slowed)),
            ],
        )
    }
}

/// A point request as a value.
pub fn point(point: Vec2i) -> Value {
    Value::Vec2i(point)
}
