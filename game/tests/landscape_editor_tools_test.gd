extends SceneTree


func _initialize() -> void:
	var document := Sc2File.load_path(ProjectSettings.globalize_path("res://../references/SIMCITY2000/DEFAULT.SC2"))
	var generated := NewCityTerrain.generate(document, false, false, 0, 0, 0, SimRandom.new(1), GameLcgRandom.new(1))
	assert(generated.ok)
	document.set_misc_u32(0x0e40, 2)
	var city := CityState.from_document(document)
	var random := SimRandom.new(22)
	var bytes: PackedByteArray = document.serialize().data
	var funds := city.funds()

	for tool in [Vector2i(0, 5), Vector2i(0, 6), Vector2i(0, 7), Vector2i(1, 2), Vector2i(1, 3)]:
		var result := LandscapeEditorCommand.apply(city, tool.x, tool.y, Vector2i(60, 60), random, 3)
		assert(result.ok, str(tool) + ": " + result.error)
		assert(city.funds() == funds)
		assert(document.serialize().data != bytes)
		assert(TerrainCommand.undo(city, result, random).ok)
		assert(document.serialize().data == bytes)
		assert(random.state == 22)

	var forest := LandscapeCommand.apply_path(city, 1, 3, [Vector2i(60, 60)], random)
	assert(forest.ok and forest.cost > 0)
	assert(forest.tile_indices.size() >= 8 and forest.tile_indices.size() <= 20)
	assert(city.funds() == funds - forest.cost)
	assert(forest.cost == forest.tile_indices.size() * 3)
	assert(LandscapeCommand.undo(city, forest, random).ok)
	assert(document.serialize().data == bytes and random.state == 22)
	var repeated := LandscapeCommand.apply_path(city, 1, 3, [Vector2i(60, 60)], random)
	assert(repeated.tile_indices == forest.tile_indices and repeated.random_state_after == forest.random_state_after)
	assert(LandscapeCommand.undo(city, repeated, random).ok)
	print("PASS: editor stretch, both sea levels, stream and forest change terrain for free with exact Undo")
	quit()
