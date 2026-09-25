# Media pack format

OpenSC2K loads the original game assets from packs. A pack is a folder that
contains a UTF-8 `pack.json` file and the files that it refers to. These are
OpenSC2K formats. They are not original SimCity 2000 formats.

There are four pack kinds:

| Kind | `format` value | Content | Automatic location |
| --- | --- | --- | --- |
| Graphics | `opensc2k-graphics` | Palettes, city sprites, and interface images as indexed PNG files | `user://packs/graphics/pack.json` |
| Sound | `opensc2k-sound` | Sound effects as WAV files | `user://packs/sound/pack.json` |
| Music | `opensc2k-music` | Music as MIDI files or recordings | `user://packs/music/pack.json` |
| Data | `opensc2k-data` | Original game data files: text, newspaper data, the city template, cities, scenarios, and SCURK tile sets | `user://packs/data/pack.json` |

The game needs a graphics pack. Sound, music, and data packs are optional. The
game can run without them, but some features are then not available. Packs do
not change city files or simulation rules.

Do not share packs that contain original game assets. Each player must import
the assets from their own copy of the game.

## Select packs

Use Settings to select each pack:

- Graphics tab: Graphics pack.
- Audio tab: Sound Pack and Music Pack.
- Import Data tab: Data pack.

Each field contains the path of a `pack.json` file. Select Browse to choose the
file. Keep a field empty to use the automatic location of that pack kind. If a
sound, music, or data location has no `pack.json` file, the game continues
without that pack. If there is no valid graphics pack, the main menu disables
the city and SCURK actions and shows Import Assets with a flashing border.

The name of each loaded pack shows at the right of its field. When you type or
select a different file, the name disappears until Apply loads that file. Point
to a long name to read all of it.

Apply loads the new packs immediately. A new graphics pack changes the city,
the toolbar, and the interface. A new sound or music pack reloads the sound
effects and restarts the music. A new data pack changes the text, the city
template, and the city and scenario folders. If a selected pack is not valid,
the game shows an error and keeps the packs that it uses now.

The import dialog selects the packs that it makes. Refer to
[Import original game files](#import-original-game-files).

### Environment variables for development

These variables select a pack for one run. They override the Settings value.

| Variable | Value |
| --- | --- |
| `OPENSC2K_GRAPHICS_PACK` | Graphics pack folder or `pack.json` file |
| `OPENSC2K_DATA_PACK` | Data pack folder or `pack.json` file |
| `OPENSC2K_SOUNDTRACK_DIR` | Folder of music recordings. Refer to [Music recordings](#music-recordings). |
| `OPENSC2K_FFMPEG` | Path of the FFmpeg program that decodes FLAC recordings |

## Common rules

Each `pack.json` file contains one JSON object with these fields:

| Field | Type | Rule |
| --- | --- | --- |
| `format` | string | Required. One of the four `format` values above. |
| `version` | number | Required. Must be `1`. |
| `name` | string | Required. The display name. It must not be empty. |
| `import_revision` | integer | Optional. The importer writes it. Refer to [Import revision](#import-revision). |
| `source_platform` | string | Optional. The importer writes the platform of the source game, for example `Windows`. |

The game ignores top-level fields that this document does not specify.

A path in a manifest is relative to the folder that contains `pack.json`.
Use forward slashes. Do not use absolute paths, backslashes, colons, empty path
components, `.`, or `..`. Each file must exist. Some file systems make file
names case-sensitive, so use the exact case.

A loader accepts the pack folder or the `pack.json` file.

## Import revision

The importers write `import_revision` in each pack that they make. The value
tells which revision of the importer content the pack contains. Each pack kind
has a current revision in `ImportedPackRevision.CURRENT` in
`game/src/assets/imported_pack_revision.gd`. The current revision is `1` for
all four kinds.

When an importer adds content to a pack kind or changes it, increase the current
revision of that kind. Packs of that kind with a lower revision are then out of
date.

The game reads the revision of a pack as follows:

1. If `import_revision` is present, the game uses its value. The value must be
   a whole number that is not negative. Otherwise, the pack is not valid.
2. If `import_revision` is not present, and the pack has `source_platform`,
   has `runtime_data`, or has a name that starts with `Original SimCity 2000`,
   an importer made the pack before importers recorded a revision. The game
   uses revision `1`.
3. In all other conditions, a person made the pack. The game never marks it out
   of date.

At startup, when a graphics pack is loaded, the game checks the active packs.
It shows the Update imported packs dialog if one or more of these conditions
are true:

- An imported graphics, sound, music, or data pack has a revision that is lower
  than the current revision of its kind.
- No valid data pack is loaded.

The dialog lists only those pack kinds. Import opens the import dialog with
only those kinds selected. Later closes the dialog. An out-of-date pack stays
active until a new import replaces it.

## Graphics pack

```json
{
  "format": "opensc2k-graphics",
  "version": 1,
  "name": "Example graphics pack",
  "import_revision": 1,
  "palette": "palette.png",
  "scenario_palette": "scenario-palette.png",
  "large_sprites": [{"id": 1000, "png": "large/0000-1000.png"}],
  "small_medium_sprites": [{"id": 14, "png": "small/0000-14.png"}, {"id": 514, "png": "medium/0466-514.png"}],
  "ui": {
    "toolbar_art": "ui/toolbar_art.png",
    "industry_icons": "ui/industry_icons.png",
    "city_map_icons": "ui/city_map_icons.png",
    "simnation_sprites": "ui/simnation_sprites.png",
    "forest_protest_image": "ui/forest_protest_image.png"
  },
  "redraw_small_highway_ground": false
}
```

This example shows the schema. A playable pack contains all the sprite records.

| Field | Rule |
| --- | --- |
| `palette` | Required. Indexed PNG that supplies the 256-color city palette. |
| `scenario_palette` | Required, except in a partial pack. Indexed PNG that supplies the 256-color scenario palette. |
| `large_sprites` | Required. Array of sprite records for the large city view. It must not be empty, except in a partial pack. |
| `small_medium_sprites` | Required. Array of sprite records for the small and medium city views. It must not be empty, except in a partial pack. |
| `ui` | Required, except in a partial pack. Object with the five interface image paths shown above. Other names are not valid. |
| `partial` | Optional boolean. The default is `false`. Refer to [Partial packs](#partial-packs). |
| `redraw_small_highway_ground` | Optional boolean. The default is `false`. Keep `false` for original artwork. |
| `city_ui` | Optional. Refer to [City interface images](#city-interface-images). |
| `desktop` | Optional. Refer to [Icons and cursors](#icons-and-cursors). |
| `scurk` | Optional. Refer to [SCURK images](#scurk-images). |
| `scenario_pictures` | Optional. Refer to [Scenario pictures](#scenario-pictures). |

A sprite record is an object with these fields:

| Field | Rule |
| --- | --- |
| `id` | Integer from 0 through 65535 |
| `png` | Path of an indexed PNG file |

Sprite IDs below 500 are small sprites. IDs from 500 through 999 are medium
sprites. IDs from 1000 are large sprites. The same ID can occur more than one
time. The order of the records sets the duplicate index of each copy. The last
record with an ID supplies that ID for a normal look-up. Keep the original
record order.

The game gets the size of each sprite from its PNG file. Keep the original
dimensions and footprints for normal artwork.

A graphics pack must contain at least one asset. The game uses a graphics pack
only if both sprite arrays contain records and the city palette is valid.

### Partial packs

With `partial: true`, a pack can omit `scenario_palette`, can supply an empty
sprite array, and can supply only some of the `ui` images. The multi-platform
importer writes partial packs because some game versions do not contain all
the assets. The game still needs both sprite arrays to use the pack.

If a partial pack supplies only one sprite array, its city palette must be the
same as the active city palette. This prevents a color change in the other
sprite group.

### PNG rules

These rules apply to all PNG files in a graphics pack:

- Use 8-bit indexed color with a palette of exactly 256 entries.
- Each dimension must be from 1 through 4096 pixels.
- Transparency is binary. Each palette entry is fully transparent or fully
  opaque.

Sprites, SCURK images, and scenario pictures must use the same palette, in the
same order, as their pack palette. Keep duplicate colors and their indices.
The indices control color animation. The `ui`, `city_ui`, and `desktop` images
can use their own palettes.

### Interface images

The five `ui` images are:

| Name | Content |
| --- | --- |
| `toolbar_art` | Toolbar button art |
| `industry_icons` | City Industry window icons |
| `city_map_icons` | City map window icons |
| `simnation_sprites` | SimNation window sprite sheet |
| `forest_protest_image` | Picture for the citizen objection notice |

When an image is not in the pack, the game uses its built-in controls where
they are available.

### City interface images

`city_ui` is an object that contains one or more of the groups below. Each
group is an array of records with an `id` and a `png` path. Each group can
contain some or all of its IDs. Each ID can occur only one time. Each image
must be opaque and must have the size shown.

| Group | IDs and sizes |
| --- | --- |
| `controls` | `ADVICED`, `ADVICEF`, `ADVICEU`: 30 by 25. `BOOKD`, `BOOKF`, `BOOKU`: 30 by 24. `CHECKD`, `CHECKF`, `CHECKU`: 16 by 16. `MAPBUTTONIMAGED`, `MAPBUTTONIMAGEU`: 26 by 20. `PAPERCLOSED`, `PAPERCLOSEU`: 13 by 12. `ADVISBTN.BMP`: 20 by 16. `BOOKBTN.BMP`: 40 by 32. |
| `hourglass` | 189 through 195: 16 by 30. 196: 15 by 30. |
| `portraits` | 197 through 204: 64 by 82. |
| `terrain` | 139: 65 by 65. 207: 544 by 19. `TERRAIN.BMP`: 341 by 19. |
| `media` | 261, 262, `WILL0D.BMP`, `WILL0U.BMP`: 140 by 70. 263 through 270 and `WILL1D.BMP` through `WILL4U.BMP`: 70 by 70. |
| `notices` | 400 through 410: 155 by 100. 411: 154 by 100. |
| `presentation` | `128.BMP`: 106 by 53. `2000WIN.BMP`: 371 by 331. `ABOUT.BMP`: 480 by 299. `PRESNTS.BMP`: 238 by 198. `TITLESCR.BMP`: 644 by 484. `PAL_LOAD.BMP`, `PAL_MSTR.BMP`, `PAL_STTC.BMP`: 101 by 101. |
| `checks` | `CTL3D_3DCHECK`: 70 by 39. |

Numeric IDs are JSON numbers. Name IDs are JSON strings.

### Icons and cursors

`desktop` is an object with a `city` group, a `scurk` group, or both. Each group
is an object with `icons`, `cursors`, or both. Each of these is an array of
records with an `id` and a `png` path. Each ID can occur only one time.

| Group | Icon IDs | Cursor IDs |
| --- | --- | --- |
| `city` | 1 through 10 | 11 through 111 |
| `scurk` | 1 through 8 | 1 through 34 |

The IDs are the image resource IDs in the original executables. An icon with
an even ID is 16 by 16. An icon with an odd ID is 32 by 32. The exception is
city icons 9 and 10: icon 9 is 16 by 16 and icon 10 is 32 by 32. All cursors
are 32 by 32.

A cursor record also needs `hotspot`, an array of two integers from 0 through
31. It can also have `and_png`, the path of an AND mask. The mask must have the
same size as the cursor. Its pixel indices must be 0 or 1. When a cursor has a
mask, its main image must be opaque.

### SCURK images

`scurk` is an object with these groups. Each group is an array of records in
the order shown. Each record has an `id` and a `png` path. The array must
contain all the IDs of its group. The images must use the pack palette and
must be opaque, except where the table shows otherwise.

| Group | Required | IDs, in order | Size |
| --- | --- | --- | --- |
| `textures` | Yes | 25039, 25040, 25041, then 25000 through 25038 | 8 by 8 |
| `backgrounds` | Yes | 20015, 20018, 20019, 20020, 20021 | 128 by 256 |
| `controls` | No | 20000 through 20013, 20016, 20017, 21000 through 21007, 21018, 21019, 21020 | 20 by 20 |
| `workspace` | No | Refer to the list below | Refer to the list below |
| `presentation` | No | 123, 124, 125 | 123 and 124: 128 by 256, and transparency is permitted. 125: 640 by 480. |

Each `textures` record also needs `name`, a text that is not empty. The editor
shows this name for the texture.

The `workspace` IDs and sizes, in order, are:

- 1200: 33 by 25. 1201: 32 by 24. 1202, 1203, 1204: 33 by 25.
- 1205 through 1215: 32 by 24.
- 20014: 64 by 64. 21008, 21009: 8 by 8. 21021: 48 by 208.
- 22001, 22002: 10 by 10. 22003, 22004: 16 by 16. 22005: 256 by 256.
- 22100, 22101: 26 by 26. 22103, 22104: 24 by 24. 22105: 100 by 24.
- 22106: 8 by 8. 22107: 48 by 8. 22108: 48 by 300. 22109: 48 by 8.
- 22110: 64 by 64. 23000: 400 by 200.

Image 22005 is the palette sheet. It has 16 by 16 cells. The center pixel of
cell `n` must use palette index `n`. The cells go from left to right, then from
top to bottom.

### Scenario pictures

`scenario_pictures` is an array of records that replace the pictures of
scenario files. The pack must have `scenario_palette`.

| Field | Rule |
| --- | --- |
| `id` | Text that is not empty. Each record must have a different ID. |
| `pict_sha256` | Lowercase hexadecimal SHA-256 of the scenario's decoded `PICT` chunk. Each record must have a different value. |
| `png` | Path of an opaque indexed PNG that uses the scenario palette |

The game shows the replacement picture only if its size is the same as the
original picture. A change to the scenario file name does not change its
picture.

## Sound pack

```json
{
  "format": "opensc2k-sound",
  "version": 1,
  "name": "Example sound pack",
  "import_revision": 1,
  "files": {
    "505": "505.wav",
    "508": "508.wav"
  }
}
```

`files` is a required object. Each key is a sound ID from `500` through `529`.
Write the key as a decimal number in a JSON string, without leading zeros. Each
value is the path of a WAV file. The file extension must be `.wav`. Each file
must decode with the Godot WAV loader. Use PCM WAV files. An empty `files`
object is permitted.

An imported pack contains all 30 original files. For example, sound `505` is
the Center and toolbar sound. Sound `508` is the tractor sound of the land
tools and the held Bulldozer.

A sound that the pack does not contain is silent. A tool sound that loops
plays the complete WAV file again. Other sounds play one time. The normal
repeat limits of game sounds stay in effect. The toolbar sound plays at each
activation. The Sound Effects setting, the effects volume, the background audio
setting, and the toolbar sound setting control playback. The toolbar sound
setting does not stop the sounds of the land tools.

## Music pack

```json
{
  "format": "opensc2k-music",
  "version": 1,
  "name": "Example music pack",
  "import_revision": 1,
  "files": {
    "10001": "10001.mid",
    "10004": "tracks/disaster.ogg"
  }
}
```

`files` uses the same rules as the sound pack, with track IDs from `10000`
through `10018`. The file extension must be `.mid`, `.midi`, `.wav`, `.ogg`,
`.mp3`, or `.flac`. The extension is not case-sensitive.

The game reads each MIDI file when it loads the pack. A MIDI file that does not
decode makes the pack not valid. The built-in synthesizer plays MIDI files. The
game decodes a recording when it plays it. Godot decodes WAV, Ogg Vorbis, and
MP3 files. FFmpeg decodes FLAC files. The game looks for FFmpeg in the usual
install locations. Set `OPENSC2K_FFMPEG` to the path of a different FFmpeg
program.

An imported pack contains all 19 original MIDI files, copied without a change.
The game selects tracks with its own rules. The title track is `10001`. The
general cycle is `10001`, `10004`, `10008`, `10012`, and `10018`. The disaster
track is `10004`. The recreation track is `10010`. A pack cannot add track IDs.

### Music recordings

The game can also play recordings from a soundtrack folder. The folder is
`OPENSC2K_SOUNDTRACK_DIR` when this variable is set. Otherwise, it is the `OST`
folder in the data pack. A recording file name must be the track ID, or the
track ID followed by ` - ` and a title. For example: `10001 - Main Theme.ogg`.
The file extension must be `.flac`, `.ogg`, or `.mp3`.

For each track, the game uses the first available source in this order:

1. The music pack entry for the track.
2. A recording in the soundtrack folder.

If there is no source, the track does not play.

## Data pack

```json
{
  "format": "opensc2k-data",
  "version": 1,
  "name": "Example data pack",
  "import_revision": 1,
  "source_platform": "Windows"
}
```

A data pack contains copies of original game data files. The files keep their
original relative paths in the pack folder. The manifest has no file list.

| Path | Required | Use |
| --- | --- | --- |
| `DATA/TEXT_USA.DAT`, `DATA/TEXT_USA.IDX` | Yes | Game text, for example the Library text and the original credits |
| `DATA/DATA_USA.DAT`, `DATA/DATA_USA.IDX` | Yes | Newspaper data |
| `DEFAULT.SC2` | Yes | Template for New City, and the main menu background city when there are no cities |
| `CITIES/` | No | Sample cities for Open City and the main menu background |
| `SCENARIO/` | No | Scenarios for Play Scenario |
| `SCURKART/` | No | SCURK tile sets. SCURK opens `SCURKART/ORIGINAL.MIF` when no other tile set is active. |

The importer copies the complete text and newspaper files. A new game feature
can use more of these files without a new import. A data pack never contains an
executable file.

The game loads the data pack only if all the required files are present and the
text and newspaper files are valid.

Open City and Play Scenario start in `user://cities` and `user://scenarios`
when these folders exist. Otherwise, they start in the `CITIES` and `SCENARIO`
folders of the data pack. The game does not save a city in the data pack
folder.

Without a data pack, the game still runs, but these features change:

- New City uses a built-in city template.
- The newspaper has no article text.
- The Library Ruminate action shows an error.
- The About window has no original credits.
- The game shows the Update imported packs dialog at startup.

## Import original game files

Settings > Import Data > Import SimCity 2000 opens the import dialog. Import
Assets on the main menu opens the same Settings tab.

1. Select a source: an installed game folder, a macOS `.app` bundle, or
   extracted game files. Install a GOG download before you import it. Do not
   select an installer file.
2. Select the pack kinds to import: Graphics, Sounds, Music, and Game data.
   All four are selected by default.
3. Select Import.

The importer reads the source files. It does not run the original game or
change the source files. It identifies the platform of the source: `Windows`,
`Windows 3.x`, `Windows Network Edition`, `DOS`, or `Macintosh`. A folder with
assets from more than one platform is not valid.

The importer makes a new folder in `user://packs` for each import. The folder
name starts with the platform name. The folder contains `graphics`, `sound`,
`music`, and `data` subfolders for the kinds that imported successfully. The
importer checks each kind separately. The game activates each successful kind
immediately and saves its path in Settings. A kind that fails or that you did
not select keeps its current pack. Each import makes a new folder. The dialog
lists the saved paths, the partial results, the missing assets, and the
activation errors.

Some assets need a complete Windows installation. A complete installation
contains `SIMCITY.EXE` and these files:

- `DEFAULT.SC2`
- `DATA/DATA_USA.DAT`, `DATA/DATA_USA.IDX`, `DATA/TEXT_USA.DAT`, `DATA/TEXT_USA.IDX`
- `DATA/LARGE.DAT`, `DATA/SMALLMED.DAT`, `DATA/SPECIAL.DAT`
- `BITMAPS/403.BMP`, `BITMAPS/NEIGHBOR.BMP`, `BITMAPS/PAL_MSTR.BMP`, `BITMAPS/PAL_MAC.BMP`
- `SCURKART/ORIGINAL.MIF`
- `WINSCURK.EXE`

With a complete Windows installation, the importer also adds these groups to the
graphics pack: the `city_ui` portraits, terrain strip 207, and notices; the
`desktop` icons and cursors; and the `scurk` textures and backgrounds. The Game
data kind needs a complete Windows installation. With another source, the
Game data import fails and the other kinds continue.

### Make example packs for development

This command exports the four packs from `references/SIMCITY2000` to `ext/`:

```sh
godot --headless --audio-driver Dummy --path game \
  --script res://tools/export_original_packs.gd
```

To use other folders, add the source folder and the output folder as
arguments. The exporter does not write to an existing pack folder. Use a new
output folder to make another copy. Tests use the packs in `ext/`. Git ignores
`ext/graphics`, `ext/sound`, `ext/music`, and `ext/data` because they contain
original assets.

## Saved-data location

Godot maps `user://` to these folders:

- macOS: `~/Library/Application Support/Godot/app_userdata/OpenSC2K/`
- Windows: `%APPDATA%\Godot\app_userdata\OpenSC2K\`
- Linux: `~/.local/share/godot/app_userdata/OpenSC2K/`

The game does not search the repository `references/`, `ext/`, or `local/`
folders. To use a pack from `ext/`, select it in Settings or set an
environment variable.
