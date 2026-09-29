class_name NativeDataMapPhase
extends RefCounted

# Inline integer division avoids a function call for every cell.
@warning_ignore_start("integer_division")
# SC2X v3 per-tile rules. These differ from the original executable's coarse-grid rules.

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

# per-building tables. the per-tile loops read one table entry in place of a
# chain of range tests or a dictionary lookup
static var _pollution_weights := _make_pollution_weights()
static var _density_weights := _make_density_weights()
static var _residential_values := _make_residential_values()
static var _land_value_halved := _make_land_value_halved()


# the full monthly scan. the day schedule runs the two halves on separate days
static func run(city: CityState) -> PollutionPhase.Result:
	return NativeSimulationBridge.run("data_maps.native", city, null, null, null).result


# pollution, city center, and police and fire coverage. these read only the
# map, the previous pollution and traffic, and the budget
static func run_pollution_and_coverage(city: CityState) -> PollutionCoverageResult:
	return NativeSimulationBridge.run("data_maps.coverage", city, null, null, null).result


# land value, population density, growth, and crime. these read the pollution,
# police coverage, and city center that run_pollution_and_coverage stores
static func run_land_value_and_crime(city: CityState) -> PollutionPhase.Result:
	return NativeSimulationBridge.run("data_maps.land_value", city, null, null, null).result


# derive once from the shared rules; workers only read these tables
static func _make_pollution_weights() -> PackedInt32Array:
	var values := PackedInt32Array()
	values.resize(Tiles.COUNT)
	for building in values.size():
		values[building] = int(PollutionPhase.BUILDING_POLLUTION.get(building, 0)) * 4

	values[PollutionPhase.RADIOACTIVITY] += 800

	return values


# population weights for occupied buildings, and fixed weights for power
# plants, arcologies, and other large facilities
static func _make_density_weights() -> PackedInt32Array:
	var values := PackedInt32Array()
	values.resize(Tiles.COUNT)
	for building in values.size():
		if building >= Tiles.DEVELOPED_FIRST and building < Tiles.HYDRO_POWER_1:
			values[building] = PollutionPhase._population_weight(building)
		elif building >= Tiles.HYDRO_POWER_1:
			values[building] = 12 if building >= Tiles.PLYMOUTH_ARCOLOGY and building <= Tiles.LAUNCH_ARCOLOGY else 2

	return values


# residential desirability of a tile that is not empty. the scan sets empty
# tiles from their water flag
static func _make_residential_values() -> PackedInt32Array:
	var values := PackedInt32Array()
	values.resize(Tiles.COUNT)
	for building in values.size():
		if building == PollutionPhase.BIG_PARK:
			values[building] = 40
		elif building >= PollutionPhase.FIRST_TREE and building <= PollutionPhase.SMALL_PARK:
			values[building] = 20
		elif building < PollutionPhase.FIRST_TREE:
			values[building] = -20

	return values


static func _make_land_value_halved() -> PackedByteArray:
	var values := PackedByteArray()
	values.resize(Tiles.COUNT)
	for building: int in PollutionPhase.LAND_VALUE_HALVED:
		values[building] = 1

	return values


# police and fire stations add a coverage pattern at their origin tile
static func _add_stations(city: CityState, police: PackedByteArray, fire: PackedByteArray) -> void:
	var edge := city.map_size
	var patterns: Dictionary = {}
	var police_strength := (city.document.misc_i32(PollutionPhase.MISC_PRISON_BONUS) + 5) * PollutionPhase._budget_funding(city,
		PollutionPhase.BUDGET_POLICE) / 2
	var fire_strength := PollutionPhase._budget_funding(city, PollutionPhase.BUDGET_FIRE) * 5 / 2

	# the station list is in the order of a scan by x, then by y
	for index in city.building_indices([PollutionPhase.POLICE_STATION, PollutionPhase.FIRE_STATION]):
		if not city.zones[index] & PollutionPhase.ZONE_BUILDING_ORIGIN:
			continue

		var building := city.buildings[index]
		var strength := police_strength if building == PollutionPhase.POLICE_STATION else fire_strength

		if not city.tile_flags[index] & PollutionPhase.FLAG_POWERED:
			strength /= 2

		_checkpoint(city)

		if not patterns.has(strength):
			patterns[strength] = NativeGridMath.service_pattern(strength)

		NativeGridMath.apply_service_pattern(
			police if building == PollutionPhase.POLICE_STATION else fire,
			edge,
			Vector2i(index / edge, index % edge),
			patterns[strength],
		)


static func _checkpoint(city: CityState) -> void:
	if city.simulation_slice != null:
		city.simulation_slice.checkpoint()


# the day-two half of the monthly scan. the power scan runs first on the same
# day, so station coverage reads the new powered flags
class PollutionCoverageResult extends PhaseResult:
	var pollution_total := 0
	var city_center := Vector2i.ZERO
