# Native simulation

The city simulation is the Rust crate `sc2k_sim` in `native/core/sim`. It has no
dependencies and no engine types. The bridge crate `opensc2k_simulation` in
`native/simulation` uses [godot-rust](https://github.com/godot-rust/gdext) (`gdext`)
to load it into Godot as a GDExtension. See [Native workspace](native-workspace.md).

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
Godot checks. Rebuild the library after each change to `native/core/sim` or `native/simulation`.

## Layout

The paths below are in `native/core/sim`, except `src/bridge`, which is in `native/simulation`.

- `src/sim` is the simulation. It has no Godot types, so `cargo test` runs it.
  - `city.rs` holds the saved chunks that the simulation reads and writes.
  - `engine/day.rs` runs one scheduled day in the original phase order.
  - `growth`, `infrastructure`, `data_maps`, `economy`, `civic`, `reports`, `disasters`,
    and `moving` hold the rules of each part of the simulation.
  - `tools` holds the edit rules that the simulation shares with the player tools, such as demolition.
    `tools/commands` holds the player tool commands: network and highway drags, bridges, tunnels,
    on-ramps, subway-to-rail connections, buildings and their facility records, zones, the bulldozer,
    the terrain and landscape tools, the terrain editor, and SCURK Place & Print.
    `tools/rotation.rs` turns the city for `CityRotationCommand`.
    `tools/new_terrain.rs` runs the map-size stages of `NewCityTerrain` and the landscape
    editor stream. GDScript still makes the 128 by 128 landform, because its layout features
    use Godot noise and float vectors.
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

## Player tools

Each tool command class in `game/src/tools`, such as `NetworkCommand`, `BuildingCommand`, and
`TerrainCommand`, keeps its public functions and calls a `tool.*` operation through
`NativeToolEdit.run`. The library edits the chunks and returns the GDScript result class. The
bridge stores only the chunks that changed, and only for a successful edit. `NativeToolEdit` keeps
the payloads before and after the edit; undo exchanges them in GDScript.

`NativeCityTools` answers the tool questions of the view and the dialogs: building areas and
sites, building corners, bridge deck tiles, and SCURK sites.

The dispatch tool, the sign tool, the query tool, the news queue, and the interface stay in GDScript.

## Rules

- Keep the rules of the original executable, including its random-call order and integer widths.
  The saved random states must match those of the GDScript simulation that this library replaced.
- A test that passes a subclass of `SimRandom`, `SimLfsrRandom`, or `GameLcgRandom` replaces the
  draws. The library calls the subclass methods for each draw.
- Long loops call `budget::checkpoint()`, so that the frame runner can pause the work between frames.
- Add a Rust unit test for each simulation rule. Keep the GDScript tests for behavior that the
  interface or the file formats show.
