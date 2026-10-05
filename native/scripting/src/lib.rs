//! `ScriptRuntime`, the Godot class of the JavaScript runtime. The runtime is
//! in the `sc2k_scripting` crate. The game functions of scripts are GDScript
//! host functions.

mod godot_class;

use godot::prelude::*;

struct OpenSc2kScripting;

#[gdextension(entry_symbol = opensc2k_scripting_init)]
unsafe impl ExtensionLibrary for OpenSc2kScripting {}
