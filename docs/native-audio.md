# Native audio

The music synthesizers are a Rust GDExtension in `native/audio`. Its only crate
dependency is `godot`. FluidSynth loads at run time; see [FluidSynth music](fluidsynth.md).

## Layout

- `src/midi.rs` holds the timed MIDI events and the event codes that GDScript sends.
- `src/sequencer` plays an event list through a synthesizer. It splits each render
  at event times, seeks, loops and ends after the release tail.
- `src/fluidsynth` is the FluidSynth backend: run-time library loading, the C
  function table, and the safe `FluidSynth` owner. All FFI code is here.
- `src/fluid_midi_synth.rs` holds `FluidMidiSynth`, the default music synthesizer.
- `src/synth` renders standard MIDI sequences with additive voices. It keeps the
  arithmetic of the GDScript synthesizer that it replaced: 64-bit voice state and
  mix sums, 32-bit wavetables and channel controls, and the reverse voice mix
  order. A render therefore gives the same samples at every fill size.
- `src/native_midi_synth.rs` holds `NativeMidiSynth`, the built-in synthesizer.
- `MidiSynthPlayer` keeps the music thread, the stream buffer and the track
  status, and calls `render` on the active synthesizer for each fill.

## Build and checks

`python3 tools/build_native.py` builds and installs every native library, builds
FluidSynth and downloads the SoundFonts. Run `cargo fmt`, `cargo fmt --check`,
`cargo clippy --all-targets --all-features -- -D warnings` and
`cargo test --release` from `native/audio`.
