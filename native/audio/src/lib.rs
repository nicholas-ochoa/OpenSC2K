//! Native music synthesis. The GDScript player owns the music thread and the
//! stream; this library only renders frames. `FluidMidiSynth` renders with
//! FluidSynth, a separate LGPL shared library that loads at run time.
//! `NativeMidiSynth` is the built-in fallback. Modules without Godot types
//! (`midi`, `sequencer`, `synth`, `fluidsynth`) run under `cargo test`.
mod fluid_midi_synth;
mod fluidsynth;
mod midi;
mod native_midi_synth;
mod sequencer;
mod synth;

use godot::prelude::*;

struct OpenSc2kAudio;

#[gdextension(entry_symbol = opensc2k_audio_init)]
unsafe impl ExtensionLibrary for OpenSc2kAudio {}
