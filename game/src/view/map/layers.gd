class_name CityMapLayers
extends CityMapConstants


var map: CityMapControl


func _init(control: CityMapControl) -> void:
	map = control


func set_data_view(value: CityState, mode: CityViewMode.Mode) -> void:
	var mode_changed := map.data_view_mode != mode
	var signature := CityDataView.signature(value, mode)
	var geometry_signature := CityDataView.geometry_signature(value, mode)

	if map.data_geometry_signature != geometry_signature:
		map.data_view_mesh = CityDataView.create_mesh(value, mode, true)
		map.data_geometry_signature = geometry_signature

	if map.data_view_layer == null:
		map.data_view_layer = MeshInstance2D.new()
		map.data_view_layer.name = "TileDataLayer"
		map.data_view_layer.show_behind_parent = true
		var shader := Shader.new()
		shader.code = CityDataView.GRID_SHADER
		var grid_material := ShaderMaterial.new()
		grid_material.shader = shader
		map.data_view_layer.material = grid_material
		map.add_child(map.data_view_layer)

	var material := map.data_view_layer.material as ShaderMaterial
	material.set_shader_parameter("map_edge", float(value.map_size))

	if map.data_view_signature != signature:
		var image := CityDataView.value_image(value, mode)

		if map.data_value_texture != null and Vector2i(map.data_value_texture.get_size()) == image.get_size():
			map.data_value_texture.update(image)
		else:
			map.data_value_texture = ImageTexture.create_from_image(image)

		material.set_shader_parameter("tile_values", map.data_value_texture)
		map.data_view_signature = signature

	if map.data_view_mode != mode:
		material.set_shader_parameter("value_colors", ImageTexture.create_from_image(CityDataView.color_image(mode)))

	map.data_view_mode = mode
	map.data_view_layer.mesh = map.data_view_mesh
	map.presentation.set_city_view(value, CityMapSource.new(Renderer.output_size_for_view(Renderer.VIEW_LARGE, value.map_size)))

	if mode_changed and map.hover_tile.x >= 0:
		map.hover_tile = map.camera._tile_at(map.get_local_mouse_position())

	map.queue_redraw()


func clear_data_view() -> void:
	if map.data_view_mode == CityViewMode.Mode.NONE:
		return

	map.data_view_mode = CityViewMode.Mode.NONE
	map.data_view_mesh = null

	if map.data_view_layer != null:
		map.data_view_layer.hide()
		map.data_view_layer.mesh = null

	map.data_view_signature.clear()
	map.data_geometry_signature.clear()
	map.data_value_texture = null

	if map._dynamic_canvas != null:
		map._dynamic_canvas.show()

	_sync_base_layer()
	map.queue_redraw()


func _draw_data_view(scale: float, offset: Vector2) -> void:
	if map.hover_tile.x >= 0:
		var outline := CityDataView.surface_polygon(map.city, map.hover_tile.x, map.hover_tile.y, map.data_view_mode == CityViewMode.Mode.HEIGHT)

		for index in outline.size():
			outline[index] = offset + outline[index] * scale

		if not outline.is_empty():
			outline.append(outline[0])
			map.draw_polyline(outline, Color.WHITE, 1.0)

	_draw_data_key()

	if map.hover_tile.x >= 0:
		var text := CityDataView.tile_text(map.city, map.data_view_mode, map.hover_tile, map._shift_pressed)
		var font := ThemeDB.fallback_font
		var lines := text.split("\n")
		var width := 0.0

		for line in lines:
			width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)

		var extent := Vector2(width + 20, lines.size() * 24 + 8)
		var position := map.get_local_mouse_position() + Vector2(18, 24)
		position.x = clampf(position.x, 4, maxf(4, map.size.x - extent.x - 4))
		position.y = clampf(position.y, 4, maxf(4, map.size.y - extent.y - 4))
		map.draw_style_box(_data_legend_box(), Rect2(position, extent))

		for index in lines.size():
			map.draw_string(font, position + Vector2(10, 22 + index * 24), lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
					map.get_theme_color("font_color", "MapLegend"))


func _draw_data_key() -> void:
	var font := ThemeDB.fallback_font
	var origin := data_key_origin()
	map.draw_style_box(_data_legend_box(), Rect2(origin, Vector2(320, 116 if map.data_view_mode == CityViewMode.Mode.HEIGHT else 96)))
	var title: String = CityDataView.TITLES[CityViewMode.DATA_MODES.find(map.data_view_mode)]
	map.draw_string(font, origin + Vector2(12, 24), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, map.get_theme_color("font_color", "MapLegend"))

	if map.data_view_mode in [CityViewMode.Mode.WATER, CityViewMode.Mode.POWER]:
		for index in 3:
			var position := origin + Vector2(12 + index * 100, 38)
			map.draw_rect(Rect2(position, Vector2(88, 18)), CityDataView.color(index, map.data_view_mode))
			map.draw_string(font, position + Vector2(0, 38), ["No link", "No supply", "Supplied"][index], HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
					map.get_theme_color("font_color", "MapLegend"))
	else:
		for index in 32:
			var number := index if map.data_view_mode == CityViewMode.Mode.HEIGHT else roundi(index * 255.0 / 31)
			map.draw_rect(Rect2(origin + Vector2(12 + index * 9.25, 38), Vector2(9.25, 20)), CityDataView.color(number, map.data_view_mode))

		if map.data_view_mode == CityViewMode.Mode.HEIGHT:
			map.draw_rect(Rect2(origin + Vector2(12, 96), Vector2(18, 10)), Color(0.35, 0.75, 1.0, 0.65))
			map.draw_string(font, origin + Vector2(38, 106), "Water surface (transparent)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
					map.get_theme_color("font_color", "MapLegend"))

		var low := "Level 1" if map.data_view_mode == CityViewMode.Mode.HEIGHT else "Very low"
		var high := "Level 32" if map.data_view_mode == CityViewMode.Mode.HEIGHT else "Very high"
		map.draw_string(font, origin + Vector2(12, 80), low, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, map.get_theme_color("font_color", "MapLegend"))
		var high_width := font.get_string_size(high, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		map.draw_string(font, origin + Vector2(308 - high_width, 80), high, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, map.get_theme_color("font_color", "MapLegend"))


func data_key_origin() -> Vector2:
	if map.data_view_mode == CityViewMode.Mode.HEIGHT:
		# match trip query: anchor inside the map area, clear of the sidebar
		var workspace := map.get_parent()
		if workspace != null:
			var map_space := workspace.get_node_or_null("Page/Content/MapSpace") as Control
			if map_space != null:
				return map_space.global_position - map.global_position + Vector2(12, 12)
		return Vector2(12, 12)
	return Vector2(maxf(8, map.size.x - 332), maxf(8, map.size.y - 108))


func _data_legend_box() -> StyleBoxFlat:
	return map.get_theme_stylebox("panel", "MapLegend") as StyleBoxFlat


func _ensure_base_layer() -> void:
	if map._base_layer != null:
		return

	map._base_layer = TextureRect.new()
	map._base_layer.name = "CityBaseLayer"
	map._base_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map._base_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map._base_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map._base_layer.stretch_mode = TextureRect.STRETCH_SCALE
	map._base_layer.show_behind_parent = true
	map._price_layer = Node2D.new()
	map._price_layer.name = "SelectionPriceLayer"
	map._price_layer.z_index = PRICE_LAYER_Z_INDEX
	map._price_layer.draw.connect(map.selection._draw_selection_price)
	map.add_child(map._price_layer)
	map._foreground_palette_material = CityForegroundPalette.create_material(map.animated_palette_texture)
	map.material = map._foreground_palette_material
	map._palette_shader = Shader.new()
	map._palette_shader.code = PALETTE_CYCLE_SHADER
	map._base_material = _new_palette_material()
	map._base_layer.material = map._base_material
	map.add_child(map._base_layer)
	map._dynamic_canvas = DynamicSpriteCanvas.new()
	map._dynamic_canvas.name = "DynamicSpriteCanvas"
	map._dynamic_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map._dynamic_canvas.show_behind_parent = true
	map._dynamic_material = CityMapMovingOcclusion.create_sprite_material()
	map._dynamic_canvas.material = map._dynamic_material
	map.add_child(map._dynamic_canvas)
	map._dynamic_canvas.set_visuals(
		map.dynamic_sprites, map.camera._view_scale(), map.camera._draw_offset(map.camera._view_scale())
	)
	_sync_base_layer()


func _sync_base_layer() -> void:
	_sync_base_nodes()
	map.moving_occlusion.sync()


func _sync_base_nodes() -> void:
	if not map.data_view_mode == CityViewMode.Mode.NONE:
		if map.data_view_layer != null:
			var data_scale := map.camera._view_scale()
			map.data_view_layer.position = map.camera._draw_offset(data_scale)
			map.data_view_layer.scale = Vector2.ONE * data_scale
			map.data_view_layer.show()

		if map._base_layer != null:
			map._base_layer.hide()

		if map._dynamic_canvas != null:
			map._dynamic_canvas.hide()

		return

	if map._base_layer == null:
		return

	if map.city_source == null:
		map._base_layer.hide()

		return

	var scale := map.camera._view_scale()

	if map._tiled_source != map.city_source:
		for tile in map._tile_layers:
			tile.queue_free()

		map._tile_layers.clear()
		var retained_meshes := {}

		for mesh in map._mesh_layers:
			retained_meshes[mesh.get_meta("source_position")] = mesh

		map._mesh_layers.clear()
		map._tiled_source = map.city_source

		for entry in map.city_source.tiles:
			var tile := TextureRect.new()
			tile.texture = entry.texture
			tile.set_meta("source_position", entry.position)
			tile.set_meta("source_size", entry.size)
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tile.material = map._base_material
			map._base_layer.add_child(tile)
			map._tile_layers.append(tile)

		for entry in map.city_source.meshes:
			var mesh: MeshInstance2D = retained_meshes.get(entry.position)

			if mesh == null:
				mesh = MeshInstance2D.new()
				map._base_layer.add_child(mesh)
			else:
				retained_meshes.erase(entry.position)

				if mesh.mesh == entry.mesh and mesh.texture == entry.texture and int(mesh.get_meta("divisor")) == entry.divisor:
					map._mesh_layers.append(mesh)
					continue

			mesh.position = Vector2(entry.position) * scale
			mesh.scale = Vector2.ONE * scale * entry.divisor

			if mesh.mesh != entry.mesh:
				mesh.mesh = entry.mesh

			if mesh.texture != entry.texture:
				mesh.texture = entry.texture

			mesh.set_meta("source_position", entry.position)
			mesh.set_meta("divisor", entry.divisor)
			mesh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			mesh.material = map._base_material
			map._mesh_layers.append(mesh)
		for mesh: MeshInstance2D in retained_meshes.values():
			mesh.hide()
			mesh.queue_free()

	map._base_layer.texture = map.city_source.texture

	for tile in map._tile_layers:
		tile.position = Vector2(tile.get_meta("source_position")) * scale
		tile.size = Vector2(tile.get_meta("source_size")) * scale

	if not is_equal_approx(map._mesh_view_scale, scale):
		for mesh in map._mesh_layers:
			mesh.position = Vector2(mesh.get_meta("source_position")) * scale
			mesh.scale = Vector2.ONE * scale * int(mesh.get_meta("divisor"))

		map._mesh_view_scale = scale

	map._base_layer.position = map.camera._draw_offset(scale)
	map._base_layer.size = Vector2(map.city_source.size) * scale
	map._base_layer.show()
	_sync_base_material()
	_sync_dynamic_canvas()


func _sync_base_material() -> void:
	if map._foreground_palette_material != null:
		map._foreground_palette_material.set_shader_parameter("foreground_palette", map.animated_palette_texture)

	if map._base_material == null:
		return

	map._base_material.set_shader_parameter("dark_underground", map.dark_underground)
	map._base_material.set_shader_parameter("dark_underground_palette", map.dark_underground_palette_texture)
	map._base_material.set_shader_parameter("palette_indices", map.palette_index_texture)
	map._base_material.set_shader_parameter("animated_palette", map.animated_palette_texture)
	# with palette_lookup_all, the base texture holds the indices itself
	map._base_material.set_shader_parameter(
		"palette_cycle_enabled",
		(map.palette_index_texture != null or map.base_palette_lookup_all) and map.animated_palette_texture != null,
	)
	map._base_material.set_shader_parameter("palette_lookup_all", map.base_palette_lookup_all)

	if map._dynamic_material != null:
		map._dynamic_material.set_shader_parameter(
			"animated_palette", map.animated_palette_texture
		)
		map._dynamic_material.set_shader_parameter(
			"palette_cycle_enabled", map.animated_palette_texture != null
		)
		map._dynamic_material.set_shader_parameter("palette_lookup_all", true)


func _sync_dynamic_canvas() -> void:
	if map._dynamic_canvas == null:
		return

	if map.city_source == null:
		map._dynamic_canvas.hide()

		return

	var scale := map.camera._view_scale()
	var offset := map.camera._draw_offset(scale)
	map._dynamic_canvas.set_view_transform(scale, offset)


func _new_palette_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = map._palette_shader

	return material
