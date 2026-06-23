class_name NewTerrainConstants
extends RefCounted

const ProcessRandom = preload("res://src/simulation/random/sim_random.gd")
const GameRandom = preload("res://src/simulation/random/game_lcg_random.gd")
const TerrainTools = preload("res://src/tools/landscape/terrain_command.gd")
const Landscapes = preload("res://src/tools/landscape/landscape_command.gd")

const LAYOUTS := ["classic", "meander", "delta", "peninsula", "crossing", "branch", "rejoin", "bay", "island", "islands", "plateau", "ridge", "valley", "rolling", "basin", "canyon", "cliffs", "lake", "lakes"]
const MAP_SIZE := 128
const TILE_COUNT := MAP_SIZE * MAP_SIZE
const MISC_SIZE := 4800
const MISC_TILE_COUNTS := 0x01f0
const MISC_WATER_LEVEL := 0x0e40
const MISC_HAS_OCEAN := 0x0e44
const MISC_HAS_RIVER := 0x0e48
const FLAG_SALT_WATER := 0x01
const FLAG_WATER := 0x04
const FIRST_TREE := 0x06
const LAST_TREE := 0x0c
const FORBIDDEN_COAST := 0x2e
const WATERFALL := 0x3e

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
