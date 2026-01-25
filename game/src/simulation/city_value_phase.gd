class_name CityValuePhase
extends RefCounted

const MISC_SIZE := 4800
const MISC_CITY_VALUE := 0x0024
const MISC_TILE_COUNTS := 0x01f0
const MISC_SUBWAY_COUNT := 0x0fe8

# these rules reproduce the supplied executable at 0x0046a270. some values are
# defects. in particular, each underground subway tile subtracts one dollar
const BUILDING_RULES := {
	0xc6: [1, 400],
	0xc7: [1, 400],
	0xc8: [1, 100],
	0xc9: [16, 2000],
	0xca: [16, 6600],
	0xcb: [16, 15000],
	0xcc: [16, 1300],
	0xcd: [16, 28000],
	0xce: [16, 40000],
	0xcf: [16, 4000],
	0xd1: [9, 500],
	0xd2: [9, 500],
	0xd3: [9, 500],
	0xd4: [9, 1000],
	0xd5: [9, 150],
	0xd6: [9, 250],
	0xd7: [16, 5000],
	0xd8: [16, 3000],
	0xd9: [16, 1000],
	0xda: [16, 3000],
	0xdc: [1, 100],
	0xdd: [1, 250],
	0xde: [1, 250],
	0xdf: [1, 150],
	0xe0: [1, 150],
	0xe1: [1, 250],
	0xe3: [1, 150],
	0xe4: [1, 250],
	0xe5: [1, 250],
	0xe6: [1, 250],
	0xe9: [1, 250],
	0xea: [1, 250],
	0xeb: [4, 250],
	0xec: [4, 250],
	0xed: [4, 500],
	0xee: [1, 250],
	0xf0: [1, 150],
	0xf2: [1, 150],
	0xf4: [9, 500],
	0xf5: [4, 500],
	0xf6: [1, 250],
	0xf8: [9, 1000],
	0xfa: [9, 1000],
	0xfb: [16, 100000],
	0xfc: [16, 120000],
	0xfd: [16, 150000],
	0xfe: [16, 200000],
}


static func calculate(city: CityState) -> Dictionary:
	var validated := _misc_data(city)
	if not validated.ok:
		return validated
	var misc: PackedByteArray = validated.misc
	var value := _to_i32(-_read_count(misc, MISC_SUBWAY_COUNT, city.map_size))
	for tile_id in range(0x0e, 0x70):
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
	return {"ok": true, "error": "", "city_value": value}


static func run(city: CityState) -> Dictionary:
	var calculated := calculate(city)
	if not calculated.ok:
		return calculated
	var misc_chunk := city.document.find_chunk("MISC")
	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	_write_i32(misc, MISC_CITY_VALUE, int(calculated.city_value))
	if not misc_chunk.set_decoded_payload(misc):
		return {"ok": false, "error": "cannot store the city value"}
	return calculated


static func _misc_data(city: CityState) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	var misc_chunk := city.document.find_chunk("MISC")
	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		return {"ok": false, "error": "MISC is missing or has the wrong size"}
	return {"ok": true, "error": "", "misc": misc_chunk.decoded_payload}


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
