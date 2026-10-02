# Install OpenSC2K

Download the package for your system from [GitHub Releases](https://github.com/nicholas-ochoa/OpenSC2K/releases).
Version 0.1.0 is the first public release. Keep backup copies of your cities.

All packages require your own copy of SimCity 2000 Special Edition for Windows 95 (1996).
Keep its companion files beside `SIMCITY.EXE`. On first launch, select that executable at the import prompt.
You can also import from the game CD-ROM. To use a disc image file, such as an `.iso` file, mount it first.
Then select the mounted disc. Refer to [Import original game files](media-pack-format.md#import-original-game-files).
Original game files are not included in the download.

## Windows

Use the Windows x64 ZIP on a 64-bit Intel or AMD Windows system.
Use the Windows arm64 ZIP on a Windows on Arm system.
Extract the entire ZIP to a writable folder. Run `OpenSC2K.exe`.
Keep the PCK and DLL files beside the executable.
The package is not code signed.

### Portable version

Each Windows portable ZIP keeps all user files in the `data` folder beside `OpenSC2K.exe`.
Use it on a removable drive or in a folder that you can write to.
Do not extract it to `Program Files`.

The `data` folder contains:

- `settings.cfg` for settings
- `packs` for imported graphics, sound, music, and data packs
- `cities` and `scenarios` for saved games
- `scurk` and other SCURK output folders

To change a standard installation to a portable installation, make an empty `data` folder beside `OpenSC2K.exe`.
To use the Windows user profile again, move or remove the `data` folder.
OpenSC2K does not move files between the two locations.
The standard version keeps user files in `%APPDATA%\Godot\app_userdata\OpenSC2K`.
The Godot engine writes its log files to the `logs` folder in that location in both versions.

## Linux

Use the Linux x64 archive on an x86-64 system, or the Linux arm64 archive on an arm64 (AArch64) system.
Both need glibc 2.34 or later.
Extract the entire archive. Run `./OpenSC2K.x86_64` (x64) or `./OpenSC2K.arm64` (arm64) from its folder.
Keep the PCK and shared library files beside the executable.

## macOS

The macOS DMG includes an app for Intel and Apple Silicon.
It requires macOS 11 or later on Intel, or macOS 13 or later on Apple Silicon.
Open the DMG. Drag `OpenSC2K.app` to Applications, then open it.

The app has an ad-hoc signature and is not notarized.
If macOS blocks it, use **Open Anyway** in **System Settings > Privacy & Security** after the first launch attempt.
See the [Godot macOS launch instructions](https://docs.godotengine.org/en/4.7/tutorials/export/running_on_macos.html).

## Music SoundFonts

OpenSC2K plays the MIDI music with FluidSynth and a General MIDI sound set. Only the Linux
packages include a sound set. Select one in **Settings > Audio > Music SoundFont**:

- **macOS GS Sound Set** or **Microsoft GS Wavetable Sound Set** (the default): the Roland GS
  sounds that macOS and Windows include. It is close to the General MIDI hardware of the
  original game. On Linux, **System SoundFont** uses a SoundFont package of your distribution,
  such as `fluid-soundfont-gm`. Without one, it uses **Bundled SoundFont (FluidR3 Mono)**,
  the `FluidR3Mono_GM.sf3` file beside the executable.
- **Custom SoundFont**: an SF2, SF3 or DLS General MIDI SoundFont of your own.
  Select the file with **Browse...**. OpenSC2K reads the file in place and does not copy or change it.

If a custom SoundFont cannot load, for example because the file moved, OpenSC2K plays the
system sound set and shows the reason below the list. Without either, the game plays no MIDI
music; recorded soundtracks still play. The SoundFont loads when MIDI music first plays.

## Saves and licenses

Original `.sc2` cities use the original compatibility mode.
Extended `.sc2x` cities cannot be opened by the original game.

Project code uses the MIT license. Dependency notices are available in **About > Licenses**,
and in `THIRD_PARTY_NOTICES.md` and the `licenses` folder of each package.
FluidSynth is a separate library under the LGPL 2.1 or later. You can replace it with a compatible
FluidSynth 2 library of the same name. Its source is published with each release.
The project license does not grant rights to SimCity 2000 or its assets.
