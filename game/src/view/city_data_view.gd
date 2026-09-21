class_name CityDataView
extends RefCounted
# display-only tile data. geometry and values come from the active city
# titles follow cityviewmode.data_modes

@warning_ignore_start("integer_division")

const TITLES := [
	"Density", "Rate of Growth", "Traffic", "Pollution", "Crime",
	"Police Power", "Fire Power", "Land Value", "Water Supply", "Power Supply", "Height",
]
const GRID_SHADER := preload("res://src/view/city_data_view_grid.gdshader")
# saved data maps behind each gradient view. coarse grids sample through citydatagrid
const CHUNKS: Dictionary[CityViewMode.Mode, String] = {
	CityViewMode.Mode.DENSITY: "XPOP", CityViewMode.Mode.GROWTH: "XROG", CityViewMode.Mode.TRAFFIC: "XTRF",
	CityViewMode.Mode.POLLUTION: "XPLT", CityViewMode.Mode.CRIME: "XCRM",
	CityViewMode.Mode.POLICE_POWER: "XPLC", CityViewMode.Mode.FIRE_POWER: "XFIR",
	CityViewMode.Mode.LAND_VALUE: "XVAL",
}
# low and high ends of each gradient
static var GRADIENTS: Dictionary[CityViewMode.Mode, PackedColorArray] = {
	CityViewMode.Mode.DENSITY: PackedColorArray([Color("1f2d3f"), Color("ffd166")]),
	CityViewMode.Mode.TRAFFIC: PackedColorArray([Color("1e3a2f"), Color("ff694c")]),
	CityViewMode.Mode.POLICE_POWER: PackedColorArray([Color("1c2440"), Color("6fa8ff")]),
	CityViewMode.Mode.FIRE_POWER: PackedColorArray([Color("3a1f1c"), Color("ffa552")]),
	CityViewMode.Mode.LAND_VALUE: PackedColorArray([Color("273c65"), Color("58d7a1")]),
}
# default gradient for the remaining nuisance maps
static var DEFAULT_GRADIENT := PackedColorArray([Color("2b5260"), Color("ff694c")])
# labels under the gradient bar in the isometric legend
const RANGE_LABELS := {
	CityViewMode.Mode.HEIGHT: ["Level 1", "Level 32"],
}
# rate of growth stores a steady band around the middle of the byte range
const GROWTH_DECLINE := 0x7d
const GROWTH_INCREASE := 0x83
# decline, steady, and growth. the original map reads as a sign, not a scale
static var GROWTH_COLORS := PackedColorArray([Color("e2453c"), Color("b9c2cd"), Color("35d16a")])
# modes that read as a few named states instead of a gradient
const STATE_LABELS := {
	CityViewMode.Mode.WATER: ["No link", "No supply", "Supplied"],
	CityViewMode.Mode.POWER: ["No link", "No supply", "Supplied"],
	CityViewMode.Mode.GROWTH: ["Decline", "Steady", "Growth"],
}


static func value(city: CityState, mode: CityViewMode.Mode, x: int, y: int) -> int:
	if city.index_of(x, y) < 0:
		return -1

	if mode == CityViewMode.Mode.HEIGHT:
		return city.land_altitude(x, y)

	if mode == CityViewMode.Mode.POWER:
		return 2 if city.is_powered(x, y) else (1 if city.is_powerable(x, y) else 0)

	if mode == CityViewMode.Mode.WATER:
		return 2 if city.is_watered(x, y) else (1 if city.is_piped(x, y) else 0)

	var chunk := city.document.find_chunk(CHUNKS.get(mode, ""))

	if chunk == null:
		return -1

	var index := CityDataGrid.index(chunk.decoded_payload, city.map_size, x, y)

	return chunk.decoded_payload[index] if index >= 0 else -1


static func color(value: int, mode: CityViewMode.Mode) -> Color:
	if value < 0:
		return Color("535b67")

	if mode == CityViewMode.Mode.HEIGHT:
		return Color.from_hsv((31 - clampi(value, 0, 31)) / 31.0 * 0.75, 0.85, 0.95)

	if mode in [CityViewMode.Mode.WATER, CityViewMode.Mode.POWER]:
		return [Color("687381"), Color("e25c46"), Color("42bde8") if mode == CityViewMode.Mode.WATER else Color("f4d35e")][value]

	var amount := clampf(value / 255.0, 0.0, 1.0)

	if mode == CityViewMode.Mode.GROWTH:
		# the original map reads as a sign. exact amounts stay in the hover text
		return GROWTH_COLORS[growth_state(value)]

	var gradient: PackedColorArray = GRADIENTS.get(mode, DEFAULT_GRADIENT)

	return gradient[0].lerp(gradient[1], amount)


static func tile_text(city: CityState, mode: CityViewMode.Mode, point: Vector2i, exact := false) -> String:
	var number := value(city, mode, point.x, point.y)

	if number < 0:
		return ""

	if mode == CityViewMode.Mode.HEIGHT and city.is_water(point.x, point.y):
		var water := city.water_altitude(point.x, point.y)

		return "Terrain: %s\nWater: %s" % [_level_text(number, exact), _level_text(water, exact)]

	var description: String

	if mode in [CityViewMode.Mode.WATER, CityViewMode.Mode.POWER]:
		description = ["No connection", "Not supplied", "Supplied"][number]
	elif mode == CityViewMode.Mode.HEIGHT:
		description = "Level %d of 32" % (number + 1)
	elif mode == CityViewMode.Mode.GROWTH:
		description = ["Declining", "Steady", "Growing"][growth_state(number)]
	else:
		description = ["Very low", "Low", "Moderate", "High", "Very high"][mini((number * 5) / 256, 4)]

	var title: String = TITLES[CityViewMode.DATA_MODES.find(mode)]
	var result := "%s: %s" % [title, description]

	if mode == CityViewMode.Mode.LAND_VALUE:
		description = "Medium" if description == "Moderate" else description
		# query reports (xval + 1) thousands of dollars per acre
		result = "Land Value: $%d,000 (%s)" % [number + 1, description]

	if exact:
		var raw := city.tile_flags[city.index_of(point.x, point.y)] if mode in [CityViewMode.Mode.WATER, CityViewMode.Mode.POWER] else number
		result += "  (%s%d / 0x%02X)" % ["XBIT " if mode in [CityViewMode.Mode.WATER, CityViewMode.Mode.POWER] else "", raw, raw]

	return result


# rate of growth reads as decline, steady, or growth around its middle band
static func growth_state(number: int) -> int:
	if number < GROWTH_DECLINE:
		return 0

	return 1 if number < GROWTH_INCREASE else 2


# low and high labels for the gradient bar in the isometric legend
static func range_labels(mode: CityViewMode.Mode) -> PackedStringArray:
	return PackedStringArray(RANGE_LABELS.get(mode, ["Very low", "Very high"]))


# named states for the legend, or an empty list for a gradient mode
static func state_labels(mode: CityViewMode.Mode) -> PackedStringArray:
	return PackedStringArray(STATE_LABELS.get(mode, []))


# tile value that paints each named state in the legend
static func state_value(mode: CityViewMode.Mode, state: int) -> int:
	if mode == CityViewMode.Mode.GROWTH:
		return [0, GROWTH_DECLINE, GROWTH_INCREASE][state]

	return state


static func _level_text(level: int, exact: bool) -> String:
	var result := "Level %d of 32" % (level + 1)

	if exact:
		result += " (%d / 0x%02X)" % [level, level]

	return result


static func geometry_signature(city: CityState, mode := CityViewMode.Mode.NONE) -> Array:
	var result: Array = [city.document.get_instance_id(), city.map_size, city.visible_altitude_levels, mode == CityViewMode.Mode.HEIGHT]

	for id in ["ALTM", "XTER"]:
		var chunk := city.document.find_chunk(id)
		result.append(chunk.mutation_revision if chunk != null else -1)

	if mode == CityViewMode.Mode.HEIGHT:
		result.append(city.masked_tile_flag_signature(0x04))

	return result


static func value_image(city: CityState, mode: CityViewMode.Mode) -> Image:
	if CHUNKS.has(mode):
		var chunk := city.document.find_chunk(CHUNKS[mode])
		var data := chunk.decoded_payload if chunk != null else PackedByteArray()
		var edge := CityDataGrid.edge(data, city.map_size)

		if edge > 0:
			return Image.create_from_data(edge, edge, false, Image.FORMAT_R8, data)

		return Image.create(city.map_size, city.map_size, false, Image.FORMAT_R8)

	var data := PackedByteArray()
	data.resize(city.map_size * city.map_size)

	if mode == CityViewMode.Mode.HEIGHT:
		for index in data.size():
			data[index] = city.altitude_words[index] & 0x1f
	else:
		var flags := city.document.find_chunk("XBIT").decoded_payload
		var supplied := 0x40 if mode == CityViewMode.Mode.POWER else 0x10
		var connected := 0x80 if mode == CityViewMode.Mode.POWER else 0x20

		for index in data.size():
			data[index] = 2 if flags[index] & supplied else (1 if flags[index] & connected else 0)

	return Image.create_from_data(city.map_size, city.map_size, false, Image.FORMAT_R8, data)


static func color_image(mode: CityViewMode.Mode) -> Image:
	var image := Image.create(256, 1, false, Image.FORMAT_RGB8)

	for index in 256:
		image.set_pixel(index, 0, color(mini(index, 2) if mode in [CityViewMode.Mode.WATER, CityViewMode.Mode.POWER] else index, mode))

	return image


static func signature(city: CityState, mode: CityViewMode.Mode) -> Array:
	var result: Array = [city.document.get_instance_id(), city.map_size, mode, city.visible_altitude_levels]

	for id in ["ALTM", "XTER", CHUNKS.get(mode, "ALTM" if mode == CityViewMode.Mode.HEIGHT else "XBIT")]:
		var chunk := city.document.find_chunk(id)
		result.append(chunk.mutation_revision if chunk != null else -1)

	return result


static func surface_polygon(city: CityState, x: int, y: int, height_view := false) -> PackedVector2Array:
	return CityIsometricRenderer.terrain_surface_polygon(city, x, y, height_view)


static func visible(city: CityState, x: int, y: int, height_view: bool) -> bool:
	return city.land_altitude(x, y) < city.visible_altitude_levels if height_view else city.tile_is_visible(x, y)


static func create_mesh(city: CityState, mode: CityViewMode.Mode, encoded := false) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# compute each surface once. adjacent walls reuse the same corner heights
	var surfaces: Array[PackedVector2Array] = []
	surfaces.resize(city.map_size * city.map_size)

	for x in city.map_size:
		for y in city.map_size:
			surfaces[x * city.map_size + y] = surface_polygon(city, x, y, mode == CityViewMode.Mode.HEIGHT)

	# match terrain painter order so raised foreground tiles cover distant tiles
	for diagonal in range(city.map_size * 2 - 1):
		for y in range(maxi(0, diagonal - city.map_size + 1), mini(city.map_size - 1, diagonal) + 1):
			var x := diagonal - y

			if not visible(city, x, y, mode == CityViewMode.Mode.HEIGHT):
				continue

			var polygon := surfaces[x * city.map_size + y]
			var tint := Color.WHITE if encoded else color(value(city, mode, x, y), mode)
			var ground_left := Vector2(CityIsometricRenderer.SIDE_MARGIN + city.map_size * 16 + (x - y) * 16,
				CityIsometricRenderer.TOP_MARGIN + (x + y) * 8)
			var ground := PackedVector2Array([ground_left + Vector2(16, 0), ground_left + Vector2(32, 8),
				ground_left + Vector2(16, 16), ground_left + Vector2(0, 8)])
			var left_bottom := ground[2]

			# only exposed walls need fragments. neighbor tops cover everything below them
			if x + 1 < city.map_size and visible(city, x + 1, y, mode == CityViewMode.Mode.HEIGHT):
				var neighbor := surfaces[(x + 1) * city.map_size + y]
				ground[1] = Vector2(polygon[1].x, maxf(polygon[1].y, neighbor[0].y))
				ground[2] = Vector2(polygon[2].x, maxf(polygon[2].y, neighbor[3].y))

			if y + 1 < city.map_size and visible(city, x, y + 1, mode == CityViewMode.Mode.HEIGHT):
				var neighbor := surfaces[x * city.map_size + y + 1]
				left_bottom = Vector2(polygon[2].x, maxf(polygon[2].y, neighbor[1].y))
				ground[3] = Vector2(polygon[3].x, maxf(polygon[3].y, neighbor[0].y))

			for side in [1, 2]:
				if side == 2:
					ground[2] = left_bottom

				if polygon[side].y < ground[side].y or polygon[side + 1].y < ground[side + 1].y:
					_append_quad(vertices, colors, uvs, indices, PackedVector2Array([polygon[side], polygon[side + 1],
						ground[side + 1], ground[side]]),
						Color(tint.r, tint.g, 0.78 if side == 1 else 0.65) if encoded else tint.darkened(0.22 if side == 1 else 0.35),
						Vector2(y, x) * 2 if encoded else Vector2.ZERO)

			_append_quad(vertices, colors, uvs, indices, polygon, tint, Vector2(y, x) * 2 if encoded else Vector2.ZERO)

			if mode == CityViewMode.Mode.HEIGHT and city.is_water(x, y) and city.water_altitude(x, y) < city.visible_altitude_levels:
				var water := CityIsometricRenderer.tile_polygon(city, x, y)

				# the water flag can also occur on a flat terrain code
				if city.terrain_id(x, y) < TerrainTileIds.DEEP_WATER_FIRST:
					for corner in 4:
						water[corner].y -= (city.water_altitude(x, y) - city.land_altitude(x, y)) * CityIsometricRenderer.ALTITUDE_STEP

				_append_quad(vertices, colors, uvs, indices, water, Color(1, 1, 1, 0.28), Vector2(y, x) * 2 if encoded else Vector2.ZERO)

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
	indices: PackedInt32Array, polygon: PackedVector2Array, tint: Color, uv_origin := Vector2.ZERO) -> void:
	var first := vertices.size()

	for point in polygon:
		vertices.append(point)
		colors.append(tint)

	uvs.append_array(PackedVector2Array([uv_origin, uv_origin + Vector2.RIGHT, uv_origin + Vector2.ONE, uv_origin + Vector2.DOWN]))

	for index in [0, 1, 2, 0, 2, 3]:
		indices.append(first + index)
