class_name AppSettingsStore
extends RefCounted

const SETTINGS_PATH := "user://settings.cfg"


static func load_values(
	path := SETTINGS_PATH,
	default_music_volume := 0.8,
	default_effects_volume := 0.8,
	default_fullscreen := false
) -> Dictionary:
	var result := {
		"music_volume": clampf(default_music_volume, 0.0, 1.0),
		"effects_volume": clampf(default_effects_volume, 0.0, 1.0),
		"fullscreen": default_fullscreen,
		"graphics_source": "auto",
		"graphics_folder": "",
		"soundtrack_folder": "",
		"city_renderer": "gpu",
		"background_audio": false,
	}
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return result
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
	result.background_audio = bool(config.get_value("audio", "background_audio", false))
	result.soundtrack_folder = str(config.get_value("audio", "soundtrack_folder", ""))
	result.fullscreen = bool(
		config.get_value("display", "fullscreen", result.fullscreen)
	)
	result.graphics_source = str(config.get_value("graphics", "source", "auto"))
	result.graphics_folder = str(config.get_value("graphics", "folder", ""))
	result.city_renderer = normalize_renderer(config.get_value("display", "city_renderer", "gpu"))
	return result


static func normalize_renderer(value: Variant) -> String:
	return "cpu" if str(value) == "cpu" else "gpu"


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
) -> Error:
	var config := ConfigFile.new()
	if FileAccess.file_exists(path):
		config.load(path)
	if not graphics_source.is_empty():
		config.set_value("graphics", "source", graphics_source)
		config.set_value("graphics", "folder", graphics_folder)
	if soundtrack_folder != null:
		config.set_value("audio", "soundtrack_folder", str(soundtrack_folder).strip_edges())
	config.set_value("audio", "music_volume", clampf(music_volume, 0.0, 1.0))
	config.set_value("audio", "effects_volume", clampf(effects_volume, 0.0, 1.0))
	config.set_value("display", "fullscreen", fullscreen)
	if city_renderer != null:
		config.set_value("display", "city_renderer", normalize_renderer(city_renderer))
	if background_audio != null:
		config.set_value("audio", "background_audio", bool(background_audio))
	return config.save(path)
