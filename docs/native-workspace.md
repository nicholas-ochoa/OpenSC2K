# Native workspace

The Rust code is one Cargo workspace in `native/`. It has three kinds of crates:

- **Core crates** in `native/core/`. They hold the game: the simulation, the city
  painter, the codecs, the music sequencer and the script runtime. They have no
  engine types, so `cargo test` runs them and a later front end can use them.
- **Bridge crates** in `native/<module>/`. Each one builds one GDExtension library,
  `opensc2k_<module>`, that loads into Godot. A bridge converts Godot values to
  core types and back. It holds no game rules.
- **The native game** in `native/app/`: the `opensc2k` binary. It opens a window
  with `winit`, presents CPU pixels with `softbuffer`, and plays sound with `cpal`.
  It uses only core crates and no Godot.

| Core crate | Folder | Bridge crate | Contents |
| --- | --- | --- | --- |
| `sc2k_sim` | `core/sim` | `opensc2k_simulation` | Simulation, player tool rules, city file codecs |
| `sc2k_render` | `core/render` | `opensc2k_rendering` | Region builder, rasterizer, compositor, views |
| `sc2k_formats` | `core/formats` | `opensc2k_formats` | BMP, GIF, PNG, PE resources, sprites, CRC-32 |
| `sc2k_audio` | `core/audio` | `opensc2k_audio` | MIDI events, sequencer, FluidSynth loader |
| `sc2k_scripting` | `core/scripting` | `opensc2k_scripting` | QuickJS-ng runtime, sandbox, inspector |
| `sc2k_game` | `core/game` | `opensc2k_simulation` | Engine days, speed controller, newspaper text |
| `sc2k_assets` | `core/assets` | `opensc2k_formats`, `opensc2k_simulation` | Original resources: DATA_USA grammar, Johab codec |
| `sc2k_platform` | `core/platform` | `opensc2k_simulation` | Release check, version comparison, mod manifests, settings files, user folder, console log |
| `sc2k_view` | `core/view` | (native game only) | City view on CPU pixels: camera, regions, palette cycling, moving draws, effects, data views, HD art |
| `sc2k_ui` | `core/ui` | (native game only) | Control map; later the widget toolkit and screens |

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
| `miniz_oxide` | `sc2k_formats` | MIT/Zlib/Apache-2.0 | DEFLATE of ZIP members and PNG files |
| `winit` | `opensc2k` (native game) | Apache-2.0 | Window, events, keyboard, DPI |
| `softbuffer` | `opensc2k` (native game) | MIT/Apache-2.0 | Presents CPU pixels in the window |
| `cpal` | `opensc2k` (native game) | Apache-2.0 | Audio output |

## The native game

`cargo run -p opensc2k --release -- <city file>` opens a city in the native game.
It reads the settings, graphics pack, sound pack, music pack, and HD sprite pack of
the Godot build from the same user folder. Command line modes without a window:

```sh
opensc2k <city> --snapshot out.png [zoom steps]      # one 1280x800 frame
opensc2k <city> --render out.png [view] [underground] # the whole city, as the CPU painter exports it
opensc2k <city> --benchmark [frames] [speed]          # frame work while the simulation runs
```

The simulation runs on its own thread (`sc2k_game::runner`). It publishes the changed
map cells, the moving objects, and the disaster markers (`sc2k_view::scene`) after each
step, so the frame never waits for a day. `core/view/tests/renders.rs` checks whole-city
renders against hashes that match the Godot painter pixel for pixel.
