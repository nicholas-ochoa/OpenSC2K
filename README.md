# OpenSC2K
OpenSC2K - An Open Source remake of SimCity 2000 written in TypeScript, using Electron, WebGL Canvas and [Phaser 3](https://github.com/photonstorm/phaser/).

## Overview
After a pretty long break, I've decided to rewrite the codebase in TypeScript. This project is not currently in a usable state as only the basic components have been re-written. I've also decided to return to Electron as a host versus a web app due a few reasons (the need for loading multiple assets that can't be distributed from the filesystem being a large part of that). Eventually I may try and do a web-only port, but I'd rather deal with the headache of loading assets via the web at a later time.

## Acknowledgements
Based on the work of Dale Floer
 - SimCity 2000 saved city specification
 - MIF / LARGE.DAT graphics artwork specification
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

Copyright (C) 2020 Nicholas Ochoa

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
