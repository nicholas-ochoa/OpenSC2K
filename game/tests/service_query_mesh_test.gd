extends SceneTree


func _initialize() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create())
	var values: Dictionary[Vector2i, int] = {Vector2i(32, 32): 125, Vector2i(33, 32): 250}
	var result := ServiceQueryAnalysis.Result.new()
	result.values = values
	result.fire = true
	result.sites = [Rect2i(32, 32, 3, 3)]
	var overlay := ServiceQueryOverlay.new()
	overlay.rebuild(city, result)
	var arrays := overlay.fill_mesh.surface_get_arrays(0)
	assert(arrays[Mesh.ARRAY_VERTEX].size() == 8)
	assert(arrays[Mesh.ARRAY_INDEX].size() == 12)
	for tile in 2:
		for corner in 4:
			var vertex: Vector2 = arrays[Mesh.ARRAY_VERTEX][tile * 4 + corner]
			assert(vertex == overlay.polygons[tile][corner])
			var expected := overlay.colors[tile]
			expected.a = 0.55
			var actual: Color = arrays[Mesh.ARRAY_COLOR][tile * 4 + corner]
			# ArrayMesh stores vertex colors as normalized bytes.
			for channel in 4:
				assert(absf(actual[channel] - expected[channel]) <= 1.0 / 255.0)
	assert(overlay.border_mesh.surface_get_array_index_len(0) == 48)
	assert(overlay.station_border_mesh.surface_get_array_index_len(0) == 216)
	assert(overlay.station_highlight_mesh.surface_get_array_index_len(0) == 216)
	# Cached stroke ribbons have no zero-length edges or invalid miter coordinates.
	for mesh in [overlay.fill_mesh, overlay.border_mesh, overlay.station_border_mesh, overlay.station_highlight_mesh]:
		for vertex: Vector2 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			assert(vertex.is_finite())
	# Rebuilding empty coverage must release the previous geometry.
	result.values = {}
	result.sites = []
	overlay.rebuild(city, result)
	assert(overlay.fill_mesh == null and overlay.border_mesh == null)
	assert(overlay.station_border_mesh == null and overlay.station_highlight_mesh == null)
	print("PASS: Service Query mesh coordinates, colors, indices, borders and empty rebuild")
	quit()
