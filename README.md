# OpenSC2K
OpenSC2K - An Open Source remake of SimCity 2000 written in JavaScript using HTML5 Canvas API, SQLite and built on [Electron](https://github.com/atom/electron).

## Overview
Currently a lot remains to be implemented but the basic framework is there for importing and viewing cities. Lots of stuff remains completely unimplemented such as the actual simulation, rendering of many special case tiles and buildings, support for zoom levels and anything else that exists outside of importing and viewing.

Along with implementing the original functionality and features, I plan to add additional capabilities beyond the original such as larger city/map sizes, additional network types, adding buildings beyond the initial tileset limitations, action/history tracking along with replays and more.

![Screenshot](/screenshots/1.png)

## Installation
1. `git clone https://github.com/rage8885/OpenSC2K` or download this repository
1. `cd OpenSC2K`
1. **Windows**: `npm install --global --production windows-build-tools` (as admin) installs Windows specific prerequisites
1. `npm install` downloads and installs the dependancies
1. **Windows/Linux**: `node_modules/.bin/electron-rebuild -f -w better-sqlite3` rebuilds Electron with better-sqlite3 bindings
1. `npm start` to run

## Usage
By default, there is no saved city loaded - select a valid SimCity 2000 .sc2 saved game when the file open prompt appears. The city will be imported and saved within the SQLite database and prompt to reload. Right now, the last imported city will automatically load with no option to change cities. To import a new city, press `O` and the file open prompt should appear.

Additional Keys:
 - `O` to open a new .sc2 file for import
 - `Q` or `W` to rotate the camera left or right respectively.
 - `1` sets the current cursor tool to none
 - `2` sets the current cursor tool to "center" (center the map on click)
 - `3` sets the current cursor tool to "info" (displays tile info)
 - `0` clears the database (deletes all cities)
 - Arrow keys to move the camera around

### Debug Overlays
These functions will toggle various debug overlays and views built in to the engine to assist with development. Many of these overlays negatively impact performance significantly.

 - `Z` toggles building key tile display (corners)
 - `C` toggles display of tile coordinates
 - `I` toggles display of a sequence number on each tile in the order of rendering
 - `X` toggles display of terrain layer
 - `V` toggles display of zones layer
 - `Y` toggles display of networks layer (roads, rails, powerlines, highways)
 - `B` toggles display of buildings
 - `N` toggles display of water
 - `M` toggles display of terrain edge blocks
 - `H` toggles display of terrain height map
 - `K` toggles an overlay on top of zones
 - `J` toggles an overlay on top of networks
 - `T` toggles the clip boundary debug view (and sets the clipping box to 200px away from the window border)
 - `F5` to reload the application / re-initialize

![Screenshot](/screenshots/2.png)
![Screenshot](/screenshots/3.png)

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
