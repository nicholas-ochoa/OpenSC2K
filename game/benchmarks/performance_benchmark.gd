extends SceneTree

const Sc2Document = preload("res://src/formats/sc2_file.gd")
const CityModel = preload("res://src/model/city_state.gd")
const Palette = preload("res://src/assets/sc2_palette.gd")
const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")
const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const RenderJob = preload("res://src/view/city_render_job.gd")
const Simulation = preload("res://src/simulation/simulation_engine.gd")
const DisasterMap = preload("res://src/simulation/disaster_map_phase.gd")
const Random = preload("res://src/simulation/sim_random.gd")
const LfsrRandom = preload("res://src/simulation/sim_lfsr_random.gd")


func _init() -> void:
	var reference_root := ProjectSettings.globalize_path("res://../references")
	var city := CityModel.from_document(
		Sc2Document.load_path(reference_root.path_join("CITIES/CAPEQUES.SC2"))
	)
	var index_palette := Palette.index_encoding()
	var sprites := SpriteArchive.load_path(
		reference_root.path_join("DATA/LARGE.DAT")
	)
	if not city.is_valid() or not index_palette.is_valid() or not sprites.is_valid():
		printerr("Cannot load the Capeques benchmark input.")
		quit(1)
		return

	var started := Time.get_ticks_usec()
	var asset_errors := Renderer.validate_assets(city, sprites)
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

	var job := RenderJob.new()
	job.city_snapshot = city
	job.index_palette = index_palette
	job.sprites = sprites
	started = Time.get_ticks_usec()
	var rebuilt := job.run()
	_print_measurement("warm_worker_render", started, rebuilt.ok)

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
	started = Time.get_ticks_usec()
	for dynamic_index in 40:
		Renderer.dynamic_draw_commands(city, sprites, Renderer.VIEW_LARGE, dynamic_index)
	print("dynamic_layer_40: %d us" % (Time.get_ticks_usec() - started))

	var split_disaster_city := CityModel.from_document(city.document.duplicate_document())
	var split_random := Random.new(1)
	var split_lfsr := LfsrRandom.new(1)
	var split_ok := true
	started = Time.get_ticks_usec()
	for _disaster_index in 40:
		var fire_tick := DisasterMap.run_fire(
			split_disaster_city, split_random, split_lfsr
		)
		var dispatch_tick := DisasterMap.run_dispatch(
			split_disaster_city, split_random, split_lfsr
		)
		split_ok = split_ok and fire_tick.ok and dispatch_tick.ok
	print(
		"split_disaster_map_40: %d us; ok=%s"
		% [Time.get_ticks_usec() - started, split_ok]
	)
	var unified_disaster_city := CityModel.from_document(city.document.duplicate_document())
	var unified_random := Random.new(1)
	var unified_lfsr := LfsrRandom.new(1)
	var unified_ok := true
	started = Time.get_ticks_usec()
	for _disaster_index in 40:
		var unified_tick := DisasterMap.run_all(
			unified_disaster_city, unified_random, unified_lfsr, 0
		)
		unified_ok = unified_ok and unified_tick.ok
	print(
		"unified_disaster_map_40: %d us; ok=%s"
		% [Time.get_ticks_usec() - started, unified_ok]
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
			printerr("Capeques simulation benchmark failed: %s" % day.error)
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
	quit(0 if rebuilt.ok else 1)


func _print_measurement(label: String, started: int, ok: bool) -> void:
	print("%s: %d us; ok=%s" % [label, Time.get_ticks_usec() - started, ok])
