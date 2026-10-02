//! Native music synthesis. The GDScript player owns the music thread and the
//! stream; this library only renders frames. `FluidMidiSynth` renders with
//! FluidSynth, a separate LGPL shared library that loads at run time. Modules
//! without Godot types (`midi`, `sequencer`, `fluidsynth`) run under `cargo test`.
mod fluid_midi_synth;
mod fluidsynth;
mod midi;
mod sequencer;

use godot::prelude::*;

struct OpenSc2kAudio;

#[gdextension(entry_symbol = opensc2k_audio_init)]
unsafe impl ExtensionLibrary for OpenSc2kAudio {}
