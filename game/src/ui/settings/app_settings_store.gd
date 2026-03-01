class_name AppSettingsStore
extends RefCounted

const SETTINGS_PATH := "user://settings.cfg"
const GRAPHICS_ZOOMS := [25, 50, 100, 200, 300, 400]
const GRAPHICS_SIZES := ["Small", "Medium", "Large"]
const DEFAULT_ZOOM_GRAPHICS := [0, 1, 2, 2, 2, 2]


static func load_values(
	path := SETTINGS_PATH,
	default_music_volume := 0.8,
	default_effects_volume := 0.8,
	default_fullscreen := false
) -> Dictionary:
	var result := {
		"default_mayor_name": "Mayor",
		"overview_graphics": 0,
		"music_volume": clampf(default_music_volume, 0.0, 1.0),
		"effects_volume": clampf(default_effects_volume, 0.0, 1.0),
		"fullscreen": default_fullscreen,
		"graphics_source": "auto",
		"graphics_folder": "",
		"soundtrack_folder": "",
		"city_renderer": "gpu",
		"zoom_graphics": normalize_zoom_graphics(DEFAULT_ZOOM_GRAPHICS),
		"background_audio": false,
		"shuffle_music": false,
		"original_compatibility": false,
		"warn_sc2x_conversion": true,
		"toolbar_sounds": true,
		"sound_pack_folder": "",
		"music_pack_folder": "",
	}
	var config := ConfigFile.new()

	if config.load(path) != OK:
		return result

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

	for key in ["toolbar_sounds", "sound_pack_folder", "music_pack_folder"]:
		result[key] = config.get_value("audio", key, result[key])

	result.warn_sc2x_conversion = bool(config.get_value("simulation", "warn_sc2x_conversion", true))
	result.original_compatibility = bool(config.get_value("simulation", "original_compatibility", false))
	result.shuffle_music = bool(config.get_value("audio", "shuffle_music", false))
	result.background_audio = bool(config.get_value("audio", "background_audio", false))
	result.soundtrack_folder = str(config.get_value("audio", "soundtrack_folder", ""))
	result.fullscreen = bool(
		config.get_value("display", "fullscreen", result.fullscreen)
	)
	result.graphics_source = str(config.get_value("graphics", "source", "auto"))


	result.graphics_folder = str(config.get_value("graphics", "folder", ""))
	result.zoom_graphics = normalize_zoom_graphics(config.get_value("graphics", "zoom_graphics", DEFAULT_ZOOM_GRAPHICS))
	result.city_renderer = normalize_renderer(config.get_value("display", "city_renderer", "gpu"))

	return result


static func normalize_renderer(value: Variant) -> String:
	return "cpu" if str(value) == "cpu" else "gpu"


static func normalize_zoom_graphics(value: Variant) -> Array[int]:
	var result: Array[int] = []

	for index in GRAPHICS_ZOOMS.size():
		var size_index: int = DEFAULT_ZOOM_GRAPHICS[index]

		if value is Array and index < value.size() and (value[index] is int or value[index] is float):
			size_index = clampi(int(value[index]), 0, GRAPHICS_SIZES.size() - 1)

		result.append(maxi(size_index, result.back() if not result.is_empty() else 0))

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
	original_compatibility: Variant = null,
	warn_sc2x_conversion: Variant = null,
	default_mayor_name: Variant = null,
	overview_graphics: Variant = null,
) -> Error:
	var config := ConfigFile.new()

	if FileAccess.file_exists(path):
		config.load(path)

	if not graphics_source.is_empty():
		config.set_value("graphics", "source", graphics_source)
		config.set_value("graphics", "folder", graphics_folder)

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

	if warn_sc2x_conversion != null:
		config.set_value("simulation", "warn_sc2x_conversion", bool(warn_sc2x_conversion))

	if original_compatibility != null:
		config.set_value("simulation", "original_compatibility", bool(original_compatibility))

	if shuffle_music != null:
		config.set_value("audio", "shuffle_music", bool(shuffle_music))

	if background_audio != null:
		config.set_value("audio", "background_audio", bool(background_audio))

	if zoom_graphics != null:
		config.set_value("graphics", "zoom_graphics", normalize_zoom_graphics(zoom_graphics))

	for pair in [["toolbar_sounds", toolbar_sounds], ["sound_pack_folder", sound_pack_folder], ["music_pack_folder", music_pack_folder]]:
		if pair[1] != null:
			config.set_value("audio", pair[0], pair[1])

	return config.save(path)


static func save_original_compatibility(enabled: bool, path := SETTINGS_PATH) -> Error:
	var config := ConfigFile.new()

	if FileAccess.file_exists(path):
		config.load(path)

	config.set_value("simulation", "original_compatibility", enabled)

	return config.save(path)
