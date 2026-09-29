# Native region builder

The GPU region builder is a separate Rust GDExtension in `native/rendering`.
It uses an immutable display snapshot. It does not read or change native simulation
state. Each existing geometry worker owns one builder and its caches.

Rust selects terrain and building sprites, calculates bounds and positions, applies
traffic masks, packs the sprite atlas, clips draws, and builds mesh arrays. It also
returns foreground records for moving objects and signs. GDScript adapts those
records to the existing `CityGpuRegionResult` interface. Godot still uploads textures
and meshes, runs shaders, and displays the city.

Rust is the default GPU region builder. Set `OPENSC2K_REGION_BUILDER=gdscript` to
use the retained GDScript implementation for comparisons. This switch does not
change the separate CPU/GPU renderer preference.

## Build and checks

`python3 tools/build_native.py` builds and installs both native extensions.
`--package` builds their desktop package libraries. Each crate has its own lockfile
and toolchain selection. The renderer has no dependency on the simulation crate.

Run `cargo fmt`, `cargo fmt --check`, `cargo clippy --all-targets --all-features -- -D warnings`,
and `cargo test --release` from `native/rendering`. The project validator also builds
both extensions and runs both sets of Rust unit tests.

`city_native_region_test` compares native regions against GDScript. It checks
indexed pixels, foreground order and train fields, all artwork sizes, surface and
underground views, building and terrain catalogs, traffic, cutaways, display
filters, revision changes, and a 512-by-512 city. Its native counterpart also checks
GPU pixels. Dispatch checks include extended record IDs and coordinates above 255.
The existing cache, sign, moving-object and renderer tests exercise the normal
region interface.

## Performance measurement

Run the comparison with Dummy audio:

```sh
godot --headless --audio-driver Dummy --path game \
  --script res://tools/benchmarks/native_region_benchmark.gd
```

The benchmark prepares 64 regions, moves to 64 new regions, then returns. It uses
128-pixel Small regions and 256-pixel Medium/Large regions. It alternates builder
order across three repeats. It records input hashes, engine version, source
revision, and whether the worktree has changes.

On the development Mac (Apple M3 Max) with Godot 4.7.2, commit `075ccc61` produced
these median CPU times for the new-region pan stage on the generated 512-by-512 city.
The worktree was clean. No other project tests or builds ran during the measurement.

| Artwork | GDScript | Rust | Ratio |
| --- | ---: | ---: | ---: |
| Small | 728.5 ms | 176.9 ms | 4.12x |
| Medium | 718.7 ms | 175.9 ms | 4.09x |
| Large | 222.7 ms | 51.9 ms | 4.29x |

These measurements include bridge costs. They exclude GPU uploads and display
latency. They are not frame-rate measurements or promises for other machines.
Cold measurements also include the native snapshot and asset setup. Raw local
results are in `local/performance/native-region-20260929/compare-final.log`.

Both builders retain a bounded map-cell cache. A large view can still evict tile
data before a later request reuses it. Complete region meshes have a separate
cache. The native port does not increase the map-cell cache limit.
