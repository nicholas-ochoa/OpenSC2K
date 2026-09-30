//! File and image codecs. The codec modules have no Godot types, so `cargo test`
//! runs them. `bridge.rs` converts Godot values.
mod bmp;
mod bridge;
mod crc32;
mod gif;
mod pe;
mod png;
mod sprite;

use godot::prelude::*;

struct OpenSc2kFormats;
#[gdextension(entry_symbol = opensc2k_formats_init)]
unsafe impl ExtensionLibrary for OpenSc2kFormats {}
