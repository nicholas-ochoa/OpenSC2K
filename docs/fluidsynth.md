# FluidSynth music

OpenSC2K plays the MIDI music with [FluidSynth](https://www.fluidsynth.org/) and a
General MIDI SoundFont. The custom additive synthesizer stays as a fallback and as
a player choice.

## Architecture

```text
SOUNDS/<track>.MID or a music pack MIDI file
    |  StandardMidiFile (GDScript) parses the file on the main thread
    v
event arrays: times, and kind, channel, a, b per event
    |  MidiSynthPlayer gives them to the music thread
    v
FluidMidiSynth (Rust GDExtension, native/audio)
    |  Sequencer sends each event on its own sample
    |  FluidSynth renders float PCM with fluid_synth_write_float
    v
AudioStreamGenerator ring buffer (1 second)
    |  Godot's audio thread reads it
    v
AudioStreamPlayer -> Master bus -> output device
```

- `game/src/audio/standard_midi_file.gd` parses standard MIDI files. It was kept,
  because it already gives exact event times, and the original duration rules
  decide the end of each track. It reports note, program, controller, pitch-bend,
  channel-pressure and key-pressure events.
- `game/src/audio/midi_synth_player.gd` keeps its public behavior: `play_path`,
  `play_sequence`, `stop`, `set_paused`, `set_volume_linear`, `track_finished`.
  It now also takes `set_soundfont(choice, custom_path)`.
- `native/audio/src/sequencer` plays the event list through any `MidiOutput`. It
  splits each render at event times, seeks (it replays programs, controllers,
  bends and pressure, but no notes), loops, and ends after a release tail of at
  most 2 seconds.
- `native/audio/src/fluidsynth` is the only code that calls FluidSynth.
  `platform.rs` opens the library, `api.rs` holds the function table, `synth.rs`
  is the safe `FluidSynth` owner, and `log.rs` keeps the last FluidSynth error.
- `native/audio/src/fluid_midi_synth.rs` is the Godot class `FluidMidiSynth`.
- `native/audio/src/synth` is the built-in synthesizer (`NativeMidiSynth`).

FluidSynth's own MIDI file player was not used. The game already parses MIDI
files, and its track-end, gap and shuffle rules use that parser. With only the
synthesizer replaced, both synthesizers play the same events, and a track can
change synthesizer at its current position. FluidSynth receives every channel
message that the parser reports. System exclusive messages are skipped, as
before; the original tracks contain none.

### Why FluidSynth

FluidSynth is a mature, maintained, cross-platform SoundFont 2.04 synthesizer
with complete General MIDI behavior: programs and banks, the channel 10 drum
kit, velocity, pitch bend and its range, sustain, expression, volume, pan,
reverb and chorus sends, modulators and SF3 compressed SoundFonts. It renders
into a caller buffer without an audio driver, so Godot keeps control of output.

## Rust integration

OpenSC2K uses direct FFI to the public FluidSynth 2 C API, loaded at run time.
No Rust FluidSynth crate is used:

- Crates reviewed on crates.io: `fluidsynth` 0.0.1 (2018, unmaintained, links
  at build time), `fluidlite` and `fluidlite-sys` 0.2.1 (2021, bind fluidlite, a
  reduced FluidSynth 1 fork, built statically into the program, which the LGPL
  would make harder), and `oxisynth` 0.1 and `rustysynth` (other synthesizers
  written in Rust, not FluidSynth). None is a maintained binding of FluidSynth 2.
- Linking at build time would need FluidSynth on every developer computer and
  would stop the game when the library is missing.
- OpenSC2K uses 23 functions. A hand-written table is small, and it adds no crate.

The function declarations follow the FluidSynth API documentation. No FluidSynth
header or source is copied into OpenSC2K. All `unsafe` code is in
`native/audio/src/fluidsynth`. The rest of the crate uses the safe `FluidSynth`
type. The library is checked at load: its `fluid_version` major version must be 2.

### Threading

- A `WorkerThreadPool` task creates the `FluidMidiSynth` and loads the SoundFont.
  This reads and decodes the whole file (about 1.5 s and 144 MB for the default).
- The main thread then gives the synthesizer to the music thread with each track,
  and does not call it again. The music thread is the only caller of `render`.
- The music thread fills the 1-second `AudioStreamGenerator` buffer in blocks of
  at most 1024 frames, and waits 10 ms when the buffer is full.
- Godot's audio thread only reads the ring buffer. It never calls FluidSynth, and
  no file access, SoundFont load or large allocation happens on it.
- FluidSynth's own API lock is off (`synth.threadsafe-api = 0`), because one
  thread at a time owns each synthesizer. `synth.cpu-cores = 1`, so FluidSynth
  starts no worker threads.
- FluidSynth shares loaded samples between synthesizers in one process-wide
  cache. Creating a synthesizer, loading a SoundFont and deleting a synthesizer
  take a Rust mutex, so two threads never change that cache at once. Rendering
  never takes it.
- The render buffers of the sequencer grow to the largest request and are reused.

FluidSynth starts events at the next 64-frame block (1.5 ms at 44.1 kHz).

## How audio reaches Godot

`FluidMidiSynth` renders 44,100 Hz stereo float frames. `MidiSynthPlayer` sets
the `AudioStreamGenerator` mix rate to the rate of the active synthesizer
(22,050 Hz for the built-in one), and Godot resamples to the device rate. Music
therefore uses the normal Godot path: the music volume setting, pause, focus
muting and the Master bus all apply. FluidSynth opens no audio driver; the
library is built without any.

The FluidSynth gain is 0.35. That is about as loud as the built-in synthesizer
on the original tracks. The FluidSynth limiter keeps peaks below -1 dBFS.

## Building

`python3 tools/build_native.py` builds the native libraries, then
`tools/build_fluidsynth.py` builds FluidSynth, and `tools/fetch_soundfonts.py`
downloads the bundled SoundFonts. Each step skips output that is current. The
validation runner calls the same build.

Requirements: Rust (see `rust-toolchain.toml`), CMake 3.24 or later, Python 3,
and a C and C++ compiler:

- Windows: Visual Studio 2022 with the C++ workload. CMake uses the Visual Studio
  generator and the static C runtime, so the DLL needs no redistributable.
- macOS: Xcode command line tools. The library is universal (arm64 and x86_64)
  for macOS 11 and later, with an ad-hoc signature.
- Linux: GCC or Clang. The library links the C++ runtime statically and needs
  only glibc.

`tools/build_fluidsynth.py` downloads each pinned source archive, checks its
SHA-256, and builds libogg, libvorbis, libFLAC, Opus and libsndfile as static
libraries, then FluidSynth as a shared library with all of them inside. CMake
runs with `FETCHCONTENT_FULLY_DISCONNECTED`, so the build downloads nothing
that the script does not pin. Every audio, MIDI, shell, network, LADSPA and
OpenMP option is off. The script rejects a library that needs a shared library
outside the operating system. A change to the script rebuilds the library.

Developers can also use a system FluidSynth 2 library: on macOS the loader
also tries `/opt/homebrew/lib` and `/usr/local/lib`, and on Linux the system
search path. Set `OPENSC2K_FLUIDSYNTH` to the path of a library to use only that
library.

### Tests

- `cargo test --release` in `native/audio` tests the sequencer and, with the
  library, FluidSynth: valid, invalid, truncated and missing SoundFonts, SoundFont
  switching, programs, the drum channel, velocity, pitch bend, sustain, volume,
  expression, pan, gain and a missing library. Without the library these tests
  pass with a note, unless `OPENSC2K_REQUIRE_FLUIDSYNTH` is set.
  `tools/build_native.py` sets it, and so does CI.
- The tests use `game/tests/fixtures/soundfonts/opensc2k_test_gm.sf2`, a 17 KB
  SoundFont that `native/audio/src/fluidsynth/test_soundfont.rs` generates. It has
  no third-party content. Set `OPENSC2K_UPDATE_FIXTURES=1` to write it again.
- `game/tests/fluidsynth_music_test.gd` tests the Godot classes: the library,
  SoundFont errors, MIDI parsing, rendering, looping, seeking, the fallback order,
  the saved preference, deferred start, runtime switching and track end.

## Runtime library layout

| Platform | Development | Package |
| --- | --- | --- |
| Windows | `game/bin/opensc2k_audio/windows-x86_64/libfluidsynth-3.dll` | `libfluidsynth-3.dll` beside `OpenSC2K.exe` |
| macOS | `game/bin/opensc2k_audio/macos/libfluidsynth.3.dylib` | `OpenSC2K.app/Contents/Frameworks/libfluidsynth.3.dylib` |
| Linux | `game/bin/opensc2k_audio/linux-x86_64/libfluidsynth.so.3` | `libfluidsynth.so.3` beside `OpenSC2K.x86_64` |

The `[dependencies]` section of `game/opensc2k_audio.gdextension` makes the Godot
export copy the library and the SoundFonts. The audio extension finds its own
file (`dladdr` on macOS and Linux, `GetModuleHandleExW` on Windows) and opens
FluidSynth from the same folder by full path. So:

- Windows: `LoadLibraryExW` with `LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR` and
  `LOAD_LIBRARY_SEARCH_DEFAULT_DIRS`. The current folder and `PATH` are never
  searched.
- macOS: no `@rpath` or `@loader_path` lookup is needed, because the full path is
  opened. The library's install name is `@rpath/libfluidsynth.3.dylib`, so a
  replacement can also be linked normally.
- Linux: no `RPATH` or `$ORIGIN` is needed for the same reason.

If that file is missing, the loader tries the system search path, then the
development folders. When no library loads, the game shows the reason in the
settings and the music notice, and plays the built-in synthesizer.

## SoundFont selection

The **Settings > Audio > Music SoundFont** list sets the preference
`audio/music_soundfont`:

| Choice | Value | SoundFont |
| --- | --- | --- |
| OpenSC2K Default (FluidR3Mono GM) | `default` | the default bundled SoundFont |
| FluidR3Mono GM | `fluidr3mono` | `FluidR3Mono_GM.sf3` |
| MuseScore General | `musescore_general` | `MuseScore_General.sf3` |
| Custom SoundFont | `custom` | the file in `audio/music_soundfont_path` |
| Built-in synthesizer | `builtin` | none |

`SoundFontCatalog.candidates` gives the files to try. When a SoundFont fails
(missing, unsupported or damaged), the bundled default loads instead. When that
fails too, or FluidSynth is missing, the built-in synthesizer plays. The status
names each failure. A custom SoundFont is read in place and never copied or
changed. A change while music plays continues the same track from its position
with the new SoundFont; the built-in synthesizer restarts the track.

A SoundFont loads the first time that MIDI music plays, not at startup. The first
track waits for the load.

The bundled SoundFonts are in `game/bin/soundfonts` in a source checkout (a
`.gdignore` file keeps Godot from importing them), beside the executable in
Windows and Linux packages, and in `OpenSC2K.app/Contents/Resources/soundfonts`.

## Adding a SoundFont

1. Review its license and sample provenance from the canonical upstream source,
   as in the table below. Do not use a mirror as the license authority.
2. Add its file and license file, with URLs and SHA-256 hashes, to `FILES` in
   `tools/fetch_soundfonts.py`.
3. Add its id, label and file name to `BUNDLED` in
   `game/src/audio/sound_font_catalog.gd`.
4. Add the files to each platform in the `[dependencies]` section of
   `game/opensc2k_audio.gdextension`.
5. Copy its license to `game/assets/licenses/soundfonts`, add it to
   `about_dialog.gd`, and add it to `THIRD_PARTY_NOTICES.md` and this page.

## SoundFont review

Reviewed on 2026-10-01 from the upstream sources.

| SoundFont | License | Size | Bundled? | Source | Notes |
|---|---|---:|---|---|---|
| FluidR3Mono GM 2.312 | MIT | 14.5 MB (SF3) | Yes, default | MuseScore 2.3.2 `share/sound` (github.com/musescore/MuseScore, commit 45924076) | Complete GM set with GS drum kits. Mono samples of FluidR3 by Michael Cowgill. Loads in 1.5 s, about 144 MB in memory. |
| MuseScore General 0.2 | MIT | 38 MB (SF3), 206 MB (SF2) | Yes | ftp.osuosl.org/pub/musescore/soundfont/MuseScore_General (MuseScore's download server) | FluidR3Mono with new piano and other instruments by S. Christian Collins. Sample sources are listed per preset; new samples are public domain or by the author. Loads in 3.2 s, about 240 MB in memory. |
| MuseScore General HQ | MIT | about 480 MB (SF2) | No | Same project; not offered on the MuseScore download server | Too large for a game download. Players can select it as a custom SoundFont. |
| MS Basic (MuseScore 4) | MIT | 51 MB (SF3) | No | github.com/musescore/MuseScore `share/sound` | MIT, current, complete GM. Its license file still describes MuseScore General 0.2 (MuseScore issue 19446), and it is a renamed descendant of MuseScore General, so it adds little. |
| FluidR3 GM (stereo) | MIT (Debian `fluid-soundfont`, from Frank Wen's 2008 release) | 141 MB (SF2) | No | ftp.osuosl.org/pub/musescore/soundfont/fluid-soundfont.tar.gz | Complete GM. The MuseScore archive holds a community-edited "GM2-2" file and a readme that says "public domain", but no license file, so its provenance is not clear enough to bundle. FluidR3Mono covers the same samples. |
| GeneralUser GS 2.0.3 | GeneralUser GS License v2.0 (permissive, not MIT) | 31 MB (SF2) | No | github.com/mrbumpy409/GeneralUser-GS | High quality and FluidSynth-tested. Its license states that the origin of some samples is not certain, so it is not bundled. It works as a custom SoundFont. |
| FreePats General MIDI | GPL-3.0-or-later with an exception | 307 MB (SF2) | No | freepats.zenvoid.org | Incomplete: 45 melodic and 43 drum entries. |
| TimGM6mb | GPL-2.0 | 6 MB | No | Debian `timgm6mb-soundfont` | GPL, not suitable to bundle with the MIT project. |

No complete General MIDI SoundFont under the MIT license that is not derived from
FluidR3 was found. FluidR3Mono and MuseScore General are separate, maintained
derivatives with different sample sets and quality, and both have clear licenses.

## Third-party licensing

- OpenSC2K's own code, including `native/audio`, is MIT. FluidSynth is a
  separate LGPL-2.1-or-later library. See `THIRD_PARTY_NOTICES.md`.
- Packages contain `THIRD_PARTY_NOTICES.md` and a `licenses` folder. The game shows
  the same texts under **About > Licenses**. The texts are in
  `game/assets/licenses/fluidsynth` and `game/assets/licenses/soundfonts`.
- Each SoundFont has its license file beside it in the `soundfonts` folder.

## LGPL considerations

The LGPL 2.1 lets an MIT program use an LGPL library when the user can change
the library and use the changed library with the program (section 6). OpenSC2K
meets this as follows:

- **Separate, replaceable library.** FluidSynth is never linked statically or at
  build time. The audio extension opens it at run time and calls only the public
  API. Any compatible FluidSynth 2 build with the same file name, or one named in
  `OPENSC2K_FLUIDSYNTH`, works in its place (section 6b).
- **No FluidSynth code in OpenSC2K.** The FFI declarations are written from the
  API documentation. OpenSC2K is a "work that uses the Library" and keeps the MIT
  license (section 5).
- **Unchanged sources.** FluidSynth and every library in it are built from the
  unchanged upstream release archives. OpenSC2K applies no patches.
- **Corresponding source.** Each release publishes
  `OpenSC2K-<version>-fluidsynth-source.zip` beside the packages, from the same
  place (sections 4 and 6). It contains every source archive in the library, the
  build script, and their SHA-256 list. `tools/build_fluidsynth.py --source-bundle
  <folder>` writes the same files.
- **Notices.** The LGPL text, the FluidSynth copyright and authors, and the notice
  of every other library are in each package and in the game.
- The official FluidSynth Windows binaries are not used. Their `sndfile.dll` also
  contains mpg123 and LAME (LGPL), whose exact source versions OpenSC2K cannot
  name. A build from pinned sources gives the same corresponding source on every
  platform.

If OpenSC2K ever changes FluidSynth, keep the changes as patch files beside the
build script, apply them in the build, add them to the source bundle, and mark the
changed files as required by LGPL section 2.

## Remaining issues

- The Windows build runs only in CI on `windows-2025`; it is not tested locally.
- macOS packages are ad-hoc signed. Notarization would also need the FluidSynth
  library signed with the same identity.
- Memory: an SF3 SoundFont is decoded at load. The default uses about 144 MB.
  FluidSynth's `synth.dynamic-sample-loading` would lower this, but it reads the
  file during program changes on the music thread, so it is off.
- The SoundFont loads on the first MIDI track, so that track starts about 1.5 s
  later. Recorded soundtracks are not affected.
