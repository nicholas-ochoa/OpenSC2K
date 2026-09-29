//! Native SimCity 2000 simulation for OpenSC2K.
//!
//! `sim` holds the simulation. It has no Godot types, so `cargo test` can run it.
//! `bridge` converts Godot values to and from the simulation types.

mod bridge;
pub mod sim;

use godot::prelude::*;

struct OpenSc2kSimulation;

#[gdextension(entry_symbol = opensc2k_simulation_init)]
unsafe impl ExtensionLibrary for OpenSc2kSimulation {}
