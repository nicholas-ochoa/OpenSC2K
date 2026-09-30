class_name Sc2ImportBitmap
extends RefCounted
## Decode indexed Windows BMP/DIB resources without a PE-specific wrapper.


static func decode(data: PackedByteArray, file_header := false) -> IndexedImageResult:
	var decoded := NativeIndexedBmp.decode_indexed(data, file_header)

	if not decoded.ok:
		return IndexedImageResult.failure(decoded.error)

	var result := IndexedImageResult.new()
	result.pixels = decoded.pixels
	result.palette = Sc2Palette.from_rgb_bytes(decoded.palette)
	result.colors = result.palette.colors
	result.width = decoded.width
	result.height = decoded.height
	result.top_down = decoded.top_down
	result.ok = true
	return result
