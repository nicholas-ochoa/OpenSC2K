class_name ApplicationNewCity
extends RefCounted


const NewTerrain = preload("res://src/model/new_city_terrain.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const TerrainTools = preload("res://src/tools/landscape/terrain_command.gd")
const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func sync_new_city_workspace() -> void:
	app.city_workspace.set_editor_controls_visible(not app.new_city_dialog.visible)


func open_new_city_dialog() -> void:
	if not app.asset_state.assets_ready:
		return

	if app.new_city_dialog == null:
		return

	app.new_city_state.return_to_main_menu = app.main_menu != null and app.main_menu.visible

	if app.new_city_state.return_to_main_menu:
		app.main_menu.hide()

	app.new_city_dialog.preview_timer.stop()
	app.new_city_state.session.begin(app.tool_state.tool_random.state, app.simulation_state.nuisance_random.state)
	app.new_city_dialog.preview_view.texture = null
	app.new_city_dialog.landscape_background.texture = null
	app.new_city_dialog.compatibility_input.set_pressed_no_signal(false)
	app.new_city_dialog.compatibility_changed(false)
	app.new_city_dialog.native_maps_input.set_pressed_no_signal(true)
	app.new_city_dialog.city_name_input.text = "New City"
	app.new_city_dialog.mayor_name_input.text = app.preferences.default_mayor_name
	app.new_city_dialog.difficulty_input.select(0)
	app.new_city_dialog.year_input.select(0)
	app.new_city_dialog.reset_features()
	app.new_city_dialog.ocean_input.button_pressed = NewTerrain.DEFAULT_OCEAN
	app.new_city_dialog.river_input.button_pressed = NewTerrain.DEFAULT_RIVER
	app.new_city_dialog.hills_input.value = NewTerrain.DEFAULT_HILLS
	app.new_city_dialog.water_input.value = NewTerrain.DEFAULT_WATER
	app.new_city_dialog.trees_input.value = NewTerrain.DEFAULT_TREES
	_update_new_city_slider_labels()
	app.new_city_dialog.show()
	app.new_city_dialog.invalidate()
	app.new_city_dialog.city_name_input.grab_focus()
	app.new_city_dialog.city_name_input.select_all()


func reopen_terrain_dialog() -> void:
	if not app.tool_state.landscape_editor:
		return
	app.new_city_state.return_to_main_menu = false
	app.new_city_dialog.show()
	app.new_city_dialog.invalidate()


func schedule_new_city_preview(_value: Variant = null) -> void:
	_update_new_city_slider_labels()

	if app.new_city_dialog != null and app.new_city_dialog.visible:
		app.new_city_dialog.invalidate()


func _update_new_city_slider_labels() -> void:
	if app.new_city_dialog == null or app.new_city_dialog.hills_input == null:
		return

	app.new_city_dialog.hills_value.text = str(roundi(app.new_city_dialog.hills_input.value))
	app.new_city_dialog.water_value.text = str(roundi(app.new_city_dialog.water_input.value))
	app.new_city_dialog.trees_value.text = str(roundi(app.new_city_dialog.trees_input.value))


func _new_city_terrain_options() -> Dictionary:
	return OriginalCompatibility.terrain_options({
		"features": app.new_city_dialog.selected_features(),
		"smooth_slopes": true,
		"size": app.new_city_dialog.size_input.get_selected_id(),
		"native_maps": app.new_city_dialog.native_maps_input.button_pressed,
		"ocean": app.new_city_dialog.ocean_input.button_pressed,
		"river": app.new_city_dialog.river_input.button_pressed,
		"hills": roundi(app.new_city_dialog.hills_input.value),
		"water": roundi(app.new_city_dialog.water_input.value),
		"trees": roundi(app.new_city_dialog.trees_input.value),
	}, app.new_city_dialog.compatibility_input.button_pressed)


func make_new_city_preview() -> void:
	if app.new_city_state.preview_job != null:
		return
	app.new_city_dialog.preview_timer.stop()
	app.new_city_dialog.invalidate()
	app.audio_controller.play_sound_events([529], app.document_state.city == null or app.document_state.city.sound_enabled(),
			CityViewMode.Mode.CITY, IsometricRenderer.VIEW_LARGE)
	_generate_new_city_preview(true)


func _generate_new_city_preview(advance_seed: bool) -> bool:
	if app.asset_state.palette == null or not app.asset_state.palette.is_valid():
		app.new_city_dialog.preview_status.text = "Terrain preview is not available."

		return false

	if app.new_city_state.preview_job != null:
		return false
	app.new_city_state.preview_job = NewCityPreviewJob.new()
	app.new_city_state.preview_job.revision = app.new_city_dialog.generation_revision
	app.new_city_state.preview_job.view_size = NewCityPreviewJob.preview_view_size(
		app.new_city_dialog.size_input.get_selected_id(), app.new_city_dialog.size)
	var preview_sprites := (app.asset_state.large_sprites if app.new_city_state.preview_job.view_size == IsometricRenderer.VIEW_LARGE
			else app.asset_state.small_medium_sprites)
	var error := app.new_city_state.preview_job.start(app.new_city_state.session,
		app.asset_state.reference_root.path_join("DEFAULT.SC2"), _new_city_terrain_options(),
		app.asset_state.palette, preview_sprites, advance_seed)
	if error != OK:
		app.new_city_state.preview_job = null
		app.new_city_dialog.preview_status.text = "Cannot start terrain generation."
		return false
	app.new_city_dialog.set_generating(true)
	return true


func poll_new_city_preview() -> void:
	if app.new_city_state.preview_job == null or app.new_city_state.preview_job.thread.is_alive():
		return
	var job := app.new_city_state.preview_job
	var generated: NewCityTerrainSession.PreviewResult = job.thread.wait_to_finish()
	app.new_city_state.preview_job = null
	app.new_city_dialog.set_generating(false)
	if not app.new_city_dialog.visible or job.revision != app.new_city_dialog.generation_revision:
		return
	if not generated.ok:
		app.new_city_dialog.preview_status.text = "Cannot generate terrain: %s" % generated.error
		return
	app.new_city_state.session = job.session
	app.new_city_dialog.landscape_background.texture = ImageTexture.create_from_image(generated.landscape_image)
	app.new_city_dialog.preview_view.texture = ImageTexture.create_from_image(generated.minimap_image)
	app.new_city_dialog.candidate_valid = true
	app.new_city_dialog.done_button.disabled = false

	app.new_city_dialog.preview_status.text = (
		"Water: %s tiles   Trees: %s tiles   Height: %s–%s"
		% [
			app.interface.format_number(int(generated.terrain.water_tiles)),
			app.interface.format_number(int(generated.terrain.tree_tiles)),
			int(generated.terrain.minimum_altitude),
			int(generated.terrain.maximum_altitude),
		]
	)


func cancel_new_city() -> void:
	app.new_city_dialog.invalidate()
	app.new_city_dialog.preview_timer.stop()
	app.new_city_dialog.hide()
	app.new_city_state.session.clear()
	app.new_city_dialog.preview_view.texture = null
	var return_to_main_menu := app.new_city_state.return_to_main_menu
	app.new_city_state.return_to_main_menu = false

	if return_to_main_menu:
		app.interface.show_main_menu()


func create_new_city() -> void:
	if not app.new_city_dialog.candidate_valid:
		return
	if app.tool_state.landscape_editor:
		create_new_city_unchecked()
	else:
		app.city_files.request_city_exit("create_new_city")


func create_new_city_unchecked() -> void:
	app.new_city_dialog.preview_timer.stop()
	var terrain_options := _new_city_terrain_options()

	if not app.new_city_dialog.candidate_valid or not app.new_city_state.session.matches(terrain_options):
		return

	var template_path := app.asset_state.reference_root.path_join("DEFAULT.SC2")
	var difficulty := app.new_city_dialog.difficulty_input.get_selected_id()
	var starting_year := app.new_city_dialog.year_input.get_selected_id()
	var result := app.new_city_state.session.create_city(
		template_path,
		app.new_city_dialog.city_name_input.text,
		app.new_city_dialog.mayor_name_input.text,
		difficulty,
		starting_year,
		terrain_options,
		app.newspaper_state.session_state,
	)

	if not result.ok:
		if result.stage == "template":
			app.interface.show_error("Cannot load the default city: %s" % result.error)
		else:
			app.interface.show_error("Cannot create a new city: %s" % result.error)

		return

	app.tool_state.tool_random.state = int(result.process_state)
	app.simulation_state.nuisance_random.state = int(result.game_state)
	var document: Sc2File = result.document
	app.city_session.activate_document(
		document,
		null,
		"Created %s in %d on %s difficulty with generated terrain. Map view: %s."
		% [
			document.city_name(),
			starting_year,
			_difficulty_name(difficulty),
			CityViewMode.key(app.view_state.overlay_mode).capitalize(),
		],
	)

	_enter_landscape_editor()


func _difficulty_name(difficulty: int) -> String:
	match difficulty:
		1:
			return "Easy"
		2:
			return "Medium"
		3:
			return "Hard"
		_:
			return "Unknown"


func level_brush_active() -> bool:
	return app.tool_state.selected_group == 0 and app.tool_state.selected_subtool == TerrainTools.SUBTOOL_LEVEL


func _enter_landscape_editor() -> void:
	app.tool_state.landscape_editor = true
	app.frame.select_speed(GameSpeed.Speed.PAUSED)
	app.city_toolbar.set_landscape_editor(true)
	app.city_menu_bar.disasters_menu.disabled = true
	app.menus.set_overlay(CityViewMode.Mode.CITY)
	app.current_tool.select_tool_group(0)
	app.current_tool.select_subtool(2)
	app.status_label.text = "Landscape editor: terrain changes are free. Select Start City when ready."


func start_city() -> void:
	if not app.tool_state.landscape_editor or app.document_state.city == null:
		return

	app.tool_state.landscape_editor = false
	app.city_toolbar.set_landscape_editor(false)
	app.city_menu_bar.disasters_menu.disabled = false
	app.tool_state.last_edit_command = null
	app.current_tool.select_tool_group(9)
	app.frame.select_speed(GameSpeed.Speed.TURTLE)
	app.status_label.text = "City started. Build zones, roads, and services."
	app.effects_audio.play_sound_events([513])
	app.newspaper_state.founding_pending = true
	app.reports.on_newspaper_menu(0)


func on_founding_newspaper_visibility_changed() -> void:
	if not app.newspaper_state.founding_pending or app.newspaper_dialog.visible:
		return

	app.newspaper_state.founding_pending = false

	if app.document_state.city != null and app.document_state.city.music_enabled():
		app.audio_controller.music_director.general_track_index = 0
		app.effects_audio.play_music_track(app.audio_controller.music_director.next_general_track())
