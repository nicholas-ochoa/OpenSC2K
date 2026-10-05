//! The Godot class of the music synthesizer. The GDScript player owns the music
//! thread and the stream; this library only renders frames. The synthesis is in
//! the `sc2k_audio` crate.

mod fluid_midi_synth;
mod midi_file;
mod music_shuffle;

use godot::prelude::*;

struct OpenSc2kAudio;

#[gdextension(entry_symbol = opensc2k_audio_init)]
unsafe impl ExtensionLibrary for OpenSc2kAudio {}
