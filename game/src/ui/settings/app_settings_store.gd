class_name AppSettingsStore
extends RefCounted

const GRAPHICS_ZOOMS := [25, 50, 100, 200, 300, 400]
const GRAPHICS_SIZES := ["Small", "Medium", "Large"]
const DEFAULT_ZOOM_GRAPHICS := [0, 1, 2, 2, 2, 2]
const BINDINGS_VERSION := 1
const BINDING_PREFIX := "binding/"


static func default_path() -> String:
	return AppPaths.path("settings.cfg")


static func load_values(
	path := default_path(),
	default_music_volume := 0.8,
	default_effects_volume := 0.8,
	default_fullscreen := false
) -> LoadedValues:
	var result := LoadedValues.new()
	result.music_volume = clampf(default_music_volume, 0.0, 1.0)
	result.effects_volume = clampf(default_effects_volume, 0.0, 1.0)
	result.fullscreen = default_fullscreen
	var config := ConfigFile.new()

	if config.load(path) != OK:
		return result
	result.visual_enhancements = VisualEnhancementOptions.normalize(config.get_value("visual_enhancements", "options", {}))

	result.dark_underground = bool(config.get_value("display", "dark_underground", false))
	result.ui_theme = normalize_theme(config.get_value("general", "ui_theme", "light"))
	result.translucent_menus = bool(config.get_value("general", "translucent_menus", true))
	result.ui_scale = AppUiScale.normalize(config.get_value("general", "ui_scale", AppUiScale.DEFAULT))
	result.default_mayor_name = str(config.get_value("general", "default_mayor_name", "Mayor"))
	result.overview_graphics = clampi(int(config.get_value("graphics", "overview_graphics", 0)), 0, 2)
	result.music_volume = clampf(
		float(config.get_value("audio", "music_volume", result.music_volume)),
		0.0,
		1.0,
	)
	result.effects_volume = clampf(
		float(config.get_value("audio", "effects_volume", result.effects_volume)),
		0.0,
		1.0,
	)

	result.toolbar_sounds = bool(config.get_value("audio", "toolbar_sounds", result.toolbar_sounds))
	result.city_sounds = normalize_city_sounds(config.get_value("audio", "city_sounds", result.city_sounds))
	result.sound_pack_folder = AppPaths.loaded_path(str(config.get_value("audio", "sound_pack_folder", result.sound_pack_folder)))
	result.music_pack_folder = AppPaths.loaded_path(str(config.get_value("audio", "music_pack_folder", result.music_pack_folder)))
	result.data_pack_folder = AppPaths.loaded_path(str(config.get_value("data", "pack_folder", result.data_pack_folder)))

	result.shuffle_music = bool(config.get_value("audio", "shuffle_music", false))
	result.music_soundfont = SoundFontCatalog.normalize(str(config.get_value("audio", "music_soundfont", SoundFontCatalog.DEFAULT)))
	result.music_soundfont_path = AppPaths.loaded_path(str(config.get_value("audio", "music_soundfont_path", "")))
	result.background_audio = bool(config.get_value("audio", "background_audio", false))
	result.soundtrack_folder = AppPaths.loaded_path(str(config.get_value("audio", "soundtrack_folder", "")))
	result.fullscreen = bool(
		config.get_value("display", "fullscreen", result.fullscreen)
	)
	result.graphics_source = str(config.get_value("graphics", "source", "auto"))


	result.graphics_folder = AppPaths.loaded_path(str(config.get_value("graphics", "folder", "")))
	result.zoom_graphics = normalize_zoom_graphics(
		config.get_value("graphics", "zoom_graphics", DEFAULT_ZOOM_GRAPHICS),
		result.overview_graphics,
	)
	result.city_renderer = normalize_renderer(config.get_value("display", "city_renderer", "gpu"))

	result.check_for_updates = bool(config.get_value("updates", "check_periodically", false))
	result.update_last_check = int(config.get_value("updates", "last_check", 0))
	result.update_skipped_version = str(config.get_value("updates", "skipped_version", ""))
	result.update_checked_at = int(config.get_value("updates", "checked_at", 0))
	result.update_error = str(config.get_value("updates", "error", ""))
	result.control_bindings = load_bindings(config)
	result.debug_mode = bool(config.get_value("debug", "enabled", false))

	return result


static func normalize_theme(value: Variant) -> String:
	return "dark" if str(value) == "dark" else "light"


static func normalize_renderer(value: Variant) -> String:
	return "cpu" if str(value) == "cpu" else "gpu"


static func normalize_city_sounds(value: Variant) -> int:
	if not (value is int or value is float):
		return WaveSoundGate.CitySounds.DEFAULT

	return clampi(int(value), WaveSoundGate.CitySounds.DEFAULT, WaveSoundGate.CitySounds.OFF)


# A missing key uses the default bindings. An empty list keeps the action
# unbound. Text that does not name a key or mouse button is skipped.
static func load_bindings(config: ConfigFile) -> ControlBindings:
	var result := ControlBindings.defaults()

	for id in ControlActions.bindable_ids():
		var key := BINDING_PREFIX + id

		if not config.has_section_key("controls", key):
			continue

		var list: Array[ControlBinding] = []
		var saved: Variant = config.get_value("controls", key, PackedStringArray())

		if saved is PackedStringArray or saved is Array:
			for text in saved:
				var binding := ControlBinding.from_text(str(text))

				if binding != null and not list.any(func(other: ControlBinding) -> bool: return other.equals(binding)):
					list.append(binding)

		result.bindings[id] = list

	if not config.has_section_key("controls", "bindings_version"):
		_migrate_mouse_buttons(config, result)

	return result


# Earlier versions had one choice each for the right and middle buttons, and
# both centered the map by default. The right button now opens the context
# menu by default, so only the changed middle button choice moves across.
static func _migrate_mouse_buttons(config: ConfigFile, result: ControlBindings) -> void:
	if str(config.get_value("controls", "middle_button", "center")) != "context_menu":
		return

	result.remove_binding("map_center_on_tile", ControlBinding.mouse(MOUSE_BUTTON_MIDDLE))
	result.add("map_context_menu", ControlBinding.mouse(MOUSE_BUTTON_MIDDLE))


static func _write_bindings(config: ConfigFile, bindings: ControlBindings) -> void:
	for id in ControlActions.bindable_ids():
		config.set_value("controls", BINDING_PREFIX + id, bindings.to_texts(id))

	config.set_value("controls", "bindings_version", BINDINGS_VERSION)

	for old_key in ["right_button", "middle_button"]:
		if config.has_section_key("controls", old_key):
			config.erase_section_key("controls", old_key)


# save only the controls section, and keep every other saved value
static func save_controls(bindings: ControlBindings, path := default_path()) -> Error:
	var config := ConfigFile.new()

	if FileAccess.file_exists(path):
		config.load(path)

	_write_bindings(config, bindings)

	return config.save(path)


# each zoom level uses the size of the level below it or a larger size. the
# 10% overview size is the minimum for 25% zoom
static func normalize_zoom_graphics(value: Variant, overview_size := 0) -> Array[int]:
	var result: Array[int] = []
	var minimum := clampi(overview_size, 0, GRAPHICS_SIZES.size() - 1)

	for index in GRAPHICS_ZOOMS.size():
		var size_index: int = DEFAULT_ZOOM_GRAPHICS[index]

		if value is Array and index < value.size() and (value[index] is int or value[index] is float):
			size_index = clampi(int(value[index]), 0, GRAPHICS_SIZES.size() - 1)

		result.append(maxi(size_index, result.back() if not result.is_empty() else minimum))

	return result


static func graphics_size_at_zoom(sizes: Array[int], zoom_percent: int, overview_size := 0) -> int:
	# retain the six existing saved preferences and store overview separately
	if zoom_percent <= 10:
		return clampi(overview_size, 0, 2)

	for index in GRAPHICS_ZOOMS.size():
		if zoom_percent <= GRAPHICS_ZOOMS[index]:
			return sizes[index]

	return sizes.back()


static func save_values(
	music_volume: float, effects_volume: float, fullscreen: bool,
	path := default_path(), options: SaveOptions = null,
) -> Error:
	if options == null:
		options = SaveOptions.new()

	var config := ConfigFile.new()

	if FileAccess.file_exists(path):
		config.load(path)

	if not options.graphics_source.is_empty():
		config.set_value("graphics", "source", options.graphics_source)
		config.set_value("graphics", "folder", AppPaths.stored_path(options.graphics_folder))

	if options.dark_underground != null:
		config.set_value("display", "dark_underground", bool(options.dark_underground))

	if options.ui_theme != null:
		config.set_value("general", "ui_theme", normalize_theme(options.ui_theme))

	if options.translucent_menus != null:
		config.set_value("general", "translucent_menus", bool(options.translucent_menus))

	if options.ui_scale != null:
		config.set_value("general", "ui_scale", AppUiScale.normalize(options.ui_scale))

	if options.default_mayor_name != null:
		var mayor := str(options.default_mayor_name).strip_edges().left(23)
		config.set_value("general", "default_mayor_name", "Mayor" if mayor.is_empty() else mayor)

	if options.overview_graphics != null:
		config.set_value("graphics", "overview_graphics", clampi(int(options.overview_graphics), 0, 2))

	if options.soundtrack_folder != null:
		config.set_value("audio", "soundtrack_folder", AppPaths.stored_path(str(options.soundtrack_folder).strip_edges()))

	config.set_value("audio", "music_volume", clampf(music_volume, 0.0, 1.0))
	config.set_value("audio", "effects_volume", clampf(effects_volume, 0.0, 1.0))
	config.set_value("display", "fullscreen", fullscreen)

	if options.city_renderer != null:
		config.set_value("display", "city_renderer", normalize_renderer(options.city_renderer))

	if options.shuffle_music != null:
		config.set_value("audio", "shuffle_music", bool(options.shuffle_music))

	if options.music_soundfont != null:
		config.set_value("audio", "music_soundfont", SoundFontCatalog.normalize(str(options.music_soundfont)))

	if options.music_soundfont_path != null:
		config.set_value("audio", "music_soundfont_path", AppPaths.stored_path(str(options.music_soundfont_path).strip_edges()))

	if options.background_audio != null:
		config.set_value("audio", "background_audio", bool(options.background_audio))

	if options.city_sounds != null:
		config.set_value("audio", "city_sounds", normalize_city_sounds(options.city_sounds))

	if options.zoom_graphics != null:
		config.set_value("graphics", "zoom_graphics",
			normalize_zoom_graphics(options.zoom_graphics, int(config.get_value("graphics", "overview_graphics", 0))))

	if options.check_for_updates != null:
		config.set_value("updates", "check_periodically", bool(options.check_for_updates))

	if options.data_pack_folder != null:
		config.set_value("data", "pack_folder", AppPaths.stored_path(str(options.data_pack_folder).strip_edges()))

	if options.control_bindings != null:
		_write_bindings(config, options.control_bindings)
	if options.visual_enhancements != null:
		config.set_value("visual_enhancements", "options", VisualEnhancementOptions.normalize(options.visual_enhancements))

	for pair in [["toolbar_sounds", options.toolbar_sounds], ["sound_pack_folder", options.sound_pack_folder],
		["music_pack_folder", options.music_pack_folder]]:
		if pair[1] != null:
			config.set_value("audio", pair[0], pair[1] if pair[1] is bool else AppPaths.stored_path(str(pair[1])))

	return config.save(path)


# the Debug window saves this choice when it changes
static func save_debug_mode(enabled: bool, path := default_path()) -> Error:
	var config := ConfigFile.new()

	if FileAccess.file_exists(path):
		config.load(path)

	config.set_value("debug", "enabled", enabled)

	return config.save(path)


static func save_update_state(
	last_check: int, skipped_version: String, checked_at: int, error: String, path := default_path()
) -> Error:
	var config := ConfigFile.new()

	if FileAccess.file_exists(path):
		config.load(path)

	config.set_value("updates", "last_check", last_check)
	config.set_value("updates", "skipped_version", skipped_version)
	config.set_value("updates", "checked_at", checked_at)
	config.set_value("updates", "error", error)

	return config.save(path)


class Values extends RefCounted:
	var visual_enhancements := VisualEnhancementOptions.normalize({})
	var default_mayor_name := "Mayor"
	var ui_theme := "light"
	var ui_scale := AppUiScale.DEFAULT
	var translucent_menus := true
	var dark_underground := false
	var overview_graphics := 0
	var music_volume := 0.8
	var effects_volume := 0.8
	var fullscreen := false
	var graphics_source := "auto"
	var graphics_folder := ""
	var city_renderer := "gpu"
	var zoom_graphics: Array[int] = AppSettingsStore.normalize_zoom_graphics(DEFAULT_ZOOM_GRAPHICS)
	var background_audio := false
	var shuffle_music := false
	var music_soundfont := SoundFontCatalog.DEFAULT
	var music_soundfont_path := ""
	var toolbar_sounds := true
	var city_sounds: int = WaveSoundGate.CitySounds.DEFAULT
	var sound_pack_folder := ""
	var music_pack_folder := ""
	var data_pack_folder := ""
	var check_for_updates := false
	var control_bindings := ControlBindings.defaults()


class LoadedValues extends Values:
	# legacy file preference is read for migration, but is not a dialog option
	var soundtrack_folder := ""
	# update check state, which the update check writes
	var update_last_check := 0
	var update_skipped_version := ""
	var update_checked_at := 0
	var update_error := ""
	# debug mode shows the Debug menu and the debug query tools
	var debug_mode := false


# Null leaves a saved value unchanged. An empty graphics source keeps both graphics fields.
class SaveOptions extends RefCounted:
	var visual_enhancements: Variant = null
	var graphics_source := ""
	var graphics_folder := ""
	var soundtrack_folder: Variant = null
	var city_renderer: Variant = null
	var background_audio: Variant = null
	var zoom_graphics: Variant = null
	var toolbar_sounds: Variant = null
	var city_sounds: Variant = null
	var sound_pack_folder: Variant = null
	var music_pack_folder: Variant = null
	var shuffle_music: Variant = null
	var music_soundfont: Variant = null
	var music_soundfont_path: Variant = null
	var default_mayor_name: Variant = null
	var overview_graphics: Variant = null
	var ui_theme: Variant = null
	var dark_underground: Variant = null
	var translucent_menus: Variant = null
	var check_for_updates: Variant = null
	var data_pack_folder: Variant = null
	var ui_scale: Variant = null
	var control_bindings: ControlBindings = null
