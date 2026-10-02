class_name IsometricStaticVisuals
extends IsometricConstants
# isometric static visuals and a main-thread overlay signature cache

@warning_ignore_start("integer_division")


static func validate_assets(
	city: CityState, sprites: Sc2SpriteArchive, view_size := VIEW_LARGE
) -> PackedStringArray:
	if IsometricGeometry.view_configuration(view_size) == null:
		return PackedStringArray(["city view size is invalid"])

	return IsometricImageRender.missing_sprite_errors(city, sprites, view_size)


# some generated cities store a flat stream on a height transition. supply the
# missing waterfall face for display without changing their saved xter bytes


static func fire_overlay_visual(
	city: CityState, x: int, y: int, view_size := VIEW_LARGE, animation_phase := 0
) -> SpecialOverlay:
	if city == null or city.marker_overlay_id(x, y) != 0xff:
		return null

	return special_overlay_visual(city, x, y, view_size, animation_phase)


static func special_overlay_visual(
	city: CityState, x: int, y: int, view_size := VIEW_LARGE, animation_phase := 0
) -> SpecialOverlay:
	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return null

	var overlay := city.marker_overlay_id(x, y)

	if not SPECIAL_OVERLAY_SPRITE_OFFSETS.has(overlay):
		return null

	if city.is_water(x, y) and overlay != 0xfb and overlay != 0xfc:
		return null

	var configuration := IsometricGeometry.view_configuration(view_size)

	if configuration == null:
		return null

	var phase := animation_phase + x * 3 + y * 5

	if overlay == 0xff:
		# Mix tile coordinates to break up diagonal fire patterns without advancing the simulation RNG.
		var seed_value := ((x + y * city.map_size + 1) * 0x45d9f3b) & 0xffffffff
		seed_value = ((seed_value >> 16) ^ seed_value) * 0x45d9f3b
		phase = animation_phase + (((seed_value >> 16) ^ seed_value) & 0xffff)

	var sprite_offsets: Array = SPECIAL_OVERLAY_SPRITE_OFFSETS[overlay]
	var sprite_offset: int = sprite_offsets[0]

	if sprite_offsets.size() > 1:
		sprite_offset = sprite_offsets[phase % sprite_offsets.size()]

	var result := SpecialOverlay.new()
	result.sprite_id = configuration.sprite_base + sprite_offset
	result.flip = ((phase >> 2) & 1) != 0
	result.overlay = overlay

	return result


static func static_visual_signature(city: CityState, view_size := VIEW_LARGE) -> Array:
	if city == null or not city.is_valid():
		return []

	return [
		view_size,
		city.visible_altitude_levels,
		city.compass_rotation(),
		city.chunk_revision("ALTM"),
		city.chunk_revision("XTER"),
		city.chunk_revision("XBLD"),
		city.chunk_revision("XZON"),
		city.masked_tile_flag_signature(0xc6),
		city.chunk_revision("XTRF"),
		_static_text_overlay_signature(city),
	]


# scan xtxt for signs only when it changes. dispatch content is still read
# after every xthg revision change
static func _static_text_overlay_signature(city: CityState) -> int:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id(),
		"Static overlay signature cache is main-thread only")
	var key: Array[int] = [city.chunk_revision("XTXT"), city.chunk_revision("XTHG"), city.chunk_revision("XSGN")]
	var cache := city.static_text_overlay_cache

	if cache != null and cache.key == key:
		return cache.value

	if cache == null:
		cache = CitySignatureCache.TextOverlays.new()

	if cache.key.is_empty() or cache.key[0] != key[0]:
		cache.signs = OverlayData.sign_indices(city.text_overlays)

	# the signature adds dispatch cells to its own copy
	var indices := cache.signs.duplicate()
	var value := _compute_static_text_overlay_signature(city, indices)
	cache.key = key
	cache.value = value
	city.static_text_overlay_cache = cache

	return value


static func _compute_static_text_overlay_signature(city: CityState, indices: PackedInt32Array) -> int:
	var values := PackedInt32Array()
	var things := city.document.find_chunk("XTHG")

	for record in city.thing_count() if things != null else 0:
		if int(things.decoded_payload[record * CityState.THING_RECORD_SIZE]) not in DISPATCH_SPRITE_OFFSETS:
			continue

		var overlay_id := OverlayData.thing_id(record)
		var found := OverlayData.find(city.text_overlays, overlay_id)

		while found >= 0:
			indices.append(found)
			found = OverlayData.find(city.text_overlays, overlay_id, found + 1)

	indices.sort()

	for index in indices:
		var overlay := int(OverlayData.read(city.text_overlays, index))

		if OverlayData.is_sign(overlay):
			values.append(index)
			values.append(overlay)
		elif OverlayData.is_thing(overlay):
			var thing := city.thing(OverlayData.thing_record(overlay))

			if thing != null and thing.type in DISPATCH_SPRITE_OFFSETS:
				values.append(index)
				values.append_array([thing.type, thing.direction, thing.state, thing.x, thing.y, thing.z, thing.px, thing.py])

	return hash(values)


class SpecialOverlay extends CitySpriteVisual:
	var overlay: int
