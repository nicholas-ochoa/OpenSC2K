extends "res://tools/benchmarks/fixture_paths.gd"
## The cost of the debug record tables on one city: the first refresh, a sort,
## a search, and the frame times while each table is open. Run without
## --headless and with --audio-driver Dummy:
##   godot --audio-driver Dummy --path game --script res://tools/benchmarks/debug_table_benchmark.gd -- [city] [image folder]

const TABS := ["MicroSims", "Objects", "Tiles", "State"]
const FRAMES := 120


func _benchmark_initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var city_path := input_path(large_city_path(512))
	var image_folder := arguments[1] if arguments.size() > 1 else ""
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

	main.frame.select_speed(GameSpeedController.Speed.PAUSED)
	main.debug_overlay.toggle()
	var tabs: TabContainer = main.debug_overlay._tabs

	for tab_name in TABS:
		var table := tabs.get_node(tab_name) as DebugRecordTable
		# opening the tab refreshes it
		var started := Time.get_ticks_usec()
		tabs.current_tab = tabs.get_tab_idx_from_control(table)
		await process_frame
		var refresh_ms := (Time.get_ticks_usec() - started) / 1000.0
		await process_frame
		started = Time.get_ticks_usec()
		table.sort_by(table._titles.size() - 1)
		var sort_ms := (Time.get_ticks_usec() - started) / 1000.0
		started = Time.get_ticks_usec()
		table.search.text = "police"
		table._apply()
		var search_ms := (Time.get_ticks_usec() - started) / 1000.0
		table.search.text = ""
		table.sort_by(-1)
		table.table._v_scroll.value = table.table._v_scroll.max_value
		var frame_ms := await _frames()
		print("DEBUGTABLE tab=%s records=%d refresh_ms=%.1f sort_ms=%.1f search_ms=%.1f frame_avg_ms=%.2f frame_max_ms=%.2f" % [
			tab_name, table.row_count(), refresh_ms, sort_ms, search_ms, frame_ms.x, frame_ms.y])

		if not image_folder.is_empty():
			table.table._v_scroll.value = 0
			table.table.set_expanded(table.shown_ids()[0], true) if table.row_count() > 0 else null
			await _frames()
			DirAccess.make_dir_recursive_absolute(image_folder)
			root.get_texture().get_image().save_png(image_folder.path_join("table_%s.png" % tab_name.to_lower()))

	main.debug_overlay.toggle()
	main.queue_free()
	await process_frame
	quit()


# the mean and the slowest frame, in milliseconds
func _frames() -> Vector2:
	var previous := Time.get_ticks_usec()
	var started := previous
	var slowest := 0.0

	for _frame in FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		slowest = maxf(slowest, (now - previous) / 1000.0)
		previous = now

	return Vector2((previous - started) / 1000.0 / FRAMES, slowest)


static func fixture_paths() -> PackedStringArray:
	var paths := PackedStringArray(["res://main.tscn", large_city_path(512)])
	paths.append_array(application_paths())

	return paths
