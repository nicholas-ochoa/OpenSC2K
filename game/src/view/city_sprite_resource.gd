class_name CitySpriteResource
extends RefCounted
# cached indexed sprite pixels and their display texture

var image: Image
var native_size := Vector2i.ZERO
var texture: ImageTexture
var index_texture: ImageTexture
var _waterline := PackedInt32Array()


# the waterline rows of `image`, for floating sprites. see IsometricFloatingOcclusion
func waterline() -> PackedInt32Array:
	if _waterline.is_empty() and image != null:
		_waterline = IsometricFloatingOcclusion.waterline(image)

	return _waterline
