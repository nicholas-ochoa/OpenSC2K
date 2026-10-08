class_name CityMapLayers
extends CityMapConstants

# Retain one mesh. The budget counts its source vertex and index arrays.
# Driver and resource overhead are separate from this estimate.
const RETAINED_GEOMETRY_BYTES := 64 * 1024 * 1024

# the top of the underwater scale of the height legend
const WATER_SCALE_TOP := 96

var map: CityMapControl
# the price label draws above the network preview layer, not under it
var price_layer: Node2D
# the selection preview, bulldozer and trip routes draw above the map's own commands
var overlay_layer: Control
var _tile_layers: Array[TextureRect] = []
var _mesh_layers: Array[MeshInstance2D] = []
var _mesh_view_scale := -1.0
var _tiled_source: CityMapSource
var base_layer: TextureRect
var _base_material: ShaderMaterial
var dynamic_canvas: CityDynamicSpriteCanvas
var _dynamic_material: ShaderMaterial
var _palette_shader: Shader
var _foreground_palette_material: ShaderMaterial
var _retained_data_mesh: ArrayMesh
var _retained_data_signature: Array = []
var environment_parameters: Dictionary = {}
var water_layer: CityWaterLayer
var _visual_materials: Dictionary = {}
var _environment := CityEnvironmentParameters.new()
var _power_warning_palette: Texture2D
var _power_warning_blend := 0.0


func set_power_warning_animation(next_palette: Texture2D, blend: float) -> void:
	if _power_warning_palette == next_palette and _power_warning_blend == blend:
		return
	_power_warning_palette = next_palette
	_power_warning_blend = blend
	_apply_power_warning(_base_material)
	for material: ShaderMaterial in _visual_materials.values():
		_apply_power_warning(material)


func _apply_power_warning(material: ShaderMaterial) -> void:
	if material == null:
		return
	material.set_shader_parameter("power_warning_palette", _power_warning_palette)
	material.set_shader_parameter("power_warning_blend", _power_warning_blend if _power_warning_palette != null else 0.0)


func set_environment(parameters: Dictionary) -> void:
	environment_parameters = parameters
	_environment.update(parameters)
	if water_layer != null:
		water_layer.set_environment(parameters)
	for material: ShaderMaterial in [_base_material, _dynamic_material]:
		_apply_environment(material)
	for material: ShaderMaterial in _visual_materials.values():
		_apply_environment(material)


func _apply_environment(material: ShaderMaterial) -> void:
	_environment.apply(material)


func visual_material(emission: Texture2D, seasons: Texture2D) -> ShaderMaterial:
	if emission == null and seasons == null:
		return _base_material
	var key := "%d/%d" % [emission.get_instance_id() if emission != null else 0, seasons.get_instance_id() if seasons != null else 0]
	if not _visual_materials.has(key):
		var material := _base_material.duplicate() as ShaderMaterial
		material.set_shader_parameter("environment_emission", emission)
		material.set_shader_parameter("environment_has_emission", emission != null)
		material.set_shader_parameter("environment_season_mask", seasons)
		material.set_shader_parameter("environment_has_seasons", seasons != null)
		_apply_environment(material)
		_visual_materials[key] = material
	return _visual_materials[key]


func _init(control: CityMapControl) -> void:
	map = control


func set_data_view(value: CityState, mode: CityViewMode.Mode) -> void:
	var mode_changed := map.data_view_mode != mode
	var signature := CityDataView.signature(value, mode)
	var geometry_signature := CityDataView.geometry_signature(value, mode)

	if map.data_geometry_signature != geometry_signature:
		var cached_mesh: ArrayMesh = _retained_data_mesh if _retained_data_signature == geometry_signature else null
		_clear_retained_geometry()
		map.data_view_mesh = cached_mesh if cached_mesh != null else CityDataView.create_mesh(value, mode)
		map.data_geometry_signature = geometry_signature

	if map.data_view_layer == null:
		map.data_view_layer = MeshInstance2D.new()
		map.data_view_layer.name = "TileDataLayer"
		map.data_view_layer.show_behind_parent = true
		var grid_material := ShaderMaterial.new()
		grid_material.shader = CityDataView.GRID_SHADER
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
	_clear_retained_geometry()
	if map.data_view_mesh != null and CityDataView.mesh_array_bytes(map.data_view_mesh) <= RETAINED_GEOMETRY_BYTES:
		_retained_data_mesh = map.data_view_mesh
		_retained_data_signature = map.data_geometry_signature.duplicate()
	map.data_view_mesh = null

	if map.data_view_layer != null:
		map.data_view_layer.hide()
		map.data_view_layer.mesh = null

	map.data_view_signature.clear()
	map.data_geometry_signature.clear()
	map.data_value_texture = null

	if dynamic_canvas != null:
		dynamic_canvas.show()

	_sync_base_layer()
	map.queue_redraw()


func discard_geometry_for_other_city(value: CityState) -> void:
	if _retained_data_signature.is_empty():
		return
	if value == null or value.document == null or _retained_data_signature[0] != value.document.get_instance_id():
		_clear_retained_geometry()


func _clear_retained_geometry() -> void:
	_retained_data_mesh = null
	_retained_data_signature.clear()


func _draw_data_view(scale: float, offset: Vector2) -> void:
	if map.hover_tile.x >= 0:
		var outline := CityDataView.surface_polygon(
			map.city,
			map.hover_tile.x,
			map.hover_tile.y,
			map.data_view_mode == CityViewMode.Mode.HEIGHT,
		)

		for index in outline.size():
			outline[index] = offset + outline[index] * scale

		if not outline.is_empty():
			outline.append(outline[0])
			map.draw_polyline(outline, Color.WHITE, 1.0)


func draw_data_key(canvas: Control) -> void:
	var font := ThemeDB.fallback_font
	var origin := Vector2.ZERO
	var title: String = CityDataView.TITLES[CityViewMode.DATA_MODES.find(map.data_view_mode)]
	canvas.draw_string(
		font,
		origin + Vector2(12, 24),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		map.get_theme_color("font_color", "MapLegend"),
	)

	var states := CityDataView.state_labels(map.data_view_mode)

	if not states.is_empty():
		for index in states.size():
			var position := origin + Vector2(12 + index * 100, 38)
			canvas.draw_rect(
				Rect2(position, Vector2(88, 18)),
				CityDataView.color(index, map.data_view_mode),
			)
			canvas.draw_string(font, position + Vector2(0, 38), states[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
					map.get_theme_color("font_color", "MapLegend"))
	else:
		for index in CityDataView.SCALE_CELLS:
			canvas.draw_rect(
				Rect2(origin + Vector2(12 + index * 9.25, 38), Vector2(9.25, 20)),
				CityDataView.color(CityDataView.scale_value(map.data_view_mode, index), map.data_view_mode),
			)

		if map.data_view_mode == CityViewMode.Mode.HEIGHT:
			# underwater tiles have their own scale, the same size as the land scale
			for index in 32:
				var depth := roundi(index * CityDataView.MAX_SHOWN_DEPTH / 31.0)
				canvas.draw_rect(Rect2(origin + Vector2(12 + index * 9.25, WATER_SCALE_TOP), Vector2(9.25, 20)),
					CityDataView.color(CityDataView.UNDERWATER_BASE + depth, map.data_view_mode))

			_draw_scale_labels(canvas, font, origin + Vector2(0, WATER_SCALE_TOP + 42), "Shallow water", "Deep water")

		var labels := CityDataView.range_labels(map.data_view_mode)
		_draw_scale_labels(canvas, font, origin + Vector2(0, 80), labels[0], labels[1])
		var middle := CityDataView.middle_label(map.data_view_mode)

		if not middle.is_empty():
			var middle_width := font.get_string_size(middle, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			canvas.draw_string(font, origin + Vector2(160 - middle_width / 2, 80), middle, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
					map.get_theme_color("font_color", "MapLegend"))


# the low label under the left end of a scale and the high label under its right end
func _draw_scale_labels(canvas: Control, font: Font, baseline: Vector2, low: String, high: String) -> void:
	var color := map.get_theme_color("font_color", "MapLegend")
	canvas.draw_string(font, baseline + Vector2(12, 0), low, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
	var high_width := font.get_string_size(high, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	canvas.draw_string(font, baseline + Vector2(308 - high_width, 0), high, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)


func data_key_origin() -> Vector2:
	# match trip query: anchor inside the map area, clear of the sidebar
	var workspace := map.get_parent()
	if workspace != null:
		var map_space := workspace.get_node_or_null("Page/Content/MapSpace") as Control
		if map_space != null:
			return map_space.global_position - map.global_position + Vector2(12, 12)
	return Vector2(12, 12)


func _ensure_base_layer() -> void:
	if base_layer != null:
		return

	base_layer = TextureRect.new()
	base_layer.name = "CityBaseLayer"
	base_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	base_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base_layer.stretch_mode = TextureRect.STRETCH_SCALE
	base_layer.show_behind_parent = true
	price_layer = Node2D.new()
	price_layer.name = "SelectionPriceLayer"
	price_layer.z_index = PRICE_LAYER_Z_INDEX
	price_layer.draw.connect(map.selection._draw_selection_price)
	map.add_child(price_layer)
	_foreground_palette_material = CityForegroundPalette.create_material(map.animated_palette_texture)
	map.material = _foreground_palette_material
	_palette_shader = PALETTE_CYCLE_SHADER
	_base_material = _new_palette_material()
	base_layer.material = _base_material
	map.add_child(base_layer)
	water_layer = CityWaterLayer.new()
	water_layer.name = "WaterReflections"
	water_layer.show_behind_parent = true
	map.add_child(water_layer)
	water_layer.set_environment(environment_parameters)
	dynamic_canvas = DynamicSpriteCanvas.new()
	dynamic_canvas.name = "DynamicSpriteCanvas"
	dynamic_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dynamic_canvas.show_behind_parent = true
	_dynamic_material = _new_palette_material()
	dynamic_canvas.material = _dynamic_material
	map.add_child(dynamic_canvas)
	overlay_layer = Control.new()
	overlay_layer.name = "SelectionOverlayLayer"
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.use_parent_material = true
	overlay_layer.draw.connect(map.presentation._draw_overlay)
	map.add_child(overlay_layer)
	dynamic_canvas.set_visuals(
		map.dynamic_sprites, map.camera._view_scale(), map.camera._draw_offset(map.camera._view_scale())
	)
	_sync_base_layer()


func _sync_base_layer() -> void:
	_sync_base_nodes()


func _sync_base_nodes() -> void:
	if not map.data_view_mode == CityViewMode.Mode.NONE:
		if map.data_view_layer != null:
			var data_scale := map.camera._view_scale()
			map.data_view_layer.position = map.camera._draw_offset(data_scale)
			map.data_view_layer.scale = Vector2.ONE * data_scale
			map.data_view_layer.show()

		if base_layer != null:
			base_layer.hide()
		if water_layer != null:
			water_layer.hide()

		if dynamic_canvas != null:
			dynamic_canvas.hide()

		return

	if base_layer == null:
		return

	if map.city_source == null:
		base_layer.hide()
		if water_layer != null:
			water_layer.sync(null, 1.0, Vector2.ZERO, map.animated_palette_texture)

		return

	var scale := map.camera._view_scale()

	if _tiled_source != map.city_source and not _update_region_meshes(scale):
		for tile in _tile_layers:
			tile.queue_free()

		_tile_layers.clear()
		var retained_meshes := {}

		for mesh in _mesh_layers:
			retained_meshes[mesh.get_meta("source_position")] = mesh

		_mesh_layers.clear()
		_tiled_source = map.city_source

		for entry in map.city_source.tiles:
			var tile := TextureRect.new()
			tile.texture = entry.texture
			tile.set_meta("source_position", entry.position)
			tile.set_meta("source_size", entry.size)
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tile.material = visual_material(entry.emission, entry.seasons)
			base_layer.add_child(tile)
			_tile_layers.append(tile)

		for entry in map.city_source.meshes:
			var mesh: MeshInstance2D = retained_meshes.get(entry.position)

			if mesh == null:
				mesh = MeshInstance2D.new()
				base_layer.add_child(mesh)
			else:
				retained_meshes.erase(entry.position)

				if mesh.mesh == entry.mesh and mesh.texture == entry.texture and int(mesh.get_meta("divisor")) == entry.divisor:
					_mesh_layers.append(mesh)
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
			mesh.material = visual_material(entry.emission, entry.seasons)
			_mesh_layers.append(mesh)
		for mesh: MeshInstance2D in retained_meshes.values():
			mesh.hide()
			mesh.queue_free()

	base_layer.texture = map.city_source.texture
	base_layer.material = visual_material(map.city_source.emission, map.city_source.seasons)

	for tile in _tile_layers:
		tile.position = Vector2(tile.get_meta("source_position")) * scale
		tile.size = Vector2(tile.get_meta("source_size")) * scale

	if not is_equal_approx(_mesh_view_scale, scale):
		for mesh in _mesh_layers:
			mesh.position = Vector2(mesh.get_meta("source_position")) * scale
			mesh.scale = Vector2.ONE * scale * int(mesh.get_meta("divisor"))

		_mesh_view_scale = scale

	base_layer.position = map.camera._draw_offset(scale)
	base_layer.size = Vector2(map.city_source.size) * scale
	base_layer.show()
	water_layer.sync(map.city_source, scale, map.camera._draw_offset(scale), map.animated_palette_texture, map.visible_source_rect())
	var used_materials := {}
	used_materials[base_layer.material] = true
	for tile in _tile_layers:
		used_materials[tile.material] = true
	for mesh in _mesh_layers:
		used_materials[mesh.material] = true
	for key in _visual_materials.keys():
		if not used_materials.has(_visual_materials[key]):
			_visual_materials.erase(key)
	_sync_base_material()
	_sync_dynamic_canvas()


# A stationary view publishes the same region positions with a few new meshes.
# Keep the node list and skip unchanged, immutable descriptors. Pans, missing
# regions, and CPU texture sources still use the full reconciliation above.
func _update_region_meshes(scale: float) -> bool:
	var before := _tiled_source
	var after := map.city_source

	if (before == null or after.meshes.is_empty() or not before.tiles.is_empty() or not after.tiles.is_empty()
			or before.meshes.size() != after.meshes.size() or _mesh_layers.size() != after.meshes.size()):
		return false

	var changed := after.mesh_updates
	if after.mesh_updates_from != before.get_instance_id():
		changed = PackedInt32Array()
		for index in after.meshes.size():
			if (not before.meshes[index].immutable or not after.meshes[index].immutable
					or before.meshes[index].position != after.meshes[index].position):
				return false
			if before.meshes[index] != after.meshes[index]:
				changed.append(index)

	for index in changed:
		var entry := after.meshes[index]

		var mesh := _mesh_layers[index]
		mesh.position = entry.position * scale
		mesh.scale = Vector2.ONE * scale * entry.divisor
		mesh.mesh = entry.mesh
		mesh.texture = entry.texture
		mesh.material = visual_material(entry.emission, entry.seasons)
		mesh.set_meta("divisor", entry.divisor)

	_tiled_source = after

	return true


func _sync_base_material() -> void:
	if _foreground_palette_material != null:
		_foreground_palette_material.set_shader_parameter("foreground_palette", map.animated_palette_texture)

	if _base_material == null:
		return

	_base_material.set_shader_parameter("dark_underground", map.dark_underground)
	_base_material.set_shader_parameter("dark_underground_palette", map.dark_underground_palette_texture)
	_base_material.set_shader_parameter("palette_indices", map.palette_index_texture)
	_base_material.set_shader_parameter("animated_palette", map.animated_palette_texture)
	# with palette_lookup_all, the base texture holds the indices itself
	_base_material.set_shader_parameter(
		"palette_cycle_enabled",
		(map.palette_index_texture != null or map.base_palette_lookup_all) and map.animated_palette_texture != null,
	)
	_base_material.set_shader_parameter("palette_lookup_all", map.base_palette_lookup_all)
	_apply_power_warning(_base_material)

	if _dynamic_material != null:
		_dynamic_material.set_shader_parameter(
			"animated_palette", map.animated_palette_texture
		)
		_dynamic_material.set_shader_parameter(
			"palette_cycle_enabled", map.animated_palette_texture != null
		)
		_dynamic_material.set_shader_parameter("palette_lookup_all", true)
	for material: ShaderMaterial in _visual_materials.values():
		for key in ["dark_underground", "dark_underground_palette", "palette_indices", "animated_palette", "palette_cycle_enabled", "palette_lookup_all"]:
			material.set_shader_parameter(key, _base_material.get_shader_parameter(key))
	set_environment(environment_parameters)


func _sync_dynamic_canvas() -> void:
	if dynamic_canvas == null:
		return

	if map.city_source == null:
		dynamic_canvas.hide()

		return

	var scale := map.camera._view_scale()
	var offset := map.camera._draw_offset(scale)
	dynamic_canvas.set_view_transform(scale, offset)


func _new_palette_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _palette_shader

	return material
