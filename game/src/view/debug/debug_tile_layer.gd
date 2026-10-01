class_name CityDebugTileLayer
extends MeshInstance2D
## Tints the tile tops of a window around the view with the active debug layer.
## The native library builds the window again only when the view leaves it or
## the terrain changes. A new layer value changes one texture, not the mesh.

@warning_ignore_start("integer_division")

const SHADER := preload("res://src/view/debug/debug_tile_layer.gdshader")
# the most tiles in one window. a wider view keeps the tiles around its center
const MAX_WINDOW_EDGE := 512
# tiles outside the visible outline. raised terrain draws above its map position
const VISIBLE_MARGIN := 48

var layer := DebugTileLayers.Layer.NONE
var window := Rect2i()
var geometry_signature: Array = []
var window_tiles := 0
var clipped := false
var builds := 0
var last_build_usec := 0
var _material := ShaderMaterial.new()
var _values_texture: ImageTexture


func _init() -> void:
	name = "DebugTileLayer"
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_material.shader = SHADER
	material = _material
	hide()


func set_layer(value: DebugTileLayers.Layer) -> void:
	if layer == value:
		return

	layer = value
	_material.set_shader_parameter("value_colors", ImageTexture.create_from_image(DebugLayerColors.table(value)))


func set_values(image: Image, map_edge: int) -> void:
	if (_values_texture != null and Vector2i(_values_texture.get_size()) == image.get_size()
			and _values_texture.get_format() == image.get_format()):
		_values_texture.update(image)
	else:
		_values_texture = ImageTexture.create_from_image(image)
		_material.set_shader_parameter("tile_values", _values_texture)

	_material.set_shader_parameter("map_edge", float(map_edge))


func set_opacity(value: float) -> void:
	_material.set_shader_parameter("opacity", value)


# true when the view or the terrain needs a new window mesh
func needs_window(target: Rect2i, signature: Array) -> bool:
	if signature != geometry_signature:
		return true

	if window.encloses(target):
		return false

	# a clipped window follows the view center in steps of a quarter window
	return not clipped or Vector2(target.get_center() - window.get_center()).length() > MAX_WINDOW_EDGE / 4


func build_window(city: CityState, target: Rect2i, signature: Array) -> void:
	var started := Time.get_ticks_usec()
	var grown := target.grow(maxi(target.size.x, target.size.y) / 4).intersection(Rect2i(0, 0, city.map_size, city.map_size))
	var limited := _limited(grown, target)
	var built := NativeDebugTiles.window_mesh(city.map_size, city.visible_altitude_levels, city.altitude_words, city.terrain,
		city.tile_flags, limited)
	var result := ArrayMesh.new()

	if not built.has("error") and not (built.vertices as PackedVector2Array).is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = built.vertices
		arrays[Mesh.ARRAY_TEX_UV] = built.uvs
		arrays[Mesh.ARRAY_INDEX] = built.indices
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)

	mesh = result
	window = limited
	clipped = not window.encloses(target)
	window_tiles = int(built.get("tiles", 0))
	geometry_signature = signature
	builds += 1
	last_build_usec = Time.get_ticks_usec() - started


func clear() -> void:
	layer = DebugTileLayers.Layer.NONE
	mesh = null
	window = Rect2i()
	geometry_signature.clear()
	window_tiles = 0
	hide()


# the tile window that covers `outline`, the visible tile corners, and `margin`
# tiles around it
static func visible_window(outline: PackedVector2Array, map_edge: int, margin := VISIBLE_MARGIN) -> Rect2i:
	if outline.is_empty():
		return Rect2i()

	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)

	for point in outline:
		low = low.min(point)
		high = high.max(point)

	var result := Rect2i(Vector2i(low.floor()), Vector2i((high - low).ceil()) + Vector2i.ONE).grow(margin)

	return result.intersection(Rect2i(0, 0, map_edge, map_edge))


# keep the window inside the size limit, centered on the target
static func _limited(window_rect: Rect2i, target: Rect2i) -> Rect2i:
	var size := window_rect.size.min(Vector2i(MAX_WINDOW_EDGE, MAX_WINDOW_EDGE))

	if size == window_rect.size:
		return window_rect

	var center := target.get_center()

	return Rect2i(center - size / 2, size).intersection(window_rect)
