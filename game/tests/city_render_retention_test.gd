extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var view := CityMapControl.new()
	root.add_child(view)
	var mesh_a := QuadMesh.new()
	var mesh_b := QuadMesh.new()
	var texture := ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_LA8))
	view.city_source = _source([CityMapSource.MeshEntry.new(Vector2.ZERO, mesh_a, texture, 1)])
	view.layers._sync_base_layer()
	var first: MeshInstance2D = view._mesh_layers[0]
	view.city_source = _source([
		CityMapSource.MeshEntry.new(Vector2.ZERO, mesh_a, texture, 1),
		CityMapSource.MeshEntry.new(Vector2(256, 0), mesh_b, texture, 1),
	])
	view.layers._sync_base_layer()
	assert(view._mesh_layers[0] == first, "Publishing a region replaced unchanged mesh nodes")
	view.city_source = _source([CityMapSource.MeshEntry.new(Vector2.ZERO, mesh_b, texture, 2)])
	view.layers._sync_base_layer()
	assert(view._mesh_layers.size() == 1 and view._mesh_layers[0] == first)
	assert(first.mesh == mesh_b and first.get_meta("divisor") == 2)
	view.city_source = _source([CityMapSource.MeshEntry.new(Vector2.ZERO, mesh_b, texture, 4)])
	view.layers._sync_base_layer()
	assert(first.get_meta("divisor") == 4 and first.scale == Vector2.ONE * view.camera._view_scale() * 4, "Cached geometry used the old divisor")
	_check_region_updates(view, texture)
	var foreground: Dictionary[int, CitySignVisual] = {1: CitySignVisual.new(texture)}
	view.set_sign_occlusion_visuals(foreground)
	var replacement := ImageTexture.create_from_image(Image.create(3, 3, false, Image.FORMAT_LA8))
	foreground[1].texture = replacement
	assert(view.sign_occlusion_visuals[1].texture == texture, "Changing cached input altered a retained visual")
	view.set_sign_occlusion_visuals(foreground)
	assert(view.sign_occlusion_visuals[1].texture == replacement)
	var dynamic := CityDynamicVisual.new(texture, Vector2(5, 7))
	view.set_dynamic_sprites([dynamic])
	var revision := view._dynamic_canvas.visual_revision
	view.set_dynamic_sprites([dynamic.copy()])
	assert(view._dynamic_canvas.visual_revision == revision, "Unchanged visual fields rebuilt the canvas")
	dynamic.position = Vector2(15, 17)
	assert(view.dynamic_sprites[0].position == Vector2(5, 7), "Changing input altered a retained dynamic visual")
	view.set_dynamic_sprites([dynamic])
	assert(view.dynamic_sprites[0].position == dynamic.position)
	var main = load("res://src/main.gd").new()
	main.render_caches.sign_foreground_cache.assign({
		1: RenderCaches.SignForeground.new([2, Rect2i(0, 0, 40, 40)]),
		2: RenderCaches.SignForeground.new([2, Rect2i(400, 400, 40, 40)]),
	})
	var shadow := CityDynamicVisual.new(null, Vector2(150, 150), Vector2(20, 20))
	shadow.samples_static = true
	main.render_caches.dynamic_visual_cache.assign({
		"near": CityDynamicVisual.new(null, Vector2.ZERO, Vector2(20, 20)),
		"far": CityDynamicVisual.new(null, Vector2(500, 500), Vector2(20, 20)),
		"empty": null,
		"shadow": shadow,
		"unoccluded": CityDynamicVisual.new(null, Vector2(100, 100), Vector2(20, 20)),
	})
	main.render_caches.dynamic_occluder_cache.assign({
		"near": RenderCaches.OccluderMask.new(Rect2i(0, 0, 20, 20), null),
		"far": RenderCaches.OccluderMask.new(Rect2i(100, 100, 20, 20), null),
	})
	# the region pixels changed, but its silhouettes changed only near the origin
	var near: Array[Rect2i] = [Rect2i(0, 0, 256, 256)]
	var near_silhouettes: Array[Rect2i] = [Rect2i(0, 0, 64, 64)]
	main.map_render._invalidate_region_foregrounds(near, near_silhouettes)
	assert(main.render_caches.dynamic_visual_cache.keys() == ["far", "unoccluded"])
	assert(main.render_caches.dynamic_occluder_cache.keys() == ["far"])
	assert(not main.render_caches.sign_foreground_cache.has(1) and main.render_caches.sign_foreground_cache.has(2))
	var whole: Array[Rect2i] = [Rect2i(0, 0, 1024, 1024)]
	main.map_render._invalidate_region_foregrounds(whole, whole)
	assert(main.render_caches.sign_foreground_cache.is_empty())
	assert(main.render_caches.dynamic_visual_cache.is_empty() and main.render_caches.dynamic_occluder_cache.is_empty())
	var unused := CityDynamicVisual.new(null, Vector2.ZERO, Vector2(20, 20))
	main.render_caches.dynamic_visual_cache["unused"] = unused
	assert(not main.map_render._invalidate_region_foregrounds(near, near_silhouettes), "Evicting an old position must not redraw current sprites")
	assert(main.render_caches.dynamic_visual_cache.is_empty())
	main.render_caches.dynamic_visual_cache["current"] = unused
	main.render_caches.dynamic_active_keys["current"] = true
	assert(main.map_render._invalidate_region_foregrounds(near, near_silhouettes), "A changed current sprite must redraw")
	unused.hidden = true
	unused.samples_static = true
	main.render_caches.dynamic_visual_cache["current"] = unused
	assert(main.map_render._invalidate_region_foregrounds(near, [] as Array[Rect2i]), "A static change can reveal a hidden current shadow")
	var mapping := PackedInt32Array(range(256))
	var used_indices: Dictionary[int, bool] = {17: true}
	var colors: int = main.map_render.sign_palette_signature(used_indices, mapping)
	mapping[161] = 162
	assert(main.map_render.sign_palette_signature(used_indices, mapping) == colors)
	mapping[17] = 18
	assert(main.map_render.sign_palette_signature(used_indices, mapping) != colors)
	_check_sign_layout_tokens(view)
	main.free()
	view.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless":
		await _check_region_pixels()
	print("PASS: GPU node retention, changed mesh replacement, eviction and foreground input ownership")
	quit()


func _check_region_pixels() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := CityMapControl.new()
	view.size = Vector2(viewport.size)
	viewport.add_child(view)
	var left := _colored_entry(Vector2(448, 480), Color.RED, 1)
	var right := _colored_entry(Vector2(576, 544), Color.GREEN, 1)
	view.city_source = _source([left, right])
	view.source_center = Vector2(512, 512)
	view.zoom_factor = 1.0
	view.layers._sync_base_layer()
	var before := await _capture_region_pixels(viewport)
	var changed := _colored_entry(right.position, Color.BLUE, 2)
	view.city_source = _source([left, changed])
	view.city_source.mesh_updates_from = view._tiled_source.get_instance_id()
	view.city_source.mesh_updates = PackedInt32Array([1])
	assert(view.layers._update_region_meshes(view.camera._view_scale()))
	view.layers._sync_base_layer()
	var updated := await _capture_region_pixels(viewport)
	assert(before.get_data() != updated.get_data(), "Replacing a region did not change the drawn pixels")
	assert(updated.get_pixel(192, 160).b > 0.9, "The replacement region was not drawn")
	for zoom in [1.0, 0.5]:
		view.zoom_factor = zoom
		view.layers._sync_base_layer()
		updated = await _capture_region_pixels(viewport)
		view._tiled_source = null
		view.layers._sync_base_layer()
		var reconciled := await _capture_region_pixels(viewport)
		assert(updated.get_data() == reconciled.get_data(), "Retained region pixels differ from full reconciliation")
	viewport.queue_free()
	await process_frame
	print("PASS: retained region GPU pixels match full reconciliation at two zoom levels")


func _colored_entry(position: Vector2, color: Color, divisor: int) -> CityMapSource.MeshEntry:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(24, 24)
	var entry := CityMapSource.MeshEntry.new(position, mesh, ImageTexture.create_from_image(image), divisor)
	entry.immutable = true
	return entry


func _capture_region_pixels(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _check_region_updates(view: CityMapControl, texture: ImageTexture) -> void:
	var a := CityMapSource.MeshEntry.new(Vector2.ZERO, QuadMesh.new(), texture, 1)
	var b := CityMapSource.MeshEntry.new(Vector2(256, 0), QuadMesh.new(), texture, 1)
	a.immutable = true
	b.immutable = true
	view.city_source = _source([a, b])
	view.layers._sync_base_layer()
	var left := view._mesh_layers[0]
	var right := view._mesh_layers[1]
	var changed := CityMapSource.MeshEntry.new(b.position, QuadMesh.new(), texture, 2)
	changed.immutable = true
	view.city_source = _source([a, changed])
	view.city_source.mesh_updates_from = view._tiled_source.get_instance_id()
	view.city_source.mesh_updates = PackedInt32Array([1])
	assert(view.layers._update_region_meshes(view.camera._view_scale()))
	assert(view._mesh_layers[0] == left and left.mesh == a.mesh)
	assert(view._mesh_layers[1] == right and right.mesh == changed.mesh and right.get_meta("divisor") == 2)
	view.zoom_factor = 0.5
	view.layers._sync_base_layer()
	assert(left.scale == Vector2.ONE * view.camera._view_scale())
	assert(right.scale == Vector2.ONE * view.camera._view_scale() * 2)
	# A consumer can miss a publication. Its older snapshot needs a full diff.
	var changed_left := CityMapSource.MeshEntry.new(a.position, QuadMesh.new(), texture, 1)
	changed_left.immutable = true
	var skipped := _source([changed_left, changed])
	skipped.mesh_updates_from = view.city_source.get_instance_id()
	skipped.mesh_updates = PackedInt32Array([0])
	var changed_right := CityMapSource.MeshEntry.new(changed.position, QuadMesh.new(), texture, 1)
	changed_right.immutable = true
	view.city_source = _source([changed_left, changed_right])
	view.city_source.mesh_updates_from = skipped.get_instance_id()
	view.city_source.mesh_updates = PackedInt32Array([1])
	assert(view.layers._update_region_meshes(view.camera._view_scale()))
	assert(left.mesh == changed_left.mesh and right.mesh == changed_right.mesh, "Skipped publications lost a mesh replacement")
	a = changed_left
	changed = changed_right
	view.city_source = _source([changed, a])
	assert(not view.layers._update_region_meshes(view.camera._view_scale()), "Reordered regions need position reconciliation")
	view.layers._sync_base_layer()
	assert(view._mesh_layers[0] == right and view._mesh_layers[1] == left)
	var moved := CityMapSource.MeshEntry.new(Vector2(512, 0), QuadMesh.new(), texture, 1)
	view.city_source = _source([moved, a])
	assert(not view.layers._update_region_meshes(view.camera._view_scale()))
	view.layers._sync_base_layer()
	assert(view._mesh_layers[0].position == moved.position * view.camera._view_scale())
	assert(view._mesh_layers[1] == left)
	# Public mutable descriptors retain the original reconciliation behavior.
	moved.position = Vector2(768, 0)
	view.city_source = _source([moved, a])
	view.layers._sync_base_layer()
	assert(view._mesh_layers[0].position == moved.position * view.camera._view_scale())


func _check_sign_layout_tokens(view: CityMapControl) -> void:
	var city := CityState.from_document(Sc2File.load_path("res://tests/fixtures/cities/generated-128.SC2"))
	view.set_city_view(city, view.city_source, null, false, true, [1])
	var scans := view._sign_cache_build_count
	var copy := CityState.from_document(city.document.duplicate_document())
	view.set_city_view(copy, view.city_source, null, false, true, [1])
	assert(view._sign_entries_city == copy and view._sign_cache_build_count == scans)
	assert(copy.set_label(1, "Updated label"))
	view.set_city_view(copy, view.city_source, null, false, true, [2])
	assert(view._sign_cache_build_count == scans + 1, "Changed labels were not checked on the current city")
	view.zoom_factor = 0.25
	view.set_city_view(copy, view.city_source, null, false, true, [2])
	assert(view._sign_cache_build_count == scans + 2, "Zoom left stale sign dimensions")
	view.signs._invalidate_sign_entries()
	assert(view._external_sign_layout_token.is_empty())
	view.set_animated_palette(ImageTexture.create_from_image(Image.create(256, 1, false, Image.FORMAT_RGBA8)))
	view.set_city_view(copy, _source([]), null, true, true, [2])
	assert(view._base_material.get_shader_parameter("palette_cycle_enabled"), "Indexed base sources cycle without a separate index texture")
	view.set_city_view(copy, _source([]), null, false, true, [2])
	assert(not view._base_material.get_shader_parameter("palette_cycle_enabled"))


func _source(meshes: Array[CityMapSource.MeshEntry]) -> CityMapSource:
	var result := CityMapSource.new(Vector2i(1024, 1024))
	result.meshes = meshes

	return result
