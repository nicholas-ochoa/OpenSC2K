# Third-party notices

OpenSC2K is MIT licensed (see `LICENSE`). The OpenSC2K source code, including
the Rust code in `native/audio` that loads FluidSynth, is MIT licensed.

OpenSC2K packages also contain the separate works below. Each keeps its own
license. The license texts are in `game/assets/licenses` (in packages:
`licenses`, and in the game under **About > Licenses**). Developer details are in `docs/fluidsynth.md`.

## FluidSynth 2.6.1 shared library

- File: `libfluidsynth-3.dll` (Windows), `libfluidsynth.3.dylib` (macOS,
  `OpenSC2K.app/Contents/Frameworks`), `libfluidsynth.so.3` (Linux).
- License: GNU Lesser General Public License, version 2.1 or later
  (`LGPL-2.1.txt`).
- Copyright (C) 2003 Peter Hanappe and others. See `fluidsynth-AUTHORS.txt`.
- Source: <https://github.com/FluidSynth/fluidsynth>, tag `v2.6.1`, unchanged.
- OpenSC2K does not link FluidSynth. It opens the shared library at run time
  and calls only its public C API. You can replace the library with your own
  build of a compatible FluidSynth 2.x library with the same file name.
- The library is built by `tools/build_fluidsynth.py` with these unchanged
  libraries inside it. Their complete corresponding source is published with
  each release as `OpenSC2K-<version>-fluidsynth-source.zip`, and the build
  script names each upstream archive and its SHA-256 hash.

| Library | Version | License | Notice file |
| --- | --- | --- | --- |
| libsndfile | 1.2.2 | LGPL-2.1-or-later | `libsndfile-COPYING.txt`, `libsndfile-AUTHORS.txt` |
| libsndfile GSM 6.10 codec | 1.2.2 | Permissive (Degener and Bormann) | `libsndfile-GSM610-COPYRIGHT.txt` |
| libsndfile ALAC codec | 1.2.2 | Apache-2.0, Copyright (c) 2011 Apple Inc. | `Apache-2.0.txt` |
| libogg | 1.3.6 | BSD-3-Clause | `libogg-COPYING.txt` |
| libvorbis | 1.3.7 | BSD-3-Clause | `libvorbis-COPYING.txt` |
| libFLAC | 1.5.0 | BSD-3-Clause | `flac-COPYING.Xiph.txt` |
| Opus | 1.5.2 | BSD-3-Clause | `opus-COPYING.txt` |
| GCE-Math (build-time headers) | commit 012ae73c | Apache-2.0 | `Apache-2.0.txt`, `gcem-NOTICE.txt` |
| Signalsmith Audio basics | commit 012d2be1 | MIT | `signalsmith-basics-LICENSE.txt` |
| Signalsmith Audio linear | 0.3.1 | MIT | `signalsmith-linear-LICENSE.txt` |
| Signalsmith Audio DSP | 1.7.1 | MIT | `signalsmith-dsp-LICENSE.txt` |
| Signalsmith Audio Hilbert IIR | 1.0.0 | 0BSD | `signalsmith-hilbert-iir-LICENSE.txt` |

## QuickJS-ng 0.17.0

- File: inside the scripting library, `opensc2k_scripting.dll` (Windows),
  `libopensc2k_scripting.dylib` (macOS) and `libopensc2k_scripting.so` (Linux).
- License: MIT. Copyright (c) 2017-2026 Fabrice Bellard, Copyright (c)
  2017-2024 Charlie Gordon, Copyright (c) 2023-2026 Ben Noordhuis, Copyright (c)
  2023-2026 Saúl Ibarra Corretgé.
- License text: `game/assets/licenses/quickjs/QuickJS-ng-LICENSE.txt` (in
  packages: `licenses/quickjs`, and in the game under **About > Licenses**).
- Source: <https://github.com/quickjs-ng/quickjs>, tag `v0.17.0`, unchanged.
  The used files are in `native/scripting/quickjs`. See `docs/native-scripting.md`.

## FluidR3Mono GM SoundFont (Linux packages only)

- File: `FluidR3Mono_GM.sf3`, beside the executable. The Windows and macOS
  packages include no SoundFont; they use the sound set of the operating system.
- Version 2.312, as MuseScore 2.3.2 includes it (`share/sound`), unchanged.
- License: MIT. Copyright (c) 2000-2002, 2008 Frank Wen; mono version
  Copyright (c) 2014-16 Michael Cowgill; Temple Blocks by Ethan Winer;
  Drumline Percussion by Michael Schorsch.
- License text: `game/assets/licenses/fluidr3mono/FluidR3Mono-License.txt`
  (in Linux packages: `licenses/fluidr3mono`).
