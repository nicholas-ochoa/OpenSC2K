class_name GrowthConstants
extends RefCounted

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const MovingThings = preload("res://src/simulation/moving_things/moving_thing_spawner.gd")
const SpecialZoneGrowth = preload("res://src/simulation/growth/special_zone_growth.gd")
const MAP_VALUE_COUNT := 64 * 64
const MISC_SIZE := Sc2MiscLayout.SIZE
const MISC_TILE_COUNTS := Sc2MiscLayout.TILE_COUNTS
const MISC_ZONE_POPULATIONS := Sc2MiscLayout.ZONE_POPULATIONS
const MISC_DEMAND := Sc2MiscLayout.DEMAND
const MISC_BUDGETS := Sc2MiscLayout.BUDGETS
const MISC_BUDGET_RECORD_SIZE := Sc2BudgetLayout.RECORD_SIZE
const MISC_MILITARY_TILE_COUNTS := SpecialZoneGrowth.MISC_MILITARY_TILE_COUNTS
const MISC_SUBWAY_COUNT := Sc2MiscLayout.SUBWAY_COUNT
const MISC_NORMAL_POPULATION := Sc2MiscLayout.NORMAL_POPULATION
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
const ZONE_CORNERS_MASK := Sc2ZoneLayout.CORNERS_MASK
const CORNER_TOP_RIGHT := Sc2ZoneLayout.CORNER_TOP_RIGHT
const STATUS_NORMAL := 0
const STATUS_CONSTRUCTION := 1
const STATUS_ABANDONED := 2
const CLASS_RESIDENTIAL := 0
const CLASS_CONSTRUCTION := 3
const CLASS_ABANDONED := 4
const CHURCH_TILE := Tiles.CHURCH

# fixed timing indices keep per-tile instrumentation inexpensive. tiles replaces
# the ten per-tile categories unless the debug window asks for detailed timing.
# the order is the execution order: the debug window shows the steps in this order
enum TimingStep {
	PREPARE, TILES, SCAN, SURFACE, FACILITIES, SPECIAL_ZONES, TRIPS,
	POPULATION, COMPLETION, RECOVERY, DENSITY, SUBWAY, CHANGES, STORE,
}
const TIMING_LABELS := [
	"prepare and copy city data", "all per-tile growth work",
	"tile scan and eligibility", "surface maintenance",
	"trains, sailboats and arcologies", "airport, seaport and military growth",
	"transport trips", "population and abandonment",
	"construction completion", "abandoned building recovery",
	"density growth", "subway maintenance",
	"find changed chunks", "store growth changes",
]
# the steps that each timing mode does not measure
const COARSE_TIMING_STEPS := [TimingStep.TILES]
const DETAILED_TIMING_STEPS := [
	TimingStep.SCAN, TimingStep.SURFACE, TimingStep.FACILITIES, TimingStep.SPECIAL_ZONES,
	TimingStep.TRIPS, TimingStep.POPULATION, TimingStep.COMPLETION, TimingStep.RECOVERY,
	TimingStep.DENSITY, TimingStep.SUBWAY,
]

# scanned tiles between worker checkpoints. a growth tile is expensive, so this
# stride stays far below one rendered frame
const CHECKPOINT_TILE_MASK := 15
