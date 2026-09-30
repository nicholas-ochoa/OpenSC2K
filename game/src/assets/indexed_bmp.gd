class_name IndexedBmp
extends RefCounted

## 8-bit indexed bitmaps with 256 colors. The native formats library reads and writes them.

const FILE_HEADER_SIZE := 14
const INFO_HEADER_SIZE := 40
const PALETTE_COLOR_COUNT := 256
const PIXEL_OFFSET := FILE_HEADER_SIZE + INFO_HEADER_SIZE + PALETTE_COLOR_COUNT * 4


static func load_path(path: String, target_palette: Sc2Palette) -> IndexedImageResult:
	if not FileAccess.file_exists(path):
		return IndexedImageResult.failure("BMP file does not exist: %s" % path)

	var bytes := FileAccess.get_file_as_bytes(path)

	if FileAccess.get_open_error() != OK:
		return IndexedImageResult.failure("Cannot read BMP file: %s" % path)

	var decoded := decode(bytes)

	if not decoded.ok:
		return decoded

	var mapped := map_to_palette(decoded, target_palette)

	if not mapped.ok:
		return mapped

	var outcome := IndexedImageResult.new()
	outcome.ok = true
	outcome.error = ""
	outcome.width = decoded.width
	outcome.height = decoded.height
	outcome.pixels = mapped.pixels
	outcome.remapped_color_count = mapped.remapped_color_count

	return outcome


static func save_path(
	path: String,
	width: int,
	height: int,
	pixels: PackedInt32Array,
	palette: Sc2Palette
) -> FileWriteResult:
	var encoded := encode(width, height, pixels, palette)

	if not encoded.ok:
		return FileWriteResult.failure(encoded.error)

	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		return FileWriteResult.failure("Cannot open BMP output: %s" % error_string(FileAccess.get_open_error()))

	file.store_buffer(encoded.bytes)
	var write_error := file.get_error()
	file.close()

	if write_error != OK:
		return FileWriteResult.failure("Cannot write BMP output: %s" % error_string(write_error))

	var outcome := FileWriteResult.new()
	outcome.ok = true
	outcome.error = ""
	outcome.path = path

	return outcome


static func encode_dib(
	width: int,
	height: int,
	pixels: PackedInt32Array,
	palette: Sc2Palette,
	transparent_index := 0
) -> AssetBytesResult:
	var encoded := encode(width, height, pixels, palette, transparent_index)

	if not encoded.ok:
		return encoded

	return bmp_to_dib(encoded.bytes)


static func decode_dib(bytes: PackedByteArray) -> IndexedImageResult:
	var wrapped := dib_to_bmp(bytes)

	if not wrapped.ok:
		return IndexedImageResult.failure(wrapped.error)

	return decode(wrapped.bytes)


static func bmp_to_dib(bytes: PackedByteArray) -> AssetBytesResult:
	return _bytes_result(NativeIndexedBmp.to_dib(bytes))


static func dib_to_bmp(bytes: PackedByteArray) -> AssetBytesResult:
	return _bytes_result(NativeIndexedBmp.from_dib(bytes))


static func decode(bytes: PackedByteArray) -> IndexedImageResult:
	var decoded := NativeIndexedBmp.decode(bytes)

	if not decoded.ok:
		return IndexedImageResult.failure(decoded.error)

	var outcome := IndexedImageResult.new()
	outcome.ok = true
	outcome.error = ""
	outcome.width = decoded.width
	outcome.height = decoded.height
	outcome.pixels = decoded.pixels
	outcome.colors = Sc2Palette.from_rgb_bytes(decoded.palette).colors
	outcome.top_down = decoded.top_down

	return outcome


static func map_to_palette(
	decoded: IndexedImageResult, target_palette: Sc2Palette, transparent_index := 0
) -> IndexedImageResult:
	if not decoded.ok:
		return IndexedImageResult.failure(decoded.error)

	if target_palette == null or not target_palette.is_valid():
		return IndexedImageResult.failure("The SimCity 2000 palette is not available.")

	var source := Sc2Palette.new()
	source.colors.assign(decoded.colors)

	if not source.is_valid():
		return IndexedImageResult.failure("BMP palette does not contain 256 colors.")

	var mapped := NativeIndexedBmp.map_to_palette(decoded.pixels, source.to_rgb_bytes(), target_palette.to_rgb_bytes(),
		transparent_index)
	var outcome := IndexedImageResult.new()
	outcome.ok = true
	outcome.error = ""
	outcome.pixels = mapped.pixels
	outcome.remapped_color_count = mapped.remapped_color_count

	return outcome


static func encode(
	width: int,
	height: int,
	pixels: PackedInt32Array,
	palette: Sc2Palette,
	transparent_index := 0
) -> AssetBytesResult:
	var colors := palette.to_rgb_bytes() if palette != null else PackedByteArray()

	return _bytes_result(NativeIndexedBmp.encode(width, height, pixels, colors, transparent_index))


static func _bytes_result(value: Dictionary) -> AssetBytesResult:
	if not value.ok:
		return AssetBytesResult.failure(value.error)

	var outcome := AssetBytesResult.new()
	outcome.ok = true
	outcome.error = ""
	outcome.bytes = value.bytes

	return outcome
