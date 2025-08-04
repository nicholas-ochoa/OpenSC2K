class_name DisasterDamage
extends RefCounted

const NetworkTiles = preload("res://src/tools/network_command.gd")
const Demolish = preload("res://src/tools/demolish_command.gd")
const TEXT_LABEL_BASE := 201


static func apply(
	city: CityState,
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	traffic: PackedByteArray,
	text: PackedByteArray,
	labels: PackedByteArray,
	microsims: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	random,
	lfsr_random,
	allow_small_tile := false
) -> int:
	var index := _index(point)
	if index < 0 or flags[index] & 0x04 != 0:
		return 0
	if buildings[index] < 6 and not allow_small_tile:
		return 0
	var overlay := int(text[index])
	var result_code := 1
	if overlay > 0:
		if overlay < 51:
			labels[overlay * CityState.LABEL_RECORD_SIZE] = 0
		elif overlay < TEXT_LABEL_BASE:
			burn_structure(
				city, altitude, buildings, terrain, zones, underground,
				flags, text, labels, microsims, misc, point, random, lfsr_random,
				true, false
			)
			result_code = 3
		elif overlay < 241:
			return 0
		elif overlay < 250:
			NetworkTiles._replace_building(
				buildings, zones, misc, index, lfsr_random.next_mod(4) + 1
			)
			return 2
		elif overlay != 250:
			return 0
		else:
			result_code = 4
	text[index] = 0xff
	traffic[int(point.x / 2) * 64 + int(point.y / 2)] = 0
	return result_code


static func apply_flood(
	city: CityState,
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	traffic: PackedByteArray,
	text: PackedByteArray,
	labels: PackedByteArray,
	microsims: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	maximum_altitude: int,
	random,
	lfsr_random
) -> int:
	var index := _index(point)
	if index < 0 or _altitude_word(altitude, index) & 0x1f > maximum_altitude:
		return 0
	if terrain[index] >= 0x10 and terrain[index] <= 0x1f:
		return 0
	var overlay := int(text[index])
	if overlay > 0:
		if overlay < 51:
			labels[overlay * CityState.LABEL_RECORD_SIZE] = 0
		elif overlay < TEXT_LABEL_BASE:
			burn_structure(
				city, altitude, buildings, terrain, zones, underground,
				flags, text, labels, microsims, misc, point, random, lfsr_random,
				false, false
			)
		elif overlay < 241:
			return 0
		elif overlay < 250:
			NetworkTiles._replace_building(
				buildings, zones, misc, index, lfsr_random.next_mod(4) + 1
			)
			return 2
		else:
			return 0
	text[index] = 0xfc
	traffic[int(point.x / 2) * 64 + int(point.y / 2)] = 0
	return 1


static func burn_structure(
	city: CityState,
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	labels: PackedByteArray,
	microsims: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	random,
	lfsr_random,
	mark_fire := true,
	clear_current := true
) -> Dictionary:
	var result := Demolish._demolish_point(
		city, altitude, buildings, terrain, zones, underground,
		flags, text, labels, microsims, misc, point, random, true, true, false
	)
	for index in result.get("indices", PackedInt32Array()):
		if mark_fire and flags[index] & 0x04 == 0:
			text[index] = 0xff
	var point_index := _index(point)
	if mark_fire and clear_current and point_index >= 0 and text[point_index] == 0xff:
		text[point_index] = 0
		var tile := int(buildings[point_index])
		if (tile < 0x3f or tile > 0x42) and tile < 0x61:
			NetworkTiles._replace_building(
				buildings, zones, misc, point_index, lfsr_random.next_mod(4) + 1
			)
	return result


static func _altitude_word(altitude: PackedByteArray, index: int) -> int:
	return (altitude[index * 2] << 8) | altitude[index * 2 + 1]


static func _index(point: Vector2i) -> int:
	if point.x < 0 or point.y < 0 or point.x >= CityState.MAP_SIZE or point.y >= CityState.MAP_SIZE:
		return -1
	return point.x * CityState.MAP_SIZE + point.y
