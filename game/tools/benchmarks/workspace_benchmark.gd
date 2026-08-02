extends SceneTree

const WorkspaceScript = preload("res://src/ui/shell/city_workspace.gd")
const SCENE_PATH := "res://src/ui/shell/city_workspace.tscn"
const SAMPLES := 11
const CREATIONS := 50
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
	host.size = Vector2(1280, 800)
	root.add_child(host)

	for sample in range(SAMPLES + 1):
		var started := Time.get_ticks_usec()

		for index in CREATIONS:
			var workspace := scene.instantiate() as CityWorkspace if scene != null else WorkspaceScript.new()
			workspace.toolbar_art = assets.toolbar_art
			host.add_child(workspace)
			workspace.free()

		var creation_usec := float(Time.get_ticks_usec() - started) / CREATIONS
		var workspace := scene.instantiate() as CityWorkspace if scene != null else WorkspaceScript.new()
		workspace.toolbar_art = assets.toolbar_art
		host.add_child(workspace)
		workspace.toolbar.show_tool_group(9, null)
		await process_frame
		await process_frame
		started = Time.get_ticks_usec()

		for index in UPDATES:
			workspace.menu_bar.set_date("01/01/2000")
			workspace.menu_bar.set_money("$20,000")
			workspace.menu_bar.set_fps(60)
			workspace.status_bar.set_environment(Vector3i(500, -200, 800), "Clear")
			workspace.status_bar.set_speed("Paused")
			workspace.status_bar.update_report_rotation(0.016)
			workspace.toolbar.sync_view_mode(CityViewMode.Mode.CITY if index % 2 == 0 else CityViewMode.Mode.UNDERGROUND)
			workspace.toolbar.sync_child_tool_selection(9, index % 2)

		var update_usec := float(Time.get_ticks_usec() - started) / UPDATES
		workspace.free()

		if sample > 0:
			creation_samples.append(creation_usec)
			update_samples.append(update_usec)

	print(JSON.stringify({
		"godot": Engine.get_version_info().string,
		"scene": scene != null,
		"creation_and_free_usec": creation_samples,
		"update_bundle_usec": update_samples,
	}))
	host.free()
	quit()
