//! Native music synthesis without engine types. `midi` holds the timed events,
//! `sequencer` plays them through a synthesizer, and `fluidsynth` loads the
//! FluidSynth shared library (LGPL) at run time.

pub mod fluidsynth;
pub mod midi;
pub mod sequencer;
pub mod shuffle;
pub mod smf;
pub mod soundfont;
pub mod wave_gate;
