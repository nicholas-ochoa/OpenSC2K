class_name RciAftermathPhase
extends RefCounted

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const MISC_SIZE := Sc2MiscLayout.SIZE
const MISC_START_YEAR := Sc2MiscLayout.START_YEAR
const MISC_WEATHER_TREND := Sc2MiscLayout.WEATHER_TREND
const MISC_INVENTION_YEARS := Sc2MiscLayout.INVENTION_YEARS
const MISC_TILE_COUNTS := Sc2MiscLayout.TILE_COUNTS
const MISC_MILITARY_TILE_COUNTS := Sc2MiscLayout.MILITARY_TILE_COUNTS
const MISC_STADIUM_TEAMS := Sc2MiscLayout.STADIUM_TEAMS
const RADIOACTIVITY_TILE := Tiles.RADIOACTIVE_WASTE
const INVENTION_COUNT := 17
const NEWS_JUNK := 0x01
const WEATHER_NAMES := [
	"Cold", "Clear", "Hot", "Foggy", "Chilly", "Overcast",
	"Snow", "Rain", "Windy", "Blizzard", "Hurricane", "Tornado",
]
# four 12-by-8 season blocks. each row is the current weather trend and each
# column is the low three bits of the process-random value
const WEATHER_TRANSITIONS := [
	# season 0
	0, 0, 0, 3, 4, 5, 1, 8,
	1, 1, 1, 0, 0, 3, 4, 8,
	2, 1, 1, 1, 8, 8, 5, 3,
	3, 3, 0, 1, 4, 5, 8, 7,
	4, 4, 0, 1, 4, 5, 7, 6,
	5, 5, 1, 4, 3, 7, 7, 8,
	6, 6, 7, 7, 5, 4, 0, 9,
	7, 7, 7, 6, 8, 8, 4, 3,
	8, 8, 8, 7, 7, 5, 4, 4,
	9, 6, 6, 6, 6, 7, 7, 3,
	7, 7, 6, 6, 7, 7, 7, 8,
	8, 8, 8, 8, 8, 7, 6, 4,
	# season 1
	0, 0, 0, 1, 1, 1, 3, 4,
	1, 1, 1, 1, 2, 2, 0, 4,
	2, 2, 2, 1, 1, 5, 4, 3,
	3, 3, 0, 8, 1, 1, 4, 7,
	4, 4, 4, 1, 8, 0, 5, 3,
	5, 5, 5, 7, 2, 4, 1, 8,
	6, 7, 7, 7, 3, 8, 5, 5,
	7, 7, 7, 6, 3, 5, 8, 10,
	8, 8, 8, 7, 5, 4, 1, 1,
	7, 6, 6, 7, 7, 8, 8, 4,
	10, 7, 7, 7, 8, 8, 4, 4,
	8, 8, 8, 8, 8, 4, 1, 2,
	# season 2
	0, 0, 0, 1, 1, 1, 3, 4,
	1, 1, 1, 1, 2, 2, 0, 4,
	2, 2, 2, 1, 1, 5, 4, 3,
	3, 3, 0, 8, 1, 1, 4, 7,
	4, 4, 4, 1, 8, 0, 5, 3,
	5, 5, 5, 7, 2, 4, 1, 8,
	6, 7, 7, 7, 3, 8, 5, 4,
	7, 7, 7, 6, 3, 5, 8, 8,
	8, 8, 8, 7, 5, 4, 1, 11,
	7, 6, 6, 7, 7, 8, 8, 4,
	6, 7, 7, 7, 8, 8, 4, 4,
	11, 8, 8, 8, 8, 4, 1, 2,
	# season 3
	0, 0, 0, 3, 4, 5, 1, 8,
	1, 1, 1, 0, 0, 3, 4, 8,
	2, 1, 1, 1, 8, 8, 5, 3,
	3, 3, 0, 1, 4, 5, 8, 7,
	4, 4, 0, 1, 4, 5, 7, 6,
	5, 5, 1, 4, 3, 7, 7, 8,
	6, 6, 7, 7, 5, 4, 0, 0,
	7, 7, 7, 6, 8, 4, 3, 10,
	8, 8, 8, 7, 7, 5, 4, 5,
	6, 6, 6, 6, 7, 7, 7, 3,
	10, 7, 6, 6, 7, 7, 7, 8,
	8, 8, 8, 8, 8, 7, 6, 4,
]
const MILITARY_TILE_COUNT_INDEX := {
	Tiles.RUNWAY: 1, Tiles.RUNWAY_CROSSING: 2, Tiles.PARKING_LOT_2: 3, Tiles.CARGO_YARD: 4, Tiles.RADAR: 5, Tiles.SEAPORT_WAREHOUSE: 6,
	Tiles.AIRPORT_BUILDING_1: 7, Tiles.AIRPORT_BUILDING_2: 8, Tiles.TOP_SECRET: 9, Tiles.CRANE: 10, Tiles.CONTROL_TOWER_2: 11,
	Tiles.FIGHTER_JET: 12,
	Tiles.HANGAR_1: 13, Tiles.HANGAR_2: 14, Tiles.MISSILE_SILO: 15,
}


static func weather_transition(current_trend: int, season: int, roll: int) -> int:
	if current_trend < 0 or current_trend >= 12 or season < 0 or season >= 4:
		return -1

	return WEATHER_TRANSITIONS[(season * 12 + current_trend) * 8 + (roll & 7)]


static func _replace_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	var old_tile := int(buildings[index])

	if old_tile == new_tile:
		return

	var military := (zones[index] & Sc2ZoneLayout.TYPE_MASK) == 7
	var old_offset := _tile_count_offset(old_tile, military)
	var new_offset := _tile_count_offset(new_tile, military)
	BinaryData.write_u32_be(
		misc,
		old_offset,
		(BinaryData.read_u32_be(misc, old_offset) - 1) & (0xffff if buildings.size() == 16384 else 0xffffffff),
	)
	BinaryData.write_u32_be(
		misc,
		new_offset,
		(BinaryData.read_u32_be(misc, new_offset) + 1) & (0xffff if buildings.size() == 16384 else 0xffffffff),
	)
	buildings[index] = new_tile


static func _tile_count_offset(tile: int, military: bool) -> int:
	if not military:
		return MISC_TILE_COUNTS + tile * 4

	return MISC_MILITARY_TILE_COUNTS + int(MILITARY_TILE_COUNT_INDEX.get(tile, 0)) * 4


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func run(city: CityState, random: SimRandom, season: int) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	if random == null:
		return _failed("a compatible process random generator is required")

	return NativeSimulationBridge.run("rci_aftermath", city, random, null, null, {"season": season}).result


class MapChange extends RefCounted:
	var point: Vector2i
	var old_tile: int
	var new_tile: int

	func _init(location: Vector2i, previous: int, replacement: int) -> void:
		point = location
		old_tile = previous
		new_tile = replacement


class Result extends PhaseResult:
	var season := 0
	var old_weather_trend := 0
	var weather_trend := 0
	var weather_name := ""
	var weather_roll := 0
	var heat := 0
	var wind := 0
	var rain := 0
	var map_changes: Array[MapChange] = []
	var map_changed := false
	var invention_index := -1
