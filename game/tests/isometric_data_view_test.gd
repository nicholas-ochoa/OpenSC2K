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
				var image := CityDataView.value_image(city, mode)
				var scale: int = edge / image.get_width()
				check(roundi(image.get_pixel(IntegerMath.div_trunc(point.y, scale), IntegerMath.div_trunc(point.x, scale)).r * 255) == 173, "Texture retains far value and column-major coordinates")
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

	check_land_value_amounts()
	check_height_and_walls()
	await check_ui()
	await check_shader()
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
	var shared_mesh: ArrayMesh

	for index in CityDataView.MODES.size():
		var mode: String = CityDataView.MODES[index]
		main._on_view_menu(index + 2)
		check(main.overlay_mode == mode and main.map_view.data_view_mesh != null, "Menu opens isometric data view")

		if shared_mesh != null and mode != "height":
			check(main.map_view.data_view_mesh == shared_mesh, "All data modes share terrain geometry")

		shared_mesh = main.map_view.data_view_mesh
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
	check(main.map_view.data_view_mesh == old_mesh, "Changed simulation grid retains geometry")
	check(main.map_view.data_view_signature == CityDataView.signature(main.city, "land_value"), "Updated texture tracks current data revision")

	if DisplayServer.get_name() != "headless":
		check(roundi(main.map_view.data_value_texture.get_image().get_pixel(20, 20).r * 255) == 255, "Changed grid uploads current value")

	check(CityDataView.tile_text(main.city, "land_value", Vector2i(20, 20), true).contains("255 / 0xFF"), "Exact hover value")
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


func check_height_and_walls() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create())
	var colors: Dictionary = {}

	for level in 32:
		city.set_land_altitude(level, 0, level)
		check(CityDataView.value(city, "height", level, 0) == level, "Height uses the stored five bits")
		check(CityDataView.tile_text(city, "height", Vector2i(level, 0)) == "Height: Level %d of 32" % (level + 1), "Height has one-based friendly levels")
		check(CityDataView.tile_text(city, "height", Vector2i(level, 0), true).ends_with("(%d / 0x%02X)" % [level, level]), "Shift retains raw decimal and hex height")
		colors[CityDataView.color(level, "height").to_rgba32()] = true

	check(colors.size() == 32, "Every height has a distinct rainbow color")
	var heights := CityDataView.value_image(city, "height")
	check(roundi(heights.get_pixel(0, 31).r * 255) == 31, "Height texture retains highest land level")
	city.set_water_altitude(31, 0, 10)
	check(CityDataView.value(city, "height", 31, 0) == 31, "Height value does not use water level")
	check(CityDataView.tile_text(city, "pollution", Vector2i.ZERO) == "Pollution: Very low", "Numeric views use friendly labels by default")
	city.set_land_altitude(0, 0, 2)
	city.set_water_altitude(0, 0, 10)
	city.set_terrain_id(0, 0, 0x10)
	city.set_tile_flag(0, 0, 0x04, true)
	check(CityDataView.tile_text(city, "height", Vector2i.ZERO) == "Terrain: Level 3 of 32\nWater: Level 11 of 32", "Water-covered tooltip shows both levels")
	check(CityDataView.tile_text(city, "height", Vector2i.ZERO, true) == "Terrain: Level 3 of 32 (2 / 0x02)\nWater: Level 11 of 32 (10 / 0x0A)", "Shift shows both raw heights")
	var geometry_signature := CityDataView.geometry_signature(city, "height")
	city.set_tile_flag(0, 0, 0x40, true)
	check(CityDataView.geometry_signature(city, "height") == geometry_signature, "Power changes do not rebuild height geometry")
	var ground := CityDataView.surface_polygon(city, 0, 0, true)
	var water := CityIsometricRenderer.tile_polygon(city, 0, 0)
	check(ground[0].y - water[0].y == 8 * CityIsometricRenderer.ALTITUDE_STEP, "Seabed stays below separate water plane")
	var land_center := (ground[0] + ground[2]) * 0.5
	check(CityIsometricRenderer.screen_to_tile(city, land_center, true) == Vector2i.ZERO, "Height hover selects seabed through water")
	var water_center := (water[0] + water[2]) * 0.5
	check(CityIsometricRenderer.screen_to_tile(city, water_center, true) != Vector2i.ZERO, "Height hover ignores the water plane")
	var wet_mesh := CityDataView.create_mesh(city, "height", true)
	var wet_colors: PackedColorArray = wet_mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var transparent_vertices := 0

	for tint in wet_colors:
		if tint.a < 0.9:
			transparent_vertices += 1

	check(transparent_vertices == 4, "Water has one transparent tile at its surface")
	city.set_tile_flag(0, 0, 0x04, false)
	city.set_terrain_id(0, 0, 0)
	city.altitude_words.fill(16)
	var mesh := CityDataView.create_mesh(city, "height", true)
	check(mesh.surface_get_array_len(0) == (128 * 128 + 128 * 2) * 4, "Raised flat terrain draws only outside walls")
	var uvs: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	check(uvs[0] == Vector2.ZERO and uvs[4] == Vector2(0, 2), "Shader coordinates keep exact tile identity")

	var vertices: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# The left outer wall reaches ground at both ends, including beside a hidden wall.
	var found_outer_wall := false

	for first in range(0, vertices.size(), 4):
		if uvs[first] == Vector2(254, 0) and vertices[first + 2].y > vertices[first + 1].y + 100:
			check(vertices[first + 3].y > vertices[first].y + 100, "Outside wall has two full-height ends")
			found_outer_wall = true

	check(found_outer_wall, "Outside wall geometry is covered")


func check_shader() -> void:
	if DisplayServer.get_name() == "headless":
		return

	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var layer := MeshInstance2D.new()
	var shader := Shader.new()
	shader.code = CityDataView.GRID_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	layer.material = material
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2.ZERO, Vector2(64, 0), Vector2(64, 64), Vector2(0, 64)])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(1020, 1022), Vector2(1021, 1022), Vector2(1021, 1023), Vector2(1020, 1023)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	layer.mesh = mesh
	viewport.add_child(layer)
	material.set_shader_parameter("map_edge", 512.0)
	var values := Image.create(512, 512, false, Image.FORMAT_R8)

	for mode in CityDataView.MODES:
		var number := 31 if mode == "height" else (2 if mode in ["water", "power"] else 255)
		values.set_pixel(510, 511, Color(number / 255.0, 0, 0))
		material.set_shader_parameter("tile_values", ImageTexture.create_from_image(values))
		material.set_shader_parameter("value_colors", ImageTexture.create_from_image(CityDataView.color_image(mode)))
		await process_frame
		await RenderingServer.frame_post_draw
		var output := viewport.get_texture().get_image()
		var actual := output.get_pixel(32, 32)
		var expected := CityDataView.color(number, mode)
		check(absf(actual.r - expected.r) < 0.02 and absf(actual.g - expected.g) < 0.02 and absf(actual.b - expected.b) < 0.02, "GPU colors use the exact far tile: " + mode)
		check(output.get_pixel(0, 32).get_luminance() < actual.get_luminance() * 0.8, "GPU tile borders remain visible: " + mode)

	viewport.queue_free()
	await process_frame


func check_land_value_amounts() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create())
	var cases := {0: "Land Value: $1,000 (Very low)", 63: "Land Value: $64,000 (Low)",
		124: "Land Value: $125,000 (Medium)", 255: "Land Value: $256,000 (Very high)"}

	for raw in cases:
		var chunk := city.document.find_chunk("XVAL")
		var data := chunk.decoded_payload.duplicate()
		data[0] = raw
		chunk.set_decoded_payload(data)
		var query := QueryInfo.inspect(city, Vector2i.ZERO)
		check(QueryInfo.format_text(query).contains("$%d,000/acre" % (raw + 1)), "Tooltip dollar scale agrees with Query")
		check(CityDataView.tile_text(city, "land_value", Vector2i.ZERO) == cases[raw], "Land Value shows Query dollars and friendly band")
		check(CityDataView.tile_text(city, "land_value", Vector2i.ZERO, true) == cases[raw] + "  (%d / 0x%02X)" % [raw, raw], "Shift retains dollars and adds raw value")
