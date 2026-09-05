extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var city := CityState.from_document(Sc2File.load_path("res://../references/SIMCITY2000/CITIES/SYDNEY.SC2"))
	var palette := Sc2Palette.index_encoding()
	var large := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/LARGE.DAT")
	var medium := Sc2SpriteArchive.combine([Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/SMALLMED.DAT"), Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/SPECIAL.DAT")])

	for view in [0, 1, 2]:
		var sprites := large if view == 2 else medium
		var divisor := int(CityIsometricRenderer.view_configuration(view).divisor)
		var cache := CityRegionCache.new()
		cache.configure(city, palette, sprites, [view], view, CityViewMode.Mode.CITY, CityViewFilter.DEFAULT_VISIBILITY, true, true)
		var viewport := Rect2(1400, 800, 1400, 1100)
		cache.update_viewport(viewport)
		var deadline := Time.get_ticks_msec() + 30000

		while not cache.ready() and Time.get_ticks_msec() < deadline:
			cache.tick()
			await process_frame

		assert(cache.ready() and cache.last_error.is_empty())
		var whole := CityIsometricRenderer.static_occlusion_commands(city, sprites, view)

		for point in [Vector2i(1500, 950), Vector2i(2041, 1021), Vector2i(2300, 1510)]:
			var bounds := Rect2i(point, Vector2i(83, 127))
			var expected: Array[CityStaticCommand] = []

			for command in whole:
				if Rect2i(command.position * divisor, command.size * divisor).intersects(bounds):
					expected.append(command)

			var actual: Array[CityStaticCommand] = []

			for command in cache.occlusion_candidates(bounds):
				if Rect2i(command.position * divisor, command.size * divisor).intersects(bounds):
					actual.append(command)

			assert(_static_command_values(actual, false) == _static_command_values(expected, false), "Regional foreground order differs at view %d" % view)

		cache.close()

	print("PASS: regional foreground candidates match whole-map painter order at all native views")
	quit()


func _static_command_values(commands: Array[CityStaticCommand], include_region := true) -> Array:
	var values: Array = []

	for command in commands:
		var fields := [command.sprite_id, command.flip, command.position, command.size,
			command.depth_order, command.train_ignore, command.train_foreground_reference_sprite_id,
			command.train_deck_thickness, command.train_deck_reference_sprite_id,
			command.train_foreground_requires_depth]

		if include_region:
			fields.append(command.region_order)

		values.append(fields)

	return values
