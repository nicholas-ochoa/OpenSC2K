class_name GrowthState
extends GrowthConstants


@warning_ignore_start("integer_division")


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

	if (zones[index] & 0x0f) != 7:
		var old_offset := MISC_TILE_COUNTS + old_tile * 4
		var new_offset := MISC_TILE_COUNTS + new_tile * 4
		BinaryData.write_u32_be(misc, old_offset, (BinaryData.read_u32_be(misc, old_offset) - 1) & (0xffff if buildings.size() == 16384 else 0xffffffff))
		BinaryData.write_u32_be(misc, new_offset, (BinaryData.read_u32_be(misc, new_offset) + 1) & (0xffff if buildings.size() == 16384 else 0xffffffff))

	buildings[index] = new_tile


static func payloads(city: CityState) -> Dictionary[String, PackedByteArray]:
	var map_edge: int = city.map_size if city != null else 128
	var result: Dictionary[String, PackedByteArray] = {}

	for checked in [
		["ALTM", (map_edge * map_edge) * 2],
		["XTER", (map_edge * map_edge)],
		["XBLD", (map_edge * map_edge)],
		["XZON", (map_edge * map_edge)],
		["XUND", (map_edge * map_edge)],
		["XTXT", (map_edge * map_edge)],
		["XMIC", CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE],
		["XTHG", city.document.decoded_size("XTHG")],
		["XBIT", (map_edge * map_edge)],
		["XTRF", ((map_edge / 2) * (map_edge / 2))],
		["XPLT", ((map_edge / 2) * (map_edge / 2))],
		["XVAL", ((map_edge / 2) * (map_edge / 2))],
		["XCRM", ((map_edge / 2) * (map_edge / 2))],
		["MISC", MISC_SIZE],
	]:
		var chunk := city.document.find_chunk(checked[0])

		if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size(str(checked[0])):
			return {}

		result[checked[0]] = chunk.decoded_payload.duplicate()

	return result


static func duplicate_payloads(payloads: Dictionary) -> Dictionary[String, PackedByteArray]:
	var result: Dictionary[String, PackedByteArray] = {}

	for chunk_id in payloads:
		result[chunk_id] = payloads[chunk_id].duplicate()

	return result


static func _apply_payloads(
	city: CityState,
	chunk_ids: PackedStringArray,
	payloads: Dictionary,
	rollback: Dictionary
) -> bool:
	var applied := PackedStringArray()

	for chunk_id in chunk_ids:
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		var chunk := city.document.find_chunk(chunk_id)

		if chunk == null or not chunk.set_decoded_payload(payloads[chunk_id]):
			for rollback_id in applied:
				city.document.find_chunk(rollback_id).set_decoded_payload(rollback[rollback_id])

			# the rollback restored the chunks it had already written, so those
			# are the mirrors that moved. a chunk later in chunk_ids was never
			# committed and its mirror is still current
			_refresh_city(city, applied)

			return false

		applied.append(chunk_id)

	_refresh_city(city, chunk_ids)

	return true


# resync the mirrors of the committed chunks. a commit that only rewrites xbld
# must not copy five other map arrays and decode every altitude word again
static func _refresh_city(city: CityState, chunk_ids: PackedStringArray) -> void:
	city.resync_mirrors(chunk_ids)


static func _sync_altitudes(altitude: PackedByteArray, altitudes: PackedInt32Array, map_edge: int = 128) -> void:
	for index in (map_edge * map_edge):
		altitudes[index] = (altitude[index * 2] << 8) | altitude[index * 2 + 1]


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if point.x < 0 or point.x >= map_edge or point.y < 0 or point.y >= map_edge:
		return -1

	return point.x * map_edge + point.y


static func _add_i32(data: PackedByteArray, offset: int, value: int) -> void:
	BinaryData.write_u32_be(data, offset, BinaryData.read_i32_be(data, offset) + value)
