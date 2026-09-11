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
You can use yarn (recommended) or npm to install and run. Once installed and started, open a browser to http://localhost:3000 to start the game.

### OS X / Linux
1. `git clone https://github.com/rage8885/OpenSC2K` or download this repository
1. `cd OpenSC2K`
1. `yarn install` downloads and installs the dependancies
1. `yarn dev` to run

## Usage
By default, a test city included in the /assets/cities/ folder will load. Currently you must modify the `/src/city/load.js` file to load different cities.

Requires two files from the Windows 95 Special Edition version of SimCity 2000: `LARGE.DAT` and `PAL_MSTR.BMP`. These must be placed in the `/assets/import/` directory prior to starting the game. The files will be automatically parsed and used for all in game graphics.

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

## 🌐 Web Resources & Interactive Index
- [SNAKE OUT](https://learnaction.netlify.app/snake-out.html)
- [VORTEX BALL](https://skillquest-en.pages.dev/vortex-ball.html)
- [TAXI SIMULATOR 2024](https://eduquestsjp.pages.dev/taxi-simulator-2024.html)
- [EMOJI MATCH](https://eduquestkr.pages.dev/emoji-match.html)
- [LAST DAY ON EARTH SURVIVAL](https://brainquestspt.pages.dev/last-day-on-earth-survival.html)
- [HOOP WORLD 3D](https://eduquestkr.pages.dev/hoop-world-3d.html)
- [BROKEN CITY COMBAT](https://brainquestskr.pages.dev/broken-city-combat.html)
- [INDEX3](https://eduquestsjp.pages.dev/index3.html)
- [FLY FLY FLY](https://mindconvertfr.pages.dev/fly-fly-fly.html)
- [GLADIATORS MERGE AND FIGHT](https://quizzesarena.onrender.com/gladiators-merge-and-fight.html)
- [STAR WING](https://jangkhangplay.pages.dev/star-wing.html)
- [CATEGORY 2D1 070](https://jangkhangkr.pages.dev/category-2d1-070.html)
- [CHIBI DOLL AVATAR CREATOR](https://eduquestkr.pages.dev/chibi-doll-avatar-creator.html)
- [AIM NINJA](https://quizzesarena.web.app/aim-ninja.html)
- [CAT CHALLENGE](https://jangkhangkr.pages.dev/cat-challenge.html)
- [GRANNY RETURNS 3D EVIL DESTINY](https://brainquestspt.pages.dev/granny-returns-3d-evil-destiny.html)
- [WAFFLE WORDS](https://mindconvert.onrender.com/waffle-words.html)
- [INDEX22](https://quizzesarena.web.app/index22.html)
- [HAIR SALON BEAUTY SALON](https://eduquestsjp.pages.dev/hair-salon-beauty-salon.html)
- [BOLTS AND NUTS](https://quizzesarena.web.app/bolts-and-nuts.html)
- [ONLINE PORTAL](https://brainquesteses.pages.dev/)
- [NOOB SAVING FRIENDS](https://mindconvertes.pages.dev/noob-saving-friends.html)
- [EAT DONUTS](https://mindconvertpt.pages.dev/eat-donuts.html)
- [JUMPER](https://quizzesarena.web.app/jumper.html)
- [SKY MAZE CHALLENGE](https://learnaction.netlify.app/sky-maze-challenge.html)
- [RABBIT CARROT](https://jangkhangplay.pages.dev/rabbit-carrot.html)
- [PAPAS BURGER COOK](https://mindconvertjp.pages.dev/papas-burger-cook.html)
- [GOING BALLS 3D](https://learnaction.netlify.app/going-balls-3d.html)
- [ZOMBIE FRONTIER SHOOTER](https://brainquestsfr.pages.dev/zombie-frontier-shooter.html)
- [SPACEFLIGHT SIMULATOR](https://quizzesarena.onrender.com/spaceflight-simulator.html)
- [CATEGORY DESTROY](https://jangkhangkr.pages.dev/category-destroy.html)
- [WORD GUESS GAME](https://learnaction.netlify.app/word-guess-game.html)
- [MOJICON GARDEN JIGSOLITAIRE](https://quizzesarena.web.app/mojicon-garden-jigsolitaire.html)
- [CATEGORY CUTE](https://brainquesteses.pages.dev/category-cute.html)
- [CATEGORY CASUAL 3](https://brainquestskr.pages.dev/category-casual-3.html)
- [INDEX13](https://mindconvert.onrender.com/index13.html)
- [ANIMAL SORT CUTE PUZZLE GAME](https://jangkhangkr.pages.dev/animal-sort-cute-puzzle-game.html)
- [PIRATES MATCH THE LOST TREASURE](https://learnaction.netlify.app/pirates-match-the-lost-treasure.html)
- [AUTUMN GLAM GALA](https://learnaction.netlify.app/autumn-glam-gala.html)
- [ADVERSATOR](https://quizzesarena.web.app/adversator.html)
- [NEIGHBORHOOD DEFENSE](https://brainquestsjp.pages.dev/neighborhood-defense.html)
- [TINY BAKER RAINBOW BUTTERCREAM CAKE](https://eduquests.netlify.app/tiny-baker-rainbow-buttercream-cake.html)
- [UP HERO](https://quizzesarena.onrender.com/up-hero.html)
- [CATEGORY HALLOWEEN45](https://mindconvert.onrender.com/category-halloween45.html)
- [GETTING OVER IT](https://learnaction.netlify.app/getting-over-it.html)
- [FOOTBALL SUPERSTARS 2026](https://mindconvertfr.pages.dev/football-superstars-2026.html)
- [OFFROAD ISLAND](https://brainquestsfr.pages.dev/offroad-island.html)
- [SOKOBAN PUZZLE GAME](https://quizzesarena.onrender.com/sokoban-puzzle-game.html)
- [RED STICKMAN VS CRAFTMANS 2](https://learnaction.netlify.app/red-stickman-vs-craftmans-2.html)
- [TAP AWAY BLOCK PUZZLE 3D](https://quizzesarena.web.app/tap-away-block-puzzle-3d.html)
- [FRUIT JAM MERGE PUZZLE GAME](https://mindconvertfr.pages.dev/fruit-jam-merge-puzzle-game.html)
- [WHAT S THE DIFFERENCE ONLINE](https://eduquestkr.pages.dev/what-s-the-difference-online.html)
- [PANDA RESTAURANT](https://learnaction.netlify.app/panda-restaurant.html)
- [CAPYBARA COIN MASTER](https://learnaction.netlify.app/capybara-coin-master.html)
- [BLOCK COMBO BLAST](https://eduquestkr.pages.dev/block-combo-blast.html)
- [HALLOWEEN CHALLENGE](https://eduquestkr.pages.dev/halloween-challenge.html)
- [FLAG PUZZLE JAM COLLECT FLAGS](https://brainquestsfr.pages.dev/flag-puzzle-jam-collect-flags.html)
- [TOWN RUN](https://eduquests.netlify.app/town-run.html)
- [GOLD MINER TOWER DEFENSE](https://mindconvertfr.pages.dev/gold-miner-tower-defense.html)
- [INDEX38](https://brainquestspt.pages.dev/index38.html)
- [WORLD WARS TANKS](https://mindconvertfr.pages.dev/world-wars-tanks.html)
- [OUTSIDE](https://learnaction.netlify.app/outside.html)
- [CATEGORY FARMING87](https://eduquestsjp.pages.dev/category-farming87.html)
- [CATEGORY DIRT BIKE18](https://brainquestspt.pages.dev/category-dirt-bike18.html)
- [MASK EVOLUTION 3D](https://quizzesarena.web.app/mask-evolution-3d.html)
- [DICE MERGE](https://eduquests.netlify.app/dice-merge.html)
- [SHEEP SORT PUZZLE SORT COLOR](https://learnaction.netlify.app/sheep-sort-puzzle-sort-color.html)
- [BALLOON MATCH 3D](https://quizzesarena.web.app/balloon-match-3d.html)
- [LITTLE BUGS](https://quizzesarena.onrender.com/little-bugs.html)
- [3D BLOCK GLADIATOR SWORD DRAW](https://mindconvert.onrender.com/3d-block-gladiator-sword-draw.html)
- [MY FARM LIFE](https://brainquestsfr.pages.dev/my-farm-life.html)
- [CAPYBARA JUMP](https://jangkhangplay.pages.dev/capybara-jump.html)
- [CATEGORY DIRT BIKE](https://jangkhangkr.pages.dev/category-dirt-bike.html)
- [HORROR PLAYTIME ROOM ESCAPE](https://brainquestsfr.pages.dev/horror-playtime-room-escape.html)
- [HERO WIZARD SAVE YOUR GIRLFRIEND](https://brainquestsfr.pages.dev/hero-wizard-save-your-girlfriend.html)
- [SLOPE SNOWBALL](https://mindconvertjp.pages.dev/slope-snowball.html)
- [TCG CARD CLICKER](https://brainquestsfr.pages.dev/tcg-card-clicker.html)
- [HOOK PIN JAM](https://learnaction.netlify.app/hook-pin-jam.html)
- [INDEX32](https://eduquestses.pages.dev/index32.html)
- [UNBLOCK IT 3D](https://quizzesarena.onrender.com/unblock-it-3d.html)
- [OCEAN KIDS BACK TO SCHOOL](https://eduquestkr.pages.dev/ocean-kids-back-to-school.html)
- [MEGA RAMPS ULTIMATE CAR RACES](https://quizzesarena.onrender.com/mega-ramps-ultimate-car-races.html)
- [PLANET DEMOLISH](https://mindconvertfr.pages.dev/planet-demolish.html)
- [CATEGORY TOP DOWN248](https://welearnaction.onrender.com/category-top-down248.html)
- [OPENGUESSR](https://learnaction.netlify.app/openguessr.html)
- [CATEGORY BYPASS](https://mindconvert.onrender.com/category-bypass.html)
- [INK SHOP DRESS TATTOO](https://eduquestses.pages.dev/ink-shop-dress-tattoo.html)
- [SAVE MY PET PARTY](https://quizzesarena.web.app/save-my-pet-party.html)
- [ITALIAN BRAINROT DRAG MERGE PUZZLE](https://brainquestsjp.pages.dev/italian-brainrot-drag-merge-puzzle.html)
- [TRICKY CHALLENGES MINI GAMES](https://quizzesarena.onrender.com/tricky-challenges-mini-games.html)
- [CANDY CHAIN MASTER](https://quizzesarena.web.app/candy-chain-master.html)
- [CHESSFIELD](https://jangkhangplay.pages.dev/chessfield.html)
- [SOCCER DASH](https://quizzesarena.web.app/soccer-dash.html)
- [CATEGORY RACING DRIVING](https://brainquestsjp.pages.dev/category-racing-driving.html)
- [HORDE HUNTERS](https://brainquestsjp.pages.dev/horde-hunters.html)
- [STICKMAN FIGHT PRO](https://mindconvertpt.pages.dev/stickman-fight-pro.html)
- [CATEGORY CONTROLLER 2](https://eduquests.netlify.app/category-controller-2.html)
- [CUTE ANIMAL WORLD](https://learnaction.netlify.app/cute-animal-world.html)
- [DOOMSDAY TOWER DEFENSE](https://mindconvertpt.pages.dev/doomsday-tower-defense.html)
- [INDEX6](https://eduquests.netlify.app/index6.html)
- [FARM BUSINESS SAGA](https://welearnaction.onrender.com/farm-business-saga.html)
- [MINI GAMES RELAX COLLECTION 2](https://learnaction.netlify.app/mini-games-relax-collection-2.html)
- [CATEGORY BATTLE ROYALE](https://brainquesteses.pages.dev/category-battle-royale.html)
- [CATEGORY FPS 3](https://mindconvertpt.pages.dev/category-fps-3.html)
- [PIECE OF CAKE MERGE AND BAKE](https://ieduquests.web.app/piece-of-cake-merge-and-bake.html)
- [SUMMER MAZE](https://eduquestkr.pages.dev/summer-maze.html)
- [CATEGORY MAKEUP](https://jangkhangkr.pages.dev/category-makeup.html)
- [CATEGORY CASUAL 3](https://mindconvertpt.pages.dev/category-casual-3.html)
- [QUEST BY COUNTRY](https://brainquestsjp.pages.dev/quest-by-country.html)
- [MY PERFECT YEAR PLANNER](https://quizzesarena.web.app/my-perfect-year-planner.html)
- [CATEGORY WAR](https://brainquestses.pages.dev/category-war.html)
- [CATEGORY JIGSAW](https://mindconvertpt.pages.dev/category-jigsaw.html)
- [CATEGORY FLASH](https://eduquests.netlify.app/category-flash.html)
- [WIRED CHICKEN INC](https://brainquestsfr.pages.dev/wired-chicken-inc.html)
- [FRUIT SURVIVOR](https://eduquestses.pages.dev/fruit-survivor.html)
- [CATEGORY ART32](https://mindconvertpt.pages.dev/category-art32.html)
- [CATEGORY BUILDING179](https://eduquests.netlify.app/category-building179.html)
- [RETRO STREET FIGHTER](https://eduquests.netlify.app/retro-street-fighter.html)
- [CS UPGRADE GUN](https://mindconvertpt.pages.dev/cs-upgrade-gun.html)
- [CATEGORY POOL17](https://quizzesarena.web.app/category-pool17.html)
- [BUBBLE POP FAIRYLAND](https://learnaction.netlify.app/bubble-pop-fairyland.html)
- [DRUNKEN FIGHTERS](https://quizzesarena.onrender.com/drunken-fighters.html)
- [BUBBLE SHOOTER VINTAGE](https://mindconvertfr.pages.dev/bubble-shooter-vintage.html)
- [PET SALON 2](https://eduquestspt.pages.dev/pet-salon-2.html)
- [CLAW MERGE LABUBU DROP](https://jangkhangplay.pages.dev/claw-merge-labubu-drop.html)
- [POLICE TRAFFIC RACER](https://learnaction.netlify.app/police-traffic-racer.html)
- [TWO DOTS REMASTERED](https://jangkhangkr.pages.dev/two-dots-remastered.html)
- [SAND BLOCK BLAST](https://mindconvertpt.pages.dev/sand-block-blast.html)
- [SORT PARKING](https://mindconvert.onrender.com/sort-parking.html)
- [PUT THE FRUIT TOGETHER](https://brainquests.pages.dev/put-the-fruit-together.html)
