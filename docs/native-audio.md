# Native audio

The music synthesizers are the Rust crate `sc2k_audio` in `native/core/audio`. It has no
dependencies and no engine types. The bridge crate `opensc2k_audio` in `native/audio` holds
the Godot class `FluidMidiSynth`. See [Native workspace](native-workspace.md). FluidSynth loads at run time; see [FluidSynth music](fluidsynth.md).

## Layout

- `src/midi.rs` holds the timed MIDI events and the event codes that GDScript sends.
- `src/sequencer` plays an event list through a synthesizer. It splits each render
  at event times, seeks, loops and ends after the release tail.
- `src/fluidsynth` is the FluidSynth backend: run-time library loading, the C
  function table, and the safe `FluidSynth` owner. All FFI code is here.
- `src/fluid_midi_synth.rs` holds `FluidMidiSynth`, the music synthesizer.
- `MidiSynthPlayer` keeps the music thread, the stream buffer and the track
  status, and calls `FluidMidiSynth.render` for each fill.

## Build and checks

`python3 tools/build_native.py` builds and installs every native library and builds
FluidSynth. Run `cargo fmt`, `cargo fmt --check`,
`cargo clippy --all-targets --all-features -- -D warnings` and
`cargo test --release` from `native/`.
