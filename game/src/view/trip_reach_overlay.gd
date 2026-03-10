class_name TripReachOverlay
extends RefCounted

var analysis: Dictionary = {}
var segments := PackedVector2Array()
var colors := PackedColorArray()
var arrows := PackedVector2Array()
var arrow_colors := PackedColorArray()
var markers := PackedVector2Array()
var marker_colors := PackedColorArray()
var destinations := PackedVector2Array()
var tile_costs: Dictionary = {}
var failed_points := PackedVector2Array()
var origin := Vector2.ZERO
var access := Vector2.ZERO


func rebuild(city: CityState, result: Dictionary) -> void:
	analysis = result
	segments.clear()
	colors.clear()
	arrows.clear()
	arrow_colors.clear()
	markers.clear()
	marker_colors.clear()
	destinations.clear()
	tile_costs.clear()
	failed_points.clear()
	origin = _center(city, result.origin)
	access = _center(city, result.get("start", result.origin))
	var limit := int(result.limit)
	var seen := {}

	for node: Dictionary in result.get("reachable", []):
		var key: Vector2i = node.point
		if not seen.has(key):
			seen[key] = _center(city, key, int(node.mode))
			tile_costs[key] = int(node.cost)
			markers.append(_center(city, key, int(node.mode)))
			marker_colors.append(heat_color(float(node.cost) / limit))

	for link: Dictionary in result.get("links", []):
		var a := _center(city, link.from, int(link.mode))
		var b := _center(city, link.to, int(link.mode))
		var color := heat_color(float(link.cost) / limit)
		segments.append_array(PackedVector2Array([a, b]))
		colors.append_array(PackedColorArray([color, color]))

		if int(link.mode) in [TransportTrip.HIGHWAY_MODE, TransportTrip.BUS_HIGHWAY_MODE]:
			var direction := (b - a).normalized()
			var normal := Vector2(-direction.y, direction.x)
			var tip := a.lerp(b, 0.7)
			arrows.append_array(PackedVector2Array([tip - direction * 4 + normal * 2,
				tip, tip, tip - direction * 4 - normal * 2]))
			arrow_colors.append_array(PackedColorArray([color, color, color, color]))

	var destination_sites := {}
	for point: Vector2i in result.get("destinations", {}):
		# neighbor connections end one tile outside the map
		var bounded := point.clamp(Vector2i.ZERO, Vector2i.ONE * (city.map_size - 1))
		var site := TripReachAnalysis._building_site(city, bounded)
		if destination_sites.has(site):
			continue
		destination_sites[site] = true
		var center := Vector2.ZERO
		for x in range(site.position.x, site.end.x):
			for y in range(site.position.y, site.end.y):
				center += _center(city, Vector2i(x, y))
		destinations.append(center / float(site.get_area()))

	for point: Vector2i in result.get("limit_points", {}):
		failed_points.append(seen.get(point, _center(city, point)))


func draw_on(canvas: Control, scale: float, offset: Vector2) -> void:
	if analysis.is_empty():
		return

	canvas.draw_set_transform(offset, 0.0, Vector2.ONE * scale)
	if not segments.is_empty():
		canvas.draw_multiline(segments, Color(0.12, 0.20, 0.28, 0.55), 5.0)
		canvas.draw_multiline_colors(segments, colors, 2.5)
	if not arrows.is_empty():
		canvas.draw_multiline_colors(arrows, arrow_colors, 1.5)
	for i in markers.size():
		canvas.draw_circle(markers[i], 3.5, marker_colors[i])
	for point in destinations:
		_draw_destination(canvas, point, 1.0)
	canvas.draw_dashed_line(origin, access, Color.WHITE, 1.5, 5.0)
	_draw_origin(canvas, origin, 1.0)
	for point in failed_points:
		_draw_failure(canvas, point, 1.0)
	canvas.draw_set_transform(Vector2.ZERO)
	_draw_key(canvas)


func _draw_key(canvas: Control) -> void:
	var font := ThemeDB.fallback_font
	var lines: PackedStringArray = analysis.summary
	var available := Rect2(Vector2.ZERO, canvas.size)
	# the workspace can extend the map behind the sidebar and menu
	var workspace := canvas.get_parent()
	if workspace != null:
		var map_space := workspace.get_node_or_null("Page/Content/MapSpace") as Control
		if map_space != null:
			available = Rect2(map_space.global_position - canvas.global_position, map_space.size)
	var width := minf(500.0, available.size.x - 24.0)
	var panel := Rect2(available.position + Vector2(12, 12), Vector2(width, 134 + lines.size() * 22))
	canvas.draw_rect(panel, Color(0.06, 0.08, 0.12, 0.94))
	canvas.draw_rect(panel, Color("98aabf"), false, 1.0)
	canvas.draw_string(font, panel.position + Vector2(12, 25), "Trip Query", HORIZONTAL_ALIGNMENT_LEFT, width - 24, 17, Color.WHITE)
	for i in 48:
		canvas.draw_rect(Rect2(panel.position + Vector2(12 + i * (width - 24) / 48.0, 36),
			Vector2((width - 24) / 48.0 + 1, 12)), heat_color(i / 47.0))
	canvas.draw_string(font, panel.position + Vector2(12, 67), "Low cost", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	canvas.draw_string(font, panel.position + Vector2(width - 108, 67), "Near trip limit", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	_draw_origin(canvas, panel.position + Vector2(20, 98), 0.7)
	canvas.draw_string(font, panel.position + Vector2(34, 94), "Origin", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	_draw_destination(canvas, panel.position + Vector2(122, 90), 0.8)
	canvas.draw_string(font, panel.position + Vector2(138, 94), "Destinations", HORIZONTAL_ALIGNMENT_LEFT, width - 150, 14, Color.WHITE)
	_draw_failure(canvas, panel.position + Vector2(260, 90), 0.8)
	canvas.draw_string(font, panel.position + Vector2(275, 94), "Trip limit", HORIZONTAL_ALIGNMENT_LEFT, width - 287, 14, Color.WHITE)
	canvas.draw_string(font, panel.position + Vector2(12, 120), "Trip Budget: %d" % analysis.limit, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	var status := "Destination reachable" if analysis.reached_destination else "Destination not reachable"
	var status_width := font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var status_x := width - 12 - status_width
	var icon := panel.position + Vector2(status_x - 14, 115)
	if analysis.reached_destination:
		canvas.draw_polyline(PackedVector2Array([icon + Vector2(-5, 0),
			icon + Vector2(-1, 4), icon + Vector2(6, -5)]), Color("57de91"), 2.5, true)
	else:
		_draw_failure(canvas, icon, 1.0)
	canvas.draw_string(font, panel.position + Vector2(status_x, 120), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	for i in lines.size():
		canvas.draw_string(font, panel.position + Vector2(12, 144 + i * 22), lines[i], HORIZONTAL_ALIGNMENT_LEFT, width - 24, 14, Color.WHITE)


static func heat_color(fraction: float) -> Color:
	var stops := [Color("258bff"), Color("20d6b1"), Color("f7dc50"), Color("ef594b")]
	var value := clampf(fraction, 0.0, 1.0) * 3.0
	var index := mini(int(value), 2)
	return stops[index].lerp(stops[index + 1], value - index)


static func _center(city: CityState, point: Vector2i, mode := -1) -> Vector2:
	var center := Vector2.ZERO
	for corner in CityIsometricRenderer.terrain_surface_polygon(city, point.x, point.y):
		center += corner / 4.0
	if mode in [TransportTrip.HIGHWAY_MODE, TransportTrip.BUS_HIGHWAY_MODE]:
		center.y -= CityIsometricRenderer.ALTITUDE_STEP
	return center


func tile_tooltip(point: Vector2i) -> String:
	if point.x < 0:
		return ""
	var title := "Trip Query\n"
	if analysis.get("origin_tiles", {}).has(point):
		return title + "Origin: tile %d, %d\n%s\nTrip Budget: %d" % [point.x, point.y,
			"Destination reachable" if analysis.reached_destination else "Destination not reachable", analysis.limit]
	if analysis.get("destinations", {}).has(point):
		return title + "Destination: tile %d, %d\nTrip Cost: %d / %d" % [point.x, point.y, analysis.destinations[point], analysis.limit]
	if analysis.get("access_tiles", {}).has(point):
		return title + "Building: tile %d, %d\nWithin network access\nNot a compatible destination for this trip." % [point.x, point.y]
	if analysis.get("limit_points", {}).has(point):
		return title + "Tile: %d, %d\nTrip limit reached\nTrip Cost: %d / %d" % [point.x, point.y, tile_costs[point], analysis.limit]
	if tile_costs.has(point):
		return title + "Tile: %d, %d\nMinimum Trip Cost: %d / %d" % [point.x, point.y, tile_costs[point], analysis.limit]
	return title + "Tile: %d, %d\nNot reached by this trip." % [point.x, point.y]


static func _draw_origin(canvas: Control, point: Vector2, scale: float) -> void:
	var center := point + Vector2(0, -12) * scale
	var edge := Color("244960")
	var fill := Color("42b6ff")
	var triangle := PackedVector2Array([point, point + Vector2(-7, -11) * scale,
		point + Vector2(7, -11) * scale])
	canvas.draw_colored_polygon(triangle, fill)
	canvas.draw_polyline(PackedVector2Array([triangle[1], point, triangle[2]]), edge, 1.5 * scale, true)
	canvas.draw_circle(center, 8 * scale, fill)
	canvas.draw_arc(center, 8 * scale, PI, TAU, 16, edge, 1.5 * scale, true)
	canvas.draw_circle(center, 3 * scale, Color.WHITE)


static func _draw_destination(canvas: Control, point: Vector2, scale: float) -> void:
	canvas.draw_circle(point, 8 * scale, Color("249957"))
	canvas.draw_arc(point, 8 * scale, 0, TAU, 24, Color("145c35"), 1.2 * scale, true)
	canvas.draw_polyline(PackedVector2Array([point + Vector2(-4, 0) * scale,
		point + Vector2(-1, 3) * scale, point + Vector2(4, -3) * scale]),
		Color.WHITE, 2 * scale, true)


static func _draw_failure(canvas: Control, point: Vector2, scale: float) -> void:
	var cross := PackedVector2Array([point + Vector2(-5, -5) * scale,
		point + Vector2(5, 5) * scale, point + Vector2(5, -5) * scale,
		point + Vector2(-5, 5) * scale])
	canvas.draw_multiline(cross, Color(0.16, 0.22, 0.28, 0.75), 4 * scale, true)
	canvas.draw_multiline(cross, Color("ff5959"), 2.5 * scale, true)
