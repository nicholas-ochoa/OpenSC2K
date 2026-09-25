# Install OpenSC2K

Download the package for your system from [GitHub Releases](https://github.com/nicholas-ochoa/OpenSC2K/releases).
Version 0.1.0 is the first public release. Keep backup copies of your cities.

All packages require your own copy of SimCity 2000 Special Edition for Windows 95 (1996).
Keep its companion files beside `SIMCITY.EXE`. On first launch, select that executable at the import prompt.
Original game files are not included in the download.

## Windows

Use the Windows x64 ZIP on a 64-bit Windows system.
Extract the entire ZIP to a writable folder. Run `OpenSC2K.exe`.
Keep the PCK and DLL files beside the executable.
The package is not code signed.

The newspaper uses Microsoft Edge WebView2. If the runtime is missing, install the
[Evergreen WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/).

## Linux

Use the Linux x64 archive on an x86-64 system with glibc 2.34 or later.
The newspaper needs GTK 3 and WebKitGTK 4.1. On Ubuntu 22.04 or later, install these with:

```sh
sudo apt install libgtk-3-0 libwebkit2gtk-4.1-0
```

Extract the entire archive. Run `./OpenSC2K.x86_64` from its folder.
Keep the PCK and shared library files beside the executable.

## macOS

The macOS DMG includes an app for Intel and Apple Silicon.
It requires macOS 11 or later on Intel, or macOS 13 or later on Apple Silicon.
Open the DMG. Drag `OpenSC2K.app` to Applications, then open it.

The app has an ad-hoc signature and is not notarized.
If macOS blocks it, use **Open Anyway** in **System Settings > Privacy & Security** after the first launch attempt.
See the [Godot macOS launch instructions](https://docs.godotengine.org/en/4.7/tutorials/export/running_on_macos.html).

## Saves and licenses

Original `.sc2` cities use the original compatibility mode.
Extended `.sc2x` cities cannot be opened by the original game.

Project code uses the MIT license. Dependency notices are available in **About > Licenses**.
The project license does not grant rights to SimCity 2000 or its assets.
