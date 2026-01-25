class_name CityRotationCommand
extends RefCounted

const MAP_SIZE := CityState.MAP_SIZE
const COMPASS_OFFSET := 0x0008
const TILE_COUNT_OFFSET := 0x01f0
const MILITARY_ZONE := 7
const FLIP_FLAG := 0x02

const REQUIRED_CHUNKS := [
	["MISC", 4800],
	["ALTM", 32768],
	["XTER", 16384],
	["XBLD", 16384],
	["XZON", 16384],
	["XUND", 16384],
	["XTXT", 16384],
	["XTHG", 480],
	["XBIT", 16384],
	["XTRF", 4096],
	["XPLT", 4096],
	["XVAL", 4096],
	["XCRM", 4096],
	["XPLC", 1024],
	["XFIR", 1024],
	["XPOP", 1024],
	["XROG", 1024],
]


# View rotation rewrites the saved city coordinates.
static func apply(city: CityState, counter_clockwise: bool) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	var old_payloads := _payloads(city)
	if old_payloads.is_empty():
		return {"ok": false, "error": "rotation data is missing or invalid"}
	var changed := _duplicate_payloads(old_payloads)
	var surface_table := _surface_table(counter_clockwise)
	changed.ALTM = _rotate_grid(changed.ALTM, map_edge, 2, counter_clockwise)
	changed.XTER = _rotate_byte_grid(
		changed.XTER, map_edge, counter_clockwise, _terrain_table(counter_clockwise)
	)
	changed.XBLD = _rotate_byte_grid(
		changed.XBLD, map_edge, counter_clockwise, surface_table
	)
	changed.XZON = _rotate_grid(changed.XZON, map_edge, 1, counter_clockwise)
	changed.XUND = _rotate_byte_grid(
		changed.XUND, map_edge, counter_clockwise, _underground_table(counter_clockwise)
	)
	changed.XTXT = _rotate_grid(changed.XTXT, map_edge, 1, counter_clockwise)
	changed.XBIT = _rotate_grid(changed.XBIT, map_edge, 1, counter_clockwise)
	_rotate_surface_tile_counts(changed.MISC, surface_table)
	_rotate_special_surface(
		changed.XBLD,
		changed.XZON,
		changed.XBIT,
		changed.MISC,
		surface_table,
		counter_clockwise,
	)
	for chunk_id in ["XTRF", "XPLT", "XVAL", "XCRM"]:
		changed[chunk_id] = _rotate_grid(changed[chunk_id], map_edge / 2, 1, counter_clockwise)
	for chunk_id in ["XPLC", "XFIR", "XPOP", "XROG"]:
		changed[chunk_id] = _rotate_grid(changed[chunk_id], map_edge / 4, 1, counter_clockwise)
	_rotate_things(changed.XTHG, counter_clockwise, map_edge)
	var old_compass := _read_u32_be(changed.MISC, COMPASS_OFFSET) & 3
	var new_compass := (old_compass + (1 if counter_clockwise else 3)) & 3
	_write_u32_be(changed.MISC, COMPASS_OFFSET, new_compass)

	var changed_ids := PackedStringArray()
	for specification in REQUIRED_CHUNKS:
		var chunk_id: String = specification[0]
		if changed[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)
	if not _apply_payloads(city, changed_ids, changed, old_payloads):
		return {"ok": false, "error": "cannot store rotated city data"}
	return {
		"ok": true,
		"counter_clockwise": counter_clockwise,
		"old_compass": old_compass,
		"new_compass": new_compass,
		"changed_ids": changed_ids,
		"error": "",
	}


static func rotate_point(point: Vector2i, size: int, counter_clockwise: bool) -> Vector2i:
	if size < 1 or point.x < 0 or point.x >= size or point.y < 0 or point.y >= size:
		return Vector2i(-1, -1)
	if counter_clockwise:
		return Vector2i(point.y, size - 1 - point.x)
	return Vector2i(size - 1 - point.y, point.x)


static func surface_tile_after_rotation(tile: int, counter_clockwise: bool) -> int:
	if tile < 0 or tile > 0xff:
		return tile
	return _surface_table(counter_clockwise)[tile]


static func terrain_tile_after_rotation(tile: int, counter_clockwise: bool) -> int:
	var table := _terrain_table(counter_clockwise)
	return table[tile] if tile >= 0 and tile < table.size() else tile


static func underground_tile_after_rotation(tile: int, counter_clockwise: bool) -> int:
	var table := _underground_table(counter_clockwise)
	return table[tile] if tile >= 0 and tile < table.size() else tile


static func _payloads(city: CityState) -> Dictionary:
	var result := {}
	for specification in REQUIRED_CHUNKS:
		var chunk_id: String = specification[0]
		var expected_size: int = city.document.decoded_size(chunk_id)
		var chunk := city.document.find_chunk(chunk_id)
		if chunk == null or chunk.decoded_payload.size() != expected_size:
			return {}
		result[chunk_id] = chunk.decoded_payload.duplicate()
	return result


static func _duplicate_payloads(payloads: Dictionary) -> Dictionary:
	var result := {}
	for chunk_id in payloads:
		result[chunk_id] = payloads[chunk_id].duplicate()
	return result


static func _apply_payloads(
	city: CityState, chunk_ids: PackedStringArray, payloads: Dictionary, rollback: Dictionary
) -> bool:
	var applied := PackedStringArray()
	for chunk_id in chunk_ids:
		var chunk := city.document.find_chunk(chunk_id)
		if chunk == null or not chunk.set_decoded_payload(payloads[chunk_id]):
			for rollback_id in applied:
				city.document.find_chunk(rollback_id).set_decoded_payload(rollback[rollback_id])
			_sync_city_arrays(city)
			return false
		applied.append(chunk_id)
	_sync_city_arrays(city)
	return true


static func _sync_city_arrays(city: CityState) -> void:
	var map_edge: int = city.map_size if city != null else 128
	var altitude: PackedByteArray = city.document.find_chunk("ALTM").decoded_payload
	for index in (map_edge * map_edge):
		city.altitude_words[index] = (altitude[index * 2] << 8) | altitude[index * 2 + 1]
	city.terrain = city.document.find_chunk("XTER").decoded_payload.duplicate()
	city.buildings = city.document.find_chunk("XBLD").decoded_payload.duplicate()
	city.zones = city.document.find_chunk("XZON").decoded_payload.duplicate()
	city.underground = city.document.find_chunk("XUND").decoded_payload.duplicate()
	city.text_overlays = city.document.find_chunk("XTXT").decoded_payload.duplicate()
	city.tile_flags = city.document.find_chunk("XBIT").decoded_payload.duplicate()


# Scan x first to match the original rotation order.
static func _rotate_grid(
	input: PackedByteArray, size: int, record_size: int, counter_clockwise: bool
) -> PackedByteArray:
	var output := PackedByteArray()
	output.resize(input.size())
	for old_x in size:
		for old_y in size:
			var destination := rotate_point(
				Vector2i(old_x, old_y), size, counter_clockwise
			)
			var source_offset := (old_x * size + old_y) * record_size
			var destination_offset := (destination.x * size + destination.y) * record_size
			for byte_index in record_size:
				output[destination_offset + byte_index] = input[source_offset + byte_index]
	return output


static func _rotate_byte_grid(
	input: PackedByteArray,
	size: int,
	counter_clockwise: bool,
	mapping: PackedByteArray
) -> PackedByteArray:
	var output := _rotate_grid(input, size, 1, counter_clockwise)
	for index in output.size():
		var value := int(output[index])
		if value < mapping.size():
			output[index] = mapping[value]
	return output


static func _identity_table(size: int) -> PackedByteArray:
	var table := PackedByteArray()
	table.resize(size)
	for index in size:
		table[index] = index
	return table


# the tile number has a direction baked into it too
static func _surface_table(counter_clockwise: bool) -> PackedByteArray:
	var table := _identity_table(256)
	for pair in [
		[0x0e, 0x0f], [0x1d, 0x1e], [0x2c, 0x2d], [0x43, 0x44],
		[0x45, 0x46], [0x47, 0x48], [0x49, 0x4a], [0x4b, 0x4c],
		[0x4d, 0x4e], [0x4f, 0x50], [0x51, 0x55], [0x52, 0x54],
	]:
		_swap(table, pair[0], pair[1])
	for cycle in [
		[0x10, 0x11, 0x12, 0x13], [0x14, 0x15, 0x16, 0x17],
		[0x18, 0x19, 0x1a, 0x1b], [0x1f, 0x20, 0x21, 0x22],
		[0x23, 0x24, 0x25, 0x26], [0x27, 0x28, 0x29, 0x2a],
		[0x2e, 0x2f, 0x30, 0x31], [0x32, 0x33, 0x34, 0x35],
		[0x36, 0x37, 0x38, 0x39], [0x3b, 0x3c, 0x3d, 0x3e],
		[0x3f, 0x40, 0x41, 0x42], [0x61, 0x62, 0x63, 0x64],
		[0x65, 0x66, 0x67, 0x68], [0x6c, 0x6d, 0x6e, 0x6f],
	]:
		_set_cycle(table, cycle, counter_clockwise)
	return table


# four turns won't recover garbage tile ids
static func _terrain_table(counter_clockwise: bool) -> PackedByteArray:
	var table := _identity_table(0x48)
	for invalid in [0x0e, 0x0f, 0x1e, 0x1f, 0x2f, 0x3f, 0x46, 0x47]:
		table[invalid] = 0
	_swap(table, 0x40, 0x41)
	for cycle in [
		[0x01, 0x02, 0x03, 0x04], [0x05, 0x06, 0x07, 0x08],
		[0x09, 0x0a, 0x0b, 0x0c], [0x11, 0x12, 0x13, 0x14],
		[0x15, 0x16, 0x17, 0x18], [0x19, 0x1a, 0x1b, 0x1c],
		[0x21, 0x22, 0x23, 0x24], [0x25, 0x26, 0x27, 0x28],
		[0x29, 0x2a, 0x2b, 0x2c], [0x31, 0x32, 0x33, 0x34],
		[0x35, 0x36, 0x37, 0x38], [0x39, 0x3a, 0x3b, 0x3c],
		[0x42, 0x43, 0x44, 0x45],
	]:
		_set_cycle(table, cycle, counter_clockwise)
	return table


static func _underground_table(counter_clockwise: bool) -> PackedByteArray:
	var table := _identity_table(0x28)
	for invalid in [0x24, 0x25, 0x26, 0x27]:
		table[invalid] = 0
	for pair in [[0x01, 0x02], [0x10, 0x11], [0x1f, 0x20]]:
		_swap(table, pair[0], pair[1])
	for cycle in [
		[0x03, 0x04, 0x05, 0x06], [0x07, 0x08, 0x09, 0x0a],
		[0x0b, 0x0c, 0x0d, 0x0e], [0x12, 0x13, 0x14, 0x15],
		[0x16, 0x17, 0x18, 0x19], [0x1a, 0x1b, 0x1c, 0x1d],
	]:
		_set_cycle(table, cycle, counter_clockwise)
	return table


static func _swap(table: PackedByteArray, first: int, second: int) -> void:
	table[first] = second
	table[second] = first


static func _set_cycle(
	table: PackedByteArray, cycle: Array, counter_clockwise: bool
) -> void:
	for index in cycle.size():
		var target := index - 1 if counter_clockwise else index + 1
		table[cycle[index]] = cycle[posmod(target, cycle.size())]


# Orientation uses both the tile ID and the flip bit.
static func _rotate_special_surface(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	flags: PackedByteArray,
	misc: PackedByteArray,
	surface_table: PackedByteArray,
	counter_clockwise: bool
) -> void:
	var ramp_tiles := (
		[0x5e, 0x5d, 0x60, 0x5f, 0x60, 0x5f, 0x5e, 0x5d]
		if counter_clockwise
		else [0x60, 0x5f, 0x5e, 0x5d, 0x5e, 0x5d, 0x60, 0x5f]
	)
	for index in buildings.size():
		var tile := int(buildings[index])
		var flipped := (flags[index] & FLIP_FLAG) != 0
		if tile >= 0x5d and tile <= 0x60:
			var ramp_index := tile - 0x5d + (4 if flipped else 0)
			_replace_building(buildings, zones, misc, index, ramp_tiles[ramp_index])
			flags[index] = (flags[index] & 0xfd) | (FLIP_FLAG if ramp_index < 4 else 0)
			continue
		if not ((tile >= 0x51 and tile <= 0x5c) or tile == 0x6a or tile == 0x6b):
			continue
		if counter_clockwise:
			if flipped:
				flags[index] &= 0xfd
			else:
				flags[index] |= FLIP_FLAG
				_replace_building(buildings, zones, misc, index, surface_table[tile])
		else:
			if flipped:
				flags[index] &= 0xfd
				_replace_building(buildings, zones, misc, index, surface_table[tile])
			else:
				flags[index] |= FLIP_FLAG


# rotate the road counts too or misc disagrees with xbld
static func _rotate_surface_tile_counts(
	misc: PackedByteArray, surface_table: PackedByteArray
) -> void:
	var old_counts := PackedInt64Array()
	old_counts.resize(0x70)
	for tile in 0x70:
		old_counts[tile] = _read_u32_be(misc, TILE_COUNT_OFFSET + tile * 4)
	for tile in 0x70:
		_write_u32_be(
			misc, TILE_COUNT_OFFSET + int(surface_table[tile]) * 4, old_counts[tile]
		)


# word-sized count wrapping on the 128 map; military tiles don't count
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
	if (zones[index] & 0x0f) != MILITARY_ZONE:
		var old_offset := TILE_COUNT_OFFSET + old_tile * 4
		var new_offset := TILE_COUNT_OFFSET + new_tile * 4
		_write_u32_be(misc, old_offset, (_read_u32_be(misc, old_offset) - 1) & (0xffff if buildings.size() == 16384 else 0xffffffff))
		_write_u32_be(misc, new_offset, (_read_u32_be(misc, new_offset) + 1) & (0xffff if buildings.size() == 16384 else 0xffffffff))
	buildings[index] = new_tile


# these bytes are coordinates until the object decides they aren't
static func _rotate_things(things: PackedByteArray, counter_clockwise: bool, map_edge: int = 128) -> void:
	for record in range(1, CityState.THING_COUNT):
		var offset := record * CityState.THING_RECORD_SIZE
		var type := int(ThingData.read(things, offset))
		if type == 0:
			continue
		var old_x := int(ThingData.read(things, offset + 3))
		var old_y := int(ThingData.read(things, offset + 4))
		if counter_clockwise:
			ThingData.write(things, offset + 3, old_y)
			ThingData.write(things, offset + 4, (map_edge - 1 - old_x))
		else:
			ThingData.write(things, offset + 3, (map_edge - 1 - old_y))
			ThingData.write(things, offset + 4, old_x)
		if type >= 10 and type <= 13:
			_rotate_train_thing(things, offset, counter_clockwise)
		else:
			ThingData.write(things, offset + 1, (
				ThingData.read(things, offset + 1) + (-2 if counter_clockwise else 2)
			) & 7)
			var old_dx := int(ThingData.read(things, offset + 8))
			var old_dy := int(ThingData.read(things, offset + 9))
			if counter_clockwise:
				ThingData.write(things, offset + 8, old_dy)
				ThingData.write(things, offset + 9, (map_edge - 1 - old_dx))
			else:
				ThingData.write(things, offset + 8, (map_edge - 1 - old_dy))
				ThingData.write(things, offset + 9, old_dx)
			if type == 1:
				var turn := -0x20 if counter_clockwise else 0x20
				ThingData.write(things, offset + 2, (
					((ThingData.read(things, offset + 2) + turn) & 0x70) | (ThingData.read(things, offset + 2) & 0x0f)
				))


static func _rotate_train_thing(
	things: PackedByteArray, offset: int, counter_clockwise: bool
) -> void:
	ThingData.write(things, offset + 1, (
		ThingData.read(things, offset + 1) + (-1 if counter_clockwise else 1)
	) & 3)
	ThingData.write(things, offset + 8, (
		ThingData.read(things, offset + 8) + (-2 if counter_clockwise else 2)
	) & 7)
	var old_px := int(ThingData.read(things, offset + 6))
	var old_py := int(ThingData.read(things, offset + 7))
	if counter_clockwise:
		ThingData.write(things, offset + 6, old_py)
		ThingData.write(things, offset + 7, (127 - old_px) & 0xff)
	else:
		ThingData.write(things, offset + 6, (127 - old_py) & 0xff)
		ThingData.write(things, offset + 7, old_px)


static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _write_u32_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff
