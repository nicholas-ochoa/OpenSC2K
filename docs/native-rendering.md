# Native region builder

The GPU region builder is a Rust GDExtension in `native/rendering`. It is the only
GPU region painter. The CPU region renderer remains the fallback and the reference
for tests. The builder uses an immutable display snapshot. It does not read or
change native simulation state. Each geometry worker owns one builder and its caches.

Rust selects terrain and building sprites, calculates bounds and positions, applies
traffic masks, packs the sprite atlas, clips draws, and builds mesh arrays. Godot
uploads textures and meshes, runs shaders, and displays the city.

## Region results

`CityGpuBuildContext` sends city snapshots to the builder and makes a
`CityGpuRegionResult` for each region. The result keeps the draws as packed
records and a native draw index, `NativeCityRegionDraws`. It does not make a
Godot object for each draw:

- `occlusion_indices()` and `occlusion_command()` answer moving-sprite occlusion
  queries. A command object is made only for a draw that a query returns.
- `paint()` rasterizes the draws that meet an area, in painter order, for pixel
  reads and sign masks.
- `changed_foreground_from()` compares two results of one region in Rust.

## Caches

- **Tile bounds.** The builder keeps the sprite bounds of each painted map cell.
  Bounds outlive evicted draws, so a region skips known cells outside it. A region
  caches only the tiles that it draws.
- **Tile draws.** Up to 65,536 tiles keep their draws. The least recently used
  tiles leave the cache first.
- **Invalidation.** A new city revision compares the snapshot arrays. A changed
  cell expires the cell and its eight neighbors, because a tile also reads
  neighboring land and terrain. Traffic expires a block only when its density
  crosses a traffic sprite limit.
- **Atlas.** Configuration packs all unflipped artwork of the view, tallest first.
  Scrolling then seldom adds a sprite, so the main thread seldom uploads an atlas.
  Flipped and traffic-masked sprites are added when a region first needs them.

## Other native view work

- **Data map overlays.** `data_view.rs` builds the overlay mesh of each data map from the
  ALTM words, XTER, and XBIT. `CityDataView.create_mesh` calls it through `NativeCityDataMesh`.
  Vertex colors mark tops, walls, and water; the grid shader reads each tile's value through
  the UVs. The same file makes the tile values of the height, power and water maps, which have no
  data chunk.
- **City Map window.** `minimap.rs` selects the palette index of each Map window pixel for
  each of the 18 map modes and colors the image. `CityMinimap` calls it through
  `NativeCityMinimap`. Maps larger than 1024 tiles sample every second or fourth tile.
- **Region changes.** `changes.rs` compares two revisions of the region source chunks and
  returns the screen areas that changed. `ApplicationStaticRender.changed_source_rects` calls
  it through `NativeCityChanges` after each simulation refresh. A tile change reports the
  tile's potential sprite bounds; a traffic change reports only the road sprites whose traffic
  level changed. Above a quarter of the map, it asks for a full redraw.

## Build and checks

`python3 tools/build_native.py` builds and installs both native extensions.
`--package` builds their desktop package libraries. Each crate has its own lockfile
and toolchain selection. The renderer has no dependency on the simulation crate.

Run `cargo fmt`, `cargo fmt --check`, `cargo clippy --all-targets --all-features -- -D warnings`,
and `cargo test --release` from `native/rendering`. The project validator also builds
both extensions and runs both sets of Rust unit tests.

`city_native_region_test` compares native regions with the CPU region renderer. It
checks pixels and foreground order for the building and terrain catalog, random
tiles at each view, rotation and cutaway, surface and underground switches,
traffic, dispatch records, a 512-by-512 city, and draw queries. A warm builder must
also match the CPU after each kind of tile, neighbor, cliff and layout edit. Its
native counterpart also checks GPU pixels. `city_gpu_geometry_test` checks batches,
atlas uploads and tile reuse. The Rust unit tests check invalidation, eviction,
atlas packing and the draw index.

## Performance measurement

Run the benchmark with Dummy audio:

```sh
godot --headless --audio-driver Dummy --path game \
  --script res://tools/benchmarks/native_region_benchmark.gd
```

The benchmark prepares 64 regions, moves to 64 new regions, returns, and then
builds the first regions again in a new city revision. It uses 128-pixel Small
regions and 256-pixel Medium/Large regions. It reports tile builds and reuses,
cached tiles and atlas changes. The times include the snapshot, artwork setup,
native geometry, the bridge and the region result. They exclude GPU uploads and
display latency. They are not frame-rate measurements or promises for other machines.

On the development Mac (Apple M3 Max) with Godot 4.7.2, the generated 512-by-512
city produced these median times for the 64-region stages. The earlier native
builder made a GDScript object for each draw; its times are from commit `af8cc01d`.

| Artwork | Stage | Earlier native | Current | Atlas changes |
| --- | --- | ---: | ---: | ---: |
| Small | pan | 176.9 ms | 19.7 ms | 1 |
| Small | new revision | not measured | 10.4 ms | 0 |
| Medium | pan | 175.9 ms | 18.8 ms | 1 |
| Large | pan | 51.9 ms | 6.6 ms | 2 |
| Large | return | 51.3 ms | 3.1 ms | 0 |

Both builders produced the same quad counts in each stage. A Small or Medium pan
paints more map cells than it caches, because the builder paints each unknown
candidate cell once to learn its bounds. Sixty-four Small regions hold more tiles
than the tile cache, so the return stage paints them again. The region mesh cache
normally serves a return to recent regions.
