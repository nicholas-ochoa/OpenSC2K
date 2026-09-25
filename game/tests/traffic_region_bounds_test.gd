extends "res://tests/simulation_region_refresh_test.gd"
## Traffic invalidation must contain every changed pixel, including custom art.

@warning_ignore_start("integer_division")

var _comparisons := 0
var _changed_pixels := 0


func _initialize() -> void:
	var palette := Sc2Palette.index_encoding()
	var large := FixtureGraphics.pack().large_sprites
	var small := FixtureGraphics.pack().small_medium_sprites
	assert(large.is_valid() and small.is_valid())

	for view in [2, 1, 0]:
		var city := CityState.from_document(EmptyCityTemplate.create(128))
		city.document.set_misc_u32(0x08, view)
		var points: Array[Vector2i] = []

		for index in IsometricStaticVisuals.TRAFFIC_TILE_VARIANTS.size():
			var point := Vector2i(40 + (index % 8) * 2, 40 + (index / 8) * 2)
			points.append(point)
			assert(city.set_building_id(point.x, point.y, IsometricStaticVisuals.TRAFFIC_TILE_FIRST + index))
			assert(city.set_land_altitude(point.x, point.y, [0, 5, 31][index % 3]))
			assert(city.set_terrain_id(point.x, point.y, TerrainTileIds.RAISED if index % 3 == 1 else 0))
			assert(city.set_tile_flag(point.x, point.y, Sc2TileFlags.FLIPPED, index % 2 == 0))
			city.zones[city.index_of(point.x, point.y)] = 0xf0

		assert(city.replace_zones(city.zones))
		var sprites := large if view == 2 else small
		var images := {}
		var before := _paint_tiles(city, palette, sprites, view, points, images)

		for density in [28, 29, 56, 57, 85, 86, 170, 171, 0]:
			var previous := _payloads(city)
			var traffic := city.document.find_chunk("XTRF").decoded_payload.duplicate()
			traffic.fill(density)
			assert(city.document.find_chunk("XTRF").set_decoded_payload(traffic, true))
			var rects: Array[Rect2i] = []
			assert(ApplicationStaticRender.changed_source_rects(city, previous, sprites, view, rects))
			var after := _paint_tiles(city, palette, sprites, view, points, images)
			_check_pixels(before, after, rects)
			before = after

	# Custom road artwork can be narrower than the traffic image. The mask must
	# keep every changed pixel inside the road, including odd-sized sprite data.
	var custom_city := CityState.from_document(EmptyCityTemplate.create(128))
	assert(custom_city.set_building_id(60, 60, BuildingTileIds.ROAD_STRAIGHT_1))
	_custom_sprite(large, 1000 + BuildingTileIds.ROAD_STRAIGHT_1, Vector2i(19, 23), 0xa1)
	_custom_sprite(large, 1400, Vector2i(73, 41), 5)
	var custom_points: Array[Vector2i] = [Vector2i(60, 60)]
	var images := {}
	var custom_before := _paint_tiles(custom_city, palette, large, 2, custom_points, images)
	var custom_old := _payloads(custom_city)
	_write(custom_city, "XTRF", 30 * 64 + 30, 86)
	var custom_rects: Array[Rect2i] = []
	assert(ApplicationStaticRender.changed_source_rects(custom_city, custom_old, large, 2, custom_rects))
	assert(custom_rects.size() == 1 and custom_rects[0].size == Vector2i(19, 23))
	_check_pixels(custom_before, _paint_tiles(custom_city, palette, large, 2, custom_points, images), custom_rects)

	# A traffic cell on an extended map covers a different number of tiles.
	var wide := CityState.from_document(EmptyCityTemplate.create(512))
	assert(wide.set_building_id(510, 510, BuildingTileIds.ROAD_STRAIGHT_1))
	assert(wide.set_building_id(511, 511, BuildingTileIds.HIGHWAY_STRAIGHT_1))
	var old := _payloads(wide)
	var traffic := wide.document.find_chunk("XTRF").decoded_payload.duplicate()
	traffic.fill(29)
	assert(wide.document.find_chunk("XTRF").set_decoded_payload(traffic, true))
	var rects: Array[Rect2i] = []
	assert(ApplicationStaticRender.changed_source_rects(wide, old, large, 2, rects))
	assert(rects.size() == 1, "A highway threshold must not dirty a road or empty tiles")
	assert(_changed_pixels > 0)
	print("PASS: traffic bounds contain %d changed pixels in %d tile comparisons, all artwork sizes and extended-map edges" % [_changed_pixels, _comparisons])
	quit()


func _custom_sprite(sprites: Sc2SpriteArchive, id: int, size: Vector2i, color: int) -> void:
	var entry := Sc2SpriteArchive.SpriteEntry.new()
	entry.sprite_id = id
	entry.width = size.x
	entry.height = size.y
	entry._direct_indices.resize(size.x * size.y)
	entry._direct_indices.fill(color)
	sprites.entries_by_id[id] = entry
	sprites.entries.append(entry)


func _paint_tiles(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		view: int, points: Array[Vector2i], images: Dictionary) -> Array[CityGpuDrawList]:
	var config := CityIsometricRenderer.view_configuration(view)
	var result: Array[CityGpuDrawList] = []

	for point in points:
		var draws := CityGpuDrawList.new()
		CityIsometricRenderer.draw_tile(draws, city, palette, sprites, images, config,
			config.side_margin + city.map_size * config.half_width, point.x, point.y, 0, false, false)
		result.append(draws)

	return result


func _check_pixels(before: Array[CityGpuDrawList], after: Array[CityGpuDrawList], rects: Array[Rect2i]) -> void:
	for index in before.size():
		var bounds := Rect2i()

		for draw: CityGpuDrawList.Draw in before[index].draws + after[index].draws:
			var rectangle := Rect2i(draw.position, draw.source.size)
			bounds = bounds.merge(rectangle) if bounds.has_area() else rectangle

		if not bounds.has_area():
			continue

		var a_bytes := CityGpuDrawList.paint(before[index].draws, bounds, Color.TRANSPARENT).get_data()
		var b_bytes := CityGpuDrawList.paint(after[index].draws, bounds, Color.TRANSPARENT).get_data()
		a_bytes.resize((a_bytes.size() + 3) & ~3)
		b_bytes.resize((b_bytes.size() + 3) & ~3)
		var a := a_bytes.to_int32_array()
		var b := b_bytes.to_int32_array()
		# LA8 has two bytes per pixel; compare two pixels at once.
		for word in a.size():
			if a[word] == b[word]:
				continue

			for pixel in 2:
				if ((a[word] ^ b[word]) & (0xffff << (pixel * 16))) == 0:
					continue

				var offset := word * 2 + pixel
				var point := bounds.position + Vector2i(offset % bounds.size.x, offset / bounds.size.x)
				assert(rects.any(func(rect: Rect2i) -> bool: return rect.has_point(point)), "Traffic changed outside its dirty bounds at %s" % point)
				_changed_pixels += 1

		_comparisons += 1
