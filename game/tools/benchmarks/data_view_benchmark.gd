extends SceneTree


## CPU geometry and texture-update timings. Use --audio-driver Dummy.
func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for edge in [128, 256, 384, 512]:
		var document := EmptyCityTemplate.create(edge)
		document.enable_full_resolution_maps()
		var city := CityState.from_document(document)
		city.altitude_words.fill(16)
		var view := CityMapControl.new()
		view.size = Vector2(1280, 720)
		root.add_child(view)
		var start := Time.get_ticks_usec()
		view.set_data_view(city, "land_value")
		var mesh := view.data_view_mesh
		print("data_view edge=%d initial_ms=%.2f vertices=%d" % [edge, (Time.get_ticks_usec() - start) / 1000.0, mesh.surface_get_array_len(0)])
		var refresh_usec := 0

		for iteration in 20:
			var chunk := document.find_chunk("XVAL")
			var data := chunk.decoded_payload.duplicate()
			data[edge * (edge - 2) + edge - 2] = iteration
			chunk.set_decoded_payload(data)
			start = Time.get_ticks_usec()
			view.set_data_view(city, "land_value")
			refresh_usec += Time.get_ticks_usec() - start
			assert(view.data_view_mesh == mesh)

		print("data_view edge=%d refresh_ms=%.4f mesh_reused=true" % [edge, refresh_usec / 20000.0])
		view.free()

	quit()
