extends SceneTree
var main: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("OPENSC2K_ASSET_SOURCE", "original")
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	root.title = "Data Views Preview"
	await process_frame
	var doc := Sc2File.load_path(ProjectSettings.globalize_path("res://../references/SIMCITY2000/CITIES/CAPEQUES.SC2"))
	main.city_session._activate_document(doc)
	main.frame._select_speed(GameSpeedController.Speed.PAUSED)
	main.current_tool._select_tool_group(16)
	main.menus._set_overlay(CityViewMode.Mode.HEIGHT)
	main.map_view.zoom_factor = 0.5
	main.map_view.queue_redraw()
