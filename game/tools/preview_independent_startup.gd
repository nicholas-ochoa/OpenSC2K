extends SceneTree
## Run the game UI without original assets or audio. Saves use the usual dialogs.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "free")
	OS.unset_environment("OPENSC2K_GRAPHICS_PACK")
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	main.reference_root = ProjectSettings.globalize_path("user://independent-preview-no-original-data")
	root.add_child(main)
	root.title = "OpenSC2K - Independent startup check"
