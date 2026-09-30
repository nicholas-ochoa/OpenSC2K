# SC2X file version 4

OpenSC2K saves every city that the original game cannot open as an SC2X version 4
file. The file is a ZIP archive with flat entries. SC2 and SCN cities keep the original
format. SCLG files (the experimental SC2X versions 1 to 3) stay readable; a load converts
them in memory, and a save writes a new version 4 file.

## Archive

The reader selects the format from the file signature, not the extension: `PK\x03\x04`
selects version 4, and `FORM` selects the original or SCLG reader.

Every entry is at the archive root. ZIP compresses every entry with DEFLATE level 9
(`compression/formats/gzip/compression_level=9` in `project.godot`). No entry uses Maxis RLE
or another inner compression. The writer uses fixed timestamps and this entry order:

```text
metadata.json
metadata.schema.json
MISC.bin ALTM.bin XTER.bin XBLD.bin XZON.bin XUND.bin XTXT.bin XLAB.bin XMIC.bin
XTHG.bin XBIT.bin XTRF.bin XPLT.bin XVAL.bin XCRM.bin XPLC.bin XFIR.bin XPOP.bin
XROG.bin XGRP.bin XSGN.bin
SCEN.bin TEXT.bin PICT.bin TMPL.bin     (scenarios)
CUNK.bin                                 (preserved chunks, when needed)
<ID>.bin                                 (a preserved unknown chunk with a safe name)
other entries                            (unknown entries of a loaded file)
```

A file must not contain `FORM.bin`, `SCDH.bin`, `SCLG.bin`, `SIZE.bin`, or `CNAM.bin`.
The reader rejects entries in folders, repeated names, a CRC or size mismatch, missing
required entries, and entries with the wrong size.

## Metadata

`metadata.json` is UTF-8 JSON. `game/assets/data/sc2x-metadata.schema.json` is the copy of
the schema that each save includes as `metadata.schema.json`. `Sc2xMetadata` checks the same
rules; the included schema cannot relax them.

| Field | Meaning |
| --- | --- |
| `format`, `file_version` | `"OpenSC2K.SC2X"` and `4`. |
| `map.size` | The map edge. The game opens 16, 32, 64, 128, 256, 384, 512, 640, 1024, 2048, and 4096. SCLG files end at 1024; larger maps exist only as version 4 files. |
| `city.name` | The city name: 1 to 64 characters. There is no CNAM entry. |
| `city.mayor_name`, `city.stadium_teams` | The mayor name and the five shared team names. |
| `identity_counters` | The next sign ID and the next moving-object ID. |
| `simulation.rng_states` | The three 32-bit random states. `lfsr_random` must be 1 to 65535. |
| `simulation.phase_state` | Engine state that no structure holds. See [Saved simulation state](#saved-simulation-state). |
| `required_features` | Extra capabilities that a reader needs. This version supports none. `Sc2File` still loads such a file for inspection, and `compatibility_error` names the missing features; the game shows that message and does not open the city for play. |
| `legacy` | Import data: the source container, version, and chunk order, and the CNAM bytes that are not the name. |
| `extensions` | Optional data. A save keeps it. |

Names have at most 64 code points and 256 UTF-8 bytes and no NUL. JSON numbers are doubles:
integers stay exact up to 2^53.

## Binary structures

All multi-byte fields are big-endian, except the PICT dimensions. Tile planes are
column-major (`x * N + y`).

| Entry | Size | Content |
| --- | --- | --- |
| MISC | 4,800 | The original global block. MISC stays authoritative for the values it holds. |
| ALTM | 2N² | Altitude words. |
| XTER, XBLD, XZON, XUND, XBIT | N² | Tile planes. |
| XTXT | N² | Markers only: 0, or 241 through 255 (0xFA connection, 0xFB toxic, 0xFC flood, 0xFD and 0xFE riot, 0xFF fire). Values 1 through 240 are rejected. |
| XTRF, XPLT, XVAL, XCRM, XPLC, XFIR, XPOP, XROG | N² | Per-tile data maps. A conversion expands coarse maps. |
| XGRP | 3,328 | Graph history. |
| XLAB | 25L, L ≥ 256 | The compatibility label table only. Names never come from it. A new city writes 6,400 zero bytes; a conversion keeps the labels that it could not assign. |
| XMIC, XTHG, XSGN | see below | Named record collections. |
| SCEN | 64 | SCEN schema 2, only for scenarios. |
| TEXT | 16 + 16K + P | Every scenario TEXT payload, unchanged, with its source order and occurrence. |
| PICT | 8 + WH or 8 + H(W+1) | The scenario picture, unchanged. |
| TMPL | 4 + Σ(5 + name) | Descriptors of SCEN schema 2. |
| CUNK | 16 + 24K + P | Preserved chunks. |

### Named collections

XMIC, XTHG, and XSGN start with six u32 fields: `schema_version` (1), `capacity`,
`active_records`, `record_stride`, `text_bytes`, and `extension_bytes`. The fixed records
follow, then one 8-byte text index per slot (`offset:u32`, `byte_length:u16`,
`code_point_count:u16`), the UTF-8 text packed by slot with no gaps, and the extension
section. An empty name has offset, length, and count zero.

The extension section is a list of blocks: a 4-byte printable ASCII tag, a u32 length,
and the data. A reader keeps blocks with unknown tags.

**XMIC** adds `position_bytes:u32` at offset 24. Each 24-byte core holds the tile ID, the
seven original statistic bytes, the footprint bounds (`x`, `y`, `width`, `height`: u16), and a
position offset and count (u32). A complete rectangle has no tile list. A shared, irregular,
or fragmented footprint lists every owned tile as `x:u16, y:u16` in ascending column-major
order; the lists are packed by slot. A tile belongs to at most one record. Slot 0 is
reserved and a free slot (tile ID 0) has no geometry or name. Slots 1 through 9 are the
shared categories; individual records start at 10, and an active individual record owns at
least one tile. Size: `28 + 32C + 4P + T + E`.

| Extension tag | Entry | Meaning |
| --- | --- | --- |
| `ORPH` | slot u32, 8-byte working record, name length u16, UTF-8 name | An active individual record that owns no tile. Its slot is free in the core table; a load puts the record and name back. |

**XTHG** uses a 32-byte core: type (u8), direction (u8), then state, X, Y, Z, PX, PY, DX, DY,
reserved (zero), goal, ship home X + 1, ship home Y + 1, flags (u16), and the object ID (u32).
An active object has a unique nonzero ID; a free slot has no ID, name, or flags. Size:
`24 + 40C + T + E`.

| Flag bits | Meaning |
| --- | --- |
| 0 | The object occupies its tile in the runtime tile index. |
| 8 to 15 | Stacking depth of an occupant; 0 is the bottom object of its tile. |

| Extension tag | Entry | Meaning |
| --- | --- | --- |
| `LOCC` | slot u32, x u16, y u16 | An occupant whose occupied tile differs from its position. Original trains and sailboats can leave such links. |
| `LREC` | slot u32, 12 low + 12 high bytes | The working record, when the core cannot express its bytes, such as a stale label field of an object that occupies no tile. |
| `LLNK` | tile index u32, link u16, zero u16 | A working tile link that no structure describes, such as a link to a free record or an object linked from two tiles. A load writes it back after the other links. |

The application keeps XMIC and XTHG extension blocks with other tags and writes them again
on the next save.

**XSGN** uses a 12-byte core: sign ID (u32; zero marks an empty slot), X, Y, flags, and
reserved (u16). An active sign has 1 to 64 characters of text. One sign per tile; IDs are
unique. Size: `24 + 20C + T + E`.

### TEXT, CUNK, SCEN, and TMPL

TEXT and CUNK start with `schema_version`, the entry count, the index stride, and the
payload size. A TEXT index entry holds the source order, the source occurrence, and the
payload offset and length. A CUNK index entry holds the original chunk ID, the occurrence,
the source order, the payload flags, and the payload offset and length.

| CUNK flag | Meaning |
| --- | --- |
| 0x1 | The stored bytes of a chunk of unknown encoding. |
| 0x2 | A legacy structure that a version 4 structure replaced, such as a TMPL that does not describe SCEN schema 2. |

An unknown chunk with one occurrence and a name of four capital letters or digits keeps
its own `<ID>.bin` entry. Repeated unknown chunks and extra occurrences of known structures
go to CUNK.

SCEN schema 2 widens the disaster X and Y to u16 and the two building tile counts to u32.
A 52-byte scenario gets zero life-expectancy and education goals. A conversion changes the
original template to the schema 2 descriptors; a template with other descriptors goes to CUNK
with flag 0x2.

## Working documents

A loaded version 4 file becomes a working document: an `Sc2File` with `large_version` 4.
The simulation, the tools, and the renderer use its chunks in the extended layout:

- XTXT is the combined runtime tile index in two byte planes at every map size: markers,
  facility links, and the top moving object of each tile. Each occupying object keeps the
  value below it in its label field. `Sc2xDocument` rebuilds the index from the markers, the
  XMIC footprints, and the XTHG occupancy flags, and saves it the same way. The index is
  never saved.
- XLAB is a runtime label table with wide records: a u16 length and 256 UTF-8 bytes. It
  holds the mayor name, the team names, and the facility names at their original label IDs.
  Its size is never a multiple of 25 bytes, so byte-level helpers can tell it from a legacy
  table.
- XMIC holds the 8-byte records, and XTHG holds split low and high record planes. Their
  capacities come from the file.
- XSGN holds the saved sign collection. Signs are not in XTXT, so a sign can share a tile
  with a facility, a moving object, and a marker. Demolition and disasters leave signs in
  place; the sign tool changes them.
- The document keeps the metadata, the compatibility XLAB table, the object identities,
  the TEXT source orders, and the preserved chunks and entries.

`Sc2xDocument.split` and `join` (native code in `native/simulation/src/formats/sc2x`) convert
between the working chunks and the saved structures. A load followed by a save writes the same
entries. After each simulation step that changes XTHG, a slot whose object was freed or changed
type loses its identity and name; the next save gives the new object a new ID. IDs are never
reused.

The runtime tile index holds 16-bit links:

| IDs | Meaning |
| --- | --- |
| 1–50, 4096–8191 | Signs of SC2, SCN, and SCLG cities. A working document keeps signs in XSGN. |
| 51–200, 256–4095 | Facility records 0–3989. |
| 201–240, 8192–16383 | Moving-object records 0–8231. |
| 241–255 | Markers. |
| 16384–65535 | Facility records from 3990, for the 2048 and 4096 profiles. |

A working document can therefore link at most 53,142 facility records and 8,232 moving
objects, and its XTHG capacity cannot be 20 (its table would look like an original
single-plane table). The loader reports a file that exceeds them. Facility links and moving
objects still share the runtime tile index; a later version can give them separate runtime
indexes without a file change.

Trip searches pack the start tile below the transport mode: 14 bits on a 128-tile map, 20
bits up to 1024 tiles, and 24 bits on larger maps.

## Conversion

`Sc2xDocument.from_legacy` makes a working document from an SC2, SCN, or SCLG document
without changing the source:

1. Expand coarse data maps to one value per tile.
2. Follow each tile link through covering objects. Save markers, facility footprints, and
   object occupancy. Signs become XSGN records with new IDs; covered signs are kept.
3. Move the city name to metadata, and keep the unparsed CNAM bytes in `legacy.cnam`.
4. Move the mayor and team names to metadata, and facility, sign, and object names to their
   records. The other labels stay in the compatibility XLAB table.
5. Upgrade SCEN and TMPL; keep TEXT and PICT unchanged; preserve other chunks.
6. Report links that the new structures cannot hold, such as an object linked from two
   tiles, and keep them unchanged in `LLNK` and `ORPH` blocks. The report is shown after
   the load.

Record capacities become the larger of the source capacity and the map profile.

The application converts an SCLG file when it loads it, and an SC2 city when the player
chooses **Upgrade City to SC2X**. A converted city has no file of its own until the player
saves it; a save never replaces the source file. New cities that are not original cities
are version 4 cities.

## Saving

`CityFileStore.prepare` checks the target, stores the simulation state, and copies the raw
entries on the main thread. `CityFileStore.write` compresses the copy, writes a temporary
file beside the target, closes it, reads it back, loads it, and checks that it holds the same
entries before it replaces the target. A failure keeps the previous file. Cities larger than
256 tiles write on a worker thread, so the game keeps running during the save.

Measured on this computer (Spiralopolis test cities, converted from SCLG version 3):

| Map | SCLG file | Raw entries | SC2X v4 file | Load | Prepare | Compress and write |
| --- | --- | --- | --- | --- | --- | --- |
| 512 | 3,027,844 | 4,449,580 | 966,006 | 12 ms | 12 ms | 395 ms |
| 1024 | 11,882,820 | 17,250,193 | 2,027,091 | 35 ms | 47 ms | 784 ms |

The supplied 128-tile cities save as 6 to 58 KB, against 54 to 125 KB in the original format.

`game/tools/tile_sc2x_city.gd` repeats a city across a larger map (for example, the 1024
Spiralopolis test city as 2048 and 4096 cities). Measured with those tiled cities: a 2048 city
loads in the game in 2.0 s and a 4096 city in 8.0 s, most of it the load-time repair of the
more than 100,000 facility buildings that the test city has without records. A 4096 city
takes about 100 ms per simulation day and about 5 s to compress and write on the worker
thread; a terrain brush step takes about 16 ms. A 4096 working document with its city state
uses about 700 MB. The map window samples every fourth tile of a 4096 map, so its image stays
at 1024 pixels.

Slower retained tests, each with its reason: `large_city_test` (about 5 s) runs the far-corner
tools, a spawn, a rotation, and a reload on a 4096 city; `sc2x_reference_conversion_test`
(about 5 s) converts all 92 supplied cities and scenarios; `map_edge_limits_test` (about 4 s)
adds the far-edge rules at 2048; and `sc2x_format_test` (about 3 s) saves, loads, and rotates a
4096 city with a high-range facility.

A city can be saved only at a completed simulation day. While the annual budget or a
military decision waits for the player, the save reports what to finish first.

### Saved simulation state

`simulation.phase_state` holds these engine and speed-controller values:
`ship_home`, `commerce_connections`, `industry_connections`, `bus_passengers`,
`rail_passengers`, `subway_passengers`, `mayor_approval`, `pending_disaster_type`,
`pending_disaster_point`, `active_disaster_type`, `unsupported_disaster_type`,
`disaster_map_counter`, `disaster_hurricane_counter`, `terminal_state`, `subtick_counter`,
`simulation_ready`, and the load-scan results `developed_tiles`, `power_usage_percent`,
`water_usage_percent`, and `city_status_resource_id`.

A file with this state loads without a new power and water scan, so the next days run as
they would have without the save. The frame timing accumulators, the fire timer, the
traffic news deadline (a process clock), music playback, the vehicle layer switch, and pause
targets are runtime state and are not saved. An empty `phase_state` means the load defaults,
as after a conversion.

## Record and vehicle limits

`native/simulation/src/formats/sc2x/limits.rs` holds the default capacities and the ordinary
vehicle caps of each map size.

| Map size | XMIC | XSGN | XTHG | Airplanes | Helicopters | Ships | Sailboats | Trains |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 16 | 64 | 16 | 16 | 1 | 1 | 1 | 1 | 1 |
| 32 | 64 | 16 | 32 | 2 | 1 | 1 | 2 | 1 |
| 64 | 128 | 32 | 64 | 2 | 1 | 1 | 4 | 8 |
| 128 | 256 | 128 | 128 | 2 | 1 | 1 | 4 | 8 |
| 256 | 512 | 256 | 256 | 4 | 2 | 2 | 8 | 16 |
| 384 | 1,024 | 256 | 384 | 4 | 2 | 2 | 8 | 16 |
| 512, 640 | 1,024 | 512 | 512 | 8 | 4 | 4 | 16 | 32 |
| 1024 | 2,048 | 512 | 512 | 16 | 8 | 8 | 32 | 64 |
| 2048 | 8,192 | 512 | 1,024 | 32 | 16 | 16 | 32 | 128 |
| 4096 | 32,768 | 1,024 | 2,048 | 64 | 32 | 32 | 64 | 256 |

The plan defines sizes through 2048. The 4096 profile doubles the moving objects, signs, and
vehicle caps of 2048 and gives four times its facility records for four times the area.

- A new city uses these capacities exactly. An imported collection keeps a larger capacity;
  creation then stops while the active records fill the budget, and nothing is deleted.
- A facility that needs an individual record (slots 10 and up) is refused with a message when
  the budget is full. An arcology never takes the record of another facility.
- The vehicle caps apply to every creation path, including disaster aircraft. The train cap
  counts surface and subway engines. A train takes its three records at once and never uses
  record 0. Each sailboat of a batch checks the cap.
- New moving objects stop when the active records reach the pool budget (capacity − 1).
- New signs stop at the sign budget.

SC2, SCN, and SCLG cities keep the original allocation rules.

## Code

- `game/src/formats/sc2x_document.gd`: archive read and write, conversion, and working documents.
- `game/src/formats/sc2x_metadata.gd`: metadata rules.
- `game/src/formats/zip_archive.gd`: the in-memory ZIP codec, which checks each CRC-32.
- `game/src/model/city/sign_table.gd`: sign lookup and edits.
- `game/src/simulation/core/sc2x_checkpoint.gd`: saved simulation state.
- `native/simulation/src/formats/sc2x`: the binary structures, the projection, and the limits.
