extends "res://tests/city_gpu_geometry_test.gd"
## GPU regions must match the native CPU pixels of the same regions in pixels and
## foreground order. Warm builders must also match them after every kind of city edit.

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

var _revision := 0


func _run() -> void:
	var palette := Sc2Palette.index_encoding()
	var graphics := FixtureGraphics.pack()
	await _catalog_cases(palette, graphics)
	await _random_cases(palette, graphics)
	await _edit_cases(palette, graphics.large_sprites)
	await _dispatch_revision_case(palette, graphics)
	await _large_city_case(palette, graphics)
	print("PASS: native regions match CPU pixels, draw order, foreground and warm revisions")
	quit()


# gdstyle:ignore=quality/max-parameters
func _compare_region(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive, bounds: Rect2i,
		view: int, mode: CityViewMode.Mode, context: CityGpuBuildContext, revision: int,
		pipes := true, subways := true, mains := true) -> CityGpuRegionResult:
	var expected := CityRegionRenderer.render(city, palette, sprites, bounds, view, mode, pipes, subways, mains)
	var actual := CityGpuRegionRenderer.render(city, palette, sprites, bounds, view, mode, pipes, subways,
		context, revision, -1, true, mains)
	assert(expected.ok and actual.ok, "Native region failed: %s / %s" % [expected.error, actual.error])
	assert(actual.bounds == bounds)
	var expected_commands := _static_command_values(expected.occlusion_commands)
	var actual_commands := _static_command_values(actual.foreground_commands())

	if expected_commands != actual_commands:
		for index in mini(expected_commands.size(), actual_commands.size()):
			if expected_commands[index] != actual_commands[index]:
				print("COMMAND DIFFERENCE %d expected=%s actual=%s" % [index, expected_commands[index], actual_commands[index]])
				break

	assert(expected_commands == actual_commands,
		"Native foreground differs (%d / %d commands)" % [expected_commands.size(), actual_commands.size()])
	var expected_image := expected.image.duplicate()
	expected_image.convert(Image.FORMAT_LA8)
	assert(actual.paint(bounds).get_data() == expected_image.get_data(), "Native region pixels differ")

	if DisplayServer.get_name() != "headless":
		await _check_gpu_pixels(actual, expected_image)

	return actual


static func _cell_bounds(city: CityState, view: int, cell: Vector2i, extent: Vector2i) -> Rect2i:
	var config := CityIsometricRenderer.view_configuration(view)
	var anchor := Vector2i(config.side_margin + (city.map_size + cell.x - cell.y) * config.half_width,
		config.top_margin + (cell.x + cell.y) * config.half_height)
	var size := CityIsometricRenderer.output_size_for_view(view, city.map_size)
	var bounds := Rect2i(anchor - extent / 2, extent)

	return bounds.intersection(Rect2i(Vector2i.ZERO, size))


func _catalog_cases(palette: Sc2Palette, graphics: GraphicsPack) -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	var terrains := PackedInt32Array([0, 1, 13, 14, 16, 29, 32, 45, 48, 61, 62, 64, 69])

	for building in 256:
		var x := 56 + building / 16
		var y := 56 + building % 16
		var index := city.index_of(x, y)
		city.buildings[index] = building
		city.terrain[index] = terrains[building % terrains.size()]
		city.zones[index] = 0xf0 | (building % 9)
		city.tile_flags[index] = 0xb0 | (building % 8)
		city.altitude_words[index] = (building % 12) | ((building % 12) << 5) | ((building % 4) << 10)
		city.underground[index] = building % 36

	city.document.find_chunk("XTRF").decoded_payload.fill(200)

	for view in 3:
		var sprites := graphics.large_sprites if view == 2 else graphics.small_medium_sprites
		var size := CityIsometricRenderer.output_size_for_view(view, city.map_size)
		var extent := Vector2i(640, 640) / CityIsometricRenderer.view_configuration(view).divisor
		var bounds := Rect2i(size / 2 - extent / 2, extent)
		var context := CityGpuBuildContext.new()
		await _compare_region(city, palette, sprites, bounds, view, CityViewMode.Mode.CITY, context, 1)
		# Change tile inputs without changing layout.
		city.tile_flags[city.index_of(60, 60)] ^= Sc2TileFlags.FLIPPED
		city.altitude_words[city.index_of(60, 61)] += 1
		city.document.find_chunk("XTRF").decoded_payload.fill(100 if view == 1 else 200)
		await _compare_region(city, palette, sprites, bounds, view, CityViewMode.Mode.CITY, context, 2)
		city.visible_altitude_levels = 6
		await _compare_region(city, palette, sprites, bounds, view, CityViewMode.Mode.CITY, context, 3)
		city.visible_altitude_levels = 32

		for switches in [[true, true, true], [false, true, true], [true, false, true], [true, true, false]]:
			await _compare_region(city, palette, sprites, bounds, view, CityViewMode.Mode.UNDERGROUND, context, 4,
				switches[0], switches[1], switches[2])

		print("PASS: native building and terrain catalog, traffic, cutaways and underground switches view %d" % view)

	# Each compass anchor and filtered display snapshot must reach native code.
	for rotation in 4:
		city.document.set_misc_u32(0x08, rotation)
		var displayed := CityViewFilter.surface_copy(city, { "water": false, "zones": false })
		await _compare_region(displayed, palette, graphics.large_sprites, Rect2i(1800, 1100, 512, 512),
			2, CityViewMode.Mode.CITY, CityGpuBuildContext.new(), 1)


# Random terrain, heights, water, buildings, zones, flags, overlays and object
# heights, at each view, rotation and cutaway, near the map center and far edges.
func _random_cases(palette: Sc2Palette, graphics: GraphicsPack) -> void:
	var city := CityState.from_document(Sc2File.load_path("res://tests/fixtures/cities/generated-128.SC2"))
	var overrides := _generate(city)
	var setups := [
		{ "view": 2, "rotation": 0, "levels": 32, "overrides": true },
		{ "view": 2, "rotation": 1, "levels": 32, "overrides": true },
		{ "view": 2, "rotation": 2, "levels": 12, "overrides": true },
		{ "view": 2, "rotation": 3, "levels": 32, "overrides": false },
		{ "view": 1, "rotation": 1, "levels": 12, "overrides": true },
		{ "view": 0, "rotation": 2, "levels": 32, "overrides": true },
	]

	for setup: Dictionary in setups:
		city.document.set_misc_u32(0x08, setup.rotation)
		city.visible_altitude_levels = setup.levels
		city.object_altitude_overrides = overrides if setup.overrides else PackedInt32Array()
		var view: int = setup.view
		var sprites := graphics.large_sprites if view == 2 else graphics.small_medium_sprites
		var extent := Vector2i(512, 384) / CityIsometricRenderer.view_configuration(view).divisor
		var context := CityGpuBuildContext.new()

		for cell in [Vector2i(24, 24), Vector2i(127, 64), Vector2i(64, 127)]:
			await _compare_region(city, palette, sprites, _cell_bounds(city, view, cell, extent), view,
				CityViewMode.Mode.CITY, context, 1)

	print("PASS: native regions match random tiles at each view, rotation and cutaway")


## Fill the map from a fixed seed. Water tiles often sit level with land, so the
## shoreline terrain ids take the 0x3e substitution on some tiles.
func _generate(city: CityState) -> PackedInt32Array:
	var random := RandomNumberGenerator.new()
	random.seed = 0x5c2000
	var count := city.map_size * city.map_size
	var buildings := PackedByteArray()
	var zones := PackedByteArray()
	var flags := PackedByteArray()
	var overlays := PackedByteArray()
	var overrides := PackedInt32Array()
	buildings.resize(count)
	zones.resize(count)
	flags.resize(count)
	overlays.resize(count)
	overrides.resize(count)

	for index in count:
		var x := index / city.map_size
		var y := index % city.map_size
		var land := random.randi_range(0, 31)
		assert(city.set_terrain_id(x, y, random.randi_range(0x00, 0x45)))
		assert(city.set_land_altitude(x, y, land))
		assert(city.set_water_altitude(x, y, land if random.randf() < 0.5 else random.randi_range(0, 31)))
		buildings[index] = [0, random.randi_range(Tiles.RUBBLE_FIRST, Tiles.SMALL_PARK),
			random.randi_range(Tiles.POWER_LINE_FIRST, Tiles.RAIL_SUBWAY_LAST),
			random.randi_range(Tiles.DEVELOPED_FIRST, Tiles.MAX_ID)][random.randi_range(0, 3)]
		zones[index] = random.randi_range(0, 0xff) if random.randf() < 0.75 else random.randi_range(0, 0x0f)
		flags[index] = random.randi_range(0, 0xff)
		overlays[index] = random.randi_range(201, 240) if random.randf() < 0.05 else 0
		overrides[index] = random.randi_range(0, 31) if random.randf() < 0.3 else -1

	assert(city.replace_buildings(buildings) and city.replace_zones(zones))
	assert(city.replace_tile_flags(flags) and city.replace_text_overlays(overlays))

	return overrides


# One warm builder sees each tile edit. Stale cached draws would differ from the CPU.
func _edit_cases(palette: Sc2Palette, sprites: Sc2SpriteArchive) -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	var context := CityGpuBuildContext.new()
	var point := Vector2i(20, 20)
	var key := city.index_of(point.x, point.y)
	var near := _cell_bounds(city, 2, point, Vector2i(192, 160))
	var edge := _cell_bounds(city, 2, Vector2i(127, 20), Vector2i(192, 160))
	# A distant peak fixes the candidate span, so edits below repaint only their neighbors.
	city.altitude_words[city.index_of(100, 100)] = 31
	await _next(city, palette, sprites, near, context)
	var builds := context.tile_builds
	city.buildings[city.index_of(80, 80)] = Tiles.TREES_1
	await _next(city, palette, sprites, near, context)
	assert(context.tile_builds == builds, "An unrelated edit must not paint this region again")

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
		func(): city.buildings[key] = Tiles.POWER_LINE_STRAIGHT_1,
	]:
		mutation.call()
		builds = context.tile_builds
		await _next(city, palette, sprites, near, context)
		# The edited cell and its eight neighbors are painted again.
		assert(context.tile_builds > builds and context.tile_builds - builds <= 9)

	city.object_altitude_overrides.resize(city.map_size * city.map_size)
	city.object_altitude_overrides.fill(-1)
	city.object_altitude_overrides[key] = 9
	await _next(city, palette, sprites, near, context)
	city.object_altitude_overrides.clear()
	await _next(city, palette, sprites, near, context)

	# The shoreline depends on adjacent land, even when its own bytes stay equal.
	city.buildings[key] = Tiles.EMPTY
	city.zones[key] = 0
	city.tile_flags[key] = Sc2TileFlags.WATER
	city.altitude_words[key] = 0
	city.terrain[key] = TerrainTileIds.SURFACE_WATER_FIRST
	await _next(city, palette, sprites, near, context)
	city.altitude_words[city.index_of(point.x + 1, point.y)] = 12
	await _next(city, palette, sprites, near, context)

	# Map-edge cliffs and composite ground read other cells.
	await _next(city, palette, sprites, edge, context)
	city.altitude_words[city.index_of(127, 20)] = 7
	await _next(city, palette, sprites, edge, context)
	city.buildings[key] = Tiles.TREES_1
	await _next(city, palette, sprites, near, context)
	assert(city.set_text_overlay_id(point.x, point.y, 201))
	await _next(city, palette, sprites, near, context)
	city.visible_altitude_levels = 1
	await _next(city, palette, sprites, near, context)
	city.visible_altitude_levels = 32
	print("PASS: warm native regions follow tile edits, neighbors, cliffs and layout changes")


func _next(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive, bounds: Rect2i,
		context: CityGpuBuildContext) -> void:
	_revision += 3
	await _compare_region(city, palette, sprites, bounds, 2, CityViewMode.Mode.CITY, context, _revision)


func _dispatch_revision_case(palette: Sc2Palette, graphics: GraphicsPack) -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(512))
	var things := city.document.find_chunk("XTHG")
	var context := CityGpuBuildContext.new()
	var center := CityIsometricRenderer.output_size_for_view(2, city.map_size) / 2
	var bounds := Rect2i(center - Vector2i(128, 128), Vector2i(256, 256))
	var records := things.decoded_payload

	for index in 3:
		var record := 40 + index
		var offset := record * CityState.THING_RECORD_SIZE
		records[offset] = [7, 8, 14][index]
		ThingData.write(records, offset + Sc2ThingLayout.Field.X, 256 + index)
		ThingData.write(records, offset + Sc2ThingLayout.Field.Y, 256)
		assert(city.set_text_overlay_id(256 + index, 256, OverlayData.thing_id(record)))

	things.decoded_payload = records
	var first := await _compare_region(city, palette, graphics.large_sprites, bounds, 2,
		CityViewMode.Mode.CITY, context, 1)

	for sprite in [1382, 1383, 1384]:
		assert(first.foreground_commands().any(func(command: CityStaticCommand) -> bool: return command.sprite_id == sprite))

	# Moving only XTHG must remove the old dispatch draw until XTXT links its new cell.
	assert(things.write_decoded_byte(40 * CityState.THING_RECORD_SIZE + 3, 3))
	var moved := await _compare_region(city, palette, graphics.large_sprites, bounds, 2,
		CityViewMode.Mode.CITY, context, 2)
	assert(not moved.foreground_commands().any(func(command: CityStaticCommand) -> bool: return command.sprite_id == 1382))
	assert(city.set_text_overlay_id(256, 256, 0))
	assert(city.set_text_overlay_id(259, 256, OverlayData.thing_id(40)))
	await _compare_region(city, palette, graphics.large_sprites, bounds, 2, CityViewMode.Mode.CITY, context, 3)
	assert(things.write_decoded_byte(40 * CityState.THING_RECORD_SIZE, 14))
	assert(city.set_text_overlay_id(257, 256, 0))
	await _compare_region(city, palette, graphics.large_sprites, bounds, 2, CityViewMode.Mode.CITY, context, 4)
	print("PASS: native dispatch sprites and extended overlay links refresh across revisions")


func _large_city_case(palette: Sc2Palette, graphics: GraphicsPack) -> void:
	var city := CityState.from_document(Sc2File.load_path("res://tests/fixtures/cities/generated-512.sc2x"))
	var context := CityGpuBuildContext.new()
	var center := CityIsometricRenderer.output_size_for_view(0, city.map_size) / 2

	for offset in [Vector2i.ZERO, Vector2i(512, 0), Vector2i.ZERO]:
		await _compare_region(city, palette, graphics.small_medium_sprites, Rect2i(center + offset, Vector2i(257, 135)),
			0, CityViewMode.Mode.CITY, context, 1)

	# Pixel and foreground queries use painter order across index cells.
	var region := await _compare_region(city, palette, graphics.small_medium_sprites, Rect2i(center, Vector2i(257, 135)),
		0, CityViewMode.Mode.CITY, context, 1)
	var expected := region.paint(region.bounds)
	var probe := Rect2i(center + Vector2i(60, 30), Vector2i(130, 70))
	assert(region.paint(probe).get_data() == expected.get_region(Rect2i(probe.position - center, probe.size)).get_data())
	var screen := Rect2i(probe.position * 4, probe.size * 4)
	var orders: Array[int] = []

	for index in region.occlusion_indices(screen):
		var command := region.occlusion_command(index)
		assert(Rect2i(command.position * 4, command.size * 4).intersects(screen) and command.depth_order >= 0)
		orders.append(command.region_order)

	var sorted := orders.duplicate()
	sorted.sort()
	assert(not orders.is_empty() and orders == sorted)
	print("PASS: native 512 city regions and draw queries")
