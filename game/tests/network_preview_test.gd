extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sprites := Sc2SpriteArchive.load_path("res://../references/DATA/LARGE.DAT")
	var palette := Sc2Palette.index_encoding()
	for edge in [128, 256, 384, 512]:
		var city := CityState.from_document(EmptyCityTemplate.create(edge))
		var start := Vector2i(edge - 24, edge - 24)
		var finish := start + Vector2i(8, 0)
		var before: PackedByteArray = city.document.serialize().data
		for tool in [Vector2i(6, 0), Vector2i(7, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(7, 1), Vector2i(6, 1)]:
			var preview_city := CityState.from_document(city.document.duplicate_document())
			var result := NetworkPlacementPreview.build({"city": preview_city, "group": tool.x, "tool": tool.y, "start": start, "finish": finish, "view": CityIsometricRenderer.VIEW_LARGE, "palette": palette, "sprites": sprites, "underground": tool == Vector2i(4, 0) or tool == Vector2i(7, 1)})
			assert(result.candidate_count < 300, "Preview work scales with route length, not map area")
			assert(not result.draws.is_empty(), "Preview artwork for %s on %d map" % [tool, edge])
			var placed := CityState.from_document(city.document.duplicate_document())
			assert(NetworkPlacementPreview.apply_preview(placed, tool.x, tool.y, start, finish).ok)
			assert(preview_city.document.serialize().data == placed.document.serialize().data, "Preview uses the actual placement result")
			assert(city.document.serialize().data == before, "Preview never changes live city bytes")
	var rejected := CityState.from_document(EmptyCityTemplate.create(128))
	var invalid := NetworkPlacementPreview.build({"city": rejected, "group": 6, "tool": 0, "start": Vector2i(-1, -1), "finish": Vector2i.ZERO, "view": 2, "palette": palette, "sprites": sprites, "underground": false})
	assert(invalid.draws.is_empty())
	var controller := NetworkPlacementPreview.new()
	var map := CityMapControl.new()
	controller.map_view = map
	assert(controller.modulate.a == 0.75, "The complete preview layer uses 75% opacity")
	root.add_child(controller)
	controller.request(rejected, 6, 0, Vector2i(60, 60), Vector2i(70, 60), 2, palette, sprites, false)
	assert(map.network_preview_active, "Suppress the route highlight before worker artwork arrives")
	map.city = rejected
	map.edit_enabled = true
	map.show_selection_preview = true
	map.hover_tile = Vector2i(65, 60)
	map.selection_start = Vector2i(60, 60)
	map.selection_end = Vector2i(70, 60)
	map.selection_mode = "path"
	map.highway_preview = true
	assert(map._selection_source_polygons().size() == 1, "Keep only the current hover tile highlighted, including highways")
	controller._process(0.0)
	var session := controller.generation
	controller.request(rejected, 6, 0, Vector2i(60, 60), Vector2i(71, 60), 2, palette, sprites, false)
	assert(controller.generation == session, "Pointer motion discarded a finished worker result")
	controller.clear()
	while controller.worker != null:
		await create_timer(0.01).timeout
	assert(controller.visuals.is_empty(), "Canceled worker results cannot reappear")
	assert(not map.network_preview_active)
	map.free()
	controller.map_view = null
	controller.queue_free()
	await process_frame
	print("PASS: network artwork matches placement for roads rail power pipes subway and highways; live city bytes preserved")
	quit()
