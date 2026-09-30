extends SceneTree

@warning_ignore_start("integer_division")


func _initialize() -> void:
	var doc := EmptyCityTemplate.create()
	assert(NewCityTerrain.generate(doc, false, false, 0, 0, 0, SimRandom.new(1), GameLcgRandom.new(1)).ok)
	var city := CityState.from_document(doc)

	for index in CityState.TILE_COUNT:
		city.set_land_altitude(index / 128, index % 128, maxi(0, 16 - ((index / 128) / 4)))

	# lowering the sea from level 1 to 0 retiles the whole slope
	doc.set_misc_u32(0x0e40, 1)
	assert(LandscapeEditorCommand.apply(city, CityToolIds.Group.BULLDOZER, CityToolIds.Bulldozer.LOWER_SEA, Vector2i.ZERO,
		SimRandom.new(1)).ok)
	var before: PackedByteArray = doc.serialize().data
	var rng := SimRandom.new(22)
	var result := LandscapeEditorCommand.apply(city, 1, 2, Vector2i(40, 64), rng)
	assert(result.ok)
	assert(city.terrain_id(40, 64) == 0x3e, "Stream tool must save a waterfall on the descending slope")

	for index in CityState.TILE_COUNT:
		if not city.tile_flags[index] & 4:
			continue

		var point := Vector2i(index / 128, index % 128)

		if CityIsometricRenderer.surface_terrain_id(city, point.x, point.y) == 0x3e:
			assert(city.terrain[index] == 0x3e, "Edited slope still needs display repair")

	assert(TerrainCommand.undo(city, result, rng).ok)
	assert(doc.serialize().data == before and rng.state == 22)
	print("PASS: editor stream stores waterfall faces and exact Undo restores terrain and RNG")
	quit()
