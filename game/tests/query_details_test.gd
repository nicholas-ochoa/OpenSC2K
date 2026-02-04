extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var palette := Sc2Palette.index_encoding()
	var sprites := Sc2SpriteArchive.load_path("res://../references/DATA/LARGE.DAT")
	assert(sprites.is_valid())
	var values := {"point": Vector2i(400, 300), "tile_id": 211, "sprite_id": 1211,
		"altitude_raw": 4660, "flags_raw": 128, "flag_names": PackedStringArray(["Powered"]),
		"microsim_id": 7, "microsim_label": "Station", "microsim": {"stat_0": 12, "stat_1": 500}}
	var rows := QueryPresentation.advanced_rows(values)
	assert(rows[0] == PackedStringArray(["Tile ID", "211", "", "0xD3"]))
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
		assert(preview.get_data().size() == 256 * 240 * 4)
		var opaque := 0
		var pixels := preview.get_data()
		for offset in range(3, pixels.size(), 4):
			opaque += int(pixels[offset] == 255)
		assert(opaque > 64, "Facility highlight disappeared after rotation")
		assert(facility_city.document.serialize().data == before)
		CityRotationCommand.apply(facility_city, false)
		selected_point = Vector2i(255 - selected_point.y, selected_point.x)
	var dialog := CityQueryDialog.new()
	root.add_child(dialog)
	dialog.show_query("Station", "Station", true, "Station\nOfficers: 42\nAdvanced tile data", "", "Station", null, "", values)
	assert(dialog.summary_rows.get_child_count() == 2)
	assert(dialog.summary_rows.get_child(0).get_child(0).get_child(1).text == "X: 400, Y: 300, Z: 20")
	assert(dialog.neighborhood_view.ZOOM == 3.0)
	assert(dialog.neighborhood_view.tooltip_text.is_empty())
	for color_name in ["font_color", "font_hovered_color", "font_selected_color", "font_hovered_selected_color"]:
		assert(dialog.details_grid.get_theme_color(color_name) == Color("202830"))
	assert(dialog.details_grid.get_root().get_child_count() == rows.size())
	dialog.queue_free()
	await process_frame
	if "--preview" in OS.get_cmdline_user_args():
		var main := (load("res://main.tscn") as PackedScene).instantiate()
		root.add_child(main)
		await process_frame
		main._load_city_unchecked(ProjectSettings.globalize_path("res://../references/CITIES/SYDNEY.SC2"))
		main._select_speed(GameSpeedController.Speed.PAUSED)
		var selected := Vector2i(64, 64)
		for x in range(50, 80):
			for y in range(50, 80):
				var tile: int = main.city.building_id(x, y)
				if tile >= 0x70 and tile < 0xb0:
					selected = Vector2i(x, y)
		var started := Time.get_ticks_usec()
		main._open_query(selected)
		print("QUERY presentation usec=%d" % (Time.get_ticks_usec() - started))
		root.title = "Query layout check"
		print("PREVIEW ready")
		return
	print("PASS: structured query values, coordinates, exact opacity, map edges and unchanged city bytes")
	quit()
