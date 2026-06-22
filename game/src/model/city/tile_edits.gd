class_name CityTileEdits
extends RefCounted
# Write tile payloads and their CityState mirrors.


static func set_terrain_id(city: CityState, x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0xff:
		return false

	var changed := city.terrain.duplicate()

	if not city._set_byte_at(changed, x, y, value):
		return false

	if not city.document.find_chunk("XTER").set_decoded_payload(changed):
		return false

	city.terrain = changed

	return true


static func set_building_id(city: CityState, x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0xff:
		return false

	var changed := city.buildings.duplicate()

	if not city._set_byte_at(changed, x, y, value):
		return false

	if not city.document.find_chunk("XBLD").set_decoded_payload(changed):
		return false

	city.buildings = changed

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

	if index < 0:
		return false

	var changed := city.zones.duplicate()
	changed[index] = (changed[index] & 0xf0) | value

	if not city.document.find_chunk("XZON").set_decoded_payload(changed):
		return false

	city.zones = changed

	return true


static func set_building_corners(city: CityState, x: int, y: int, value: int) -> bool:
	if value < 0 or value > 0xf0 or value & 0x0f:
		return false

	var index := city.index_of(x, y)

	if index < 0:
		return false

	var changed := city.zones.duplicate()
	changed[index] = value | (changed[index] & 0x0f)

	if not city.document.find_chunk("XZON").set_decoded_payload(changed):
		return false

	city.zones = changed

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

	var changed := city.underground.duplicate()

	if not city._set_byte_at(changed, x, y, value):
		return false

	if not city.document.find_chunk("XUND").set_decoded_payload(changed):
		return false

	city.underground = changed

	return true


static func set_text_overlay_id(city: CityState, x: int, y: int, value: int) -> bool:
	if value < 0 or value > (0xff if city.map_size <= 128 else 0xffff):
		return false

	var changed := city.text_overlays.duplicate()
	var index := city.index_of(x, y)

	if index < 0:
		return false

	OverlayData.write(changed, index, value)

	if not city.document.find_chunk("XTXT").set_decoded_payload(changed):
		return false

	city.text_overlays = changed

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

	if index < 0:
		return false

	var changed := city.tile_flags.duplicate()

	if enabled:
		changed[index] |= mask
	else:
		changed[index] &= ~mask & 0xff

	if not city.document.find_chunk("XBIT").set_decoded_payload(changed):
		return false

	city.tile_flags = changed

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


static func _set_byte_at(city: CityState, data: PackedByteArray, x: int, y: int, value: int) -> bool:
	var index := city.index_of(x, y)

	if index < 0:
		return false

	data[index] = value

	return true


static func _set_altitude_word(city: CityState, x: int, y: int, value: int) -> bool:
	var index := city.index_of(x, y)

	if index < 0:
		return false

	var chunk := city.document.find_chunk("ALTM")

	if chunk == null:
		return false

	var changed := chunk.decoded_payload.duplicate()
	changed[index * 2] = (value >> 8) & 0xff
	changed[index * 2 + 1] = value & 0xff

	if not chunk.set_decoded_payload(changed):
		return false

	city.altitude_words[index] = value

	return true
