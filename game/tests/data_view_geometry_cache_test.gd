extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var map := CityMapControl.new()
	map.size = Vector2(1280, 720)
	root.add_child(map)
	var city := CityState.from_document(EmptyCityTemplate.create(16))
	city.set_land_altitude(3, 3, 8)
	map.set_data_view(city, CityViewMode.Mode.LAND_VALUE)
	var mesh := map.data_view_mesh
	var expected := mesh.surface_get_arrays(0)
	var source_bytes := 0
	for array in expected:
		if array != null:
			source_bytes += array.to_byte_array().size()
	assert(CityDataView.mesh_array_bytes(mesh) == source_bytes, "Cache budget counts the mesh source arrays")
	map.clear_data_view()
	assert(map.data_view_mesh == null and map.data_view_layer.mesh == null)
	map.set_data_view(city, CityViewMode.Mode.CRIME)
	assert(map.data_view_mesh == mesh, "Compatible modes reuse inactive geometry")
	assert(map.data_view_mesh.surface_get_arrays(0) == expected)
	map.clear_data_view()
	var values := city.document.find_chunk("XVAL")
	var data := values.decoded_payload.duplicate()
	data[0] = 127
	assert(values.set_decoded_payload(data))
	map.set_data_view(city, CityViewMode.Mode.LAND_VALUE)
	assert(map.data_view_mesh == mesh, "Value edits keep geometry")
	assert(map.data_view_signature == CityDataView.signature(city, CityViewMode.Mode.LAND_VALUE))
	map.clear_data_view()
	city.set_land_altitude(3, 3, 9)
	map.set_data_view(city, CityViewMode.Mode.LAND_VALUE)
	assert(map.data_view_mesh != mesh, "Altitude edits invalidate inactive geometry")
	mesh = map.data_view_mesh
	map.clear_data_view()
	var terrain := city.document.find_chunk("XTER")
	data = terrain.decoded_payload.duplicate()
	data[3 * 16 + 3] = 1
	assert(terrain.set_decoded_payload(data))
	city.resync_mirrors(PackedStringArray(["XTER"]))
	map.set_data_view(city, CityViewMode.Mode.LAND_VALUE)
	assert(map.data_view_mesh != mesh, "Terrain shape edits invalidate inactive geometry")
	mesh = map.data_view_mesh
	map.clear_data_view()
	city.visible_altitude_levels = 7
	map.set_data_view(city, CityViewMode.Mode.LAND_VALUE)
	assert(map.data_view_mesh != mesh, "Altitude visibility invalidates inactive geometry")
	mesh = map.data_view_mesh
	map.clear_data_view()
	map.set_data_view(city, CityViewMode.Mode.HEIGHT)
	assert(map.data_view_mesh != mesh, "Height mode uses separate geometry")
	mesh = map.data_view_mesh
	map.clear_data_view()
	var flags := city.document.find_chunk("XBIT")
	data = flags.decoded_payload.duplicate()
	data[0] |= 4
	assert(flags.set_decoded_payload(data))
	city.resync_mirrors(PackedStringArray(["XBIT"]))
	map.set_data_view(city, CityViewMode.Mode.HEIGHT)
	assert(map.data_view_mesh != mesh, "Water edits invalidate height geometry")
	mesh = map.data_view_mesh
	map.clear_data_view()
	var retained: WeakRef = weakref(mesh)
	mesh = null
	assert(retained.get_ref() != null)
	var snapshot := CityState.from_document(city.document.duplicate_document())
	map.set_city_view(snapshot, CityMapSource.new(CityIsometricRenderer.output_size_for_view(CityIsometricRenderer.VIEW_LARGE, 16)))
	assert(retained.get_ref() != null, "A display snapshot keeps inactive source geometry")
	map.set_data_view(city, CityViewMode.Mode.HEIGHT)
	assert(map.data_view_mesh == retained.get_ref())
	map.clear_data_view()
	map.city = CityState.from_document(EmptyCityTemplate.create(16))
	map.discard_data_geometry_for_other_city(map.city)
	assert(retained.get_ref() == null, "A new source city releases inactive geometry")
	map.set_data_view(map.city, CityViewMode.Mode.LAND_VALUE)
	retained = weakref(map.data_view_mesh)
	map.clear_data_view()
	map.city = null
	map.discard_data_geometry_for_other_city(null)
	assert(retained.get_ref() == null, "Closing the city releases inactive geometry")
	map.free()

	# Water changes which altitude controls visibility below the height limit.
	city = CityState.from_document(EmptyCityTemplate.create(16))
	var alt_chunk := city.document.find_chunk("ALTM")
	data = alt_chunk.decoded_payload.duplicate()
	BinaryData.write_u16_be(data, (3 * 16 + 3) * 2, 1 | (10 << 5))
	assert(alt_chunk.set_decoded_payload(data))
	city.resync_mirrors(PackedStringArray(["ALTM"]))
	city.visible_altitude_levels = 5
	map = CityMapControl.new()
	map.size = Vector2(1280, 720)
	root.add_child(map)
	map.set_data_view(city, CityViewMode.Mode.LAND_VALUE)
	mesh = map.data_view_mesh
	flags = city.document.find_chunk("XBIT")
	data = flags.decoded_payload.duplicate()
	data[3 * 16 + 3] |= 4
	assert(flags.set_decoded_payload(data))
	city.resync_mirrors(PackedStringArray(["XBIT"]))
	map.set_data_view(city, CityViewMode.Mode.LAND_VALUE)
	assert(map.data_view_mesh != mesh, "Water edits invalidate active clipped geometry")
	var fresh := CityDataView.create_mesh(city, CityViewMode.Mode.LAND_VALUE, true)
	assert(map.data_view_mesh.surface_get_arrays(0) == fresh.surface_get_arrays(0))
	mesh = map.data_view_mesh
	map.clear_data_view()
	data[3 * 16 + 3] &= ~4
	assert(flags.set_decoded_payload(data))
	city.resync_mirrors(PackedStringArray(["XBIT"]))
	map.set_data_view(city, CityViewMode.Mode.LAND_VALUE)
	assert(map.data_view_mesh != mesh, "Water edits invalidate inactive clipped geometry")
	fresh = CityDataView.create_mesh(city, CityViewMode.Mode.LAND_VALUE, true)
	assert(map.data_view_mesh.surface_get_arrays(0) == fresh.surface_get_arrays(0))
	map.free()

	# A large stepped map exceeds the retained-array budget.
	var doc := EmptyCityTemplate.create(512)
	var alt := doc.find_chunk("ALTM").decoded_payload.duplicate()
	for x in 512:
		for y in 512:
			BinaryData.write_u16_be(alt, (x * 512 + y) * 2, 16 if (x + y) % 2 else 0)
	assert(doc.find_chunk("ALTM").set_decoded_payload(alt))
	city = CityState.from_document(doc)
	map = CityMapControl.new()
	map.size = Vector2(1280, 720)
	root.add_child(map)
	map.set_data_view(city, CityViewMode.Mode.LAND_VALUE)
	retained = weakref(map.data_view_mesh)
	assert(CityDataView.mesh_array_bytes(map.data_view_mesh) > CityMapLayers.RETAINED_GEOMETRY_BYTES)
	map.clear_data_view()
	assert(retained.get_ref() == null, "Oversized geometry is released on close")
	map.free()
	print("PASS: inactive data geometry reuse, invalidation, city lifetime, and memory bound")
	quit()
