//! The Godot classes of the native simulation. The simulation is in the
//! `sc2k_sim` crate; `bridge` converts Godot values to and from its types.

mod bridge;

use godot::prelude::*;

struct OpenSc2kSimulation;

#[gdextension(entry_symbol = opensc2k_simulation_init)]
unsafe impl ExtensionLibrary for OpenSc2kSimulation {}
