# Native formats

File and image codecs are a Rust GDExtension in `native/formats`. Its only dependency is
the `godot` crate. It does not read city or simulation state.

## Layout

- `src/crc32.rs` calculates the CRC-32 of PNG and ZIP records. `ZipArchive` and the PNG
  codec call it through `NativeCrc32`.
- `src/bridge.rs` holds the Godot classes. The other modules have no Godot types, so
  `cargo test` runs them.

## Build and checks

`python3 tools/build_native.py` builds and installs every native library. Run `cargo fmt`,
`cargo fmt --check`, `cargo clippy --all-targets --all-features -- -D warnings` and
`cargo test --release` from `native/formats`. The project validator also builds the library
and runs its unit tests.
