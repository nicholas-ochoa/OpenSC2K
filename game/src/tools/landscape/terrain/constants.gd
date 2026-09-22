class_name TerrainEditConstants
extends RefCounted

const GROUP_BULLDOZER := 0
const SUBTOOL_LEVEL := 1
const SUBTOOL_RAISE := 2
const SUBTOOL_LOWER := 3
const MILITARY_ZONE := Sc2ZoneLayout.MILITARY
const FLAG_WATER := Sc2TileFlags.WATER
const MAX_RAISE_SOURCE := 29

const NEIGHBOR_OFFSETS := [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]
const NEIGHBOR_MASKS := [3, 2, 6, 4, 12, 8, 9, 1]
const CARDINAL_OFFSETS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const RAISE_DEPENDENCY_OFFSETS := [
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1),
]
# Raise an enclosed basin by one level before assigning its XTER tile.
const RAISE_BASIN := 50
# Index by the corners that a higher neighbor raises: 1 top, 2 right, 4 bottom, 8 left.
# NEIGHBOR_MASKS use only these four bits, so this is the reachable part of the
# 256-byte executable table.
const TERRAIN_SHAPES := [
	# no bottom or left corner
	TerrainTileIds.FLAT, TerrainTileIds.CORNER_TOP,
	TerrainTileIds.CORNER_RIGHT, TerrainTileIds.SLOPE_TOP_RIGHT,
	# bottom corner
	TerrainTileIds.CORNER_BOTTOM, TerrainTileIds.RAISED,
	TerrainTileIds.SLOPE_BOTTOM_RIGHT, TerrainTileIds.RAISED_EXCEPT_LEFT,
	# left corner
	TerrainTileIds.CORNER_LEFT, TerrainTileIds.SLOPE_TOP_LEFT,
	TerrainTileIds.RAISED, TerrainTileIds.RAISED_EXCEPT_BOTTOM,
	# bottom and left corners
	TerrainTileIds.SLOPE_BOTTOM_LEFT, TerrainTileIds.RAISED_EXCEPT_RIGHT,
	TerrainTileIds.RAISED_EXCEPT_TOP, RAISE_BASIN,
]
