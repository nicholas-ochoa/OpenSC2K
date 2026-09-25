extends SceneTree
## Check the shared frost shader through the map's data and trip legends.

const TooltipRenderTest = preload("res://tests/frosted_tooltip_render_test.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Legend pixels need a native renderer")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 320)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := TooltipRenderTest.Checker.new()
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var map := CityMapControl.new()
	map.theme = AppUiTheme.current()
	map.size = background.size
	viewport.add_child(map)
	map.city_source = CityMapSource.new(Vector2i(640, 320))
	# The checker isolates background sampling from city geometry.
	map.data_view_mesh = ArrayMesh.new()
	for mode in [CityViewMode.Mode.POWER, CityViewMode.Mode.WATER, CityViewMode.Mode.HEIGHT, CityViewMode.Mode.NONE]:
		map.data_view_mode = mode
		if mode == CityViewMode.Mode.NONE:
			map.data_view_mesh = null
			map.trip_reach = TripReachOverlay.new()
			map.trip_reach.analysis = TransportTripReachResult.new()
			map.trip_reach.analysis.limit = 100
		for theme_name in ["light", "dark"]:
			AppUiTheme.select(theme_name, true)
			background.first = Color.BLACK
			background.second = Color.WHITE
			background.queue_redraw()
			map.queue_redraw()
			await _frames()
			var area := Rect2i(Vector2i(map._legend.position + Vector2(12, map._legend.size.y - 8)), Vector2i(100, 3))
			var blurred := viewport.get_texture().get_image()
			var tint: Color = map.get_theme_stylebox("panel", "MapLegend").bg_color
			var expected := Color(0.5, 0.5, 0.5).lerp(Color(tint, 1.0), tint.a)
			assert(_contrast(blurred, area) < 0.02, "Legend must blur background detail")
			assert(_distance(blurred.get_pixelv(area.get_center()), expected) < 0.025, "Legend must sample its background")
			var stable := blurred.get_region(area).get_data()
			await _frames()
			assert(viewport.get_texture().get_image().get_region(area).get_data() == stable, "Legend must not sample itself")
			background.first = Color.BLUE
			background.second = Color.GREEN
			background.queue_redraw()
			await _frames()
			assert(blurred.get_pixelv(area.get_center()).r - viewport.get_texture().get_image().get_pixelv(area.get_center()).r > 0.05,
				"Legend must follow background changes without a map redraw")
			AppUiTheme.select(theme_name, false)
			await _frames()
			assert(_distance(viewport.get_texture().get_image().get_pixelv(area.get_center()), Color(tint, 1.0)) < 0.01,
				"Disabled translucency must restore an opaque legend")
	map.trip_reach = null
	map.queue_redraw()
	await _frames()
	assert(not map._legend.visible, "Normal city view must hide the legend")
	await _test_data_tooltips(map, viewport, background)
	viewport.free()
	print("PASS: data and trip legend blur, all data hover tooltips, live backgrounds, both themes and opaque fallback")
	quit()


func _test_data_tooltips(map: CityMapControl, viewport: SubViewport, background: Control) -> void:
	map.city = CityState.from_document(EmptyCityTemplate.create(16))
	map.data_view_mesh = ArrayMesh.new()
	map.hover_tile = Vector2i(5, 5)
	background.first = Color.BLACK
	background.second = Color.WHITE
	background.queue_redraw()
	for mode in CityViewMode.DATA_MODES:
		AppUiTheme.select("dark", true)
		map.data_view_mode = mode
		map.queue_redraw()
		await _frames()
		map._legend.hide()
		await _frames()
		var tooltip := map._data_tooltip
		assert(tooltip.visible, "Each data mode must show a hover tooltip")
		assert(Rect2(Vector2.ZERO, map.size).encloses(tooltip.get_rect()), "The tooltip must fit inside the map")
		var area := Rect2i(Vector2i(tooltip.position + Vector2(12, tooltip.size.y - 3)), Vector2i(80, 1))
		var tint: Color = map.get_theme_stylebox("panel", "TooltipPanel").bg_color
		var expected := Color(0.5, 0.5, 0.5).lerp(Color(tint, 1.0), tint.a)
		var blurred := viewport.get_texture().get_image()
		assert(_contrast(blurred, area) < 0.02, "Data hover tooltips must blur background detail: %s, contrast=%f, area=%s, tooltip=%s" % [CityViewMode.key(mode), _contrast(blurred, area), area, tooltip.get_rect()])
		assert(_distance(blurred.get_pixelv(area.get_center()), expected) < 0.025, "Data hover tooltips must sample the map")
		AppUiTheme.select("dark", false)
		await _frames()
		assert(_distance(viewport.get_texture().get_image().get_pixelv(area.get_center()), Color(tint, 1.0)) < 0.01,
			"Data hover tooltips must follow the translucency setting")
	map.hover_tile = Vector2i(-1, -1)
	map.queue_redraw()
	await _frames()
	assert(not map._data_tooltip.visible, "Leaving the map must hide the data tooltip")
	map.hover_tile = Vector2i(5, 5)
	map.clear_data_view()
	await _frames()
	assert(not map._data_tooltip.visible, "Leaving a data view must hide its tooltip")


func _frames() -> void:
	for frame in 3:
		await RenderingServer.frame_post_draw


func _contrast(image: Image, area: Rect2i) -> float:
	var minimum := 1.0
	var maximum := 0.0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var brightness := image.get_pixel(x, y).v
			minimum = minf(minimum, brightness)
			maximum = maxf(maximum, brightness)
	return maximum - minimum


func _distance(first: Color, second: Color) -> float:
	return maxf(absf(first.r - second.r), maxf(absf(first.g - second.g), absf(first.b - second.b)))
