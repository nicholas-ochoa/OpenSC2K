class_name CityValuePhase
extends RefCounted

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const MISC_SIZE := 4800
const MISC_CITY_VALUE := 0x0024
const MISC_TILE_COUNTS := 0x01f0
const MISC_SUBWAY_COUNT := 0x0fe8

# these rules reproduce the supplied executable at 0x0046a270. some values are
# defects. in particular, each underground subway tile subtracts one dollar
# the executable indexes shifted cost tables for 0xc6 through 0xcf. these are
# valuation constants, not the matching buildings' construction costs
const BUILDING_RULES := {
	Tiles.HYDRO_POWER_ONE: [1, 4000],
	Tiles.HYDRO_POWER_TWO: [1, 400],
	Tiles.WIND_POWER: [1, 6600],
	Tiles.GAS_POWER: [16, 6600],
	Tiles.OIL_POWER: [16, 2000],
	Tiles.NUCLEAR_POWER: [16, 15000],
	Tiles.SOLAR_POWER: [16, 100],
	Tiles.MICROWAVE_POWER: [16, 1300],
	Tiles.FUSION_POWER: [16, 28000],
	Tiles.COAL_POWER: [16, 40000],
	Tiles.HOSPITAL: [9, 500],
	Tiles.POLICE_STATION: [9, 500],
	Tiles.FIRE_STATION: [9, 500],
	Tiles.MUSEUM: [9, 1000],
	Tiles.BIG_PARK: [9, 150],
	Tiles.SCHOOL: [9, 250],
	Tiles.STADIUM: [16, 3000],
	Tiles.PRISON: [16, 3000],
	Tiles.COLLEGE: [16, 1000],
	Tiles.ZOO: [16, 5000],
	Tiles.WATER_PUMP: [1, 100],
	Tiles.RUNWAY: [1, 250],
	Tiles.RUNWAY_CROSSING: [1, 250],
	Tiles.PIER: [1, 150],
	Tiles.CRANE: [1, 150],
	Tiles.CONTROL_TOWER_ONE: [1, 250],
	Tiles.SEAPORT_WAREHOUSE: [1, 150],
	Tiles.AIRPORT_BUILDING_ONE: [1, 250],
	Tiles.AIRPORT_BUILDING_TWO: [1, 250],
	Tiles.TARMAC: [1, 250],
	Tiles.SUBWAY_STATION: [1, 250],
	Tiles.RADAR: [1, 250],
	Tiles.WATER_TOWER: [4, 250],
	Tiles.BUS_DEPOT: [4, 250],
	Tiles.RAIL_STATION: [4, 500],
	Tiles.PARKING_LOT_ONE: [1, 250],
	Tiles.LOADING_BAY: [1, 150],
	Tiles.CARGO_YARD: [1, 150],
	Tiles.WATER_TREATMENT: [9, 500],
	Tiles.LIBRARY: [4, 500],
	Tiles.HANGAR_TWO: [1, 250],
	Tiles.MARINA: [9, 1000],
	Tiles.DESALINIZATION: [9, 1000],
	Tiles.PLYMOUTH_ARCOLOGY: [16, 100000],
	Tiles.FOREST_ARCOLOGY: [16, 120000],
	Tiles.DARCO_ARCOLOGY: [16, 150000],
	Tiles.LAUNCH_ARCOLOGY: [16, 200000],
}


class Result extends PhaseResult:
	var city_value := 0


class MiscInput extends RefCounted:
	var ok := false
	var error := ""
	var misc := PackedByteArray()


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func calculate(city: CityState) -> Result:
	var validated := _misc_data(city)

	if not validated.ok:
		return _failed(validated.error)

	var misc: PackedByteArray = validated.misc
	var value := _to_i32(-_read_count(misc, MISC_SUBWAY_COUNT, city.map_size))

	for tile_id in range(Tiles.POWER_LINE_FIRST, Tiles.DEVELOPED_FIRST):
		var cost := 0

		if tile_id < 0x1d:
			cost = 2
		elif tile_id < 0x2c:
			cost = 10
		elif tile_id < 0x3f:
			cost = 25
		elif tile_id < 0x51:
			cost = 15
		elif tile_id < 0x61:
			cost = 100
		elif tile_id < 0x6c:
			cost = 100
		else:
			cost = 250

		value = _add_value(value, _tile_count(misc, tile_id, city.map_size), cost)

	for tile_id in BUILDING_RULES:
		var rule: Array = BUILDING_RULES[tile_id]
		var count := _divide_toward_zero(_tile_count(misc, tile_id, city.map_size), int(rule[0]))
		value = _add_value(value, count, int(rule[1]))

	var result := Result.new()
	result.ok = true
	result.city_value = value

	return result


static func run(city: CityState) -> Result:
	var calculated := calculate(city)

	if not calculated.ok:
		return calculated

	var misc_chunk := city.document.find_chunk("MISC")
	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	_write_i32(misc, MISC_CITY_VALUE, int(calculated.city_value))

	if not misc_chunk.set_decoded_payload(misc):
		return _failed("cannot store the city value")

	return calculated


static func _misc_data(city: CityState) -> MiscInput:
	var result := MiscInput.new()

	if city == null or not city.is_valid():
		result.error = "city is invalid"

		return result

	var misc_chunk := city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		result.error = "MISC is missing or has the wrong size"

		return result

	result.ok = true
	result.misc = misc_chunk.decoded_payload

	return result


static func _tile_count(misc: PackedByteArray, tile_id: int, map_edge: int = 128) -> int:
	return _read_count(misc, MISC_TILE_COUNTS + tile_id * 4, map_edge)


static func _read_count(misc: PackedByteArray, offset: int, map_edge: int) -> int:
	return _read_i16_low(misc, offset) if map_edge == 128 else ((misc[offset] << 24) | (misc[offset + 1] << 16) | (misc[offset + 2] << 8) | misc[offset + 3])


static func _add_value(current: int, count: int, cost: int) -> int:
	return _to_i32(current + _to_i32(count * cost))


static func _divide_toward_zero(value: int, divisor: int) -> int:
	var quotient := int(absi(value) / absi(divisor))

	return -quotient if value < 0 else quotient


static func _read_i16_low(data: PackedByteArray, offset: int) -> int:
	var value := (data[offset + 2] << 8) | data[offset + 3]

	return value - 0x10000 if value & 0x8000 else value


static func _to_i32(value: int) -> int:
	var unsigned := value & 0xffffffff

	return unsigned - 0x100000000 if unsigned & 0x80000000 else unsigned


static func _write_i32(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff
