extends SceneTree

const GameSpeed = preload("res://src/simulation/game_speed_controller.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var user_args := OS.get_cmdline_user_args()
	if user_args.is_empty():
		push_error("runtime_ui_smoke.gd needs the reference directory")
		quit(2)
		return
	var reference_root := str(user_args[0])
	var packed_scene := load("res://main.tscn") as PackedScene
	if packed_scene == null:
		push_error("Cannot load the main scene")
		quit(2)
		return
	var main := packed_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	for relative_path in [
		"CITIES/ISLAND.SC2",
		"CITIES/CAPEQUES.SC2",
		"SCENARIO/CHARLEST.SCN",
	]:
		var city_path := reference_root.path_join(relative_path).simplify_path()
		main.call("_load_city", city_path)
		await process_frame
		await process_frame
		var document: Sc2File = main.get("current_document")
		if (
			main.get("city") == null
			or document == null
			or document.source_path.simplify_path() != city_path
		):
			push_error("Cannot load the smoke-test city: %s" % relative_path)
			main.queue_free()
			quit(2)
			return
		var loaded_city: CityState = main.get("city")
		var date_label := main.get("title_stats_label") as Label
		var money_label := main.get("title_money_label") as Label
		var city_label := main.get("city_label") as Label
		var rci_graph: RciStatusControl = main.get("status_rci_graph")
		var expected_date := "%02d/%02d/%04d" % [
			loaded_city.current_month(),
			loaded_city.current_day(),
			loaded_city.current_year(),
		]
		var expected_money := "$%s" % main.call(
			"_format_number", loaded_city.funds()
		)
		if (
			date_label.text != expected_date
			or money_label.text != expected_money
			or city_label.horizontal_alignment != HORIZONTAL_ALIGNMENT_LEFT
			or rci_graph.demand != loaded_city.rci_demand()
			or not rci_graph.demand_available
		):
			push_error("Menu or status metrics are not synchronized for %s" % relative_path)
			main.queue_free()
			quit(2)
			return
		loaded_city.set_music_enabled(false)
		loaded_city.set_sound_enabled(false)
		var scenario_dialog := main.get("scenario_dialog") as Window
		if scenario_dialog != null:
			scenario_dialog.hide()
		for menu_id in range(5):
			main.call("_on_speed_menu", menu_id)
			var controller: GameSpeedController = main.get("speed_controller")
			if controller.speed != menu_id + GameSpeed.Speed.PAUSED:
				push_error("Speed menu item %d selected the wrong speed" % menu_id)
				main.queue_free()
				quit(2)
				return
		main.call("_select_speed", GameSpeed.Speed.AFRICAN_SWALLOW)
		for tick in range(90):
			main.call("_process", 0.2)
			if bool(main.get("annual_budget_pending")):
				main.call("_commit_budget")
				var budget_dialog := main.get("budget_dialog") as Window
				budget_dialog.hide()
			if bool(main.get("military_proposal_pending")):
				main.call("_decline_military_proposal")
				var military_dialog := main.get("military_dialog") as Window
				military_dialog.hide()
		main.call("_select_speed", GameSpeed.Speed.PAUSED)

	for mode in ["underground", "city"]:
		main.call("_set_overlay", mode)
		await process_frame
	for layer in ["buildings", "networks", "water", "trees", "zones", "signs"]:
		main.call("_set_surface_visibility", false, layer)
		main.call("_set_surface_visibility", true, layer)
	main.call("_set_overlay", "underground")
	main.call("_set_underground_pipes_visible", false)
	main.call("_set_underground_pipes_visible", true)
	main.call("_set_overlay", "city")

	for entry in [
		["_open_ordinance_window", "ordinance_window"],
		["_open_population_window", "population_window"],
		["_open_industry_window", "industry_window"],
		["_open_graph_window", "graph_window"],
		["_open_simnation_window", "simnation_window"],
		["_open_city_map_window", "city_map_window"],
		["_on_newspaper_menu", "newspaper_dialog"],
		["_open_manual_budget", "budget_dialog"],
		["_open_settings_dialog", "settings_dialog"],
		["_open_about_dialog", "about_dialog"],
	]:
		var method: String = entry[0]
		if method == "_on_newspaper_menu":
			main.call(method, 0)
		else:
			main.call(method)
		await process_frame
		var opened_window := main.get(entry[1]) as Window
		if opened_window != null:
			opened_window.hide()
		await process_frame

	main.call("_open_query", Vector2i(64, 64))
	await process_frame
	main.call("_close_query", false)
	for group in range(18):
		main.call("_select_tool_group", group)
		await process_frame

	var overflow_text := "Overflow tooltip validation ".repeat(40)
	for property in [
		"status_label",
		"status_population_label",
		"status_weather_label",
		"status_reports_label",
	]:
		var section := main.get(property) as Label
		var original_text := section.text
		section.text = overflow_text
		main.call("_sync_overflow_tooltip", section)
		if section.tooltip_text.is_empty():
			push_error("Status section %s does not expose overflow text" % property)
			main.queue_free()
			quit(2)
			return
		section.text = original_text
	main.call("_refresh_status_tooltips")

	main.call("_open_scurk_dialog")
	await process_frame
	var scurk_editor := main.get("scurk_editor") as Control
	var object_list := scurk_editor.get("object_list") as ItemList
	if not scurk_editor.visible or object_list.item_count != 499:
		push_error("Cannot open the complete SCURK object catalog")
		main.queue_free()
		quit(2)
		return
	# Hide the editor during the catalog loop to avoid rebuilding 1,497 preview
	# sets. Separate preview tests cover the View Windows.
	scurk_editor.hide()
	for item_index in range(object_list.item_count):
		scurk_editor.call("_on_object_selected", item_index)
		for view in range(3):
			scurk_editor.call("_select_view", view)
	main.queue_free()
	await process_frame
	print("PASS: runtime UI smoke")
	quit()
