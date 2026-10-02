# Third-party notices

OpenSC2K is MIT licensed (see `LICENSE`). The OpenSC2K source code, including
the Rust code in `native/audio` that loads FluidSynth, is MIT licensed.

OpenSC2K packages also contain the separate works below. Each keeps its own
license. The license texts are in `game/assets/licenses/fluidsynth` and
`game/assets/licenses/soundfonts` (in packages: `licenses/`, and in the game
under **About > Licenses**). Developer details are in `docs/fluidsynth.md`.

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

## SoundFonts

Both bundled SoundFonts are unchanged files from MuseScore, the canonical
distributor. Their license files are beside them in the `soundfonts` folder and
in `game/assets/licenses/soundfonts`.

- **FluidR3Mono GM 2.312** (`FluidR3Mono_GM.sf3`), the default. MIT license.
  Original stereo version by Frank Wen, Copyright (c) 2000-2002, 2008. Mono
  version by Michael Cowgill, Copyright (c) 2014-16. Temple Blocks by Ethan
  Winer, Copyright (c) 2002. Drumline Percussion by Michael Schorsch,
  Copyright (c) 2016. Source: MuseScore 2.3.2, `share/sound`.
- **MuseScore General 0.2** (`MuseScore_General.sf3`). MIT license. FluidR3 by
  Frank Wen, Copyright (c) 2000-02. FluidR3Mono by Michael Cowgill, Copyright
  (c) 2014-17. Adaptation by S. Christian Collins, Copyright (c) 2018-19. Temple
  Blocks by Ethan Winer, Copyright (c) 2002. Drumline Cymbals by Michael
  Schorsch, Copyright (c) 2016. Source:
  <https://ftp.osuosl.org/pub/musescore/soundfont/MuseScore_General/>.
  `MuseScore_General_Sample_Sources.csv` lists the sample sources.
