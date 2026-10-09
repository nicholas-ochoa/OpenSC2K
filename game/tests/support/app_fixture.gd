extends RefCounted
## Explicit read-only assets for application tests. Preferences stay in user://.


static func configure(main: Node, skip_menu_city := false) -> void:
	if skip_menu_city:
		main.set_script(NoMenuApp)
	var pack := ProjectSettings.globalize_path("res://../ext/graphics")
	assert(FileAccess.file_exists(pack.path_join("pack.json")), "Application fixture needs ext/graphics/pack.json")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", pack)
	var data := ProjectSettings.globalize_path("res://../ext/data")
	assert(FileAccess.file_exists(data.path_join("pack.json")), "Application fixture needs ext/data/pack.json")
	OS.set_environment("OPENSC2K_DATA_PACK", data)
	main.asset_state.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	var settings := ConfigFile.new()
	settings.load(main.preferences.settings_path)

	for kind in ["sound", "music"]:
		var key: String = kind + "_pack_folder"

		if not settings.has_section_key("audio", key):
			settings.set_value("audio", key, ProjectSettings.globalize_path("res://../ext/" + kind))

	assert(settings.save(main.preferences.settings_path) == OK)


static func wait_for_visuals(main: CityApplication) -> void:
	var started := Time.get_ticks_msec()
	while not main.visual_preparation.ready:
		assert(main.visual_preparation.failure.is_empty())
		assert(Time.get_ticks_msec() - started < 60000, "City visual preparation timed out")
		await main.get_tree().process_frame


# Use only when the test does not exercise menu visibility or its private simulation.
class NoMenuInterface extends ApplicationInterface:
	func show_main_menu() -> void:
		pass


# The base class uses a script path. gdstyle incorrectly reads this method as an outer class method.
class NoMenuApp extends "res://src/main.gd":


	# gdstyle:ignore=order/class-member-order
	func _init() -> void:
		interface = NoMenuInterface.new(self)
