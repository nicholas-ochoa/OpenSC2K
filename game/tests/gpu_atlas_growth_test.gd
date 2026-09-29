extends SceneTree

@warning_ignore_start("integer_division")


func _initialize() -> void:
	var city := CityState.from_document(Sc2File.load_path("res://tests/fixtures/cities/generated-128.SC2"))
	var sprites := FixtureGraphics.pack().large_sprites
	var center := (CityIsometricRenderer.output_size_for_view(2, city.map_size) / 2) / 256
	# Native slot growth is a Rust unit test. This batch checks normalized UVs.
	var context := CityGpuBuildContext.new()
	context.atlas_edge = 64
	var request := CityGpuRegionBatch.Request.new()
	request.city = city
	request.prepared = true
	request.visibility = {}
	request.palette = Sc2Palette.index_encoding()
	request.sprites = sprites
	request.keys = [center, center + Vector2i.ONE, center + Vector2i(2, 0)]
	request.edge = 256
	request.view = 2
	request.mode = CityViewMode.Mode.CITY
	request.pipes = true
	request.subways = true
	request.generation = 1
	request.signs = [] as Array[CitySignRequest]
	var batch := CityGpuRegionBatch.build(request, context, -1)
	assert(batch.ok and context.atlas_edge > 64)
	for region: CityGpuRegionResult in batch.regions:
		assert(region.atlas_edge == context.atlas_edge)
		var uvs: PackedVector2Array = region.gpu_arrays[Mesh.ARRAY_TEX_UV]
		var vertices: PackedVector2Array = region.gpu_arrays[Mesh.ARRAY_VERTEX]

		for index in region.draw_count():
			var at := index * CityGpuRegionResult.RECORD_SIZE
			var position := Vector2i(region.draw_records[at], region.draw_records[at + 1])
			var image := region.draw_images[region.draw_records[at + 4]]
			var uv := (uvs[index * 4] + uvs[index * 4 + 2]) * 0.5
			assert(uv.x >= 0 and uv.y >= 0 and uv.x <= 1 and uv.y <= 1)
			var point := (vertices[index * 4] + vertices[index * 4 + 2]) * 0.5 + Vector2(region.bounds.position)
			assert(
				batch.atlas_image.get_pixelv(Vector2i(uv * context.atlas_edge)) == image.get_pixelv(Vector2i(point) - position),
				"Batch UV sampled the wrong pixel after atlas growth",
			)
	print("PASS: atlas growth preserves normalized UVs across a region batch")
	quit()
