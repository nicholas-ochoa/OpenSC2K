extends SceneTree

@warning_ignore_start("integer_division")


func _initialize() -> void:
	var context := CityGpuBuildContext.new()
	context.atlas_edge = 32
	var images: Array[Image] = []
	var slots: Array[Rect2i] = []

	for index in 12:
		var image := Image.create(20, 20, false, Image.FORMAT_LA8)
		image.fill(Color(float(index + 1) / 255.0, 0, 0, 1))
		images.append(image)
		slots.append(context.slot(image))

	assert(context.error.is_empty() and context.atlas_edge > 32)

	for index in images.size():
		assert(context.slot(images[index]) == slots[index], "Atlas growth moved an existing slot")
		assert(context.atlas.get_region(slots[index]).get_data() == images[index].get_data())

	var city := CityState.from_document(Sc2File.load_path("res://../references/SIMCITY2000/CITIES/SYDNEY.SC2"))
	var sprites := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/LARGE.DAT")
	var center := (CityIsometricRenderer.output_size_for_view(2, city.map_size) / 2) / 256
	context = CityGpuBuildContext.new()
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

		for index in region.gpu_draws.size():
			var draw: Dictionary = region.gpu_draws[index]
			var uv := (uvs[index * 4] + uvs[index * 4 + 2]) * 0.5
			assert(uv.x >= 0 and uv.y >= 0 and uv.x <= 1 and uv.y <= 1)
			var point := (vertices[index * 4] + vertices[index * 4 + 2]) * 0.5 + Vector2(region.bounds.position)
			var source := Vector2i(point) - Vector2i(draw.position) + Vector2i(draw.source.position)
			assert(batch.atlas_image.get_pixelv(Vector2i(uv * context.atlas_edge)) == draw.image.get_pixelv(source), "Batch UV sampled the wrong pixel after atlas growth")
	print("PASS: atlas growth preserves pixels, slots and normalized UVs across a region batch")
	quit()
