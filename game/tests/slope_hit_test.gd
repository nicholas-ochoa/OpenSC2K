extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var checked_raised := 0

	for edge in [128, 256, 384, 512]:
		var city := CityState.from_document(EmptyCityTemplate.create(edge))
		var point := Vector2i(edge - 8, edge - 8)
		city.set_land_altitude(point.x, point.y, 31)

		for shape in range(14):
			city.set_terrain_id(point.x, point.y, shape)
			var polygon := CityIsometricRenderer.terrain_surface_polygon(city, point.x, point.y)
			var flat := CityIsometricRenderer.tile_polygon(city, point.x, point.y)
			var center := Vector2.ZERO

			for corner in polygon:
				center += corner / 4.0

			for corner in polygon:
				var sample := corner.lerp(center, 0.3)

				if not Geometry2D.is_point_in_polygon(sample, polygon):
					continue

				assert(CityIsometricRenderer.screen_to_tile(city, sample) == point, "Slope %d at map size %d, point %s" % [shape, edge, sample])

				if not Geometry2D.is_point_in_polygon(sample, flat):
					checked_raised += 1

		city.set_terrain_id(point.x, point.y, 0x10)
		assert(CityIsometricRenderer.terrain_surface_polygon(city, point.x, point.y) == CityIsometricRenderer.tile_polygon(city, point.x, point.y), "Water keeps its flat selectable surface")

	assert(checked_raised > 80, "Exercise the raised regions missed by a flat diamond")
	print("PASS: slope hit testing covers every dry slope and all four map sizes")

	if "--preview" in OS.get_cmdline_user_args():
		var city := CityState.from_document(EmptyCityTemplate.create(128))

		for x in range(58, 71):
			for y in range(58, 71):
				city.set_land_altitude(x, y, 10)

		city.set_terrain_id(64, 64, 9)
		var path := "user://slope-hit-preview.sc2"
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(city.document.serialize().data)
		file.close()
		var main := (load("res://main.tscn") as PackedScene).instantiate()
		root.add_child(main)
		await process_frame
		main._load_city_unchecked(ProjectSettings.globalize_path(path))
		main._select_speed(GameSpeedController.Speed.PAUSED)
		main.map_view.center_on_tile(Vector2i(64, 64))
		main._select_tool_group(16)
		await process_frame
		var polygon := CityIsometricRenderer.terrain_surface_polygon(main.city, 64, 64)
		var sample := polygon[0] + Vector2(0, 3)
		var scale: float = main.map_view._view_scale()
		var local: Vector2 = sample * scale + main.map_view._draw_offset(scale)
		print("SLOPE click viewport=%s expected=(64,64)" % (local + main.map_view.global_position))
		root.title = "Slope hover check"

		return

	quit()
