//! Godot entry points. Each call receives the saved city chunks and the engine
//! state, runs one simulation operation, and returns the written chunks and
//! the result as Godot values. GDScript builds the result objects.

mod convert;
mod ops;

use godot::prelude::*;

/// Static entry points for GDScript. No instance holds simulation state.
#[derive(GodotClass)]
#[class(no_init, base = Object)]
pub struct NativeSimulation {}

#[godot_api]
impl NativeSimulation {
    /// Run the operation that `request.op` names. See `ops.rs` for the fields.
    #[func]
    fn run(request: VarDictionary) -> VarDictionary {
        ops::run(&request)
    }

    /// The operations that this library implements.
    #[func]
    fn operations() -> PackedStringArray {
        ops::OPERATIONS.iter().map(|name| GString::from(*name)).collect()
    }
}
