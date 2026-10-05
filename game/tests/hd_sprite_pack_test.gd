extends SceneTree
## HD sprite packs: manifest rules, how the art binds to indexed sprites, and the
## native region quads that show it.

@warning_ignore_start("integer_division")

var _root := ""


func _initialize() -> void:
	_root = "user://hd-sprite-pack-test-%d" % Time.get_ticks_usec()
	assert(DirAccess.make_dir_recursive_absolute(_root) == OK)
	var large := FixtureGraphics.pack().large_sprites
	var road := large.find_sprite(1029)
	var tower := large.find_sprite(1112)
	var road_size := Vector2i(road.width, road.height)
	_write_png("road.png", road_size * 4, Color.CORNFLOWER_BLUE)
	_write_png("tower.png", Vector2i(tower.width, tower.height) * 2, Color.ORANGE)
	_write_png("road.strip.png", Vector2i(road_size.x * 4, road_size.y * 4 * 3), Color.TOMATO)

	var manifest := {
		"format": "opensc2k-hd-sprites", "version": 1, "name": "Test HD",
		"redraw_small_highway_ground": true,
		"sprites": [
			{ "id": 1029, "png": "road.png", "logical_size": [road.width, road.height], "display_height": road.height + 3,
				"animation": { "png": "road.strip.png", "frames": 3, "fps": 5 } },
			{ "id": 1112, "png": "tower.png", "logical_size": [tower.width, tower.height] },
			# Another graphics pack can have another size. This record does not apply.
			{ "id": 1113, "png": "tower.png", "logical_size": [3, 3] },
		],
	}

	var pack := _load(manifest)
	assert(pack.error.is_empty(), pack.error)
	assert(pack.pack_name == "Test HD" and pack.redraw_small_highway_ground)
	assert(pack.sprites[1029].height == road.height + 3 and pack.sprites[1029].frames == 3 and pack.sprites[1029].fps == 5)
	assert(pack.sprites[1112].animation == null and pack.sprites[1112].height == tower.height)

	# The art binds only where the indexed size matches. The copy shares the entries.
	var shown := pack.apply_to(large)
	assert(shown != large and shown.entries_by_id[1029] == large.entries_by_id[1029])
	assert(shown.high_resolution.keys() == [1029, 1112])
	assert(shown.redraw_small_highway_ground and large.high_resolution.is_empty())
	assert(pack.apply_to(FixtureGraphics.pack().small_medium_sprites) == FixtureGraphics.pack().small_medium_sprites)
	assert(IsometricGeometry.maximum_sprite_size(shown).y >= road.height + 3)

	# A later archive with a sprite of the same ID removes the art of that ID.
	var replacement := Sc2SpriteArchive.new()
	replacement.entries.append(large.entries_by_id[1112])
	replacement.entries_by_id[1112] = large.entries_by_id[1112]
	assert(Sc2SpriteArchive.combine([shown, replacement]).high_resolution.keys() == [1029])

	_rejects(manifest, func(m: Dictionary) -> void: m.sprites.append(m.sprites[1].duplicate()), "occurs more than one time")
	_rejects(manifest, func(m: Dictionary) -> void: m.sprites[0].display_height = 1, "display_height")
	_rejects(manifest, func(m: Dictionary) -> void: m.sprites[0].animation.fps = 6, "rate")
	_rejects(manifest, func(m: Dictionary) -> void: m.sprites[0].animation.frames = 4, "stack frames")
	_rejects(manifest, func(m: Dictionary) -> void: m.sprites[1].png = "../tower.png", "parent")
	_rejects(manifest, func(m: Dictionary) -> void: m.sprites[1].png = "missing.png", "Cannot read")
	_rejects(manifest, func(m: Dictionary) -> void: m.format = "opensc2k-graphics", "format")
	_rejects(manifest, func(m: Dictionary) -> void: m.sprites = [], "nonempty")

	# Only the sprites of one view go to its native builder.
	var request := CityGpuBuildContext.artwork_request(shown, 1000)
	assert(request.hd_sprites.keys() == [1029, 1112] and request.hd_animations.keys() == [1029])
	assert(request.hd_heights[1029] == road.height + 3 and request.hd_frames[1029] == 3 and request.hd_fps[1029] == 5)
	assert(CityGpuBuildContext.artwork_request(shown, 500).is_empty())

	_check_region_quads(shown)
	_check_export(shown)
	_check_cpu_region(shown)
	print("PASS: HD sprite packs")
	quit()


# A GPU region shows the art in the place of its sprites, with draw tags in the
# vertex colors. The test art has no underground sprites, so the underground
# view stays indexed.
func _check_region_quads(sprites: Sc2SpriteArchive) -> void:
	var city := CityState.from_document(Sc2File.load_path("res://tests/fixtures/cities/generated-128.SC2"))
	var palette := Sc2Palette.index_encoding()
	var size := CityIsometricRenderer.output_size_for_view(2, city.map_size)
	var bounds := Rect2i(size / 2 - Vector2i(512, 512), Vector2i(1024, 1024))

	for mode: CityViewMode.Mode in [CityViewMode.Mode.CITY, CityViewMode.Mode.UNDERGROUND]:
		var context := CityGpuBuildContext.new()
		var result := context.render(city, palette, sprites, bounds, 2, mode, true, true, 0, -1, true, true)
		assert(result.ok, result.error)
		var colors: PackedColorArray = result.gpu_arrays[Mesh.ARRAY_COLOR]
		var vertices: PackedVector2Array = result.gpu_arrays[Mesh.ARRAY_VERTEX]
		assert(colors.size() == vertices.size())
		var tags := {}

		for index in range(0, colors.size(), 4):
			tags[roundi(colors[index].r * 255.0)] = true

		if mode == CityViewMode.Mode.CITY:
			assert(tags.has(2) or tags.has(65), "The art of a road or a tower is drawn")
			assert(tags.has(255), "Sprites without art stay indexed")
			assert(context.atlas.get_format() == Image.FORMAT_RGBA8)
		else:
			assert(tags.keys() == [255])


# A whole-city image with HD art has `factor` pixels for each view pixel, and
# shows the art where the city has its sprites.
func _check_export(sprites: Sc2SpriteArchive) -> void:
	var city := CityState.from_document(Sc2File.load_path("res://tests/fixtures/cities/generated-128.SC2"))
	var palette := FixtureGraphics.pack().palette
	var size := CityIsometricRenderer.output_size_for_view(2, city.map_size)
	var options := ScurkCityOutput.Options.new()
	options.artwork_factor = 2
	var rendered := ScurkCityOutput.render(city, palette, sprites, 2, options)
	assert(rendered.ok, rendered.error)
	assert(rendered.image.get_size() == size * 2)
	var art_pixels := 0

	for y in range(0, rendered.image.get_height(), 7):
		for x in range(0, rendered.image.get_width(), 7):
			var color := rendered.image.get_pixel(x, y)

			if color.is_equal_approx(Color.CORNFLOWER_BLUE) or color.is_equal_approx(Color.ORANGE):
				art_pixels += 1

	assert(art_pixels > 0, "The export shows the HD art")
	options.artwork_factor = 0
	assert(ScurkCityOutput.render(city, palette, sprites, 2, options).image.get_size() == size)


# A CPU region has an HD image at ARTWORK_FACTOR pixels for each view pixel,
# beside its indexed image, when it has an artwork palette.
func _check_cpu_region(sprites: Sc2SpriteArchive) -> void:
	var city := CityState.from_document(Sc2File.load_path("res://tests/fixtures/cities/generated-128.SC2"))
	var size := CityIsometricRenderer.output_size_for_view(2, city.map_size)
	var bounds := Rect2i(size / 2 - Vector2i(128, 128), Vector2i(256, 256))

	for mode: CityViewMode.Mode in [CityViewMode.Mode.CITY, CityViewMode.Mode.UNDERGROUND]:
		var result := CityRegionRenderer.render(city, Sc2Palette.index_encoding(), sprites, bounds, 2, mode, true, true, true,
			null, 0, true, FixtureGraphics.pack().palette)
		assert(result.ok, result.error)
		assert(result.image.get_size() == bounds.size)
		assert(result.artwork_image.get_size() == bounds.size * CityRegionRenderer.ARTWORK_FACTOR)

	var indexed := CityRegionRenderer.render(city, Sc2Palette.index_encoding(), sprites, bounds, 2)
	assert(indexed.ok and indexed.artwork_image == null)


func _load(manifest: Dictionary) -> HdSpritePack:
	var file := FileAccess.open(_root.path_join("pack.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()

	return HdSpritePack.load_root(_root.path_join("pack.json"))


func _rejects(manifest: Dictionary, change: Callable, message: String) -> void:
	var changed := manifest.duplicate(true)
	change.call(changed)
	var pack := _load(changed)
	assert(pack.error.contains(message), "%s: %s" % [message, pack.error])
	assert(pack.sprites.is_empty())


func _write_png(file_name: String, size: Vector2i, color: Color) -> void:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	assert(image.save_png(_root.path_join(file_name)) == OK)
