class_name ServiceQueryOverlay
extends RefCounted

var analysis: Dictionary = {}
var polygons: Array[PackedVector2Array] = []
var colors: Array[Color] = []
var station_polygons: Array[PackedVector2Array] = []


func rebuild(city: CityState, result: Dictionary) -> void:
	analysis = result
	polygons.clear()
	colors.clear()
	station_polygons.clear()
	for point: Vector2i in result.values:
		polygons.append(CityIsometricRenderer.terrain_surface_polygon(city, point.x, point.y))
		colors.append(coverage_color(int(result.values[point]), result.fire))

	for site: Rect2i in result.sites:
		for x in range(site.position.x, site.end.x):
			for y in range(site.position.y, site.end.y):
				station_polygons.append(CityIsometricRenderer.terrain_surface_polygon(city, x, y))


static func coverage_color(value: int, fire := false) -> Color:
	var weak := Color("ffe45c") if fire else Color("58cbe8")
	var strong := Color("e53935") if fire else Color("2461df")
	return weak.lerp(strong, clampf(value / 255.0, 0.0, 1.0))


func draw_on(canvas: Control, scale: float, offset: Vector2) -> void:
	canvas.draw_set_transform(offset, 0.0, Vector2.ONE * scale)
	for i in polygons.size():
		var fill := colors[i]
		fill.a = 0.55
		canvas.draw_colored_polygon(polygons[i], fill)
		var border := polygons[i].duplicate()
		border.append(border[0])
		canvas.draw_polyline(border, Color(0.08, 0.18, 0.28, 0.7), 0.65)

	for polygon in station_polygons:
		var border := polygon.duplicate()
		border.append(border[0])
		canvas.draw_polyline(border, Color("172333"), 3.5)
		canvas.draw_polyline(border, Color("fff1a3"), 1.8)

	canvas.draw_set_transform(Vector2.ZERO)
	_draw_key(canvas)


func _draw_key(canvas: Control) -> void:
	var available := Rect2(Vector2.ZERO, canvas.size)
	var workspace := canvas.get_parent()
	if workspace != null:
		var map_space := workspace.get_node_or_null("Page/Content/MapSpace") as Control
		if map_space != null:
			available = Rect2(map_space.global_position - canvas.global_position, map_space.size)

	var width := minf(390.0, available.size.x - 24.0)
	var panel := Rect2(available.position + Vector2(12, 12), Vector2(width, 174))
	canvas.draw_rect(panel, Color(0.06, 0.08, 0.12, 0.94))
	canvas.draw_rect(panel, Color("98aabf"), false, 1.0)
	var operating := "Funding: %d%% · %s" % [analysis.funding, "Powered" if analysis.powered else "No power — half strength"]
	if analysis.all_stations:
		operating = "%d stations · %d powered · Funding: %d%%" % [analysis.station_count, analysis.powered_count, analysis.funding]
	var lines := PackedStringArray(["Service Query · " + str(analysis.name),
		"Combined station coverage" if analysis.all_stations else "Selected station's coverage", "",
		operating,
		"%d affected tiles · %s" % [analysis.values.size(), "Per-tile map" if analysis.native else "Legacy map"],
		"Shift-click: all stations. Esc: clear."])
	for i in lines.size():
		canvas.draw_string(ThemeDB.fallback_font, panel.position + Vector2(12, 25 + i * 27), lines[i],
			HORIZONTAL_ALIGNMENT_LEFT, width - 24, 14, Color.WHITE)
	for i in 48:
		canvas.draw_rect(Rect2(panel.position + Vector2(12 + i * (width - 24) / 48.0, 63),
			Vector2((width - 24) / 48.0 + 1, 9)), coverage_color(roundi(i * 255.0 / 47.0), analysis.fire))
	canvas.draw_string(ThemeDB.fallback_font, panel.position + Vector2(12, 86), "Weak", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	canvas.draw_string(ThemeDB.fallback_font, panel.position + Vector2(width - 52, 86), "Strong", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


func tile_tooltip(point: Vector2i) -> String:
	if point.x < 0:
		return ""
	var value := int(analysis.values.get(point, 0))
	var band := "None" if value == 0 else ("Weak" if value < 85 else ("Moderate" if value < 170 else "Strong"))
	var detail := ""
	if Input.is_key_pressed(KEY_SHIFT):
		detail = " (%d / 255; 0x%02X)" % [value, value]
	return "Service Query · %s\n%s: %s%s\n%s" % [analysis.name,
		"Combined station coverage" if analysis.all_stations else "Selected station coverage", band, detail,
		"Inside the affected area" if value > 0 else "No station contribution" if analysis.all_stations else "No contribution from this station"]
