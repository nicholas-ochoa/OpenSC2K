class_name ApplicationNewCity
extends RefCounted


const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const TerrainTools = preload("res://src/tools/landscape/terrain_command.gd")
const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func sync_new_city_workspace() -> void:
	app.city_workspace.set_editor_controls_visible(not app.city_dialogs.new_city_dialog.visible)


func open_new_city_dialog() -> void:
	if not app.asset_state.assets_ready:
		return

	if app.city_dialogs.new_city_dialog == null:
		return

	app.new_city_state.return_to_main_menu = app.main_menu != null and app.main_menu.visible

	if app.new_city_state.return_to_main_menu:
		app.main_menu.hide()

	app.city_dialogs.new_city_dialog.preview_timer.stop()
	app.new_city_state.session.begin(app.tool_state.tool_random.state, app.simulation_state.nuisance_random.state)
	app.city_dialogs.new_city_dialog.reset_fields(app.preferences.default_mayor_name)
	app.city_dialogs.new_city_dialog.show()
	app.city_dialogs.new_city_dialog.invalidate()
	app.city_dialogs.new_city_dialog.focus_city_name()


func reopen_terrain_dialog() -> void:
	if not app.tool_state.landscape_editor:
		return
	app.new_city_state.return_to_main_menu = false
	app.city_dialogs.new_city_dialog.show()
	app.city_dialogs.new_city_dialog.invalidate()


func schedule_new_city_preview(_value: Variant = null) -> void:
	if app.city_dialogs.new_city_dialog != null and app.city_dialogs.new_city_dialog.visible:
		app.city_dialogs.new_city_dialog.invalidate()


func make_new_city_preview() -> void:
	if app.new_city_state.preview_job != null:
		return
	app.city_dialogs.new_city_dialog.preview_timer.stop()
	app.city_dialogs.new_city_dialog.invalidate()
	var sound_ids: Array[int] = [529]
	app.audio_controller.play_sound_ids(sound_ids, app.document_state.city == null or app.document_state.city.sound_enabled(),
			CityViewMode.Mode.CITY, IsometricRenderer.VIEW_LARGE)
	_generate_new_city_preview(true)


func _generate_new_city_preview(advance_seed: bool) -> bool:
	if app.asset_state.palette == null or not app.asset_state.palette.is_valid():
		app.city_dialogs.new_city_dialog.preview_status.text = "Terrain preview is not available."
		return false

	if app.new_city_state.preview_job != null:
		return false

	app.new_city_state.preview_job = NewCityPreviewJob.new()
	app.new_city_state.preview_job.revision = app.city_dialogs.new_city_dialog.generation_revision
	app.new_city_state.preview_job.view_size = NewCityPreviewJob.preview_view_size(
		app.city_dialogs.new_city_dialog.size_input.get_selected_id(), app.city_dialogs.new_city_dialog.size)

	var preview_sprites := (app.asset_state.large_sprites if app.new_city_state.preview_job.view_size == IsometricRenderer.VIEW_LARGE
			else app.asset_state.small_medium_sprites)

	var error := app.new_city_state.preview_job.start(app.new_city_state.session,
		app.asset_state.reference_root.path_join("DEFAULT.SC2"), app.city_dialogs.new_city_dialog.terrain_options(),
		app.asset_state.palette, preview_sprites, advance_seed)

	if error != OK:
		app.new_city_state.preview_job = null
		app.city_dialogs.new_city_dialog.preview_status.text = "Cannot start terrain generation."
		return false

	app.city_dialogs.new_city_dialog.set_generating(true)

	return true


func poll_new_city_preview() -> void:
	if app.new_city_state.preview_job == null or app.new_city_state.preview_job.thread.is_alive():
		return

	var job := app.new_city_state.preview_job
	var generated: NewCityTerrainSession.PreviewResult = job.thread.wait_to_finish()
	app.new_city_state.preview_job = null
	app.city_dialogs.new_city_dialog.set_generating(false)

	if not app.city_dialogs.new_city_dialog.visible or job.revision != app.city_dialogs.new_city_dialog.generation_revision:
		return

	if not generated.ok:
		app.city_dialogs.new_city_dialog.preview_status.text = "Cannot generate terrain: %s" % generated.error
		return

	app.new_city_state.session = job.session
	app.city_dialogs.new_city_dialog.show_preview(generated.landscape_image, generated.minimap_image,
		"Water: %s tiles   Trees: %s tiles   Height: %s–%s"
		% [
			app.interface.format_number(int(generated.terrain.water_tiles)),
			app.interface.format_number(int(generated.terrain.tree_tiles)),
			int(generated.terrain.minimum_altitude),
			int(generated.terrain.maximum_altitude),
		]
	)


func cancel_new_city() -> void:
	app.city_dialogs.new_city_dialog.invalidate()
	app.city_dialogs.new_city_dialog.preview_timer.stop()
	app.city_dialogs.new_city_dialog.hide()
	app.new_city_state.session.clear()
	app.city_dialogs.new_city_dialog.preview_view.texture = null

	var return_to_main_menu := app.new_city_state.return_to_main_menu
	app.new_city_state.return_to_main_menu = false

	if return_to_main_menu:
		app.interface.show_main_menu()


func create_new_city() -> void:
	if not app.city_dialogs.new_city_dialog.candidate_valid:
		return

	if app.tool_state.landscape_editor:
		create_new_city_unchecked()
	else:
		app.city_files.request_city_exit("create_new_city")


func create_new_city_unchecked() -> void:
	app.city_dialogs.new_city_dialog.preview_timer.stop()
	var terrain_options := app.city_dialogs.new_city_dialog.terrain_options()

	if not app.city_dialogs.new_city_dialog.candidate_valid or not app.new_city_state.session.matches(terrain_options):
		return

	var template_path := app.asset_state.reference_root.path_join("DEFAULT.SC2")
	var setup := app.city_dialogs.new_city_dialog.setup_options()
	var result := app.new_city_state.session.create_city(
		template_path,
		setup.city_name,
		setup.mayor_name,
		setup.difficulty,
		setup.starting_year,
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
			setup.starting_year,
			_difficulty_name(setup.difficulty),
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
	return app.tool_state.selected_group == CityToolIds.Group.BULLDOZER and app.tool_state.selected_subtool == TerrainTools.SUBTOOL_LEVEL


func _enter_landscape_editor() -> void:
	app.tool_state.landscape_editor = true
	app.frame.select_speed(GameSpeed.Speed.PAUSED)
	app.city_toolbar.set_landscape_editor(true)
	app.city_menu_bar.disasters_menu.disabled = true
	app.menus.set_overlay(CityViewMode.Mode.CITY)
	app.current_tool.select_tool_group(CityToolIds.Group.BULLDOZER)
	app.current_tool.select_subtool(CityToolIds.Bulldozer.RAISE)
	app.status_label.text = "Landscape editor: terrain changes are free. Select Start City when ready."


func start_city() -> void:
	if not app.tool_state.landscape_editor or app.document_state.city == null:
		return

	app.tool_state.landscape_editor = false
	app.city_toolbar.set_landscape_editor(false)
	app.city_menu_bar.disasters_menu.disabled = false
	app.tool_state.last_edit_command = null
	app.current_tool.select_tool_group(CityToolIds.Group.RESIDENTIAL)
	app.frame.select_speed(GameSpeed.Speed.TURTLE)
	app.status_label.text = "City started. Build zones, roads, and services."
	var sound_ids: Array[int] = [513]
	app.effects_audio.play_sound_ids(sound_ids)
	app.newspaper_state.founding_pending = true
	app.reports.on_newspaper_menu(0)


func on_founding_newspaper_visibility_changed() -> void:
	if not app.newspaper_state.founding_pending or app.city_dialogs.newspaper_dialog.visible:
		return

	app.newspaper_state.founding_pending = false

	if app.document_state.city != null and app.document_state.city.music_enabled():
		app.audio_controller.music_director.general_track_index = 0
		app.effects_audio.play_music_track(app.audio_controller.music_director.next_general_track())
