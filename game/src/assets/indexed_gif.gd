class_name IndexedGif
extends RefCounted


# gif89a export and indexed gif import. the cycle export has full frames with
# local palettes and a repeating scurk cycle. the native formats library writes
# and reads the files

const CYCLE_START := 31 # past the one-time slow-table initialization
const CYCLE_TICKS := 120 # lcm of the 40-tick fast and 60-tick slow cycles


static func encode_cycle(width: int, height: int, pixels: PackedInt32Array, palette: Sc2Palette) -> AssetBytesResult:
	if palette == null or not palette.is_valid():
		return AssetBytesResult.failure("Invalid SCURK GIF dimensions, pixels, or palette.")

	# the first map colors the global table; each later tick may start a frame
	var mappings: Array[PackedInt32Array] = [palette.scurk_animation_index_map(CYCLE_START)]

	for tick in CYCLE_TICKS:
		mappings.append(palette.scurk_animation_index_map(CYCLE_START + tick))

	var encoded := NativeIndexedGif.encode_cycle(width, height, pixels, palette.to_rgb_bytes(), mappings)

	if not encoded.ok:
		return AssetBytesResult.failure(encoded.error)

	var outcome := AssetBytesResult.new()
	outcome.ok = true
	outcome.error = ""
	outcome.bytes = encoded.bytes
	outcome.frame_count = encoded.frame_count
	outcome.duration_cs = 660

	return outcome


# one frame with the palette in its original index order
static func encode(width: int, height: int, pixels: PackedInt32Array, palette: Sc2Palette) -> AssetBytesResult:
	if palette == null or not palette.is_valid():
		return AssetBytesResult.failure("Invalid GIF dimensions, pixels, or palette.")

	var encoded := NativeIndexedGif.encode(width, height, pixels, palette.to_rgb_bytes())

	if not encoded.ok:
		return AssetBytesResult.failure(encoded.error)

	var outcome := AssetBytesResult.new()
	outcome.ok = true
	outcome.error = ""
	outcome.bytes = encoded.bytes
	outcome.frame_count = 1

	return outcome


static func load_path(path: String) -> IndexedImageResult:
	if not FileAccess.file_exists(path):
		return IndexedImageResult.failure("GIF file does not exist: %s" % path)

	return decode(FileAccess.get_file_as_bytes(path))


# the first image of the file on its logical screen. pixels outside that image
# and pixels with the transparent index are -1. the palette has 256 entries
static func decode(bytes: PackedByteArray) -> IndexedImageResult:
	var decoded := NativeIndexedGif.decode(bytes)

	if not decoded.ok:
		return IndexedImageResult.failure(decoded.error)

	var result := IndexedImageResult.new()
	result.pixels = decoded.pixels
	result.palette = Sc2Palette.from_rgb_bytes(decoded.palette)
	result.colors = result.palette.colors
	result.width = decoded.width
	result.height = decoded.height
	result.ok = true

	return result
