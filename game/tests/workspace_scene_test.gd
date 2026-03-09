extends SceneTree

const WorkspaceScene = preload("res://src/ui/shell/city_workspace.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.theme = ClassicUiStyle.create_theme()
	host.size = Vector2(1280, 800)
	root.add_child(host)
	var workspace := WorkspaceScene.instantiate() as CityWorkspace
	assert(workspace.get_node("%Toolbar").scene_file_path == "res://src/ui/shell/city_toolbar.tscn")
	assert(workspace.get_node("%StatusBar").scene_file_path == "res://src/ui/shell/city_status_bar.tscn")
	host.add_child(workspace)
	await process_frame
	await process_frame
	var initial_map_size := workspace.map_view.size
	var sidebar_width := workspace.toolbar.size.x
	assert(workspace.size == host.size)
	assert(workspace.menu_bar.size.x == host.size.x)
	assert(workspace.status_bar.size.x == host.size.x)
	assert(is_equal_approx(workspace.status_bar.get_rect().end.y, host.size.y))
	assert(workspace.map_view.get_rect() == Rect2(Vector2.ZERO, host.size))
	assert(workspace.map_view.get_index() < workspace.get_node("Page").get_index())
	assert(workspace.get_node("Page").mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(workspace.get_node("Page/Content").mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(workspace.get_node("Page/Content/MapSpace").mouse_filter == Control.MOUSE_FILTER_IGNORE)
	host.size = Vector2(1600, 1000)
	await process_frame
	await process_frame
	assert(workspace.map_view.size.is_equal_approx(initial_map_size + Vector2(320, 200)))
	assert(workspace.toolbar.size.x == sidebar_width)
	assert(workspace.menu_bar.size.x == host.size.x)
	assert(workspace.status_bar.size.x == host.size.x)
	assert(is_equal_approx(workspace.status_bar.get_rect().end.y, host.size.y))
	workspace.free()
	var assets := OriginalGameAssets.new()
	assets.load_ui(ProjectSettings.globalize_path("res://../references/SIMCITY2000"))
	assert(assets.toolbar_art != null)
	workspace = WorkspaceScene.instantiate() as CityWorkspace
	workspace.toolbar_art = assets.toolbar_art
	host.add_child(workspace)
	assert(workspace.toolbar.toolbar_art == assets.toolbar_art)
	assert(workspace.toolbar.toolbar_buttons[0].icon != null, "Child entered _ready without its artwork")
	assert(workspace.toolbar.zoom_in_button.icon != null)
	assert(workspace.status_bar.message_label.text == "Ready.")
	host.free()
	await process_frame
	print("PASS: Workspace scene composition, resize layout and artwork initialization")
	quit()
