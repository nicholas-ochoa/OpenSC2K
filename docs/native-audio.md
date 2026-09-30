# Native audio

The music synthesizer is a Rust GDExtension in `native/audio`. Its only dependency is the
`godot` crate.

## Layout

- `src/synth.rs` renders standard MIDI sequences with additive voices. It keeps the arithmetic
  of the GDScript synthesizer that it replaced: 64-bit voice state and mix sums, 32-bit
  wavetables and channel controls, and the reverse voice mix order. A render therefore gives
  the same samples at every fill size.
- `src/lib.rs` holds `NativeMidiSynth`. `MidiSynthPlayer` keeps the music thread, the stream
  buffer and the track status, and calls `NativeMidiSynth.render` for each fill.

## Build and checks

`python3 tools/build_native.py` builds and installs every native library. Run `cargo fmt`,
`cargo fmt --check`, `cargo clippy --all-targets --all-features -- -D warnings` and
`cargo test --release` from `native/audio`.
