class_name NetworkState
extends NetworkConstants



static func replace_building(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	index: int,
	new_tile: int
) -> void:
	var old_tile := int(buildings[index])

	if old_tile == new_tile:
		return

	var zone := zones[index] & 0x0f
	var old_offset := MISC_TILE_COUNTS + old_tile * 4
	var new_offset := MISC_TILE_COUNTS + new_tile * 4

	if zone == MILITARY_ZONE:
		old_offset = MISC_MILITARY_TILE_COUNTS + int(
			MILITARY_TILE_COUNT_INDEX.get(old_tile, 0)
		) * 4
		new_offset = MISC_MILITARY_TILE_COUNTS + int(
			MILITARY_TILE_COUNT_INDEX.get(new_tile, 0)
		) * 4

	_write_u32_be(misc, old_offset, (_read_u32_be(misc, old_offset) - 1) & (0xffff if buildings.size() == 16384 else 0xffffffff))
	_write_u32_be(misc, new_offset, (_read_u32_be(misc, new_offset) + 1) & (0xffff if buildings.size() == 16384 else 0xffffffff))
	buildings[index] = new_tile


static func city_payloads(city: CityState) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128
	var result := {}

	for checked in [
		["ALTM", (map_edge * map_edge) * 2],
		["XBLD", (map_edge * map_edge)],
		["XTER", (map_edge * map_edge)],
		["XZON", (map_edge * map_edge)],
		["XUND", (map_edge * map_edge)],
		["XBIT", (map_edge * map_edge)],
		["XTXT", (map_edge * map_edge)],
		["MISC", 4800],
	]:
		var chunk := city.document.find_chunk(checked[0])

		if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size(str(checked[0])):
			return {}

		result[checked[0]] = chunk.decoded_payload.duplicate()

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

		if chunk == null or not payloads.has(chunk_id) or not chunk.set_decoded_payload(payloads[chunk_id]):
			for rollback_id in applied:
				city.document.find_chunk(rollback_id).set_decoded_payload(rollback[rollback_id])

			_refresh_city_arrays(city)

			return false

		applied.append(chunk_id)

	_refresh_city_arrays(city, chunk_ids.has("ALTM"))

	return true


static func _refresh_city_arrays(city: CityState, refresh_altitude := true) -> void:
	var map_edge: int = city.map_size if city != null else 128
	var altitude := city.document.find_chunk("ALTM").decoded_payload

	if refresh_altitude:
		for index in (map_edge * map_edge):
			city.altitude_words[index] = (altitude[index * 2] << 8) | altitude[index * 2 + 1]

	city.buildings = city.document.find_chunk("XBLD").decoded_payload.duplicate()
	city.terrain = city.document.find_chunk("XTER").decoded_payload.duplicate()
	city.zones = city.document.find_chunk("XZON").decoded_payload.duplicate()
	city.underground = city.document.find_chunk("XUND").decoded_payload.duplicate()
	var text_chunk := city.document.find_chunk("XTXT")

	if text_chunk != null:
		city.text_overlays = text_chunk.decoded_payload.duplicate()

	city.tile_flags = city.document.find_chunk("XBIT").decoded_payload.duplicate()


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
