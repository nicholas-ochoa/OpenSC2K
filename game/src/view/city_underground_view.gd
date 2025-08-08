class_name CityUndergroundView
extends RefCounted


static func prepare_render_city(city: CityState) -> bool:
	if city == null or not city.is_valid():
		return false
	var building_chunk := city.document.find_chunk("XBLD")
	var terrain_chunk := city.document.find_chunk("XTER")
	var zone_chunk := city.document.find_chunk("XZON")
	var flag_chunk := city.document.find_chunk("XBIT")
	var text_chunk := city.document.find_chunk("XTXT")
	if (
		building_chunk == null
		or terrain_chunk == null
		or zone_chunk == null
		or flag_chunk == null
		or text_chunk == null
	):
		return false
	var buildings := PackedByteArray()
	var terrain := PackedByteArray()
	var zones := PackedByteArray()
	var flags := PackedByteArray()
	var text := PackedByteArray()
	buildings.resize(CityState.TILE_COUNT)
	terrain.resize(CityState.TILE_COUNT)
	zones.resize(CityState.TILE_COUNT)
	flags.resize(CityState.TILE_COUNT)
	text.resize(CityState.TILE_COUNT)
	buildings.fill(0)
	terrain.fill(0)
	zones.fill(0)
	flags.fill(0)
	text.fill(0)
	for index in CityState.TILE_COUNT:
		buildings[index] = surface_tile_for_underground(int(city.underground[index]))
		flags[index] = int(city.tile_flags[index]) & 0x02
	if (
		not building_chunk.set_decoded_payload(buildings)
		or not terrain_chunk.set_decoded_payload(terrain)
		or not zone_chunk.set_decoded_payload(zones)
		or not flag_chunk.set_decoded_payload(flags)
		or not text_chunk.set_decoded_payload(text)
	):
		return false
	city.buildings = buildings
	city.terrain = terrain
	city.zones = zones
	city.tile_flags = flags
	city.text_overlays = text
	return true


static func surface_tile_for_underground(tile: int) -> int:
	if tile >= 0x01 and tile <= 0x0f:
		return 0x2b + tile
	if tile >= 0x10 and tile <= 0x1e:
		return tile - 2
	match tile:
		0x1f:
			return 0x47
		0x20:
			return 0x48
		0x22:
			return 0xf9
		0x23:
			return 0xe9
	return 0


static func visual_signature(city: CityState, view_size: int) -> Array:
	if city == null or not city.is_valid():
		return []
	return [
		"underground",
		view_size,
		city.compass_rotation(),
		hash(city.altitude_words),
		hash(city.underground),
	]
