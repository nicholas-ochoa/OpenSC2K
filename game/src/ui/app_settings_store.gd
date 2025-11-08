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
	result.fullscreen = bool(
		config.get_value("display", "fullscreen", result.fullscreen)
	)
	return result


static func save_values(
	music_volume: float,
	effects_volume: float,
	fullscreen: bool,
	path := SETTINGS_PATH
) -> Error:
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume", clampf(music_volume, 0.0, 1.0))
	config.set_value("audio", "effects_volume", clampf(effects_volume, 0.0, 1.0))
	config.set_value("display", "fullscreen", fullscreen)
	return config.save(path)
