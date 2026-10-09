//! The Godot classes of the file and image codecs. The codecs are in the
//! `sc2k_formats` crate; `bridge` converts Godot values.

mod bridge;

use godot::prelude::*;

struct OpenSc2kFormats;

#[gdextension(entry_symbol = opensc2k_formats_init)]
unsafe impl ExtensionLibrary for OpenSc2kFormats {}
