class_name ApplicationSettings
extends RefCounted

const SettingsStore = preload("res://src/ui/settings/app_settings_store.gd")

var app: CityApplication
var preferences: AppPreferences
var _visual_save_timer: Timer
var _visual_save_pending := false


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
	app.main_overlays.settings_dialog.tabs.current_tab = AppSettingsDialog.DATA_TAB


func open_settings_dialog() -> void:
	app.main_overlays.settings_dialog.loading_values = true
	app.main_overlays.settings_dialog.visual_tab.show_values(preferences.visual_enhancements)
	app.main_overlays.settings_dialog.dark_underground_check.button_pressed = preferences.dark_underground
	app.main_overlays.settings_dialog.theme_selector.select(1 if preferences.ui_theme == "dark" else 0)
	app.main_overlays.settings_dialog.translucent_menus_check.button_pressed = preferences.translucent_menus
	app.main_overlays.settings_dialog.ui_scale_selector.select(AppUiScale.option_index(preferences.ui_scale))
	app.main_overlays.settings_dialog.default_mayor_edit.text = preferences.default_mayor_name
	app.main_overlays.settings_dialog.overview_graphics_selector.select(preferences.overview_graphics)
	app.main_overlays.settings_dialog.check_for_updates_check.button_pressed = preferences.check_for_updates
	app.main_overlays.settings_dialog.set_update_status(preferences.update_checked_at, preferences.update_error)
	app.main_overlays.settings_dialog.shuffle_music_check.button_pressed = preferences.shuffle_music
	app.main_overlays.settings_dialog.show_soundfont(preferences.music_soundfont, preferences.music_soundfont_path,
		app.audio_controller.music_player.synth_status if app.audio_controller != null and app.audio_controller.music_player != null else "")
	app.main_overlays.settings_dialog.toolbar_sounds_check.button_pressed = preferences.toolbar_sounds
	app.main_overlays.settings_dialog.city_sounds_selector.select(preferences.city_sounds)
	app.main_overlays.settings_dialog.sound_pack_edit.text = AppSettingsDialog.pack_file_path(preferences.sound_pack_folder)
	app.main_overlays.settings_dialog.music_pack_edit.text = AppSettingsDialog.pack_file_path(preferences.music_pack_folder)
	app.main_overlays.settings_dialog.data_pack_edit.text = AppSettingsDialog.pack_file_path(preferences.data_pack_folder)
	app.main_overlays.settings_dialog.show_control_bindings(preferences.control_bindings)
	app.main_overlays.settings_dialog.show_values(
		preferences.music_volume, preferences.effects_volume, preferences.fullscreen,
		preferences.graphics_source, preferences.graphics_folder, preferences.city_renderer, preferences.background_audio,
		preferences.zoom_graphics,
	)
	app.main_overlays.settings_dialog.loading_values = false
	_refresh_settings_pack_names()


func _refresh_settings_pack_names() -> void:
	if app.main_overlays.settings_dialog == null:
		return

	app.main_overlays.settings_dialog.set_loaded_pack("graphics",
		app.asset_state.asset_source.graphics_name if app.asset_state.assets_ready else "",
		preferences.graphics_folder if preferences.graphics_source == "folder" else "")

	if app.audio_controller != null:
		app.main_overlays.settings_dialog.set_loaded_pack("sound", app.audio_controller.sound_pack.pack_name, preferences.sound_pack_folder)
		app.main_overlays.settings_dialog.set_loaded_pack("music", app.audio_controller.music_pack.pack_name, preferences.music_pack_folder)

	app.main_overlays.settings_dialog.set_loaded_pack("data", app.asset_state.data_pack.pack_name, preferences.data_pack_folder)


# apply the values in the Settings dialog. the dialog calls this for each
# change, so apply and save only what changed. a pack that does not load keeps
# the earlier pack and does not stop the other settings
func apply_settings() -> void:
	var dialog := app.main_overlays.settings_dialog
	# Visual controls have their own signal. Do not revisit audio, packs, input
	# bindings or window settings for each step of a visual adjustment.
	if dialog.visual_change_in_progress:
		if _apply_visual_options(dialog.visual_tab.selected_values()):
			if dialog.visible:
				_queue_visual_save()
			else:
				_save_settings()
		return
	var values: AppSettingsStore.Values = dialog.selected_values()
	var saved_before := _saved_settings_text()
	_apply_visual_options(values.visual_enhancements)
	var media_packs_changed := (not _same_pack(values.sound_pack_folder, preferences.sound_pack_folder)
			or not _same_pack(values.music_pack_folder, preferences.music_pack_folder))

	if not media_packs_changed:
		values.sound_pack_folder = preferences.sound_pack_folder
		values.music_pack_folder = preferences.music_pack_folder
	else:
		var pack_error: String = CityAudioController.validate_media_packs(values.sound_pack_folder, values.music_pack_folder)

		if pack_error.is_empty():
			dialog.pack_error_label.hide()
		else:
			dialog.show_pack_error(pack_error)
			_show_saved_pack(dialog.sound_pack_edit, preferences.sound_pack_folder)
			_show_saved_pack(dialog.music_pack_edit, preferences.music_pack_folder)
			values.sound_pack_folder = preferences.sound_pack_folder
			values.music_pack_folder = preferences.music_pack_folder
			media_packs_changed = false

	if not _same_pack(values.data_pack_folder, preferences.data_pack_folder):
		var data_pack := DataPack.load_folder(values.data_pack_folder)

		if data_pack.error.is_empty():
			preferences.data_pack_folder = values.data_pack_folder
			app.assets.apply_data_pack(data_pack)
		else:
			app.assets.show_graphics_source_error(data_pack.error, "Data pack")
			_show_saved_pack(dialog.data_pack_edit, preferences.data_pack_folder)

	if (values.graphics_source != preferences.graphics_source
			or (values.graphics_source == "folder" and not _same_pack(values.graphics_folder, preferences.graphics_folder))):
		var selected := GameAssetSource.load_source(app.asset_state.reference_root, values.graphics_source, values.graphics_folder)

		if selected.error.is_empty():
			media_packs_changed = media_packs_changed or not app.asset_state.assets_ready
			app.assets.apply_graphics_source(selected)
			preferences.graphics_source = values.graphics_source
			preferences.graphics_folder = values.graphics_folder
		else:
			app.assets.show_graphics_source_error(selected.error)
			_show_saved_pack(dialog.folder_edit, preferences.graphics_folder if preferences.graphics_source == "folder" else "")

	preferences.check_for_updates = bool(values.check_for_updates)

	if not preferences.control_bindings.equals(values.control_bindings):
		preferences.control_bindings = values.control_bindings
		apply_control_bindings()

	_set_city_renderer(str(values.city_renderer))

	if preferences.dark_underground != bool(values.dark_underground):
		preferences.dark_underground = bool(values.dark_underground)
		app.menus.sync_map_style()

	if preferences.ui_theme != str(values.ui_theme) or preferences.translucent_menus != bool(values.translucent_menus):
		preferences.ui_theme = str(values.ui_theme)
		preferences.translucent_menus = bool(values.translucent_menus)
		AppUiTheme.select(preferences.ui_theme, preferences.translucent_menus)

	var ui_scale := AppUiScale.normalize(values.ui_scale)

	if preferences.ui_scale != ui_scale:
		preferences.ui_scale = ui_scale
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
	preferences.city_sounds = SettingsStore.normalize_city_sounds(values.city_sounds)
	preferences.sound_pack_folder = str(values.sound_pack_folder)
	preferences.music_pack_folder = str(values.music_pack_folder)

	if app.asset_state.assets_ready and app.audio_controller != null and media_packs_changed:
		app.audio_controller.set_media_packs(preferences.sound_pack_folder, preferences.music_pack_folder)

	preferences.shuffle_music = bool(values.shuffle_music)
	preferences.music_soundfont = SoundFontCatalog.normalize(str(values.music_soundfont))
	preferences.music_soundfont_path = str(values.music_soundfont_path)
	preferences.background_audio = bool(values.background_audio)
	preferences.soundtrack_folder = ""
	preferences.music_volume = float(values.music_volume)
	preferences.effects_volume = float(values.effects_volume)

	if app.audio_controller != null:
		app.audio_controller.set_shuffle_music(preferences.shuffle_music)
		app.audio_controller.set_music_soundfont(preferences.music_soundfont, preferences.music_soundfont_path)

		# this stops sound effects, so call it only for a change
		if app.audio_controller.background_audio != preferences.background_audio:
			app.audio_controller.set_background_audio(preferences.background_audio)

		app.audio_controller.wave_sound_gate.city_sounds = preferences.city_sounds
		app.audio_controller.set_volumes(preferences.music_volume, preferences.effects_volume)
		app.audio_controller.set_soundtrack_folder(preferences.soundtrack_folder, (app.main_menu != null and app.main_menu.visible)
				or (app.document_state.city != null and app.document_state.city.music_enabled()))

	if preferences.fullscreen != bool(values.fullscreen):
		preferences.fullscreen = bool(values.fullscreen)
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN
			if preferences.fullscreen
			else DisplayServer.WINDOW_MODE_WINDOWED
		)

	_refresh_settings_pack_names()

	if _saved_settings_text() == saved_before:
		return

	_save_settings()


func _apply_visual_options(values: Dictionary) -> bool:
	if preferences.visual_enhancements == values:
		return false
	preferences.visual_enhancements = values
	app.visual_environment.configure()
	if app.main_menu != null:
		app.main_menu.city_background.set_visual_options(values)
	return true


func _queue_visual_save() -> void:
	if _visual_save_timer == null:
		_visual_save_timer = Timer.new()
		_visual_save_timer.one_shot = true
		_visual_save_timer.wait_time = 0.3
		_visual_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
		app.add_child(_visual_save_timer)
		_visual_save_timer.timeout.connect(flush_visual_save)
		app.tree_exiting.connect(flush_visual_save)
		app.main_overlays.settings_dialog.visibility_changed.connect(func() -> void:
			if not app.main_overlays.settings_dialog.visible:
				flush_visual_save())
	_visual_save_pending = true
	_visual_save_timer.start()


func flush_visual_save() -> void:
	if _visual_save_pending:
		_save_settings()


func _save_settings() -> void:
	_visual_save_pending = false
	if is_instance_valid(_visual_save_timer):
		_visual_save_timer.stop()
	var error := SettingsStore.save_values(preferences.music_volume, preferences.effects_volume, preferences.fullscreen,
		preferences.settings_path, preferences.save_options(),
	)
	app.status_label.text = (
		"Settings saved."
		if error == OK
		else "Settings applied, but the settings file could not be saved."
	)


# the fields show pack.json paths. the saved value can be the folder only
func _same_pack(selected: String, saved: String) -> bool:
	return AppSettingsDialog.pack_file_path(selected.strip_edges()) == AppSettingsDialog.pack_file_path(saved.strip_edges())


# a pack that did not load leaves the field at the pack in use
func _show_saved_pack(edit: LineEdit, folder: String) -> void:
	edit.text = AppSettingsDialog.pack_file_path(folder)
	edit.text_changed.emit(edit.text)


# compare this text before and after a change to find if the file needs a save
func _saved_settings_text() -> String:
	var options := preferences.save_options()
	var parts: Array = [preferences.music_volume, preferences.effects_volume, preferences.fullscreen]

	for property in options.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.name != "control_bindings":
			parts.append(options.get(property.name))

	for id in ControlActions.bindable_ids():
		parts.append(preferences.control_bindings.to_texts(id))

	return var_to_str(parts)


func load_app_settings() -> void:
	var values := SettingsStore.load_values(
		preferences.settings_path,
		preferences.music_volume,
		preferences.effects_volume,
		preferences.fullscreen,
	)
	preferences.toolbar_sounds = bool(values.toolbar_sounds)
	preferences.visual_enhancements = values.visual_enhancements
	app.visual_environment.configure()
	if app.main_menu != null:
		app.main_menu.city_background.set_visual_options(preferences.visual_enhancements)
	preferences.city_sounds = values.city_sounds
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
	preferences.music_soundfont = values.music_soundfont
	preferences.music_soundfont_path = values.music_soundfont_path
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
	preferences.control_bindings = values.control_bindings
	preferences.debug_mode = values.debug_mode
	DebugMode.enabled = values.debug_mode
	apply_control_bindings()

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


# give the map and the menus the current bindings. call this again when the map is created
func apply_control_bindings() -> void:
	if app.map_view != null:
		app.map_view.control_bindings = preferences.control_bindings

	if app.city_menu_bar != null:
		app.city_menu_bar.refresh_shortcut_hints(preferences.control_bindings)

	if app.scurk_editor != null:
		app.scurk_editor.set_control_bindings(preferences.control_bindings)


# Use Defaults in the Controls tab saves the default controls at once
func reset_controls() -> void:
	preferences.control_bindings = ControlBindings.defaults()
	apply_control_bindings()
	var error := SettingsStore.save_controls(preferences.control_bindings, preferences.settings_path)

	if app.main_overlays.settings_dialog != null:
		app.main_overlays.settings_dialog.show_control_bindings(preferences.control_bindings)

	app.status_label.theme_type_variation = ""
	app.status_label.text = (
		"Controls reset to their defaults." if error == OK
		else "Controls reset, but the settings file could not be saved."
	)


func set_fullscreen(enabled: bool) -> void:
	preferences.fullscreen = enabled
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	SettingsStore.save_values(preferences.music_volume, preferences.effects_volume, preferences.fullscreen, preferences.settings_path)


func _set_graphics_preferences(zoom_graphics: Array) -> void:
	var sizes := SettingsStore.normalize_zoom_graphics(zoom_graphics, preferences.overview_graphics)

	if preferences.zoom_graphics == sizes:
		return

	preferences.zoom_graphics = sizes
	app.map_render.close_region_cache()
	app.map_render.refresh_map()
