extends SceneTree
## List resource names, palette use, and duplicate dimensions.


func _initialize() -> void:
	var names := PeStringResource.load_ids("res://../references/SIMCITY2000/SIMCITY.EXE", QueryInfo.resource_string_ids())
	assert(names.ok, str(names.error))
	var city := CityState.new()
	city.document = Sc2File.new()
	city.altitude_words.resize(CityState.TILE_COUNT)
	city.terrain.resize(CityState.TILE_COUNT)
	city.buildings.resize(CityState.TILE_COUNT)
	city.tile_flags.resize(CityState.TILE_COUNT)

	for id in range(198, 256):
		var resource := QueryInfo.general_name_resource_id(city, Vector2i.ZERO, id)
		print("Role %d: %s; footprint %d" % [id, str(names.strings.get(resource, "missing")), DemolishStructures.structure_area(id)])

	for archive_name in ["LARGE.DAT", "SMALLMED.DAT", "SPECIAL.DAT"]:
		var archive := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/" + archive_name)
		assert(archive.is_valid(), archive.parse_error)

		for entry in archive.entries:
			if entry.sprite_id % 500 < 198 or entry.sprite_id % 500 > 255:
				continue

			var cycles := {}
			var pixels: PackedInt32Array = entry.decode_indices().pixels

			for index in pixels:
				if index >= 171 and index < 239:
					cycles[index] = int(cycles.get(index, 0)) + 1

			if not cycles.is_empty() or entry.sprite_id % 500 == 204:
				print("Sprite %d/%d: %dx%d, %d opaque pixels, cycle counts %s" % [entry.sprite_id, entry.duplicate_index, entry.width, entry.height, pixels.size() - pixels.count(-1), str(cycles)])

	var palette := Sc2Palette.load_bmp("res://../references/SIMCITY2000/BITMAPS/PAL_MSTR.BMP")
	assert(palette.is_valid())

	for index in range(224,234):
		print("Slow palette %d: %s" % [index,str(palette.color(index))])

	quit()
