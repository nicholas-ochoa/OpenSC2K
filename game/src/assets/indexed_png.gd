class_name IndexedPng
extends RefCounted
# read editor-authored pngs without losing duplicate palette indices. the native
# formats library checks and writes the records

const MAX_DIMENSION := 4096


static func load_path(path: String, strict_palette := true) -> IndexedImageResult:
	if not FileAccess.file_exists(path):
		return IndexedImageResult.failure("PNG file does not exist: %s" % path)

	return decode(FileAccess.get_file_as_bytes(path), strict_palette)


static func decode(bytes: PackedByteArray, strict_palette := true) -> IndexedImageResult:
	var decoded := NativeIndexedPng.decode(bytes, strict_palette)

	if not decoded.ok:
		return IndexedImageResult.failure(decoded.error)

	var outcome := IndexedImageResult.new()
	outcome.ok = true
	outcome.error = ""
	outcome.width = decoded.width
	outcome.height = decoded.height
	outcome.pixels = decoded.pixels
	outcome.palette = Sc2Palette.from_rgb_bytes(decoded.palette)

	return outcome


static func encode(
	width: int, height: int, pixels: PackedInt32Array, palette: Sc2Palette
) -> AssetBytesResult:
	if palette == null or not palette.is_valid():
		if width < 1 or height < 1 or width > MAX_DIMENSION or height > MAX_DIMENSION:
			return AssetBytesResult.failure("PNG dimensions must be 1 through 4096")

		return AssetBytesResult.failure("Invalid PNG pixels or palette")

	var encoded := NativeIndexedPng.encode(width, height, pixels, palette.to_rgb_bytes())

	if not encoded.ok:
		return AssetBytesResult.failure(encoded.error)

	var outcome := AssetBytesResult.new()
	outcome.ok = true
	outcome.error = ""
	outcome.bytes = encoded.bytes

	return outcome
