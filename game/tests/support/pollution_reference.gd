extends RefCounted
## Reference rules of the pollution, land value, crime, and service maps.
## The native simulation library runs the maps; tests compare it with these.

# Inline integer division avoids a function call for every cell.
@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const MAP_SIZE := 64
const MISC_CITY_POLLUTION := Sc2MiscLayout.CITY_POLLUTION
const MISC_CITY_LAND_VALUE := Sc2MiscLayout.CITY_LAND_VALUE
const MISC_CITY_CRIME := Sc2MiscLayout.CITY_CRIME
const MISC_BUDGETS := Sc2MiscLayout.BUDGETS
const MISC_BUDGET_RECORD_SIZE := Sc2BudgetLayout.RECORD_SIZE
const MISC_ORDINANCES := Sc2MiscLayout.ORDINANCES
const MISC_CITY_CENTER_X := Sc2MiscLayout.CITY_CENTER_X
const MISC_CITY_CENTER_Y := Sc2MiscLayout.CITY_CENTER_Y
const MISC_POLLUTION_BONUS := Sc2MiscLayout.INDUSTRIAL_POLLUTION_BONUS
const MISC_PRISON_BONUS := Sc2MiscLayout.PRISON_BONUS
const MISC_TREATMENT_SUFFICIENT := Sc2MiscLayout.TREATMENT_SUFFICIENT
const CLEAN_INDUSTRY_ORDINANCE := OrdinanceIds.POLLUTION_CONTROLS_MASK
const POLICE_COVERAGE_ORDINANCE := OrdinanceIds.NEIGHBORHOOD_WATCH_MASK
const FIRE_COVERAGE_ORDINANCE := OrdinanceIds.VOLUNTEER_FIRE_MASK
const CRIME_REDUCTION_ORDINANCE := OrdinanceIds.LEGALIZED_GAMBLING_MASK
const RADIOACTIVITY := Tiles.RADIOACTIVE_WASTE
const FIRST_TREE := Tiles.TREE_FIRST
const SMALL_PARK := Tiles.SMALL_PARK
const FIRST_ROAD := Tiles.FIRST_ROAD
const FIRST_POLLUTING_BUILDING := Tiles.DEVELOPED_FIRST
const BIG_PARK := Tiles.BIG_PARK
const POLICE_STATION := Tiles.POLICE_STATION
const FIRE_STATION := Tiles.FIRE_STATION
const FLAG_WATER := Sc2TileFlags.WATER
const FLAG_WATERED := Sc2TileFlags.WATERED
const FLAG_POWERED := Sc2TileFlags.POWERED
const ZONE_BUILDING_ORIGIN := 0x80
const BUDGET_POLICE := Sc2BudgetLayout.POLICE
const BUDGET_FIRE := Sc2BudgetLayout.FIRE
# The fixed land-value addition that replaces the original's uncleared scratch grid.
const LAND_VALUE_BASE := 32
const LAND_VALUE_HALVED := {
	Tiles.ABANDONED_1X1_1: true, Tiles.ABANDONED_1X1_2: true,
	Tiles.ABANDONED_2X2_1: true, Tiles.ABANDONED_2X2_2: true, Tiles.ABANDONED_2X2_3: true, Tiles.ABANDONED_2X2_4: true,
	Tiles.ABANDONED_3X3_1: true, Tiles.ABANDONED_3X3_2: true,
}
# nonzero bytes from the supplied executable table at 0x004e95b8
const BUILDING_POLLUTION := {
	Tiles.WAREHOUSE_1X1_2: 6, Tiles.CHEMICAL_STORAGE_1X1: 6, Tiles.WAREHOUSE_1X1_3: 6, Tiles.INDUSTRIAL_SUBSTATION_1X1: 6,
	Tiles.WAREHOUSE_2X2: 12, Tiles.CHEMICAL_PROCESSING_2X2: 12, Tiles.FACTORY_2X2_1: 12, Tiles.FACTORY_2X2_2: 12,
	Tiles.FACTORY_2X2_3: 18, Tiles.FACTORY_2X2_4: 18, Tiles.FACTORY_2X2_5: 18, Tiles.FACTORY_2X2_6: 18,
	Tiles.CHEMICAL_PROCESSING_3X3: 24, Tiles.LARGE_FACTORY_3X3: 24, Tiles.INDUSTRIAL_THINGAMAJIG_3X3: 24, Tiles.FACTORY_3X3: 24,
	Tiles.LARGE_WAREHOUSE_3X3: 24, Tiles.WAREHOUSE_3X3: 24,
	Tiles.GAS_POWER: 10, Tiles.OIL_POWER: 25, Tiles.NUCLEAR_POWER: 2, Tiles.FUSION_POWER: 2, Tiles.COAL_POWER: 50,
	Tiles.STADIUM: 4, Tiles.PRISON: 10, Tiles.WATER_PUMP: 2, Tiles.RUNWAY: 10, Tiles.RUNWAY_CROSSING: 10, Tiles.PIER: 10,
	Tiles.CRANE: 5, Tiles.SEAPORT_WAREHOUSE: 5, Tiles.AIRPORT_BUILDING_1: 5, Tiles.AIRPORT_BUILDING_2: 5, Tiles.TARMAC: 10,
	Tiles.FIGHTER_JET: 10,
	Tiles.SUBWAY_STATION: 5, Tiles.BUS_DEPOT: 3, Tiles.RAIL_STATION: 4, Tiles.PARKING_LOT_1: 2, Tiles.PARKING_LOT_2: 2,
	Tiles.LOADING_BAY: 2, Tiles.TOP_SECRET: 2,
	Tiles.CARGO_YARD: 10, Tiles.WATER_TREATMENT: 10, Tiles.HANGAR_2: 5, Tiles.PLYMOUTH_ARCOLOGY: 25, Tiles.FOREST_ARCOLOGY: 10,
	Tiles.DARCO_ARCOLOGY: 12, Tiles.LAUNCH_ARCOLOGY: 15,
}



# sign-extend the low word, 0x0000ffff means -1 here
static func pollution_divisor(document: Sc2File) -> int:
	# 0x0046a9a3..0x0046aa02 calculates and compares a signed 16-bit word
	# industryphase saves the low-word -1 as 0x0000ffff, not 0xffffffff
	var value := document.misc_u32(MISC_TREATMENT_SUFFICIENT) - document.misc_u32(MISC_POLLUTION_BONUS) + 4

	if document.misc_u32(MISC_ORDINANCES) & CLEAN_INDUSTRY_ORDINANCE:
		value += 1

	value &= 0xffff

	if value >= 0x8000:
		value -= 0x10000

	return maxi(value, 1)


static func _average_service_grid(
	values: PackedInt32Array, x: int, y: int, x_offset: int,
	map_edge: int = 128,
) -> int:
	var quarter_edge := map_edge / 4
	var center_index := (x + x_offset) * map_edge + y
	var total := values[center_index]
	var divisor := 1
	# keep every neighbor in the selected desirability grid
	var neighbor_row := center_index

	if x > 0:
		total += values[neighbor_row - map_edge]
		divisor += 1

	if x < quarter_edge - 1:
		total += values[neighbor_row + map_edge]
		divisor += 1

	if y > 0:
		total += values[center_index - 1]
		divisor += 1

	if y < quarter_edge - 1:
		total += values[center_index + 1]
		divisor += 1

	return _divide_toward_zero(total, divisor)


static func _budget_funding(city: CityState, budget_id: int) -> int:
	return city.document.misc_i32(
		MISC_BUDGETS + budget_id * MISC_BUDGET_RECORD_SIZE + 4
	)


static func _population_weight(building: int) -> int:
	if building >= Tiles.DEVELOPED_FIRST and building <= Tiles.CONSTRUCTION_1X1_LAST:
		return 1

	if building >= Tiles.RESIDENTIAL_2X2_FIRST and building <= Tiles.NICE_APARTMENTS_2X2_1:
		return 2

	if building >= Tiles.NICE_APARTMENTS_2X2_2 and building <= Tiles.RESIDENTIAL_2X2_LAST:
		return 3

	if building >= Tiles.COMMERCIAL_2X2_FIRST and building <= Tiles.OFFICE_BUILDING_2X2_2:
		return 2

	if building >= Tiles.OFFICE_RETAIL_2X2 and building <= Tiles.COMMERCIAL_2X2_LAST:
		return 3

	if building >= Tiles.INDUSTRIAL_2X2_FIRST and building <= Tiles.FACTORY_2X2_2:
		return 2

	if building >= Tiles.FACTORY_2X2_3 and building <= Tiles.INDUSTRIAL_2X2_LAST:
		return 3

	if building >= Tiles.CONSTRUCTION_2X2_FIRST and building <= Tiles.CONSTRUCTION_2X2_2:
		return 2

	if building >= Tiles.CONSTRUCTION_2X2_3 and building <= Tiles.CONSTRUCTION_2X2_LAST:
		return 3

	if building >= Tiles.RESIDENTIAL_3X3_FIRST and building <= Tiles.CONSTRUCTION_3X3_LAST:
		return 4

	return 0


static func _add_service(values: PackedByteArray, x: int, y: int, strength: int, map_edge: int = 128) -> void:
	_add_service_cell(values, x, y, strength, map_edge)
	var cardinal := _divide_toward_zero(strength * 4, 5)

	for point in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y - 1), Vector2i(x, y + 1)]:
		_add_service_cell(values, point.x, point.y, cardinal, map_edge)

	var diagonal := _divide_toward_zero(cardinal * 3, 4)

	for dx in [-1, 1]:
		for dy in [-1, 1]:
			_add_service_cell(values, x + dx, y + dy, diagonal, map_edge)

	var outer := _divide_toward_zero(diagonal * 2, 3)

	for major in [-2, 2]:
		for minor in [-1, 0, 1]:
			_add_service_cell(values, x + major, y + minor, outer, map_edge)
			_add_service_cell(values, x + minor, y + major, outer, map_edge)

	var fringe := _divide_toward_zero(outer, 2)

	for major in [-3, 3]:
		for minor in [-1, 0, 1]:
			_add_service_cell(values, x + major, y + minor, fringe, map_edge)
			_add_service_cell(values, x + minor, y + major, fringe, map_edge)

	for dx in [-2, 2]:
		for dy in [-2, 2]:
			_add_service_cell(values, x + dx, y + dy, fringe, map_edge)


static func _add_service_cell(
	values: PackedByteArray, x: int, y: int, strength: int,
	map_edge: int = 128,
) -> void:
	var quarter_edge := map_edge / 4

	if x < 0 or x >= quarter_edge or y < 0 or y >= quarter_edge:
		return

	var index := x * quarter_edge + y
	values[index] = clampi(int(values[index]) + strength, 0, 0xff)


static func _divide_toward_zero(value: int, divisor: int) -> int:
	return int(value / divisor)
