# City-life vehicle artwork

`vehicles_b.png` contains the original approved Set B views: four isometric
headings, three vehicle kinds and eighteen paint/body variants per kind.

`vehicles_diagonal.png` adds the four screen-axis headings for diagonal road
and highway tiles. It renders the same original box models, paint, glazing,
fixed world lighting and front/rear lamps at 45-degree world rotations.
These are authored pixels, not images from SimCity 2000. Existing Set B frames
are unchanged. No resampling, flipping or rotation of the existing raster
frames is used.

The added atlas has four 20 by 14 pixel columns (screen E, S, W, N) and 54 rows
(car, truck, bus, each with eighteen variants). Transparent cell margins are
removed once when each cached sprite is created. Sprites retain a centered
bottom anchor and use nearest-neighbor rendering. Lamp colors are `e9dfba`
(front) and `ab423b` (rear), matching the existing emission-mask contract.
