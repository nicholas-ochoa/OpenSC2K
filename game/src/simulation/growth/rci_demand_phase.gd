class_name RciDemandPhase
extends RefCounted

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const ZONE_POPULATION_OFFSET := Sc2MiscLayout.ZONE_POPULATIONS
const DEMAND_OFFSET := Sc2MiscLayout.DEMAND
const BUDGET_RECORD_SIZE := Sc2BudgetLayout.RECORD_SIZE
const TILE_COUNT_OFFSET := Sc2MiscLayout.TILE_COUNTS
const ORDINANCES_OFFSET := Sc2MiscLayout.ORDINANCES
const ARCOLOGY_POPULATION_OFFSET := Sc2MiscLayout.ARCOLOGY_POPULATION
const NORMAL_POPULATION_OFFSET := Sc2MiscLayout.NORMAL_POPULATION
const INDUSTRIAL_MIX_BONUS_OFFSET := Sc2MiscLayout.INDUSTRIAL_MIX_BONUS
const OLD_RESIDENTIAL_POPULATION_OFFSET := Sc2MiscLayout.OLD_RESIDENTIAL_POPULATION
const GARBAGE_OFFSET := Sc2MiscLayout.GARBAGE
const CONNECTION_LABEL := Sc2OverlayLayout.CONNECTION_MARKER
const RATIO_SCALE := 600.0
const COMMERCIAL_SCALE := 0.000006666666666666667
const INDUSTRIAL_MIX_SCALE := 0.01
const MINIMUM_INDUSTRIAL_TARGET := 15.0
const TAX_EFFECT := [
	200, 160, 120, 100, 75, 50, 25, 0, -25, -50, -100, -150,
	-200, -250, -300, -350, -400, -450, -500, -550, -600, -650, -700,
]
const INDUSTRIAL_DIFFICULTY := [0.0, 1.2, 1.1, 0.95]
const COMMERCE_CONNECTION_RANGES := [
	Vector2i(Tiles.ROAD_STRAIGHT_1, Tiles.ROAD_CROSSROADS),
	Vector2i(Tiles.TUNNEL_ENTRANCE_1, Tiles.TUNNEL_ENTRANCE_4),
	Vector2i(Tiles.HIGHWAY_ROAD_CROSSING_1, Tiles.HIGHWAY_ROAD_CROSSING_2),
	Vector2i(Tiles.HIGHWAY_ONRAMP_1, Tiles.HIGHWAY_ONRAMP_4),
]
const INDUSTRY_CONNECTION_RANGES := [
	Vector2i(Tiles.RAIL_STRAIGHT_1, Tiles.RAIL_SLOPE_8),
	Vector2i(Tiles.ROAD_RAIL_CROSSING_1, Tiles.HIGHWAY_POWER_CROSSING_2),
	Vector2i(Tiles.HIGHWAY_SLOPE_1, Tiles.HIGHWAY_INTERSECTION),
]


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


# the native find skips the tiles without the label low byte. a full scan in
# script took about 100 ms on a 512 map
static func connection_counts(city: CityState) -> ConnectionCounts:
	var overlays := city.text_overlays
	var buildings := city.buildings
	var cells := OverlayData.count(overlays)
	var low_byte := CONNECTION_LABEL & 0xff
	var commerce := 0
	var industry := 0
	var index := overlays.find(low_byte)

	# the high bytes of an sc2x label plane follow the low bytes
	while index >= 0 and index < cells:
		var tile := buildings[index]
		var labelled := OverlayData.read(overlays, index) == CONNECTION_LABEL
		index = overlays.find(low_byte, index + 1)

		if not labelled:
			continue

		if _in_ranges(tile, COMMERCE_CONNECTION_RANGES):
			commerce += 1

		if _in_ranges(tile, INDUSTRY_CONNECTION_RANGES):
			industry += 1

	var result := ConnectionCounts.new()
	result.commerce = commerce
	result.industry = industry

	return result


static func _in_ranges(value: int, ranges: Array) -> bool:
	for range_value in ranges:
		if value >= range_value.x and value <= range_value.y:
			return true

	return false


static func _tile_count(city: CityState, tile_id: int) -> int:
	return city.document.misc_i32(TILE_COUNT_OFFSET + tile_id * 4)


static func _ordinance_adjusted_tax_rate(category: int, rate: int, flags: int) -> int:
	match category:
		0:
			if flags & OrdinanceIds.INCOME_TAX_MASK:
				rate += 1

			if flags & OrdinanceIds.CITY_BEAUTIFICATION_MASK:
				rate -= 1
		1:
			if flags & OrdinanceIds.SALES_TAX_MASK:
				rate += 1

			for mask in [OrdinanceIds.TOURIST_ADVERTISING_MASK, OrdinanceIds.ANNUAL_CARNIVAL_MASK, OrdinanceIds.HOMELESS_SHELTER_MASK]:
				if flags & mask:
					rate -= 1
		2:
			if flags & OrdinanceIds.BUSINESS_ADVERTISING_MASK:
				rate -= 1

			if flags & OrdinanceIds.POLLUTION_CONTROLS_MASK:
				rate += 1

	return maxi(rate, 0)


static func run(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	return NativeSimulationBridge.run("rci_demand", city, null, null, null).result


class Result extends PhaseResult:
	var previous_population := 0
	var normal_population := 0
	var tax_population := PackedInt64Array()
	var targets: Array[float] = []
	var demands := PackedInt32Array()
	var commerce_connections := 0
	var industry_connections := 0


class ConnectionCounts extends RefCounted:
	var commerce := 0
	var industry := 0
