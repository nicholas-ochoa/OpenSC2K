extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var view := CityMapControl.new()
	root.add_child(view)
	var mesh_a := QuadMesh.new()
	var mesh_b := QuadMesh.new()
	var texture := ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_LA8))
	view.city_texture = _source([{ "position": Vector2.ZERO, "mesh": mesh_a, "texture": texture, "divisor": 1 }])
	view._sync_base_layer()
	var first: MeshInstance2D = view._mesh_layers[0]
	view.city_texture = _source([
		{ "position": Vector2.ZERO, "mesh": mesh_a, "texture": texture, "divisor": 1 },
		{ "position": Vector2(256, 0), "mesh": mesh_b, "texture": texture, "divisor": 1 },
	])
	view._sync_base_layer()
	assert(view._mesh_layers[0] == first, "Publishing a region replaced unchanged mesh nodes")
	view.city_texture = _source([{ "position": Vector2.ZERO, "mesh": mesh_b, "texture": texture, "divisor": 2 }])
	view._sync_base_layer()
	assert(view._mesh_layers.size() == 1 and view._mesh_layers[0] == first)
	assert(first.mesh == mesh_b and first.get_meta("divisor") == 2)
	view.city_texture = _source([{ "position": Vector2.ZERO, "mesh": mesh_b, "texture": texture, "divisor": 4 }])
	view._sync_base_layer()
	assert(first.get_meta("divisor") == 4 and first.scale == Vector2.ONE * view._view_scale() * 4, "Cached geometry used the old divisor")
	var foreground := {1: {"texture": texture}}
	view.set_sign_occlusion_visuals(foreground)
	var replacement := ImageTexture.create_from_image(Image.create(3, 3, false, Image.FORMAT_LA8))
	foreground[1].texture = replacement
	assert(view.sign_occlusion_visuals[1].texture == texture, "Changing cached input altered a retained visual")
	view.set_sign_occlusion_visuals(foreground)
	assert(view.sign_occlusion_visuals[1].texture == replacement)
	var main = load("res://src/main.gd").new()
	main.sign_foreground_cache = {
		1: {"signature": [2, Rect2i(0, 0, 40, 40)]},
		2: {"signature": [2, Rect2i(400, 400, 40, 40)]},
	}
	main.dynamic_visual_cache = {
		"near": {"position": Vector2.ZERO, "size": Vector2(20, 20)},
		"far": {"position": Vector2(500, 500), "size": Vector2(20, 20)},
		"empty": {},
	}
	var near: Array[Rect2i] = [Rect2i(0, 0, 256, 256)]
	main._invalidate_region_foregrounds(near)
	assert(main.dynamic_visual_cache.keys() == ["far"])
	assert(not main.sign_foreground_cache.has(1) and main.sign_foreground_cache.has(2))
	var whole: Array[Rect2i] = [Rect2i(0, 0, 1024, 1024)]
	main._invalidate_region_foregrounds(whole)
	assert(main.sign_foreground_cache.is_empty())
	var mapping := PackedInt32Array(range(256))
	var colors: int = main._sign_palette_signature({17: true}, mapping)
	mapping[161] = 162
	assert(main._sign_palette_signature({17: true}, mapping) == colors)
	mapping[17] = 18
	assert(main._sign_palette_signature({17: true}, mapping) != colors)
	_check_sign_layout_tokens(view)
	main.free()
	view.queue_free()
	await process_frame
	print("PASS: GPU node retention, changed mesh replacement, eviction and foreground input ownership")
	quit()

func _check_sign_layout_tokens(view: CityMapControl) -> void:
	var city := CityState.from_document(Sc2File.load_path("res://../references/SIMCITY2000/CITIES/SYDNEY.SC2"))
	view.set_city_view(city, view.city_texture, null, false, true, [1])
	var scans := view._sign_cache_build_count
	var copy := CityState.from_document(city.document.duplicate_document())
	view.set_city_view(copy, view.city_texture, null, false, true, [1])
	assert(view._sign_entries_city == copy and view._sign_cache_build_count == scans)
	assert(copy.set_label(1, "Updated label"))
	view.set_city_view(copy, view.city_texture, null, false, true, [2])
	assert(view._sign_cache_build_count == scans + 1, "Changed labels were not checked on the current city")
	view.zoom_factor = 0.25
	view.set_city_view(copy, view.city_texture, null, false, true, [2])
	assert(view._sign_cache_build_count == scans + 2, "Zoom left stale sign dimensions")
	view._invalidate_sign_entries()
	assert(view._external_sign_layout_token.is_empty())

func _source(meshes: Array) -> Texture2D:
	var result := PlaceholderTexture2D.new()
	result.size = Vector2(1024, 1024)
	result.set_meta("map_tiles", [])
	result.set_meta("map_meshes", meshes)
	return result
