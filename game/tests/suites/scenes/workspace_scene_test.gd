extends "res://tests/support/scene_case.gd"

const WorkspaceScene = preload("res://src/ui/shell/city_workspace.tscn")


func run() -> void:
	var host := Control.new()
	host.theme = ClassicUiStyle.create_theme()
	host.size = Vector2(1280, 800)
	root.add_child(host)
	var workspace := WorkspaceScene.instantiate() as CityWorkspace
	host.add_child(workspace)
	await process_frame
	await process_frame
	var initial_map_size := workspace.map_view.size
	assert(workspace.size == host.size)
	assert(workspace.map_view.get_rect() == Rect2(Vector2.ZERO, host.size))
	host.size = Vector2(1600, 1000)
	await process_frame
	await process_frame
	assert(workspace.map_view.size.is_equal_approx(initial_map_size + Vector2(320, 200)))
	await _check_camera_bounds(workspace, host)
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
	host.free()
	await process_frame
	print("PASS: Workspace scene composition, resize layout and artwork initialization")


func _check_camera_bounds(workspace: CityWorkspace, host: Control) -> void:
	var map := workspace.map_view
	map.city_source = CityMapSource.new(Vector2i(4096, 2304))

	for window_size in [Vector2i(1280, 800), Vector2i(1600, 1000)]:
		host.size = window_size
		await process_frame
		await process_frame
		var open_area: Control = workspace.get_node("Page/Content/MapSpace")
		var camera_rect := Rect2(open_area.global_position - map.global_position, open_area.size)
		assert(map.camera_view_rect == camera_rect)
		assert(camera_rect.position.x == workspace.toolbar.size.x)

		for zoom: float in CityMapControl.ZOOM_LEVELS:
			map.zoom_factor = zoom
			map.source_center = Vector2(-100000, -100000)
			map.camera._clamp_source_center()
			var side_padding := float(CityIsometricRenderer.TOP_MARGIN - CityIsometricRenderer.SIDE_MARGIN)
			var first_pixel := map.camera._draw_offset(zoom) - Vector2(side_padding * zoom, 0)
			assert(first_pixel.x >= camera_rect.position.x - 0.5, "Left map edge is behind the sidebar")
			assert(first_pixel.y >= camera_rect.position.y - 0.5, "Top map edge is behind the menu")
			map.source_center = Vector2(100000, 100000)
			map.camera._clamp_source_center()
			var last_pixel := map.camera._draw_offset(zoom) + (Vector2(map.city_source.size) + Vector2(side_padding, 0)) * zoom
			assert(last_pixel.x <= camera_rect.end.x + 0.5)
			assert(last_pixel.y <= camera_rect.end.y + 0.5)

		map.zoom_factor = 1.0
		map.source_center = Vector2(map.city_source.size) * 0.5
		var anchor := camera_rect.get_center() + Vector2(80, 40)
		var source_anchor := (anchor - map.camera._draw_offset(1.0))
		assert(map.zoom_in(anchor))
		assert(((anchor - map.camera._draw_offset(map.zoom_factor)) / map.zoom_factor).distance_to(source_anchor) <= 0.5)
		var center := map.source_center
		assert(map.zoom_out(Vector2.INF))
		assert(map.source_center.distance_to(center) <= 0.5, "Toolbar zoom moved the visible center")
		assert(map.scroll_state().page == camera_rect.size)
		assert(map.set_scroll_value(0, 0.0))
		assert(is_equal_approx(map.scroll_state().value.x, 0.0))
		assert(map.set_scroll_value(0, 100000.0))
		# Rendering still includes the strips behind the overlay panels.
		assert(map.visible_source_rect().size == map.size)

	workspace.set_editor_controls_visible(false)
	assert(map.camera._camera_rect() == Rect2(Vector2.ZERO, map.size))
	workspace.set_editor_controls_visible(true)
	assert(map.camera._camera_rect() == map.camera_view_rect and map.camera_view_rect.has_area())
