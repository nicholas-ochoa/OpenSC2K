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

The status bar of the Debug window shows the file format of the open city: SC2,
SC2 scenario, SCLG (an experimental SC2X version, which saves as version 4) or SC2X
version 4. The tooltip of the city name on the menu bar and the Metrics tab (City
file) also show it.

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
| Tile Grid and Coordinates | Outlines every tile in the view and shows tile coordinates. At a far zoom, every 2nd to 64th tile has text. |
| Draw Order | Shows the painter index of each sprite draw in the view, and the depth of foreground draws. It needs the GPU region renderer and at most 600 draws in view. |
| Freeze Palette Cycling | Stops the animated palette colors, for stable images. |
| Check Missing Artwork | Paints the tiles around the view with placeholders on a worker thread, and shows each tile that needs a sprite that the artwork lacks as the Missing Artwork layer. |
| Repair Bad Terrain | Repairs the bad terrain of sc2kfix: dry tiles whose own water level is above the city water level and their land. It finds the water level of the map from its water tiles, sets it on each bad tile, and marks a tile below it as water. **Undo Edit** restores ALTM and XBIT together. |
| Find Orphaned Labels, Remove Orphaned Labels | List, or clear, the sign labels that no tile shows, as sc2kfix does. A cancelled sign in the original game leaves its XLAB text. **Undo Edit** restores removed labels. SC2X version 4 cities keep signs in sign records and have none. |
| Advance One Phase, Advance One Day | Step the paused simulation. See [Steps](#steps). |
| Preview Disaster at View Center | Runs the disaster for 20 ticks in a copy of the simulation and shows the tiles that it would change as the Disaster Preview layer. The city and its random states do not change. |
| Verify Save | Saves a copy of the city to a temporary file with the normal save path, loads it again, and compares every chunk. A second save of the loaded file must write the same content. A dialog lists each chunk. The open city and its save path do not change. |
| Undo Debug Edit | Reverses the last record or MISC edit. |
| Performance HUD | Shows frame rate, frame times, draw calls, memory, simulation day cost and region state, with a graph of the last 240 frames. The Metrics tab of the Debug window also shows the engine counters. |
| Capture Screenshot and State | Saves `screen.png` and `state.json` in a new folder under `debug_captures` in the application data folder. The JSON file holds the debug metrics, the camera, the hovered tile, the inspector text and the active debug views. |

The analysis layers:

- **Power Grids** and **Water Networks** connect the tiles whose POWERABLE or PIPED flag is
  set to their four side neighbors. Each network gets its own hue. A network that holds a
  powered or watered tile is bright. The key gives the network counts.
- **Unusual Values** marks values that no known table names: a zone type above 9, an
  unused terrain or underground ID, a MARK flag that a scan left set, and sc2kfix bad
  terrain (dry land under a water level above the city's).

For a residential, commercial or industrial tile, a pinned Tile Inspector also shows the
growth inputs: the month day of the tile's growth visit, power, nearby transport, the
trip of the Trip Query, the class demand and the growth pressure of a completed trip,
the land value that the next density needs, and the density advance chance. A pinned
tile with a moving object lists each decoded field of the object.

## Debug window tabs

- **Actions.** Simulation and view actions, run to date and cheats. *Military base*
  offers a base by the game rules, or proposes an Air Force Base, Army Base, Naval Yard
  or Missile Silos: if you accept, the game searches only for a site of that type.
  *Moving things* adds a moving thing, or deletes every moving thing of the selected
  kind, as the original Debug menu does.
- **MicroSims, Moving Things, Tile Counts and State.** A virtual table draws only the
  rows in view. MicroSims and Moving Things build a row only when it is drawn, sorted or
  searched, and keep their rows until their chunks change, so the 32,768 MicroSim records
  of a 4096 city open in about 0.1 s. A search of more than 2,000 records waits for a
  pause in typing. In MicroSims and Moving Things, double-click a field to change the
  stored value. The edit checks the range of the field. *Undo edit* reverses it.
- **Steps.** <a id="steps"></a>Advance one phase runs the next action of the day
  schedule; the day stays open until its last action runs, and a speed change runs the
  rest of the day first. Advance one day runs a whole day, or one tick of an active
  disaster. The log lists the time, the changed tiles (on maps up to 1024 tiles) and the
  changed chunks of each step. A phase step runs each action as its own native call; the
  game runs a whole day in one call.
- **Chunks.** Every chunk with its size, revision and kind, preserved SC2X entries, and a
  hex view. Bytes that changed since the mark are marked: the city at load in debug mode,
  or *Mark bytes now*. *Export chunk* writes the decoded bytes to
  `debug_captures/chunks`. The mark keeps the chunks as they were, so it holds a copy of
  each chunk that changes later.
- **MISC.** The city values and every MISC word, with the Sc2MiscLayout names. Double-click
  a value to change a word. A change writes only that word: tiles, data maps and other
  chunks stay the same, and code that reads the word uses the new value the next time it
  runs. For example, WATER_LEVEL records the sea level, but the water on the map comes
  from each tile's ALTM, XTER and XBIT values; the word sets pump supply at the next
  water scan and the start of Raise and Lower Sea Level. The Notes column names the
  readers of some words.
- **Scenario.** The scenario goals with their current values and requirements, the
  scenario disaster tile, and the disaster preview with a tick count.

Every edit is a debug edit: it does not follow game rules, and a save keeps it.

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

`res://tools/benchmarks/debug_table_benchmark.gd` takes the same arguments and reports
the open, sort and search times of each record table and the frame times while it is
open.

The view benchmark pans at Cheetah speed and prints the frame times of each view and of all
views together. It can also save a window image of each view.
