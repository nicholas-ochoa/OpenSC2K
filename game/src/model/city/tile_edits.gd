class_name CityTileEdits
extends RefCounted
# Validate before writing: each edit updates both the saved chunk and
# the CityState mirror in place. A partial write would leave them out of sync.


static func set_terrain_id(city: CityState, x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0xff:
		return false

	var index := city.index_of(x, y)
	var chunk := _tile_chunk(city, "XTER", city.terrain.size(), index)

	if chunk == null:
		return false

	chunk.write_decoded_byte(index, value)
	city.terrain[index] = value

	return true


static func set_building_id(city: CityState, x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0xff:
		return false

	var index := city.index_of(x, y)
	var chunk := _tile_chunk(city, "XBLD", city.buildings.size(), index)

	if chunk == null:
		return false

	chunk.write_decoded_byte(index, value)
	city.buildings[index] = value

	return true


static func replace_buildings(city: CityState, value: PackedByteArray) -> bool:
	if value.size() != (city.map_size * city.map_size):
		return false

	var chunk := city.document.find_chunk("XBLD")

	if chunk == null or not chunk.set_decoded_payload(value):
		return false

	city.buildings = value.duplicate()

	return true


static func set_zone_id(city: CityState, x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0x0f:
		return false

	var index := city.index_of(x, y)
	var chunk := _tile_chunk(city, "XZON", city.zones.size(), index)

	if chunk == null:
		return false

	# zone and corner bits share one byte. merge over the payload, which is what
	# the document writes, rather than over the mirrored copy
	var merged := (chunk.decoded_payload[index] & 0xf0) | value
	chunk.write_decoded_byte(index, merged)
	city.zones[index] = merged

	return true


static func set_building_corners(city: CityState, x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0xf0 or value & 0x0f:
		return false

	var index := city.index_of(x, y)
	var chunk := _tile_chunk(city, "XZON", city.zones.size(), index)

	if chunk == null:
		return false

	var merged := value | (chunk.decoded_payload[index] & 0x0f)
	chunk.write_decoded_byte(index, merged)
	city.zones[index] = merged

	return true


static func replace_zones(city: CityState, value: PackedByteArray) -> bool:
	if value.size() != (city.map_size * city.map_size):
		return false

	var chunk := city.document.find_chunk("XZON")

	if chunk == null or not chunk.set_decoded_payload(value):
		return false

	city.zones = value.duplicate()

	return true


static func set_underground_id(city: CityState, x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0xff:
		return false

	var index := city.index_of(x, y)
	var chunk := _tile_chunk(city, "XUND", city.underground.size(), index)

	if chunk == null:
		return false

	chunk.write_decoded_byte(index, value)
	city.underground[index] = value

	return true


static func set_text_overlay_id(city: CityState, x: int, y: int, value: int) -> bool:
	if value < 0 or value > (0xff if city.map_size <= 128 else 0xffff):
		return false

	var index := city.index_of(x, y)
	var size := city.text_overlays.size()
	var chunk := _tile_chunk(city, "XTXT", size, index)

	if chunk == null:
		return false

	# Wide SC2X overlays store the high byte one full plane after the low byte.
	var cells := OverlayData.cells_for(size)

	if index >= cells or (cells < size and cells + index >= size):
		return false

	chunk.write_decoded_byte(index, value & 0xff)
	city.text_overlays[index] = value & 0xff

	if cells < size:
		chunk.write_decoded_byte(cells + index, (value >> 8) & 0xff)
		city.text_overlays[cells + index] = (value >> 8) & 0xff

	return true


static func replace_text_overlays(city: CityState, value: PackedByteArray) -> bool:
	if value.size() != city.document.decoded_size("XTXT"):
		return false

	var chunk := city.document.find_chunk("XTXT")

	if chunk == null or not chunk.set_decoded_payload(value):
		return false

	city.text_overlays = value.duplicate()

	return true


static func set_tile_flag(city: CityState, x: int, y: int, mask: int, enabled: bool) -> bool:
	if mask < 0 or mask > 0xff:
		return false

	var index := city.index_of(x, y)
	var chunk := _tile_chunk(city, "XBIT", city.tile_flags.size(), index)

	if chunk == null:
		return false

	var current := chunk.decoded_payload[index]
	var merged := (current | mask) if enabled else (current & ~mask & 0xff)
	chunk.write_decoded_byte(index, merged)
	city.tile_flags[index] = merged

	return true


static func replace_tile_flags(city: CityState, value: PackedByteArray) -> bool:
	if value.size() != (city.map_size * city.map_size):
		return false

	var chunk := city.document.find_chunk("XBIT")

	if chunk == null or not chunk.set_decoded_payload(value):
		return false

	city.tile_flags = value.duplicate()

	return true


static func masked_tile_flag_signature(city: CityState, mask: int) -> int:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id(),
		"CityState tile-flag signature cache is main-thread only")
	var byte_mask := mask & 0xff
	var source_signature := hash(city.tile_flags)
	var cached: Dictionary = city._masked_tile_flag_signatures.get(byte_mask, {})

	if (
		cached.get("source") == source_signature
		and cached.get("size") == city.tile_flags.size()
	):
		return int(cached.get("value", 0))

	var visible_flags := PackedByteArray()
	visible_flags.resize(city.tile_flags.size())
	var word_mask := 0

	for lane in 8:
		word_mask |= byte_mask << (lane * 8)

	var full_bytes := city.tile_flags.size() - city.tile_flags.size() % 8

	for offset in range(0, full_bytes, 8):
		visible_flags.encode_u64(offset, city.tile_flags.decode_u64(offset) & word_mask)

	for index in range(full_bytes, city.tile_flags.size()):
		visible_flags[index] = city.tile_flags[index] & byte_mask

	var value := hash(visible_flags)
	city._masked_tile_flag_signatures[byte_mask] = {
		"source": source_signature,
		"size": city.tile_flags.size(),
		"value": value,
	}

	return value


static func set_land_altitude(city: CityState, x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0x1f:
		return false

	var index := city.index_of(x, y)

	if index < 0:
		return false

	return city._set_altitude_word(x, y, (city.altitude_words[index] & ~0x1f) | value)


static func set_water_altitude(city: CityState, x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0x1f:
		return false

	var index := city.index_of(x, y)

	if index < 0:
		return false

	return city._set_altitude_word(x, y, (city.altitude_words[index] & ~0x3e0) | (value << 5))


static func set_tunnel_levels(city: CityState, x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0x3f:
		return false

	var index := city.index_of(x, y)

	if index < 0:
		return false

	return city._set_altitude_word(x, y, (city.altitude_words[index] & ~0xfc00) | (value << 10))


# the chunk behind a mirrored tile plane, when a single byte at index is safe
# to write in place. returns null unless the tile is on the map and the payload
# still has the size of the array citystate mirrors it with
static func _tile_chunk(city: CityState, chunk_id: String, mirror_size: int, index: int) -> Sc2Chunk:
	if index < 0 or index >= mirror_size:
		return null

	var chunk := city.document.find_chunk(chunk_id) if city.document != null else null

	if chunk == null or chunk.decoded_payload.size() != mirror_size:
		return null

	return chunk


static func _set_altitude_word(city: CityState, x: int, y: int, value: int) -> bool:
	var index := city.index_of(x, y)
	var cells := city.altitude_words.size()

	if index < 0 or index >= cells:
		return false

	var chunk := city.document.find_chunk("ALTM") if city.document != null else null

	if chunk == null or chunk.decoded_payload.size() != cells * 2:
		return false

	# Truncate to the stored 16-bit word before updating the ALTM mirror, so both copies agree.
	var word := value & 0xffff
	chunk.write_decoded_bytes(index * 2, PackedByteArray([word >> 8, word & 0xff]))
	city.altitude_words[index] = word

	return true
