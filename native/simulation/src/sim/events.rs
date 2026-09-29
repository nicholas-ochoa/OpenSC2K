//! Presentation events and timing, as the GDScript event classes.

use super::geom::Vec2i;
use super::value::{OrderedMap, ToValue, Value};
use crate::gd_object;

gd_object! {
    /// A story or runtime report for the saved news queue and status bar.
    pub struct NewsEvent as "NewsEvent" {
        pub type_: i64 = 0,
        pub argument: i64 = 0,
    }
}

impl NewsEvent {
    pub fn new(news_type: i64, argument: i64) -> Self {
        Self {
            type_: news_type,
            argument,
        }
    }
}

gd_object! {
    /// A sound request. Moving-object requests keep their source metadata.
    pub struct SoundEvent as "SoundEvent" {
        pub sound_id: i64 = 0,
        pub from_thing: bool = false,
        pub thing_type: i64 = -1,
        pub record: i64 = -1,
        pub point: Vec2i = Vec2i::NONE,
    }
}

impl SoundEvent {
    pub fn new(id: i64) -> Self {
        Self {
            sound_id: id,
            ..Default::default()
        }
    }

    pub fn for_thing(id: i64, thing_type: i64, record: i64, point: Vec2i) -> Self {
        Self {
            sound_id: id,
            from_thing: true,
            thing_type,
            record,
            point,
        }
    }
}

gd_object! {
    /// A demolition sprite or earthquake request. Altitude -1 uses the water altitude.
    pub struct EffectEvent as "EffectEvent" {
        pub type_: String = String::new(),
        pub point: Vec2i = Vec2i::NONE,
        pub sprite_id: i64 = 0,
        pub screen_offset: Vec2i = Vec2i::ZERO,
        pub flip: bool = false,
        pub frame: i64 = 0,
        pub altitude: i64 = -1,
        pub frames: i64 = 24,
        pub frame_msec: i64 = 5,
        pub distance: i64 = 4,
    }
}

impl EffectEvent {
    pub fn new(point: Vec2i, sprite_id: i64, screen_offset: Vec2i, flip: bool, frame: i64, altitude: i64) -> Self {
        Self {
            point,
            sprite_id,
            screen_offset,
            flip,
            frame,
            altitude,
            ..Default::default()
        }
    }

    pub fn earthquake() -> Self {
        Self {
            type_: "earthquake".to_string(),
            ..Default::default()
        }
    }
}

gd_object! {
    pub struct GameOverEvent as "GameOverEvent" {
        pub type_: String = String::new(),
        pub funds: i64 = 0,
        pub sound_id: i64 = 512,
    }
}

impl GameOverEvent {
    pub fn new(event_type: &str, funds: i64) -> Self {
        let sound_id = if event_type == "scenario_victory" { 513 } else { 512 };

        Self {
            type_: event_type.to_string(),
            funds,
            sound_id,
        }
    }

    pub fn is_terminal(&self) -> bool {
        self.type_ != "scenario_victory"
    }
}

/// Measured work for the timing window. Deterministic comparisons skip it.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Timing {
    pub has_total: bool,
    pub work_usec: i64,
    pub steps: OrderedMap<i64>,
}

impl Timing {
    pub fn new(total_usec: i64, steps: OrderedMap<i64>) -> Self {
        Self {
            has_total: total_usec >= 0,
            work_usec: total_usec.max(0),
            steps,
        }
    }
}

impl ToValue for Timing {
    fn to_value(&self) -> Value {
        Value::Object(
            "SimulationTiming",
            vec![
                ("has_total", Value::Bool(self.has_total)),
                ("work_usec", Value::Int(self.work_usec)),
                ("steps", self.steps.to_value()),
            ],
        )
    }
}
