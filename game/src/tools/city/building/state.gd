class_name BuildingState
extends BuildingConstants



static func _read_u16_be(data: PackedByteArray, offset: int) -> int:
	return (data[offset] << 8) | data[offset + 1]


static func _write_u16_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 8) & 0xff
	data[offset + 1] = value & 0xff


static func _update_building_count(
	misc: PackedByteArray, zone: int, old_building: int, new_building: int, map_edge: int = 128
) -> void:
	if zone == MILITARY_ZONE:
		return

	var old_offset := MISC_TILE_COUNTS + old_building * 4
	var new_offset := MISC_TILE_COUNTS + new_building * 4
	_write_u32_be(misc, old_offset, (_read_u32_be(misc, old_offset) - 1) & (0xffff if map_edge == 128 else 0xffffffff))
	_write_u32_be(misc, new_offset, (_read_u32_be(misc, new_offset) + 1) & (0xffff if map_edge == 128 else 0xffffffff))


static func _city_payloads(city: CityState) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128
	var result := {}

	for checked in [
		["XBLD", (map_edge * map_edge)],
		["XTER", (map_edge * map_edge)],
		["XZON", (map_edge * map_edge)],
		["XUND", (map_edge * map_edge)],
		["XBIT", (map_edge * map_edge)],
		["XTXT", (map_edge * map_edge)],
		["XLAB", CityState.LABEL_COUNT * CityState.LABEL_RECORD_SIZE],
		["XMIC", CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE],
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


static func _restore_payloads(city: CityState, old_payloads: Dictionary) -> bool:
	var current_payloads := _city_payloads(city)

	if current_payloads.is_empty():
		return false

	var changed_ids := PackedStringArray()

	for chunk_id in old_payloads:
		if current_payloads[chunk_id] != old_payloads[chunk_id]:
			changed_ids.append(chunk_id)

	return _apply_payloads(city, changed_ids, old_payloads, current_payloads)


static func _apply_payloads(
	city: CityState, chunk_ids: PackedStringArray, payloads: Dictionary, rollback: Dictionary
) -> bool:
	var applied := PackedStringArray()

	for chunk_id in chunk_ids:
		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not payloads.has(chunk_id) or not chunk.set_decoded_payload(payloads[chunk_id]):
			for rollback_id in applied:
				city.document.find_chunk(rollback_id).set_decoded_payload(rollback[rollback_id])

			_refresh_city_arrays(city, applied)

			return false

		applied.append(chunk_id)

	_refresh_city_arrays(city, chunk_ids)

	return true


# resync the mirrors of the committed chunks. passing the ids also covers
# altm, which this path used to leave to each caller to decode by hand
static func _refresh_city_arrays(city: CityState, chunk_ids: PackedStringArray) -> void:
	city.resync_mirrors(chunk_ids)


static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _read_i32_be(data: PackedByteArray, offset: int) -> int:
	var value := _read_u32_be(data, offset)

	return value - 0x100000000 if value >= 0x80000000 else value


static func _write_u32_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff
