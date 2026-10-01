extends "res://tests/support/core_test_suite.gd"
## Rendering: map interaction checks.

@warning_ignore_start("integer_division")

const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const MapControl = preload("res://src/view/city_map_control.gd")
const DynamicSpriteCanvas = preload("res://src/view/city_dynamic_sprite_canvas.gd")
const Signs = preload("res://src/tools/city/sign_command.gd")


func run(
	starter: CityState, surface_city: CityState,
	surface_point: Vector2i, raised_polygon: PackedVector2Array
) -> void:
	var map_control := MapControl.new()
	map_control.city = starter
	_check(map_control.zoom_percent() == 100, "City view starts at native large-sprite scale")
	_check(map_control.zoom_in(), "City view accepts a fixed zoom-in step")
	_check(map_control.zoom_percent() == 200, "City view zoom-in doubles source pixels")
	_check(map_control.zoom_in() and map_control.zoom_percent() == 300,
		"City view supports the intermediate 300 percent zoom")
	_check(map_control.zoom_in() and map_control.zoom_percent() == 400,
		"City view supports the additional 400 percent closer zoom")
	_check(not map_control.zoom_in(), "City view rejects zoom above the largest fixed level")
	_check(map_control.zoom_out() and map_control.zoom_percent() == 300,
		"City view zoom-out restores the 300 percent level")
	_check(map_control.zoom_out() and map_control.zoom_percent() == 200,
		"City view zoom-out restores the 200 percent level")
	_check(map_control.zoom_out(), "City view accepts a fixed zoom-out step")
	_check(map_control.zoom_percent() == 100, "City view zoom-out restores native scale")
	_check(
		map_control.camera.wheel_zoom(1, Vector2.INF, 1000)
		and map_control.zoom_percent() == 200,
		"Mouse wheel accepts one zoom level at the start of its debounce interval",
	)
	_check(
		not map_control.camera.wheel_zoom(-1, Vector2.INF, 1249)
		and map_control.zoom_percent() == 200,
		"Mouse wheel rejects another zoom level before 250 milliseconds",
	)
	_check(
		not map_control.camera.wheel_zoom(1, Vector2.INF, 1450)
		and map_control.zoom_percent() == 200,
		"Mouse wheel events in one continuing gesture extend the debounce interval",
	)
	_check(
		not map_control.camera.wheel_zoom(-1, Vector2.INF, 1499)
		and map_control.zoom_percent() == 200,
		"Mouse wheel extends the interval up to 500 milliseconds after a zoom",
	)
	_check(
		map_control.camera.wheel_zoom(-1, Vector2.INF, 1500)
		and map_control.zoom_percent() == 100,
		"A continuing gesture changes the next level 500 milliseconds after a zoom",
	)
	_check(
		not map_control.camera.wheel_zoom(1, Vector2.INF, 1749)
		and map_control.zoom_percent() == 100,
		"Mouse wheel rejects a level in the next 250 milliseconds",
	)
	_check(
		map_control.camera.wheel_zoom(1, Vector2.INF, 1999)
		and map_control.zoom_percent() == 200,
		"Mouse wheel accepts the next level after a 250 millisecond pause",
	)
	var center_tile := Vector2i(64, 64)
	var center_polygon := IsometricRenderer.tile_polygon(starter, center_tile.x, center_tile.y)
	var expected_center := (
		center_polygon[0] + center_polygon[1] + center_polygon[2] + center_polygon[3]
	) * 0.25
	_check(map_control.center_on_tile(center_tile), "Center tool accepts a city tile")
	_check(map_control.source_center == expected_center, "Center tool uses the altitude-aware tile center")
	_check(
		map_control.center_tile() == center_tile,
		"Map control reports centered tile %s, got %s" % [center_tile, map_control.center_tile()],
	)
	_check(not map_control.center_on_tile(Vector2i(-1, 0)), "Center tool rejects an invalid tile")
	_check(not map_control.is_left_drag_active(), "Map control starts without an active left drag")
	_test_scroll_limits(starter)

	_test_signs(map_control, starter, center_tile)

	_test_selection_geometry(map_control, starter, center_tile, surface_city, surface_point, raised_polygon)

	var selection_complete_signals := _test_selection_signals(map_control, starter, center_tile)

	_test_repeat_placement(starter, center_tile)

	_check(map_control.dynamic_sprites.size() == 1, "Map control accepts a dynamic sprite layer")
	map_control.layers._ensure_base_layer()
	var many_dynamic_sprites: Array[CityDynamicVisual] = []

	for index in 1500:
		many_dynamic_sprites.append(CityDynamicVisual.new(null, Vector2(index, index)))

	map_control.set_dynamic_sprites(many_dynamic_sprites)
	_check(
		map_control.dynamic_sprites.size() == 1500
		and map_control.presentation.dynamic_render_node_count() == 1
		and map_control.layers.dynamic_canvas is Node2D,
		"Map control batches 1,500 dynamic sprites in one render node",
	)
	var center_requests: Array[Vector2i] = []
	map_control.center_requested.connect(func(point: Vector2i) -> void:
		center_requests.append(point))
	var center_click := InputEventMouseButton.new()
	center_click.button_index = MOUSE_BUTTON_MIDDLE
	center_click.position = map_control.size * 0.5
	center_click.pressed = true
	map_control.interaction._handle_mouse_button(center_click)
	_check(center_requests.is_empty(), "Middle-button press waits for release before Center")
	center_click.pressed = false
	map_control.interaction._handle_mouse_button(center_click)
	_check(center_requests == [center_tile] and selection_complete_signals[0] == 1,
		"Middle click requests Center without applying the selected build tool")
	center_click.button_index = MOUSE_BUTTON_RIGHT
	map_control.control_bindings = _rebound(MOUSE_BUTTON_RIGHT, "map_context_menu", "map_center_on_tile")
	center_click.pressed = true
	map_control.interaction._handle_mouse_button(center_click)
	center_click.pressed = false
	map_control.interaction._handle_mouse_button(center_click)
	_check(center_requests == [center_tile, center_tile] and selection_complete_signals[0] == 1,
		"A right button bound to Center requests Center without applying the selected build tool")
	_test_context_menu(map_control, center_tile, center_requests, selection_complete_signals)
	center_click.pressed = true
	map_control.interaction._handle_mouse_button(center_click)
	var right_drag := InputEventMouseMotion.new()
	right_drag.relative = Vector2(12, 8)
	right_drag.position = center_click.position + right_drag.relative
	right_drag.button_mask = MOUSE_BUTTON_MASK_RIGHT
	map_control.interaction._handle_mouse_motion(right_drag)
	center_click.pressed = false
	center_click.position = right_drag.position
	map_control.interaction._handle_mouse_button(center_click)
	_check(center_requests.size() == 2, "Right drag release does not invoke Center")
	var visual_revision := map_control.layers.dynamic_canvas.visual_revision
	var dynamic_position := map_control.layers.dynamic_canvas.position
	var middle_press := InputEventMouseButton.new()
	middle_press.button_index = MOUSE_BUTTON_MIDDLE
	middle_press.pressed = true
	map_control.interaction._handle_mouse_button(middle_press)
	var pan_motion := InputEventMouseMotion.new()
	pan_motion.relative = Vector2(12, 8)
	pan_motion.position = Vector2(12, 8)
	pan_motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	map_control.interaction._handle_mouse_motion(pan_motion)
	_check(
		map_control.is_panning()
		and map_control.layers.dynamic_canvas.visual_revision == visual_revision
		and map_control.layers.dynamic_canvas.position != dynamic_position,
		"Middle-button panning moves the cached dynamic canvas without rebuilding it",
	)
	var middle_release := InputEventMouseButton.new()
	middle_release.button_index = MOUSE_BUTTON_MIDDLE
	middle_release.position = pan_motion.position
	map_control.interaction._handle_mouse_button(middle_release)
	_check(center_requests.size() == 2, "Middle drag release does not invoke Center")
	map_control.interaction._handle_mouse_button(middle_press)
	pan_motion.button_mask = 0
	map_control.interaction._handle_mouse_motion(pan_motion)
	_check(
		not map_control.is_panning(),
		"Map panning stops if the pointer no longer reports a pressed pan button",
	)
	map_control.set_dynamic_sprites([])
	_check(map_control.dynamic_sprites.is_empty(), "Map control clears its dynamic sprite layer")
	_test_marker_batches()

	map_control.free()


func _test_scroll_limits(starter: CityState) -> void:
	var scroll_control := MapControl.new()
	scroll_control.size = Vector2(400, 300)
	var scroll_image := Image.create_empty(1000, 800, false, Image.FORMAT_RGBA8)
	scroll_control.set_city_view(starter, CityMapSource.whole(ImageTexture.create_from_image(scroll_image)))
	var initial_scroll := scroll_control.camera.scroll_state()
	_check(
		initial_scroll.content == Vector2(1960, 800)
		and initial_scroll.page == Vector2(400, 300)
		and initial_scroll.value == Vector2(780, 250),
		"City scroll state includes horizontal padding, visible page, and centered offsets",
	)
	_check(
		scroll_control.camera.set_scroll_value(0, 600)
		and scroll_control.camera.set_scroll_value(1, 500)
		and scroll_control.source_center == Vector2(320, 650)
		and scroll_control.camera.scroll_state().value == Vector2(600, 500),
		"City scroll values move the source center on both axes",
	)
	_check(
		scroll_control.camera.set_scroll_value(0, 9999)
		and scroll_control.camera.scroll_state().value.x == 1560
		and not scroll_control.camera.set_scroll_value(2, 0),
		"City scroll values clamp to the last visible page and reject an invalid axis",
	)
	scroll_control.size = Vector2(2200, 900)
	scroll_control.camera._on_resized()
	var fitted_scroll := scroll_control.camera.scroll_state()
	_check(
		fitted_scroll.page == Vector2(1960, 800)
		and fitted_scroll.value == Vector2.ZERO
		and scroll_control.source_center == Vector2(500, 400),
		"A viewport larger than the city centers the texture and fills each scroll page",
	)
	scroll_control.free()


func _test_signs(map_control: CityMapControl, starter: CityState, center_tile: Vector2i) -> void:
	var small_sign := CityMapSigns.sign_layout(
		Vector2(100, 80), 40.0, IsometricRenderer.VIEW_SMALL
	)
	var medium_sign := CityMapSigns.sign_layout(
		Vector2(100, 80), 40.0, IsometricRenderer.VIEW_MEDIUM
	)
	var large_sign := CityMapSigns.sign_layout(
		Vector2(100, 80), 40.0, IsometricRenderer.VIEW_LARGE
	)
	var doubled_sign := CityMapSigns.sign_layout(
		Vector2(200, 160), 80.0, IsometricRenderer.VIEW_LARGE, 2.0
	)
	_check(
		small_sign.panel == Rect2(72, 43, 56, 17)
		and small_sign.post == Rect2(98, 60, 4, 20),
		"Small-view sign uses the recovered panel and post geometry",
	)
	_check(
		medium_sign.panel == Rect2(72, 26, 56, 19)
		and medium_sign.post == Rect2(98, 45, 4, 35),
		"Medium-view sign uses the recovered panel and post geometry",
	)
	_check(
		large_sign.panel == Rect2(72, 9, 56, 21)
		and large_sign.post == Rect2(98, 30, 4, 50),
		"Large-view sign uses the recovered panel and post geometry",
	)
	_check(
		doubled_sign.panel == Rect2(144, 18, 112, 42)
		and doubled_sign.post == Rect2(196, 60, 8, 100),
		"Extra-large sign doubles the native large-view geometry",
	)
	_check(
		CityMapSigns.sign_view_index(0.25) == IsometricRenderer.VIEW_SMALL
		and CityMapSigns.sign_view_index(0.5) == IsometricRenderer.VIEW_MEDIUM
		and CityMapSigns.sign_view_index(1.0) == IsometricRenderer.VIEW_LARGE
		and CityMapSigns.sign_view_index(2.0) == IsometricRenderer.VIEW_LARGE
		and CityMapSigns.sign_view_index(4.0) == IsometricRenderer.VIEW_LARGE
		and CityMapSigns.sign_display_multiplier(2.0) == 2.0
		and CityMapSigns.sign_display_multiplier(4.0) == 4.0,
		"Sign view selection follows all six city zoom levels",
	)
	var sign_city := CityModel.from_document(starter.document.duplicate_document())
	var sign_result := Signs.set_sign(sign_city, center_tile, "Depth Test")
	_check(sign_result.ok, "Sign bounds fixture creates a user sign")
	map_control.city = sign_city

	var sign_tile_top := IsometricRenderer.tile_polygon(sign_city, center_tile.x, center_tile.y)[0]

	# the post ends at the center of the tile in each native size
	for zoom_fixture in [
		[0.25, 152, 12], [0.5, 110, 10], [1.0, 72, 9], [2.0, 72, 9], [3.0, 72, 9], [4.0, 72, 9],
	]:
		map_control.zoom_factor = zoom_fixture[0]
		var sign_entries := map_control.sign_source_entries()
		_check(
			sign_entries.size() == 1
			and sign_entries[0].bounds.size.y == zoom_fixture[1]
			and sign_entries[0].bounds.end.y == int(sign_tile_top.y) + zoom_fixture[2]
			and sign_entries[0].draw_order == 16448,
			"Sign source bounds match zoom %.2f" % zoom_fixture[0],
		)

	var sign_cache_builds := map_control.signs.sign_cache_build_count
	map_control.sign_source_entries()
	_check(
		map_control.signs.sign_cache_build_count == sign_cache_builds,
		"Repeated sign drawing reuses the zoom-specific city-sign scan",
	)


func _test_selection_geometry(
	map_control: CityMapControl, starter: CityState, center_tile: Vector2i,
	surface_city: CityState, surface_point: Vector2i, raised_polygon: PackedVector2Array
) -> void:
	map_control.city = starter
	map_control.zoom_factor = 1.0
	map_control.set_signs_visible(false)
	_check(not map_control.signs_visible, "Data views can hide surface signs")
	map_control.set_signs_visible(true)
	map_control.selection_start = center_tile
	_check(map_control.is_left_drag_active(), "Map control reports an active left drag")
	map_control.selection_end = center_tile + Vector2i(2, 1)
	map_control.edit_enabled = true
	map_control.selection_mode = "rectangle"
	map_control.selection._rebuild_selection_path()
	_check(
		map_control.selection.selection_tiles().size() == 6,
		"Rectangle selection contains every tile while it grows",
	)
	map_control.city = surface_city
	map_control.selection_start = surface_point
	map_control.selection_end = surface_point + Vector2i(1, 0)
	map_control.selection._rebuild_selection_path()
	var terrain_selection_polygons := map_control.selection._selection_source_polygons()
	_check(
		terrain_selection_polygons.size() == 2
		and terrain_selection_polygons[0] == raised_polygon
		and terrain_selection_polygons[1] == IsometricRenderer.terrain_surface_polygon(
			surface_city, surface_point.x + 1, surface_point.y
		),
		"A multi-tile mouse selection follows each tile surface",
	)
	map_control.city = starter
	map_control.selection_start = center_tile
	map_control.selection_end = center_tile + Vector2i(2, 1)
	map_control.selection._rebuild_selection_path()
	map_control.selection_end = center_tile + Vector2i(1, 0)
	map_control.selection._rebuild_selection_path()
	_check(
		map_control.selection.selection_tiles() == [center_tile, center_tile + Vector2i(1, 0)],
		"Rectangle selection shrinks from its fixed start",
	)
	map_control.selection_mode = "point"
	map_control.point_footprint_area = 4
	_check(
		map_control.selection.point_preview_tiles(center_tile)
		== [
			Vector2i(63, 63), Vector2i(63, 64), Vector2i(63, 65), Vector2i(63, 66),
			Vector2i(64, 63), Vector2i(64, 64), Vector2i(64, 65), Vector2i(64, 66),
			Vector2i(65, 63), Vector2i(65, 64), Vector2i(65, 65), Vector2i(65, 66),
			Vector2i(66, 63), Vector2i(66, 64), Vector2i(66, 65), Vector2i(66, 66),
		],
		"Point preview shows the complete asymmetric four-tile building footprint",
	)
	map_control.point_footprint_area = 2
	_check(
		map_control.selection.point_preview_tiles(center_tile)
		== [center_tile, Vector2i(64, 65), Vector2i(65, 64), Vector2i(65, 65)],
		"Point preview starts a two-tile building footprint at the pointer",
	)
	map_control.set_edit_enabled(true, "path")
	map_control.selection_start = Vector2i(-1, -1)
	map_control.selection_end = Vector2i(-1, -1)
	map_control.hover_tile = center_tile
	_check(
		map_control.selection._selection_source_polygons() == [
			IsometricRenderer.terrain_surface_polygon(starter, center_tile.x, center_tile.y),
		],
		"An idle network tool highlights the exact hovered terrain tile",
	)
	map_control.highway_preview = true
	map_control.hover_tile = center_tile + Vector2i.ONE
	_check(map_control.selection._selection_source_polygons().size() == 4,
		"Highway hover highlights its snapped two-by-two section")
	map_control.highway_preview = false
	map_control.show_selection_preview = false
	_check(map_control.selection._selection_source_polygons().is_empty(),
		"Center can suppress all tile previews")
	map_control.show_selection_preview = true
	map_control.set_edit_enabled(false)
	_check(map_control.selection._selection_source_polygons().is_empty(),
		"Disabling network input clears its hover highlight")
	map_control.set_edit_enabled(true, "path")
	map_control.selection_start = center_tile
	map_control.selection_end = center_tile + Vector2i(3, 2)
	map_control.selection._rebuild_selection_path()
	var preview_path := map_control.selection.selection_tiles()
	_check(
		preview_path == [
			center_tile,
			center_tile + Vector2i(1, 0),
			center_tile + Vector2i(1, 1),
			center_tile + Vector2i(2, 1),
			center_tile + Vector2i(2, 2),
			center_tile + Vector2i(3, 2),
		],
		"Path selection follows a contiguous diagonal route",
	)


func _test_selection_signals(map_control: CityMapControl, starter: CityState, center_tile: Vector2i) -> Array:
	var selection_cancel_signals := [0]
	var selection_complete_signals := [0]
	var selection_start_signals := [0]
	var selection_finish_signals := [0]
	var selection_complete_drags: Array[bool] = []
	var query_signal_points: Array[Vector2i] = []
	map_control.selection_canceled.connect(func() -> void:
		selection_cancel_signals[0] += 1
	)
	map_control.selection_completed.connect(func(
		_start: Vector2i,
		_finish: Vector2i,
		_path: Array[Vector2i],
		dragged: bool
	) -> void:
		selection_complete_signals[0] += 1
		selection_complete_drags.append(dragged)
	)
	map_control.selection_started.connect(func() -> void:
		selection_start_signals[0] += 1
	)
	map_control.selection_finished.connect(func() -> void:
		selection_finish_signals[0] += 1
	)
	map_control.query_requested.connect(func(point: Vector2i) -> void:
		query_signal_points.append(point)
	)
	map_control.edit_enabled = true
	map_control.city_source = CityMapSource.whole(ImageTexture.create_from_image(
		Image.create(1, 1, false, Image.FORMAT_RGBA8)
	))
	map_control.set_selection_price(12345, false)
	_check(
		map_control.selection.selection_price_text() == "$12,345"
		and not map_control.selection_price_affordable,
		"Map control formats an unaffordable selection price",
	)
	var cancel_event := InputEventMouseButton.new()
	cancel_event.button_index = MOUSE_BUTTON_RIGHT
	cancel_event.pressed = true
	map_control.interaction._handle_mouse_button(cancel_event)
	_check(
		selection_cancel_signals[0] == 1 and selection_finish_signals[0] == 1,
		"Mouse button 2 emits canceled and finished selection signals",
	)
	_check(
		not map_control.is_left_drag_active()
		and map_control.selection.selection_tiles().is_empty()
		and map_control.selection.selection_price_text().is_empty(),
		"Canceled selection cannot commit any preview tiles",
	)
	var release_event := InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	release_event.position = Vector2.ZERO
	map_control.interaction._handle_mouse_button(release_event)
	_check(
		selection_complete_signals[0] == 0 and selection_complete_drags.is_empty(),
		"Left-button release cannot commit a mouse-button-2 cancellation",
	)
	map_control.size = Vector2(800, 600)
	var drag_start_event := InputEventMouseButton.new()
	drag_start_event.button_index = MOUSE_BUTTON_LEFT
	drag_start_event.pressed = true
	drag_start_event.position = map_control.size * 0.5
	map_control.interaction._handle_mouse_button(drag_start_event)
	_check(
		selection_start_signals[0] == 1 and selection_finish_signals[0] == 1,
		"A valid left press emits one selection-started signal",
	)
	var drag_target := center_tile + Vector2i(2, 0)
	var drag_target_polygon := IsometricRenderer.tile_polygon(
		starter, drag_target.x, drag_target.y
	)
	var drag_motion_event := InputEventMouseMotion.new()
	drag_motion_event.position = map_control.camera._draw_offset(map_control.camera._view_scale()) + (
		drag_target_polygon[0]
		+ drag_target_polygon[1]
		+ drag_target_polygon[2]
		+ drag_target_polygon[3]
	) * 0.25 * map_control.camera._view_scale()
	map_control.interaction._handle_mouse_motion(drag_motion_event)
	_check(
		map_control.selection.selection_was_dragged()
		and map_control.selection_end == drag_target,
		"Active map selection follows local pointer motion",
	)
	var drag_release_event := InputEventMouseButton.new()
	drag_release_event.button_index = MOUSE_BUTTON_LEFT
	drag_release_event.pressed = false
	drag_release_event.position = drag_motion_event.position
	map_control.interaction._handle_mouse_button(drag_release_event)
	_check(
		selection_complete_signals[0] == 1
		and selection_complete_drags == [true]
		and selection_finish_signals[0] == 2,
		"Map selection reports its moved action and finished state",
	)
	map_control.shift_query_enabled = true
	var shift_query_event := InputEventMouseButton.new()
	shift_query_event.button_index = MOUSE_BUTTON_LEFT
	shift_query_event.pressed = true
	shift_query_event.shift_pressed = true
	shift_query_event.position = map_control.size * 0.5
	map_control.interaction._handle_mouse_button(shift_query_event)
	_check(
		query_signal_points == [center_tile],
		"Shift-click emits Query for the selected landscape tile",
	)
	_check(
		not map_control.is_left_drag_active()
		and selection_complete_signals[0] == 1,
		"Shift-click does not start or commit a landscape selection",
	)
	map_control.set_dynamic_sprites([CityDynamicVisual.new(null, Vector2(10, 20))])
	return selection_complete_signals


# SIMCITY.EXE builds with a single-click tool on the press and again on each
# new tile while the left button stays down
# a button set to Context Menu opens the map menu on release. each menu item
# requests its action for the clicked tile. the other button still centers
func _test_context_menu(
	map_control: CityMapControl, center_tile: Vector2i, center_requests: Array[Vector2i], selection_complete_signals: Array
) -> void:
	var menu := RecordingContextMenu.new()
	menu.map = map_control
	map_control.context_menu = menu
	map_control.control_bindings = ControlBindings.defaults()
	var query_requests: Array[Vector2i] = []
	var bulldoze_requests: Array[Vector2i] = []
	map_control.query_requested.connect(func(point: Vector2i) -> void:
		query_requests.append(point))
	map_control.bulldoze_requested.connect(func(point: Vector2i) -> void:
		bulldoze_requests.append(point))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.position = map_control.size * 0.5
	click.pressed = true
	map_control.interaction._handle_mouse_button(click)
	_check(menu.opened == 0, "Context Menu waits for release")
	click.pressed = false
	map_control.interaction._handle_mouse_button(click)
	_check(menu.opened == 1 and menu.point == center_tile and center_requests.size() == 2 and selection_complete_signals[0] == 1,
		"Right click opens the map menu for the clicked tile without Center or the selected tool")
	_check([menu.get_item_text(0), menu.get_item_text(1), menu.get_item_text(2)] == ["Center Map", "Query Tile", "Bulldoze Tile"],
		"The map menu shows the original items in order")
	menu.id_pressed.emit(CityMapContextMenu.Item.CENTER)
	menu.id_pressed.emit(CityMapContextMenu.Item.QUERY)
	menu.id_pressed.emit(CityMapContextMenu.Item.BULLDOZE)
	_check(center_requests.size() == 3 and center_requests[2] == center_tile and query_requests == [center_tile]
		and bulldoze_requests == [center_tile], "Map menu items request Center, Query, and Bulldoze for the tile")
	click.button_index = MOUSE_BUTTON_MIDDLE
	click.pressed = true
	map_control.interaction._handle_mouse_button(click)
	click.pressed = false
	map_control.interaction._handle_mouse_button(click)
	_check(menu.opened == 1 and center_requests.size() == 4, "Middle click keeps its own Center Map action")
	map_control.control_bindings = _rebound(MOUSE_BUTTON_MIDDLE, "map_center_on_tile", "map_context_menu")
	click.pressed = true
	map_control.interaction._handle_mouse_button(click)
	click.pressed = false
	map_control.interaction._handle_mouse_button(click)
	_check(menu.opened == 2 and center_requests.size() == 4, "Middle click opens the map menu when bound to Context Menu")
	map_control.control_bindings = ControlBindings.defaults()
	map_control.context_menu = null
	menu.free()
	# keep the later counts of this suite
	center_requests.resize(2)


# the default bindings with one mouse button moved from one click action to another
func _rebound(button: MouseButton, from_action: String, to_action: String) -> ControlBindings:
	var bindings := ControlBindings.defaults()
	bindings.remove_binding(from_action, ControlBinding.mouse(button))
	bindings.add(to_action, ControlBinding.mouse(button))

	return bindings


# records the menu opening. this suite has no scene tree for a popup
class RecordingContextMenu extends CityMapContextMenu:
	var opened := 0


	func open_at(tile: Vector2i, _map_position: Vector2) -> void:
		point = tile
		opened += 1


func _test_repeat_placement(starter: CityState, center_tile: Vector2i) -> void:
	var map_control := MapControl.new()
	map_control.city = starter
	map_control.size = Vector2(800, 600)
	map_control.center_on_tile(center_tile)
	map_control.city_source = CityMapSource.whole(ImageTexture.create_from_image(
		Image.create(1, 1, false, Image.FORMAT_RGBA8)
	))
	map_control.set_edit_enabled(true, "point")
	map_control.repeat_placement = true
	var placed: Array[Vector2i] = []
	var dragged: Array[bool] = []
	var finished := [0]
	map_control.selection_completed.connect(func(
		_start: Vector2i, finish: Vector2i, _path: Array[Vector2i], moved: bool
	) -> void:
		placed.append(finish)
		dragged.append(moved)
	)
	map_control.selection_finished.connect(func() -> void:
		finished[0] += 1
	)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = map_control.size * 0.5
	map_control.interaction._handle_mouse_button(press)
	_check(placed == [center_tile] and dragged == [false], "Repeated placement builds on the press")

	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = press.position + Vector2(1, 0)
	map_control.interaction._handle_mouse_motion(motion)
	_check(placed.size() == 1, "Repeated placement waits for the cursor to enter another tile")

	var targets: Array[Vector2i] = [center_tile + Vector2i(1, 0), center_tile + Vector2i(2, 0)]

	for target in targets:
		motion.position = _tile_screen_center(map_control, starter, target)
		map_control.interaction._handle_mouse_motion(motion)

	_check(
		placed == [center_tile, targets[0], targets[1]] and dragged == [false, true, true],
		"Repeated placement builds again on each new tile while held",
	)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = motion.position
	map_control.interaction._handle_mouse_button(release)
	_check(
		placed.size() == 3 and finished[0] == 1 and not map_control.is_left_drag_active(),
		"Repeated placement release does not build again",
	)

	map_control.interaction._handle_mouse_button(press)
	motion.button_mask = 0
	motion.position = _tile_screen_center(map_control, starter, targets[0])
	map_control.interaction._handle_mouse_motion(motion)
	_check(
		placed.size() == 4 and finished[0] == 2 and not map_control.is_left_drag_active(),
		"Repeated placement stops when the pointer no longer reports the left button",
	)

	map_control.repeat_placement = false
	map_control.interaction._handle_mouse_button(press)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	map_control.interaction._handle_mouse_motion(motion)
	release.position = motion.position
	map_control.interaction._handle_mouse_button(release)
	_check(
		placed.size() == 5 and dragged[4] and placed[4] == targets[0],
		"A point tool without repeated placement builds once on release",
	)

	map_control.free()


func _tile_screen_center(map_control: CityMapControl, city: CityState, tile: Vector2i) -> Vector2:
	var polygon := IsometricRenderer.tile_polygon(city, tile.x, tile.y)

	return map_control.camera._draw_offset(map_control.camera._view_scale()) + (
		polygon[0] + polygon[1] + polygon[2] + polygon[3]
	) * 0.25 * map_control.camera._view_scale()


func _test_marker_batches() -> void:
	var marker_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	marker_image.fill(Color8(10, 10, 10, 255))
	var marker_texture := ImageTexture.create_from_image(marker_image)
	var batch_input: Array[CityDynamicVisual] = []

	for index in 1500:
		var visual := CityDynamicVisual.new(marker_texture, Vector2(index % 100, int(index / 100)), Vector2(4, 4))
		visual.image = marker_image
		visual.special_overlay = true
		visual.batch_cache_key = "marker:%d" % index
		batch_input.append(visual)

	var separator := CityDynamicVisual.new()
	separator.texture = marker_texture
	separator.image = marker_image
	separator.position = Vector2.ZERO
	separator.size = Vector2(4, 4)
	batch_input.insert(750, separator)
	var marker_batch_cache: Dictionary[String, CityDynamicVisual] = {}
	var batches := DynamicSpriteCanvas.batch_special_visuals(
		batch_input, marker_batch_cache
	)
	_check(
		batches.size() < 10
		and batches[3] == separator
		and batches[0].special_batch,
		"Dynamic marker batching keeps moving-object order and reduces 1,500 markers",
	)
	var cached_batches := DynamicSpriteCanvas.batch_special_visuals(
		batch_input, marker_batch_cache
	)
	_check(
		not marker_batch_cache.is_empty()
		and cached_batches[0].texture == batches[0].texture,
		"Dynamic marker batching reuses unchanged batch textures",
	)
