extends RefCounted
## Explicit read-only assets for application tests. Preferences stay in user://.


# Use only when the test does not exercise menu visibility or its private simulation.
class NoMenuInterface extends ApplicationInterface:
	func show_main_menu() -> void:
		pass


class NoMenuApp extends "res://src/main.gd":
	func _init() -> void:
		interface = NoMenuInterface.new(self)


static func configure(main: Node, skip_menu_city := false) -> void:
	if skip_menu_city:
		main.set_script(NoMenuApp)
	var pack := ProjectSettings.globalize_path("res://../ext/graphics")
	assert(FileAccess.file_exists(pack.path_join("pack.json")), "Application fixture needs ext/graphics/pack.json")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", pack)
	main.asset_state.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
