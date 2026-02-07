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
			var preview_city := NetworkPlacementPreview.snapshot_city(city)
			var result := NetworkPlacementPreview.build({"city": preview_city, "group": tool.x, "tool": tool.y, "start": start, "finish": finish, "view": CityIsometricRenderer.VIEW_LARGE, "palette": palette, "sprites": sprites, "underground": tool == Vector2i(4, 0) or tool == Vector2i(7, 1)})
			assert(result.candidate_count < 300, "Preview work scales with route length, not map area")
			assert(not result.draws.is_empty(), "Preview artwork for %s on %d map" % [tool, edge])
			var placed := CityState.from_document(city.document.duplicate_document())
			assert(NetworkPlacementPreview.apply_preview(placed, tool.x, tool.y, start, finish).ok)
			assert(preview_city.document.serialize().data == placed.document.serialize().data, "Preview uses the actual placement result")
			assert(city.document.serialize().data == before, "Preview never changes live city bytes")
	for edge in [128, 512]:
		var route_city := CityState.from_document(EmptyCityTemplate.create(edge))
		var offset := Vector2i(edge - 30, edge - 30)
		for slope in [false, true]:
			var copy := NetworkPlacementPreview.snapshot_city(route_city)
			if slope:
				assert(copy.set_terrain_id(offset.x + 1, offset.y + 1, 2))
			else:
				assert(copy.set_building_id(offset.x + 1, offset.y + 1, 0x2d))
			var route := NetworkCommand.apply(copy, 6, 0, offset, offset + Vector2i(3, 2))
			assert(route.ok)
			assert(route.points.has(offset + Vector2i(1, 2)), "Keep the incoming direction through a slope or crossing")
			assert(not route.points.has(offset + Vector2i(2, 1)), "Do not turn inside the crossing or slope")
	var original := CityState.from_document(EmptyCityTemplate.create(128))
	var snapshot := NetworkPlacementPreview.snapshot_city(original)
	snapshot.altitude_words[0] += 1
	snapshot.buildings[0] = 0x1d
	assert(snapshot.altitude_words[0] != original.altitude_words[0])
	assert(original.buildings[0] == 0, "Snapshot write changed the live city")
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
	await _test_highway_recovery(palette, sprites)
	print("PASS: network artwork matches placement for roads rail power pipes subway and highways; live city bytes preserved")
	quit()

func _test_highway_recovery(palette: Sc2Palette, sprites: Sc2SpriteArchive) -> void:
	var preview := NetworkPlacementPreview.new()
	root.add_child(preview)
	for edge in [128, 256, 384, 512]:
		var city := CityState.from_document(EmptyCityTemplate.create(edge))
		var start := Vector2i(edge - 24, edge - 24)
		var finish := start + Vector2i(2, 2)
		for x in range(start.x, start.x + 2):
			for y in range(start.y + 2, start.y + 4):
				assert(city.set_terrain_id(x, y, 13))
		var before: PackedByteArray = city.document.serialize().data
		var command := HighwayCommand.apply(NetworkPlacementPreview.snapshot_city(city), 6, 1, start, finish)
		assert(command.ok)
		assert(command.sections == [start, start + Vector2i(0, 2)], "Stop a forced grade at the drag boundary; never revisit a section")
		preview.request(city, 6, 1, start, finish, 2, palette, sprites, false)
		await _wait_for_preview(preview)
		assert(not preview.visuals.is_empty())
		preview.clear()
		preview.request(city, 6, 0, start - Vector2i(4, 4), start - Vector2i(1, 4), 2, palette, sprites, false)
		await _wait_for_preview(preview)
		assert(not preview.visuals.is_empty(), "Road previews still work after the highway that formerly looped")
		assert(city.document.serialize().data == before)
		preview.clear()
		# GDScript worker failures can return null. Simulate that result without
		# deliberately emitting a script error into the regression log.
		preview.worker = Thread.new()
		assert(preview.worker.start(func() -> Variant: return null) == OK)
		await _wait_for_preview(preview)
		assert(preview.worker == null, "A failed worker releases its slot")
		preview.request(city, 7, 0, start - Vector2i(4, 4), start - Vector2i(1, 4), 2, palette, sprites, false)
		await _wait_for_preview(preview)
		assert(not preview.visuals.is_empty(), "Rail previews recover after a failed worker")
		preview.clear()
	preview.queue_free()
	await process_frame

func _wait_for_preview(preview: NetworkPlacementPreview) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while not preview.pending.is_empty() or preview.worker != null:
		assert(Time.get_ticks_msec() < deadline, "Network preview worker timed out")
		await create_timer(0.01).timeout
