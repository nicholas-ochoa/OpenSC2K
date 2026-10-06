class_name CitySpriteResource
extends RefCounted
# cached indexed sprite pixels and their display texture

var image: Image
var native_size := Vector2i.ZERO
var texture: ImageTexture
var index_texture: ImageTexture
var _waterline := PackedInt32Array()
var _light_source: Image
var _light_mask: Image
var _light_texture: ImageTexture
var _reflection: WaterReflectionSprite
var _reflection_palette: Sc2Palette


# the waterline rows of `image`, for floating sprites. see IsometricFloatingOcclusion
func waterline() -> PackedInt32Array:
	if _waterline.is_empty() and image != null:
		_waterline = IsometricFloatingOcclusion.waterline(image)

	return _waterline


# Light pixels and reflected hulls depend on artwork, not the moving position.
func light_mask(source: Image, flip: bool) -> Image:
	if source != _light_source:
		_light_source = source
		_light_mask = CityBrightmaps.transform_mask(source, image, flip)
		_light_texture = ImageTexture.create_from_image(_light_mask) if _light_mask != null else null
		_reflection = null
	return _light_mask


func light_texture() -> ImageTexture:
	return _light_texture


func reflection(origin: Vector2i, level: int, palette: Sc2Palette) -> WaterReflectionSprite:
	if _reflection == null or _reflection_palette != palette:
		_reflection = WaterReflectionSprite.create(image, _light_mask, Vector2i.ZERO, 0, palette)
		_reflection_palette = palette
	var result := WaterReflectionSprite.new()
	result.position = origin
	result.level = level
	result.image = _reflection.image
	result.emission = _reflection.emission
	return result
