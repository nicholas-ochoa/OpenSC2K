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


static func city_payloads(city: CityState) -> Dictionary[String, PackedByteArray]:
	var map_edge: int = city.map_size if city != null else 128
	var result: Dictionary[String, PackedByteArray] = {}

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


static func _duplicate_payloads(payloads: Dictionary) -> Dictionary[String, PackedByteArray]:
	var result: Dictionary[String, PackedByteArray] = {}

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

			city.resync_mirrors(CityState.MIRRORED_CHUNKS)

			return false

		applied.append(chunk_id)

	# resync every mirror, but decode altitude words only when altm changed
	var mirrored := CityState.MIRRORED_CHUNKS.duplicate()

	if not chunk_ids.has("ALTM"):
		mirrored.remove_at(mirrored.find("ALTM"))

	city.resync_mirrors(mirrored)

	return true


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
