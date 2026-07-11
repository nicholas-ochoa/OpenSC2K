class_name ApplicationSettings
extends RefCounted


const SettingsStore = preload("res://src/ui/settings/app_settings_store.gd")

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func _set_city_renderer(value: String) -> void:
	var selected := SettingsStore.normalize_renderer(value)

	if selected == app.app_city_renderer:
		return

	app.app_city_renderer = selected
	app.map_render._close_region_cache()

	if app.static_render_thread != null and app.static_render_thread.is_started():
		app.static_render_thread.wait_to_finish()

	app.static_render_thread = null
	app.static_render_job = null
	app.pending_static_render = false
	app.static_view_cache.clear()
	app.dynamic_visual_cache.clear()
	app.sign_foreground_cache.clear()
	app.menus._sync_city_option_menus()
	app.map_render._refresh_map()


func _open_import_settings() -> void:
	_open_settings_dialog()
	app.settings_dialog.tabs.current_tab = 3


func _open_settings_dialog() -> void:
	app.settings_dialog.dark_underground_check.button_pressed = app.app_dark_underground
	app.settings_dialog.theme_selector.select(1 if app.app_ui_theme == "dark" else 0)
	app.settings_dialog.translucent_menus_check.button_pressed = app.app_translucent_menus
	app.settings_dialog.default_mayor_edit.text = app.app_default_mayor_name
	app.settings_dialog.overview_graphics_selector.select(app.app_overview_graphics)
	app.settings_dialog.original_compatibility_check.button_pressed = app.app_original_compatibility
	app.settings_dialog.original_compatibility_check.disabled = app.current_document != null and app.current_document.is_extended()
	app.settings_dialog.original_compatibility_check.tooltip_text = "SC2X cities cannot return to original compatibility." if app.settings_dialog.original_compatibility_check.disabled else ""
	app.settings_dialog.warn_sc2x_conversion_check.button_pressed = app.app_warn_sc2x_conversion
	app.settings_dialog.shuffle_music_check.button_pressed = app.app_shuffle_music
	app.settings_dialog.toolbar_sounds_check.button_pressed = app.app_toolbar_sounds
	app.settings_dialog.sound_pack_edit.text = AppSettingsDialog.pack_file_path(app.app_sound_pack_folder)
	app.settings_dialog.music_pack_edit.text = AppSettingsDialog.pack_file_path(app.app_music_pack_folder)
	app.settings_dialog.show_values(
		app.app_music_volume, app.app_effects_volume, app.app_fullscreen,
		app.app_graphics_source, app.app_graphics_folder, app.app_city_renderer, app.app_background_audio, app.app_zoom_graphics,
	)
	_refresh_settings_pack_names()


func _refresh_settings_pack_names() -> void:
	if app.settings_dialog == null:
		return

	app.settings_dialog.set_loaded_pack("graphics", app.asset_source.graphics_name if app.assets_ready else "",
		app.app_graphics_folder if app.app_graphics_source == "folder" else "")

	if app.audio_controller != null:
		app.settings_dialog.set_loaded_pack("sound", app.audio_controller.sound_pack.pack_name, app.app_sound_pack_folder)
		app.settings_dialog.set_loaded_pack("music", app.audio_controller.music_pack.pack_name, app.app_music_pack_folder)


func _apply_settings() -> void:
	var values: Dictionary = app.settings_dialog.selected_values()

	if bool(values.original_compatibility) and app.current_document != null and app.current_document.is_extended():
		app.settings_dialog.show_compatibility_error("This city is SC2X and cannot return to original compatibility. Save it, then open a different original SC2 city or restart the app before enabling compatibility.")

		return

	var pack_error: String = CityAudioController.validate_media_packs(values.sound_pack_folder, values.music_pack_folder)

	if not pack_error.is_empty():
		app.settings_dialog.show_pack_error(pack_error)

		return

	var changed_source: bool = values.graphics_source != app.app_graphics_source or values.graphics_folder != app.app_graphics_folder
	var media_packs_changed: bool = values.sound_pack_folder != app.app_sound_pack_folder or values.music_pack_folder != app.app_music_pack_folder or (not app.assets_ready and changed_source)
	var selected: GameAssetSource

	if changed_source:
		selected = GameAssetSource.load_source(app.reference_root, values.graphics_source, values.graphics_folder)

		if not selected.error.is_empty():
			app.assets._show_graphics_source_error(selected.error)

			return

	if changed_source:
		app.assets._apply_graphics_source(selected)

	app.app_original_compatibility = bool(values.original_compatibility)
	app.app_warn_sc2x_conversion = bool(values.warn_sc2x_conversion)
	_apply_compatibility_controls()
	app.app_graphics_source = values.graphics_source
	app.app_graphics_folder = values.graphics_folder
	_set_city_renderer(str(values.city_renderer))
	app.app_dark_underground = bool(values.dark_underground)
	app.menus._sync_map_style()
	app.app_ui_theme = str(values.ui_theme)
	app.app_translucent_menus = bool(values.translucent_menus)
	AppUiTheme.select(app.app_ui_theme, app.app_translucent_menus)
	app.app_default_mayor_name = str(values.default_mayor_name)

	if app.app_default_mayor_name.is_empty():
		app.app_default_mayor_name = "Mayor"

	var overview_changed := app.app_overview_graphics != int(values.overview_graphics)
	app.app_overview_graphics = int(values.overview_graphics)
	_set_graphics_preferences(values.zoom_graphics)

	if overview_changed:
		app.map_render._close_region_cache()
		app.dynamic_visual_cache.clear()
		app.sign_foreground_cache.clear()
		app.map_render._refresh_map()

	app.app_toolbar_sounds = bool(values.toolbar_sounds)
	app.app_sound_pack_folder = str(values.sound_pack_folder)
	app.app_music_pack_folder = str(values.music_pack_folder)

	if app.assets_ready and app.audio_controller != null and media_packs_changed:
		app.audio_controller.set_media_packs(app.app_sound_pack_folder, app.app_music_pack_folder)

	app.app_shuffle_music = bool(values.shuffle_music)
	app.audio_controller.set_shuffle_music(app.app_shuffle_music)
	app.app_background_audio = bool(values.background_audio)
	app.app_soundtrack_folder = ""
	app.app_music_volume = float(values.music_volume)
	app.app_effects_volume = float(values.effects_volume)
	var fullscreen_changed := app.app_fullscreen != bool(values.fullscreen)
	app.app_fullscreen = bool(values.fullscreen)

	if app.audio_controller != null:
		app.audio_controller.set_background_audio(app.app_background_audio)
		app.audio_controller.set_volumes(app.app_music_volume, app.app_effects_volume)
		app.audio_controller.set_soundtrack_folder(app.app_soundtrack_folder, (app.main_menu != null and app.main_menu.visible) or (app.city != null and app.city.music_enabled()))

	if fullscreen_changed:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN
			if app.app_fullscreen
			else DisplayServer.WINDOW_MODE_WINDOWED
		)

	var error := SettingsStore.save_values(
		app.app_music_volume, app.app_effects_volume, app.app_fullscreen,
		app.app_settings_path, app.app_graphics_source, app.app_graphics_folder, app.app_soundtrack_folder, app.app_city_renderer, app.app_background_audio, app.app_zoom_graphics, app.app_toolbar_sounds, app.app_sound_pack_folder, app.app_music_pack_folder, app.app_shuffle_music, app.app_original_compatibility, app.app_warn_sc2x_conversion, app.app_default_mayor_name, app.app_overview_graphics, app.app_ui_theme, app.app_dark_underground,
		app.app_translucent_menus,
	)
	app.status_label.text = (
		"Settings saved."
		if error == OK
		else "Settings applied, but the settings file could not be saved."
	)
	_refresh_settings_pack_names()


func _load_app_settings() -> void:
	var values := SettingsStore.load_values(
		app.app_settings_path,
		app.app_music_volume,
		app.app_effects_volume,
		app.app_fullscreen,
	)
	app.app_toolbar_sounds = bool(values.toolbar_sounds)
	app.app_sound_pack_folder = str(values.sound_pack_folder)
	app.app_music_pack_folder = str(values.music_pack_folder)
	app.app_dark_underground = bool(values.dark_underground)
	app.menus._sync_map_style()
	app.app_ui_theme = str(values.ui_theme)
	app.app_translucent_menus = bool(values.translucent_menus)
	AppUiTheme.select(app.app_ui_theme, app.app_translucent_menus)
	app.app_default_mayor_name = str(values.default_mayor_name)
	app.app_overview_graphics = int(values.overview_graphics)
	app.app_zoom_graphics = values.zoom_graphics
	app.app_background_audio = values.background_audio
	app.app_original_compatibility = bool(values.original_compatibility)
	app.app_warn_sc2x_conversion = bool(values.warn_sc2x_conversion)
	app.app_shuffle_music = values.shuffle_music
	app.app_city_renderer = values.city_renderer
	app.app_soundtrack_folder = values.soundtrack_folder
	app.app_music_volume = values.music_volume
	app.app_effects_volume = values.effects_volume
	app.app_fullscreen = values.fullscreen
	app.app_graphics_source = values.graphics_source
	app.app_graphics_folder = values.graphics_folder

	if app.app_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _set_graphics_preferences(zoom_graphics: Array) -> void:
	var sizes := SettingsStore.normalize_zoom_graphics(zoom_graphics)

	if app.app_zoom_graphics == sizes:
		return

	app.app_zoom_graphics = sizes
	app.map_render._close_region_cache()
	app.dynamic_visual_cache.clear()
	app.sign_foreground_cache.clear()
	app.map_render._refresh_map()


func _apply_compatibility_controls() -> void:
	if app.speed_controller != null:
		app.speed_controller.original_compatibility = app.app_original_compatibility
		app.speed_controller.fire_elapsed_msec = 0.0


	app.city_files._sync_upgrade_city_option()
