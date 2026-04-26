extends RefCounted
## Explicit read-only assets for application tests. Preferences stay in user://.


static func configure(main: Node) -> void:
	var pack := ProjectSettings.globalize_path("res://../ext/graphics")
	assert(FileAccess.file_exists(pack.path_join("pack.json")), "Application fixture needs ext/graphics/pack.json")
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", pack)
	main.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
