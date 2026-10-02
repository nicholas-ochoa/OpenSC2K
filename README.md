# OpenSC2K

An open-source remake of SimCity 2000, built with Godot.

Join our [Discord community](https://discord.gg/k9S6c3AqcX).

[![OpenSC2K main menu over a waterfront city](.github/screenshots/image1-preview.png)](.github/screenshots/image1.png)

## Screenshots

Click a thumbnail to view the full screenshot.

<p>
  <a href=".github/screenshots/image1.png"><img src=".github/screenshots/thumbnails/image1.png" width="260" alt="Main menu" /></a>
  <a href=".github/screenshots/image2.png"><img src=".github/screenshots/thumbnails/image2.png" width="260" alt="City and terrain overview" /></a>
  <a href=".github/screenshots/image3.png"><img src=".github/screenshots/thumbnails/image3.png" width="260" alt="Waterfront city with bridges and a seaport" /></a>
  <br />
  <a href=".github/screenshots/image4.png"><img src=".github/screenshots/thumbnails/image4.png" width="260" alt="Water supply data view" /></a>
  <a href=".github/screenshots/image5.png"><img src=".github/screenshots/thumbnails/image5.png" width="260" alt="Transport routes in the trip query view" /></a>
  <a href=".github/screenshots/image6.png"><img src=".github/screenshots/thumbnails/image6.png" width="260" alt="SCURK sprite editor" /></a>
</p>

## Run

Download a package from [GitHub Releases](https://github.com/nicholas-ochoa/OpenSC2K/releases).
See the [installation instructions](docs/install.md) for Windows, Linux, and macOS.
The packages include the engine. You do not need to install Godot.

To run from source:

Use Godot 4.7 and provide your own copy of SimCity 2000 Special Edition for Windows 95 (1996).
The simulation is a native library written in Rust. Install Rust with [rustup](https://rustup.rs).
`rust-toolchain.toml` selects the Rust version.

Before the first run of a fresh checkout, build the native simulation from the repository root:

```sh
python3 tools/build_native.py
```

Then run this command:

```sh
godot --headless --audio-driver Dummy --path game --editor --import
```

Wait for the command to finish. It builds the local `game/.godot` cache, including the script class index
and imported resources. Git excludes this generated folder. Without this step, a fresh checkout can show
a black screen with script errors. Opening `game/project.godot` in the Godot editor also builds the cache.

Then start the game:

```sh
godot --path game
```

At the import prompt, navigate to the location where your copy of SimCity 2000 is stored, then select `SIMCITY.EXE`.
The app checks the supported version and imports the game files. These files supply the original graphics, text,
sound, and music.

## Extensions

- Larger cities: 256, 384, and 512 tiles per side, alongside the original 128
- Smaller cities: 16, 32 and 64 tiles per side
- Updated coverage, land value, pollution, crime, and other data maps to be 1:1 resolution with the map, instead of lower resolution
- Massively increased the amount of MicroSims (XMIC) and movable objects (XTHG) that are available to be used in each city
- Improved terrain generator with configurable terrain features supported
- New isometric data views, height map, service coverage, and transport-trip overlays
- More zoom levels, layer controls, and optional dark underground views
- Detailed simulation data available including simulation timings, inspection tools
- Support for external graphics, sound, and music packs

Larger cities and per-tile data maps use `.sc2x` saves: ZIP archives with one raw entry per
city structure, city names of up to 64 characters, and signs that can share a tile with any
building. See [the SC2X format](docs/sc2x-format.md). The original game cannot open these
files. Original `.sc2` cities keep their separate compatibility mode until you choose
**Upgrade City to SC2X**. Older `.sc2x` files load as version 4 cities and save as a new copy.

## sc2kfix

Many fixes identified by [sc2kfix](https://github.com/sc2kfix/sc2kfix) have also
been applied or ported to this codebase. The [sc2kfix MIT notice](LICENSE)
is retained for adapted work.

## Development

Open `game/project.godot` in Godot. Run `python3 tools/build_native.py` after each change
to a crate in `native`. It also builds the FluidSynth library, which needs CMake, and downloads
the bundled SoundFonts. The validation command also builds the native libraries and runs
their unit tests. See [the native simulation](docs/native-simulation.md),
[the native region builder](docs/native-rendering.md),
[the native formats](docs/native-formats.md), [the native audio](docs/native-audio.md) and
[FluidSynth music](docs/fluidsynth.md) for their layouts. Run the checks with:

```sh
tools/validate_project.sh
```

The tests use silent audio. Generated city fixtures are committed. Original-data audits need `references/SIMCITY2000`; renderer and media tests can also need imported packs in `ext/`. See [fixture generation](docs/generated-city-fixtures.md).

## AI-Assisted Development

OpenSC2K is developed with the assistance of AI tools, including large language models (LLMs).
AI is used for tasks such as code generation, refactoring, research, documentation, testing, and debugging.
All architectural decisions, implementations, and contributions are reviewed and directed by the project maintainer.

See [AI-POLICY.md](AI-POLICY.md) for the project's AI usage and contribution policy.


## License

Project code is under the [MIT license](LICENSE).

Bundled [Rajdhani fonts](game/assets/fonts/rajdhani/OFL.txt) and
[Godot WRY](game/addons/godot_wry/LICENSE) retain their own licenses.

The MIT license does not grant rights to the original game or its assets.

This project is not affiliated with or endorsed by Maxis or Electronic Arts.

OpenSC2K is an independently written re-implementation. Compatibility and simulation behavior
have been determined through observation, testing, analysis of game data, publicly available
research, and reverse engineering of the original executable.

No original SimCity 2000 source code or assets is included in OpenSC2K.
