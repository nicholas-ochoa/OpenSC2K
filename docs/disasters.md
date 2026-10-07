# Disasters compared with SIMCITY.EXE

This review compares each disaster in OpenSC2K with the Windows 95
`SIMCITY.EXE` (1996). Addresses are in the executable. The native
simulation is in `native/core/sim/src/sim/disasters/` and
`native/core/sim/src/sim/moving/`.

## Common routines

| Routine | Address | Port |
| --- | --- | --- |
| Start dispatcher, per-tick loop, end | `0x0045cf10` | `SimulationEngine.start_disaster`, `advance_disaster_tick`, `end.rs` |
| Random disaster selection and city status | `0x00471bc0` | `weather.rs` |
| Marker spread: fire, flood, riots, toxic, units | `0x0045f760` | `map.rs` |
| Tile damage that starts a fire | `0x00460e10` | `damage::apply` |
| Flood damage | `0x00461000` | `damage::apply_flood` |
| Burn a structure | `0x00461330` | `damage::burn_structure` |
| Put out a fire and leave rubble | `0x004611e0` | `burn_structure` with `clear_current`, `extinguish_dispatch_fire` |
| Moving objects | `0x00450890` | `moving/phase.rs` |
| Explosion, monster, tornado | `0x004546f0`, `0x004548c0`, `0x00454ea0` | `things.rs` |
| Airplane, helicopter | `0x00453980`, `0x004540c0` | `moving/air.rs` |
| Maxis Man response | `0x00452fa0` | `end.rs` |
| Sound loop: play, end of plays, stop | `0x00480480`, `0x0047fda0`, `0x00480720` | `sound_loop.rs` in `native/core/audio` |

The random selection, the city status messages, the end summary story,
the removal of dispatched units at the end, and the check for active
monsters, tornadoes, explosions and falling planes match the original.

## Menus

The original Disasters menu has Fire, Flood, Air Crash, Tornado,
Earthquake, Monster, Hurricane, Rioters and No Disasters. Each item sets
the disaster place itself (`0x0040f5b0` to `0x0040f7b0`):

| Item | Type | Place |
| --- | --- | --- |
| Fire | 1 | city center ± 20, random (the start ignores it) |
| Flood | 2 | city center |
| Air Crash | 18 | unchanged |
| Tornado, Earthquake | 7, 6 | random map tile |
| Monster, Rioters | 8, 3 | city center − 15 + 0..31, random |
| Hurricane | 16 | unchanged |

The hidden Debug menu (`0x00412340` to `0x004124a0`) has Melt Down (9),
Microwave (10), Volcano (11, random tile), Fire Storm (12, center), Mass
Riots (13, center), Major Flood (14, random tile) and Toxic Spill
(4, center).

All menu items stay enabled during a disaster. A new disaster then starts
on the next disaster tick and replaces the active type.

## Siren and fire sounds

The original plays one sound at a time. A disaster also has one looping
sound:

- When a disaster starts, `0x0045cf10` stops all sounds and loops the
  siren (520) for five plays.
- Each scan that finds fire asks for the fire sound (507) as a loop with no
  end (`0x0045f760`). A request for the sound that loops changes nothing,
  so the fire plays without a break. A loop request during the five siren
  plays waits, and the fire starts when the siren ends.
- After its five plays, the siren continues until another loop replaces it
  or the disaster ends: `0x0047fda0` clears the count but does not stop the
  sound.
- When the disaster ends, `0x0045cf10` stops all sounds.

The port sends these requests as sound events with `loop_plays` and a stop
request. One player repeats the loop. Other sounds play over it; in the
original, they interrupt the loop, and the loop then starts again. Closing
the city or opening the main menu also stops the loop.

## Pace

The timer of SIMCITY.EXE (`0x0040c100`) marks a due tick at the pace of the
game speed: each base tick of 200 ms at Cheetah, each second tick at Llama
and each fourth tick at Turtle. In disaster mode it drops every other due
tick, except at African Swallow. A disaster therefore scans 2.5 times a
second at Cheetah, 1.25 times at Llama and 0.625 times at Turtle. Every
disaster, fires included, uses this pace (`native/core/game/src/speed.rs`).
A save keeps whether the next due tick is dropped.

## Each disaster

| Disaster | Start | Result |
| --- | --- | --- |
| Fire (1) | `0x0045e920` | Matches |
| Flood (2) | `0x0045db00` | Matches, including the seeds that depend on the search offset |
| Riots (3) | `0x0045e5f0`, three times | Matches |
| Toxic Spill (4) | `0x0045e590` | Matches |
| Air Crash (5) | none | Matches: enters disaster mode only. No menu item sends it |
| Earthquake (6) | `0x0045eb20` | Damage matches. The shake is a presentation change (see below) |
| Tornado (7) | `0x0045f090` | Matches |
| Monster (8) | `0x0045ee10` | Fixed: scenario goal and view center |
| Meltdown (9) | `0x0045f2b0` | Fixed: the plant center keeps its fire |
| Microwave (10) | `0x0045f5c0` | Matches |
| Volcano (11) | `0x0045e2a0` | Matches |
| Firestorm (12) | `0x0045e030` | Fixed: rubble does not count, disaster point |
| Mass Riots (13) | `0x0045e180` | Matches |
| Mass Floods (14) | `0x0045d9d0` | Matches |
| Pollution (15) | `0x0045d8b0` | Fixed: disaster point |
| Hurricane (16) | `0x0045d4e0` | Matches |
| Helicopter Crash (17) | none | Matches: enters disaster mode only |
| Plane Crash (18) | `0x0045e7d0` | Matches |

## Fixed differences

- **Earthquake shake.** The original moves the view 4 small-view pixels to
  the side and back 24 times, with at least 5 ms for each move. This is
  too short and fast to see on current computers. The shake now lasts
  4 seconds at 15 moves a second, moves up to 8 pixels (times the zoom),
  grows at the start, fades at the end, and repeats the rumble sound. The
  simulation event keeps the original values.
- **Tunnel entrances.** `0x00461330` does not burn a tunnel entrance.
  The port demolished the tunnel. A fire on a tunnel entrance now goes out
  and the tunnel stays.
- **Connection markers.** When a fire burns a neighbor connection marker,
  `0x00460e10` lowers the commerce count (road tiles) or the industry count
  (other tiles). The port did this only for explosions. Fires from all
  disasters now lower the counts.
- **Dust and sound.** The original shows the demolition dust and plays
  sound 504 when a fire burns out a building, when a tornado demolishes a
  tile, and when a monster with a goal demolishes a tile. The port did not.
  The dust also draws process random values in the original, so the
  random sequence now matches after these demolitions.
- **Explosions.** `0x004546f0` clears the text overlay of the explosion
  tile. The port cleared the building tile instead. The building now stays
  and a marker under the explosion goes. Rubble from an explosion is no
  damage in the original, so it does not start a fire disaster. With No
  Disasters on, an explosion damages its neighbors only in a scenario.
- **Put out fires.** A fire unit demolishes a tile past the network tiles
  when the zone byte has all four corner bits. The port read the tile
  flags.
- **Riots** follow the first straight road tile (`0x1d`) too.
- **Toxic clouds** move to the first lowest neighbor in the order north,
  east, south, west (`0x004e8828`, `0x004e8838`). The port used west,
  north, east, south. The random fallback direction uses the same order.
- **Burned chemical plants.** The original looks for the plant corner after
  the fire removed the plant, so the search fails. The toxic area then
  starts at the burning tile and goes to +x and −y. The port used the
  real plant area.
- **Meltdown.** The original burns the plant and leaves the fire on its
  center. The port put out that fire and left rubble.
- **Firestorm** counts only new fires toward its 65 tiles, and moves the
  disaster point to the last fire. **Pollution** moves the disaster point
  to its last seed. A Maxis Man goes to this point.
- **Monster.** In a scenario the monster gets no goal and draws no random
  values. The view centers 8 tiles up and to the left of the monster.
- **National Guard.** When disaster mode starts in a city with no police,
  fire, or military units, `0x0044f910` sends one military unit, plays
  sound 513 and shows notice 119 with picture 406. The port sent the unit
  without the notice.
- **Menus.** Air Crash starts a plane crash (type 18). It did nothing.
  Each menu item now selects its place as in the original, and not at the
  view center. A disaster can start during another one.

## Remaining differences

These differences are intentional:

- The Disasters menu also lists the Debug menu disasters and Pollution,
  after a separator.
- With No Disasters or the vehicle crash option, airplanes and helicopters
  leave the map instead of crashing.
- The Debug window starts any disaster at the view center.
- Larger maps scale the random places and searches by the map size.
  Layered text overlays keep markers, facilities and moving objects apart.
- At African Swallow the original scans a disaster on each pass of its main
  loop. OpenSC2K scans once per base tick, five times a second.
- The original redraws and waits during some starts (volcano, mass floods,
  earthquake). The port does not block the simulation.
