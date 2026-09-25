extends SceneTree
## Cache hits preserve insertion order across eviction and revision changes.

@warning_ignore_start("integer_division")

func _initialize() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(256))
	var sprites := FixtureGraphics.pack().large_sprites
	assert(city.is_valid() and sprites.is_valid())
	var palette := Sc2Palette.index_encoding()
	var config := CityIsometricRenderer.view_configuration(2)
	var context := CityGpuBuildContext.new()
	context.set_revision(1, [city.map_size])
	for index in 17409:
		context.tile(city, palette, sprites, config, index / 256, index % 256, CityViewMode.Mode.CITY, true, true)
		if index == 16383:
			var first := context.tiles[0]
			assert(context.tile(city, palette, sprites, config, 0, 0, CityViewMode.Mode.CITY, true, true) == first)
	assert(context.tiles.size() == 15361)
	assert(not context.tiles.has(0) and not context.tiles.has(2047) and context.tiles.has(2048),
		"Two FIFO batches expire the oldest keys, including a recently hit key")
	context.set_revision(2, [city.map_size])
	var retained := context.tiles[2048]
	assert(context.tile(city, palette, sprites, config, 8, 0, CityViewMode.Mode.CITY, true, true) == retained)
	city.buildings[2048] = 1
	context.set_revision(3, [city.map_size])
	assert(context.tile(city, palette, sprites, config, 8, 0, CityViewMode.Mode.CITY, true, true) != retained)
	assert(context.tiles.size() == 15361, "Replacements must preserve FIFO size and order")

	for index in range(17409, 18433):
		context.tile(city, palette, sprites, config, index / 256, index % 256, CityViewMode.Mode.CITY, true, true)

	assert(context.tiles.size() == 15361)
	assert(not context.tiles.has(2048) and not context.tiles.has(3071) and context.tiles.has(3072),
		"Replacing a tile must not duplicate its FIFO key or change its eviction order")
	context.set_revision(4)
	assert(context.tiles.is_empty())
	var rebuilt := context.tile(city, palette, sprites, config, 0, 0, CityViewMode.Mode.CITY, true, true)
	assert(context.tiles.size() == 1 and context.tiles[0] == rebuilt)
	print("PASS: bounded GPU tile FIFO, hits, replacements, wraparound and layout reset")
	quit()
