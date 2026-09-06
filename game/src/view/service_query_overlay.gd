class_name ServiceQueryOverlay
extends RefCounted

var analysis: ServiceQueryAnalysis.Result
var polygons: Array[PackedVector2Array] = []
var colors: Array[Color] = []
var station_polygons: Array[PackedVector2Array] = []
var fill_mesh: ArrayMesh
var border_mesh: ArrayMesh
var station_border_mesh: ArrayMesh
var station_highlight_mesh: ArrayMesh


func rebuild(city: CityState, result: ServiceQueryAnalysis.Result) -> void:
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

	fill_mesh = _fill_mesh(polygons, colors)
	border_mesh = _stroke_mesh(polygons, 0.65, Color(0.08, 0.18, 0.28, 0.7))
	station_border_mesh = _stroke_mesh(station_polygons, 3.5, Color("172333"))
	station_highlight_mesh = _stroke_mesh(station_polygons, 1.8, Color("fff1a3"))


static func _fill_mesh(shapes: Array[PackedVector2Array], tints: Array[Color]) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var vertex_colors := PackedColorArray()
	var indices := PackedInt32Array()
	for i in shapes.size():
		var tint := tints[i]
		tint.a = 0.55
		_append_quad(vertices, vertex_colors, indices, shapes[i], tint)
	return _mesh(vertices, vertex_colors, indices)


static func _stroke_mesh(shapes: Array[PackedVector2Array], width: float, tint: Color) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var vertex_colors := PackedColorArray()
	var indices := PackedInt32Array()
	for polygon in shapes:
		# cache the same closed miter joins as the former draw_polyline calls
		var outside := PackedVector2Array()
		var inside := PackedVector2Array()
		for i in polygon.size():
			var incoming := (polygon[i] - polygon[posmod(i - 1, polygon.size())]).normalized()
			var outgoing := (polygon[(i + 1) % polygon.size()] - polygon[i]).normalized()
			var normal := Vector2(-incoming.y, incoming.x)
			var next_normal := Vector2(-outgoing.y, outgoing.x)
			var miter := (normal + next_normal).normalized()
			var length := width * 0.5 / maxf(absf(miter.dot(normal)), 0.1)
			outside.append(polygon[i] + miter * length)
			inside.append(polygon[i] - miter * length)
		for i in polygon.size():
			var next := (i + 1) % polygon.size()
			_append_quad(vertices, vertex_colors, indices,
				PackedVector2Array([outside[i], outside[next], inside[next], inside[i]]), tint)
	return _mesh(vertices, vertex_colors, indices)


static func _append_quad(vertices: PackedVector2Array, vertex_colors: PackedColorArray,
	indices: PackedInt32Array, polygon: PackedVector2Array, tint: Color) -> void:
	var first := vertices.size()
	for point in polygon:
		vertices.append(point)
		vertex_colors.append(tint)
	for index in [0, 1, 2, 0, 2, 3]:
		indices.append(first + index)


static func _mesh(vertices: PackedVector2Array, vertex_colors: PackedColorArray,
	indices: PackedInt32Array) -> ArrayMesh:
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = vertex_colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func coverage_color(value: int, fire := false) -> Color:
	var weak := Color("ffe45c") if fire else Color("58cbe8")
	var strong := Color("e53935") if fire else Color("2461df")
	return weak.lerp(strong, clampf(value / 255.0, 0.0, 1.0))


func draw_on(canvas: Control, scale: float, offset: Vector2) -> void:
	canvas.draw_set_transform(offset, 0.0, Vector2.ONE * scale)
	if fill_mesh != null:
		canvas.draw_mesh(fill_mesh, null)
	if border_mesh != null:
		canvas.draw_mesh(border_mesh, null)
	if station_border_mesh != null:
		canvas.draw_mesh(station_border_mesh, null)
	if station_highlight_mesh != null:
		canvas.draw_mesh(station_highlight_mesh, null)

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
	canvas.draw_style_box(canvas.get_theme_stylebox("panel", "MapLegend"), panel)
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
			HORIZONTAL_ALIGNMENT_LEFT, width - 24, 14, canvas.get_theme_color("font_color", "MapLegend"))
	for i in 48:
		canvas.draw_rect(Rect2(panel.position + Vector2(12 + i * (width - 24) / 48.0, 63),
			Vector2((width - 24) / 48.0 + 1, 9)), coverage_color(roundi(i * 255.0 / 47.0), analysis.fire))
	canvas.draw_string(ThemeDB.fallback_font, panel.position + Vector2(12, 86), "Weak", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			canvas.get_theme_color("font_color", "MapLegend"))
	canvas.draw_string(ThemeDB.fallback_font, panel.position + Vector2(width - 52, 86), "Strong", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			canvas.get_theme_color("font_color", "MapLegend"))


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
