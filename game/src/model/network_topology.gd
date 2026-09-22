class_name NetworkTopology
extends RefCounted
## Tile offsets for cardinal network connections.

# The mask bits are north = 1, east = 2, south = 4, and west = 8.
# Add the selected offset to the network's first tile ID. Callers keep their
# own slope, neighbor eligibility, map-edge, and isolated-pipe rules.
const SHAPE_OFFSET_BY_CONNECTION_MASK := [0, 0, 1, 6, 0, 0, 7, 11, 1, 9, 1, 10, 8, 13, 12, 14]
