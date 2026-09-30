class_name CityDataView
extends RefCounted


# display-only tile data. geometry and values come from the active city
# titles follow cityviewmode.data_modes

@warning_ignore_start("integer_division")

const TITLES := [
	"Density", "Rate of Growth", "Traffic", "Pollution", "Crime",
	"Police Power", "Fire Power", "Land Value", "Water Supply", "Power Supply", "Heightmap",
]
const GRID_SHADER := preload("res://src/view/city_data_view_grid.gdshader")
# saved data maps behind each gradient view. coarse grids sample through citydatagrid
const CHUNKS: Dictionary[CityViewMode.Mode, String] = {
	CityViewMode.Mode.DENSITY: "XPOP", CityViewMode.Mode.GROWTH: "XROG", CityViewMode.Mode.TRAFFIC: "XTRF",
	CityViewMode.Mode.POLLUTION: "XPLT", CityViewMode.Mode.CRIME: "XCRM",
	CityViewMode.Mode.POLICE_POWER: "XPLC", CityViewMode.Mode.FIRE_POWER: "XFIR",
	CityViewMode.Mode.LAND_VALUE: "XVAL",
}
# labels under the gradient bar in the isometric legend
const RANGE_LABELS := {
	CityViewMode.Mode.HEIGHT: ["Level 1", "Level 32"],
}
# rate of growth stores a steady band around the middle of the byte range
const GROWTH_DECLINE := 0x7d
const GROWTH_INCREASE := 0x83
# modes that read as a few named states instead of a gradient
const STATE_LABELS := {
	CityViewMode.Mode.WATER: ["No link", "No supply", "Supplied"],
	CityViewMode.Mode.POWER: ["No link", "No supply", "Supplied"],
	CityViewMode.Mode.GROWTH: ["Decline", "Steady", "Growth"],
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
# heightmap stops from the original JavaScript OpenSC2K. dry land runs from green
# at level 0 to red at level 31; underwater tiles run from shallow to deep blue
static var LAND_HEIGHT_COLORS := PackedColorArray([
	Color8(0, 68, 0), Color8(0, 136, 0), Color8(0, 204, 0), Color8(0, 255, 0),
	Color8(68, 204, 0), Color8(150, 150, 0), Color8(204, 68, 0), Color8(255, 0, 17),
])
static var UNDERWATER_COLORS := PackedColorArray([Color8(17, 0, 255), Color8(0, 0, 204), Color8(0, 0, 120)])
# heightmap values from this one are underwater tiles: this value plus the depth
const UNDERWATER_BASE := 32
const MAX_LEVEL := 31
const MAX_SHOWN_DEPTH := 15
# decline, steady, and growth. the original map reads as a sign, not a scale
static var GROWTH_COLORS := PackedColorArray([Color("e2453c"), Color("b9c2cd"), Color("35d16a")])


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


static func color(data_value: int, mode: CityViewMode.Mode) -> Color:
	if data_value < 0:
		return Color("535b67")

	if mode == CityViewMode.Mode.HEIGHT:
		if data_value >= UNDERWATER_BASE:
			return _ramp(UNDERWATER_COLORS, float(data_value - UNDERWATER_BASE) / MAX_SHOWN_DEPTH)

		return _ramp(LAND_HEIGHT_COLORS, float(data_value) / MAX_LEVEL)

	if mode in [CityViewMode.Mode.WATER, CityViewMode.Mode.POWER]:
		return [Color("687381"), Color("e25c46"), Color("42bde8") if mode == CityViewMode.Mode.WATER else Color("f4d35e")][data_value]

	var amount := clampf(data_value / 255.0, 0.0, 1.0)

	if mode == CityViewMode.Mode.GROWTH:
		# the original map reads as a sign. exact amounts stay in the hover text
		return GROWTH_COLORS[growth_state(data_value)]

	var gradient: PackedColorArray = GRADIENTS.get(mode, DEFAULT_GRADIENT)

	return gradient[0].lerp(gradient[1], amount)


# a color between evenly spaced stops. `amount` runs from 0 to 1
static func _ramp(stops: PackedColorArray, amount: float) -> Color:
	var position := clampf(amount, 0.0, 1.0) * (stops.size() - 1)
	var first := mini(floori(position), stops.size() - 2)

	return stops[first].lerp(stops[first + 1], position - first)


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
		var raw := (city.tile_flags[city.index_of(point.x, point.y)] if mode in [CityViewMode.Mode.WATER, CityViewMode.Mode.POWER]
			else number)
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

	# Clipped terrain also uses the water flag to select its visible altitude.
	if mode == CityViewMode.Mode.HEIGHT or city.visible_altitude_levels < 32:
		result.append(city.masked_tile_flag_signature(Sc2TileFlags.WATER))

	return result


static func value_image(city: CityState, mode: CityViewMode.Mode) -> Image:
	if CHUNKS.has(mode):
		var chunk := city.document.find_chunk(CHUNKS[mode])
		var chunk_data := chunk.decoded_payload if chunk != null else PackedByteArray()
		var edge := CityDataGrid.edge(chunk_data, city.map_size)

		if edge > 0:
			return Image.create_from_data(edge, edge, false, Image.FORMAT_R8, chunk_data)

		return Image.create(city.map_size, city.map_size, false, Image.FORMAT_R8)

	var power := mode == CityViewMode.Mode.POWER
	var data := (NativeCityDataMesh.height_values(city.altitude_words, city.document.find_chunk("XBIT").decoded_payload)
		if mode == CityViewMode.Mode.HEIGHT
		else NativeCityDataMesh.utility_values(city.document.find_chunk("XBIT").decoded_payload,
			0x40 if power else 0x10, 0x80 if power else 0x20))

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


# the rendering library builds the geometry. see native/rendering/src/data_view.rs
# vertex colors only mark tops, walls and water. the grid shader reads each
# tile's value through the uvs
static func create_mesh(city: CityState, mode: CityViewMode.Mode) -> ArrayMesh:
	var built: Dictionary = NativeCityDataMesh.build(city.map_size, city.visible_altitude_levels, mode == CityViewMode.Mode.HEIGHT,
		city.altitude_words, city.terrain, city.tile_flags)
	var mesh := ArrayMesh.new()

	if built.has("error"):
		push_error(built.error)

		return mesh

	var vertices: PackedVector2Array = built.vertices

	if not vertices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = built.colors
		arrays[Mesh.ARRAY_TEX_UV] = built.uvs
		arrays[Mesh.ARRAY_INDEX] = built.indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return mesh


static func mesh_array_bytes(mesh: ArrayMesh) -> int:
	# create_mesh stores Vector2 vertices, Color values, Vector2 UVs, and int indices.
	var bytes := 0
	for surface in mesh.get_surface_count():
		bytes += mesh.surface_get_array_len(surface) * (8 + 16 + 8)
		bytes += mesh.surface_get_array_index_len(surface) * 4
	return bytes
