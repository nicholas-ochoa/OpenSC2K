//! The JavaScript runtime of OpenSC2K: QuickJS-ng, compiled from the vendored
//! C sources in `quickjs`. `engine` runs one runtime and `prelude.js` defines
//! its core: console, timers, events and script commands. `godot_class`
//! holds `ScriptRuntime`, the Godot class. The game functions of scripts are
//! GDScript host functions. Modules without Godot types run under `cargo test`.
mod engine;
mod ffi;
mod godot_class;
mod inspector;
mod value;

use godot::prelude::*;

struct OpenSc2kScripting;

#[gdextension(entry_symbol = opensc2k_scripting_init)]
unsafe impl ExtensionLibrary for OpenSc2kScripting {}
