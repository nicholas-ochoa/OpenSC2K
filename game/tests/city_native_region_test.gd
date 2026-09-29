extends "res://tests/city_gpu_geometry_test.gd"
## Native region output must match the retained GDScript painter and GPU pixels.


func _run() -> void:
	var palette := Sc2Palette.index_encoding()
	var graphics := FixtureGraphics.pack()
	var city := CityState.from_document(Sc2File.load_path("res://tests/fixtures/cities/generated-128.SC2"))
	for view in 3:
		var sprites := graphics.large_sprites if view == 2 else graphics.small_medium_sprites
		var size := CityIsometricRenderer.output_size_for_view(view, city.map_size)
		for mode: CityViewMode.Mode in [CityViewMode.Mode.CITY, CityViewMode.Mode.UNDERGROUND]:
			var native := CityGpuBuildContext.new()
			native.use_native = true
			var reference := CityGpuBuildContext.new()
			reference.use_native = false
			for center: Vector2i in [size / 2, Vector2i(size.x / 2, size.y - 160)]:
				var bounds := Rect2i(center - Vector2i(128, 64), Vector2i(257, 135))
				await _compare_builders(city, palette, sprites, bounds, view, mode, native, reference, 1)
				await _compare_builders(city, palette, sprites, bounds, view, mode, native, reference, 3)
			print("PASS: native region view %d mode %s" % [view, CityViewMode.key(mode)])
	await _catalog_cases(palette, graphics)
	await _dispatch_revision_case(palette, graphics)
	await _large_city_case(palette, graphics)
	print("PASS: native regions match GDScript pixels, draw order, foreground and warm revisions")
	quit()


func _compare_builders(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive, bounds: Rect2i,
		view: int, mode: CityViewMode.Mode, native: CityGpuBuildContext, reference: CityGpuBuildContext, revision: int,
		pipes := true, subways := true, mains := true) -> CityGpuRegionResult:
	var expected := CityGpuRegionRenderer.render(city, palette, sprites, bounds, view, mode, pipes, subways,
		reference, revision, -1, true, mains)
	var actual := CityGpuRegionRenderer.render(city, palette, sprites, bounds, view, mode, pipes, subways,
		native, revision, -1, true, mains)
	assert(expected.ok and actual.ok, "Native region failed: %s / %s" % [expected.error, actual.error])
	var expected_commands := _static_command_values(expected.occlusion_commands)
	var actual_commands := _static_command_values(actual.occlusion_commands)
	if expected_commands != actual_commands:
		for index in mini(expected_commands.size(), actual_commands.size()):
			if expected_commands[index] != actual_commands[index]:
				print("COMMAND DIFFERENCE %d expected=%s actual=%s" % [index, expected_commands[index], actual_commands[index]])
				break
	assert(expected_commands == actual_commands,
		"Native foreground differs (%d / %d commands)" % [expected_commands.size(), actual_commands.size()])
	var expected_image := CityGpuDrawList.paint(expected.gpu_draws, expected.bounds, expected.background)
	var actual_image := CityGpuDrawList.paint(actual.gpu_draws, actual.bounds, actual.background)
	assert(expected_image.get_data() == actual_image.get_data(), "Native region pixels differ")
	assert(expected.bounds == actual.bounds)
	if DisplayServer.get_name() != "headless":
		await _check_gpu_pixels(actual, expected_image)
	return actual


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
		var native := CityGpuBuildContext.new()
		native.use_native = true
		var reference := CityGpuBuildContext.new()
		reference.use_native = false
		await _compare_builders(city, palette, sprites, bounds, view, CityViewMode.Mode.CITY, native, reference, 1)
		# Change tile inputs without changing layout.
		city.tile_flags[city.index_of(60, 60)] ^= Sc2TileFlags.FLIPPED
		city.altitude_words[city.index_of(60, 61)] += 1
		city.document.find_chunk("XTRF").decoded_payload.fill(100 if view == 1 else 200)
		await _compare_builders(city, palette, sprites, bounds, view, CityViewMode.Mode.CITY, native, reference, 2)
		city.visible_altitude_levels = 6
		await _compare_builders(city, palette, sprites, bounds, view, CityViewMode.Mode.CITY, native, reference, 3)
		city.visible_altitude_levels = 32
		for switches in [[true, true, true], [false, true, true], [true, false, true], [true, true, false]]:
			await _compare_builders(city, palette, sprites, bounds, view, CityViewMode.Mode.UNDERGROUND, native, reference, 4,
				switches[0], switches[1], switches[2])
		print("PASS: native building and terrain catalog, traffic, cutaways and underground switches view %d" % view)
	# Each compass anchor and filtered display snapshot must reach native code.
	for rotation in 4:
		city.document.set_misc_u32(0x08, rotation)
		var displayed := CityViewFilter.surface_copy(city, { "water": false, "zones": false })
		var native := CityGpuBuildContext.new()
		native.use_native = true
		var reference := CityGpuBuildContext.new()
		reference.use_native = false
		await _compare_builders(displayed, palette, graphics.large_sprites, Rect2i(1800, 1100, 512, 512),
			2, CityViewMode.Mode.CITY, native, reference, 1)


func _dispatch_revision_case(palette: Sc2Palette, graphics: GraphicsPack) -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(512))
	var things := city.document.find_chunk("XTHG")
	var native := CityGpuBuildContext.new()
	native.use_native = true
	var reference := CityGpuBuildContext.new()
	reference.use_native = false
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
	var first := await _compare_builders(city, palette, graphics.large_sprites, bounds, 2,
		CityViewMode.Mode.CITY, native, reference, 1)
	for sprite in [1382, 1383, 1384]:
		assert(first.gpu_draws.any(func(draw: CityGpuDrawList.Draw) -> bool: return draw.sprite_id == sprite))
	# Moving only XTHG must remove the old dispatch draw until XTXT links its new cell.
	assert(things.write_decoded_byte(40 * CityState.THING_RECORD_SIZE + 3, 3))
	var moved := await _compare_builders(city, palette, graphics.large_sprites, bounds, 2,
		CityViewMode.Mode.CITY, native, reference, 2)
	assert(not moved.gpu_draws.any(func(draw: CityGpuDrawList.Draw) -> bool: return draw.sprite_id == 1382))
	assert(city.set_text_overlay_id(256, 256, 0))
	assert(city.set_text_overlay_id(259, 256, OverlayData.thing_id(40)))
	await _compare_builders(city, palette, graphics.large_sprites, bounds, 2,
		CityViewMode.Mode.CITY, native, reference, 3)
	assert(things.write_decoded_byte(40 * CityState.THING_RECORD_SIZE, 14))
	assert(city.set_text_overlay_id(257, 256, 0))
	await _compare_builders(city, palette, graphics.large_sprites, bounds, 2,
		CityViewMode.Mode.CITY, native, reference, 4)
	print("PASS: native dispatch sprites and extended overlay links refresh across revisions")


func _large_city_case(palette: Sc2Palette, graphics: GraphicsPack) -> void:
	var city := CityState.from_document(Sc2File.load_path("res://tests/fixtures/cities/generated-512.sc2x"))
	var native := CityGpuBuildContext.new()
	native.use_native = true
	var reference := CityGpuBuildContext.new()
	reference.use_native = false
	var center := CityIsometricRenderer.output_size_for_view(0, city.map_size) / 2
	for offset in [Vector2i.ZERO, Vector2i(512, 0), Vector2i.ZERO]:
		await _compare_builders(city, palette, graphics.small_medium_sprites, Rect2i(center + offset, Vector2i(257, 135)),
			0, CityViewMode.Mode.CITY, native, reference, 1)
