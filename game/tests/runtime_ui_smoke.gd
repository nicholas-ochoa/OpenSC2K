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
		if relative_path == "CITIES/ISLAND.SC2":
			var patch_point := Vector2i(-1, -1)
			for x in range(8, CityState.MAP_SIZE - 8):
				if patch_point.x >= 0:
					break
				for y in range(8, CityState.MAP_SIZE - 8):
					if (
						loaded_city.building_id(x, y) == 0
						and loaded_city.terrain_id(x, y) == 0
						and not loaded_city.is_water(x, y)
						and loaded_city.zone_id(x, y) == 0
					):
						patch_point = Vector2i(x, y)
						break
			if patch_point.x < 0:
				push_error("Cannot find clear terrain for the regional edit smoke test")
				main.queue_free()
				quit(2)
				return
			main.set("selected_group", 9)
			main.set("selected_subtool", 0)
			var patch_path: Array[Vector2i] = [patch_point]
			main.call(
				"_apply_map_selection",
				patch_point,
				patch_point,
				patch_path,
				false
			)
			var patch_command: Dictionary = main.get("last_edit_command")
			var view_size := int(main.call("_city_view_size"))
			var expected_signature: Array = main.call(
				"_static_signature_for_mode", "city", view_size
			)
			if (
				patch_command.get("command_type", "") != "zone"
				or main.get("static_render_thread") != null
				or main.get("static_visual_signature") != expected_signature
			):
				push_error("A bounded city edit did not use the exact regional refresh")
				main.queue_free()
				quit(2)
				return
			main.call("_undo_last_edit")
			if (
				main.get("static_render_thread") != null
				or loaded_city.zone_id(patch_point.x, patch_point.y) != 0
			):
				push_error("Regional city-edit Undo did not restore the prior view")
				main.queue_free()
				quit(2)
				return
			var funds_before_scurk := loaded_city.funds()
			main.call("_open_scurk_place_print")
			await process_frame
			var place_print: ScurkPlacePrintControl = main.get("scurk_place_print")
			if place_print == null:
				push_error("SCURK Place & Print control is missing")
				main.queue_free()
				quit(2)
				return
			var place_list: ItemList = place_print.object_list
			if (
				not place_print.visible
				or place_list == null
				or place_list.item_count != 24
				or not place_print.select_tile(0x0d)
			):
				push_error("Cannot open the SCURK Place & Print object selector")
				main.queue_free()
				quit(2)
				return
			var place_preview: Array[Vector2i] = main.get("map_view").point_preview_tiles(
				patch_point
			)
			main.call(
				"_apply_map_selection",
				patch_point,
				patch_point,
				patch_path,
				false
			)
			var scurk_command: Dictionary = main.get("last_edit_command")
			if (
				place_preview != [patch_point]
				or scurk_command.get("command_type", "") != "scurk_place_object"
				or loaded_city.building_id(patch_point.x, patch_point.y) != 0x0d
				or loaded_city.funds() != funds_before_scurk
			):
				push_error("SCURK Place & Print did not place the previewed object")
				main.queue_free()
				quit(2)
				return
			main.call("_undo_scurk_place")
			if loaded_city.building_id(patch_point.x, patch_point.y) != 0:
				push_error("SCURK Place & Print Undo did not restore the city")
				main.queue_free()
				quit(2)
				return
			main.call("_redo_scurk_place")
			if loaded_city.building_id(patch_point.x, patch_point.y) != 0x0d:
				push_error("SCURK Place & Print Redo did not restore the object")
				main.queue_free()
				quit(2)
				return
			main.call("_undo_scurk_place")
			main.call("_close_scurk_place_print")
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
