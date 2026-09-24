extends SceneTree

@warning_ignore_start("integer_division")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var palette := Sc2Palette.index_encoding()
	var large := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/LARGE.DAT")
	var small := Sc2SpriteArchive.combine([Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/SMALLMED.DAT"), Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/SPECIAL.DAT")])

	for edge in [128, 512]:
		var path := "res://../references/SIMCITY2000/CITIES/SYDNEY.SC2" if edge == 128 else "res://../local/large-cities/stitched-%d.sc2x" % edge
		var city := CityState.from_document(Sc2File.load_path(path))

		for view in ([0, 1, 2] if edge == 128 else [2]):
			var sprites := large if view == 2 else small

			for mode: CityViewMode.Mode in [CityViewMode.Mode.CITY, CityViewMode.Mode.UNDERGROUND]:
				var context := CityGpuBuildContext.new()
				var size := CityIsometricRenderer.output_size_for_view(view, city.map_size)

				for center in [size / 2, Vector2i(size.x / 2, size.y - 160)]:
					var bounds := Rect2i(center - Vector2i(128, 64), Vector2i(257, 135))
					await _compare(city, palette, sprites, bounds, view, mode, context)

				print("PASS: GPU pixels and foreground %d view %d %s" % [edge, view, CityViewMode.key(mode)])

	# All anchor orientations, cutaway terrain, and hidden water/buildings.
	var city := CityState.from_document(Sc2File.load_path("res://../references/SIMCITY2000/CITIES/SYDNEY.SC2"))

	for rotation in 4:
		city.document.set_misc_u32(0x08, rotation)

		for visibility in ([{}, {"water": false}, {"buildings": false, "networks": false, "trees": false, "zones": false}] if rotation == 0 else [{}]):
			var displayed := CityViewFilter.surface_copy(city, visibility)
			displayed.visible_altitude_levels = 16 if visibility.is_empty() else 32
			var bounds := Rect2i((CityIsometricRenderer.output_size_for_view(2, 128) / 2) - Vector2i(128, 64), Vector2i(257, 135))
			await _compare(displayed, palette, large, bounds, 2, CityViewMode.Mode.CITY, CityGpuBuildContext.new())

	print("PASS: GPU rotations, cutaways and layer filtering")

	for view in 3:
		for mode: CityViewMode.Mode in [CityViewMode.Mode.CITY, CityViewMode.Mode.UNDERGROUND]:
			var sprites := large if view == 2 else small
			var context := CityGpuBuildContext.new()
			var center := (CityIsometricRenderer.output_size_for_view(view, city.map_size) / 2) / 256
			var request := CityGpuRegionBatch.Request.new()
			request.city = city
			request.prepared = true
			request.visibility = {}
			request.palette = palette
			request.sprites = sprites
			request.keys = [center, center + Vector2i.ONE, center + Vector2i(2, 0)]
			request.edge = 256
			request.view = view
			request.mode = mode
			request.pipes = true
			request.subways = true
			request.generation = 1
			request.signs = [] as Array[CitySignRequest]
			var batch := CityGpuRegionBatch.build(request, context, -1)
			assert(batch.ok and batch.regions.size() == 3 and batch.atlas_image != null)
			request.occlusion_depth = false
			var without_depth := CityGpuRegionBatch.build(request, CityGpuBuildContext.new(), -1)
			assert(without_depth.ok and without_depth.atlas_image.get_data() == batch.atlas_image.get_data(), "Depth mode changed atlas placement")
			for index in batch.regions.size():
				assert(without_depth.regions[index].gpu_arrays == batch.regions[index].gpu_arrays)
				assert(without_depth.regions[index].depth_arrays.is_empty() and without_depth.regions[index].train_depth_arrays.is_empty())
			request.occlusion_depth = true
			for region: CityGpuRegionResult in batch.regions:
				var expected := CityRegionRenderer.render(city, palette, sprites, region.bounds, view, mode)
				expected.image.convert(Image.FORMAT_LA8)
				assert(_static_command_values(region.occlusion_commands) == _static_command_values(expected.occlusion_commands))
				assert(CityGpuDrawList.paint(region.gpu_draws, region.bounds, region.background, region.gpu_draw_grid).get_data() == expected.image.get_data())

				if DisplayServer.get_name() != "headless":
					region.atlas_image = batch.atlas_image
					await _check_gpu_pixels(region, expected.image)
			assert(CityGpuRegionBatch.build(request, context, batch.atlas_revision).atlas_image == null, "Warm batch uploaded an unchanged atlas")

			if view == 2 and mode == CityViewMode.Mode.CITY:
				request.generation = 4
				var reused := CityGpuRegionBatch.build(request, context, batch.atlas_revision)
				assert(reused.ok and context.tile_reuses > 0, "A new revision must reuse unchanged common tiles")
				var edited := -1

				for key: int in context.tiles:
					if context.tiles[key].reusable:
						edited = key
						break

				assert(edited >= 0)
				var prior := context.tiles[edited]
				assert(city.set_tile_flag(edited / city.map_size, edited % city.map_size, Sc2TileFlags.FLIPPED,
					not city.is_flipped(edited / city.map_size, edited % city.map_size)))
				request.generation = 9
				var changed := CityGpuRegionBatch.build(request, context, -1)
				assert(changed.ok and context.tiles[edited] != prior)

				for region: CityGpuRegionResult in changed.regions:
					var expected := CityRegionRenderer.render(city, palette, sprites, region.bounds, view, mode)
					expected.image.convert(Image.FORMAT_LA8)
					assert(_static_command_values(region.occlusion_commands) == _static_command_values(expected.occlusion_commands))
					assert(CityGpuDrawList.paint(region.gpu_draws, region.bounds, region.background, region.gpu_draw_grid).get_data() == expected.image.get_data())

					if DisplayServer.get_name() != "headless":
						region.atlas_image = changed.atlas_image
						await _check_gpu_pixels(region, expected.image)

	print("PASS: batched GPU regions share one exact atlas at every native view")
	quit()


func _compare(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive, bounds: Rect2i, view: int, mode: CityViewMode.Mode, context: CityGpuBuildContext) -> void:
	var cpu := CityRegionRenderer.render(city, palette, sprites, bounds, view, mode)
	var gpu := CityGpuRegionRenderer.render(city, palette, sprites, bounds, view, mode, true, true, context, 1, -1)
	assert(cpu.ok and gpu.ok)
	assert(_static_command_values(cpu.occlusion_commands) == _static_command_values(gpu.occlusion_commands), "GPU foreground must match CPU command order")
	var rasterized := CityGpuDrawList.paint(gpu.gpu_draws, bounds, gpu.background, gpu.gpu_draw_grid)
	cpu.image.convert(Image.FORMAT_LA8)
	assert(cpu.image.get_data() == rasterized.get_data(), "GPU draw list differs from CPU pixels")

	if DisplayServer.get_name() != "headless":
		await _check_gpu_pixels(gpu, cpu.image)


func _check_gpu_pixels(result: CityGpuRegionResult, expected: Image) -> void:
	var viewport := SubViewport.new()
	viewport.size = expected.get_size()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var instance := MeshInstance2D.new()
	var mesh := ArrayMesh.new()

	if not result.gpu_arrays[Mesh.ARRAY_VERTEX].is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, result.gpu_arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)

	instance.mesh = mesh

	if result.atlas_image != null:
		instance.texture = ImageTexture.create_from_image(result.atlas_image)

	instance.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(instance)
	await RenderingServer.frame_post_draw
	var actual := viewport.get_texture().get_image()
	actual.convert(Image.FORMAT_LA8)
	var differences := 0
	var actual_bytes := actual.get_data()
	var expected_bytes := expected.get_data()
	if actual_bytes != expected_bytes:
		for index in range(0, actual_bytes.size(), 2):
			if actual_bytes[index + 1] != expected_bytes[index + 1] or (actual_bytes[index + 1] > 0 and actual_bytes[index] != expected_bytes[index]):
				differences += 1

	assert(differences == 0, "GPU raster differs at %d pixels" % differences)
	viewport.queue_free()
	await process_frame


func _static_command_values(commands: Array[CityStaticCommand], include_region := true) -> Array:
	var values: Array = []

	for command in commands:
		var fields := [command.sprite_id, command.flip, command.position, command.size,
			command.depth_order, command.train_ignore, command.train_foreground_reference_sprite_id,
			command.train_deck_thickness, command.train_deck_reference_sprite_id,
			command.train_foreground_requires_depth]

		if include_region:
			fields.append(command.region_order)

		values.append(fields)

	return values
