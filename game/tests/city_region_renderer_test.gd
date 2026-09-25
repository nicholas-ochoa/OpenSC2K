extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_configuration_offsets()
	var large := FixtureGraphics.pack().large_sprites
	var small := FixtureGraphics.pack().small_medium_sprites
	var palette := Sc2Palette.index_encoding()

	for edge in [128, 512]:
		# Dense original city for sprite coverage; sparse maximum map for extents.
		var document := Sc2File.load_path("res://tests/fixtures/cities/generated-128.SC2") if edge == 128 else EmptyCityTemplate.create(edge)
		var city := CityState.from_document(document)
		if edge == 512:
			for point in [Vector2i(10, 10), Vector2i(256, 256), Vector2i(509, 509)]:
				assert(city.set_building_id(point.x, point.y, BuildingTileIds.SMALL_PARK))
				assert(city.set_building_id(point.x + 1, point.y, BuildingTileIds.ROAD_STRAIGHT_1))

		# All sprite sizes at 128; maximum map bounds with the small painter.
		for view in ([0, 1, 2] if edge == 128 else [CityIsometricRenderer.VIEW_SMALL]):
			var sprites := large if view == CityIsometricRenderer.VIEW_LARGE else small

			for mode: CityViewMode.Mode in ([CityViewMode.Mode.CITY, CityViewMode.Mode.UNDERGROUND] if edge == 128 else [CityViewMode.Mode.CITY]):
				var full: AssetImageResult

				if mode == CityViewMode.Mode.CITY:
					full = CityIsometricRenderer.create_image(city, palette, sprites, view, 0, false, true, false, false)
				else:
					full = CityUndergroundView.create_image(city, palette, sprites, view, false)

				assert(full.ok)
				var size: Vector2i = full.image.get_size()

				for fraction in [Vector2(0.1, 0.1), Vector2(0.5, 0.5), Vector2(0.8, 0.8), Vector2(0.5, 0.9)]:
					var bounds := Rect2i(Vector2i(Vector2(size) * fraction), Vector2i(517, 263)).intersection(Rect2i(Vector2i.ZERO, size))
					var region := CityRegionRenderer.render(city, palette, sprites, bounds, view, mode)
					assert(region.ok)
					assert(region.image.get_data() == full.image.get_region(bounds).get_data(), "Region pixels differ: %d %d %s %s" % [edge, view, CityViewMode.key(mode), bounds])
					assert(region.tiles_drawn < edge * edge, "Region render scanned the whole map")

				print("PASS: %d view %d %s regional pixels match whole-map painter" % [edge, view, CityViewMode.key(mode)])

	quit()


func _check_configuration_offsets() -> void:
	assert(CityIsometricRenderer.view_configuration(-1) == null)
	assert(CityIsometricRenderer.view_configuration(3) == null)

	for view in 3:
		var base := CityIsometricRenderer.view_configuration(view)
		var original_margin := base.top_margin

		for margin in [-512, 0, 128, original_margin]:
			var local := base.with_top_margin(margin)
			assert(local != base and local.top_margin == margin)
			assert(base.top_margin == original_margin)
			assert(local.view_size == base.view_size and local.divisor == base.divisor)
			assert(local.tile_width == base.tile_width and local.tile_height == base.tile_height)
			assert(local.half_width == base.half_width and local.half_height == base.half_height)
			assert(local.altitude_step == base.altitude_step and local.side_margin == base.side_margin)
			assert(local.sprite_base == base.sprite_base)

		assert(CityIsometricRenderer.view_configuration(view) == base)
