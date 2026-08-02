extends SceneTree
## List resource roles, dimensions, and palette statistics.


func _initialize() -> void:
	var names := PeStringResource.load_ids("res://../references/SIMCITY2000/SIMCITY.EXE", QueryText.resource_string_ids())
	assert(names.ok, str(names.error))
	var city := CityState.new()
	city.document = Sc2File.new()
	city.altitude_words.resize(CityState.TILE_COUNT)
	city.terrain.resize(CityState.TILE_COUNT)
	city.buildings.resize(CityState.TILE_COUNT)
	city.tile_flags.resize(CityState.TILE_COUNT)

	for id in range(1, 14):
		var resource := QueryText.general_name_resource_id(city, Vector2i.ZERO, id)
		print("Role %d: %s" % [id, str(names.strings.get(resource, "missing"))])

	for archive_name in ["LARGE.DAT", "SMALLMED.DAT", "SPECIAL.DAT"]:
		var archive := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/" + archive_name)
		assert(archive.is_valid(), archive.parse_error)

		for entry in archive.entries:
			var base := entry.sprite_id % 500

			if not (base in range(1, 14) or base in range(291, 305) or base in range(354, 359) or base == 386 or base in range(468, 478)):
				continue

			var colors := {}
			var cycles := {}
			var pixels: PackedInt32Array = entry.decode_indices().pixels

			for index in pixels:
				if index < 0:
					continue

				colors[index] = int(colors.get(index, 0)) + 1

				if index >= 171 and index < 239:
					cycles[index] = int(cycles.get(index, 0)) + 1

			print("Sprite %d/%d: %dx%d, %d opaque, %d colors, cycles %s%s" % [entry.sprite_id, entry.duplicate_index, entry.width, entry.height, pixels.size() - pixels.count(-1), colors.size(), str(cycles), ", all counts " + str(colors) if colors.size() <= 5 else ""])

	quit()
