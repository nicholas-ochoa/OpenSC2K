extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for edge in [128, 512]:
		var doc := EmptyCityTemplate.create(edge)
		assert(NewCityTerrain.generate(doc, false, false, 47, 0, 0,
			SimRandom.new(1), GameLcgRandom.new(1), "classic", [], true).ok)
		var city := CityState.from_document(doc)
		for x in edge - 1:
			for y in edge - 1:
				var a := CityIsometricRenderer.terrain_surface_polygon(city, x, y, true)
				var b := CityIsometricRenderer.terrain_surface_polygon(city, x + 1, y, true)
				var c := CityIsometricRenderer.terrain_surface_polygon(city, x, y + 1, true)
				assert(a[1] == b[0] and a[2] == b[3], "Gap across x at %d,%d" % [x, y])
				assert(a[3] == c[0] and a[2] == c[1], "Gap across y at %d,%d" % [x, y])
		print("Continuous ground: ", edge)

	for stream in [false, true]:
		var painted := CityState.from_document(EmptyCityTemplate.create())
		var before := CityIsometricRenderer.terrain_surface_polygon(painted, 64, 64, true)
		var result: Dictionary
		if stream:
			result = LandscapeEditorCommand.apply(painted, 1, 2, Vector2i(64, 64), SimRandom.new(1))
		else:
			result = LandscapeCommand.apply_path(painted, 1, 1, [Vector2i(64, 64)], SimRandom.new(1), true)
		assert(result.ok)
		assert(CityIsometricRenderer.terrain_surface_polygon(painted, 64, 64, true) == before)

	var flat := CityState.from_document(EmptyCityTemplate.create())
	for terrain in range(0x30, 0x46):
		flat.set_terrain_id(64, 64, terrain)
		flat.set_tile_flag(64, 64, 4, true)
		assert(CityIsometricRenderer.terrain_surface_polygon(flat, 64, 64, true) ==
			CityIsometricRenderer.tile_polygon(flat, 64, 64, true), "Shore code raised flat land")
	# A waterfall can still have real sloping ground under it.
	flat.set_land_altitude(65, 64, flat.land_altitude(64, 64) + 1)
	flat.set_terrain_id(64, 64, 0x3e)
	var slope := CityIsometricRenderer.terrain_surface_polygon(flat, 64, 64, true)
	flat.set_terrain_id(64, 64, 3)
	assert(slope == CityIsometricRenderer.terrain_surface_polygon(flat, 64, 64, true))
	print("Terrain surface continuity and water ground checks passed")
	quit()
