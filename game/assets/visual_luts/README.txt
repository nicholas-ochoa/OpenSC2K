OpenSC2K Visual Enhancement LUT profiles

The 15 built-in profiles refine the existing seasons, light and weather. They
do not repeat their exposure changes. Day and sunny are neutral.
Morning is cool blue; evening is warm orange/yellow. Colors are uniform
across the scene, with no spatial gradient. Seasons affect masked vegetation
and ground only. Seasonal water color uses its own surface pass and strength.
Brightmaps and lightning keep their own colors. Time and season profiles
emphasize shadows and highlights, with gentle middle tones and opaque black.
Summer adds warm highlights and cool shadows rather than a neutral table.
Seasons > Seasonal water color strength blends spring blue-green, clear
summer blue, muted autumn blue-green and winter steel blue. At zero, water
bypasses both seasonal surface color and its season LUT. Turning Seasons off
also disables this water treatment. Reflections retain the reflected art's
own masks; underwater ground does not inherit the surface's water tint.

EDITING
Each PNG is an opaque 1024 x 32 RGB strip with 32 samples per RGB axis.
Pixel (blue * 32 + red, green) maps input (red, green, blue) / 31 to the
pixel's output RGB / 255. Axes run left-to-right/top-to-bottom. Blue slices
run left-to-right. All numbers describe sRGB colors, not linear light.
Use neutral.png as the starting point and apply a color adjustment to the
entire strip. Save without scaling, cropping, blur, dithering, transparency,
palette indexing or color-profile conversion. Embedded ICC metadata is not
used. PNG alpha, if present, must be fully opaque. Do not edit the strip
layout. PNG quantization can introduce a small error; the supplied exact
neutral table is detected and bypassed.

Put the named files in one folder and enter it in Visual Enhancements >
Other Effects > Custom LUT profile folder. An empty folder setting uses the
built-in profiles. Reload LUT profiles applies edits without restarting.
Missing, unreadable or invalid profiles individually fall back to neutral;
Reload displays which files failed. Export LUT profiles writes the profiles,
neutral template and these instructions, and never overwrites existing files.
With an empty folder setting, Export creates and activates visual_luts inside
the current profile (data/visual_luts in the portable Runtime).
Leave a category's strength at 0 to bypass its profiles. Disabling a category
also bypasses its LUTs. The optional single color LUT is applied after the
automatic profiles and before brightmaps; clear its path to disable it. This
single LUT accepts strip sizes from 2 to 64; automatic profiles always use 32.

PROFILES
day_morning, day_day, day_evening, day_night
season_spring, season_summer, season_autumn, season_winter
weather_sunny, weather_light_rain, weather_heavy_rain, weather_rain_thunder,
weather_dry_thunder, weather_light_snow, weather_heavy_snow

ORDER AND TRANSITIONS
Original palette -> season recoloring and masked LUT -> ambient day/night
light and its LUT -> weather tint and its LUT -> optional single LUT ->
colored/graded brightmaps. Water and moving art share ambient grading.
Time and season profiles use the existing cosmetic clock, speed and pause
settings. Weather profiles follow the selected visual weather, including
manual overrides and game weather, with its configured transition time.
Visible snow and weather frost are limited to the resolved winter season.
Requested light/heavy snow uses light/heavy rain in other seasons, including
fixed weather. The simulation weather remains unchanged. Leaving winter
removes flakes immediately even while paused; returning to winter restores
the requested snow without needing a game-weather change.
Shader interpolation is trilinear, between sample centers, without mipmaps;
the source artwork keeps its nearest-neighbor pixel-art filtering. LUT data
is sampled without implicit gamma decoding. HDR 2D input/output is explicitly
converted to/from sRGB. No city, simulation, gameplay RNG or save data changes.
