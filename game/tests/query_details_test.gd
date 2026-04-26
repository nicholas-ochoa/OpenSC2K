extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var palette := Sc2Palette.index_encoding()
	var sprites := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/LARGE.DAT")
	assert(sprites.is_valid())
	var values := {"point": Vector2i(400, 300), "tile_id": 211, "sprite_id": 1211,
		"altitude_raw": 4660, "flags_raw": 128, "flag_names": PackedStringArray(["Powered"]),
		"microsim_id": 7, "microsim_label": "Station", "microsim": {"stat_0": 12, "stat_1": 500}}
	var rows := QueryPresentation.advanced_rows(values)
	assert(rows[0][1] == "211" and rows[0][3] == "0xD3")
	assert(rows[1][3] == "0x04BB")
	assert(rows[2] == PackedStringArray(["ALTM", "4660", "", "0x1234"]))
	assert(rows[7][1] == "400" and rows[8][1] == "300")
	var image := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 0.5, 0, 1))
	image.set_pixel(2, 0, Color.TRANSPARENT)
	var mask := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	mask.set_pixel(0, 0, image.get_pixel(0, 0))
	var faded := QueryNeighborhood.apply_opacity(image, mask)
	assert(faded.get_pixel(0, 0) == image.get_pixel(0, 0))
	assert(faded.get_data()[7] == 64 and faded.get_data()[11] == 0)
	assert(faded.get_pixel(1, 0).r == image.get_pixel(1, 0).r)

	for edge in [128, 256, 384, 512]:
		var city := CityState.from_document(EmptyCityTemplate.create(edge))
		var before: PackedByteArray = city.document.serialize().data

		for point in [Vector2i(edge / 2, edge / 2), Vector2i.ZERO, Vector2i(edge - 1, edge - 1)]:
			var preview := QueryNeighborhood.render(city, point, palette, sprites)
			assert(preview != null and preview.get_size() == QueryNeighborhood.SIZE)
			var opaque := 0
			var dimmed := 0
			var pixels := preview.get_data()

			for offset in range(3, pixels.size(), 4):
				opaque += int(pixels[offset] == 255)
				dimmed += int(pixels[offset] == 64)

			assert(opaque > 0 and dimmed > 0, "Wrong highlight alpha on the selected tile or its neighbors")

		assert(city.document.serialize().data == before)

	var facility_city := CityState.from_document(EmptyCityTemplate.create(256))
	var built := BuildingCommand.apply(facility_city, 13, 0, Vector2i(160, 160), SimLfsrRandom.new(1), SimRandom.new(1))
	assert(built.ok)
	var selected_point := Vector2i(160, 160)

	for rotation in 4:
		var before: PackedByteArray = facility_city.document.serialize().data
		var preview := QueryNeighborhood.render(facility_city, selected_point, palette, sprites)
		assert(preview.get_data().size() == QueryNeighborhood.SIZE.x * QueryNeighborhood.SIZE.y * 4)
		var opaque := 0
		var pixels := preview.get_data()

		for offset in range(3, pixels.size(), 4):
			opaque += int(pixels[offset] == 255)

		assert(opaque > 64, "Facility highlight disappeared after rotation")
		assert(facility_city.document.serialize().data == before)
		CityRotationCommand.apply(facility_city, false)
		selected_point = Vector2i(255 - selected_point.y, selected_point.x)

	var dialog := preload("res://src/ui/tools/city_query_dialog.tscn").instantiate() as CityQueryDialog
	root.add_child(dialog)
	dialog.show_query("Station", "Station", true, "Station\nOfficers: 42\nAdvanced tile data", "", values)
	assert(dialog.summary_rows.get_child_count() == 2)
	var coordinates: String = dialog.summary_rows.get_child(0).get_child(0).get_child(1).text
	assert(coordinates.contains("400") and coordinates.contains("300") and coordinates.contains("20"))

	assert(dialog.details_grid.get_root().get_child_count() == rows.size())
	assert(dialog.tabs.is_tab_hidden(dialog.things_grid.get_index()))
	var with_thing := values.duplicate(true)
	with_thing.things = [{"record": 1, "type": 1, "type_name": "Airplane", "direction": 2, "direction_name": "East", "state": 0, "x": 400, "y": 300, "z": 12, "px": 0, "py": 0, "dx": 1, "dy": 0, "label": 0, "goal": 0}]
	dialog.show_query("Station", "Station", true, "Station", "", with_thing)
	assert(not dialog.tabs.is_tab_hidden(dialog.things_grid.get_index()))
	assert(dialog.things_grid.get_root().get_child_count() == QueryPresentation.thing_rows(with_thing).size())
	assert(QueryPresentation.advanced_rows(with_thing) == rows)
	var thing_rows := QueryPresentation.thing_rows(with_thing)
	assert(thing_rows[1][1] == "1" and thing_rows[1][3] == "0x01")
	assert(thing_rows[2][1] == "2" and thing_rows[2][3] == "0x02")
	dialog.tabs.current_tab = dialog.things_grid.get_index()
	dialog.show_query("Station", "Station", true, "Station", "", values)
	assert(dialog.tabs.current_tab == 0 and dialog.tabs.is_tab_hidden(dialog.things_grid.get_index()))
	var animated_image := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	animated_image.set_pixel(0, 0, Color8(171, 171, 171, 255))
	animated_image.set_pixel(1, 0, Color8(180, 180, 180, 64))
	var indexed_texture := ImageTexture.create_from_image(animated_image)
	dialog.neighborhood_view.texture = indexed_texture
	dialog.neighborhood_view.show()
	dialog.neighborhood_view.configure_animation(palette, 0)
	var initial_colors := palette.animation_image(dialog.neighborhood_view.ticks).get_data()
	dialog.neighborhood_view._process(0.2)
	assert(dialog.neighborhood_view.ticks == 1)
	assert(palette.animation_image(dialog.neighborhood_view.ticks).get_data() != initial_colors)
	assert(indexed_texture.get_image().get_data() == animated_image.get_data(), "Animation changed palette indices or highlight alpha")
	dialog.hide()
	dialog.neighborhood_view._process(0.4)
	assert(dialog.neighborhood_view.ticks == 1, "Hidden preview does not animate")
	dialog.close_query()
	assert(not dialog.neighborhood_view.is_processing())
	dialog.queue_free()
	await process_frame

	if "--preview" in OS.get_cmdline_user_args():
		var main := (load("res://main.tscn") as PackedScene).instantiate()
		preload("res://tests/support/app_fixture.gd").configure(main)
		root.add_child(main)
		await process_frame
		main._load_city_unchecked(ProjectSettings.globalize_path("res://../references/SIMCITY2000/CITIES/SYDNEY.SC2"))
		main._select_speed(GameSpeedController.Speed.PAUSED)
		var selected := Vector2i(64, 64)

		for x in range(50, 80):
			for y in range(50, 80):
				var tile: int = main.city.building_id(x, y)

				if tile >= 0x70 and tile < 0xb0:
					selected = Vector2i(x, y)

		if "--thing" in OS.get_cmdline_user_args():
			for x in main.city.map_size:
				for y in main.city.map_size:
					if not CityIsometricRenderer.moving_thing_visual(main.city, x, y).is_empty():
						selected = Vector2i(x, y)

		var started := Time.get_ticks_usec()
		main._open_query(selected)
		print("QUERY presentation usec=%d" % (Time.get_ticks_usec() - started))
		root.title = "Query layout check"
		print("PREVIEW ready")

		return

	print("PASS: structured query values, coordinates, exact opacity, map edges and unchanged city bytes")
	quit()
