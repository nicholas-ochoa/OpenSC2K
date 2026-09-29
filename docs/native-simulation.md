# Native simulation

The city simulation is a Rust library in `native/simulation`. It uses
[godot-rust](https://github.com/godot-rust/gdext) (`gdext`) to load into Godot as a
GDExtension. Its only dependency is the `godot` crate.

## Build

Install Rust with [rustup](https://rustup.rs). `rust-toolchain.toml` selects the version.

```sh
python3 tools/build_native.py            # the library for this computer
python3 tools/build_native.py --package  # the library of a desktop package
```

The script copies the library to `game/bin/opensc2k_simulation/<platform>/`. Git excludes
this folder. `game/opensc2k_simulation.gdextension` names the library of each platform.
`--package` builds a universal library on macOS and the x86_64 library on Windows and Linux.

`tools/validate_project.sh` builds the library and runs its unit tests (`cargo test`) before the
Godot checks. Rebuild the library after each change to `native/simulation`.

## Layout

- `src/sim` is the simulation. It has no Godot types, so `cargo test` runs it.
  - `city.rs` holds the saved chunks that the simulation reads and writes.
  - `engine/day.rs` runs one scheduled day in the original phase order.
  - `growth`, `infrastructure`, `data_maps`, `economy`, `civic`, `reports`, `disasters`,
    and `moving` hold the rules of each part of the simulation.
  - `tools` holds the edit rules that the simulation shares with the player tools, such as demolition.
    `tools/rotation.rs` turns the city for `CityRotationCommand`.
  - `testing.rs` has test cities and scripted random generators.
- `src/formats` holds the city file codecs. `rle.rs` decodes and encodes the Maxis run-length
  code of compressed chunks. `MaxisRle` calls it through `NativeMaxisRle`.
- `src/bridge` converts Godot values. `NativeSimulation.run` takes one request and runs one operation.

## Calls from GDScript

`NativeSimulationBridge.run` in `game/src/simulation/native` sends copies of the saved chunks,
the three random generator states, and the operation arguments. The library returns the chunks
that it wrote, the new random states, and a result. The bridge stores the written chunks in the
document, refreshes the city mirrors, and builds the GDScript result objects.

The GDScript phase classes, such as `GrowthScan`, `WaterPhase`, and `MovingThingPhase`, keep
their public functions. Each function calls the bridge. `SimulationEngine` keeps the engine state
and the player interactions. Each day, disaster tick, and moving-thing tick is one native call.

The player tools, the news queue, and the interface stay in GDScript.

## Rules

- Keep the rules of the original executable, including its random-call order and integer widths.
  The saved random states must match those of the GDScript simulation that this library replaced.
- A test that passes a subclass of `SimRandom`, `SimLfsrRandom`, or `GameLcgRandom` replaces the
  draws. The library calls the subclass methods for each draw.
- Long loops call `budget::checkpoint()`, so that the frame runner can pause the work between frames.
- Add a Rust unit test for each simulation rule. Keep the GDScript tests for behavior that the
  interface or the file formats show.
