class_name DisasterDamage
extends RefCounted

const Demolish = preload("res://src/tools/city/demolish_command.gd")
const TEXT_LABEL_BASE := 201
const SOUND_DAMAGE := 0x1f8


static func new_runtime_events() -> Dictionary:
	return {
		"effect_events": [] as Array[Dictionary],
		"sound_events": [] as Array[int],
		"next_effect_frame": 0,
	}


static func append_damage_events(runtime_events: Dictionary, damage: Dictionary) -> void:
	if runtime_events.is_empty():
		return

	var source: Array = damage.get("effect_events", [])

	if source.is_empty():
		return

	var destination: Array[Dictionary] = runtime_events.get("effect_events", [])
	runtime_events["next_effect_frame"] = Demolish.append_effect_sequence(
		destination, source, int(runtime_events.get("next_effect_frame", 0))
	)
	runtime_events["effect_events"] = destination
	var sounds: Array[int] = runtime_events.get("sound_events", [])
	sounds.append(SOUND_DAMAGE)
	runtime_events["sound_events"] = sounds


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
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	allow_small_tile := false,
	runtime_events: Dictionary = {},
) -> int:
	var map_edge: int = city.map_size if city != null else 128
	var index := _index(point, map_edge)

	if index < 0 or flags[index] & 0x04 != 0:
		return 0

	if buildings[index] < 6 and not allow_small_tile:
		return 0

	var overlay := int(OverlayData.read(text, index))
	var result_code := 1

	if overlay > 0:
		if (overlay == 0 or OverlayData.is_sign(overlay)):
			labels[overlay * CityState.LABEL_RECORD_SIZE] = 0
		elif OverlayData.is_facility(overlay):
			var damage := burn_structure(
				city, altitude, buildings, terrain, zones, underground,
				flags, text, labels, microsims, misc, point, random, lfsr_random,
				true, false, true
			)
			append_damage_events(runtime_events, damage)
			result_code = 3
		elif OverlayData.is_thing(overlay):
			return 0
		elif overlay < 250:
			NetworkState.replace_building(
				buildings, zones, misc, index, lfsr_random.next_mod(4) + 1
			)

			return 2
		elif overlay != 250:
			return 0
		else:
			result_code = 4

	OverlayData.write(text, index, 0xff)
	traffic[CityDataGrid.index(traffic, map_edge, point.x, point.y)] = 0

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
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	runtime_events: Dictionary = {},
) -> int:
	var map_edge: int = city.map_size if city != null else 128
	var index := _index(point, map_edge)

	if index < 0 or _altitude_word(altitude, index) & 0x1f > maximum_altitude:
		return 0

	if terrain[index] >= 0x10 and terrain[index] <= 0x1f:
		return 0

	var overlay := int(OverlayData.read(text, index))

	if overlay > 0:
		if (overlay == 0 or OverlayData.is_sign(overlay)):
			labels[overlay * CityState.LABEL_RECORD_SIZE] = 0
		elif OverlayData.is_facility(overlay):
			var damage := burn_structure(
				city, altitude, buildings, terrain, zones, underground,
				flags, text, labels, microsims, misc, point, random, lfsr_random,
				false, false, true
			)
			append_damage_events(runtime_events, damage)
		elif OverlayData.is_thing(overlay):
			return 0
		elif overlay < 250:
			NetworkState.replace_building(
				buildings, zones, misc, index, lfsr_random.next_mod(4) + 1
			)

			return 2
		else:
			return 0

	OverlayData.write(text, index, 0xfc)
	traffic[CityDataGrid.index(traffic, map_edge, point.x, point.y)] = 0

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
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	mark_fire := true,
	clear_current := true,
	emit_effects := false
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128
	var result := Demolish._demolish_point(
		city, altitude, buildings, terrain, zones, underground,
		flags, text, labels, microsims, misc, point, random, true, true, emit_effects
	)

	for index in result.get("indices", PackedInt32Array()):
		if mark_fire and flags[index] & 0x04 == 0:
			OverlayData.write(text, index, 0xff)

	var point_index := _index(point, map_edge)

	if mark_fire and clear_current and point_index >= 0 and OverlayData.read(text, point_index) == 0xff:
		OverlayData.write(text, point_index, 0)
		var tile := int(buildings[point_index])

		if (tile < 0x3f or tile > 0x42) and tile < 0x61:
			NetworkState.replace_building(
				buildings, zones, misc, point_index, lfsr_random.next_mod(4) + 1
			)

	return result


static func _altitude_word(altitude: PackedByteArray, index: int) -> int:
	return (altitude[index * 2] << 8) | altitude[index * 2 + 1]


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if point.x < 0 or point.y < 0 or point.x >= map_edge or point.y >= map_edge:
		return -1

	return point.x * map_edge + point.y
