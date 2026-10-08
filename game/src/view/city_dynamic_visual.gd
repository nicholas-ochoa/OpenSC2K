class_name CityDynamicVisual
extends RefCounted
# one sprite or overlay batch sent to the city canvas

var water_reflection: WaterReflectionSprite
var emission_texture: Texture2D
var vehicle_light := false
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
var transparent_shadow: bool = false
var fullbright: bool = false
var toxic_cloud: bool = false
var warm_cloud: bool = false
var beam_glow: bool = false
var special_batch: bool = false
var hidden: bool = false
var hazard_animation: CitySpriteFrameBlend
# true when the pixels come from the static image, as a shadow does, and not only from its silhouettes
var samples_static: bool = false


func _init(image_texture: Texture2D = null, destination := Vector2.ZERO, extent := Vector2.INF) -> void:
	texture = image_texture
	position = destination
	size = extent if extent != Vector2.INF else (Vector2(texture.get_size()) if texture != null else Vector2.ZERO)


# retained records own their fields and share the image and texture resources
func copy() -> CityDynamicVisual:
	var result := CityDynamicVisual.new()
	result.water_reflection = water_reflection
	result.emission_texture = emission_texture
	result.vehicle_light = vehicle_light
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
	result.transparent_shadow = transparent_shadow
	result.fullbright = fullbright
	result.toxic_cloud = toxic_cloud
	result.warm_cloud = warm_cloud
	result.beam_glow = beam_glow
	result.special_batch = special_batch
	result.hidden = hidden
	result.hazard_animation = hazard_animation
	result.samples_static = samples_static

	return result


func matches(other: CityDynamicVisual) -> bool:
	return (other != null
		and texture == other.texture
		and water_reflection == other.water_reflection
		and emission_texture == other.emission_texture
		and vehicle_light == other.vehicle_light
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
		and transparent_shadow == other.transparent_shadow
		and fullbright == other.fullbright
		and toxic_cloud == other.toxic_cloud
		and warm_cloud == other.warm_cloud
		and beam_glow == other.beam_glow
		and special_batch == other.special_batch
		and hidden == other.hidden
		and hazard_animation == other.hazard_animation
	)


# cache stamps compare fields by value while retaining resource identity
func value_signature() -> Array:
	return [texture, water_reflection, emission_texture, vehicle_light, index_texture, palette_lookup_all, texture_factor, position, size,
		image, special_overlay, batch_cache_key, depth_order, shadow, transparent_shadow, fullbright, toxic_cloud, warm_cloud, beam_glow, special_batch, hidden, hazard_animation]


static func build_grid(visuals: Array[CityDynamicVisual]) -> NativeRectIndex:
	var rects := PackedInt32Array()

	for visual in visuals:
		rects.append_array([int(visual.position.x), int(visual.position.y), int(visual.size.x), int(visual.size.y)])

	return IsometricPixelOperations.build_rect_grid(rects, 1)
