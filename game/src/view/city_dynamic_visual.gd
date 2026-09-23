class_name CityDynamicVisual
extends RefCounted
# one sprite or overlay batch sent to the city canvas
# a negative gpu mode uses the cpu-composed pixels

var texture: Texture2D
var index_texture: Texture2D
var palette_lookup_all: bool = false
var texture_factor: int = 1
var position: Vector2 = Vector2.ZERO
var size: Vector2 = Vector2.ZERO
var image: Image
var special_overlay: bool = false
var batch_cache_key: String = ""
var depth_order: int = -1
var shadow: bool = false
var record: int = -1
var gpu_mode: int = -1
var special_batch: bool = false
var hidden: bool = false
# true when the pixels come from the static image, as a shadow does, and not only from its silhouettes
var samples_static: bool = false


func _init(image_texture: Texture2D = null, destination := Vector2.ZERO, extent := Vector2.INF) -> void:
	texture = image_texture
	position = destination
	size = extent if extent != Vector2.INF else (Vector2(texture.get_size()) if texture != null else Vector2.ZERO)


# retained records own their fields and share the image and texture resources
func copy() -> CityDynamicVisual:
	var result := CityDynamicVisual.new()
	result.texture = texture
	result.index_texture = index_texture
	result.palette_lookup_all = palette_lookup_all
	result.texture_factor = texture_factor
	result.position = position
	result.size = size
	result.image = image
	result.special_overlay = special_overlay
	result.batch_cache_key = batch_cache_key
	result.depth_order = depth_order
	result.shadow = shadow
	result.record = record
	result.gpu_mode = gpu_mode
	result.special_batch = special_batch
	result.hidden = hidden
	result.samples_static = samples_static

	return result


func matches(other: CityDynamicVisual) -> bool:
	return (other != null
		and texture == other.texture
		and index_texture == other.index_texture
		and palette_lookup_all == other.palette_lookup_all
		and texture_factor == other.texture_factor
		and position == other.position
		and size == other.size
		and image == other.image
		and special_overlay == other.special_overlay
		and batch_cache_key == other.batch_cache_key
		and depth_order == other.depth_order
		and shadow == other.shadow
		and record == other.record
		and gpu_mode == other.gpu_mode
		and special_batch == other.special_batch
		and hidden == other.hidden
	)


# cache stamps compare fields by value while retaining resource identity
func value_signature() -> Array:
	return [texture, index_texture, palette_lookup_all, texture_factor, position, size,
		image, special_overlay, batch_cache_key, depth_order, shadow, record,
		gpu_mode, special_batch, hidden]


static func build_grid(visuals: Array[CityDynamicVisual]) -> Dictionary[Vector2i, Array]:
	var grid: Dictionary[Vector2i, Array] = {}

	for index in visuals.size():
		var visual := visuals[index]
		IsometricPixelOperations.append_occlusion_bounds(grid, Rect2i(Vector2i(visual.position), Vector2i(visual.size)), index)

	return grid
