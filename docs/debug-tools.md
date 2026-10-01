# Debug tools

Open the Debug window with F12 or Windows > Debug. On the Actions tab, select
**Enable debug mode**. The choice is kept in the settings file (`[debug] enabled`).

Debug mode adds:

- A **Debug** menu on the menu bar.
- Two Query tools: **Trip Query** and **Tile Inspector**. Without debug mode, the Query
  palette shows only Query, and a debug tool cannot be selected.

When you turn debug mode off, all debug views close. If a debug tool is selected,
the Query tool replaces it.

## Tile Inspector

Point at a tile to see its stored values:

- the XBLD, XZON, XTER and XUND bytes
- the land, water and tunnel fields of the ALTM word
- the decoded XBIT flags
- each overlay layer
- each data map value
- the moving object on the tile
- the value of the active debug tile layer

Click to pin the panel to a tile. Click the same tile again, or press Escape, to unpin it.

## Debug menu

| Item | Effect |
| --- | --- |
| Tile Layer | Tints the tile tops with one value per tile. The groups are the raw tile bytes (zone type, building, terrain and underground IDs, overlay kind, ALTM fields), each XBIT flag, the raw data map bytes, and analysis layers. A key shows the colors. |
| Show Tile Values | Shows the layer value on each tile at a close zoom. At most 1,200 tiles get text. |
| Change Baseline, Take Change Snapshot | Select what **Changed Tiles** compares with: the city when it loaded, a snapshot that you take, or the start of the last simulated day. The key gives the count for each changed array. MARK flags are ignored. |
| Region Bounds | Outlines the render regions. Green is ready, yellow is stale, blue is building, red is missing. Faint outlines are regions painted ahead of the view. |
| Region Repaints | Shows each region that is published again, for a moment. |
| Occlusion Rectangles, Sprite Bounds | Outline the foreground commands and all sprite draws in the view, and the moving sprites. |
| Moving Thing Paths | Marks each moving thing in the view, its record and type, and the line to its target tile. |
| Performance HUD | Shows frame rate, frame times, draw calls, memory, simulation day cost and region state, with a graph of the last 240 frames. The Metrics tab of the Debug window also shows the engine counters. |
| Capture Screenshot and State | Saves `screen.png` and `state.json` in a new folder under `debug_captures` in the application data folder. The JSON file holds the debug metrics, the camera, the hovered tile, the inspector text and the active debug views. |

The analysis layers:

- **Power Grids** and **Water Networks** connect the tiles whose POWERABLE or PIPED flag is
  set to their four side neighbors. Each network gets its own hue. A network that holds a
  powered or watered tile is bright. The key gives the network counts.
- **Unusual Values** marks values that no known table names: a zone type above 9, an
  unused terrain or underground ID, and a MARK flag that a scan left set.

## Performance

The views are for large maps too:

- The tile layer draws only a window of tile tops around the view: at most 512 by 512
  tiles. The native library builds the window again only when the view leaves it or the
  terrain changes.
- A worker thread builds the layer values from shared copies of the city arrays. A build
  starts only when a source chunk changes. After a slow build, the next one waits longer.
- Native code makes the network labels, the tile differences and the moving thing rows.
  The draw outlines come from the native region draw index.
- Each line list is one draw call, and it changes only after a pan, a zoom or a region
  publish. Repaint highlights have their own canvas.

To measure the views in a window, use the Dummy audio driver:

```sh
godot --audio-driver Dummy --path game --script res://tools/benchmarks/debug_view_benchmark.gd -- \
  <city> [image folder]
```

The benchmark pans at Cheetah speed and prints the frame times of each view and of all
views together. It can also save a window image of each view.
