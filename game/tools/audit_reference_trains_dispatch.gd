extends SceneTree
## Print sprite bounds and palette counts.

@warning_ignore_start("integer_division")


func _initialize() -> void:
	if "--cities" in OS.get_cmdline_user_args():
		_scan_cities()
		quit()

		return

	for archive_name in ["LARGE.DAT", "SMALLMED.DAT", "SPECIAL.DAT"]:
		var archive := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/" + archive_name)
		assert(archive.is_valid(), archive.parse_error)

		for entry in archive.entries:
			var base := entry.sprite_id % 500

			if not (base in range(374, 379) or base in range(382, 385)):
				continue

			var pixels: PackedInt32Array = entry.decode_indices().pixels
			var colors := {}
			var bounds := {}

			for i in pixels.size():
				var index := int(pixels[i])

				if index < 0:
					continue

				colors[index] = int(colors.get(index, 0)) + 1
				var point := Vector2i(i % entry.width, i / entry.width)
				var box: Rect2i = bounds.get(index, Rect2i(point, Vector2i.ONE))
				bounds[index] = box.merge(Rect2i(point, Vector2i.ONE))

			print("Sprite %d: %dx%d, %d opaque, palette counts %s" % [entry.sprite_id, entry.width, entry.height, pixels.size() - pixels.count(-1), str(colors)])

			if base < 379:
				print("Palette bounds: ", bounds)
			else:
				for index in colors:
					if index in range(224, 232):
						print("Beacon %d bounds: %s" % [index, str(bounds[index])])

	print("Train variants: flat Y, horizontal curve, vertical curve, north-high Y grade, east-high X grade. Dispatch: Police, Fire, Military.")
	quit()


func _scan_cities() -> void:
	var counts := {}

	for folder in ["", "CITIES", "SCENARIO", "test-cities"]:
		var root := "res://../references/SIMCITY2000/" + str(folder)

		if not DirAccess.dir_exists_absolute(root):
			continue

		for name in DirAccess.get_files_at(root):
			if name.get_extension().to_upper() not in ["SC2", "SCN"]:
				continue

			var city := CityState.from_document(Sc2File.load_path(root.path_join(name)))
			assert(city.is_valid())

			for index in city.buildings.size():
				var tile := int(city.buildings[index])

				if tile not in range(59, 63):
					continue

				counts[tile] = int(counts.get(tile, 0)) + 1

				if int(counts[tile]) > 3:
					continue

				var point := Vector2i(index / 128, index % 128)
				var adjacent := []

				for direction in NetworkCommand.DIRECTIONS:
					var p: Vector2i = point + direction
					adjacent.append([city.building_id(p.x, p.y), city.terrain_id(p.x, p.y), city.land_altitude(p.x, p.y)])

				print("%s/%s %s: XBLD %d, XTER %d, altitude %d, N/E/S/W [building, terrain, altitude] %s" % [folder, name, point, tile, city.terrain[index], city.land_altitude(point.x, point.y), adjacent])

	print("Half-height rail counts: ", counts)
