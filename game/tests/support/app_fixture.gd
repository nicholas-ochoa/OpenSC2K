extends RefCounted
## Explicit read-only assets for application tests. Preferences stay in user://.


# Use only when the test does not exercise menu visibility or its private simulation.
class NoMenuApp extends "res://src/main.gd":
	func _show_main_menu() -> void:
		pass


static func configure(main: Node, skip_menu_city := false) -> void:
	if skip_menu_city:
		main.set_script(NoMenuApp)
	var pack := ProjectSettings.globalize_path("res://../ext/graphics")
	assert(FileAccess.file_exists(pack.path_join("pack.json")), "Application fixture needs ext/graphics/pack.json")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", pack)
	main.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
