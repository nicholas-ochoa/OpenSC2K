extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var palette := Sc2Palette.index_encoding()
	var large := Sc2SpriteArchive.load_path("res://../references/DATA/LARGE.DAT")
	var small := Sc2SpriteArchive.combine([Sc2SpriteArchive.load_path("res://../references/DATA/SMALLMED.DAT"), Sc2SpriteArchive.load_path("res://../references/DATA/SPECIAL.DAT")])
	for edge in [128, 256, 384, 512]:
		var path := "res://../references/CITIES/SYDNEY.SC2" if edge == 128 else "res://../local/large-cities/stitched-%d.sc2x" % edge
		var city := CityState.from_document(Sc2File.load_path(path))
		for view in 3:
			var sprites := large if view == 2 else small
			for mode in ["city", "underground"]:
				var context := CityGpuBuildContext.new()
				var size := CityIsometricRenderer.output_size_for_view(view, city.map_size)
				for center in [size / 2, Vector2i(size.x / 2, size.y - 160)]:
					var bounds := Rect2i(center - Vector2i(256, 128), Vector2i(517, 263))
					await _compare(city, palette, sprites, bounds, view, mode, context)
				print("PASS: GPU pixels and foreground %d view %d %s" % [edge, view, mode])
	# All anchor orientations, cutaway terrain, and hidden water/buildings.
	var city := CityState.from_document(Sc2File.load_path("res://../references/CITIES/SYDNEY.SC2"))
	for rotation in 4:
		city.document.set_misc_u32(0x08, rotation)
		for visibility in [{}, {"water": false}, {"buildings": false, "networks": false, "trees": false, "zones": false}]:
			var displayed := CityViewFilter.surface_copy(city, visibility)
			displayed.visible_altitude_levels = 16 if visibility.is_empty() else 32
			var bounds := Rect2i(CityIsometricRenderer.output_size_for_view(2, 128) / 2 - Vector2i(256, 128), Vector2i(517, 263))
			await _compare(displayed, palette, large, bounds, 2, "city", CityGpuBuildContext.new())
	print("PASS: GPU rotations, cutaways and layer filtering")
	quit()

func _compare(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive, bounds: Rect2i, view: int, mode: String, context: CityGpuBuildContext) -> void:
	var cpu := CityRegionRenderer.render(city, palette, sprites, bounds, view, mode)
	var gpu := CityGpuRegionRenderer.render(city, palette, sprites, bounds, view, mode, true, true, context, 1, -1)
	assert(cpu.ok and gpu.ok)
	assert(cpu.occlusion_commands == gpu.occlusion_commands, "GPU foreground must match CPU command order")
	var rasterized := CityGpuDrawList.paint(gpu.gpu_draws, bounds, gpu.background, gpu.gpu_draw_grid)
	cpu.image.convert(Image.FORMAT_LA8)
	assert(cpu.image.get_data() == rasterized.get_data(), "GPU draw list differs from CPU pixels")
	if DisplayServer.get_name() != "headless":
		await _check_gpu_pixels(gpu, cpu.image)


func _check_gpu_pixels(result: Dictionary, expected: Image) -> void:
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
	for y in actual.get_height():
		for x in actual.get_width():
			var a := actual.get_pixel(x, y)
			var b := expected.get_pixel(x, y)
			if a.a != b.a or (a.a > 0 and a.r != b.r):
				differences += 1
	assert(differences == 0, "GPU raster differs at %d pixels" % differences)
	viewport.queue_free()
	await process_frame
