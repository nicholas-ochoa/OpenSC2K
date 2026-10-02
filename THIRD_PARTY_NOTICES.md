# Third-party notices

OpenSC2K is MIT licensed (see `LICENSE`). The OpenSC2K source code, including
the Rust code in `native/audio` that loads FluidSynth, is MIT licensed.

OpenSC2K packages also contain the separate works below. Each keeps its own
license. The license texts are in `game/assets/licenses/fluidsynth` (in packages:
`licenses/fluidsynth`, and in the game under **About > Licenses**). Developer details are in `docs/fluidsynth.md`.

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

OpenSC2K includes no SoundFont. The music uses the General MIDI sound set of
the operating system, or a SoundFont that the player selects, in place.
