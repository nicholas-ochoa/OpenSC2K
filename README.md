# OpenSC2K
OpenSC2K - An Open Source remake of SimCity 2000 by Maxis

## Overview
Currently a lot remains to be implemented but the basic framework is there for importing and viewing cities. Lots of stuff remains completely unimplemented such as the actual simulation, rendering of many special case tiles and buildings, support for zoom levels and anything else that exists outside of importing and viewing.

## Installation

1. Download or clone this repository
2. Run `npm install`
3. Run `npm start`

## Usage
By default, there is no saved city loaded - select a valid SimCity 2000 .sc2 saved game when the file open prompt appears. The city will be imported and saved within the SQLite database and prompt to reload. Right now, the last imported city will automatically load with no option to change cities. To import a new city, press "O" and the file open prompt should appear.

Additional Commands:

 - To clear the database (delete all cities) press "0" (zero)
 - Map rotation "Q" or "W" to rotate left or right respectively.
 - "1" sets the current cursor tool to none
 - "2" sets the current cursor tool to "center" (center the map on click)
 - "3" sets the current cursor tool to "info" (displays tile info)
 - Arrow keys to move the camera around

### Debug Overlays
These functions will toggle various debug overlays and views built in to the engine to assist with development. Many of these overlays negatively impact performance significantly.

 - "Z" toggles building key tile display (corners)
 - "C" toggles display of tile coordinates
 - "I" toggles display of a sequence number on each tile in the order of rendering
 - "X" toggles display of terrain layer
 - "V" toggles display of zones layer
 - "Y" toggles display of networks layer (roads, rails, powerlines, highways)
 - "B" toggles display of buildings
 - "N" toggles display of water
 - "M" toggles display of terrain edge blocks
 - "H" toggles display of terrain height map
 - "K" toggles an overlay on top of zones
 - "J" toggles an overlay on top of networks
 - "T" toggles the clip boundary debug view (and sets the clipping box to 200px away from the window border)
 - "F5" to reload the application / re-initialize

## Contributions
Using sc2kparser created by Objelisks distributed under the terms of the ISC license.
<https://github.com/Objelisks/sc2kparser>

Based on the work of Dale Floer
 - SimCity 2000 specifications (*.sc2)
 - MIF / LARGE.DAT graphics extraction

## License
sc2k - An Open Source SimCity 2000 remake
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
