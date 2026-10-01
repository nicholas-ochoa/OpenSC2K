extends "res://tools/benchmarks/fixture_paths.gd"
## Frame pacing of each debug view on one city, with a window image of each.
## Run without --headless and with --audio-driver Dummy:
##   godot --audio-driver Dummy --path game --script res://tools/benchmarks/debug_view_benchmark.gd -- [city] [image folder]
## CITY_BENCH_SECONDS sets the time of each case (default 4). CITY_BENCH_ZOOM
## sets the zoom (default 1). The debug mode choice is not saved.

@warning_ignore_start("integer_division")

const Layer = DebugTileLayers.Layer
const CASES: Array = [
	["baseline", {}],
	["zone_type", { "tile_layer": Layer.ZONE_TYPE }],
	["building_id", { "tile_layer": Layer.BUILDING_ID }],
	["power_grids", { "tile_layer": Layer.POWER_GRIDS }],
	["water_networks", { "tile_layer": Layer.WATER_NETWORKS }],
	["unusual_values", { "tile_layer": Layer.UNUSUAL_VALUES }],
	["traffic_raw", { "tile_layer": Layer.TRAFFIC }],
	["changed_previous_day", { "tile_layer": Layer.CHANGED_TILES, "baseline": DebugViewState.ChangeBaseline.PREVIOUS_DAY }],
	["tile_values", { "tile_layer": Layer.LAND_VALUE, "tile_values": true, "zoom": 4.0 }],
	["region_bounds", { "region_bounds": true, "region_repaints": true }],
	["occluders_sprites", { "occluders": true, "sprite_bounds": true }],
	["thing_paths", { "thing_paths": true }],
	["performance_hud", { "performance_hud": true }],
	["tile_grid", { "tile_grid": true, "zoom": 2.0 }],
	["draw_order", { "draw_order": true, "zoom": 4.0 }],
	["inspector", { "inspector": true }],
	["everything", {"tile_layer": Layer.POWER_GRIDS, "region_bounds": true, "region_repaints": true, "occluders": true,
		"sprite_bounds": true, "thing_paths": true, "performance_hud": true, "inspector": true}],
]


func _benchmark_initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("The debug view benchmark needs a window")
		quit(1)

		return

	var arguments := OS.get_cmdline_user_args()
	var city_path := input_path(large_city_path(512))
	var image_folder := arguments[1] if arguments.size() > 1 else ""
	var seconds := float(OS.get_environment("CITY_BENCH_SECONDS")) if OS.has_environment("CITY_BENCH_SECONDS") else 4.0
	var base_zoom := float(OS.get_environment("CITY_BENCH_ZOOM")) if OS.has_environment("CITY_BENCH_ZOOM") else 1.0
	root.size = Vector2i(1920, 1080)
	var main := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	configure_application(main)
	root.add_child(main)

	if not main.asset_state.assets_ready:
		printerr(main.asset_state.asset_source.error)
		quit(1)

		return

	await process_frame
	main.main_menu.city_background.set_process(false)

	if not main.city_session.activate_document(Sc2File.load_path(city_path)):
		printerr("Cannot open ", city_path)
		quit(1)

		return

	main.debug_tools.set_debug_mode(true, false)
	main.menus.set_overlay(CityViewMode.Mode.CITY)
	await _wait_ready(main)

	for case: Array in CASES:
		await _measure(main, case[0], case[1], seconds, base_zoom, image_folder)

	if not image_folder.is_empty():
		await _capture_tabs(main, image_folder)

	main.debug_tools.set_debug_mode(false, false)
	main.queue_free()
	await process_frame
	quit()


func _measure(main: CityApplication, title: String, options: Dictionary, seconds: float, base_zoom: float, folder: String) -> void:
	var tools := main.debug_tools
	tools.state.reset()
	tools.set_tile_layer(options.get("tile_layer", Layer.NONE))

	if options.has("baseline"):
		tools.tile_views.set_baseline(options.baseline)

	for field in ["tile_values", "region_bounds", "region_repaints", "occluders", "sprite_bounds", "thing_paths",
			"performance_hud", "draw_order"]:
		tools.state.set(field, bool(options.get(field, false)))

	tools.tile_views.set_grid(bool(options.get("tile_grid", false)))

	tools._apply_view_change()
	main.map_view.zoom_factor = float(options.get("zoom", base_zoom))
	main.map_view.center_on_tile(Vector2i(main.document_state.city.map_size / 2, main.document_state.city.map_size / 2))

	if options.get("inspector", false):
		main.current_tool.select_tool_group(CityToolIds.Group.QUERY)
		main.current_tool.select_subtool(CityToolIds.Query.TILE_INSPECTOR)
		tools.pin_inspector(main.map_view.center_tile())
	else:
		main.current_tool.select_tool_group(CityToolIds.Group.RESIDENTIAL)

	main.frame.select_speed(GameSpeedController.Speed.CHEETAH)
	await _wait_ready(main)
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	var finish := previous + int(seconds * 1000000)
	var pan := 0

	while Time.get_ticks_usec() < finish:
		# pan back and forth so window and outline refreshes are part of the measurement
		pan += 1
		main.map_view.pan_screen(Vector2(4.0 if (pan / 60) % 2 == 0 else -4.0, 0.0))
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now

	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	samples.sort()
	var total := 0.0

	for value in samples:
		total += value

	print("DEBUGVIEW case=%s frames=%d avg_fps=%.1f p50_ms=%.2f p95_ms=%.2f p99_ms=%.2f max_ms=%.2f metrics=%s" % [title,
		samples.size(), samples.size() * 1000.0 / total, samples[samples.size() / 2], samples[int(samples.size() * 0.95)],
		samples[int(samples.size() * 0.99)], samples.back(), JSON.stringify(tools.metrics())])

	if not folder.is_empty():
		await process_frame
		DirAccess.make_dir_recursive_absolute(folder)
		root.get_texture().get_image().save_png(folder.path_join("%s.png" % title))

	if options.get("inspector", false):
		tools.unpin_inspector()


# window images of the Debug window tabs
func _capture_tabs(main: CityApplication, folder: String) -> void:
	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	main.debug_tools.steps.step_phase()
	main.debug_tools.mark_chunks()
	main.debug_tools.edits.set_misc_word(Sc2MiscLayout.BONDS, "1234")
	main.debug_overlay.toggle()
	var tabs: TabContainer = main.debug_overlay._tabs

	for tab_name in ["Steps", "Chunks", "MISC", "Scenario", "Actions"]:
		tabs.current_tab = tabs.get_tab_idx_from_control(tabs.get_node(tab_name))

		if tab_name == "Chunks":
			var chunks := tabs.get_node(tab_name) as CityDebugChunksTab
			chunks.refresh(true)
			chunks._selected = "MISC"
			chunks._show_page()

		var tab_started := Time.get_ticks_usec()
		var tab := tabs.get_node(tab_name)

		if tab is DebugWindowTab:
			(tab as DebugWindowTab).refresh(true)

		var refresh_usec := Time.get_ticks_usec() - tab_started
		var metrics_started := Time.get_ticks_usec()
		main.debug_overlay._refresh_metrics()
		print("DEBUGTAB %s refresh_ms=%.1f metrics_ms=%.1f" % [tab_name, refresh_usec / 1000.0,
			(Time.get_ticks_usec() - metrics_started) / 1000.0])

		for _frame in 20:
			await process_frame

		var slowest := 0.0
		var frames_started := Time.get_ticks_usec()
		var previous := frames_started

		for _frame in 100:
			await process_frame
			var now := Time.get_ticks_usec()
			slowest = maxf(slowest, (now - previous) / 1000.0)
			previous = now

		print("DEBUGTAB %s open avg_ms=%.2f max_ms=%.2f" % [tab_name, (previous - frames_started) / 100000.0, slowest])
		root.get_texture().get_image().save_png(folder.path_join("tab_%s.png" % tab_name.to_lower()))

	main.debug_overlay.toggle()
	main.debug_tools.edits.undo()


func _wait_ready(main: CityApplication) -> void:
	var deadline := Time.get_ticks_msec() + 60000

	while (main.render_caches.region_cache == null or not main.render_caches.region_cache.ready()) and Time.get_ticks_msec() < deadline:
		await process_frame

	for _frame in 10:
		await process_frame


static func fixture_paths() -> PackedStringArray:
	var paths := PackedStringArray(["res://main.tscn", large_city_path(512)])
	paths.append_array(application_paths())

	return paths
