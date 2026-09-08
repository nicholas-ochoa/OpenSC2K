class_name IsometricStaticVisuals
extends IsometricConstants
# isometric static visuals and a main-thread overlay signature cache

@warning_ignore_start("integer_division")

class Edge extends RefCounted:
	var sprite_id: int
	var elevation: int

	func _init(id: int, height: int) -> void:
		sprite_id = id
		elevation = height


class Ground extends RefCounted:
	var source: Vector2i
	var sprite_id: int
	var offset: Vector2i

	func _init(point: Vector2i, id: int, position: Vector2i) -> void:
		source = point
		sprite_id = id
		offset = position


class Traffic extends CitySpriteVisual:
	var variant: int
	var density: int


class SpecialOverlay extends CitySpriteVisual:
	var overlay: int


const SIGN_PAGE_CELLS := 1024


static func validate_assets(
	city: CityState, sprites: Sc2SpriteArchive, view_size := VIEW_LARGE
) -> PackedStringArray:
	var map_edge: int = city.map_size if city != null else 128
	var errors := PackedStringArray()
	var configuration := IsometricGeometry.view_configuration(view_size)

	if configuration == null:
		errors.append("city view size is invalid")

		return errors

	var missing: Dictionary = {}

	for x in map_edge:
		for y in map_edge:
			var terrain_sprite := IsometricGeometry.terrain_sprite_id(
				city.terrain_id(x, y), city.is_water(x, y), configuration.sprite_base
			)

			if sprites.find_sprite(terrain_sprite) == null:
				missing[terrain_sprite] = true

			if x == map_edge - 1 or y == map_edge - 1:
				if city.land_altitude(x, y) > 0:
					var land_edge_sprite: int = configuration.sprite_base + 269

					if sprites.find_sprite(land_edge_sprite) == null:
						missing[land_edge_sprite] = true

				if city.is_water(x, y) and city.water_altitude(x, y) > city.land_altitude(x, y):
					var water_edge_sprite: int = configuration.sprite_base + 284

					if sprites.find_sprite(water_edge_sprite) == null:
						missing[water_edge_sprite] = true

			var zone := city.zone_id(x, y)

			if zone > 0 and city.building_id(x, y) == 0:
				var zone_sprite: int = configuration.sprite_base + 290 + zone

				if sprites.find_sprite(zone_sprite) == null:
					missing[zone_sprite] = true

			var building := city.building_id(x, y)

			if building > 0 and _should_draw_building(city, x, y, building):
				var building_sprite: int = configuration.sprite_base + building

				if sprites.find_sprite(building_sprite) == null:
					missing[building_sprite] = true

				var traffic_visual := traffic_overlay_visual(city, x, y, view_size)

				if traffic_visual != null and sprites.find_sprite(traffic_visual.sprite_id) == null:
					missing[traffic_visual.sprite_id] = true

				var power_marker := power_marker_visual(city, x, y, view_size)

				if power_marker != null and sprites.find_sprite(power_marker.sprite_id) == null:
					missing[power_marker.sprite_id] = true

			var special_overlay := city.text_overlay_id(x, y)

			if SPECIAL_OVERLAY_SPRITE_OFFSETS.has(special_overlay):
				var can_draw_on_water := special_overlay == 0xfb or special_overlay == 0xfc

				if not city.is_water(x, y) or can_draw_on_water:
					for sprite_offset in SPECIAL_OVERLAY_SPRITE_OFFSETS[special_overlay]:
						var special_sprite: int = configuration.sprite_base + sprite_offset

						if sprites.find_sprite(special_sprite) == null:
							missing[special_sprite] = true

			var dispatch_sprite := dispatch_sprite_id(city, x, y, view_size)

			if dispatch_sprite > 0 and sprites.find_sprite(dispatch_sprite) == null:
				missing[dispatch_sprite] = true

			var moving_visual := IsometricMovingVisuals.moving_thing_visual(city, x, y, view_size)

			if moving_visual != null:
				if moving_visual.monster:
					for layer in moving_visual.layers:
						if sprites.find_sprite(layer.sprite_id) == null:
							missing[layer.sprite_id] = true
				elif sprites.find_sprite(moving_visual.sprite_id) == null:
					missing[moving_visual.sprite_id] = true

	var ids := missing.keys()
	ids.sort()

	for sprite_id in ids:
		errors.append("required large sprite %d is missing" % sprite_id)

	return errors


# some generated cities store a flat stream on a height transition. supply the
# missing waterfall face for display without changing their saved xter bytes


static func edge_stack_visuals(
	city: CityState, x: int, y: int, view_size := VIEW_LARGE
) -> Array[Edge]:
	var map_edge: int = city.map_size if city != null else 128
	var visuals: Array[Edge] = []

	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return visuals

	if x != map_edge - 1 and y != map_edge - 1:
		return visuals

	var configuration := IsometricGeometry.view_configuration(view_size)

	if configuration == null:
		return visuals

	var land := city.land_altitude(x, y)

	for level in land:
		visuals.append(Edge.new(int(configuration.sprite_base) + 269, level * int(configuration.altitude_step)))

	if city.is_water(x, y):
		var water := city.water_altitude(x, y)

		for level in range(land, water):
			visuals.append(Edge.new(int(configuration.sprite_base) + 284, level * int(configuration.altitude_step)))

	return visuals


static func highway_ground_visuals(
	city: CityState, x: int, y: int, view_size := VIEW_LARGE,
	redraw_small := false
) -> Array[Ground]:
	var visuals: Array[Ground] = []

	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return visuals

	var configuration := IsometricGeometry.view_configuration(view_size)

	if configuration == null:
		return visuals

	# The small highway composite already includes the ground.
	if view_size == VIEW_SMALL and not redraw_small:
		return visuals

	var screen_offsets := [
		Vector2i(0, 0),
		Vector2i(configuration.half_width, -configuration.half_height),
		Vector2i(configuration.tile_width, 0),
		Vector2i(configuration.half_width, configuration.half_height),
	]

	for index in HIGHWAY_GROUND_SOURCE_OFFSETS.size():
		var source: Vector2i = (
			Vector2i(x, y) + HIGHWAY_GROUND_SOURCE_OFFSETS[index]
		)

		if city.index_of(source.x, source.y) < 0:
			continue

		visuals.append(Ground.new(source, IsometricGeometry.terrain_sprite_id(
				city.terrain_id(source.x, source.y),
				city.is_water(source.x, source.y),
				configuration.sprite_base,
			),
			screen_offsets[index]))

	return visuals


static func traffic_overlay_visual(
	city: CityState, x: int, y: int, view_size := VIEW_LARGE
) -> Traffic:
	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return null

	var configuration := IsometricGeometry.view_configuration(view_size)

	if configuration == null:
		return null

	var tile := city.building_id(x, y)

	# the executable enters its traffic branch only for road-or-higher xbld
	# values. earlier table entries belong to other painter paths
	if tile < 0x1d or tile >= TRAFFIC_TILE_VARIANTS.size():
		return null

	var variant: int = TRAFFIC_TILE_VARIANTS[tile]

	if variant == 0:
		return null

	var density := city.traffic_density(x, y)
	var low_threshold := 85
	var high_threshold := 170

	if (tile >= 0x49 and tile <= 0x50) or (tile >= 0x61 and tile <= 0x6b):
		low_threshold = 28
		high_threshold = 56

	if density <= low_threshold:
		return null

	var flip := city.is_flipped(x, y)

	# traffic variants depend on tile parity as well as density
	if variant == 11 and (x & 1) != 0:
		variant = 12
	elif variant == 12:
		flip = true

		if (y & 1) != 0:
			variant = 11

	if density > high_threshold:
		if variant < 0 or variant >= TRAFFIC_HIGH_VARIANTS.size():
			return null

		variant = TRAFFIC_HIGH_VARIANTS[variant]

	if variant == 0:
		return null

	# The small archive ends at traffic variant 27, even though the original
	# painter can request later IDs.
	if view_size == VIEW_SMALL and variant > 27:
		return null

	var result := Traffic.new()
	result.sprite_id = int(configuration.sprite_base) + TRAFFIC_SPRITE_OFFSET + variant
	result.flip = flip
	result.variant = variant
	result.density = density

	return result


static func power_marker_visual(
	city: CityState, x: int, y: int, view_size := VIEW_LARGE
) -> CitySpriteVisual:
	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return null

	var configuration := IsometricGeometry.view_configuration(view_size)

	if configuration == null:
		return null

	if (
		city.building_id(x, y) < 0x70
		or not city.is_powerable(x, y)
		or city.is_powered(x, y)
	):
		return null

	var result := CitySpriteVisual.new()
	result.sprite_id = int(configuration.sprite_base) + POWER_MARKER_SPRITE_OFFSET

	return result


static func fire_overlay_visual(
	city: CityState, x: int, y: int, view_size := VIEW_LARGE, animation_phase := 0
) -> SpecialOverlay:
	if city == null or city.text_overlay_id(x, y) != 0xff:
		return null

	return special_overlay_visual(city, x, y, view_size, animation_phase)


static func special_overlay_visual(
	city: CityState, x: int, y: int, view_size := VIEW_LARGE, animation_phase := 0
) -> SpecialOverlay:
	if city == null or not city.is_valid() or city.index_of(x, y) < 0:
		return null

	var overlay := city.text_overlay_id(x, y)

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
	result.sprite_id = int(configuration.sprite_base) + sprite_offset
	result.flip = ((phase >> 2) & 1) != 0
	result.overlay = overlay

	return result


static func dispatch_sprite_id(
	city: CityState, x: int, y: int, view_size := VIEW_LARGE
) -> int:
	var overlay := city.text_overlay_id(x, y)

	if not OverlayData.is_thing(overlay) or OverlayData.thing_record(overlay) == 0:
		return 0

	var thing := city.thing(OverlayData.thing_record(overlay))

	if thing == null or thing.x != x or thing.y != y:
		return 0

	var configuration := IsometricGeometry.view_configuration(view_size)

	if configuration == null:
		return 0

	var sprite_offset := int(DISPATCH_SPRITE_OFFSETS.get(thing.type, 0))

	if sprite_offset == 0:
		return 0

	return int(configuration.sprite_base) + sprite_offset


# moving an object doesn't always change the static image
# chunk revisions stand in for whole-map content hashes. every committed write
# bumps the revision, so this answers "did the drawn city change?" in constant
# time instead of hashing megabytes on the main thread
# xbit and xtxt/xthg keep content signatures. the surface image follows only the
# powered, powerable and water flag bits, and only signs and dispatch vehicles
# among the overlays. their chunks also carry watered, piped and moving-thing
# bytes that change every tick, so their revisions would repaint continuously
# cache those content signatures behind revisions; a changed revision only
# triggers comparison of visible content, not an unconditional repaint
# applicationmaprender reads entries 1, 2, 3 and 9 by position for the sign
# layout token. keep the order and the length


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


# a tick usually changes only a few xtxt pages. compare their bytes natively,
# then scan changed pages once. unchanged pages retain their sign indices
# dispatch content is still read after every xthg revision change
static func _static_text_overlay_signature(city: CityState) -> int:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id(),
		"Static overlay signature cache is main-thread only")
	var key: Array[int] = [city.chunk_revision("XTXT"), city.chunk_revision("XTHG")]
	var cache := city._static_text_overlay_cache

	if cache != null and cache.key == key:
		return cache.value

	if cache == null:
		cache = CitySignatureCache.TextOverlays.new()

	var page_bytes := cache.pages
	var page_indices := cache.indices
	var high_pages := cache.high_pages
	var previous_key := cache.key
	var text_changed: bool = previous_key.is_empty() or previous_key[0] != key[0]

	var indices := PackedInt32Array()
	var cells := OverlayData.count(city.text_overlays)
	var wide := cells < city.text_overlays.size()

	for start in range(0, cells, SIGN_PAGE_CELLS):
		var end := mini(start + SIGN_PAGE_CELLS, cells)
		var page := start / SIGN_PAGE_CELLS

		if not text_changed:
			indices.append_array(page_indices[page])
			continue

		var bytes := city.text_overlays.slice(start, end)
		var high := city.text_overlays.slice(cells + start, cells + end) if wide else PackedByteArray()

		if page == page_bytes.size():
			page_bytes.append(bytes)
			high_pages.append(high)
			page_indices.append(OverlayData.sign_indices(city.text_overlays, start, end))
		elif bytes != page_bytes[page] or high != high_pages[page]:
			page_bytes[page] = bytes
			high_pages[page] = high
			page_indices[page] = OverlayData.sign_indices(city.text_overlays, start, end)

		indices.append_array(page_indices[page])

	var value := _compute_static_text_overlay_signature(city, indices)
	cache.key = key
	cache.value = value
	city._static_text_overlay_cache = cache

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


# four occupied corners, one sprite, compass picks the winner
static func _should_draw_building(city: CityState, x: int, y: int, building_id: int) -> bool:
	if building_id <= 0x60 or (building_id >= 0x6c and building_id <= 0x6f):
		return true

	var anchor_masks := [0x80, 0x10, 0x20, 0x40]

	return (city.building_corners(x, y) & anchor_masks[city.compass_rotation()]) != 0


# for buildings, flipped means unflipped every other compass turn
static func building_sprite_flip(
	city: CityState, x: int, y: int, building_id: int
) -> bool:
	var flip := city.is_flipped(x, y)

	if building_id >= 0x70 and (city.compass_rotation() & 1) != 0:
		flip = not flip

	return flip


# These sprites use their width to set the vertical offset.
static func building_baseline_offset(
	building_id: int, terrain_id: int, sprite_width: int, view_size := VIEW_LARGE
) -> int:
	var configuration := IsometricGeometry.view_configuration(view_size)

	if configuration == null or sprite_width < 0:
		return 0

	if building_id >= 0x61 and building_id <= 0x6b:
		return int(configuration.half_height)

	if building_id >= 0x70:
		return int(sprite_width / 4) - int(configuration.half_height)

	if terrain_id == 0x0d:
		return -int(configuration.altitude_step)

	return 0
