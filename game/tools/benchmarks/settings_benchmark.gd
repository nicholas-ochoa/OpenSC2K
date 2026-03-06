extends SceneTree

const SettingsScript = preload("res://src/ui/settings/app_settings_dialog.gd")
const SCENE_PATH := "res://src/ui/settings/app_settings_dialog.tscn"
const SAMPLES := 11
const CREATIONS := 30
const UPDATES := 2000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load(SCENE_PATH) as PackedScene if ResourceLoader.exists(SCENE_PATH) else null
	var creation_samples: Array[float] = []
	var update_samples: Array[float] = []

	for sample in range(SAMPLES + 1):
		var started := Time.get_ticks_usec()

		for index in CREATIONS:
			var dialog := scene.instantiate() as AppSettingsDialog if scene != null else SettingsScript.new()
			root.add_child(dialog)
			dialog.free()

		var creation_usec := float(Time.get_ticks_usec() - started) / CREATIONS
		var dialog := scene.instantiate() as AppSettingsDialog if scene != null else SettingsScript.new()
		root.add_child(dialog)
		dialog.set_loaded_pack("graphics", "Original", "")
		dialog.set_loaded_pack("sound", "Original", "")
		dialog.set_loaded_pack("music", "Original", "")
		await process_frame
		started = Time.get_ticks_usec()

		for index in UPDATES:
			dialog._update_zoom_graphics_choices()
			dialog.selected_values()
			dialog.set_loaded_pack("graphics", "Original", "")

		var update_usec := float(Time.get_ticks_usec() - started) / UPDATES
		dialog.free()

		if sample > 0:
			creation_samples.append(creation_usec)
			update_samples.append(update_usec)

	print(JSON.stringify({
		"godot": Engine.get_version_info().string,
		"scene": scene != null,
		"creation_and_free_usec": creation_samples,
		"update_bundle_usec": update_samples,
	}))
	quit()
