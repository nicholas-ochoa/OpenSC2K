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
	for id in range(112, 198):
		var resource := QueryInfo.general_name_resource_id(city, Vector2i.ZERO, id)
		print("Role %d: %s" % [id, str(names.strings.get(resource, "missing"))])
	var archive := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/LARGE.DAT")
	assert(archive.is_valid(), archive.parse_error)
	for entry in archive.entries:
		if entry.sprite_id < 1112 or entry.sprite_id > 1197:
			continue
		var cycles := {}
		var pixels: PackedInt32Array = entry.decode_indices().pixels
		for index in pixels:
			if index >= 171 and index < 239:
				cycles[index] = int(cycles.get(index, 0)) + 1
		if not cycles.is_empty() or entry.sprite_id == 1183:
			print("Sprite %d/%d: %dx%d, %d opaque pixels, cycle counts %s" % [entry.sprite_id, entry.duplicate_index, entry.width, entry.height, pixels.size() - pixels.count(-1), str(cycles)])
	quit()
