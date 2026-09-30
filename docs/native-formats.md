# Native formats

File and image codecs are a Rust GDExtension in `native/formats`. Its only dependency is
the `godot` crate. It does not read city or simulation state.

## Layout

- `src/crc32.rs` calculates the CRC-32 of PNG and ZIP records. `ZipArchive` and the PNG
  codec call it through `NativeCrc32`.
- `src/sprite.rs` decodes SimCity 2000 and DOS sprite records and makes the color and index
  images of sprites (`NativeSpriteCodec`, used by `Sc2SpriteArchive` and `Sc2ImportSprites`).
- `src/png.rs` writes indexed PNG files and checks and rewrites their records for decoding
  (`NativeIndexedPng`, used by `IndexedPng`). Godot compresses the pixel data and decodes the
  rewritten file; the rewritten palette makes each decoded pixel read as its index.
- `src/gif.rs` writes one-frame and palette-cycle GIF files and decodes GIF images with their
  LZW codes (`NativeIndexedGif`, used by `IndexedGif`).
- `src/bmp.rs` reads and writes 8-bit indexed BMP files and DIBs, decodes 1-, 4- and 8-bit
  indexed DIBs, and maps colors to the city palette (`NativeIndexedBmp`, used by `IndexedBmp`,
  `Sc2ImportBitmap` and the SCURK image import).
- `src/pe.rs` reads the resource directories of 32-bit Windows executables: bitmaps, RLE8
  data, icons and cursors (`NativePeResources`, used by `PeBitmapResource`,
  `PeIconCursorResource` and `WindowsBitmapRle8`).
- `src/bridge.rs` holds the Godot classes. The other modules have no Godot types, so
  `cargo test` runs them.

## Build and checks

`python3 tools/build_native.py` builds and installs every native library. Run `cargo fmt`,
`cargo fmt --check`, `cargo clippy --all-targets --all-features -- -D warnings` and
`cargo test --release` from `native/formats`. The project validator also builds the library
and runs its unit tests.
