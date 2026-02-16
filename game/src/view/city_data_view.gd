class_name CityDataView
extends RefCounted
# display-only tile data. geometry and values come from the active city
const MODES := ["land_value", "pollution", "crime", "water", "power"]
const TITLES := ["Land Value", "Pollution", "Crime", "Water Supply", "Power Supply"]
const GRID_SHADER := """
shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec2 edge = min(UV, vec2(1.0) - UV) / max(fwidth(UV), vec2(0.00001));
	float fill = smoothstep(0.45, 0.95, min(edge.x, edge.y));
	COLOR.rgb *= mix(0.28, 1.0, fill);
}
"""
const CHUNKS := {"land_value": "XVAL", "pollution": "XPLT", "crime": "XCRM"}

static func value(city: CityState, mode: String, x: int, y: int) -> int:
	if city.index_of(x, y) < 0:
		return -1
	if mode == "power":
		return 2 if city.is_powered(x, y) else (1 if city.is_powerable(x, y) else 0)
	if mode == "water":
		return 2 if city.is_watered(x, y) else (1 if city.is_piped(x, y) else 0)
	var chunk := city.document.find_chunk(CHUNKS.get(mode, ""))
	if chunk == null:
		return -1
	var index := CityDataGrid.index(chunk.decoded_payload, city.map_size, x, y)
	return chunk.decoded_payload[index] if index >= 0 else -1

static func color(value: int, mode: String) -> Color:
	if value < 0:
		return Color("535b67")
	if mode in ["water", "power"]:
		return [Color("687381"), Color("e25c46"), Color("42bde8") if mode == "water" else Color("f4d35e")][value]
	var amount := clampf(value / 255.0, 0.0, 1.0)
	if mode == "land_value":
		return Color("273c65").lerp(Color("58d7a1"), amount)
	return Color("2b5260").lerp(Color("ff694c"), amount)

static func legend(mode: String) -> String:
	if mode in ["water", "power"]:
		return "Gray: no connection   Red: not supplied   %s: supplied" % ("Blue" if mode == "water" else "Yellow")
	return "Low: dark   High: %s   Range: 0–255" % ("green" if mode == "land_value" else "red")

static func tile_text(city: CityState, mode: String, point: Vector2i) -> String:
	var number := value(city, mode, point.x, point.y)
	if number < 0:
		return "Point at a tile to inspect its value."
	var description := str(number)
	if mode in ["water", "power"]:
		description = ["No connection", "Not supplied", "Supplied"][number]
	return "Tile %d, %d: %s" % [point.x, point.y, description]

static func signature(city: CityState, mode: String) -> Array:
	var result: Array = [city.document.get_instance_id(), city.map_size, mode, city.visible_altitude_levels]
	for id in ["ALTM", "XTER", CHUNKS.get(mode, "XBIT")]:
		var chunk := city.document.find_chunk(id)
		result.append(chunk.mutation_revision if chunk != null else -1)
	return result

static func create_mesh(city: CityState, mode: String) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# match terrain painter order so raised foreground tiles cover distant tiles
	for diagonal in range(city.map_size * 2 - 1):
		for y in range(maxi(0, diagonal - city.map_size + 1), mini(city.map_size - 1, diagonal) + 1):
			var x := diagonal - y
			if not city.tile_is_visible(x, y):
				continue
			var polygon := CityIsometricRenderer.terrain_surface_polygon(city, x, y)
			var tint := color(value(city, mode, x, y), mode)
			var ground_left := Vector2(CityIsometricRenderer.SIDE_MARGIN + city.map_size * 16 + (x - y) * 16,
				CityIsometricRenderer.TOP_MARGIN + (x + y) * 8)
			var ground := PackedVector2Array([ground_left + Vector2(16, 0), ground_left + Vector2(32, 8),
				ground_left + Vector2(16, 16), ground_left + Vector2(0, 8)])
			# front walls close height discontinuities; later tile tops cover hidden walls
			for side in [1, 2]:
				if polygon[side].y < ground[side].y or polygon[side + 1].y < ground[side + 1].y:
					_append_quad(vertices, colors, uvs, indices, PackedVector2Array([polygon[side], polygon[side + 1],
						ground[side + 1], ground[side]]), tint.darkened(0.22 if side == 1 else 0.35))
			_append_quad(vertices, colors, uvs, indices, polygon, tint)
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _append_quad(vertices: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array,
	indices: PackedInt32Array, polygon: PackedVector2Array, tint: Color) -> void:
	var first := vertices.size()
	for point in polygon:
		vertices.append(point)
		colors.append(tint)
	uvs.append_array(PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]))
	for index in [0, 1, 2, 0, 2, 3]:
		indices.append(first + index)
