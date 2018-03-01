# OpenSC2K
OpenSC2K - An Open Source remake of SimCity 2000 written in JavaScript, using WebGL Canvas and [Phaser 3](https://github.com/photonstorm/phaser/).

## Overview
Currently a lot remains to be implemented but the basic framework is there for importing and viewing cities. Lots of stuff remains completely unimplemented such as the actual simulation, rendering of many special case tiles and buildings and anything else that exists outside of importing and viewing.

Along with implementing the original functionality and features, I plan to add additional capabilities beyond the original such as larger city/map sizes, additional network types, adding buildings beyond the initial tileset limitations, action/history tracking along with replays and more.

I've only tested using Chrome 64 on macOS, but it should run fairly well on any modern browser/platform that supports WebGL. Performance should be acceptable but there is still a LOT of room for optimizations and improvements.

![Screenshot](/screenshots/1.png)

## Installation
You can use yarn (recommended) or npm to install and run. Once installed and started, open a browser to http://localhost:3000 to start the game.

### OS X / Linux
1. `git clone https://github.com/rage8885/OpenSC2K` or download this repository
1. `cd OpenSC2K`
1. `yarn install` downloads and installs the dependancies
1. `yarn start` to run

### Windows (not tested)
1. `git clone https://github.com/rage8885/OpenSC2K` or download this repository
1. `cd OpenSC2K`
1. `npm install --global --production windows-build-tools` (as admin) installs Windows specific prerequisites
1. `npm config set msvs_version 2015 --global` changes config to use correct version of msvs
1. Close all shell/cmd windows and open a new one (non-admin) to reload npm config with correct version
1. Navigate to the OpenSC2K directory
1. `yarn install` downloads and installs the dependencies
1. `yarn start` to run

## Usage
By default, a city included in the /assets/cities/ folder will load. Open the debug controls (top right) and select City -> Open City to select a valid SimCity 2000 .sc2 save file to import. The City -> Save City option will export the currently active city as a compressed JSON data file. The ability to re-import these files has yet to be implemented.

### Controls
 - `WASD` to move the camera viewport
 - `Q` or `E` to adjust camera zoom

![Screenshot](/screenshots/2.png)
![Screenshot](/screenshots/3.png)
![Screenshot](/screenshots/4.png)

## Acknowledgements
Using sc2kparser created by Objelisks distributed under the terms of the ISC license.
<https://github.com/Objelisks/sc2kparser>

Based on the work of Dale Floer
 - SimCity 2000 specifications (*.sc2)
 - MIF / LARGE.DAT graphics extraction

Based on the work of David Moews
 - SimCity 2000 for MS-DOS file format; unofficial partial information <http://djm.cc/dmoews.html>

## License
OpenSC2K - An Open Source SimCity 2000 remake

Copyright (C) 2018 Nicholas Ochoa

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

Includes assets and graphics extracted from the original SimCity 2000 Special Edition CD. These assets are NOT covered by the GNU General Public License used by this project and are copyright EA / Maxis. I'm including these assets in the hope that because the game has been made freely available at various points in time by EA, and because it's 24 years old as of publishing this project that no action will be taken. Long story short, please don't sue me! Long term, I plan to add functionality to extract assets from the original game files within this project.
