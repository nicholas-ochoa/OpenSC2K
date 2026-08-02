extends SceneTree

const ToolbarScript = preload("res://src/ui/shell/city_toolbar.gd")
const SCENE_PATH := "res://src/ui/shell/city_toolbar.tscn"
const SAMPLES := 11
const CREATIONS := 100
const UPDATES := 2000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var assets := OriginalGameAssets.new()
	assets.load_ui(ProjectSettings.globalize_path("res://../references/SIMCITY2000"))
	assert(assets.toolbar_art != null)
	var scene := load(SCENE_PATH) as PackedScene if ResourceLoader.exists(SCENE_PATH) else null
	var creation_samples: Array[float] = []
	var update_samples: Array[float] = []
	var host := Control.new()
	host.theme = AppUiTheme.current()
	root.add_child(host)

	for sample in range(SAMPLES + 1):
		var started := Time.get_ticks_usec()

		for index in CREATIONS:
			var toolbar := scene.instantiate() as CityToolbar if scene != null else ToolbarScript.new()
			toolbar.toolbar_art = assets.toolbar_art
			host.add_child(toolbar)
			toolbar.free()

		var creation_usec := float(Time.get_ticks_usec() - started) / CREATIONS
		var toolbar := scene.instantiate() as CityToolbar if scene != null else ToolbarScript.new()
		toolbar.toolbar_art = assets.toolbar_art
		host.add_child(toolbar)
		toolbar.show_tool_group(9, null)
		await process_frame
		started = Time.get_ticks_usec()

		for index in UPDATES:
			toolbar.sync_view_mode(CityViewMode.Mode.CITY if index % 2 == 0 else CityViewMode.Mode.UNDERGROUND)
			toolbar.sync_child_tool_selection(9, index % 2)
			toolbar.set_landscape_editor(index % 2 == 0)

		var update_usec := float(Time.get_ticks_usec() - started) / UPDATES
		toolbar.free()

		if sample > 0:
			creation_samples.append(creation_usec)
			update_samples.append(update_usec)

	print(JSON.stringify({
		"godot": Engine.get_version_info().string,
		"scene": scene != null,
		"tool_groups": ToolCatalog.GROUPS.size(),
		"creation_and_free_usec": creation_samples,
		"update_bundle_usec": update_samples,
	}))
	host.free()
	quit()
