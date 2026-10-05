//! Player tool commands, as the GDScript tool command classes.
//!
//! Each command edits the city chunks and returns its GDScript result class.
//! The chunks that changed go back to the document. GDScript keeps the payloads
//! before and after the edit for undo; see NativeToolEdit.

pub mod building;
pub mod demolish;
pub mod dispatch;
pub mod highway;
pub mod hydro;
pub mod landscape;
pub mod network;
pub mod onramp;
pub mod route;
pub mod scurk_place;
pub mod subway_to_rail;
pub mod tunnel;
pub mod zone;

use super::super::events::EffectEvent;
use super::super::geom::{Rect2i, Vec2i};
use super::super::value::{Ints32, ToValue, Value};

/// The EditCommandResult fields. Each result class adds its own fields.
#[derive(Clone, Debug, PartialEq)]
pub struct EditBase {
    pub ok: bool,
    pub error: String,
    pub command_type: String,
    pub group_index: i64,
    pub subtool_index: i64,
    pub cost: i64,
    pub listed_cost: i64,
    pub free_mode: bool,
    pub tile_indices: Ints32,
    pub points: Vec<Vec2i>,
    pub site: Rect2i,
    pub tracks_random: bool,
    pub random_state_before: i64,
    pub random_state_after: i64,
    pub power_usage_percent: i64,
    pub water_usage_percent: i64,
    pub sound_events: Vec<i64>,
    pub effect_events: Vec<EffectEvent>,
}

impl Default for EditBase {
    fn default() -> Self {
        Self {
            ok: false,
            error: String::new(),
            command_type: String::new(),
            group_index: -1,
            subtool_index: -1,
            cost: 0,
            listed_cost: 0,
            free_mode: false,
            tile_indices: Ints32::default(),
            points: Vec::new(),
            site: Rect2i::default(),
            tracks_random: false,
            random_state_before: 0,
            random_state_after: 0,
            power_usage_percent: -1,
            water_usage_percent: -1,
            sound_events: Vec::new(),
            effect_events: Vec::new(),
        }
    }
}

impl EditBase {
    /// A failed edit, as EditCommandResult.failure and the `rejected` helpers.
    pub fn rejected(message: &str, charged: i64) -> Self {
        Self {
            error: message.to_string(),
            cost: charged,
            ..Default::default()
        }
    }

    /// A successful edit of one tool.
    pub fn accepted(command_type: &str, group_index: i64, subtool_index: i64) -> Self {
        Self {
            ok: true,
            command_type: command_type.to_string(),
            group_index,
            subtool_index,
            ..Default::default()
        }
    }

    pub fn fields(&self) -> Vec<(&'static str, Value)> {
        vec![
            ("ok", Value::Bool(self.ok)),
            ("error", Value::Str(self.error.clone())),
            ("command_type", Value::Str(self.command_type.clone())),
            ("group_index", Value::Int(self.group_index)),
            ("subtool_index", Value::Int(self.subtool_index)),
            ("cost", Value::Int(self.cost)),
            ("listed_cost", Value::Int(self.listed_cost)),
            ("free_mode", Value::Bool(self.free_mode)),
            ("tile_indices", self.tile_indices.to_value()),
            ("points", self.points.to_value()),
            ("site", self.site.to_value()),
            ("tracks_random", Value::Bool(self.tracks_random)),
            ("random_state_before", Value::Int(self.random_state_before)),
            ("random_state_after", Value::Int(self.random_state_after)),
            ("power_usage_percent", Value::Int(self.power_usage_percent)),
            ("water_usage_percent", Value::Int(self.water_usage_percent)),
            ("sound_events", self.sound_events.to_value()),
            ("effect_events", self.effect_events.to_value()),
        ]
    }
}

/// Declare an EditCommandResult subclass. It holds the common fields in `base`,
/// and GDScript receives the base fields and its own fields as one object.
#[macro_export]
macro_rules! gd_edit_result {
    (
        $(#[$meta:meta])*
        pub struct $name:ident as $class:literal {
            $( $(#[$field_meta:meta])* pub $field:ident : $kind:ty = $default:expr ),* $(,)?
        }
    ) => {
        $(#[$meta])*
        #[derive(Clone, Debug, PartialEq)]
        pub struct $name {
            pub base: $crate::sim::tools::commands::EditBase,
            $( $(#[$field_meta])* pub $field: $kind ),*
        }

        impl Default for $name {
            fn default() -> Self {
                Self { base: Default::default(), $( $field: $default ),* }
            }
        }

        impl $name {
            /// A failed edit that reports `message` and the price it would have charged.
            #[allow(dead_code)]
            pub fn rejected(message: &str, charged: i64) -> Self {
                Self { base: $crate::sim::tools::commands::EditBase::rejected(message, charged), ..Default::default() }
            }
        }

        impl $crate::sim::value::ToValue for $name {
            fn to_value(&self) -> $crate::sim::value::Value {
                #[allow(unused_mut)]
                let mut fields = self.base.fields();
                $( fields.push(($crate::sim::value::field_name(stringify!($field)), $crate::sim::value::ToValue::to_value(&self.$field))); )*

                $crate::sim::value::Value::Object($class, fields)
            }
        }
    };
}

/// The four cardinal steps in network direction order: north, east, south, west.
pub const DIRECTIONS: [Vec2i; 4] = [Vec2i::new(0, -1), Vec2i::new(1, 0), Vec2i::new(0, 1), Vec2i::new(-1, 0)];

/// The largest tile that a route, tunnel, or on-ramp may replace.
pub use super::super::ids::building_tile_ids::SMALL_PARK as MAX_CLEAR_BUILDING;

/// A point scaled by `factor`, as Vector2i * int.
#[inline]
pub fn scaled(point: Vec2i, factor: i64) -> Vec2i {
    Vec2i::new(point.x * factor, point.y * factor)
}

#[inline]
pub fn in_bounds(point: Vec2i, map_edge: i64) -> bool {
    point.x >= 0 && point.x < map_edge && point.y >= 0 && point.y < map_edge
}

/// The arguments that GDScript passes to a tool command.
pub struct ToolArgs {
    pub group: i64,
    pub subtool: i64,
    /// ToolCatalog cost of the tool.
    pub cost: i64,
    pub free_mode: bool,
}

/// Append `index` to an ordered set held in a vector, as PackedInt32Array.has
/// followed by append.
pub fn append_unique(list: &mut Vec<i32>, seen: &mut std::collections::HashSet<i32>, index: i64) {
    if seen.insert(index as i32) {
        list.push(index as i32);
    }
}
