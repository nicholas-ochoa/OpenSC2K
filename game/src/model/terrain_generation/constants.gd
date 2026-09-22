class_name NewTerrainConstants
extends RefCounted

const ProcessRandom = preload("res://src/simulation/random/sim_random.gd")
const GameRandom = preload("res://src/simulation/random/game_lcg_random.gd")
const TerrainTools = preload("res://src/tools/landscape/terrain_command.gd")
const Landscapes = preload("res://src/tools/landscape/landscape_command.gd")

const LAYOUTS := ["classic", "meander", "delta", "peninsula", "crossing", "branch", "rejoin", "bay", "island", "islands", "plateau", "ridge", "valley", "rolling", "basin", "canyon", "cliffs", "lake", "lakes"]
const MAP_SIZE := 128
const TILE_COUNT := MAP_SIZE * MAP_SIZE
const MISC_SIZE := Sc2MiscLayout.SIZE
const MISC_TILE_COUNTS := Sc2MiscLayout.TILE_COUNTS
const MISC_WATER_LEVEL := Sc2MiscLayout.WATER_LEVEL
const MISC_HAS_OCEAN := Sc2MiscLayout.HAS_OCEAN
const MISC_HAS_RIVER := Sc2MiscLayout.HAS_RIVER
const FLAG_SALT_WATER := Sc2TileFlags.SALT_WATER
const FLAG_WATER := Sc2TileFlags.WATER
const FIRST_TREE := BuildingTileIds.TREE_FIRST
const LAST_TREE := BuildingTileIds.TREE_LAST
const FORBIDDEN_COAST := TerrainTileIds.FORBIDDEN_COAST
const WATERFALL := TerrainTileIds.WATERFALL

const MIN_SLIDER := 0
const MAX_SLIDER := 47
const DEFAULT_OCEAN := false
const DEFAULT_RIVER := true
const DEFAULT_HILLS := 12
const DEFAULT_WATER := 5
const DEFAULT_TREES := 15

const INTERPOLATION_PASSES := [
	Vector2i(8, 15), Vector2i(4, 7), Vector2i(2, 3), Vector2i(1, 1),
]
const CARDINAL_OFFSETS := [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]
const STREAM_X_OFFSETS := [-1, 0, 1, 0]
const STREAM_Y_OFFSETS := [0, 1, 0, -1]
const STREAM_TURN_ORDER := [0, 1, 3, 2]
