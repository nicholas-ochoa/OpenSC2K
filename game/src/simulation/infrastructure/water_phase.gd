class_name WaterPhase
extends RefCounted

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const MAP_SIZE := CityState.MAP_SIZE
const FLAG_WATER := Sc2TileFlags.WATER
const FLAG_WATERED := Sc2TileFlags.WATERED
const FLAG_PIPED := Sc2TileFlags.PIPED
const FLAG_POWERED := Sc2TileFlags.POWERED
const MISC_TILE_COUNTS := Sc2MiscLayout.TILE_COUNTS
const MISC_TREATMENT_SUFFICIENT := Sc2MiscLayout.TREATMENT_SUFFICIENT
const WATER_PUMP := Tiles.WATER_PUMP
const WATER_TOWER := Tiles.WATER_TOWER
const WATER_TREATMENT := Tiles.WATER_TREATMENT
const DESALINIZATION := Tiles.DESALINIZATION


static func run(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	return NativeSimulationBridge.run("water", city, null, null, null).result


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


class Result extends PhaseResult:
	var supply := 0
	var consumers := 0
	var watered_consumers := 0
	var usage_percent := 0
	var treatment_capacity := 0
	var treatment_sufficient := false
