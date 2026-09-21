class_name GrowthConstants
extends RefCounted

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const MovingThings = preload("res://src/simulation/moving_things/moving_thing_spawner.gd")
const SpecialZoneGrowth = preload("res://src/simulation/growth/special_zone_growth.gd")
const MAP_VALUE_COUNT := 64 * 64
const MISC_SIZE := 4800
const MISC_TILE_COUNTS := 0x01f0
const MISC_ZONE_POPULATIONS := 0x05f0
const MISC_DEMAND := 0x0718
const MISC_BUDGETS := 0x077c
const MISC_BUDGET_RECORD_SIZE := 0x006c
const MISC_MILITARY_TILE_COUNTS := SpecialZoneGrowth.MISC_MILITARY_TILE_COUNTS
const MISC_SUBWAY_COUNT := 0x0fe8
const MISC_NORMAL_POPULATION := 0x102c
const NEWSPAPER_BRIDGE_COLLAPSE := 39
const SOUND_EXPLODE := 504
const POPULATION_BY_DENSITY := [0, 1, 8, 12, 36]
const BUILDING_BASE := [
	0, Tiles.DEVELOPED_FIRST, Tiles.RESIDENTIAL_2X2_FIRST, Tiles.RESIDENTIAL_2X2_DENSE_FIRST, Tiles.RESIDENTIAL_3X3_FIRST,
	Tiles.COMMERCIAL_1X1_FIRST, Tiles.COMMERCIAL_2X2_FIRST, Tiles.COMMERCIAL_2X2_DENSE_FIRST, Tiles.COMMERCIAL_3X3_FIRST,
	Tiles.INDUSTRIAL_1X1_FIRST, Tiles.INDUSTRIAL_2X2_FIRST, Tiles.INDUSTRIAL_2X2_DENSE_FIRST, Tiles.INDUSTRIAL_3X3_FIRST,
	Tiles.CONSTRUCTION_1X1_FIRST, Tiles.CONSTRUCTION_2X2_FIRST, Tiles.CONSTRUCTION_2X2_DENSE_FIRST, Tiles.CONSTRUCTION_3X3_FIRST,
	Tiles.ABANDONED_1X1_FIRST, Tiles.ABANDONED_2X2_FIRST, Tiles.ABANDONED_2X2_DENSE_FIRST, Tiles.ABANDONED_3X3_FIRST,
]
const BUILDING_RANGE := [
	196, 12, 4, 4, 4,
	8, 5, 5, 10,
	4, 4, 4, 6,
	2, 2, 2, 2,
	2, 2, 2, 2,
]
const ANCHOR_MASKS := [0x80, 0x10, 0x20, 0x40]
const ZONE_CORNERS_MASK := 0xf0
const CORNER_BOTTOM_LEFT := [0x10, 0x20, 0x40, 0x80]
const CORNER_BOTTOM_RIGHT := [0x20, 0x40, 0x80, 0x10]
const CORNER_TOP_LEFT := [0x40, 0x80, 0x10, 0x20]
const CORNER_TOP_RIGHT := [0x80, 0x10, 0x20, 0x40]
const STATUS_NORMAL := 0
const STATUS_CONSTRUCTION := 1
const STATUS_ABANDONED := 2
const CLASS_RESIDENTIAL := 0
const CLASS_CONSTRUCTION := 3
const CLASS_ABANDONED := 4
const CHURCH_TILE := Tiles.CHURCH

# fixed timing indices keep per-tile instrumentation inexpensive. tiles replaces
# the nine per-tile categories unless the debug window asks for detailed timing
enum TimingStep {
	PREPARE, SCAN, SURFACE, FACILITIES, SUBWAY, SPECIAL_ZONES, TRIPS,
	POPULATION, COMPLETION, RECOVERY, DENSITY, CHANGES, STORE, TILES,
}
const TIMING_LABELS := [
	"prepare and copy city data", "tile scan and eligibility",
	"surface maintenance", "facility updates and spawning",
	"subway maintenance", "airport, seaport and military growth",
	"transport trips", "population and abandonment",
	"construction completion", "abandoned building recovery",
	"density growth", "find changed chunks",
	"store growth changes", "all per-tile growth work",
]

# scanned tiles between worker checkpoints. a growth tile is expensive, so this
# stride stays far below one rendered frame
const CHECKPOINT_TILE_MASK := 15
