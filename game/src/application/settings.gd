class_name ApplicationSettings
extends RefCounted


const SettingsStore = preload("res://src/ui/settings/app_settings_store.gd")

var app: CityApplication
var preferences: AppPreferences


func _init(application: CityApplication) -> void:
	app = application
	preferences = application.preferences


func _set_city_renderer(value: String) -> void:
	var selected := SettingsStore.normalize_renderer(value)

	if selected == preferences.city_renderer:
		return

	preferences.city_renderer = selected
	# closing the region cache also clears the dynamic sprite caches
	app.map_render.close_region_cache()
	app.static_render.restart_static_render()
	app.menus.sync_city_option_menus()
	app.map_render.refresh_map()


func open_import_settings() -> void:
	open_settings_dialog()
	app.main_overlays.settings_dialog.tabs.current_tab = 3


func open_settings_dialog() -> void:
	app.main_overlays.settings_dialog.dark_underground_check.button_pressed = preferences.dark_underground
	app.main_overlays.settings_dialog.theme_selector.select(1 if preferences.ui_theme == "dark" else 0)
	app.main_overlays.settings_dialog.translucent_menus_check.button_pressed = preferences.translucent_menus
	app.main_overlays.settings_dialog.ui_scale_selector.select(AppUiScale.option_index(preferences.ui_scale))
	app.main_overlays.settings_dialog.default_mayor_edit.text = preferences.default_mayor_name
	app.main_overlays.settings_dialog.overview_graphics_selector.select(preferences.overview_graphics)
	app.main_overlays.settings_dialog.check_for_updates_check.button_pressed = preferences.check_for_updates
	app.main_overlays.settings_dialog.set_update_status(preferences.update_checked_at, preferences.update_error)
	app.main_overlays.settings_dialog.shuffle_music_check.button_pressed = preferences.shuffle_music
	app.main_overlays.settings_dialog.toolbar_sounds_check.button_pressed = preferences.toolbar_sounds
	app.main_overlays.settings_dialog.sound_pack_edit.text = AppSettingsDialog.pack_file_path(preferences.sound_pack_folder)
	app.main_overlays.settings_dialog.music_pack_edit.text = AppSettingsDialog.pack_file_path(preferences.music_pack_folder)
	app.main_overlays.settings_dialog.data_pack_edit.text = AppSettingsDialog.pack_file_path(preferences.data_pack_folder)
	app.main_overlays.settings_dialog.show_values(
		preferences.music_volume, preferences.effects_volume, preferences.fullscreen,
		preferences.graphics_source, preferences.graphics_folder, preferences.city_renderer, preferences.background_audio, preferences.zoom_graphics,
	)
	_refresh_settings_pack_names()


func _refresh_settings_pack_names() -> void:
	if app.main_overlays.settings_dialog == null:
		return

	app.main_overlays.settings_dialog.set_loaded_pack("graphics", app.asset_state.asset_source.graphics_name if app.asset_state.assets_ready else "",
		preferences.graphics_folder if preferences.graphics_source == "folder" else "")

	if app.audio_controller != null:
		app.main_overlays.settings_dialog.set_loaded_pack("sound", app.audio_controller.sound_pack.pack_name, preferences.sound_pack_folder)
		app.main_overlays.settings_dialog.set_loaded_pack("music", app.audio_controller.music_pack.pack_name, preferences.music_pack_folder)

	app.main_overlays.settings_dialog.set_loaded_pack("data", app.asset_state.data_pack.pack_name, preferences.data_pack_folder)


func apply_settings() -> void:
	var values: AppSettingsStore.Values = app.main_overlays.settings_dialog.selected_values()

	var pack_error: String = CityAudioController.validate_media_packs(values.sound_pack_folder, values.music_pack_folder)

	if not pack_error.is_empty():
		app.main_overlays.settings_dialog.show_pack_error(pack_error)

		return

	var changed_source: bool = values.graphics_source != preferences.graphics_source or values.graphics_folder != preferences.graphics_folder
	var media_packs_changed: bool = (values.sound_pack_folder != preferences.sound_pack_folder
			or values.music_pack_folder != preferences.music_pack_folder or (not app.asset_state.assets_ready and changed_source))
	var selected: GameAssetSource

	if changed_source:
		selected = GameAssetSource.load_source(app.asset_state.reference_root, values.graphics_source, values.graphics_folder)

		if not selected.error.is_empty():
			app.assets.show_graphics_source_error(selected.error)

			return

	var data_pack: DataPack

	if values.data_pack_folder != preferences.data_pack_folder:
		data_pack = DataPack.load_folder(values.data_pack_folder)

		if not data_pack.error.is_empty():
			app.assets.show_graphics_source_error(data_pack.error, "Data pack")

			return

	if data_pack != null:
		preferences.data_pack_folder = values.data_pack_folder
		app.assets.apply_data_pack(data_pack)

	if changed_source:
		app.assets.apply_graphics_source(selected)

	preferences.check_for_updates = bool(values.check_for_updates)
	preferences.graphics_source = values.graphics_source
	preferences.graphics_folder = values.graphics_folder
	_set_city_renderer(str(values.city_renderer))
	preferences.dark_underground = bool(values.dark_underground)
	app.menus.sync_map_style()
	preferences.ui_theme = str(values.ui_theme)
	preferences.translucent_menus = bool(values.translucent_menus)
	AppUiTheme.select(preferences.ui_theme, preferences.translucent_menus)
	preferences.ui_scale = AppUiScale.normalize(values.ui_scale)
	apply_ui_scale()
	preferences.default_mayor_name = str(values.default_mayor_name)

	if preferences.default_mayor_name.is_empty():
		preferences.default_mayor_name = "Mayor"

	var overview_changed := preferences.overview_graphics != int(values.overview_graphics)
	preferences.overview_graphics = int(values.overview_graphics)
	_set_graphics_preferences(values.zoom_graphics)

	if overview_changed:
		app.map_render.close_region_cache()
		app.map_render.refresh_map()

	preferences.toolbar_sounds = bool(values.toolbar_sounds)
	preferences.sound_pack_folder = str(values.sound_pack_folder)
	preferences.music_pack_folder = str(values.music_pack_folder)

	if app.asset_state.assets_ready and app.audio_controller != null and media_packs_changed:
		app.audio_controller.set_media_packs(preferences.sound_pack_folder, preferences.music_pack_folder)

	preferences.shuffle_music = bool(values.shuffle_music)
	app.audio_controller.set_shuffle_music(preferences.shuffle_music)
	preferences.background_audio = bool(values.background_audio)
	preferences.soundtrack_folder = ""
	preferences.music_volume = float(values.music_volume)
	preferences.effects_volume = float(values.effects_volume)
	var fullscreen_changed := preferences.fullscreen != bool(values.fullscreen)
	preferences.fullscreen = bool(values.fullscreen)

	if app.audio_controller != null:
		app.audio_controller.set_background_audio(preferences.background_audio)
		app.audio_controller.set_volumes(preferences.music_volume, preferences.effects_volume)
		app.audio_controller.set_soundtrack_folder(preferences.soundtrack_folder, (app.main_menu != null and app.main_menu.visible)
				or (app.document_state.city != null and app.document_state.city.music_enabled()))

	if fullscreen_changed:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN
			if preferences.fullscreen
			else DisplayServer.WINDOW_MODE_WINDOWED
		)

	var error := SettingsStore.save_values(
		preferences.music_volume, preferences.effects_volume, preferences.fullscreen,
		preferences.settings_path, preferences.graphics_source, preferences.graphics_folder, preferences.soundtrack_folder,
		preferences.city_renderer, preferences.background_audio, preferences.zoom_graphics, preferences.toolbar_sounds,
		preferences.sound_pack_folder, preferences.music_pack_folder, preferences.shuffle_music,
		preferences.default_mayor_name, preferences.overview_graphics, preferences.ui_theme, preferences.dark_underground,
		preferences.translucent_menus, preferences.check_for_updates, preferences.data_pack_folder, preferences.ui_scale,
	)
	app.status_label.text = (
		"Settings saved."
		if error == OK
		else "Settings applied, but the settings file could not be saved."
	)
	_refresh_settings_pack_names()


func load_app_settings() -> void:
	var values := SettingsStore.load_values(
		preferences.settings_path,
		preferences.music_volume,
		preferences.effects_volume,
		preferences.fullscreen,
	)
	preferences.toolbar_sounds = bool(values.toolbar_sounds)
	preferences.sound_pack_folder = str(values.sound_pack_folder)
	preferences.music_pack_folder = str(values.music_pack_folder)
	preferences.data_pack_folder = str(values.data_pack_folder)
	preferences.dark_underground = bool(values.dark_underground)
	app.menus.sync_map_style()
	preferences.ui_theme = str(values.ui_theme)
	preferences.translucent_menus = bool(values.translucent_menus)
	AppUiTheme.select(preferences.ui_theme, preferences.translucent_menus)
	preferences.ui_scale = values.ui_scale
	apply_ui_scale()
	preferences.default_mayor_name = str(values.default_mayor_name)
	preferences.overview_graphics = int(values.overview_graphics)
	preferences.zoom_graphics = values.zoom_graphics
	preferences.background_audio = values.background_audio
	preferences.shuffle_music = values.shuffle_music
	preferences.city_renderer = values.city_renderer
	preferences.soundtrack_folder = values.soundtrack_folder
	preferences.music_volume = values.music_volume
	preferences.effects_volume = values.effects_volume
	preferences.fullscreen = values.fullscreen
	preferences.graphics_source = values.graphics_source
	preferences.graphics_folder = values.graphics_folder
	preferences.check_for_updates = values.check_for_updates
	preferences.update_last_check = values.update_last_check
	preferences.update_skipped_version = values.update_skipped_version
	preferences.update_checked_at = values.update_checked_at
	preferences.update_error = values.update_error

	if preferences.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# scale the interface and keep pixel artwork on whole screen pixels. call this
# again when the window size or screen changes
func apply_ui_scale() -> void:
	var window := app.get_window()

	if window == null:
		return

	var screen_pixels := AppUiScale.apply(window, preferences.ui_scale)
	# headless windows have no real pixels, so keep one artwork pixel for each
	# interface pixel there
	var headless := DisplayServer.get_name() == "headless"
	ScreenPixels.set_scale(0.0 if headless else screen_pixels)
	# keep the frosted glass blur in proportion to the interface
	RenderingServer.global_shader_parameter_set("ui_scale_factor", AppUiScale.relative)

	if app.map_view == null:
		return

	if headless:
		app.map_view.set_pixel_scales(0.0, 1)
	else:
		app.map_view.set_pixel_scales(screen_pixels, AppUiScale.map_pixels(AppUiScale.fit_scale(window.size, window.content_scale_size)))


func _set_graphics_preferences(zoom_graphics: Array) -> void:
	var sizes := SettingsStore.normalize_zoom_graphics(zoom_graphics, preferences.overview_graphics)

	if preferences.zoom_graphics == sizes:
		return

	preferences.zoom_graphics = sizes
	app.map_render.close_region_cache()
	app.map_render.refresh_map()
