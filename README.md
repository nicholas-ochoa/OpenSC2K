# OpenSC2K
OpenSC2K - An Open Source remake of SimCity 2000 written in JavaScript, using WebGL Canvas and [Phaser 3](https://github.com/photonstorm/phaser/).

## Overview
Currently a lot remains to be implemented but the basic framework is there for importing and viewing cities. Lots of stuff remains completely unimplemented such as the actual simulation, rendering of many special case tiles and buildings and anything else that exists outside of importing and viewing.

Along with implementing the original functionality and features, I plan to add additional capabilities beyond the original such as larger city/map sizes, additional network types, adding buildings beyond the initial tileset limitations, action/history tracking along with replays and more.

I've only tested using Chrome / Firefox on macOS, but it should run fairly well on any modern browser/platform that supports WebGL. Performance should be acceptable but there is still a LOT of room for optimizations and improvements.

Due to copyrights, the original graphics and assets from SimCity 2000 cannot be provided here. I've developed and tested using the assets from SimCity 2000 Special Edition for Windows 95. Once I've got the basic engine stabilized I plan to add support for multiple versions of SimCity 2000 in the future.

**Update:** I've been working on refactoring considerable portions of the code for clarity and performance. Due to the changes a lot of existing functionality is now completely broken and will be fixed in upcoming commits.

![Screenshot](/screenshots/1.png)

## Installation
OpenSC2K requires Node.js 20.19 or newer.

1. `git clone https://github.com/nicholas-ochoa/OpenSC2K`
1. `cd OpenSC2K`
1. `npm install`
1. Add the local game assets described below.
1. `npm run dev`
1. Open http://localhost:3000.

Use `npm run build` to create a production bundle in `/dist`, and
`npm run preview` to serve that bundle locally.

## Usage
By default, a test city included in the /assets/cities/ folder will load. Currently you must modify the `/src/city/load.js` file to load different cities.

Requires two files from a legally owned Windows 95 Special Edition version of
SimCity 2000: `LARGE.DAT` and `PAL_MSTR.BMP`. Place them in
`/assets/import/` before starting the game. The files are parsed locally and
used for the in-game graphics.

Common source locations in the Windows 95 installation are:

- `SC2K/DATA/LARGE.DAT`
- `SC2K/BITMAPS/PAL_MSTR.BMP`

These proprietary files are ignored by Git and must not be committed or
redistributed. See `assets/import/README.md` for the local setup reminder.

### Controls
 - `WASD` to move the camera viewport
 - `Q` or `E` to adjust camera zoom

![Screenshot](/screenshots/2.png)
![Screenshot](/screenshots/3.png)
![Screenshot](/screenshots/4.png)

## Acknowledgements
Based on the work of Dale Floer
 - SimCity 2000 specifications (*.sc2)
 - MIF / LARGE.DAT graphics extraction
<https://github.com/dfloer/SC2k-docs>

Based on the work of David Moews
 - SimCity 2000 for MS-DOS file format; unofficial partial information
<http://djm.cc/dmoews.html>

Portions of the SC2 import logic are based on sc2kparser created by Objelisks and distributed under the terms of the ISC license.
<https://github.com/Objelisks/sc2kparser>

Includes work adapted from the Graham Scan polygon union JavaScript implementation by Lovasoa and distributed under the terms of the MIT license
<https://github.com/lovasoa/graham-fast>

## License
OpenSC2K - An Open Source SimCity 2000 remake

Copyright (C) 2019 Nicholas Ochoa

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

SimCity 2000 is copyright Electronic Arts / Maxis. No assets, artwork or other media from the original game is included in this remake. The OpenSC2K engine is being rebuilt as a new implementation and does not use any code from the original game reproduced in any form.
