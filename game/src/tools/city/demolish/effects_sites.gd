class_name DemolishEffectsSites
extends DemolishConstants



static func append_effect_sequence(
	destination: Array[Dictionary], source: Array, first_frame: int
) -> int:
	if source.is_empty():
		return first_frame

	var frame_count := 0

	for source_effect in source:
		var effect: Dictionary = source_effect.duplicate()
		var source_frame := int(effect.get("frame", 0))
		effect["frame"] = first_frame + source_frame
		destination.append(effect)
		frame_count = maxi(frame_count, source_frame + 1)

	return first_frame + frame_count


static func parallel_effect_offset(
	point: Vector2i, action_index: int, random_seed: int
) -> int:
	if action_index <= 0:
		return 0

	var mixed := (
		point.x * 0x45d9f3b
		+ point.y * 0x119de1f3
		+ action_index * 0x27d4eb2d
		+ random_seed
	)
	mixed = mixed ^ (mixed >> 16)

	return 1 + absi(mixed) % MAX_PARALLEL_EFFECT_OFFSET_FRAMES


static func _effect_altitude(
	altitude: PackedByteArray, flags: PackedByteArray, index: int
) -> int:
	return (
		DemolishTerrain._water_altitude(altitude, index)
		if (flags[index] & FLAG_WATER) != 0
		else DemolishTerrain._land_altitude(altitude, index)
	)


static func _dust_effect(
	point: Vector2i, effect_altitude: int, random: SimRandom, frame: int, screen_offset: Vector2i
) -> Dictionary:
	return {
		"point": point,
		"sprite_id": BRIDGE_DEBRIS_SPRITE + (random.next_u15() & 3),
		"screen_offset": screen_offset,
		"flip": (random.next_u15() & 1) != 0,
		"frame": frame,
		"altitude": effect_altitude,
	}


static func _structure_effects(
	altitude: PackedByteArray,
	flags: PackedByteArray,
	site: Rect2i,
	area: int,
	random: SimRandom,
	map_edge: int = 128,
) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	var anchor := Vector2i(site.position.x, site.end.y - 1)
	var anchor_index := anchor.x * map_edge + anchor.y
	var effect_altitude := _effect_altitude(altitude, flags, anchor_index)

	for frame in area:
		for x_offset in area:
			for y_offset in area:
				var effect_point := Vector2i(
					site.position.x + x_offset, site.end.y - 1 - y_offset
				)
				effects.append(_dust_effect(
					effect_point,
					effect_altitude,
					random,
					frame,
					Vector2i(0, -frame * 8)
				))

	return effects


static func _building_area(tile_id: int) -> int:
	if tile_id < 0x70:
		return 1

	if tile_id <= 0x8b:
		return 1

	if tile_id <= 0xad:
		return 2

	if tile_id <= 0xc5:
		return 3

	if tile_id <= 0xc8:
		return 1

	if tile_id <= 0xcf:
		return 4

	if tile_id <= 0xd6:
		return 3

	if tile_id <= 0xda:
		return 4

	if tile_id <= 0xea:
		return 1

	if tile_id <= 0xf7:
		return 2

	if tile_id <= 0xfa:
		return 3

	return 4


static func _find_building_site(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	selected: Vector2i,
	tile_id: int,
	area: int,
	rotation: int,
	map_edge: int = 128,
) -> Rect2i:
	if area == 1:
		return Rect2i(selected, Vector2i.ONE)

	for origin_x in range(selected.x - area + 1, selected.x + 1):
		for origin_y in range(selected.y - area + 1, selected.y + 1):
			var site := Rect2i(origin_x, origin_y, area, area)

			if site.position.x < 0 or site.position.y < 0 or site.end.x > map_edge or site.end.y > map_edge:
				continue

			if _site_matches(buildings, zones, site, tile_id, rotation, map_edge):
				return site

	return Rect2i()


static func _site_matches(
	buildings: PackedByteArray,
	zones: PackedByteArray,
	site: Rect2i,
	tile_id: int,
	rotation: int,
	map_edge: int = 128,
) -> bool:
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			if buildings[x * map_edge + y] != tile_id:
				return false

	var far := site.end - Vector2i.ONE
	var view := rotation & 3

	return (
		(zones[site.position.x * map_edge + site.position.y] & 0xf0) == CORNER_BOTTOM_LEFT[view]
		and (zones[far.x * map_edge + site.position.y] & 0xf0) == CORNER_BOTTOM_RIGHT[view]
		and (zones[far.x * map_edge + far.y] & 0xf0) == CORNER_TOP_LEFT[view]
		and (zones[site.position.x * map_edge + far.y] & 0xf0) == CORNER_TOP_RIGHT[view]
	)


static func _release_overlay(
	text_overlays: PackedByteArray,
	labels: PackedByteArray,
	microsims: PackedByteArray,
	index: int
) -> void:
	var label_id := int(OverlayData.read(text_overlays, index))

	if label_id == 0:
		return

	if not OverlayData.blocks_thing(label_id) or label_id == 250:
		OverlayData.write(text_overlays, index, 0)

	if OverlayData.is_sign(label_id):
		labels[label_id * CityState.LABEL_RECORD_SIZE] = 0
	elif OverlayData.is_facility(label_id) and OverlayData.facility_record(label_id) >= BuildingCommand.MICROSIM_DYNAMIC_FIRST:
		var record_id := OverlayData.facility_record(label_id)
		microsims[record_id * CityState.MICROSIM_RECORD_SIZE] = 0
		labels[label_id * CityState.LABEL_RECORD_SIZE] = 0
