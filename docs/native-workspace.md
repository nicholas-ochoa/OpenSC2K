# Native workspace

The Rust code is one Cargo workspace in `native/`. It has two kinds of crates:

- **Core crates** in `native/core/`. They hold the game: the simulation, the city
  painter, the codecs, the music sequencer and the script runtime. They have no
  engine types, so `cargo test` runs them and a later front end can use them.
- **Bridge crates** in `native/<module>/`. Each one builds one GDExtension library,
  `opensc2k_<module>`, that loads into Godot. A bridge converts Godot values to
  core types and back. It holds no game rules.

| Core crate | Folder | Bridge crate | Contents |
| --- | --- | --- | --- |
| `sc2k_sim` | `core/sim` | `opensc2k_simulation` | Simulation, player tool rules, city file codecs |
| `sc2k_render` | `core/render` | `opensc2k_rendering` | Region builder, rasterizer, compositor, views |
| `sc2k_formats` | `core/formats` | `opensc2k_formats` | BMP, GIF, PNG, PE resources, sprites, CRC-32 |
| `sc2k_audio` | `core/audio` | `opensc2k_audio` | MIDI events, sequencer, FluidSynth loader |
| `sc2k_scripting` | `core/scripting` | `opensc2k_scripting` | QuickJS-ng runtime, sandbox, inspector |

## Rules

- A core crate must not depend on `godot`, directly or through another crate.
  `cargo xtask check-cores` checks this. The validator and CI run it before the unit tests.
- Put new game rules in a core crate first. GDScript and the bridges only present them.
- Put the tests of a rule beside the rule, in its core crate.

## Tasks

Run these from `native/`:

```sh
cargo xtask check-cores   # each core crate builds without Godot
cargo xtask lint          # cargo fmt --check and Clippy with -D warnings
cargo xtask test          # check-cores, then cargo test --release --workspace
```

`python3 tools/build_native.py` builds the bridge libraries and copies them into
`game/bin/`. `tools/validate_project.sh` builds them and runs the unit tests before
the Godot checks.

## Dependencies

Use as few crates as possible. Write small helpers (hashing, JSON, containers) by hand.
When a crate is necessary, it must have a permissive license that is compatible with
MIT: MIT, Apache-2.0, Zlib, ISC, BSD or CC0. Do not use copyleft crates such as MPL,
LGPL or GPL. FluidSynth (LGPL) stays a separate shared library that loads at run time.

Current crates:

| Crate | Used by | License | Purpose |
| --- | --- | --- | --- |
| `godot` | bridge crates only | MPL-2.0 (bridge only; removed with Godot) | GDExtension bindings |
| `cc` | `sc2k_scripting` (build) | MIT/Apache-2.0 | Compiles QuickJS-ng |
| `miniz_oxide` | `sc2k_formats` | MIT/Zlib/Apache-2.0 | DEFLATE of ZIP members |
