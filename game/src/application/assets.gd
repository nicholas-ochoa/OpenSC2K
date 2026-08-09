class_name ApplicationAssets
extends RefCounted


const Palette = preload("res://src/assets/sc2_palette.gd")
const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")
const SettingsStore = preload("res://src/ui/settings/app_settings_store.gd")
const Random = preload("res://src/simulation/random/sim_random.gd")
const CityAudio = preload("res://src/audio/city_audio_controller.gd")
const NewsQueue = preload("res://src/simulation/reports/news_queue.gd")
const DebugOverlayView = preload("res://src/debug/debug_overlay.tscn")

var app: CityApplication
var text_resources: OriginalTextResources


func _init(application: CityApplication) -> void:
	app = application
	text_resources = application.original_text_resources


func initialize_runtime() -> void:
	if app.runtime_initialized:
		return

	var mode := OS.get_environment("OPENSC2K_ASSET_SOURCE")

	if mode.is_empty():
		mode = app.preferences.graphics_source

	app.asset_source = GameAssetSource.load_source(
		app.reference_root, mode, app.preferences.graphics_folder, OS.get_environment("OPENSC2K_GRAPHICS_PACK")
	)
	app.assets_ready = app.asset_source.error.is_empty()

	if app.assets_ready:
		app.reference_root = app.asset_source.reference_root
	else:
		app.asset_source.assets = OriginalGameAssets.new()
		app.asset_source.use_original_data = false

	app.runtime_initialized = true
	app.new_city_session.independent_template = not app.asset_source.use_original_data
	app.audio_controller = CityAudio.new()
	app.audio_controller.startup_theme_pending = true
	app.audio_controller.background_audio = app.preferences.background_audio
	app.audio_controller.set_shuffle_music(app.preferences.shuffle_music)
	app.audio_controller.music_activity_changed.connect(app.effects_audio.on_music_activity_changed)
	app.audio_controller.music_notice.connect(func(message: String) -> void:
		if app.city_status_bar != null:
			app.city_status_bar.show_music_notice(message)
	)
	app.add_child(app.audio_controller)
	app.audio_controller.setup(
		app.reference_root, app.preferences.music_volume, app.preferences.effects_volume, app.asset_source.use_original_data
	)

	if app.assets_ready:
		app.audio_controller.set_media_packs(app.preferences.sound_pack_folder, app.preferences.music_pack_folder)
		app.audio_controller.set_soundtrack_folder(app.preferences.soundtrack_folder)

	app.reports.newspaper_session_seed = Time.get_ticks_msec() & 0xffff

	if app.reports.newspaper_session_seed & 0x8000:
		app.reports.newspaper_session_seed -= 0x10000

	app.tool_random = Random.new(app.reports.newspaper_session_seed)
	app.reports.newspaper_session_state.resize(NewsQueue.MISC_SIZE)
	app.reports.newspaper_session_state.fill(0)
	NewsQueue.initialize_session(app.reports.newspaper_session_state, app.tool_random)
	var original_assets := app.asset_source.assets
	text_resources.newspaper_data = original_assets.newspaper_data
	text_resources.original_query_strings = original_assets.strings
	text_resources.building_objection_text = original_assets.building_objection_text
	text_resources.library_texts = original_assets.library_texts
	app.scurk_graphics = original_assets.scurk_graphics
	app.interface.build_interface(original_assets)
	app.settings.apply_compatibility_controls()
	app.desktop_presentation = CityDesktopPresentation.new()
	app.desktop_presentation.map_view = app.map_view
	app.desktop_presentation.editor = app.scurk_editor
	app.desktop_presentation.place_print = app.scurk_place_print
	app.desktop_presentation.print_dialog = app.scurk_print
	app.add_child(app.desktop_presentation)
	app.desktop_presentation.set_graphics(original_assets.desktop_graphics)
	app.debug_overlay = DebugOverlayView.instantiate()
	app.debug_overlay.setup(app)
	app.add_child(app.debug_overlay)

	if not original_assets.error.is_empty():
		app.interface.show_error(original_assets.error)

		return

	app.palette = original_assets.palette
	app.scenario_palette = original_assets.scenario_palette
	app.scenario_graphics = original_assets.scenario_graphics
	app.palette_index_encoding = Palette.index_encoding()
	app.static_render.update_palette_cycle_texture()
	app.base_large_sprites = original_assets.large_sprites
	app.base_small_medium_sprites = original_assets.small_medium_sprites
	app.large_sprites = app.base_large_sprites
	app.small_medium_sprites = app.base_small_medium_sprites
	app.camera_input.refresh_child_tool_icons()

	app.interface.show_main_menu()


func build_reference_import_dialogs() -> void:
	app.graphics_source_error_dialog = AcceptDialog.new()
	app.graphics_source_error_dialog.title = "Graphics source"
	app.graphics_source_error_dialog.exclusive = true
	app.add_child(app.graphics_source_error_dialog)
	app.reference_import_dialog = FileDialog.new()
	app.reference_import_dialog.title = "Select the original SimCity 2000 SIMCITY.EXE"
	app.reference_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	app.reference_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	app.reference_import_dialog.filters = PackedStringArray([
		"*.EXE,*.exe ; SimCity 2000 executable",
	])
	app.reference_import_dialog.exclusive = true
	app.reference_import_dialog.file_selected.connect(_import_original_game)
	app.reference_import_dialog.canceled.connect(_on_reference_import_canceled)
	app.add_child(app.reference_import_dialog)

	app.reference_import_error_dialog = AcceptDialog.new()
	app.reference_import_error_dialog.title = "Cannot import SimCity 2000"
	app.reference_import_error_dialog.exclusive = true
	app.reference_import_error_dialog.confirmed.connect(show_reference_import_dialog)
	app.add_child(app.reference_import_error_dialog)

	for dialog in [app.graphics_source_error_dialog, app.reference_import_dialog, app.reference_import_error_dialog]:
		dialog.theme = AppUiTheme.file_dialog() if dialog is FileDialog else AppUiTheme.current()


func show_graphics_source_error(message: String) -> void:
	app.graphics_source_error_dialog.dialog_text = message
	app.graphics_source_error_dialog.call_deferred("popup_centered", Vector2i(620, 220))


func show_reference_import_dialog() -> void:
	if app.reference_import_dialog == null:
		return

	app.reference_import_dialog.popup_centered_ratio(0.8)


func _on_reference_import_canceled() -> void:
	if app.settings_dialog != null:
		app.settings.open_import_settings()


func _show_reference_import_error(message: String) -> void:
	if app.reference_import_error_dialog == null:
		return

	app.reference_import_error_dialog.dialog_text = message
	app.reference_import_error_dialog.popup_centered(Vector2i(640, 260))


func _import_original_game(executable_path: String) -> void:
	var install_result := OriginalPackImporter.import_executable(
		executable_path, ProjectSettings.globalize_path("user://packs"), ProjectSettings.globalize_path("user://")
	)

	if not install_result.ok:
		_show_reference_import_error(install_result.error)

		return

	var selected := GameAssetSource.load_source(install_result.root, "folder", install_result.graphics)

	if not selected.error.is_empty():
		_show_reference_import_error(selected.error)

		return

	app.reference_import_dialog.hide()
	app.reference_import_error_dialog.hide()
	app.preferences.graphics_source = "folder"
	app.preferences.graphics_folder = install_result.graphics
	app.preferences.sound_pack_folder = install_result.sound
	app.preferences.music_pack_folder = install_result.music
	app.preferences.soundtrack_folder = ""
	apply_graphics_source(selected)
	app.audio_controller.set_media_packs(app.preferences.sound_pack_folder, app.preferences.music_pack_folder)
	app.audio_controller.set_soundtrack_folder("")
	var saved := SettingsStore.save_values(
		app.preferences.music_volume, app.preferences.effects_volume, app.preferences.fullscreen,
		app.preferences.settings_path, app.preferences.graphics_source, app.preferences.graphics_folder, app.preferences.soundtrack_folder, app.preferences.city_renderer, app.preferences.background_audio, app.preferences.zoom_graphics, app.preferences.toolbar_sounds, app.preferences.sound_pack_folder, app.preferences.music_pack_folder, app.preferences.shuffle_music, app.preferences.original_compatibility, app.preferences.warn_sc2x_conversion, app.preferences.default_mayor_name, app.preferences.overview_graphics, app.preferences.ui_theme, app.preferences.dark_underground,
	)
	app.settings.open_import_settings()
	app.status_label.text = "Packs active. Imported %d cities and %d scenarios." % [install_result.cities, install_result.scenarios]

	if saved != OK:
		app.interface.show_error("Packs imported, but their preferences could not be saved.")


func apply_graphics_source(selected: GameAssetSource) -> void:
	# wait for workers using the old archives
	app.map_render.close_region_cache()
	app.static_render.stop_render_job()
	app.asset_source = selected
	app.assets_ready = true
	app.reference_root = selected.reference_root
	app.new_city_session.independent_template = false
	app.audio_controller.reference_root = app.reference_root
	app.audio_controller.original_media_enabled = true
	var assets := selected.assets
	text_resources.newspaper_data = assets.newspaper_data
	text_resources.original_query_strings = assets.strings
	text_resources.building_objection_text = assets.building_objection_text
	text_resources.library_texts = assets.library_texts
	app.palette = assets.palette
	app.scenario_palette = assets.scenario_palette
	app.scenario_graphics = assets.scenario_graphics
	app.scurk_graphics = assets.scurk_graphics
	app.base_large_sprites = assets.large_sprites
	app.base_small_medium_sprites = assets.small_medium_sprites
	app.large_sprites = app.base_large_sprites
	app.small_medium_sprites = app.base_small_medium_sprites

	if app.active_scurk_tile_set != null:
		app.large_sprites = SpriteArchive.combine([app.base_large_sprites, app.active_scurk_tile_set.overrides])
		app.small_medium_sprites = SpriteArchive.combine([app.base_small_medium_sprites, app.active_scurk_tile_set.overrides])

	app.static_render.invalidate_rendered_city()
	app.static_render.update_palette_cycle_texture()
	app.city_toolbar.replace_artwork(assets.toolbar_art)
	app.camera_input.refresh_child_tool_icons()
	app.about_dialog.set_assets(assets)
	app.new_city_dialog.set_control_graphics(assets.city_ui_graphics)
	app.newspaper_dialog.set_control_graphics(assets.city_ui_graphics)
	app.desktop_presentation.set_graphics(assets.desktop_graphics)
	app.city_dialogs.original_assets = assets
	app.industry_window.industry_control.set_icon_strip(assets.industry_icons)
	app.simnation_window.simnation_control.set_sprite_sheet(assets.simnation_sprites)
	app.city_map_window.set_resources(assets.city_map_icons, assets.strings)
	app.building_objection_dialog.set_picture(assets.forest_protest_image)
	if app.scurk_editor != null:
		app.scurk_editor.configure(app.palette, app.base_large_sprites, app.base_small_medium_sprites, app.reference_root, app.scurk_graphics)

	if app.scurk_place_print != null and app.scurk_place_print.visible:
		app.scurk_place_print.configure(app.palette, app.large_sprites, app.active_scurk_tile_set.names if app.active_scurk_tile_set != null else {}, app.scurk_graphics)

	app.menus.sync_asset_menu_actions()
	app.main_menu.set_assets_ready(true)
	app.main_menu.city_background.replace_graphics(app.palette, app.large_sprites)

	if app.main_menu.visible:
		app.main_menu.city_background.configure(app.reference_root, app.palette, app.large_sprites)

	app.map_render.refresh_map(false)


func refresh_scurk_artwork() -> void:
	if app.map_view == null:
		return

	app.map_view.scurk_stamp_visuals.clear()

	if app.city != null and app.scurk_place_print != null and app.scurk_place_print.visible and app.overlay_mode == CityViewMode.Mode.CITY:
		for stamp in app.city.scurk_artwork_stamps:
			var entry = app.large_sprites.find_sprite(1000 + int(stamp.tile_id))

			if entry == null:
				continue

			var rendered: Dictionary = entry.create_image(app.palette)

			if not rendered.ok:
				continue

			var texture := ImageTexture.create_from_image(rendered.image)
			var anchor: Vector2 = CityIsometricRenderer.tile_polygon(app.city, stamp.point.x, stamp.point.y)[2]
			app.map_view.scurk_stamp_visuals.append({"texture": texture, "position": anchor - Vector2(texture.get_width() / 2.0, texture.get_height() - 1)})

	app.map_view.queue_redraw()


# level terrain paints a round brush toward the height under the first click
