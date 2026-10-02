//! The FluidSynth backend. FluidSynth is LGPL-2.1-or-later; OpenSC2K loads it at
//! run time from a separate shared library and never links it. See docs/fluidsynth.md.
//!
//! Threading: the GDScript music thread owns a synthesizer while a track plays and
//! is the only caller of `render`. SoundFont loads read files and run on another
//! thread before the synthesizer passes to the music thread. Godot's audio thread
//! only reads the ring buffer of an `AudioStreamGenerator`; it never calls FluidSynth.
mod api;
mod log;
mod platform;
mod synth;

#[cfg(test)]
mod test_soundfont;

#[cfg(test)]
mod tests;

pub use api::{open_first, shared};
pub use synth::FluidSynth;

/// An error when the library cannot load from `path`, or an empty string. This
/// does not change the library that the game uses.
pub fn probe_library(path: &str) -> String {
    match open_first(&[std::path::PathBuf::from(path)]) {
        Ok(_) => String::new(),
        Err(error) => error,
    }
}
