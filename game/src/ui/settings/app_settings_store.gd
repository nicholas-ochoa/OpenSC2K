class_name AppSettingsStore
extends RefCounted

const SETTINGS_PATH := "user://settings.cfg"
const GRAPHICS_ZOOMS := [25, 50, 100, 200, 300, 400]
const GRAPHICS_SIZES := ["Small", "Medium", "Large"]
const DEFAULT_ZOOM_GRAPHICS := [0, 1, 2, 2, 2, 2]


class Values extends RefCounted:
	var default_mayor_name := "Mayor"
	var ui_theme := "light"
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
	var toolbar_sounds := true
	var sound_pack_folder := ""
	var music_pack_folder := ""
	var data_pack_folder := ""
	var check_for_updates := false


class LoadedValues extends Values:
	# legacy file preference is read for migration, but is not a dialog option
	var soundtrack_folder := ""
	# update check state, which the update check writes
	var update_last_check := 0
	var update_skipped_version := ""
	var update_checked_at := 0
	var update_error := ""


static func load_values(
	path := SETTINGS_PATH,
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

	result.dark_underground = bool(config.get_value("display", "dark_underground", false))
	result.ui_theme = normalize_theme(config.get_value("general", "ui_theme", "light"))
	result.translucent_menus = bool(config.get_value("general", "translucent_menus", true))
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
	result.sound_pack_folder = str(config.get_value("audio", "sound_pack_folder", result.sound_pack_folder))
	result.music_pack_folder = str(config.get_value("audio", "music_pack_folder", result.music_pack_folder))
	result.data_pack_folder = str(config.get_value("data", "pack_folder", result.data_pack_folder))

	result.shuffle_music = bool(config.get_value("audio", "shuffle_music", false))
	result.background_audio = bool(config.get_value("audio", "background_audio", false))
	result.soundtrack_folder = str(config.get_value("audio", "soundtrack_folder", ""))
	result.fullscreen = bool(
		config.get_value("display", "fullscreen", result.fullscreen)
	)
	result.graphics_source = str(config.get_value("graphics", "source", "auto"))


	result.graphics_folder = str(config.get_value("graphics", "folder", ""))
	result.zoom_graphics = normalize_zoom_graphics(config.get_value("graphics", "zoom_graphics", DEFAULT_ZOOM_GRAPHICS), result.overview_graphics)
	result.city_renderer = normalize_renderer(config.get_value("display", "city_renderer", "gpu"))

	result.check_for_updates = bool(config.get_value("updates", "check_periodically", false))
	result.update_last_check = int(config.get_value("updates", "last_check", 0))
	result.update_skipped_version = str(config.get_value("updates", "skipped_version", ""))
	result.update_checked_at = int(config.get_value("updates", "checked_at", 0))
	result.update_error = str(config.get_value("updates", "error", ""))

	return result


static func normalize_theme(value: Variant) -> String:
	return "dark" if str(value) == "dark" else "light"


static func normalize_renderer(value: Variant) -> String:
	return "cpu" if str(value) == "cpu" else "gpu"


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
	music_volume: float,
	effects_volume: float,
	fullscreen: bool,
	path := SETTINGS_PATH,
	graphics_source := "",
	graphics_folder := "",
	soundtrack_folder: Variant = null,
	city_renderer: Variant = null,
	background_audio: Variant = null,
	zoom_graphics: Variant = null,
	toolbar_sounds: Variant = null,
	sound_pack_folder: Variant = null,
	music_pack_folder: Variant = null,
	shuffle_music: Variant = null,
	default_mayor_name: Variant = null,
	overview_graphics: Variant = null,
	ui_theme: Variant = null,
	dark_underground: Variant = null,
	translucent_menus: Variant = null,
	check_for_updates: Variant = null,
	data_pack_folder: Variant = null,
) -> Error:
	var config := ConfigFile.new()

	if FileAccess.file_exists(path):
		config.load(path)

	if not graphics_source.is_empty():
		config.set_value("graphics", "source", graphics_source)
		config.set_value("graphics", "folder", graphics_folder)

	if dark_underground != null:
		config.set_value("display", "dark_underground", bool(dark_underground))

	if ui_theme != null:
		config.set_value("general", "ui_theme", normalize_theme(ui_theme))

	if translucent_menus != null:
		config.set_value("general", "translucent_menus", bool(translucent_menus))

	if default_mayor_name != null:
		var mayor := str(default_mayor_name).strip_edges().left(23)
		config.set_value("general", "default_mayor_name", "Mayor" if mayor.is_empty() else mayor)

	if overview_graphics != null:
		config.set_value("graphics", "overview_graphics", clampi(int(overview_graphics), 0, 2))

	if soundtrack_folder != null:
		config.set_value("audio", "soundtrack_folder", str(soundtrack_folder).strip_edges())

	config.set_value("audio", "music_volume", clampf(music_volume, 0.0, 1.0))
	config.set_value("audio", "effects_volume", clampf(effects_volume, 0.0, 1.0))
	config.set_value("display", "fullscreen", fullscreen)

	if city_renderer != null:
		config.set_value("display", "city_renderer", normalize_renderer(city_renderer))

	if shuffle_music != null:
		config.set_value("audio", "shuffle_music", bool(shuffle_music))

	if background_audio != null:
		config.set_value("audio", "background_audio", bool(background_audio))

	if zoom_graphics != null:
		config.set_value("graphics", "zoom_graphics",
			normalize_zoom_graphics(zoom_graphics, int(config.get_value("graphics", "overview_graphics", 0))))

	if check_for_updates != null:
		config.set_value("updates", "check_periodically", bool(check_for_updates))

	if data_pack_folder != null:
		config.set_value("data", "pack_folder", str(data_pack_folder).strip_edges())

	for pair in [["toolbar_sounds", toolbar_sounds], ["sound_pack_folder", sound_pack_folder], ["music_pack_folder", music_pack_folder]]:
		if pair[1] != null:
			config.set_value("audio", pair[0], pair[1])

	return config.save(path)


static func save_update_state(
	last_check: int, skipped_version: String, checked_at: int, error: String, path := SETTINGS_PATH
) -> Error:
	var config := ConfigFile.new()

	if FileAccess.file_exists(path):
		config.load(path)

	config.set_value("updates", "last_check", last_check)
	config.set_value("updates", "skipped_version", skipped_version)
	config.set_value("updates", "checked_at", checked_at)
	config.set_value("updates", "error", error)

	return config.save(path)
