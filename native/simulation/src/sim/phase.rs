//! Common phase results and measured work time.

use std::time::Instant;

use super::events::{EffectEvent, GameOverEvent, NewsEvent, SoundEvent, Timing};
use super::geom::Vec2i;
use super::value::{Ints32, OrderedMap, ToValue, Value};

/// The PhaseResult fields. Subclasses add their own fields.
#[derive(Clone, Debug, PartialEq)]
pub struct PhaseBase {
    pub ok: bool,
    pub error: String,
    /// False when the phase must run again on a later slice of the same day.
    pub complete: bool,
    pub news_items: Vec<NewsEvent>,
    pub news_queue_updated: bool,
    pub news_queue_inserted: i64,
    pub sound_events: Vec<SoundEvent>,
    pub effect_events: Vec<EffectEvent>,
    pub game_over_events: Vec<GameOverEvent>,
    pub refresh_requests: Vec<String>,
    pub view_center_requests: Vec<Vec2i>,
    pub music_track_requests: Ints32,
    pub notice_ids: Ints32,
    pub newspaper_requested: bool,
    pub newspaper_paper: i64,
    pub timing: Timing,
}

impl Default for PhaseBase {
    fn default() -> Self {
        Self {
            ok: false,
            error: String::new(),
            complete: true,
            news_items: Vec::new(),
            news_queue_updated: false,
            news_queue_inserted: 0,
            sound_events: Vec::new(),
            effect_events: Vec::new(),
            game_over_events: Vec::new(),
            refresh_requests: Vec::new(),
            view_center_requests: Vec::new(),
            music_track_requests: Ints32::default(),
            notice_ids: Ints32::default(),
            newspaper_requested: false,
            newspaper_paper: -1,
            timing: Timing::new(-1, OrderedMap::new()),
        }
    }
}

impl PhaseBase {
    pub fn fields(&self) -> Vec<(&'static str, Value)> {
        vec![
            ("ok", Value::Bool(self.ok)),
            ("error", Value::Str(self.error.clone())),
            ("complete", Value::Bool(self.complete)),
            ("news_items", self.news_items.to_value()),
            ("news_queue_updated", Value::Bool(self.news_queue_updated)),
            ("news_queue_inserted", Value::Int(self.news_queue_inserted)),
            ("sound_events", self.sound_events.to_value()),
            ("effect_events", self.effect_events.to_value()),
            ("game_over_events", self.game_over_events.to_value()),
            ("refresh_requests", self.refresh_requests.to_value()),
            ("view_center_requests", self.view_center_requests.to_value()),
            ("music_track_requests", self.music_track_requests.to_value()),
            ("notice_ids", self.notice_ids.to_value()),
            ("newspaper_requested", Value::Bool(self.newspaper_requested)),
            ("newspaper_paper", Value::Int(self.newspaper_paper)),
            ("timing", self.timing.to_value()),
        ]
    }
}

/// A result that has the common PhaseResult fields.
pub trait PhaseResultLike: ToValue {
    fn base(&self) -> &PhaseBase;
    fn base_mut(&mut self) -> &mut PhaseBase;
}

/// A plain PhaseResult.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct PlainPhaseResult {
    pub base: PhaseBase,
}

impl ToValue for PlainPhaseResult {
    fn to_value(&self) -> Value {
        Value::Object("PhaseResult", self.base.fields())
    }
}

impl PhaseResultLike for PlainPhaseResult {
    fn base(&self) -> &PhaseBase {
        &self.base
    }

    fn base_mut(&mut self) -> &mut PhaseBase {
        &mut self.base
    }
}

impl PlainPhaseResult {
    pub fn failed(message: impl Into<String>) -> Self {
        let mut result = Self::default();
        result.base.error = message.into();
        result
    }

    /// A phase that only asks the interface to refresh.
    pub fn refreshing(requests: &[&str]) -> Self {
        let mut result = Self::default();
        result.base.ok = true;
        result.base.refresh_requests = requests.iter().map(|request| request.to_string()).collect();
        result
    }
}

/// Elapsed work time, as SimulationTimingSpan. Frame waits are excluded when a
/// slice budget reports them.
pub struct TimingSpan {
    started: Instant,
    step_started: Instant,
    current_step: String,
    steps: OrderedMap<i64>,
    indexed_labels: &'static [&'static str],
    indexed_totals: Vec<i64>,
    current_index: i64,
    parked_usec: fn() -> i64,
}

fn no_parking() -> i64 {
    0
}

impl TimingSpan {
    pub fn new() -> Self {
        Self::with_labels(&[])
    }

    pub fn with_labels(labels: &'static [&'static str]) -> Self {
        let now = Instant::now();

        Self {
            started: now,
            step_started: now,
            current_step: String::new(),
            steps: OrderedMap::new(),
            indexed_labels: labels,
            indexed_totals: vec![0; labels.len()],
            current_index: -1,
            parked_usec: no_parking,
        }
    }

    fn elapsed(from: Instant, to: Instant) -> i64 {
        to.duration_since(from).as_micros() as i64
    }

    pub fn mark(&mut self, label: &str) {
        let now = Instant::now();

        if !self.current_step.is_empty() {
            let spent = Self::elapsed(self.step_started, now);
            let total = self.steps.get(&self.current_step).copied().unwrap_or(0) + spent;
            let step = self.current_step.clone();
            self.steps.set(&step, total);
        }

        self.current_step = label.to_string();
        self.step_started = now;
    }

    /// Use fixed indices for hot loops. A span uses indexed or string marks, not both.
    pub fn mark_index(&mut self, index: i64) {
        let now = Instant::now();

        if self.current_index >= 0 {
            self.indexed_totals[self.current_index as usize] += Self::elapsed(self.step_started, now);
        }

        self.current_index = index;
        self.step_started = now;
    }

    pub fn finish(&mut self) -> Timing {
        if self.indexed_labels.is_empty() {
            self.mark("");
        } else {
            self.mark_index(-1);

            for (index, label) in self.indexed_labels.iter().enumerate() {
                self.steps.set(label, self.indexed_totals[index]);
            }
        }

        let total = Self::elapsed(self.started, Instant::now()) - (self.parked_usec)();

        Timing::new(total.max(0), self.steps.clone())
    }
}

impl Default for TimingSpan {
    fn default() -> Self {
        Self::new()
    }
}
