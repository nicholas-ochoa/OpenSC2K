class_name WindowsBitmapRle8
extends RefCounted
# bi_rle8 decoding to top-down palette indices. no rgb index matching. the
# native formats library decodes the runs


static func decode(bytes: PackedByteArray, width: int, height: int) -> IndexedImageResult:
	var decoded := NativePeResources.decode_rle8(bytes, width, height)

	if not decoded.ok:
		return IndexedImageResult.failure(decoded.error)

	var outcome := IndexedImageResult.new()
	outcome.ok = true
	outcome.pixels = decoded.pixels
	outcome.consumed = decoded.consumed
	outcome.error = ""

	return outcome
