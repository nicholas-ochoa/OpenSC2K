//! The Godot classes of the city painter. The painter is in the `sc2k_render`
//! crate. The bridge copies a display snapshot once per revision; Godot
//! receives only completed geometry and immutable sprite images.

mod bridge;

use godot::prelude::*;

struct OpenSc2kRendering;

#[gdextension(entry_symbol = opensc2k_rendering_init)]
unsafe impl ExtensionLibrary for OpenSc2kRendering {}
