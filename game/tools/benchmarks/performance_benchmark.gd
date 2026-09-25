extends "res://tools/benchmarks/fixture_paths.gd"

@warning_ignore_start("integer_division")

const Sc2Document = preload("res://src/formats/sc2_file.gd")
const CityModel = preload("res://src/model/city_state.gd")
const Palette = preload("res://src/assets/sc2_palette.gd")
const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")
const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const RenderJob = preload("res://src/view/city_render_job.gd")
const DynamicSpriteCanvas = preload("res://src/view/city_dynamic_sprite_canvas.gd")
const Simulation = preload("res://src/simulation/core/simulation_engine.gd")
const Random = preload("res://src/simulation/random/sim_random.gd")
const LfsrRandom = preload("res://src/simulation/random/sim_lfsr_random.gd")
const DEFAULT_CITY_FILE := "res://tests/fixtures/cities/generated-128.SC2"
const CAPTURE_WARMUP := 5
const CAPTURE_SAMPLES := 40


func _benchmark_initialize() -> void:
	var reference_root := reference_path()
	var city_file := DEFAULT_CITY_FILE
	var arguments := OS.get_cmdline_user_args()

	if not arguments.is_empty():
		city_file = arguments[0]

	print("benchmark_city: %s" % city_file)
	var city := CityModel.from_document(
		Sc2Document.load_path(city_file)
	)
	var index_palette := Palette.index_encoding()
	var sprites := SpriteArchive.load_path(
		reference_root.path_join("DATA/LARGE.DAT")
	)

	if not city.is_valid() or not index_palette.is_valid() or not sprites.is_valid():
		printerr("Cannot load the %s benchmark input." % city_file)
		quit(1)

		return

	report_metadata({"map_size": city.map_size, "full_resolution": city.document.full_resolution_maps(),
		"capture_warmup": CAPTURE_WARMUP, "capture_samples": CAPTURE_SAMPLES, "other_workloads": "see measurement labels"})

	var started := Time.get_ticks_usec()
	var asset_errors := IsometricStaticVisuals.validate_assets(city, sprites)
	_print_measurement("asset_validation", started, asset_errors.is_empty())

	if not asset_errors.is_empty():
		printerr(asset_errors[0])
		quit(1)

		return

	started = Time.get_ticks_usec()
	var initial := Renderer.create_image(
		city, index_palette, sprites, Renderer.VIEW_LARGE, 0, false, true, true, false
	)
	_print_measurement("initial_index_render", started, initial.ok)

	if not initial.ok:
		printerr(initial.error)
		quit(1)

		return

	started = Time.get_ticks_usec()
	var initial_texture := ImageTexture.create_from_image(initial.image)
	print(
		"static_texture_upload: %d us; format=%d; bytes=%d"
		% [
			Time.get_ticks_usec() - started,
			initial.image.get_format(),
			initial.image.get_data_size(),
		]
	)
	initial_texture = null

	var job := RenderJob.new()
	job.city_snapshot = city
	job.index_palette = index_palette
	job.sprites = sprites
	started = Time.get_ticks_usec()
	var rebuilt := job.run()
	_print_measurement("warm_worker_render", started, rebuilt.ok)
	if not rebuilt.ok:
		printerr("%s worker render failed: %s" % [city_file, rebuilt.error])
		quit(1)
		return

	var edit_city := CityModel.from_document(city.document.duplicate_document())
	var edit_point := Vector2i(-1, -1)

	for x in range(8, CityModel.MAP_SIZE - 8):
		if edit_point.x >= 0:
			break

		for y in range(8, CityModel.MAP_SIZE - 8):
			if (
				edit_city.building_id(x, y) == BuildingTileIds.EMPTY
				and edit_city.terrain_id(x, y) == 0
				and not edit_city.is_water(x, y)
			):
				edit_point = Vector2i(x, y)
				break

	if edit_point.x < 0 or not edit_city.set_building_id(
		edit_point.x, edit_point.y, BuildingTileIds.SMALL_PARK
	):
		printerr("Cannot prepare the regional-render benchmark edit.")
		quit(1)

		return

	started = Time.get_ticks_usec()
	var patched := Renderer.patch_static_image(
		initial.image,
		edit_city,
		index_palette,
		sprites,
		PackedInt32Array([edit_city.index_of(edit_point.x, edit_point.y)]),
		Renderer.VIEW_LARGE,
		0
	)
	var patch_usec := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var edit_full := Renderer.create_image(
		edit_city, index_palette, sprites, Renderer.VIEW_LARGE, 0,
		false, true, false, false
	)
	var edit_full_usec := Time.get_ticks_usec() - started
	print(
		"regional_edit_render: %d us; full=%d us; area=%d; tiles=%d; exact=%s"
		% [
			patch_usec,
			edit_full_usec,
			patched.output_rect.get_area() if patched.ok else 0,
			patched.tiles_drawn if patched.ok else 0,
			patched.ok and edit_full.ok
				and patched.image.get_data() == edit_full.image.get_data(),
		]
	)

	if not patched.ok or not edit_full.ok or patched.image.get_data() != edit_full.image.get_data():
		printerr("Regional render does not match the complete city image.")
		quit(1)

		return

	started = Time.get_ticks_usec()
	var edit_occlusion := Renderer.patch_static_occlusion_commands(
		rebuilt.occlusion_commands,
		edit_city,
		sprites,
		PackedInt32Array([edit_city.index_of(edit_point.x, edit_point.y)]),
		Renderer.VIEW_LARGE
	)
	var edit_occlusion_patch_usec := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var edit_full_occlusion := Renderer.static_occlusion_commands(
		edit_city, sprites, Renderer.VIEW_LARGE
	)
	print(
		"regional_edit_occlusion: %d us; full=%d us; commands=%d; exact=%s"
		% [
			edit_occlusion_patch_usec,
			Time.get_ticks_usec() - started,
			edit_occlusion.size(),
			_static_command_values(edit_occlusion) == _static_command_values(edit_full_occlusion),
		]
	)

	if _static_command_values(edit_occlusion) != _static_command_values(edit_full_occlusion):
		printerr("Regional occlusion commands do not match the complete list.")
		quit(1)

		return

	started = Time.get_ticks_usec()
	var edit_occlusion_grid := Renderer.build_occlusion_grid(edit_occlusion, 1)
	print(
		"regional_edit_occlusion_grid: %d us; cells=%d"
		% [Time.get_ticks_usec() - started, edit_occlusion_grid.size()]
	)

	var points := PackedVector2Array()

	for x in range(0, CityModel.MAP_SIZE, 8):
		for y in range(0, CityModel.MAP_SIZE, 8):
			var polygon := Renderer.tile_polygon(city, x, y)
			points.append(
				(polygon[0] + polygon[1] + polygon[2] + polygon[3]) * 0.25
			)

	started = Time.get_ticks_usec()
	var checksum := Vector2i.ZERO

	for point in points:
		checksum += Renderer.screen_to_tile(city, point)

	var elapsed := Time.get_ticks_usec() - started
	print(
		"map_hit_test: %d us for %d points; checksum=%s"
		% [elapsed, points.size(), checksum]
	)
	started = Time.get_ticks_usec()

	for _signature_index in 40:
		Renderer.static_visual_signature(city)

	print("static_signature_40: %d us" % (Time.get_ticks_usec() - started))
	_measure_captures(city, index_palette, sprites)
	started = Time.get_ticks_usec()

	for dynamic_index in 40:
		Renderer.dynamic_draw_commands(city, sprites, Renderer.VIEW_LARGE, dynamic_index)

	print("dynamic_layer_40: %d us" % (Time.get_ticks_usec() - started))
	var scenario_city := CityModel.from_document(
		Sc2Document.load_path(reference_root.path_join("SCENARIO/CHARLEST.SCN"))
	)
	var scenario_simulation := Simulation.new(scenario_city, 1, 7, 13)
	var scenario_day := scenario_simulation.advance_day()
	if not scenario_day.ok:
		printerr("CHARLEST.SCN initial day failed: %s" % scenario_day.error)
		quit(1)
		return


	for _hurricane_tick in 30:
		var hurricane_tick := scenario_simulation.advance_disaster_tick()

		if not hurricane_tick.ok:
			printerr("Charleston hurricane benchmark failed: %s" % hurricane_tick.error)
			quit(1)

			return

	var hurricane_commands := Renderer.dynamic_draw_commands(
		scenario_city, sprites, Renderer.VIEW_LARGE, 30
	)
	var hurricane_visuals: Array[CityDynamicVisual] = []
	var hurricane_images := {}

	for command in hurricane_commands:
		if command.overlay < 0:
			continue

		var image_key := "%d:%d" % [command.sprite_id, int(command.flip)]
		var marker_image: Image = hurricane_images.get(image_key) as Image

		if marker_image == null:
			var marker := sprites.find_sprite(command.sprite_id)

			if marker == null:
				continue

			var marker_result := marker.create_image(index_palette)

			if not marker_result.ok:
				continue

			marker_image = marker_result.image

			if command.flip:
				marker_image = marker_image.duplicate()
				marker_image.flip_x()

			hurricane_images[image_key] = marker_image

		var visual := CityDynamicVisual.new(null, Vector2(command.position), Vector2(marker_image.get_size()))
		visual.image = marker_image
		visual.special_overlay = true
		visual.batch_cache_key = image_key + ":" + str(command.position)
		hurricane_visuals.append(visual)

	started = Time.get_ticks_usec()
	var hurricane_batch_cache: Dictionary[String, CityDynamicVisual] = {}
	var hurricane_batches := DynamicSpriteCanvas.batch_special_visuals(
		hurricane_visuals, hurricane_batch_cache
	)
	var hurricane_cold_batch_usec := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()

	for _batch_index in 40:
		hurricane_batches = DynamicSpriteCanvas.batch_special_visuals(
			hurricane_visuals, hurricane_batch_cache
		)

	print(
		"hurricane_batch: cold=%d us; warm_40=%d us; visuals=%d; batches=%d"
		% [
			hurricane_cold_batch_usec,
			Time.get_ticks_usec() - started,
			hurricane_visuals.size(),
			hurricane_batches.size(),
		]
	)
	var dynamic_canvas := DynamicSpriteCanvas.new()
	var canvas_visuals: Array[CityDynamicVisual] = []

	for command in hurricane_commands:
		var visual := CityDynamicVisual.new(null, Vector2(command.position))
		visual.depth_order = command.depth_order
		visual.record = command.record
		visual.shadow = command.shadow
		canvas_visuals.append(visual)

	started = Time.get_ticks_usec()

	for _canvas_index in 40:
		dynamic_canvas.set_visuals(canvas_visuals, 1.0, Vector2.ZERO)

	print(
		"hurricane_dynamic_canvas_40: %d us; commands=%d; ok=%s"
		% [
			Time.get_ticks_usec() - started,
			hurricane_commands.size(),
			scenario_day.ok,
		]
	)
	dynamic_canvas.free()

	var split_disaster_city := CityModel.from_document(city.document.duplicate_document())
	var split_random := Random.new(1)
	var split_lfsr := LfsrRandom.new(1)
	started = Time.get_ticks_usec()

	for _disaster_index in 40:
		var fire_tick := DisasterMapFireFlood.run_fire(
			split_disaster_city, split_random, split_lfsr
		)
		var dispatch_tick := DisasterMapScanDispatch.run_dispatch(
			split_disaster_city, split_random, split_lfsr
		)
		if not fire_tick.ok or not dispatch_tick.ok:
			printerr("%s split disaster tick %d failed: %s %s" % [city_file, _disaster_index, fire_tick.error, dispatch_tick.error])
			quit(1)
			return

	print(
		"split_disaster_map_40: %d us; ok=true"
		% [Time.get_ticks_usec() - started]
	)
	var unified_disaster_city := CityModel.from_document(city.document.duplicate_document())
	var unified_random := Random.new(1)
	var unified_lfsr := LfsrRandom.new(1)
	started = Time.get_ticks_usec()

	for _disaster_index in 40:
		var unified_tick := DisasterMapScanDispatch.run_all(
			unified_disaster_city, unified_random, unified_lfsr, 0
		)
		if not unified_tick.ok:
			printerr("%s unified disaster tick %d failed: %s" % [city_file, _disaster_index, unified_tick.error])
			quit(1)
			return

	print(
		"unified_disaster_map_40: %d us; ok=true"
		% [Time.get_ticks_usec() - started]
	)

	var simulation_city := CityModel.from_document(city.document.duplicate_document())
	var simulation := Simulation.new(simulation_city, 1, 1, 1)
	var simulation_started := Time.get_ticks_usec()
	var slowest_day_usec := 0
	var slowest_actions := PackedStringArray()

	for _day in 25:
		started = Time.get_ticks_usec()
		var day := simulation.advance_day()
		var day_usec := Time.get_ticks_usec() - started

		if not day.ok:
			printerr("%s simulation benchmark failed: %s" % [city_file, day.error])
			quit(1)

			return

		if day_usec > slowest_day_usec:
			slowest_day_usec = day_usec
			slowest_actions = day.applied

	print(
		"simulation_25_days: %d us; slowest_day=%d us; actions=%s"
		% [
			Time.get_ticks_usec() - simulation_started,
			slowest_day_usec,
			", ".join(slowest_actions),
		]
	)

	started = Time.get_ticks_usec()

	for tick in 40:
		var moving := simulation.advance_moving_things(tick * 200)

		if not moving.ok:
			printerr("Capeques moving benchmark failed: %s" % moving.error)
			quit(1)

			return

	print("moving_40_ticks: %d us" % (Time.get_ticks_usec() - started))
	quit()


func _print_measurement(label: String, started: int, ok: bool) -> void:
	print("%s: %d us; ok=%s" % [label, Time.get_ticks_usec() - started, ok])


func _measure_captures(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive) -> void:
	var controller := GameSpeedController.new(SimulationEngine.new(city, 123, 456, 789))
	var regions := CityRegionCache.new()
	var samples := {"full_image_capture": [], "region_configure_capture": [], "simulation_capture": []}

	for index in CAPTURE_WARMUP + CAPTURE_SAMPLES:
		var started := Time.get_ticks_usec()
		var snapshot := CityState.from_document(city.document.duplicate_document(true))
		snapshot.visible_altitude_levels = city.visible_altitude_levels
		var elapsed := Time.get_ticks_usec() - started
		if index >= CAPTURE_WARMUP:
			samples.full_image_capture.append(elapsed)

		started = Time.get_ticks_usec()
		regions.configure(city, palette, sprites, [index], Renderer.VIEW_LARGE,
			CityViewMode.Mode.CITY, CityViewFilter.DEFAULT_VISIBILITY, true, true)
		elapsed = Time.get_ticks_usec() - started
		if index >= CAPTURE_WARMUP:
			samples.region_configure_capture.append(elapsed)

		started = Time.get_ticks_usec()
		var simulation_snapshot := SimulationSnapshot.capture(controller, null)
		elapsed = Time.get_ticks_usec() - started
		if index >= CAPTURE_WARMUP:
			samples.simulation_capture.append(elapsed)
		simulation_snapshot = null

	regions.close()
	for name in samples:
		var values: Array = samples[name]
		values.sort()
		print("%s: samples=%d; median=%d us; min=%d us; max=%d us" % [
			name, values.size(), values[values.size() / 2], values[0], values[-1]])


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([
		input_path(DEFAULT_CITY_FILE), reference_path("DATA/LARGE.DAT"),
		reference_path("SCENARIO/CHARLEST.SCN"),
	])


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
