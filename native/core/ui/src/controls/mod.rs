//! The player actions that keys and mouse buttons start, as ControlActions,
//! ControlBinding, and ControlBindings. Keys use the key names of the settings
//! file, which are Godot's names, so the native game reads the same bindings.

mod actions;
mod binding;
mod bindings;

#[cfg(test)]
mod tests;

pub use actions::{Action, DATA_VIEW_IDS, Kind, SPEED_IDS, SURFACE_LAYERS, Scope, TOOL_IDS, WINDOW_ACTIONS, actions, bindable_ids, find};
pub use binding::{Binding, Device, Input, KEY_NAMES, MOUSE_NAMES, modifier_bits, modifiers};
pub use bindings::Bindings;
