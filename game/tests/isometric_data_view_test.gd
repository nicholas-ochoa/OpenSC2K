extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _run() -> void:
	for edge in Sc2File.MAP_SIZES:
		for native in [false, true]:
			var doc := EmptyCityTemplate.create(edge)
			if native:
				check(doc.enable_full_resolution_maps(), "Native fixture")
			var city := CityState.from_document(doc)
			var point := Vector2i(edge - 4, edge - 4)
			for mode in CityDataView.CHUNKS:
				var chunk := doc.find_chunk(CityDataView.CHUNKS[mode])
				var data := chunk.decoded_payload.duplicate()
				data[CityDataGrid.index(data, edge, point.x, point.y)] = 173
				chunk.set_decoded_payload(data)
				check(CityDataView.value(city, mode, point.x, point.y) == 173, "Far-tile value")
				check(CityDataView.value(city, mode, point.x, point.y + 1) == (0 if native else 173), "Native/legacy resolution")
			city.set_tile_flag(point.x, point.y, 0x80, true)
			check(CityDataView.value(city, "power", point.x, point.y) == 1, "Powerable but not powered")
			city.set_tile_flag(point.x, point.y, 0x40, true)
			check(CityDataView.value(city, "power", point.x, point.y) == 2, "Powered")
			city.set_tile_flag(point.x, point.y, 0x20, true)
			check(CityDataView.value(city, "water", point.x, point.y) == 1, "Piped but not watered")
			city.set_tile_flag(point.x, point.y, 0x10, true)
			check(CityDataView.value(city, "water", point.x, point.y) == 2, "Watered")
			var before: PackedByteArray = doc.serialize().data
			var mesh := CityDataView.create_mesh(city, "land_value")
			var arrays := mesh.surface_get_arrays(0)
			check(arrays[Mesh.ARRAY_VERTEX].size() == edge * edge * 4, "All tile geometry")
			check(arrays[Mesh.ARRAY_INDEX].size() == edge * edge * 6, "All tile triangles")
			check(arrays[Mesh.ARRAY_TEX_UV].size() == edge * edge * 4, "Every tile has border coordinates")
			check(doc.serialize().data == before, "Rendering does not change city bytes")
			print("PASS: data mesh %d native=%s" % [edge, native])
	await check_ui()
	print("Isometric data views: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func check_ui() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var doc := EmptyCityTemplate.create()
	doc.enable_full_resolution_maps()
	main.map_view.zoom_factor = 0.25
	check(main._activate_document(doc), "Activate fixture")
	main._select_speed(GameSpeedController.Speed.PAUSED)
	var before: PackedByteArray = doc.serialize().data
	main._select_tool_group(16)
	var center: Vector2 = main.map_view.source_center
	for index in CityDataView.MODES.size():
		var mode: String = CityDataView.MODES[index]
		main._on_view_menu(index + 2)
		check(main.overlay_mode == mode and main.map_view.data_view_mesh != null, "Menu opens isometric data view")
		check(main.view_menu.get_popup().is_item_checked(index + 2), "Selected menu check")
		check(main.city_toolbar.data_view_input.selected == index + 1, "Sidebar follows view menu")
		check(Vector2i(main.map_view.city_texture.get_size()) == CityIsometricRenderer.output_size_for_view(2, 128), "Native isometric extent")
		check(main.map_view.source_center == center, "Switch preserves camera")
		check(main.map_view.edit_enabled, "Query stays enabled")
		var mesh: ArrayMesh = main.map_view.data_view_mesh
		main._refresh_map(false)
		check(main.map_view.data_view_mesh == mesh, "Unchanged data reuses mesh")
		check(main.map_view.data_view_layer.visible and main.map_view.data_view_layer.material != null, "Grid shader is active")
		check(doc.serialize().data == before, "View changes preserve saved city")
	main.city_toolbar.data_view_input.item_selected.emit(1)
	check(main.overlay_mode == "land_value", "Sidebar opens data view")
	var old_mesh: ArrayMesh = main.map_view.data_view_mesh
	var data := doc.find_chunk("XVAL").decoded_payload.duplicate()
	data[20 * 128 + 20] = 255
	doc.find_chunk("XVAL").set_decoded_payload(data)
	main._refresh_map(false)
	check(main.map_view.data_view_mesh != old_mesh, "Changed simulation grid refreshes mesh")
	check(CityDataView.tile_text(main.city, "land_value", Vector2i(20, 20)).ends_with("255"), "Exact hover value")
	main._select_tool_group(17)
	check(main.overlay_mode == "land_value" and main.map_view.edit_enabled, "Center preserves data view")
	main._set_overlay("underground")
	check(main.map_view.data_view_mesh == null and main.map_view.data_view_mode.is_empty(), "Underground restores normal renderer")
	main._set_overlay("crime")
	main._select_tool_group(0)
	check(main.overlay_mode == "city", "Demolish leaves analysis view for surface editing")
	main._set_overlay("crime")
	main._select_tool_group(6)
	check(main.overlay_mode == "city" and main.map_view.data_view_mesh == null, "Construction restores city view")
	main.queue_free()
	await process_frame
