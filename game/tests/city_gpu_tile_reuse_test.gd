extends "res://tests/city_gpu_fast_tile_test.gd"
## Reuse unchanged surface drawings without hiding edits or neighbor changes.

var _revision := 0


func _initialize() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	var palette := Sc2Palette.index_encoding()
	var sprites := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/LARGE.DAT")
	var context := CityGpuBuildContext.new()
	var config := CityIsometricRenderer.view_configuration(2)
	var point := Vector2i(20, 20)
	var key := city.index_of(point.x, point.y)
	assert(city.is_valid() and sprites.is_valid())
	var first := _next(city, palette, sprites, config, context, point)
	assert(_next(city, palette, sprites, config, context, point) == first,
		"An unchanged tile must retain its drawing objects across skipped revisions")
	city.buildings[city.index_of(80, 80)] = Tiles.TREES_1
	assert(_next(city, palette, sprites, config, context, point) == first,
		"An unrelated edit must not discard this tile")

	# Each change is checked against the uncached painter, using the same images.
	for mutation: Callable in [
		func(): city.terrain[key] = TerrainTileIds.RAISED,
		func(): city.altitude_words[key] = 5,
		func(): city.zones[key] = 1,
		func(): city.buildings[key] = Tiles.TREES_1,
		func(): city.tile_flags[key] = Sc2TileFlags.FLIPPED,
		func(): city.buildings[key] = Tiles.DEVELOPED_FIRST,
		func(): city.zones[key] = 0xf1,
		func(): city.tile_flags[key] = Sc2TileFlags.POWERABLE,
		func(): city.tile_flags[key] |= Sc2TileFlags.POWERED,
	]:
		mutation.call()
		var changed := _next(city, palette, sprites, config, context, point)
		assert(changed != first, "Changed drawing inputs must expire the tile")
		first = changed

	city.object_altitude_overrides.resize(city.map_size * city.map_size)
	city.object_altitude_overrides.fill(-1)
	city.object_altitude_overrides[key] = 9
	assert(_next(city, palette, sprites, config, context, point) != first)
	city.object_altitude_overrides.clear()

	# The shoreline depends on adjacent land, even when its own bytes stay equal.
	city.buildings[key] = Tiles.EMPTY
	city.zones[key] = 0
	city.tile_flags[key] = Sc2TileFlags.WATER
	city.altitude_words[key] = 0
	city.terrain[key] = TerrainTileIds.SURFACE_WATER_FIRST
	first = _next(city, palette, sprites, config, context, point)
	city.altitude_words[city.index_of(point.x + 1, point.y)] = 12
	assert(_next(city, palette, sprites, config, context, point) != first,
		"A neighboring height change must update the waterfall")

	# Complex painters still expire every revision, including map-edge cliffs.
	city.buildings[key] = Tiles.POWER_LINE_STRAIGHT_1
	first = _next(city, palette, sprites, config, context, point)
	assert(_next(city, palette, sprites, config, context, point) != first)
	first = _next(city, palette, sprites, config, context, Vector2i(127, 20))
	assert(_next(city, palette, sprites, config, context, Vector2i(127, 20)) != first)

	city.buildings[key] = Tiles.TREES_1
	first = _next(city, palette, sprites, config, context, point)
	assert(city.set_text_overlay_id(point.x, point.y, 201))
	assert(_next(city, palette, sprites, config, context, point) != first,
		"A moving-object overlay must leave the reusable painter")

	# Exercise the actual region entry point, including its layout reset contract.
	var bounds := Rect2i(4000, 1000, 128, 128)
	var result := CityGpuRegionRenderer.render(city, palette, sprites, bounds, 2,
		CityViewMode.Mode.CITY, true, true, context, 100, -1)
	assert(result.ok and not context.tiles.is_empty())
	var previous: Dictionary[int, CityGpuBuildContext.Tile] = context.tiles.duplicate()
	city.visible_altitude_levels = 1
	result = CityGpuRegionRenderer.render(city, palette, sprites, bounds, 2,
		CityViewMode.Mode.CITY, true, true, context, 101, -1)
	assert(result.ok)

	for tile_key: int in context.tiles:
		assert(not previous.has(tile_key) or previous[tile_key] != context.tiles[tile_key],
			"Altitude visibility changes must discard drawings from the old layout")

	var cleared := _measure_reuse(palette, sprites, config, false)
	var retained := _measure_reuse(palette, sprites, config, true)
	assert(cleared.builds == 11264 and retained.builds == 1034 and retained.reuses == 10230,
		"Ten one-tile edits must rebuild only ten of the 1024 cached common tiles")
	print("Tile allocation workload: clear=%s; retain=%s" % [cleared, retained])
	print("PASS: unchanged GPU tile reuse, drawing mutations, waterfall neighbors, complex tiles and layout resets")
	quit()


func _next(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		config: CityViewConfiguration, context: CityGpuBuildContext, point: Vector2i) -> CityGpuBuildContext.Tile:
	_revision += 3
	context.set_revision(_revision, [city.map_size, city.visible_altitude_levels, city.compass_rotation(),
		2, CityViewMode.Mode.CITY, true, true, true, palette, sprites])
	context.rotation = city.compass_rotation()
	var result := context.tile(city, palette, sprites, config, point.x, point.y, CityViewMode.Mode.CITY, true, true)
	var reference := CityGpuDrawList.new()
	CityIsometricRenderer.draw_tile(reference, city, palette, sprites, context.images, config,
		config.side_margin + city.map_size * config.half_width, point.x, point.y, 0, false, false)
	assert(_same(result.draws, reference.draws), "Reused tile differs from the uncached painter at %s" % point)

	return result


func _measure_reuse(palette: Sc2Palette, sprites: Sc2SpriteArchive, config: CityViewConfiguration, retain: bool) -> Dictionary:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	var context := CityGpuBuildContext.new()
	var started := Time.get_ticks_usec()

	for revision in 11:
		context.set_revision(revision, [128] if retain else [])
		city.buildings[city.index_of(10, 10)] = Tiles.TREES_1 if revision % 2 == 1 else Tiles.EMPTY

		for x in 32:
			for y in 32:
				context.tile(city, palette, sprites, config, x, y, CityViewMode.Mode.CITY, true, true)

	return {"usec": Time.get_ticks_usec() - started, "builds": context.tile_builds, "reuses": context.tile_reuses}
