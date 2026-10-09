# Cosmetic night lighting

The Day and Night Shift options separate ambient darkness from artificial light
activation. A fixed midnight still lights windows when Night strength is reduced.
Night ambient light recovers a cool fraction of the original surface color after
LUT/weather grading. It does not lift black or affect the brightmap cores.

Light glow strength controls a visible-emission pass followed by two separable
Gaussian blur passes. The pass shares existing static meshes and textures. Unlit
opaque surfaces erase covered emission before blur. Whole-map and tiled raster
sources use their already composited brightmap masks. Masked moving sprites and
city-life lamps feed the same buffer. The padded viewport is at most 1024 pixels
on its longest edge. Menus, tools, clouds, weather and reflections are not light
sources for this pass. The original brightmap pixels stay sharp.

Street and entrance lighting adds short warm pools only to projected road/deck
receivers. Each deck's foreground mask clips the pool. It does not perform general
3D shadow casting or illuminate arbitrary facades. No water reflection effect is
added. Street locations use a stable coordinate pattern, never simulation RNG.

`game/src/view/environment/night_light_profiles.json` contains the street color,
radius (in tiles), intensity and spacing, plus optional building-ID profiles.
The initial entrance profiles cover the two 1x1 gas stations, the inn, convenience
store, two small offices and toy store. They illuminate the immediately adjacent
street approach only on equal-height ground. They do not infer window heights or
paint light over unknown building artwork. Add profiles for further building IDs
after visually checking their approaches in the original artwork.

Ground receivers are cached, rebuilt after city geometry/artwork/view changes,
and prepared with a per-frame work budget. Overview density is bounded across
the visible area. Daytime, disabled enhancements, and data/underground views
disable the light passes. Three zero strengths restore the prior lighting, apart
from the intentional separation of Night strength and artificial light activation.

Street and junction lighting includes short pixel-art lamp posts with warm heads
and wider pools on ordinary roads and road bridges. Fixtures use the same
foreground silhouettes as their road receivers. Normal T and four-way junctions
with at least three connected approaches also receive small signal heads. They
cycle through green, amber and an all-red clearance on a separate presentation
clock. Opposing approaches share a phase; crossing approaches never show green
together. The clock follows the environment speed/pause options and resets for
a newly loaded city. Signals are decorative: vehicles do not obey them, and no
traffic rules or pathfinding data are changed. Highways, rail crossings, bridge
decks and disconnected junction artwork do not receive traffic signals. Setting
the street-light strength to zero hides fixtures, signals and light pools.

All controls persist in local preferences. City documents, simulation state,
power rules, disasters and simulation random state remain unchanged.


### Included standard masks

The application includes 308 authored light masks for the standard Windows artwork
in `game/assets/brightmaps/standard`. An empty custom brightmap folder uses this set.
An explicit custom folder replaces it. The catalog checks decoded source-index
hashes before applying a mask, so other artwork cannot receive misplaced lights.
Original sprites and palettes are not included. The PNG masks are imported as
textures and the catalog is included in every export preset.

### Main menu

The scrolling menu city uses the same visual options and rendering components as
the player view: day/night, authored lights and glow, seasonal colors, weather,
clouds, water and decorative traffic. Applying options or reloading custom assets
updates the menu too. Cloud bodies keep the normal zoom-dependent visibility.
Each launch selects a random hour, season and weather for the menu using a
separate presentation RNG. Snow is selected only in winter. This atmosphere stays
fixed when returning to the menu or applying options; effect toggles, strengths
and custom assets still follow the options. Player settings are not overwritten.
The existing private menu simulation and camera sequence are unchanged. Its
render context has no active player document, save path, input or audio controller;
all menu effect layers are released when gameplay starts.
